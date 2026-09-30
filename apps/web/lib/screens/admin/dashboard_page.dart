import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/design_tokens.dart';
import '../../models/admin_models.dart';
import '../../models/order.dart';
import '../../providers/auth_provider.dart';
import '../../services/backend_api.dart';
import '../../utils/money.dart';
import 'admin_components.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  AdminDashboardData? dashboard;
  List<CustomerOrder> recentOrders = const [];
  String? error;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => load());
  }

  Future<void> load() async {
    final token = context.read<AuthProvider>().accessToken;
    if (token == null) return;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final api = context.read<BackendApi>();
      final results = await Future.wait<dynamic>([
        api.getAdminDashboard(token),
        api.getOrders(accessToken: token, admin: true),
      ]);
      if (!mounted) return;
      setState(() {
        dashboard = results[0] as AdminDashboardData;
        recentOrders = (results[1] as List<CustomerOrder>).take(6).toList();
      });
    } catch (exception) {
      if (mounted) setState(() => error = BackendApi.readableError(exception));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          AdminPageHeader(
            title: 'Xin chào, Admin',
            subtitle: 'Theo dõi hoạt động vận hành của Lumi Beauty.',
            actions: [
              OutlinedButton.icon(
                onPressed: load,
                icon: const Icon(Icons.refresh),
                label: const Text('Làm mới'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          if (loading && dashboard == null)
            const AdminLoading(rows: 4)
          else if (error != null)
            AdminSectionCard(
              child: AdminMessageState(
                icon: Icons.cloud_off_outlined,
                title: 'Không thể tải dashboard',
                message: error!,
                actionLabel: 'Thử lại',
                onAction: load,
              ),
            )
          else if (dashboard != null) ...[
            _KpiGrid(data: dashboard!),
            const SizedBox(height: AppSpacing.lg),
            LayoutBuilder(
              builder: (context, constraints) {
                final status = AdminSectionCard(
                  title: 'Trạng thái đơn hàng',
                  child: _OrderStatusSummary(values: dashboard!.orderStatuses),
                );
                final data = AdminSectionCard(
                  title: 'AI & dữ liệu',
                  child: _DataSummary(data: dashboard!),
                );
                if (constraints.maxWidth < 840) {
                  return Column(
                    children: [
                      status,
                      const SizedBox(height: AppSpacing.md),
                      data,
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: status),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(flex: 2, child: data),
                  ],
                );
              },
            ),
            const SizedBox(height: AppSpacing.lg),
            AdminSectionCard(
              title: 'Đơn hàng gần đây',
              trailing: TextButton(
                onPressed: () => context.go('/admin/orders'),
                child: const Text('Xem tất cả'),
              ),
              child: _RecentOrders(orders: recentOrders),
            ),
          ],
        ],
      ),
    );
  }
}

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({required this.data});
  final AdminDashboardData data;

  @override
  Widget build(BuildContext context) {
    final revenue = data.revenueByCurrency.isEmpty
        ? '—'
        : data.revenueByCurrency.entries
              .map((item) => formatMoney(item.value, item.key))
              .join(' · ');
    final cards = [
      AdminStatCard(
        label: 'Doanh thu hoàn thành',
        value: revenue,
        icon: Icons.payments_outlined,
        color: AdminColors.success,
      ),
      AdminStatCard(
        label: 'Tổng đơn hàng',
        value: '${data.orders}',
        icon: Icons.shopping_bag_outlined,
        color: AdminColors.info,
      ),
      AdminStatCard(
        label: 'Người dùng',
        value: '${data.users}',
        icon: Icons.people_outline,
      ),
      AdminStatCard(
        label: 'Sản phẩm',
        value: '${data.totalProducts}',
        icon: Icons.inventory_2_outlined,
        color: AdminColors.dataQuality,
      ),
      AdminStatCard(
        label: 'Đơn hôm nay',
        value: '${data.ordersToday}',
        icon: Icons.today_outlined,
        color: AdminColors.info,
      ),
      AdminStatCard(
        label: 'Chờ xử lý',
        value: '${data.pendingOrders}',
        icon: Icons.pending_actions_outlined,
        color: AdminColors.warning,
      ),
      AdminStatCard(
        label: 'Sắp hết hàng',
        value: '${data.lowStockProducts}',
        icon: Icons.inventory_outlined,
        color: AdminColors.danger,
      ),
      AdminStatCard(
        label: 'AI-ready',
        value: '${data.aiReadyProducts}',
        icon: Icons.auto_awesome_outlined,
        color: AdminColors.aiAccent,
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final count = constraints.maxWidth >= 1050
            ? 4
            : constraints.maxWidth >= 620
            ? 2
            : 1;
        return GridView.count(
          crossAxisCount: count,
          crossAxisSpacing: AppSpacing.md,
          mainAxisSpacing: AppSpacing.md,
          childAspectRatio: count == 1 ? 3.2 : 2.25,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: cards,
        );
      },
    );
  }
}

class _OrderStatusSummary extends StatelessWidget {
  const _OrderStatusSummary({required this.values});
  final Map<String, int> values;

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) {
      return const AdminMessageState(
        icon: Icons.receipt_long_outlined,
        title: 'Chưa có đơn hàng',
        message: 'Trạng thái đơn hàng sẽ xuất hiện khi có dữ liệu thật.',
      );
    }
    final total = values.values.fold<int>(0, (sum, value) => sum + value);
    return Column(
      children: values.entries.map((entry) {
        final ratio = total == 0 ? 0.0 : entry.value / total;
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: Row(
            children: [
              SizedBox(width: 100, child: AdminStatusBadge(entry.key)),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: LinearProgressIndicator(
                  value: ratio,
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  backgroundColor: AdminColors.softLavender,
                  color: AdminColors.primaryPurple,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              SizedBox(
                width: 34,
                child: Text('${entry.value}', textAlign: TextAlign.end),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _DataSummary extends StatelessWidget {
  const _DataSummary({required this.data});
  final AdminDashboardData data;

  @override
  Widget build(BuildContext context) {
    final rate = data.totalProducts == 0
        ? 0.0
        : data.aiReadyProducts / data.totalProducts;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Tỷ lệ AI-ready', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        LinearProgressIndicator(
          value: rate,
          minHeight: 10,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          backgroundColor: AdminColors.softLavender,
          color: AdminColors.aiAccent,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text('${(rate * 100).toStringAsFixed(1)}% sản phẩm'),
        const Divider(height: 32),
        Text(
          'Recommendation requests',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          '${data.recommendationRequests}',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
      ],
    );
  }
}

class _RecentOrders extends StatelessWidget {
  const _RecentOrders({required this.orders});
  final List<CustomerOrder> orders;

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return const AdminMessageState(
        icon: Icons.receipt_long_outlined,
        title: 'Chưa có đơn hàng',
        message: 'Đơn hàng mới sẽ xuất hiện tại đây.',
      );
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Mã đơn')),
          DataColumn(label: Text('Khách hàng')),
          DataColumn(label: Text('Tổng')),
          DataColumn(label: Text('Trạng thái')),
          DataColumn(label: Text('Thời gian')),
          DataColumn(label: Text('')),
        ],
        rows: orders
            .map(
              (order) => DataRow(
                cells: [
                  DataCell(Text('#${order.orderId}')),
                  DataCell(Text(order.shippingName)),
                  DataCell(
                    Text(formatMoney(order.totalAmount, order.currency)),
                  ),
                  DataCell(AdminStatusBadge(order.status)),
                  DataCell(
                    Text(
                      order.createdAt?.toLocal().toString().substring(0, 16) ??
                          '—',
                    ),
                  ),
                  DataCell(
                    IconButton(
                      tooltip: 'Xem đơn hàng',
                      onPressed: () =>
                          context.go('/admin/orders/${order.orderId}'),
                      icon: const Icon(Icons.arrow_forward),
                    ),
                  ),
                ],
              ),
            )
            .toList(),
      ),
    );
  }
}
