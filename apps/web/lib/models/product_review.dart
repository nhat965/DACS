class ProductReview {
  const ProductReview({
    required this.reviewId,
    required this.productId,
    required this.userId,
    required this.authorName,
    required this.rating,
    required this.comment,
    required this.createdAt,
    required this.updatedAt,
    required this.isMine,
  });

  final int reviewId;
  final int productId;
  final int userId;
  final String authorName;
  final int rating;
  final String comment;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isMine;

  factory ProductReview.fromJson(Map<String, dynamic> json) => ProductReview(
    reviewId: (json['reviewId'] as num).toInt(),
    productId: (json['productId'] as num).toInt(),
    userId: (json['userId'] as num).toInt(),
    authorName: json['authorName']?.toString() ?? 'Khách hàng Lumi',
    rating: (json['rating'] as num).toInt(),
    comment: json['comment']?.toString() ?? '',
    createdAt: DateTime.parse(json['createdAt'].toString()),
    updatedAt: DateTime.parse(json['updatedAt'].toString()),
    isMine: json['isMine'] == true,
  );
}

class ProductReviewPage {
  const ProductReviewPage({
    required this.items,
    required this.total,
    required this.averageRating,
  });

  final List<ProductReview> items;
  final int total;
  final double? averageRating;

  factory ProductReviewPage.fromJson(Map<String, dynamic> json) =>
      ProductReviewPage(
        items: (json['items'] as List<dynamic>? ?? const [])
            .map((item) => ProductReview.fromJson(item as Map<String, dynamic>))
            .toList(),
        total: (json['total'] as num?)?.toInt() ?? 0,
        averageRating: (json['averageRating'] as num?)?.toDouble(),
      );
}
