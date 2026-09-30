import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';

import '../providers/auth_provider.dart';

import '../screens/customer/home_page.dart';
import '../screens/customer/category_page.dart';
import '../screens/customer/categories_page.dart';
import '../screens/customer/brands_page.dart';
import '../screens/customer/catalog_status_page.dart';
import '../screens/customer/sale_collection_page.dart';
import '../screens/customer/product_detail_page.dart';
import '../screens/customer/search_page.dart';
import '../screens/customer/cart_page.dart';
import '../screens/customer/checkout_page.dart';
import '../screens/customer/login_page.dart';
import '../screens/customer/register_page.dart';
import '../screens/customer/forgot_password_page.dart';
import '../screens/customer/profile_page.dart';
import '../screens/customer/onboarding_page.dart';
import '../screens/customer/order_lookup_page.dart';
import '../screens/customer/personalized_page.dart';

import '../screens/admin/admin_layout.dart';
import '../screens/admin/admin_placeholder_page.dart';
import '../screens/admin/catalog_insights_pages.dart';
import '../screens/admin/dashboard_page.dart';
import '../screens/admin/inventory_page.dart';
import '../screens/admin/order_detail_page.dart';
import '../screens/admin/orders_page.dart';
import '../screens/admin/product_pages.dart';
import '../screens/admin/products_page.dart';
import '../screens/admin/users_page.dart';

Widget _adminShell(GoRouterState state, String title, Widget child) =>
    AdminLayout(currentPath: state.uri.path, title: title, child: child);

GoRoute _appRoute({
  required String path,
  required Widget Function(BuildContext, GoRouterState) builder,
}) => GoRoute(
  path: path,
  pageBuilder: (context, state) {
    final child = builder(context, state);
    return CustomTransitionPage<void>(
      key: state.pageKey,
      transitionDuration: const Duration(milliseconds: 240),
      reverseTransitionDuration: const Duration(milliseconds: 180),
      child: child,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        if (MediaQuery.disableAnimationsOf(context)) return child;
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.015),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
    );
  },
);

GoRouter createAppRouter(AuthProvider auth) => GoRouter(
  initialLocation: '/',
  refreshListenable: auth,
  redirect: (context, state) {
    if (!auth.isInitialized) return null;
    final path = state.uri.path;
    final isAuthPage =
        path == '/login' || path == '/register' || path == '/forgot-password';
    final needsCustomer =
        path == '/checkout' ||
        path == '/profile' ||
        path == '/onboarding' ||
        path == '/order-lookup' ||
        path == '/recommendations';
    final needsAdmin = path.startsWith('/admin');

    if ((needsCustomer || needsAdmin) && !auth.isAuthenticated) {
      final encoded = Uri.encodeComponent(state.uri.toString());
      return '/login?redirect=$encoded';
    }
    if (needsAdmin && !auth.isAdmin) return '/';
    if (isAuthPage && auth.isAuthenticated) {
      return auth.isAdmin ? '/admin' : '/';
    }
    return null;
  },
  errorBuilder: (context, state) => Scaffold(
    appBar: AppBar(title: const Text('Không tìm thấy trang')),
    body: Center(
      child: Text(state.error?.toString() ?? 'Đường dẫn không hợp lệ.'),
    ),
  ),

  routes: [
    // =========================
    // WEBSITE KHÁCH HÀNG
    // =========================

    _appRoute(path: '/', builder: (context, state) => const HomePage()),

    _appRoute(
      path: '/categories',
      builder: (context, state) => const CategoriesPage(),
    ),

    _appRoute(
      path: '/category/:id',
      builder: (context, state) {
        final category = state.pathParameters['id']!;
        return CategoryPage(category: category);
      },
    ),

    _appRoute(path: '/brands', builder: (context, state) => const BrandsPage()),

    _appRoute(
      path: '/brand/:slug',
      builder: (context, state) => CategoryPage(
        category: 'brand:${Uri.decodeComponent(state.pathParameters['slug']!)}',
      ),
    ),

    _appRoute(
      path: '/new-arrivals',
      builder: (_, _) => const CatalogStatusPage(
        title: 'Hàng mới về',
        message: 'Những sản phẩm mới nhất của Lumi đang được tuyển chọn và sẽ sớm xuất hiện tại đây.',
        icon: Icons.auto_awesome_outlined,
      ),
    ),
    _appRoute(
      path: '/gifts',
      builder: (_, _) => const CatalogStatusPage(
        title: 'Quà tặng từ Lumi',
        message:
            'Các bộ quà tặng dành cho những dịp đặc biệt đang được chuẩn bị.',
        icon: Icons.card_giftcard_outlined,
      ),
    ),
    _appRoute(
      path: '/blog',
      builder: (_, _) => const CatalogStatusPage(
        title: 'Blog làm đẹp',
        message: 'Cẩm nang chăm sóc da và làm đẹp từ Lumi sẽ sớm ra mắt.',
        icon: Icons.auto_stories_outlined,
      ),
    ),
    _appRoute(
      path: '/outlet',
      builder: (_, _) => const SaleCollectionPage(title: 'Outlet - Giá tốt'),
    ),
    _appRoute(
      path: '/promotions',
      builder: (_, _) => const SaleCollectionPage(title: 'Khuyến mại'),
    ),
    _appRoute(
      path: '/flash-sale',
      builder: (_, _) => const SaleCollectionPage(title: 'Flash Sale'),
    ),
    _appRoute(
      path: '/stores',
      builder: (_, _) => const CatalogStatusPage(
        title: 'Hệ thống cửa hàng',
        message: 'Thông tin các điểm mua sắm Lumi đang được cập nhật.',
        icon: Icons.storefront_outlined,
      ),
    ),
    _appRoute(
      path: '/order-lookup',
      builder: (_, _) => const OrderLookupPage(),
    ),
    _appRoute(
      path: '/social/:network',
      builder: (_, state) => CatalogStatusPage(
        title: 'Lumi Beauty trên ${state.pathParameters['network']}',
        message: 'Kênh chính thức của Lumi đang được hoàn thiện.',
        icon: Icons.favorite_outline,
        actionLabel: 'Về trang chủ',
        actionRoute: '/',
      ),
    ),

    _appRoute(
      path: '/product/:id',
      builder: (context, state) {
        final id = int.tryParse(state.pathParameters['id'] ?? '');

        return id == null
            ? const Scaffold(
                body: Center(child: Text('Mã sản phẩm không hợp lệ.')),
              )
            : ProductDetailPage(productId: id);
      },
    ),

    _appRoute(
      path: '/search',
      builder: (context, state) => SearchPage(
        initialQuery: state.uri.queryParameters['q'] ?? '',
        initialConcern: state.uri.queryParameters['concern'],
        initialGoal: state.uri.queryParameters['goal'],
      ),
    ),

    _appRoute(path: '/cart', builder: (context, state) => const CartPage()),

    _appRoute(
      path: '/checkout',
      builder: (context, state) => const CheckoutPage(),
    ),

    _appRoute(
      path: '/login',
      builder: (context, state) =>
          LoginPage(redirectPath: state.uri.queryParameters['redirect']),
    ),

    _appRoute(
      path: '/register',
      builder: (context, state) => const RegisterPage(),
    ),

    _appRoute(
      path: '/forgot-password',
      builder: (context, state) => const ForgotPasswordPage(),
    ),

    _appRoute(
      path: '/profile',
      builder: (context, state) => const ProfilePage(),
    ),

    _appRoute(
      path: '/onboarding',
      builder: (context, state) => const OnboardingPage(),
    ),

    _appRoute(
      path: '/recommendations',
      builder: (context, state) => const PersonalizedPage(),
    ),

    // =========================
    // ADMIN
    // =========================
    GoRoute(path: '/admin', redirect: (_, _) => '/admin/dashboard'),
    _appRoute(
      path: '/admin/dashboard',
      builder: (_, state) =>
          _adminShell(state, 'Dashboard', const DashboardPage()),
    ),
    _appRoute(
      path: '/admin/reports',
      builder: (_, state) => _adminShell(
        state,
        'Báo cáo',
        const AdminPlaceholderPage(
          title: 'Báo cáo',
          message: 'Báo cáo doanh thu sẽ khả dụng khi có dữ liệu theo thời gian đủ tin cậy.',
          icon: Icons.query_stats_outlined,
        ),
      ),
    ),
    _appRoute(
      path: '/admin/orders',
      builder: (_, state) => _adminShell(state, 'Đơn hàng', const OrdersPage()),
    ),
    _appRoute(
      path: '/admin/orders/:id',
      builder: (_, state) {
        final id = int.tryParse(state.pathParameters['id'] ?? '');
        return _adminShell(
          state,
          'Chi tiết đơn hàng',
          id == null
              ? const AdminPlaceholderPage(
                  title: 'Đơn hàng không hợp lệ',
                  message: 'Mã đơn hàng không đúng định dạng.',
                  icon: Icons.error_outline,
                )
              : OrderDetailPage(orderId: id),
        );
      },
    ),
    _appRoute(
      path: '/admin/products',
      builder: (_, state) =>
          _adminShell(state, 'Sản phẩm', const ProductsPage()),
    ),
    _appRoute(
      path: '/admin/products/new',
      builder: (_, state) =>
          _adminShell(state, 'Thêm sản phẩm', const ProductFormPage()),
    ),
    _appRoute(
      path: '/admin/products/:id/edit',
      builder: (_, state) {
        final id = int.tryParse(state.pathParameters['id'] ?? '');
        return _adminShell(
          state,
          'Chỉnh sửa sản phẩm',
          id == null
              ? const AdminPlaceholderPage(
                  title: 'Sản phẩm không hợp lệ',
                  message: 'Mã sản phẩm không đúng định dạng.',
                  icon: Icons.error_outline,
                )
              : ProductFormPage(productId: id),
        );
      },
    ),
    _appRoute(
      path: '/admin/products/:id',
      builder: (_, state) {
        final id = int.tryParse(state.pathParameters['id'] ?? '');
        return _adminShell(
          state,
          'Chi tiết sản phẩm',
          id == null
              ? const AdminPlaceholderPage(
                  title: 'Sản phẩm không hợp lệ',
                  message: 'Mã sản phẩm không đúng định dạng.',
                  icon: Icons.error_outline,
                )
              : ProductAdminDetailPage(productId: id),
        );
      },
    ),
    _appRoute(
      path: '/admin/categories',
      builder: (_, state) =>
          _adminShell(state, 'Danh mục', const AdminCategoriesPage()),
    ),
    _appRoute(
      path: '/admin/brands',
      builder: (_, state) =>
          _adminShell(state, 'Thương hiệu', const AdminBrandsPage()),
    ),
    _appRoute(
      path: '/admin/inventory',
      builder: (_, state) =>
          _adminShell(state, 'Kho hàng', const InventoryPage()),
    ),
    _appRoute(
      path: '/admin/users',
      builder: (_, state) =>
          _adminShell(state, 'Người dùng', const UsersPage()),
    ),
    _appRoute(
      path: '/admin/users/:id',
      builder: (_, state) {
        final id = int.tryParse(state.pathParameters['id'] ?? '');
        return _adminShell(
          state,
          'Chi tiết người dùng',
          id == null
              ? const AdminPlaceholderPage(
                  title: 'Người dùng không hợp lệ',
                  message: 'Mã người dùng không đúng định dạng.',
                  icon: Icons.error_outline,
                )
              : UserDetailPage(userId: id),
        );
      },
    ),
    _appRoute(
      path: '/admin/behavior',
      builder: (_, state) => _adminShell(
        state,
        'Hành vi',
        const AdminPlaceholderPage(
          title: 'Hành vi người dùng',
          message: 'Dữ liệu behavior đang được thu thập; màn hình phân tích sẽ chỉ bật khi đủ dữ liệu.',
          icon: Icons.insights_outlined,
        ),
      ),
    ),
    _appRoute(
      path: '/admin/recommendation-analytics',
      builder: (_, state) => _adminShell(
        state,
        'Recommendation Analytics',
        const AdminMetricPage(kind: AdminMetricKind.recommendations),
      ),
    ),
    _appRoute(
      path: '/admin/data-quality',
      builder: (_, state) =>
          _adminShell(state, 'Data Quality', const DataQualityPage()),
    ),
  ],
);
