import 'package:flutter/foundation.dart';

import '../models/ai_chat.dart';
import '../services/backend_api.dart';
import 'auth_provider.dart';
import 'recommendation_provider.dart';

class AiChatProvider extends ChangeNotifier {
  AiChatProvider(this._api, this._auth, this._recommendations);

  final BackendApi _api;
  final AuthProvider _auth;
  final RecommendationProvider _recommendations;

  final List<AiChatMessage> _messages = [
    const AiChatMessage(
      role: 'assistant',
      text: 'Chào bạn, mình là Lumi AI. Hãy chia sẻ loại da, điều bạn đang lo lắng hoặc ngân sách để mình tư vấn từ sản phẩm có thật trong cửa hàng.',
    ),
  ];

  List<AiChatMessage> get messages => List.unmodifiable(_messages);
  bool isLoading = false;
  String? errorMessage;

  Future<void> send(String rawMessage) async {
    final message = rawMessage.trim();
    if (message.isEmpty || isLoading) return;
    final history = _messages.skip(1).toList();
    _messages.add(AiChatMessage(role: 'user', text: message));
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    await _recommendations.track(
      eventType: 'chatbot_message',
      metadata: {'messageLength': message.length},
    );

    try {
      final result = await _api.sendChatMessage(
        message: message,
        history: history.length <= 10
            ? history
            : history.sublist(history.length - 10),
        sessionId: _recommendations.sessionId,
        accessToken: _auth.accessToken,
      );
      _messages.add(
        AiChatMessage(
          role: 'assistant',
          text: result.response,
          recommendations: result.recommendations,
          followUpQuestions: result.followUpQuestions,
          consultationType: result.consultationType,
          routine: result.routine,
          cautions: result.cautions,
          missingInformation: result.missingInformation,
        ),
      );
    } catch (error) {
      errorMessage = BackendApi.readableError(error);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void clearError() {
    errorMessage = null;
    notifyListeners();
  }
}
