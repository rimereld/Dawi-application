import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart' show MediaType;
import 'package:image_picker/image_picker.dart' show XFile;

import '../models/api_models.dart';
import 'token_storage.dart';

/// Thin HTTP client wrapping the personal health app's FastAPI backend.
/// Attaches the stored JWT (if any) as a Bearer token on every request.
class ApiService {
  final String baseUrl;
  final http.Client _client;
  String? _cachedToken;

  static const String _dartDefineBaseUrl = String.fromEnvironment('API_BASE_URL');

  /// Auto-detected default, correct for the common local-dev cases — see
  /// the frontend README's troubleshooting section for details on each case.
  static String get _defaultBaseUrl {
    if (_dartDefineBaseUrl.isNotEmpty) return _dartDefineBaseUrl;
    if (kIsWeb) return 'http://localhost:8000';
    try {
      if (Platform.isAndroid) return 'http://10.0.2.2:8000';
    } catch (_) {
      // Platform.* can throw in unusual embeddings; fall through.
    }
    return 'http://localhost:8000'; // iOS simulator, macOS, etc.
  }

  ApiService({String? baseUrl, http.Client? client})
      : baseUrl = baseUrl ?? _defaultBaseUrl,
        _client = client ?? http.Client();

  Uri _uri(String path) => Uri.parse('$baseUrl$path');

  Future<Map<String, String>> _authHeaders({bool json = true}) async {
    _cachedToken ??= await tokenStorage.readToken();
    return {
      if (json) 'Content-Type': 'application/json',
      if (_cachedToken != null) 'Authorization': 'Bearer $_cachedToken',
    };
  }

  /// Call after login/register/logout so subsequent requests immediately
  /// use the new (or cleared) token without waiting on secure storage.
  void setCachedToken(String? token) => _cachedToken = token;

  void _throwIfError(http.Response response, String action) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    String message = response.body;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map && decoded['detail'] != null) message = decoded['detail'].toString();
    } catch (_) {
      // response body wasn't JSON; use it as-is
    }
    throw ApiException('$action failed (${response.statusCode}): $message');
  }

  /// Turns a relative path returned by the API (e.g. '/uploads/xyz.jpg')
  /// into a fully-qualified URL the app can load with Image.network.
  String resolveImageUrl(String urlOrPath) {
    if (urlOrPath.isEmpty) return '';
    if (urlOrPath.startsWith('http')) return urlOrPath;
    final path = urlOrPath.startsWith('/') ? urlOrPath : '/$urlOrPath';
    return '$baseUrl$path';
  }

  // -------------------------------------------------------------------
  // Auth
  // -------------------------------------------------------------------

  Future<AuthResult> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String phone,
    required String preferredLanguage,
  }) async {
    final response = await _client.post(
      _uri('/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
        'first_name': firstName,
        'last_name': lastName,
        'phone': phone,
        'preferred_language': preferredLanguage,
      }),
    );
    _throwIfError(response, 'Registration');
    return AuthResult.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<AuthResult> login({required String email, required String password}) async {
    final response = await _client.post(
      _uri('/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    _throwIfError(response, 'Login');
    return AuthResult.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<ApiUser> getMe() async {
    final response = await _client.get(_uri('/auth/me'), headers: await _authHeaders());
    _throwIfError(response, 'Fetching profile');
    return ApiUser.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  // -------------------------------------------------------------------
  // Documents
  // -------------------------------------------------------------------

  /// Best-effort MIME type for a picked file, since `image_picker`'s
  /// `XFile.mimeType` is often null (especially on iOS/desktop), and an
  /// unset Content-Type on the multipart part makes the backend reject the
  /// upload with 400 Bad Request. Falls back to the file extension, then
  /// to JPEG as a last resort.
  MediaType _mimeTypeFor(XFile file) {
    final reported = file.mimeType;
    if (reported != null && reported.contains('/')) {
      return MediaType.parse(reported);
    }
    final name = file.name.toLowerCase();
    if (name.endsWith('.png')) return MediaType('image', 'png');
    if (name.endsWith('.webp')) return MediaType('image', 'webp');
    if (name.endsWith('.heic') || name.endsWith('.heif')) return MediaType('image', 'heic');
    if (name.endsWith('.pdf')) return MediaType('application', 'pdf');
    return MediaType('image', 'jpeg');
  }

  /// Uploads a document (photo or PDF), runs OCR/text-extraction + AI
  /// parsing, and returns the draft extracted info for the user to review.
  Future<ScanResult> scanDocument(XFile file) async {
    final request = http.MultipartRequest('POST', _uri('/documents/scan'));
    final authHeaders = await _authHeaders(json: false);
    request.headers.addAll(authHeaders);
    final bytes = await file.readAsBytes();
    final contentType = _mimeTypeFor(file);
    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: file.name.isNotEmpty ? file.name : 'document.${contentType.subtype}',
        contentType: contentType,
      ),
    );

    final streamedResponse = await _client.send(request);
    final response = await http.Response.fromStream(streamedResponse);
    _throwIfError(response, 'Scan');
    return ScanResult.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<ApiDocument> confirmDocument({
    required String documentId,
    required String documentType,
    required String doctorName,
    required String clinicName,
    required String documentDate,
    required List<ApiMedication> medications,
  }) async {
    final response = await _client.patch(
      _uri('/documents/$documentId/confirm'),
      headers: await _authHeaders(),
      body: jsonEncode({
        'document_type': documentType,
        'doctor_name': doctorName,
        'clinic_name': clinicName,
        'document_date': documentDate,
        'medications': medications.map((m) => m.toJson()).toList(),
      }),
    );
    _throwIfError(response, 'Confirm document');
    return ApiDocument.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<List<ApiDocument>> listDocuments({String? documentType}) async {
    final uri = _uri('/documents').replace(
      queryParameters: documentType != null ? {'document_type': documentType} : null,
    );
    final response = await _client.get(uri, headers: await _authHeaders());
    _throwIfError(response, 'List documents');
    final list = jsonDecode(response.body) as List<dynamic>;
    return list.map((d) => ApiDocument.fromJson(d as Map<String, dynamic>)).toList();
  }

  Future<ApiDocument> getDocument(String documentId) async {
    final response = await _client.get(_uri('/documents/$documentId'), headers: await _authHeaders());
    _throwIfError(response, 'Get document');
    return ApiDocument.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<void> deleteDocument(String documentId) async {
    final response = await _client.delete(_uri('/documents/$documentId'), headers: await _authHeaders());
    _throwIfError(response, 'Delete document');
  }

  Future<AiExplanationResult> explainDocument(String documentId) async {
    final response = await _client.post(_uri('/documents/$documentId/explain'), headers: await _authHeaders());
    _throwIfError(response, 'AI explanation');
    return AiExplanationResult.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  // -------------------------------------------------------------------
  // Medications
  // -------------------------------------------------------------------

  Future<List<ApiMedication>> listMedications({String? status}) async {
    final uri = _uri('/medications').replace(queryParameters: status != null ? {'status': status} : null);
    final response = await _client.get(uri, headers: await _authHeaders());
    _throwIfError(response, 'List medications');
    final list = jsonDecode(response.body) as List<dynamic>;
    return list.map((m) => ApiMedication.fromJson(m as Map<String, dynamic>)).toList();
  }

  Future<ApiMedication> getMedication(String id) async {
    final response = await _client.get(_uri('/medications/$id'), headers: await _authHeaders());
    _throwIfError(response, 'Get medication');
    return ApiMedication.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<ApiMedication> createMedication(ApiMedication medication) async {
    final response = await _client.post(
      _uri('/medications'),
      headers: await _authHeaders(),
      body: jsonEncode(medication.toJson()),
    );
    _throwIfError(response, 'Add medication');
    return ApiMedication.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<ApiMedication> updateMedication(String id, ApiMedication medication) async {
    final response = await _client.put(
      _uri('/medications/$id'),
      headers: await _authHeaders(),
      body: jsonEncode(medication.toJson()),
    );
    _throwIfError(response, 'Update medication');
    return ApiMedication.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<void> deleteMedication(String id) async {
    final response = await _client.delete(_uri('/medications/$id'), headers: await _authHeaders());
    _throwIfError(response, 'Delete medication');
  }

  // -------------------------------------------------------------------
  // Appointments
  // -------------------------------------------------------------------

  Future<List<ApiAppointment>> listAppointments({String? status}) async {
    final uri = _uri('/appointments').replace(queryParameters: status != null ? {'status': status} : null);
    final response = await _client.get(uri, headers: await _authHeaders());
    _throwIfError(response, 'List appointments');
    final list = jsonDecode(response.body) as List<dynamic>;
    return list.map((a) => ApiAppointment.fromJson(a as Map<String, dynamic>)).toList();
  }

  Future<ApiAppointment> createAppointment(ApiAppointment appointment) async {
    final response = await _client.post(
      _uri('/appointments'),
      headers: await _authHeaders(),
      body: jsonEncode(appointment.toJson()),
    );
    _throwIfError(response, 'Add appointment');
    return ApiAppointment.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<ApiAppointment> updateAppointment(String id, ApiAppointment appointment) async {
    final response = await _client.put(
      _uri('/appointments/$id'),
      headers: await _authHeaders(),
      body: jsonEncode(appointment.toJson()),
    );
    _throwIfError(response, 'Update appointment');
    return ApiAppointment.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<void> deleteAppointment(String id) async {
    final response = await _client.delete(_uri('/appointments/$id'), headers: await _authHeaders());
    _throwIfError(response, 'Delete appointment');
  }

  // -------------------------------------------------------------------
  // Doctors
  // -------------------------------------------------------------------

  Future<List<ApiDoctor>> listDoctors() async {
    final response = await _client.get(_uri('/doctors'), headers: await _authHeaders());
    _throwIfError(response, 'List doctors');
    final list = jsonDecode(response.body) as List<dynamic>;
    return list.map((d) => ApiDoctor.fromJson(d as Map<String, dynamic>)).toList();
  }

  Future<ApiDoctor> createDoctor(ApiDoctor doctor) async {
    final response = await _client.post(
      _uri('/doctors'),
      headers: await _authHeaders(),
      body: jsonEncode(doctor.toJson()),
    );
    _throwIfError(response, 'Add doctor');
    return ApiDoctor.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  // -------------------------------------------------------------------
  // Health profile / medical record / AI summary
  // -------------------------------------------------------------------

  Future<ApiHealthProfile?> getHealthProfile() async {
    final response = await _client.get(_uri('/health/profile'), headers: await _authHeaders());
    _throwIfError(response, 'Get health profile');
    if (response.body == 'null' || response.body.isEmpty) return null;
    return ApiHealthProfile.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<ApiHealthProfile> saveHealthProfile(ApiHealthProfile profile) async {
    final response = await _client.put(
      _uri('/health/profile'),
      headers: await _authHeaders(),
      body: jsonEncode(profile.toJson()),
    );
    _throwIfError(response, 'Save health profile');
    return ApiHealthProfile.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<MedicalRecord> getMedicalRecord() async {
    final response = await _client.get(_uri('/health/medical-record'), headers: await _authHeaders());
    _throwIfError(response, 'Get medical record');
    return MedicalRecord.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<AiHealthSummary> getAiHealthSummary() async {
    final response = await _client.get(_uri('/health/summary'), headers: await _authHeaders());
    _throwIfError(response, 'Get AI health summary');
    return AiHealthSummary.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  // -------------------------------------------------------------------
  // AI Assistant chat
  // -------------------------------------------------------------------

  Future<String> sendChatMessage({required String message, String? documentId}) async {
    final response = await _client.post(
      _uri('/chat'),
      headers: await _authHeaders(),
      body: jsonEncode({'message': message, if (documentId != null) 'document_id': documentId}),
    );
    _throwIfError(response, 'Chat');
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return body['reply'] as String? ?? '';
  }

  Future<List<Map<String, String>>> getChatHistory({String? documentId}) async {
    final uri = _uri('/chat/history').replace(
      queryParameters: documentId != null ? {'document_id': documentId} : null,
    );
    final response = await _client.get(uri, headers: await _authHeaders());
    _throwIfError(response, 'Get chat history');
    final list = jsonDecode(response.body) as List<dynamic>;
    return list
        .map((m) => {'role': m['role'] as String, 'content': m['content'] as String})
        .toList();
  }

  void dispose() => _client.close();
}

class ApiException implements Exception {
  final String message;
  ApiException(this.message);

  @override
  String toString() => message;
}

/// Shared instance used across screens so they don't each open their own
/// HTTP client. Screens import this and call e.g. `apiService.listDocuments()`.
final ApiService apiService = ApiService();
