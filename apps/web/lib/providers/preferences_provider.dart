import 'package:flutter/foundation.dart';

import '../models/beauty_preferences.dart';
import '../services/backend_api.dart';
import 'auth_provider.dart';

class PreferencesProvider extends ChangeNotifier {
  PreferencesProvider(this._api, this._auth);

  final BackendApi _api;
  final AuthProvider _auth;

  BeautyPreferences? preferences;
  bool isLoading = false;
  String? errorMessage;

  bool get isComplete => preferences?.completed ?? false;

  Future<void> load() async {
    final token = _auth.accessToken;
    if (token == null) return;
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      preferences = await _api.getPreferences(token);
    } catch (error) {
      errorMessage = BackendApi.readableError(error);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> save(BeautyPreferences value) async {
    final token = _auth.accessToken;
    if (token == null) return false;
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      preferences = await _api.savePreferences(
        accessToken: token,
        preferences: value,
      );
      return true;
    } catch (error) {
      errorMessage = BackendApi.readableError(error);
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
