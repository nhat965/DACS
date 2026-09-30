import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../app/design_tokens.dart';
import '../models/product.dart';
import '../providers/auth_provider.dart';
import '../providers/cart_provider.dart';
import '../services/backend_api.dart';
import '../utils/money.dart';

const _navigationItems = <({String label, String route, IconData icon})>[
  (
    label: 'Danh mục sản phẩm',
    route: '/categories',
    icon: Icons.grid_view_outlined,
  ),
  (label: 'Outlet - Giá tốt', route: '/outlet', icon: Icons.sell_outlined),
  (
    label: 'Hàng mới về',
    route: '/new-arrivals',
    icon: Icons.auto_awesome_outlined,
  ),
  (label: 'Khuyến mại', route: '/promotions', icon: Icons.local_offer_outlined),
  (label: 'Flash Sale ⚡', route: '/flash-sale', icon: Icons.bolt_outlined),
  (label: 'Thương hiệu', route: '/brands', icon: Icons.diamond_outlined),
  (label: 'Blog làm đẹp', route: '/blog', icon: Icons.auto_stories_outlined),
  (
    label: 'Hệ thống cửa hàng',
    route: '/stores',
    icon: Icons.storefront_outlined,
  ),
  (
    label: 'Tra cứu đơn hàng',
    route: '/order-lookup',
    icon: Icons.receipt_long_outlined,
  ),
];

class AppHeader extends StatelessWidget {
  const AppHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final cartCount = context.watch<CartProvider>().itemCount;
    return DecoratedBox(
      decoration: const BoxDecoration(boxShadow: AppShadows.header),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < AppBreakpoints.navigation) {
            return _CompactHeader(auth: auth, cartCount: cartCount);
          }
          return _DesktopHeader(auth: auth, cartCount: cartCount);
        },
      ),
    );
  }
}

class _DesktopHeader extends StatelessWidget {
  const _DesktopHeader({required this.auth, required this.cartCount});

  final AuthProvider auth;
  final int cartCount;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          height: 76,
          decoration: const BoxDecoration(gradient: AppGradients.brandHeader),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: AppBreakpoints.large),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                child: Row(
                  children: [
                    _Brand(onTap: () => context.go('/'), light: true),
                    const SizedBox(width: AppSpacing.xxl),
                    const Expanded(child: _HeaderSearch()),
                    const SizedBox(width: AppSpacing.lg),
                    TextButton.icon(
                      onPressed: () => context.go(
                        auth.isAuthenticated ? '/profile' : '/login',
                      ),
                      icon: const Icon(Icons.person_outline),
                      label: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 150),
                        child: Text(
                          auth.isAuthenticated
                              ? auth.user!.fullName
                              : 'Đăng nhập',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.surface,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    IconButton(
                      tooltip: 'Hệ thống cửa hàng',
                      onPressed: () => context.go('/stores'),
                      color: AppColors.surface,
                      icon: const Icon(Icons.location_on_outlined),
                    ),
                    _CartButton(cartCount: cartCount, light: true),
                  ],
                ),
              ),
            ),
          ),
        ),
        Container(
          height: 52,
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border(
              top: BorderSide(color: Theme.of(context).dividerColor),
            ),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _navigationItems
                  .map(
                    (item) =>
                        _DesktopNavItem(label: item.label, route: item.route),
                  )
                  .toList(),
            ),
          ),
        ),
      ],
    );
  }
}

class _HeaderSearch extends StatefulWidget {
  const _HeaderSearch();

  @override
  State<_HeaderSearch> createState() => _HeaderSearchState();
}

class _HeaderSearchState extends State<_HeaderSearch> {
  final controller = TextEditingController();
  final focusNode = FocusNode();
  final layerLink = LayerLink();
  final tapGroup = Object();
  final api = BackendApi();

  Timer? debounce;
  OverlayEntry? suggestionsOverlay;
  List<Product> suggestions = const [];
  bool loading = false;
  int requestSequence = 0;
  double fieldWidth = 0;

  @override
  void dispose() {
    debounce?.cancel();
    suggestionsOverlay?.remove();
    focusNode.dispose();
    controller.dispose();
    super.dispose();
  }

  void onQueryChanged(String rawQuery) {
    debounce?.cancel();
    final query = rawQuery.trim();
    if (query.length < 2) {
      requestSequence++;
      loading = false;
      suggestions = const [];
      closeSuggestions();
      return;
    }

    loading = true;
    showSuggestions();
    debounce = Timer(const Duration(milliseconds: 350), () {
      loadSuggestions(query);
    });
  }

  Future<void> loadSuggestions(String query) async {
    final sequence = ++requestSequence;
    try {
      final result = await api.getProductPage(search: query, limit: 6);
      if (!mounted || sequence != requestSequence) return;
      suggestions = result.items;
    } catch (_) {
      if (!mounted || sequence != requestSequence) return;
      suggestions = const [];
    } finally {
      if (mounted && sequence == requestSequence) {
        loading = false;
        showSuggestions();
      }
    }
  }

  void showSuggestions() {
    final renderBox = context.findRenderObject() as RenderBox?;
    fieldWidth = renderBox?.size.width ?? fieldWidth;
    if (suggestionsOverlay == null) {
      suggestionsOverlay = OverlayEntry(
        builder: (context) => _SearchSuggestionsOverlay(
          link: layerLink,
          width: fieldWidth,
          tapGroup: tapGroup,
          query: controller.text.trim(),
          loading: loading,
          products: suggestions,
          onProductSelected: openProduct,
          onShowAll: submit,
        ),
      );
      Overlay.of(context).insert(suggestionsOverlay!);
    } else {
      suggestionsOverlay!.markNeedsBuild();
    }
  }

  void closeSuggestions() {
    suggestionsOverlay?.remove();
    suggestionsOverlay = null;
  }

  void openProduct(Product product) {
    closeSuggestions();
    focusNode.unfocus();
    context.go('/product/${product.id}');
  }

  void submit() {
    final query = controller.text.trim();
    closeSuggestions();
    focusNode.unfocus();
    context.go(
      Uri(
        path: '/search',
        queryParameters: query.isEmpty ? null : {'q': query},
      ).toString(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return TapRegion(
      groupId: tapGroup,
      onTapOutside: (_) => closeSuggestions(),
      child: CompositedTransformTarget(
        link: layerLink,
        child: SearchBar(
          controller: controller,
          focusNode: focusNode,
          hintText: 'Tìm sản phẩm, thương hiệu…',
          leading: const Icon(Icons.search),
          trailing: [
            if (controller.text.isNotEmpty)
              IconButton(
                tooltip: 'Xóa từ khóa',
                onPressed: () {
                  controller.clear();
                  onQueryChanged('');
                  setState(() {});
                  focusNode.requestFocus();
                },
                icon: const Icon(Icons.close, size: 20),
              ),
            IconButton(
              tooltip: 'Tìm kiếm',
              onPressed: submit,
              icon: const Icon(Icons.arrow_forward),
            ),
          ],
          onChanged: (value) {
            setState(() {});
            onQueryChanged(value);
          },
          onSubmitted: (_) => submit(),
          backgroundColor: const WidgetStatePropertyAll(AppColors.surface),
          elevation: const WidgetStatePropertyAll(0),
        ),
      ),
    );
  }
}

class _SearchSuggestionsOverlay extends StatelessWidget {
  const _SearchSuggestionsOverlay({
    required this.link,
    required this.width,
    required this.tapGroup,
    required this.query,
    required this.loading,
    required this.products,
    required this.onProductSelected,
    required this.onShowAll,
  });

  final LayerLink link;
  final double width;
  final Object tapGroup;
  final String query;
  final bool loading;
  final List<Product> products;
  final ValueChanged<Product> onProductSelected;
  final VoidCallback onShowAll;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: CompositedTransformFollower(
        link: link,
        showWhenUnlinked: false,
        targetAnchor: Alignment.bottomLeft,
        followerAnchor: Alignment.topLeft,
        offset: const Offset(0, AppSpacing.xs),
        child: Align(
          alignment: Alignment.topLeft,
          child: TapRegion(
            groupId: tapGroup,
            child: Material(
              color: AppColors.surface,
              elevation: 10,
              shadowColor: AppColors.deepPlum.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(AppRadius.card),
              clipBehavior: Clip.antiAlias,
              child: SizedBox(
                width: width,
                child: AnimatedSwitcher(
                  duration: AppDurations.feedback,
                  child: loading
                      ? const _SuggestionLoading()
                      : _SuggestionResults(
                          query: query,
                          products: products,
                          onProductSelected: onProductSelected,
                          onShowAll: onShowAll,
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SuggestionLoading extends StatelessWidget {
  const _SuggestionLoading();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      key: ValueKey('loading'),
      padding: EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: AppSpacing.sm),
          Text('Đang tìm sản phẩm phù hợp…'),
        ],
      ),
    );
  }
}

class _SuggestionResults extends StatelessWidget {
  const _SuggestionResults({
    required this.query,
    required this.products,
    required this.onProductSelected,
    required this.onShowAll,
  });

  final String query;
  final List<Product> products;
  final ValueChanged<Product> onProductSelected;
  final VoidCallback onShowAll;

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) {
      return Padding(
        key: const ValueKey('empty'),
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: [
            const Icon(Icons.search_off_outlined, color: AppColors.mutedInk),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: Text('Không tìm thấy sản phẩm cho “$query”.')),
          ],
        ),
      );
    }

    return Column(
      key: ValueKey('results-$query'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.xs,
          ),
          child: Text(
            'Sản phẩm gợi ý',
            style: Theme.of(context).textTheme.labelLarge
                ?.copyWith(color: AppColors.plum),
          ),
        ),
        ...products.map(
          (product) => _SuggestionProductTile(
            product: product,
            onTap: () => onProductSelected(product),
          ),
        ),
        const Divider(height: 1),
        TextButton.icon(
          onPressed: onShowAll,
          iconAlignment: IconAlignment.end,
          icon: const Icon(Icons.arrow_forward, size: 18),
          label: Text('Xem tất cả kết quả cho “$query”'),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.md,
            ),
            alignment: Alignment.centerLeft,
          ),
        ),
      ],
    );
  }
}

class _SuggestionProductTile extends StatelessWidget {
  const _SuggestionProductTile({required this.product, required this.onTap});

  final Product product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.control),
              child: SizedBox.square(
                dimension: 52,
                child: product.image.isEmpty
                    ? const ColoredBox(
                        color: AppColors.paleRose,
                        child: Icon(Icons.spa_outlined),
                      )
                    : Image.network(
                        product.image,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const ColoredBox(
                          color: AppColors.paleRose,
                          child: Icon(Icons.spa_outlined),
                        ),
                      ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (product.brand.isNotEmpty)
                    Text(
                      product.brand.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.mutedInk,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  Text(
                    product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    formatMoney(product.price, product.currency),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.rose,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.mutedInk),
          ],
        ),
      ),
    );
  }
}

class _DesktopNavItem extends StatefulWidget {
  const _DesktopNavItem({required this.label, required this.route});

  final String label;
  final String route;

  @override
  State<_DesktopNavItem> createState() => _DesktopNavItemState();
}

class _DesktopNavItemState extends State<_DesktopNavItem> {
  bool hovered = false;

  @override
  Widget build(BuildContext context) {
    final currentPath = GoRouterState.of(context).uri.path;
    final active =
        currentPath == widget.route ||
        currentPath.startsWith('${widget.route}/');
    final color = active || hovered
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.onSurface;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => hovered = true),
      onExit: (_) => setState(() => hovered = false),
      child: InkWell(
        onTap: () => context.go(widget.route),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                widget.label,
                style: TextStyle(
                  color: color,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
              AnimatedContainer(
                duration: AppDurations.feedback,
                margin: const EdgeInsets.only(top: 4),
                height: 2,
                width: active || hovered ? 30 : 0,
                decoration: const BoxDecoration(
                  gradient: AppGradients.brand,
                  borderRadius: BorderRadius.all(Radius.circular(2)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompactHeader extends StatelessWidget {
  const _CompactHeader({required this.auth, required this.cartCount});

  final AuthProvider auth;
  final int cartCount;

  void openMenu(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: _navigationItems
                .map(
                  (item) => ListTile(
                    leading: Icon(item.icon),
                    title: Text(item.label),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      context.go(item.route);
                    },
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: AppGradients.brandHeader),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 68,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Mở menu',
                  onPressed: () => openMenu(context),
                  icon: const Icon(Icons.menu),
                  color: AppColors.surface,
                ),
                Expanded(
                  child: _Brand(onTap: () => context.go('/'), light: true),
                ),
                IconButton(
                  tooltip: 'Tìm kiếm',
                  onPressed: () => context.go('/search'),
                  icon: const Icon(Icons.search),
                  color: AppColors.surface,
                ),
                IconButton(
                  tooltip: auth.isAuthenticated ? 'Tài khoản' : 'Đăng nhập',
                  onPressed: () =>
                      context.go(auth.isAuthenticated ? '/profile' : '/login'),
                  icon: const Icon(Icons.person_outline),
                  color: AppColors.surface,
                ),
                _CartButton(cartCount: cartCount, light: true),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand({required this.onTap, this.light = false});

  final VoidCallback onTap;
  final bool light;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Text(
        'LUMI BEAUTY',
        maxLines: 1,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
          color: light ? AppColors.surface : AppColors.ink,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _CartButton extends StatelessWidget {
  const _CartButton({required this.cartCount, this.light = false});

  final int cartCount;
  final bool light;

  @override
  Widget build(BuildContext context) {
    return Badge(
      isLabelVisible: cartCount > 0,
      label: AnimatedSwitcher(
        duration: AppDurations.feedback,
        transitionBuilder: (child, animation) =>
            ScaleTransition(scale: animation, child: child),
        child: Text('$cartCount', key: ValueKey(cartCount)),
      ),
      child: IconButton(
        tooltip: 'Giỏ hàng',
        onPressed: () => context.go('/cart'),
        icon: const Icon(Icons.shopping_bag_outlined),
        color: light ? AppColors.surface : null,
      ),
    );
  }
}
