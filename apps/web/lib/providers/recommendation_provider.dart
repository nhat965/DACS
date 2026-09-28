import 'package:flutter/foundation.dart';

import '../models/recommendation.dart';
import '../services/backend_api.dart';
import 'auth_provider.dart';

class RecommendationProvider extends ChangeNotifier {
  RecommendationProvider(this._api, [this._auth])
    : sessionId = 'lumi-${DateTime.now().microsecondsSinceEpoch}';

  final BackendApi _api;
  final AuthProvider? _auth;
  final String sessionId;

  bool isLoading = false;
  String? errorMessage;
  RecommendationResult? similarResult;
  RecommendationResult? personalizedResult;

  Future<void> loadSimilarProducts(int productId) async {
    isLoading = true;
    errorMessage = null;
    similarResult = null;
    notifyListeners();
    try {
      similarResult = await _api.getSimilarProducts(productId);
    } catch (error) {
      errorMessage = BackendApi.readableError(error);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadPersonalized({
    Map<String, dynamic> context = const {},
  }) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      personalizedResult = await _api.getPersonalizedRecommendations(
        sessionId: sessionId,
        accessToken: _auth?.accessToken,
        context: context,
      );
    } catch (error) {
      errorMessage = BackendApi.readableError(error);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> track({
    required String eventType,
    int? productId,
    double? eventValue,
    Map<String, dynamic> metadata = const {},
  }) async {
    try {
      await _api.trackBehavior(
        eventType: eventType,
        sessionId: sessionId,
        accessToken: _auth?.accessToken,
        productId: productId,
        eventValue: eventValue,
        metadata: metadata,
      );
    } catch (_) {
      // Tracking must never block the shopping flow. The backend returns 503
      // intentionally when database persistence is disabled in local mode.
    }
  }
}
