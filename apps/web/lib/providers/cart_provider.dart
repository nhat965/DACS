import 'package:flutter/foundation.dart';

import '../models/product.dart';
import 'recommendation_provider.dart';

class CartLine {
  final Product product;
  final int quantity;

  const CartLine({required this.product, required this.quantity});

  double get lineTotal => product.price * quantity;

  CartLine copyWith({int? quantity}) =>
      CartLine(product: product, quantity: quantity ?? this.quantity);
}

class CartProvider extends ChangeNotifier {
  CartProvider(this._tracking);

  final RecommendationProvider _tracking;
  final Map<int, CartLine> _lines = {};

  List<CartLine> get lines => List.unmodifiable(_lines.values);
  bool get isEmpty => _lines.isEmpty;
  int get itemCount =>
      _lines.values.fold(0, (sum, line) => sum + line.quantity);
  double get subtotal =>
      _lines.values.fold(0, (sum, line) => sum + line.lineTotal);
  String? get currency =>
      _lines.isEmpty ? null : _lines.values.first.product.currency;

  String? addProduct(Product product, {int quantity = 1}) {
    if (product.currency.isEmpty) {
      return 'Sản phẩm chưa có đơn vị tiền tệ hợp lệ.';
    }
    if (currency != null && currency != product.currency) {
      return 'Không thể trộn sản phẩm $currency và ${product.currency} trong cùng đơn hàng.';
    }
    final current = _lines[product.id]?.quantity ?? 0;
    final next = current + quantity;
    if (product.stock != null && next > product.stock!) {
      return 'Số lượng vượt quá tồn kho hiện có.';
    }
    _lines[product.id] = CartLine(product: product, quantity: next);
    _tracking.track(
      eventType: 'add_to_cart',
      productId: product.id,
      eventValue: quantity.toDouble(),
      metadata: {'quantity': quantity},
    );
    notifyListeners();
    return null;
  }

  String? setQuantity(int productId, int quantity) {
    final line = _lines[productId];
    if (line == null) return null;
    if (quantity <= 0) {
      removeProduct(productId);
      return null;
    }
    if (line.product.stock != null && quantity > line.product.stock!) {
      return 'Số lượng vượt quá tồn kho hiện có.';
    }
    _lines[productId] = line.copyWith(quantity: quantity);
    notifyListeners();
    return null;
  }

  void removeProduct(int productId) {
    final removed = _lines.remove(productId);
    if (removed == null) return;
    _tracking.track(
      eventType: 'remove_from_cart',
      productId: productId,
      eventValue: removed.quantity.toDouble(),
    );
    notifyListeners();
  }

  List<Map<String, int>> toOrderItems() => _lines.values
      .map((line) => {'productId': line.product.id, 'quantity': line.quantity})
      .toList();

  void clear() {
    _lines.clear();
    notifyListeners();
  }
}
