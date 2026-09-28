import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';

import '../providers/auth_provider.dart';

import '../screens/customer/home_page.dart';
import '../screens/customer/category_page.dart';
import '../screens/customer/categories_page.dart';
import '../screens/customer/brands_page.dart';
import '../screens/customer/catalog_status_page.dart';
import '../screens/customer/product_detail_page.dart';
import '../screens/customer/search_page.dart';
import '../screens/customer/cart_page.dart';
import '../screens/customer/checkout_page.dart';
import '../screens/customer/login_page.dart';
import '../screens/customer/register_page.dart';
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
    final isAuthPage = path == '/login' || path == '/register';
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
      builder: (context, state) => const CatalogStatusPage(
        title: 'Hàng mới sắp có',
        message: 'Catalog hiện chưa có mốc firstSeenAt/createdAt đủ tin cậy. Lumi không gắn nhãn "mới" sai cho sản phẩm.',
        icon: Icons.auto_awesome_outlined,
      ),
    ),

    _appRoute(
      path: '/gifts',
      builder: (context, state) => const CatalogStatusPage(
        title: 'Bộ sưu tập quà tặng đang được chuẩn bị',
        message: 'Chưa có tag hoặc collection quà tặng trong dữ liệu thật, vì vậy Lumi không tự gán sản phẩm thường thành quà tặng.',
        icon: Icons.card_giftcard_outlined,
      ),
    ),

    _appRoute(
      path: '/blog',
      builder: (context, state) => const CatalogStatusPage(
        title: 'Cẩm nang Lumi Beauty',
        message: 'Hiện chưa có bài viết đã xuất bản. Khu vực này sẽ chỉ hiển thị nội dung đã được biên tập và kiểm chứng.',
        icon: Icons.auto_stories_outlined,
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
      builder: (context, state) =>
          SearchPage(initialQuery: state.uri.queryParameters['q'] ?? ''),
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
