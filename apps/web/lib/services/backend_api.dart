import 'package:dio/dio.dart';

import '../config/app_config.dart';
import '../models/product.dart';
import '../models/beauty_preferences.dart';
import '../models/recommendation.dart';
import '../models/order.dart';
import '../models/user_profile.dart';

class BackendApi {
  BackendApi({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: AppConfig.apiBaseUrl,
              connectTimeout: const Duration(seconds: 8),
              receiveTimeout: const Duration(seconds: 12),
              headers: const {'Accept': 'application/json'},
            ),
          );

  final Dio _dio;

  Future<List<Product>> getProducts({
    String? search,
    String? category,
    String? brand,
    int limit = 100,
    int offset = 0,
  }) async {
    final page = await getProductPage(
      search: search,
      category: category,
      brand: brand,
      limit: limit,
      offset: offset,
    );
    return page.items;
  }

  Future<ProductPage> getProductPage({
    String? search,
    String? category,
    String? brand,
    double? priceMin,
    double? priceMax,
    String sort = 'name_asc',
    int limit = 24,
    int offset = 0,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/products',
      queryParameters: {
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
        if (category != null && category.trim().isNotEmpty)
          'category': category.trim(),
        if (brand != null && brand.trim().isNotEmpty) 'brand': brand.trim(),
        'priceMin': ?priceMin,
        'priceMax': ?priceMax,
        'sort': sort,
        'limit': limit,
        'offset': offset,
      },
    );
    final items = response.data?['items'] as List<dynamic>? ?? const [];
    return ProductPage(
      items: items
          .map((item) => Product.fromJson(item as Map<String, dynamic>))
          .toList(),
      total: (response.data?['total'] as num?)?.toInt() ?? 0,
      limit: (response.data?['limit'] as num?)?.toInt() ?? limit,
      offset: (response.data?['offset'] as num?)?.toInt() ?? offset,
    );
  }

  Future<Product> getProduct(int productId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/products/$productId',
    );
    return Product.fromJson(response.data ?? const {});
  }

  Future<AuthSession> register({
    required String fullName,
    required String email,
    required String password,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/auth/register',
      data: {'fullName': fullName, 'email': email, 'password': password},
    );
    return AuthSession.fromJson(response.data ?? const {});
  }

  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/auth/login',
      data: {'email': email, 'password': password},
    );
    return AuthSession.fromJson(response.data ?? const {});
  }

  Future<UserProfile> getProfile(String accessToken) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/auth/profile',
      options: _authorized(accessToken),
    );
    return UserProfile.fromJson(response.data ?? const {});
  }

  Future<BeautyPreferences> getPreferences(String accessToken) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/users/me/preferences',
      options: _authorized(accessToken),
    );
    return BeautyPreferences.fromJson(response.data ?? const {});
  }

  Future<BeautyPreferences> savePreferences({
    required String accessToken,
    required BeautyPreferences preferences,
  }) async {
    final response = await _dio.put<Map<String, dynamic>>(
      '/users/me/preferences',
      options: _authorized(accessToken),
      data: preferences.toJson(),
    );
    return BeautyPreferences.fromJson(response.data ?? const {});
  }

  Future<CustomerOrder> createOrder({
    required String accessToken,
    required List<Map<String, int>> items,
    required String currency,
    required String shippingName,
    required String shippingPhone,
    required String shippingAddress,
    String? note,
    String paymentMethod = 'COD',
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/orders',
      options: _authorized(accessToken),
      data: {
        'items': items,
        'currency': currency,
        'shippingName': shippingName,
        'shippingPhone': shippingPhone,
        'shippingAddress': shippingAddress,
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
        'paymentMethod': paymentMethod,
      },
    );
    return CustomerOrder.fromJson(response.data ?? const {});
  }

  Future<List<CustomerOrder>> getOrders({
    required String accessToken,
    bool admin = false,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      admin ? '/admin/orders' : '/orders',
      options: _authorized(accessToken),
    );
    final items = response.data?['items'] as List<dynamic>? ?? const [];
    return items
        .map((item) => CustomerOrder.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<Map<String, int>> getAdminMetrics(String accessToken) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/admin/metrics',
      options: _authorized(accessToken),
    );
    return (response.data ?? const {}).map(
      (key, value) => MapEntry(key, (value as num).toInt()),
    );
  }

  Future<RecommendationResult> getPersonalizedRecommendations({
    required String sessionId,
    String? accessToken,
    int limit = 8,
    Map<String, dynamic> context = const {},
    List<int> excludeProductIds = const [],
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/recommendations/personalized',
      options: accessToken == null ? null : _authorized(accessToken),
      data: {
        'sessionId': sessionId,
        'limit': limit,
        'context': context,
        'excludeProductIds': excludeProductIds,
      },
    );
    return RecommendationResult.fromJson(response.data ?? const {});
  }

  Future<RecommendationResult> getSimilarProducts(
    int productId, {
    int limit = 6,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/recommendations/similar-products/$productId',
      queryParameters: {'limit': limit},
    );
    return RecommendationResult.fromJson(response.data ?? const {});
  }

  Future<RecommendedProduct> explainRecommendation({
    required int productId,
    required String sessionId,
    String? accessToken,
    Map<String, dynamic> context = const {},
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/recommendations/explain',
      options: accessToken == null ? null : _authorized(accessToken),
      data: {
        'productId': productId,
        'sessionId': sessionId,
        'context': context,
      },
    );
    return RecommendedProduct.fromJson(response.data ?? const {});
  }

  Future<void> trackBehavior({
    required String eventType,
    required String sessionId,
    String? accessToken,
    int? productId,
    double? eventValue,
    Map<String, dynamic> metadata = const {},
  }) async {
    final data = <String, dynamic>{
      'eventType': eventType,
      'sessionId': sessionId,
      'metadata': metadata,
      'occurredAt': DateTime.now().toUtc().toIso8601String(),
    };
    if (productId != null) {
      data['productId'] = productId;
    }
    if (eventValue != null) {
      data['eventValue'] = eventValue;
    }
    await _dio.post<void>(
      '/behavior-events',
      data: data,
      options: accessToken == null ? null : _authorized(accessToken),
    );
  }

  static String readableError(Object error) {
    if (error is DioException) {
      final status = error.response?.statusCode;
      final detail = error.response?.data is Map
          ? (error.response?.data as Map)['detail']
          : null;
      if (status == 401) {
        return detail?.toString() ?? 'Phiên đăng nhập không hợp lệ.';
      }
      if (status == 403) return 'Bạn không có quyền thực hiện thao tác này.';
      if (status == 409) return detail?.toString() ?? 'Dữ liệu đã tồn tại.';
      if (status == 422 && detail is String) return detail;
      if (status == 404) return 'Không tìm thấy dữ liệu yêu cầu.';
      if (status == 503) return 'Dịch vụ backend đang tạm thời chưa sẵn sàng.';
      if (detail is String && detail.isNotEmpty) return detail;
      if (error.type == DioExceptionType.connectionError ||
          error.type == DioExceptionType.connectionTimeout) {
        return 'Không thể kết nối backend tại ${AppConfig.apiBaseUrl}.';
      }
    }
    return 'Đã xảy ra lỗi khi tải dữ liệu. Vui lòng thử lại.';
  }

  Options _authorized(String accessToken) =>
      Options(headers: {'Authorization': 'Bearer $accessToken'});
}

class ProductPage {
  const ProductPage({
    required this.items,
    required this.total,
    required this.limit,
    required this.offset,
  });

  final List<Product> items;
  final int total;
  final int limit;
  final int offset;

  bool get hasNext => offset + items.length < total;
}
