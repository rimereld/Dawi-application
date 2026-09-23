import 'package:flutter/foundation.dart';

import '../models/api_models.dart';
import '../services/api_service.dart';
import '../services/token_storage.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

/// Holds the current user + auth token for the whole app. Call
/// [tryAutoLogin] once at startup (splash screen) to restore a saved
/// session before deciding whether to route to onboarding/login or home.
class AuthProvider extends ChangeNotifier {
  AuthStatus status = AuthStatus.unknown;
  ApiUser? user;
  String? errorMessage;
  bool isLoading = false;

  Future<void> tryAutoLogin() async {
    final token = await tokenStorage.readToken();
    if (token == null) {
      status = AuthStatus.unauthenticated;
      notifyListeners();
      return;
    }
    apiService.setCachedToken(token);
    try {
      user = await apiService.getMe();
      status = AuthStatus.authenticated;
    } catch (_) {
      // Token expired/invalid — clear it and fall back to login.
      await tokenStorage.clearToken();
      apiService.setCachedToken(null);
      status = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      final result = await apiService.login(email: email, password: password);
      await tokenStorage.saveToken(result.accessToken);
      apiService.setCachedToken(result.accessToken);
      user = result.user;
      status = AuthStatus.authenticated;
      return true;
    } on ApiException catch (e) {
      errorMessage = e.message;
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String phone,
    required String preferredLanguage,
  }) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      final result = await apiService.register(
        email: email,
        password: password,
        firstName: firstName,
        lastName: lastName,
        phone: phone,
        preferredLanguage: preferredLanguage,
      );
      await tokenStorage.saveToken(result.accessToken);
      apiService.setCachedToken(result.accessToken);
      user = result.user;
      status = AuthStatus.authenticated;
      return true;
    } on ApiException catch (e) {
      errorMessage = e.message;
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await tokenStorage.clearToken();
    apiService.setCachedToken(null);
    user = null;
    status = AuthStatus.unauthenticated;
    notifyListeners();
  }
}
