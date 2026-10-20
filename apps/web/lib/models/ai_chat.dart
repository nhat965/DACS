import 'product.dart';

class AiChatMessage {
  const AiChatMessage({
    required this.role,
    required this.text,
    this.recommendations = const [],
    this.followUpQuestions = const [],
    this.consultationType = 'general',
    this.routine = const [],
    this.cautions = const [],
    this.missingInformation = const [],
  });

  final String role;
  final String text;
  final List<AiChatRecommendation> recommendations;
  final List<String> followUpQuestions;
  final String consultationType;
  final List<AiRoutineStep> routine;
  final List<AiChatCaution> cautions;
  final List<String> missingInformation;

  bool get isUser => role == 'user';

  Map<String, dynamic> toHistoryJson() => {'role': role, 'content': text};
}

class AiRoutineStep {
  const AiRoutineStep({
    required this.order,
    required this.timeOfDay,
    required this.label,
    required this.instruction,
    required this.reason,
    this.productId,
    this.product,
  });

  final int order;
  final String timeOfDay;
  final String label;
  final int? productId;
  final Product? product;
  final String instruction;
  final String reason;

  factory AiRoutineStep.fromJson(Map<String, dynamic> json) {
    final productJson = json['product'];
    return AiRoutineStep(
      order: (json['order'] as num?)?.toInt() ?? 0,
      timeOfDay: json['timeOfDay']?.toString() ?? 'both',
      label: json['label']?.toString() ?? '',
      productId: (json['productId'] as num?)?.toInt(),
      product: productJson is Map<String, dynamic>
          ? Product.fromJson(productJson)
          : null,
      instruction: json['instruction']?.toString() ?? '',
      reason: json['reason']?.toString() ?? '',
    );
  }
}

class AiChatCaution {
  const AiChatCaution({
    required this.severity,
    required this.title,
    required this.detail,
  });

  final String severity;
  final String title;
  final String detail;

  factory AiChatCaution.fromJson(Map<String, dynamic> json) {
    return AiChatCaution(
      severity: json['severity']?.toString() ?? 'info',
      title: json['title']?.toString() ?? '',
      detail: json['detail']?.toString() ?? '',
    );
  }
}

class AiChatRecommendation {
  const AiChatRecommendation({
    required this.productId,
    required this.explanation,
    required this.product,
  });

  final int productId;
  final String explanation;
  final Product product;

  factory AiChatRecommendation.fromJson(Map<String, dynamic> json) {
    return AiChatRecommendation(
      productId: (json['productId'] as num).toInt(),
      explanation: json['explanation']?.toString() ?? '',
      product: Product.fromJson(json['product'] as Map<String, dynamic>),
    );
  }
}

class AiChatResponse {
  const AiChatResponse({
    required this.response,
    required this.recommendations,
    required this.followUpQuestions,
    required this.consultationType,
    required this.routine,
    required this.cautions,
    required this.missingInformation,
  });

  final String response;
  final List<AiChatRecommendation> recommendations;
  final List<String> followUpQuestions;
  final String consultationType;
  final List<AiRoutineStep> routine;
  final List<AiChatCaution> cautions;
  final List<String> missingInformation;

  factory AiChatResponse.fromJson(Map<String, dynamic> json) {
    return AiChatResponse(
      response: json['response']?.toString() ?? '',
      recommendations: (json['recommendations'] as List<dynamic>? ?? const [])
          .map(
            (item) =>
                AiChatRecommendation.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
      followUpQuestions:
          (json['followUpQuestions'] as List<dynamic>? ?? const [])
              .map((item) => item.toString())
              .toList(),
      consultationType: json['consultationType']?.toString() ?? 'general',
      routine: (json['routine'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(AiRoutineStep.fromJson)
          .toList(),
      cautions: (json['cautions'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(AiChatCaution.fromJson)
          .toList(),
      missingInformation:
          (json['missingInformation'] as List<dynamic>? ?? const [])
              .map((item) => item.toString())
              .toList(),
    );
  }
}
