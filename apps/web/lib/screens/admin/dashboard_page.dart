import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/order.dart';
import '../../providers/catalog_provider.dart';
import '../../providers/order_provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/backend_api.dart';
import '../../utils/money.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  Map<String, int>? metrics;
  String? metricsError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<OrderProvider>().loadOrders(admin: true);
      _loadMetrics();
    });
  }

  Future<void> _loadMetrics() async {
    final token = context.read<AuthProvider>().accessToken;
    if (token == null) {
      return;
    }
    try {
      final result = await context.read<BackendApi>().getAdminMetrics(token);
      if (mounted) setState(() => metrics = result);
    } catch (error) {
      if (mounted) {
        setState(() => metricsError = BackendApi.readableError(error));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final catalog = context.watch<CatalogProvider>();
    final orders = context.watch<OrderProvider>();
    final customers = orders.orders.map((order) => order.userId).toSet().length;
    final totals = <String, double>{};
    for (final order in orders.orders) {
      totals.update(
        order.currency,
        (value) => value + order.totalAmount,
        ifAbsent: () => order.totalAmount,
      );
    }
    final revenue = totals.isEmpty
        ? '—'
        : totals.entries
              .map((entry) => formatMoney(entry.value, entry.key))
              .join(' · ');

    return ColoredBox(
      color: Colors.grey.shade100,
      child: RefreshIndicator(
        onRefresh: () async {
          await Future.wait([
            catalog.loadProducts(force: true),
            orders.loadOrders(admin: true),
            _loadMetrics(),
          ]);
        },
        child: ListView(
          padding: const EdgeInsets.all(30),
          children: [
            const Text(
              'Tổng quan dữ liệu thực',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Kéo xuống để đồng bộ lại catalog và đơn hàng.',
              style: TextStyle(color: Colors.grey.shade700),
            ),
            const SizedBox(height: 24),
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 1000
                    ? 3
                    : constraints.maxWidth >= 560
                    ? 2
                    : 1;
                return GridView.count(
                  crossAxisCount: columns,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: columns == 1 ? 3.2 : 2.2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _StatCard(
                      title: 'Tổng giá trị đơn',
                      value: revenue,
                      icon: Icons.payments_outlined,
                    ),
                    _StatCard(
                      title: 'Đơn hàng',
                      value: '${orders.orders.length}',
                      icon: Icons.shopping_bag_outlined,
                    ),
                    _StatCard(
                      title: 'Tổng sản phẩm',
                      value:
                          '${metrics?['totalProducts'] ?? catalog.products.length}',
                      icon: Icons.inventory_2_outlined,
                    ),
                    _StatCard(
                      title: 'AI-ready',
                      value: '${metrics?['aiReadyProducts'] ?? '—'}',
                      icon: Icons.psychology_outlined,
                    ),
                    _StatCard(
                      title: 'Production candidates',
                      value: '${metrics?['productionCandidates'] ?? '—'}',
                      icon: Icons.verified_outlined,
                    ),
                    _StatCard(
                      title: 'Người dùng',
                      value: '${metrics?['users'] ?? customers}',
                      icon: Icons.people_outline,
                    ),
                    _StatCard(
                      title: 'Recommendation requests',
                      value: '${metrics?['recommendationRequests'] ?? '—'}',
                      icon: Icons.auto_awesome_outlined,
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),
            if (metricsError != null) ...[
              _AdminError(message: metricsError!, onRetry: _loadMetrics),
              const SizedBox(height: 16),
            ],
            if (orders.isLoading && orders.orders.isEmpty)
              const Center(child: CircularProgressIndicator())
            else if (orders.errorMessage != null)
              _AdminError(
                message: orders.errorMessage!,
                onRetry: () => orders.loadOrders(admin: true),
              )
            else
              _RecentOrders(orders: orders.orders.take(5).toList()),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            CircleAvatar(
              radius: 27,
              backgroundColor: Colors.pink.shade50,
              child: Icon(icon, color: Colors.pink.shade400),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(color: Colors.grey.shade700)),
                  const SizedBox(height: 5),
                  Text(
                    value,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentOrders extends StatelessWidget {
  const _RecentOrders({required this.orders});

  final List<CustomerOrder> orders;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Đơn hàng gần đây',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (orders.isEmpty)
              const Text('Chưa có đơn hàng nào.')
            else
              ...orders.map(
                (order) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: Colors.pink.shade50,
                    child: Icon(
                      Icons.shopping_bag_outlined,
                      color: Colors.pink.shade400,
                    ),
                  ),
                  title: Text('#${order.orderId} · ${order.shippingName}'),
                  subtitle: Text(order.status),
                  trailing: Text(
                    formatMoney(order.totalAmount, order.currency),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AdminError extends StatelessWidget {
  const _AdminError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: const Text('Thử lại')),
          ],
        ),
      ),
    );
  }
}
