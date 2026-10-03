import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/design_tokens.dart';
import '../../providers/auth_provider.dart';
import '../../services/backend_api.dart';
import 'admin_components.dart';

class AdminReportsPage extends StatefulWidget {
  const AdminReportsPage({super.key});

  @override
  State<AdminReportsPage> createState() => _AdminReportsPageState();
}

class _AdminReportsPageState extends State<AdminReportsPage> {
  Map<String, dynamic>? data;
  String? error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => load());
  }

  Future<void> load() async {
    final token = context.read<AuthProvider>().accessToken;
    if (token == null) return;
    setState(() => error = null);
    try {
      final value = await context.read<BackendApi>().getAdminReports(token);
      if (mounted) setState(() => data = value);
    } catch (exception) {
      if (mounted) setState(() => error = BackendApi.readableError(exception));
    }
  }

  @override
  Widget build(BuildContext context) {
    final revenue = (data?['revenueTrend'] as List<dynamic>? ?? const []);
    final best = (data?['bestSellers'] as List<dynamic>? ?? const []);
    final low = (data?['lowStock'] as List<dynamic>? ?? const []);
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        AdminPageHeader(
          title: 'Báo cáo',
          subtitle: 'Doanh thu, sản phẩm bán chạy và tồn kho từ dữ liệu đơn hàng thật.',
          actions: [OutlinedButton.icon(onPressed: load, icon: const Icon(Icons.refresh), label: const Text('Làm mới'))],
        ),
        const SizedBox(height: AppSpacing.lg),
        if (error != null) _StateCard(message: error!, onRetry: load)
        else if (data == null) const LinearProgressIndicator()
        else ...[
          AdminSectionCard(
            title: 'Doanh thu theo ngày và tiền tệ',
            child: revenue.isEmpty
                ? const _EmptyText('Chưa có đơn hàng hoàn tất để lập báo cáo.')
                : _ReportTable(columns: const ['Ngày', 'Tiền tệ', 'Đơn', 'Doanh thu'], rows: revenue.map((item) {
                    final row = item as Map<String, dynamic>;
                    return [row['date']?.toString() ?? '—', row['currency']?.toString() ?? '—', '${row['orders'] ?? 0}', '${row['revenue'] ?? 0}'];
                  }).toList()),
          ),
          const SizedBox(height: AppSpacing.md),
          AdminSectionCard(
            title: 'Sản phẩm bán chạy',
            child: best.isEmpty
                ? const _EmptyText('Chưa có sản phẩm trong đơn hoàn tất.')
                : _ReportTable(columns: const ['Sản phẩm', 'SKU', 'Số lượng', 'Doanh thu'], rows: best.map((item) {
                    final row = item as Map<String, dynamic>;
                    return [row['name']?.toString() ?? '—', row['sku']?.toString() ?? '—', '${row['quantity'] ?? 0}', '${row['revenue'] ?? 0} ${row['currency'] ?? ''}'];
                  }).toList()),
          ),
          const SizedBox(height: AppSpacing.md),
          AdminSectionCard(
            title: 'Cảnh báo tồn kho',
            child: low.isEmpty
                ? const _EmptyText('Không có sản phẩm đang ở ngưỡng tồn kho thấp.')
                : _ReportTable(columns: const ['Sản phẩm', 'SKU', 'Tồn kho', 'Trạng thái'], rows: low.map((item) {
                    final row = item as Map<String, dynamic>;
                    return [row['name']?.toString() ?? '—', row['sku']?.toString() ?? '—', '${row['stockQuantity'] ?? 0}', row['status']?.toString() ?? '—'];
                  }).toList()),
          ),
        ],
      ],
    );
  }
}

class AdminBehaviorPage extends StatefulWidget {
  const AdminBehaviorPage({super.key});

  @override
  State<AdminBehaviorPage> createState() => _AdminBehaviorPageState();
}

class _AdminBehaviorPageState extends State<AdminBehaviorPage> {
  Map<String, dynamic>? data;
  String? error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => load());
  }

  Future<void> load() async {
    final token = context.read<AuthProvider>().accessToken;
    if (token == null) return;
    try {
      final value = await context.read<BackendApi>().getAdminBehaviorAnalytics(token);
      if (mounted) setState(() => data = value);
    } catch (exception) {
      if (mounted) setState(() => error = BackendApi.readableError(exception));
    }
  }

  @override
  Widget build(BuildContext context) {
    final events = (data?['events'] as List<dynamic>? ?? const []);
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        AdminPageHeader(title: 'Hành vi người dùng', subtitle: 'Tổng hợp event đã ghi nhận từ khách và phiên truy cập.', actions: [OutlinedButton.icon(onPressed: load, icon: const Icon(Icons.refresh), label: const Text('Làm mới'))]),
        const SizedBox(height: AppSpacing.lg),
        if (error != null) _StateCard(message: error!, onRetry: load)
        else if (data == null) const LinearProgressIndicator()
        else ...[
          Wrap(spacing: AppSpacing.md, runSpacing: AppSpacing.md, children: [
            AdminStatCard(label: 'Tổng event', value: '${data!['totalEvents'] ?? 0}', icon: Icons.insights_outlined),
            AdminStatCard(label: 'User duy nhất', value: '${data!['uniqueUsers'] ?? 0}', icon: Icons.people_outline),
            AdminStatCard(label: 'Session duy nhất', value: '${data!['uniqueSessions'] ?? 0}', icon: Icons.devices_outlined),
          ]),
          const SizedBox(height: AppSpacing.md),
          AdminSectionCard(title: 'Event theo loại', child: events.isEmpty ? const _EmptyText('Chưa có behavior event nào.') : _ReportTable(columns: const ['Event', 'Số lượng', 'Actor'], rows: events.map((item) { final row = item as Map<String, dynamic>; return [row['eventType']?.toString() ?? '—', '${row['count'] ?? 0}', '${row['actors'] ?? 0}']; }).toList())),
        ],
      ],
    );
  }
}

class _ReportTable extends StatelessWidget {
  const _ReportTable({required this.columns, required this.rows});
  final List<String> columns;
  final List<List<String>> rows;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(columns: [for (final column in columns) DataColumn(label: Text(column))], rows: [for (final row in rows) DataRow(cells: [for (final value in row) DataCell(Text(value))])]),
      );
}

class _EmptyText extends StatelessWidget {
  const _EmptyText(this.message);
  final String message;
  @override
  Widget build(BuildContext context) => Text(message, style: Theme.of(context).textTheme.bodyMedium);
}

class _StateCard extends StatelessWidget {
  const _StateCard({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => AdminSectionCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(message), const SizedBox(height: AppSpacing.md), OutlinedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('Thử lại'))]));
}
