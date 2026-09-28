import 'package:flutter/foundation.dart';

import '../models/user_profile.dart';
import '../services/backend_api.dart';
import '../services/session_store_stub.dart'
    if (dart.library.html) '../services/session_store_web.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider(this._api, {SessionStore? sessionStore})
    : _sessionStore = sessionStore ?? SessionStore();

  final BackendApi _api;
  final SessionStore _sessionStore;

  String? _accessToken;
  UserProfile? _user;
  bool isLoading = false;
  bool isInitialized = false;
  String? errorMessage;

  String? get accessToken => _accessToken;
  UserProfile? get user => _user;
  bool get isAuthenticated => _accessToken != null && _user != null;
  bool get isAdmin => _user?.isAdmin ?? false;

  Future<void> restoreSession() async {
    if (isInitialized) return;
    final token = await _sessionStore.readToken();
    if (token != null && token.isNotEmpty) {
      try {
        _user = await _api.getProfile(token);
        _accessToken = token;
      } catch (_) {
        await _sessionStore.clearToken();
        _accessToken = null;
        _user = null;
      }
    }
    isInitialized = true;
    notifyListeners();
  }

  Future<bool> login({required String email, required String password}) async {
    return _authenticate(
      () => _api.login(email: email.trim(), password: password),
    );
  }

  Future<bool> register({
    required String fullName,
    required String email,
    required String password,
  }) async {
    return _authenticate(
      () => _api.register(
        fullName: fullName.trim(),
        email: email.trim(),
        password: password,
      ),
    );
  }

  Future<bool> _authenticate(Future<AuthSession> Function() request) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      final session = await request();
      _accessToken = session.accessToken;
      _user = session.user;
      await _sessionStore.writeToken(session.accessToken);
      return true;
    } catch (error) {
      errorMessage = BackendApi.readableError(error);
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void clearError() {
    errorMessage = null;
    notifyListeners();
  }

  Future<void> logout() async {
    _accessToken = null;
    _user = null;
    errorMessage = null;
    await _sessionStore.clearToken();
    notifyListeners();
  }
}
