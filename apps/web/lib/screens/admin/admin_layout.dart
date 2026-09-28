import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';

import 'dashboard_page.dart';
import 'products_page.dart';
import 'orders_page.dart';

class AdminLayout extends StatefulWidget {
  const AdminLayout({super.key});

  @override
  State<AdminLayout> createState() => _AdminLayoutState();
}

class _AdminLayoutState extends State<AdminLayout> {
  int selectedIndex = 0;

  final List<String> menuItems = ['Dashboard', 'Sản phẩm', 'Đơn hàng'];

  final List<IconData> menuIcons = [
    Icons.dashboard_outlined,
    Icons.inventory_2_outlined,
    Icons.shopping_bag_outlined,
  ];

  Widget _buildPage() {
    switch (selectedIndex) {
      case 0:
        return const DashboardPage();
      case 1:
        return const ProductsPage();
      case 2:
        return const OrdersPage();
      default:
        return const DashboardPage();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // SIDEBAR
          Container(
            width: 250,
            color: Colors.pink.shade400,
            child: Column(
              children: [
                const SizedBox(height: 30),

                const Text(
                  'LUMI BEAUTY',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 5),

                const Text(
                  'ADMIN',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    letterSpacing: 2,
                  ),
                ),

                const SizedBox(height: 40),

                Expanded(
                  child: ListView.builder(
                    itemCount: menuItems.length,
                    itemBuilder: (context, index) {
                      final isSelected = selectedIndex == index;

                      return Container(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.white : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: ListTile(
                          leading: Icon(
                            menuIcons[index],
                            color: isSelected
                                ? Colors.pink.shade400
                                : Colors.white,
                          ),
                          title: Text(
                            menuItems[index],
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.pink.shade400
                                  : Colors.white,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                          onTap: () {
                            setState(() {
                              selectedIndex = index;
                            });
                          },
                        ),
                      );
                    },
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.all(16),
                  child: ListTile(
                    leading: const Icon(Icons.logout, color: Colors.white),
                    title: const Text(
                      'Đăng xuất',
                      style: TextStyle(color: Colors.white),
                    ),
                    onTap: () {
                      context.read<AuthProvider>().logout();
                      context.go('/');
                    },
                  ),
                ),
              ],
            ),
          ),

          // MAIN CONTENT
          Expanded(
            child: Column(
              children: [
                Container(
                  height: 70,
                  padding: const EdgeInsets.symmetric(horizontal: 30),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Text(
                        menuItems[selectedIndex],
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      const CircleAvatar(child: Icon(Icons.person)),
                      const SizedBox(width: 10),
                      Text(
                        context.watch<AuthProvider>().user?.fullName ??
                            'Administrator',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),

                Expanded(child: _buildPage()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
