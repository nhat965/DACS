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
import '../screens/customer/personalized_page.dart';

import '../screens/admin/admin_layout.dart';

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
      builder: (_, _) => const CatalogStatusPage(
        title: 'Tra cứu đơn hàng',
        message: 'Đăng nhập để xem và theo dõi các đơn hàng của bạn.',
        icon: Icons.receipt_long_outlined,
        actionLabel: 'Đăng nhập',
        actionRoute: '/login?redirect=%2Fprofile',
      ),
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
    _appRoute(path: '/admin', builder: (context, state) => const AdminLayout()),
  ],
);
