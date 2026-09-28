class RecommendedProduct {
  final int productId;
  final double score;
  final List<String> reasons;
  final String status;
  final Map<String, double> scoreBreakdown;

  const RecommendedProduct({
    required this.productId,
    required this.score,
    required this.reasons,
    required this.status,
    required this.scoreBreakdown,
  });

  factory RecommendedProduct.fromJson(Map<String, dynamic> json) {
    final breakdown =
        json['scoreBreakdown'] as Map<String, dynamic>? ?? const {};
    return RecommendedProduct(
      productId: (json['productId'] as num).toInt(),
      score: (json['score'] as num?)?.toDouble() ?? 0,
      reasons: (json['reasons'] as List<dynamic>? ?? const [])
          .map((reason) => reason.toString())
          .toList(),
      status: json['status']?.toString() ?? 'RANKED',
      scoreBreakdown: breakdown.map(
        (key, value) => MapEntry(key, (value as num).toDouble()),
      ),
    );
  }
}

class RecommendationResult {
  final String algorithm;
  final List<RecommendedProduct> items;
  final int candidateCount;
  final int filteredCandidateCount;

  const RecommendationResult({
    required this.algorithm,
    required this.items,
    required this.candidateCount,
    required this.filteredCandidateCount,
  });

  factory RecommendationResult.fromJson(Map<String, dynamic> json) {
    return RecommendationResult(
      algorithm: json['algorithm']?.toString() ?? 'unknown',
      items: (json['items'] as List<dynamic>? ?? const [])
          .map(
            (item) => RecommendedProduct.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
      candidateCount: (json['candidateCount'] as num?)?.toInt() ?? 0,
      filteredCandidateCount:
          (json['filteredCandidateCount'] as num?)?.toInt() ?? 0,
    );
  }
}
