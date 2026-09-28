import 'package:flutter/foundation.dart';

import '../models/product.dart';
import '../services/backend_api.dart';

class CatalogProvider extends ChangeNotifier {
  CatalogProvider(this._api);

  final BackendApi _api;
  final Map<int, Product> _productsById = {};

  bool isLoading = false;
  String? errorMessage;

  List<Product> get products => List.unmodifiable(_productsById.values);

  Product? productById(int id) => _productsById[id];

  Future<void> loadProducts({bool force = false}) async {
    if (isLoading || (_productsById.isNotEmpty && !force)) return;
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      final result = await _api.getProducts();
      _productsById
        ..clear()
        ..addEntries(result.map((product) => MapEntry(product.id, product)));
    } catch (error) {
      errorMessage = BackendApi.readableError(error);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<Product?> loadProduct(int id) async {
    final cached = _productsById[id];
    if (cached != null) return cached;
    try {
      final product = await _api.getProduct(id);
      _productsById[id] = product;
      notifyListeners();
      return product;
    } catch (error) {
      errorMessage = BackendApi.readableError(error);
      notifyListeners();
      return null;
    }
  }
}
