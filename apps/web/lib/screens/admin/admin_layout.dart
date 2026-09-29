import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/design_tokens.dart';
import '../../providers/auth_provider.dart';

import 'dashboard_page.dart';
import 'products_page.dart';
import 'orders_page.dart';
import 'catalog_insights_pages.dart';

class AdminLayout extends StatefulWidget {
  const AdminLayout({super.key});

  @override
  State<AdminLayout> createState() => _AdminLayoutState();
}

class _AdminLayoutState extends State<AdminLayout> {
  int selectedIndex = 0;

  final List<String> menuItems = [
    'Dashboard',
    'Sản phẩm',
    'Danh mục',
    'Thương hiệu',
    'Đơn hàng',
    'Người dùng',
    'Data Quality',
    'Recommendation Analytics',
  ];

  final List<IconData> menuIcons = [
    Icons.dashboard_outlined,
    Icons.inventory_2_outlined,
    Icons.category_outlined,
    Icons.storefront_outlined,
    Icons.shopping_bag_outlined,
    Icons.people_outline,
    Icons.fact_check_outlined,
    Icons.auto_awesome_outlined,
  ];

  Widget _buildPage() {
    switch (selectedIndex) {
      case 0:
        return const DashboardPage();
      case 1:
        return const ProductsPage();
      case 2:
        return const AdminCategoriesPage();
      case 3:
        return const AdminBrandsPage();
      case 4:
        return const OrdersPage();
      case 5:
        return const AdminMetricPage(kind: AdminMetricKind.users);
      case 6:
        return const DataQualityPage();
      case 7:
        return const AdminMetricPage(kind: AdminMetricKind.recommendations);
      default:
        return const DashboardPage();
    }
  }

  void _logout() {
    context.read<AuthProvider>().logout();
    context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final userName =
        context.watch<AuthProvider>().user?.fullName ?? 'Quản trị viên';
    return ColoredBox(
      color: const Color(0xFFF7F4F7),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final desktop = constraints.maxWidth >= AppBreakpoints.navigation;
          final content = Column(
            children: [
              Container(
                height: 72,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  boxShadow: AppShadows.header,
                ),
                child: Row(
                  children: [
                    Text(
                      menuItems[selectedIndex],
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const Spacer(),
                    const CircleAvatar(
                      backgroundColor: AppColors.lavenderMist,
                      child: Icon(Icons.person_outline, color: AppColors.plum),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Flexible(
                      child: Text(userName, overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
              ),
              Expanded(child: _buildPage()),
            ],
          );
          if (desktop) {
            return Row(
              children: [
                _AdminSidebar(
                  selectedIndex: selectedIndex,
                  labels: menuItems,
                  icons: menuIcons,
                  onSelected: (value) => setState(() => selectedIndex = value),
                  onLogout: _logout,
                ),
                Expanded(child: content),
              ],
            );
          }
          return Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              title: const Text('LUMI ADMIN'),
              backgroundColor: AppColors.deepPlum,
              foregroundColor: AppColors.surface,
            ),
            drawer: Drawer(
              child: SafeArea(
                child: _AdminDrawer(
                  selectedIndex: selectedIndex,
                  labels: menuItems,
                  icons: menuIcons,
                  onSelected: (value) {
                    setState(() => selectedIndex = value);
                    Navigator.of(context).pop();
                  },
                  onLogout: _logout,
                ),
              ),
            ),
            body: content,
          );
        },
      ),
    );
  }
}

class _AdminSidebar extends StatelessWidget {
  const _AdminSidebar({
    required this.selectedIndex,
    required this.labels,
    required this.icons,
    required this.onSelected,
    required this.onLogout,
  });

  final int selectedIndex;
  final List<String> labels;
  final List<IconData> icons;
  final ValueChanged<int> onSelected;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 252,
      color: AppColors.deepPlum,
      child: SafeArea(
        child: _AdminDrawer(
          selectedIndex: selectedIndex,
          labels: labels,
          icons: icons,
          onSelected: onSelected,
          onLogout: onLogout,
          dark: true,
        ),
      ),
    );
  }
}

class _AdminDrawer extends StatelessWidget {
  const _AdminDrawer({
    required this.selectedIndex,
    required this.labels,
    required this.icons,
    required this.onSelected,
    required this.onLogout,
    this.dark = false,
  });

  final int selectedIndex;
  final List<String> labels;
  final List<IconData> icons;
  final ValueChanged<int> onSelected;
  final VoidCallback onLogout;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final foreground = dark ? AppColors.surface : AppColors.ink;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            children: [
              Text(
                'LUMI BEAUTY',
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(color: foreground, letterSpacing: 1.2),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'ADMIN',
                style: TextStyle(color: foreground.withValues(alpha: 0.7)),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            itemCount: labels.length,
            itemBuilder: (context, index) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: ListTile(
                selected: selectedIndex == index,
                selectedTileColor: AppColors.surface,
                selectedColor: AppColors.plum,
                textColor: foreground,
                iconColor: foreground,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.control),
                ),
                leading: Icon(icons[index]),
                title: Text(labels[index]),
                onTap: () => onSelected(index),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: ListTile(
            textColor: foreground,
            iconColor: foreground,
            leading: const Icon(Icons.logout),
            title: const Text('Đăng xuất'),
            onTap: onLogout,
          ),
        ),
      ],
    );
  }
}
