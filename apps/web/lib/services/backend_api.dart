import 'package:dio/dio.dart';

import '../config/app_config.dart';
import '../models/product.dart';
import '../models/product_review.dart';
import '../models/beauty_preferences.dart';
import '../models/recommendation.dart';
import '../models/order.dart';
import '../models/user_profile.dart';
import '../models/admin_models.dart';

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
    String? concern,
    String? goal,
    int limit = 100,
    int offset = 0,
  }) async {
    final page = await getProductPage(
      search: search,
      category: category,
      brand: brand,
      concern: concern,
      goal: goal,
      limit: limit,
      offset: offset,
    );
    return page.items;
  }

  Future<ProductPage> getProductPage({
    String? search,
    String? category,
    String? brand,
    String? concern,
    String? goal,
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
        if (concern != null && concern.trim().isNotEmpty)
          'concern': concern.trim(),
        if (goal != null && goal.trim().isNotEmpty) 'goal': goal.trim(),
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

  Future<List<Product>> getActivePromotions() async {
    final response = await _dio.get<Map<String, dynamic>>('/promotions/active');
    return (response.data?['items'] as List<dynamic>? ?? const [])
        .map((item) => Product.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<ProductReviewPage> getProductReviews({
    required int productId,
    String? accessToken,
    int limit = 20,
    int offset = 0,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/products/$productId/reviews',
      queryParameters: {'limit': limit, 'offset': offset},
      options: accessToken == null ? null : _authorized(accessToken),
    );
    return ProductReviewPage.fromJson(response.data ?? const {});
  }

  Future<ProductReview> saveProductReview({
    required int productId,
    required String accessToken,
    required int rating,
    required String comment,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/products/$productId/reviews',
      options: _authorized(accessToken),
      data: {'rating': rating, 'comment': comment.trim()},
    );
    return ProductReview.fromJson(response.data ?? const {});
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

  Future<PasswordResetRequestResult> requestPasswordReset(String email) async {
    // The contract is intentionally explicit until reset-token delivery exists.
    // No success is simulated and no user email is disclosed.
    return PasswordResetRequestResult.notAvailable;
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

  Future<AdminDashboardData> getAdminDashboard(String accessToken) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/admin/dashboard',
      options: _authorized(accessToken),
    );
    return AdminDashboardData.fromJson(response.data ?? const {});
  }

  Future<Map<String, int>> getAdminDataQuality(String accessToken) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/admin/data-quality',
      options: _authorized(accessToken),
    );
    return (response.data ?? const {}).map(
      (key, value) => MapEntry(key, (value as num).toInt()),
    );
  }

  Future<Map<String, dynamic>> getAdminReports(String accessToken) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/admin/reports',
      options: _authorized(accessToken),
    );
    return response.data ?? const {};
  }

  Future<Map<String, dynamic>> getAdminBehaviorAnalytics(String accessToken) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/admin/behavior-analytics',
      options: _authorized(accessToken),
    );
    return response.data ?? const {};
  }

  Future<Map<String, dynamic>> getAdminRecommendationAnalytics(
    String accessToken,
  ) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/admin/recommendation-analytics',
      options: _authorized(accessToken),
    );
    return response.data ?? const {};
  }

  Future<AdminProductPage> getAdminProducts({
    required String accessToken,
    String? search,
    String? status,
    int limit = 25,
    int offset = 0,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/admin/products',
      options: _authorized(accessToken),
      queryParameters: {
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
        if (status != null && status.isNotEmpty) 'status': status,
        'limit': limit,
        'offset': offset,
      },
    );
    final data = response.data ?? const {};
    return AdminProductPage(
      items: (data['items'] as List<dynamic>? ?? const [])
          .map((item) => AdminProduct.fromJson(item as Map<String, dynamic>))
          .toList(),
      total: (data['total'] as num?)?.toInt() ?? 0,
      limit: (data['limit'] as num?)?.toInt() ?? limit,
      offset: (data['offset'] as num?)?.toInt() ?? offset,
    );
  }

  Future<AdminProduct> getAdminProduct({
    required String accessToken,
    required int productId,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/admin/products/$productId',
      options: _authorized(accessToken),
    );
    return AdminProduct.fromJson(response.data ?? const {});
  }

  Future<AdminProduct> saveAdminProduct({
    required String accessToken,
    required Map<String, dynamic> data,
    int? productId,
  }) async {
    final response = productId == null
        ? await _dio.post<Map<String, dynamic>>(
            '/admin/products',
            data: data,
            options: _authorized(accessToken),
          )
        : await _dio.put<Map<String, dynamic>>(
            '/admin/products/$productId',
            data: data,
            options: _authorized(accessToken),
          );
    return AdminProduct.fromJson(response.data ?? const {});
  }

  Future<AdminProduct> updateAdminProductStatus({
    required String accessToken,
    required int productId,
    required String status,
  }) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      '/admin/products/$productId/status',
      data: {'status': status},
      options: _authorized(accessToken),
    );
    return AdminProduct.fromJson(response.data ?? const {});
  }

  Future<AdminProduct> updateAdminProductStock({
    required String accessToken,
    required int productId,
    required int stockQuantity,
  }) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      '/admin/products/$productId/stock',
      data: {'stockQuantity': stockQuantity},
      options: _authorized(accessToken),
    );
    return AdminProduct.fromJson(response.data ?? const {});
  }

  Future<List<AdminProduct>> getAdminInventory({
    required String accessToken,
    String? state,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/admin/inventory',
      queryParameters: {'state': ?state},
      options: _authorized(accessToken),
    );
    return (response.data?['items'] as List<dynamic>? ?? const [])
        .map((item) => AdminProduct.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<CustomerOrder> getAdminOrder({
    required String accessToken,
    required int orderId,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/admin/orders/$orderId',
      options: _authorized(accessToken),
    );
    return CustomerOrder.fromJson(response.data ?? const {});
  }

  Future<CustomerOrder> updateAdminOrderStatus({
    required String accessToken,
    required int orderId,
    required String status,
  }) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      '/admin/orders/$orderId/status',
      data: {'status': status},
      options: _authorized(accessToken),
    );
    return CustomerOrder.fromJson(response.data ?? const {});
  }

  Future<List<AdminUser>> getAdminUsers({
    required String accessToken,
    String? search,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/admin/users',
      queryParameters: {
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      },
      options: _authorized(accessToken),
    );
    return (response.data?['items'] as List<dynamic>? ?? const [])
        .map((item) => AdminUser.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<AdminUser> getAdminUser({
    required String accessToken,
    required int userId,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/admin/users/$userId',
      options: _authorized(accessToken),
    );
    return AdminUser.fromJson(response.data ?? const {});
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
      if (status == 503) {
        return 'Lumi đang tạm thời chưa sẵn sàng. Vui lòng thử lại sau.';
      }
      if (detail is String && detail.isNotEmpty) return detail;
      if (error.type == DioExceptionType.connectionError ||
          error.type == DioExceptionType.connectionTimeout) {
        return 'Không thể tải dữ liệu lúc này. Vui lòng kiểm tra kết nối và thử lại.';
      }
    }
    return 'Đã xảy ra lỗi khi tải dữ liệu. Vui lòng thử lại.';
  }

  Options _authorized(String accessToken) =>
      Options(headers: {'Authorization': 'Bearer $accessToken'});
}

enum PasswordResetRequestResult { notAvailable }

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
