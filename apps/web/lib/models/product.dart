class Product {
  final int id;
  final String name;
  final String brand;
  final String category;
  final double price;
  final double? oldPrice;
  final String image;
  final String description;
  final double? rating;
  final int? sold;
  final int? stock;
  final String sku;
  final String currency;
  final String benefits;
  final String inciIngredients;
  final String keyIngredients;
  final List<String> skinTypes;
  final List<String> skinConcerns;
  final List<String> careGoals;
  final String texture;
  final String sourceUrl;
  final String usageInstruction;
  final String warnings;
  final DateTime? createdAt;

  Product({
    required this.id,
    required this.name,
    required this.brand,
    required this.category,
    required this.price,
    this.oldPrice,
    required this.image,
    required this.description,
    this.rating,
    this.sold,
    this.stock,
    this.sku = '',
    this.currency = 'VND',
    this.benefits = '',
    this.inciIngredients = '',
    this.keyIngredients = '',
    this.skinTypes = const [],
    this.skinConcerns = const [],
    this.careGoals = const [],
    this.texture = '',
    this.sourceUrl = '',
    this.usageInstruction = '',
    this.warnings = '',
    this.createdAt,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    List<String> stringList(String key) =>
        (json[key] as List<dynamic>? ?? const [])
            .map((value) => value.toString())
            .toList();

    return Product(
      id: (json['productId'] as num).toInt(),
      sku: json['sku']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      brand: json['brand']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0,
      oldPrice: (json['originalPrice'] as num?)?.toDouble(),
      rating: (json['rating'] as num?)?.toDouble(),
      sold: (json['soldCount'] as num?)?.toInt(),
      currency: json['currency']?.toString() ?? '',
      image: json['imageUrl']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      benefits: json['benefits']?.toString() ?? '',
      inciIngredients: json['inciIngredients']?.toString() ?? '',
      keyIngredients: json['keyIngredients']?.toString() ?? '',
      skinTypes: stringList('skinTypes'),
      skinConcerns: stringList('skinConcerns'),
      careGoals: stringList('careGoals'),
      texture: json['texture']?.toString() ?? '',
      sourceUrl: json['sourceUrl']?.toString() ?? '',
      usageInstruction: json['usageInstruction']?.toString() ?? '',
      warnings: json['warnings']?.toString() ?? '',
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
      stock: (json['stockQuantity'] as num?)?.toInt(),
    );
  }
}
