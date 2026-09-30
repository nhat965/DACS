import 'order.dart';
import 'product.dart';

class AdminDashboardData {
  const AdminDashboardData({
    required this.totalProducts,
    required this.aiReadyProducts,
    required this.lowStockProducts,
    required this.users,
    required this.orders,
    required this.pendingOrders,
    required this.ordersToday,
    required this.recommendationRequests,
    required this.orderStatuses,
    required this.revenueByCurrency,
  });

  final int totalProducts;
  final int aiReadyProducts;
  final int lowStockProducts;
  final int users;
  final int orders;
  final int pendingOrders;
  final int ordersToday;
  final int recommendationRequests;
  final Map<String, int> orderStatuses;
  final Map<String, double> revenueByCurrency;

  factory AdminDashboardData.fromJson(Map<String, dynamic> json) {
    return AdminDashboardData(
      totalProducts: (json['totalProducts'] as num?)?.toInt() ?? 0,
      aiReadyProducts: (json['aiReadyProducts'] as num?)?.toInt() ?? 0,
      lowStockProducts: (json['lowStockProducts'] as num?)?.toInt() ?? 0,
      users: (json['users'] as num?)?.toInt() ?? 0,
      orders: (json['orders'] as num?)?.toInt() ?? 0,
      pendingOrders: (json['pendingOrders'] as num?)?.toInt() ?? 0,
      ordersToday: (json['ordersToday'] as num?)?.toInt() ?? 0,
      recommendationRequests:
          (json['recommendationRequests'] as num?)?.toInt() ?? 0,
      orderStatuses: (json['orderStatuses'] as Map? ?? const {}).map(
        (key, value) => MapEntry(key.toString(), (value as num).toInt()),
      ),
      revenueByCurrency: (json['revenueByCurrency'] as Map? ?? const {}).map(
        (key, value) => MapEntry(key.toString(), (value as num).toDouble()),
      ),
    );
  }
}

class AdminProduct extends Product {
  AdminProduct({
    required super.id,
    required super.name,
    required super.brand,
    required super.category,
    required super.price,
    required super.image,
    required super.description,
    required super.stock,
    required super.sku,
    required super.currency,
    super.benefits,
    super.inciIngredients,
    super.keyIngredients,
    super.skinTypes,
    super.skinConcerns,
    super.careGoals,
    super.texture,
    super.sourceUrl,
    super.usageInstruction,
    super.warnings,
    required this.status,
    required this.aiReady,
    this.createdAt,
    this.updatedAt,
  });

  final String status;
  final bool aiReady;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory AdminProduct.fromJson(Map<String, dynamic> json) {
    final base = Product.fromJson(json);
    return AdminProduct(
      id: base.id,
      name: base.name,
      brand: base.brand,
      category: base.category,
      price: base.price,
      image: base.image,
      description: base.description,
      stock: base.stock ?? 0,
      sku: base.sku,
      currency: base.currency,
      benefits: base.benefits,
      inciIngredients: base.inciIngredients,
      keyIngredients: base.keyIngredients,
      skinTypes: base.skinTypes,
      skinConcerns: base.skinConcerns,
      careGoals: base.careGoals,
      texture: base.texture,
      sourceUrl: base.sourceUrl,
      usageInstruction: base.usageInstruction,
      warnings: base.warnings,
      status: json['status']?.toString() ?? 'DRAFT',
      aiReady: json['aiReady'] == true,
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? ''),
    );
  }

  Map<String, dynamic> toAdminJson() => {
    'sku': sku,
    'name': name,
    'brand': brand,
    'category': category,
    'price': price,
    'currency': currency,
    'stockQuantity': stock ?? 0,
    'status': status,
    'aiReady': aiReady,
    'description': description,
    'benefits': benefits,
    'inciIngredients': inciIngredients,
    'keyIngredients': keyIngredients,
    'skinTypes': skinTypes,
    'skinConcerns': skinConcerns,
    'careGoals': careGoals,
    'texture': texture,
    'usageInstruction': usageInstruction,
    'warnings': warnings,
    'imageUrl': image,
    'sourceUrl': sourceUrl,
  };
}

class AdminProductPage {
  const AdminProductPage({
    required this.items,
    required this.total,
    required this.limit,
    required this.offset,
  });

  final List<AdminProduct> items;
  final int total;
  final int limit;
  final int offset;
}

class AdminUser {
  const AdminUser({
    required this.userId,
    required this.fullName,
    required this.email,
    required this.role,
    required this.orderCount,
    this.skinType,
    this.createdAt,
    this.preferences = const {},
    this.orders = const [],
  });

  final int userId;
  final String fullName;
  final String email;
  final String role;
  final int orderCount;
  final String? skinType;
  final DateTime? createdAt;
  final Map<String, dynamic> preferences;
  final List<CustomerOrder> orders;

  factory AdminUser.fromJson(Map<String, dynamic> json) => AdminUser(
    userId: (json['userId'] as num).toInt(),
    fullName: json['fullName']?.toString() ?? '',
    email: json['email']?.toString() ?? '',
    role: json['role']?.toString() ?? 'CUSTOMER',
    orderCount: (json['orderCount'] as num?)?.toInt() ?? 0,
    skinType: json['skinType']?.toString(),
    createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
    preferences: Map<String, dynamic>.from(
      json['preferences'] as Map? ?? const {},
    ),
    orders: (json['orders'] as List<dynamic>? ?? const [])
        .map((item) => CustomerOrder.fromJson(item as Map<String, dynamic>))
        .toList(),
  );
}
