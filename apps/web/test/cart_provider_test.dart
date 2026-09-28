import 'package:flutter_test/flutter_test.dart';
import 'package:lumi_beauty/models/product.dart';
import 'package:lumi_beauty/providers/cart_provider.dart';
import 'package:lumi_beauty/providers/recommendation_provider.dart';
import 'package:lumi_beauty/services/backend_api.dart';

class _TrackingBackendApi extends BackendApi {
  final List<String> events = [];

  @override
  Future<void> trackBehavior({
    required String eventType,
    required String sessionId,
    String? accessToken,
    int? productId,
    double? eventValue,
    Map<String, dynamic> metadata = const {},
  }) async {
    events.add(eventType);
  }
}

Product _product({
  required int id,
  required double price,
  required String currency,
  int? stock,
}) {
  return Product(
    id: id,
    name: 'Product $id',
    brand: 'Lumi',
    category: 'serum',
    price: price,
    image: '',
    description: '',
    currency: currency,
    stock: stock,
  );
}

void main() {
  test(
    'cart keeps one currency and computes authoritative request items',
    () async {
      final api = _TrackingBackendApi();
      final cart = CartProvider(RecommendationProvider(api));

      expect(
        cart.addProduct(
          _product(id: 1, price: 10, currency: 'USD', stock: 3),
          quantity: 2,
        ),
        isNull,
      );
      expect(cart.subtotal, 20);
      expect(cart.currency, 'USD');
      expect(cart.toOrderItems(), [
        {'productId': 1, 'quantity': 2},
      ]);

      final mismatch = cart.addProduct(
        _product(id: 2, price: 100000, currency: 'VND'),
      );
      expect(mismatch, contains('Không thể trộn'));
      expect(cart.lines, hasLength(1));

      await Future<void>.delayed(Duration.zero);
      expect(api.events, contains('add_to_cart'));
    },
  );

  test('cart enforces stock and tracks removal without blocking', () async {
    final api = _TrackingBackendApi();
    final cart = CartProvider(RecommendationProvider(api));
    final product = _product(id: 3, price: 12, currency: 'USD', stock: 1);

    expect(cart.addProduct(product), isNull);
    expect(cart.addProduct(product), contains('tồn kho'));
    cart.removeProduct(product.id);

    await Future<void>.delayed(Duration.zero);
    expect(cart.isEmpty, isTrue);
    expect(api.events, contains('remove_from_cart'));
  });
}
