/// DTOs mirroring the FastAPI backend's Pydantic schemas
/// (see `rx_scanner_backend/app/schemas.py`).
library;

// ---------------------------------------------------------------------------
// Auth
// ---------------------------------------------------------------------------

class ApiUser {
  final String id;
  final String email;
  final String firstName;
  final String lastName;
  final String phone;
  final String preferredLanguage;

  ApiUser({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.phone,
    required this.preferredLanguage,
  });

  String get fullName => [firstName, lastName].where((s) => s.isNotEmpty).join(' ');

  factory ApiUser.fromJson(Map<String, dynamic> json) => ApiUser(
        id: json['id'] as String,
        email: json['email'] as String? ?? '',
        firstName: json['first_name'] as String? ?? '',
        lastName: json['last_name'] as String? ?? '',
        phone: json['phone'] as String? ?? '',
        preferredLanguage: json['preferred_language'] as String? ?? 'English',
      );
}

class AuthResult {
  final String accessToken;
  final ApiUser user;
  AuthResult({required this.accessToken, required this.user});

  factory AuthResult.fromJson(Map<String, dynamic> json) => AuthResult(
        accessToken: json['access_token'] as String,
        user: ApiUser.fromJson(json['user'] as Map<String, dynamic>),
      );
}

// ---------------------------------------------------------------------------
// Medications
// ---------------------------------------------------------------------------

class ApiMedication {
  final String? id;
  final String? documentId;
  final String name;
  final String form;
  final String dose;
  final String frequency;
  final String timing;
  final String doctorName;
  final String startDate;
  final String endDate;
  final String status; // active | completed | upcoming
  bool confirmed;

  ApiMedication({
    this.id,
    this.documentId,
    required this.name,
    required this.form,
    required this.dose,
    required this.frequency,
    required this.timing,
    this.doctorName = '',
    this.startDate = '',
    this.endDate = '',
    this.status = 'active',
    this.confirmed = true,
  });

  factory ApiMedication.fromJson(Map<String, dynamic> json) => ApiMedication(
        id: json['id'] as String?,
        documentId: json['document_id'] as String?,
        name: json['name'] as String? ?? '',
        form: json['form'] as String? ?? '',
        dose: json['dose'] as String? ?? '',
        frequency: json['frequency'] as String? ?? '',
        timing: json['timing'] as String? ?? '',
        doctorName: json['doctor_name'] as String? ?? '',
        startDate: json['start_date'] as String? ?? '',
        endDate: json['end_date'] as String? ?? '',
        status: json['status'] as String? ?? 'active',
        confirmed: json['confirmed'] as bool? ?? true,
      );

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'name': name,
        'form': form,
        'dose': dose,
        'frequency': frequency,
        'timing': timing,
        'doctor_name': doctorName,
        'start_date': startDate,
        'end_date': endDate,
        'status': status,
        'confirmed': confirmed,
      };
}

// ---------------------------------------------------------------------------
// Documents
// ---------------------------------------------------------------------------

class ScanResult {
  final String documentId;
  final String documentType;
  final String rawOcrText;
  final String aiSummary;
  final List<ApiMedication> medications;
  final String doctorName;
  final String clinicName;
  final String fileUrl;

  ScanResult({
    required this.documentId,
    required this.documentType,
    required this.rawOcrText,
    required this.aiSummary,
    required this.medications,
    required this.doctorName,
    required this.clinicName,
    required this.fileUrl,
  });

  factory ScanResult.fromJson(Map<String, dynamic> json) => ScanResult(
        documentId: json['document_id'] as String,
        documentType: json['document_type'] as String? ?? 'other',
        rawOcrText: json['raw_ocr_text'] as String? ?? '',
        aiSummary: json['ai_summary'] as String? ?? '',
        medications: (json['medications'] as List<dynamic>? ?? [])
            .map((m) => ApiMedication.fromJson(m as Map<String, dynamic>))
            .toList(),
        doctorName: json['doctor_name'] as String? ?? '',
        clinicName: json['clinic_name'] as String? ?? '',
        fileUrl: json['file_url'] as String? ?? '',
      );
}

class ApiDocument {
  final String id;
  final String documentType;
  final String doctorName;
  final String clinicName;
  final String documentDate;
  final String fileUrl;
  final String rawOcrText;
  final String aiSummary;
  final DateTime createdAt;
  final List<ApiMedication> medications;

  ApiDocument({
    required this.id,
    required this.documentType,
    required this.doctorName,
    required this.clinicName,
    required this.documentDate,
    required this.fileUrl,
    required this.rawOcrText,
    required this.aiSummary,
    required this.createdAt,
    required this.medications,
  });

  factory ApiDocument.fromJson(Map<String, dynamic> json) => ApiDocument(
        id: json['id'] as String,
        documentType: json['document_type'] as String? ?? 'other',
        doctorName: json['doctor_name'] as String? ?? '',
        clinicName: json['clinic_name'] as String? ?? '',
        documentDate: json['document_date'] as String? ?? '',
        fileUrl: json['file_url'] as String? ?? '',
        rawOcrText: json['raw_ocr_text'] as String? ?? '',
        aiSummary: json['ai_summary'] as String? ?? '',
        createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
        medications: (json['medications'] as List<dynamic>? ?? [])
            .map((m) => ApiMedication.fromJson(m as Map<String, dynamic>))
            .toList(),
      );
}

class AiExplanationTerm {
  final String term;
  final String explanation;
  AiExplanationTerm({required this.term, required this.explanation});
  factory AiExplanationTerm.fromJson(Map<String, dynamic> json) => AiExplanationTerm(
        term: json['term'] as String? ?? '',
        explanation: json['explanation'] as String? ?? '',
      );
}

class AiMedicationExplanation {
  final String name;
  final String dosage;
  final String frequency;
  final String duration;
  final String purpose;
  AiMedicationExplanation({
    required this.name,
    required this.dosage,
    required this.frequency,
    required this.duration,
    required this.purpose,
  });
  factory AiMedicationExplanation.fromJson(Map<String, dynamic> json) => AiMedicationExplanation(
        name: json['name'] as String? ?? '',
        dosage: json['dosage'] as String? ?? '',
        frequency: json['frequency'] as String? ?? '',
        duration: json['duration'] as String? ?? '',
        purpose: json['purpose'] as String? ?? '',
      );
}

class AiExplanationResult {
  final String simpleExplanation;
  final List<AiExplanationTerm> medicalTerms;
  final List<AiMedicationExplanation> medicationExplanations;
  final List<String> importantInformation;
  final List<String> questionsForDoctor;
  final String disclaimer;

  AiExplanationResult({
    required this.simpleExplanation,
    required this.medicalTerms,
    required this.medicationExplanations,
    required this.importantInformation,
    required this.questionsForDoctor,
    required this.disclaimer,
  });

  factory AiExplanationResult.fromJson(Map<String, dynamic> json) => AiExplanationResult(
        simpleExplanation: json['simple_explanation'] as String? ?? '',
        medicalTerms: (json['medical_terms'] as List<dynamic>? ?? [])
            .map((t) => AiExplanationTerm.fromJson(t as Map<String, dynamic>))
            .toList(),
        medicationExplanations: (json['medication_explanations'] as List<dynamic>? ?? [])
            .map((m) => AiMedicationExplanation.fromJson(m as Map<String, dynamic>))
            .toList(),
        importantInformation: (json['important_information'] as List<dynamic>? ?? [])
            .map((s) => s as String)
            .toList(),
        questionsForDoctor: (json['questions_for_doctor'] as List<dynamic>? ?? [])
            .map((s) => s as String)
            .toList(),
        disclaimer: json['disclaimer'] as String? ?? '',
      );
}

// ---------------------------------------------------------------------------
// Doctors
// ---------------------------------------------------------------------------

class ApiDoctor {
  final String? id;
  final String name;
  final String specialty;
  final String hospital;
  final String phone;

  ApiDoctor({
    this.id,
    required this.name,
    required this.specialty,
    required this.hospital,
    required this.phone,
  });

  factory ApiDoctor.fromJson(Map<String, dynamic> json) => ApiDoctor(
        id: json['id'] as String?,
        name: json['name'] as String? ?? '',
        specialty: json['specialty'] as String? ?? '',
        hospital: json['hospital'] as String? ?? '',
        phone: json['phone'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'specialty': specialty,
        'hospital': hospital,
        'phone': phone,
      };
}

// ---------------------------------------------------------------------------
// Appointments
// ---------------------------------------------------------------------------

class ApiAppointment {
  final String? id;
  final String? doctorId;
  final String specialty;
  final String date;
  final String time;
  final String location;
  final String reason;
  final String status;

  ApiAppointment({
    this.id,
    this.doctorId,
    required this.specialty,
    required this.date,
    required this.time,
    required this.location,
    required this.reason,
    this.status = 'upcoming',
  });

  factory ApiAppointment.fromJson(Map<String, dynamic> json) => ApiAppointment(
        id: json['id'] as String?,
        doctorId: json['doctor_id'] as String?,
        specialty: json['specialty'] as String? ?? '',
        date: json['date'] as String? ?? '',
        time: json['time'] as String? ?? '',
        location: json['location'] as String? ?? '',
        reason: json['reason'] as String? ?? '',
        status: json['status'] as String? ?? 'upcoming',
      );

  Map<String, dynamic> toJson() => {
        'doctor_id': doctorId,
        'specialty': specialty,
        'date': date,
        'time': time,
        'location': location,
        'reason': reason,
        'status': status,
      };
}

// ---------------------------------------------------------------------------
// Health profile / medical record / AI summary
// ---------------------------------------------------------------------------

class ApiHealthProfile {
  final String dateOfBirth;
  final String bloodGroup;
  final String allergies;
  final String conditions;
  final String emergencyContactName;
  final String emergencyContactPhone;

  ApiHealthProfile({
    required this.dateOfBirth,
    required this.bloodGroup,
    required this.allergies,
    required this.conditions,
    required this.emergencyContactName,
    required this.emergencyContactPhone,
  });

  factory ApiHealthProfile.fromJson(Map<String, dynamic> json) => ApiHealthProfile(
        dateOfBirth: json['date_of_birth'] as String? ?? '',
        bloodGroup: json['blood_group'] as String? ?? '',
        allergies: json['allergies'] as String? ?? '',
        conditions: json['conditions'] as String? ?? '',
        emergencyContactName: json['emergency_contact_name'] as String? ?? '',
        emergencyContactPhone: json['emergency_contact_phone'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'date_of_birth': dateOfBirth,
        'blood_group': bloodGroup,
        'allergies': allergies,
        'conditions': conditions,
        'emergency_contact_name': emergencyContactName,
        'emergency_contact_phone': emergencyContactPhone,
      };
}

class MedicalRecord {
  final ApiHealthProfile? healthProfile;
  final List<ApiMedication> activeMedications;
  final List<ApiMedication> pastMedications;
  final List<ApiDoctor> doctors;
  final List<ApiDocument> recentDocuments;

  MedicalRecord({
    required this.healthProfile,
    required this.activeMedications,
    required this.pastMedications,
    required this.doctors,
    required this.recentDocuments,
  });

  factory MedicalRecord.fromJson(Map<String, dynamic> json) => MedicalRecord(
        healthProfile: json['health_profile'] != null
            ? ApiHealthProfile.fromJson(json['health_profile'] as Map<String, dynamic>)
            : null,
        activeMedications: (json['active_medications'] as List<dynamic>? ?? [])
            .map((m) => ApiMedication.fromJson(m as Map<String, dynamic>))
            .toList(),
        pastMedications: (json['past_medications'] as List<dynamic>? ?? [])
            .map((m) => ApiMedication.fromJson(m as Map<String, dynamic>))
            .toList(),
        doctors: (json['doctors'] as List<dynamic>? ?? [])
            .map((d) => ApiDoctor.fromJson(d as Map<String, dynamic>))
            .toList(),
        recentDocuments: (json['recent_documents'] as List<dynamic>? ?? [])
            .map((d) => ApiDocument.fromJson(d as Map<String, dynamic>))
            .toList(),
      );
}

class AiHealthSummary {
  final String currentSituation;
  final List<String> currentTreatments;
  final List<String> recentAnalyses;
  final List<String> upcomingAppointments;
  final List<String> importantInformation;
  final List<String> generalRecommendations;
  final String generatedNote;

  AiHealthSummary({
    required this.currentSituation,
    required this.currentTreatments,
    required this.recentAnalyses,
    required this.upcomingAppointments,
    required this.importantInformation,
    required this.generalRecommendations,
    required this.generatedNote,
  });

  factory AiHealthSummary.fromJson(Map<String, dynamic> json) => AiHealthSummary(
        currentSituation: json['current_situation'] as String? ?? '',
        currentTreatments:
            (json['current_treatments'] as List<dynamic>? ?? []).map((s) => s as String).toList(),
        recentAnalyses:
            (json['recent_analyses'] as List<dynamic>? ?? []).map((s) => s as String).toList(),
        upcomingAppointments:
            (json['upcoming_appointments'] as List<dynamic>? ?? []).map((s) => s as String).toList(),
        importantInformation:
            (json['important_information'] as List<dynamic>? ?? []).map((s) => s as String).toList(),
        generalRecommendations:
            (json['general_recommendations'] as List<dynamic>? ?? []).map((s) => s as String).toList(),
        generatedNote: json['generated_note'] as String? ?? '',
      );
}
