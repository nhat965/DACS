import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/design_tokens.dart';
import '../../providers/auth_provider.dart';

class AdminLayout extends StatelessWidget {
  const AdminLayout({
    super.key,
    required this.currentPath,
    required this.child,
    required this.title,
  });

  final String currentPath;
  final Widget child;
  final String title;

  static const groups = <_AdminNavGroup>[
    _AdminNavGroup('TỔNG QUAN', [
      _AdminNavItem('Dashboard', Icons.dashboard_outlined, '/admin/dashboard'),
      _AdminNavItem('Báo cáo', Icons.query_stats_outlined, '/admin/reports'),
    ]),
    _AdminNavGroup('BÁN HÀNG', [
      _AdminNavItem('Đơn hàng', Icons.shopping_bag_outlined, '/admin/orders'),
    ]),
    _AdminNavGroup('SẢN PHẨM', [
      _AdminNavItem('Sản phẩm', Icons.inventory_2_outlined, '/admin/products'),
      _AdminNavItem('Danh mục', Icons.category_outlined, '/admin/categories'),
      _AdminNavItem('Thương hiệu', Icons.storefront_outlined, '/admin/brands'),
      _AdminNavItem('Kho hàng', Icons.warehouse_outlined, '/admin/inventory'),
    ]),
    _AdminNavGroup('KHÁCH HÀNG', [
      _AdminNavItem('Người dùng', Icons.people_outline, '/admin/users'),
      _AdminNavItem('Hành vi', Icons.insights_outlined, '/admin/behavior'),
    ]),
    _AdminNavGroup('AI & DỮ LIỆU', [
      _AdminNavItem(
        'Recommendation Analytics',
        Icons.auto_awesome_outlined,
        '/admin/recommendation-analytics',
      ),
      _AdminNavItem(
        'Data Quality',
        Icons.fact_check_outlined,
        '/admin/data-quality',
      ),
    ]),
  ];

  void _logout(BuildContext context) {
    context.read<AuthProvider>().logout();
    context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final sessionKey = context.watch<AuthProvider>().accessToken;
    final sessionAwareChild = KeyedSubtree(
      key: ValueKey(sessionKey),
      child: child,
    );
    return ColoredBox(
      color: AdminColors.background,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final desktop = constraints.maxWidth >= AppBreakpoints.desktop;
          if (desktop) {
            return Row(
              children: [
                _AdminNavigation(
                  currentPath: currentPath,
                  onLogout: () => _logout(context),
                ),
                Expanded(
                  child: Column(
                    children: [
                      _AdminTopbar(
                        title: title,
                        onLogout: () => _logout(context),
                      ),
                      Expanded(child: sessionAwareChild),
                    ],
                  ),
                ),
              ],
            );
          }
          return Scaffold(
            backgroundColor: AdminColors.background,
            drawer: Drawer(
              width: 270,
              backgroundColor: AdminColors.deepPlum,
              child: _AdminNavigation(
                currentPath: currentPath,
                onNavigate: () => Navigator.of(context).pop(),
                onLogout: () => _logout(context),
              ),
            ),
            body: Column(
              children: [
                Builder(
                  builder: (context) => _AdminTopbar(
                    title: title,
                    onMenu: () => Scaffold.of(context).openDrawer(),
                    onLogout: () => _logout(context),
                  ),
                ),
                Expanded(child: sessionAwareChild),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _AdminTopbar extends StatelessWidget {
  const _AdminTopbar({
    required this.title,
    required this.onLogout,
    this.onMenu,
  });

  final String title;
  final VoidCallback onLogout;
  final VoidCallback? onMenu;

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    return Container(
      height: 68,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      decoration: const BoxDecoration(
        color: AdminColors.card,
        border: Border(bottom: BorderSide(color: AdminColors.border)),
      ),
      child: Row(
        children: [
          if (onMenu != null) ...[
            IconButton(
              tooltip: 'Mở menu quản trị',
              onPressed: onMenu,
              icon: const Icon(Icons.menu),
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
          Expanded(
            child: Text(
              title,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(color: AdminColors.textPrimary),
            ),
          ),
          IconButton(
            tooltip: 'Thông báo',
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Chưa có thông báo mới.')),
            ),
            icon: const Icon(Icons.notifications_none_outlined),
          ),
          const SizedBox(width: AppSpacing.xs),
          PopupMenuButton<String>(
            tooltip: 'Tài khoản quản trị',
            onSelected: (value) {
              if (value == 'logout') onLogout();
              if (value == 'profile') context.go('/profile');
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'profile', child: Text('Hồ sơ')),
              PopupMenuItem(value: 'logout', child: Text('Đăng xuất')),
            ],
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 18,
                  backgroundColor: AdminColors.softLavender,
                  child: Icon(
                    Icons.person_outline,
                    size: 20,
                    color: AdminColors.deepPlum,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 150),
                  child: Text(
                    user?.fullName ?? 'Quản trị viên',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                const Icon(Icons.arrow_drop_down),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminNavigation extends StatelessWidget {
  const _AdminNavigation({
    required this.currentPath,
    required this.onLogout,
    this.onNavigate,
  });

  final String currentPath;
  final VoidCallback onLogout;
  final VoidCallback? onNavigate;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AdminColors.deepPlum, AdminColors.sidebarPlum],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(22, 24, 22, 20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'LUMI BEAUTY',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Admin Console',
                      style: TextStyle(color: AdminColors.lavender),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                children: AdminLayout.groups
                    .expand(
                      (group) => [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 18, 12, 8),
                          child: Text(
                            group.label,
                            style: const TextStyle(
                              color: AdminColors.lavender,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.1,
                            ),
                          ),
                        ),
                        ...group.items.map(
                          (item) => _AdminNavTile(
                            item: item,
                            selected:
                                currentPath == item.path ||
                                (item.path != '/admin/dashboard' &&
                                    currentPath.startsWith('${item.path}/')),
                            onTap: () {
                              context.go(item.path);
                              onNavigate?.call();
                            },
                          ),
                        ),
                      ],
                    )
                    .toList(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: _AdminNavTile(
                item: const _AdminNavItem('Đăng xuất', Icons.logout, ''),
                selected: false,
                onTap: onLogout,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminNavTile extends StatefulWidget {
  const _AdminNavTile({
    required this.item,
    required this.selected,
    required this.onTap,
  });
  final _AdminNavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_AdminNavTile> createState() => _AdminNavTileState();
}

class _AdminNavTileState extends State<_AdminNavTile> {
  bool hovered = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => hovered = true),
        onExit: (_) => setState(() => hovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 170),
          decoration: BoxDecoration(
            color: widget.selected
                ? Colors.white.withValues(alpha: 0.14)
                : hovered
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.control),
          ),
          child: Material(
            color: Colors.transparent,
            child: ListTile(
              dense: true,
              minLeadingWidth: 24,
              leading: AnimatedScale(
                scale: widget.selected || hovered ? 1.04 : 1,
                duration: const Duration(milliseconds: 170),
                child: Icon(widget.item.icon, color: Colors.white, size: 21),
              ),
              title: Text(
                widget.item.label,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: widget.selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
              onTap: widget.onTap,
            ),
          ),
        ),
      ),
    );
  }
}

class _AdminNavGroup {
  const _AdminNavGroup(this.label, this.items);
  final String label;
  final List<_AdminNavItem> items;
}

class _AdminNavItem {
  const _AdminNavItem(this.label, this.icon, this.path);
  final String label;
  final IconData icon;
  final String path;
}
