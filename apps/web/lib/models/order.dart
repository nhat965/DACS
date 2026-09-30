class OrderItem {
  final int productId;
  final String productName;
  final int quantity;
  final double unitPrice;

  const OrderItem({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      productId: (json['productId'] as num).toInt(),
      productName: json['productName']?.toString() ?? '',
      quantity: (json['quantity'] as num).toInt(),
      unitPrice: (json['unitPrice'] as num).toDouble(),
    );
  }
}

class CustomerOrder {
  final int orderId;
  final int userId;
  final String status;
  final double totalAmount;
  final String currency;
  final String shippingName;
  final String shippingPhone;
  final String shippingAddress;
  final String paymentMethod;
  final String? note;
  final DateTime? createdAt;
  final List<OrderItem> items;

  const CustomerOrder({
    required this.orderId,
    required this.userId,
    required this.status,
    required this.totalAmount,
    required this.currency,
    required this.shippingName,
    required this.shippingPhone,
    required this.shippingAddress,
    required this.paymentMethod,
    this.note,
    required this.createdAt,
    required this.items,
  });

  factory CustomerOrder.fromJson(Map<String, dynamic> json) {
    return CustomerOrder(
      orderId: (json['orderId'] as num).toInt(),
      userId: (json['userId'] as num).toInt(),
      status: json['status']?.toString() ?? 'PENDING',
      totalAmount: (json['totalAmount'] as num).toDouble(),
      currency: json['currency']?.toString() ?? '',
      shippingName: json['shippingName']?.toString() ?? '',
      shippingPhone: json['shippingPhone']?.toString() ?? '',
      shippingAddress: json['shippingAddress']?.toString() ?? '',
      paymentMethod: json['paymentMethod']?.toString() ?? 'COD',
      note: json['note']?.toString(),
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
      items: (json['items'] as List<dynamic>? ?? const [])
          .map((item) => OrderItem.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}
