import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/cart_provider.dart';
import '../providers/catalog_provider.dart';
import '../providers/order_provider.dart';
import '../providers/recommendation_provider.dart';
import '../providers/preferences_provider.dart';
import '../services/backend_api.dart';
import '../widgets/lumi_page_background.dart';
import 'routes.dart';
import 'theme.dart';

class LumiBeautyApp extends StatefulWidget {
  const LumiBeautyApp({super.key, this.backendApi});

  final BackendApi? backendApi;

  @override
  State<LumiBeautyApp> createState() => _LumiBeautyAppState();
}

class _LumiBeautyAppState extends State<LumiBeautyApp> {
  late final BackendApi _api;
  late final AuthProvider _auth;
  late final CatalogProvider _catalog;
  late final RecommendationProvider _recommendations;
  late final PreferencesProvider _preferences;
  late final CartProvider _cart;
  late final OrderProvider _orders;
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _api = widget.backendApi ?? BackendApi();
    _auth = AuthProvider(_api)..restoreSession();
    _catalog = CatalogProvider(_api)..loadProducts();
    _recommendations = RecommendationProvider(_api, _auth);
    _preferences = PreferencesProvider(_api, _auth);
    _cart = CartProvider(_recommendations);
    _orders = OrderProvider(_api, _auth);
    _router = createAppRouter(_auth);
  }

  @override
  void dispose() {
    _auth.dispose();
    _catalog.dispose();
    _recommendations.dispose();
    _preferences.dispose();
    _cart.dispose();
    _orders.dispose();
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<BackendApi>.value(value: _api),
        ChangeNotifierProvider<AuthProvider>.value(value: _auth),
        ChangeNotifierProvider<CatalogProvider>.value(value: _catalog),
        ChangeNotifierProvider<RecommendationProvider>.value(
          value: _recommendations,
        ),
        ChangeNotifierProvider<PreferencesProvider>.value(value: _preferences),
        ChangeNotifierProvider<CartProvider>.value(value: _cart),
        ChangeNotifierProvider<OrderProvider>.value(value: _orders),
      ],
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        title: 'Lumi Beauty',
        theme: AppTheme.theme,
        routerConfig: _router,
        builder: (context, child) =>
            LumiPageBackground(child: child ?? const SizedBox.shrink()),
      ),
    );
  }
}
