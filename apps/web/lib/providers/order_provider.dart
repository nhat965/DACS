import 'package:flutter/foundation.dart';

import '../models/order.dart';
import '../services/backend_api.dart';
import 'auth_provider.dart';
import 'cart_provider.dart';

class OrderProvider extends ChangeNotifier {
  OrderProvider(this._api, this._auth);

  final BackendApi _api;
  final AuthProvider _auth;

  bool isLoading = false;
  String? errorMessage;
  CustomerOrder? latestOrder;
  List<CustomerOrder> orders = const [];

  Future<bool> placeOrder({
    required CartProvider cart,
    required String shippingName,
    required String shippingPhone,
    required String shippingAddress,
    String? note,
    String paymentMethod = 'COD',
  }) async {
    final token = _auth.accessToken;
    final currency = cart.currency;
    if (token == null || currency == null || cart.isEmpty) {
      errorMessage = 'Bạn cần đăng nhập và có sản phẩm trong giỏ hàng.';
      notifyListeners();
      return false;
    }
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      latestOrder = await _api.createOrder(
        accessToken: token,
        items: cart.toOrderItems(),
        currency: currency,
        shippingName: shippingName,
        shippingPhone: shippingPhone,
        shippingAddress: shippingAddress,
        note: note,
        paymentMethod: paymentMethod,
      );
      orders = [latestOrder!, ...orders];
      cart.clear();
      return true;
    } catch (error) {
      errorMessage = BackendApi.readableError(error);
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadOrders({bool admin = false}) async {
    final token = _auth.accessToken;
    if (token == null) return;
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      orders = await _api.getOrders(accessToken: token, admin: admin);
    } catch (error) {
      errorMessage = BackendApi.readableError(error);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
