import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../app/design_tokens.dart';
import '../providers/auth_provider.dart';
import '../providers/cart_provider.dart';

const _navigationItems = <({String label, String route, IconData icon})>[
  (
    label: 'Danh mục sản phẩm',
    route: '/categories',
    icon: Icons.grid_view_outlined,
  ),
  (
    label: 'Hàng mới',
    route: '/new-arrivals',
    icon: Icons.auto_awesome_outlined,
  ),
  (label: 'Thương hiệu', route: '/brands', icon: Icons.diamond_outlined),
  (label: 'Quà tặng', route: '/gifts', icon: Icons.card_giftcard_outlined),
  (label: 'Blog', route: '/blog', icon: Icons.auto_stories_outlined),
];

class AppHeader extends StatelessWidget {
  const AppHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final cartCount = context.watch<CartProvider>().itemCount;
    return Material(
      color: Theme.of(context).colorScheme.surface,
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.12),
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
        SizedBox(
          height: 76,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: AppBreakpoints.large),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                child: Row(
                  children: [
                    _Brand(onTap: () => context.go('/')),
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
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    _CartButton(cartCount: cartCount),
                  ],
                ),
              ),
            ),
          ),
        ),
        Container(
          height: 52,
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: Theme.of(context).dividerColor),
            ),
          ),
          child: Center(
            child: Wrap(
              alignment: WrapAlignment.center,
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

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void submit() {
    final query = controller.text.trim();
    context.go(
      Uri(
        path: '/search',
        queryParameters: query.isEmpty ? null : {'q': query},
      ).toString(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SearchBar(
      controller: controller,
      hintText: 'Tìm sản phẩm, thương hiệu…',
      leading: const Icon(Icons.search),
      trailing: [
        IconButton(
          tooltip: 'Tìm kiếm',
          onPressed: submit,
          icon: const Icon(Icons.arrow_forward),
        ),
      ],
      onSubmitted: (_) => submit(),
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
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.label,
                style: TextStyle(
                  color: color,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              AnimatedContainer(
                duration: AppDurations.feedback,
                height: 2,
                width: active || hovered ? 30 : 0,
                color: color,
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
    return SafeArea(
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
              ),
              Expanded(child: _Brand(onTap: () => context.go('/'))),
              IconButton(
                tooltip: 'Tìm kiếm',
                onPressed: () => context.go('/search'),
                icon: const Icon(Icons.search),
              ),
              IconButton(
                tooltip: auth.isAuthenticated ? 'Tài khoản' : 'Đăng nhập',
                onPressed: () =>
                    context.go(auth.isAuthenticated ? '/profile' : '/login'),
                icon: const Icon(Icons.person_outline),
              ),
              _CartButton(cartCount: cartCount),
            ],
          ),
        ),
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Text(
        'LUMI BEAUTY',
        maxLines: 1,
        style: Theme.of(context).textTheme.titleLarge
            ?.copyWith(fontWeight: FontWeight.w800, letterSpacing: 1.2),
      ),
    );
  }
}

class _CartButton extends StatelessWidget {
  const _CartButton({required this.cartCount});

  final int cartCount;

  @override
  Widget build(BuildContext context) {
    return Badge(
      isLabelVisible: cartCount > 0,
      label: Text('$cartCount'),
      child: IconButton(
        tooltip: 'Giỏ hàng',
        onPressed: () => context.go('/cart'),
        icon: const Icon(Icons.shopping_bag_outlined),
      ),
    );
  }
}
