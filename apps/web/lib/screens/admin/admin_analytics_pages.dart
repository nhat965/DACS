import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/design_tokens.dart';
import '../../providers/auth_provider.dart';
import '../../services/backend_api.dart';
import '../../utils/catalog_localization.dart';
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
    final totalOrders = revenue.fold<int>(
      0,
      (sum, item) => sum + _asInt((item as Map<String, dynamic>)['orders']),
    );
    final totalRevenue = revenue.fold<double>(
      0,
      (sum, item) => sum + _asDouble((item as Map<String, dynamic>)['revenue']),
    );
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        AdminPageHeader(
          title: 'Báo cáo',
          subtitle: 'Doanh thu, sản phẩm bán chạy và tồn kho từ dữ liệu đơn hàng thật.',
          actions: [
            OutlinedButton.icon(
              onPressed: load,
              icon: const Icon(Icons.refresh),
              label: const Text('Làm mới'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        if (error != null)
          _StateCard(message: error!, onRetry: load)
        else if (data == null)
          const LinearProgressIndicator()
        else ...[
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.md,
            children: [
              AdminStatCard(
                label: 'Đơn hoàn tất',
                value: '$totalOrders',
                icon: Icons.receipt_long_outlined,
                color: AdminColors.info,
              ),
              AdminStatCard(
                label: 'Điểm dữ liệu doanh thu',
                value: '${revenue.length}',
                icon: Icons.timeline_outlined,
                color: AdminColors.primaryPurple,
              ),
              AdminStatCard(
                label: 'Tổng doanh thu hiển thị',
                value: totalRevenue.toStringAsFixed(0),
                icon: Icons.payments_outlined,
                color: AdminColors.success,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 900;
              final chartWidth = wide
                  ? (constraints.maxWidth - AppSpacing.md) / 2
                  : constraints.maxWidth;
              return Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.md,
                children: [
                  SizedBox(
                    width: chartWidth,
                    child: AdminSectionCard(
                      title: 'Xu hướng doanh thu',
                      trailing: const Icon(
                        Icons.show_chart,
                        color: AdminColors.primaryPurple,
                      ),
                      child: revenue.isEmpty
                          ? const _EmptyText('Chưa có dữ liệu để vẽ biểu đồ.')
                          : _RevenueChart(rows: revenue),
                    ),
                  ),
                  SizedBox(
                    width: chartWidth,
                    child: AdminSectionCard(
                      title: 'Top sản phẩm theo số lượng',
                      trailing: const Icon(
                        Icons.bar_chart,
                        color: AdminColors.lumiPink,
                      ),
                      child: best.isEmpty
                          ? const _EmptyText(
                              'Chưa có sản phẩm trong đơn hoàn tất.',
                            )
                          : _HorizontalBarChart(
                              rows: best.take(8).map((item) {
                                final row = item as Map<String, dynamic>;
                                return _ChartRow(
                                  label: row['name']?.toString() ?? '—',
                                  value: _asDouble(row['quantity']),
                                  detail: '${row['quantity'] ?? 0} sản phẩm',
                                );
                              }).toList(),
                              color: AdminColors.lumiPink,
                            ),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: AppSpacing.lg),
          AdminSectionCard(
            title: 'Doanh thu theo ngày và tiền tệ',
            child: revenue.isEmpty
                ? const _EmptyText('Chưa có đơn hàng hoàn tất để lập báo cáo.')
                : _ReportTable(
                    columns: const ['Ngày', 'Tiền tệ', 'Đơn', 'Doanh thu'],
                    rows: revenue.map((item) {
                      final row = item as Map<String, dynamic>;
                      return [
                        row['date']?.toString() ?? '—',
                        catalogCurrencyLabel(
                          row['currency']?.toString() ?? '—',
                        ),
                        '${row['orders'] ?? 0}',
                        '${row['revenue'] ?? 0}',
                      ];
                    }).toList(),
                  ),
          ),
          const SizedBox(height: AppSpacing.md),
          AdminSectionCard(
            title: 'Sản phẩm bán chạy',
            child: best.isEmpty
                ? const _EmptyText('Chưa có sản phẩm trong đơn hoàn tất.')
                : _ReportTable(
                    columns: const ['Sản phẩm', 'SKU', 'Số lượng', 'Doanh thu'],
                    rows: best.map((item) {
                      final row = item as Map<String, dynamic>;
                      return [
                        row['name']?.toString() ?? '—',
                        row['sku']?.toString() ?? '—',
                        '${row['quantity'] ?? 0}',
                        '${row['revenue'] ?? 0} ${catalogCurrencyLabel(row['currency']?.toString() ?? '')}',
                      ];
                    }).toList(),
                  ),
          ),
          const SizedBox(height: AppSpacing.md),
          AdminSectionCard(
            title: 'Cảnh báo tồn kho',
            child: low.isEmpty
                ? const _EmptyText(
                    'Không có sản phẩm đang ở ngưỡng tồn kho thấp.',
                  )
                : _ReportTable(
                    columns: const ['Sản phẩm', 'SKU', 'Tồn kho', 'Trạng thái'],
                    rows: low.map((item) {
                      final row = item as Map<String, dynamic>;
                      return [
                        row['name']?.toString() ?? '—',
                        row['sku']?.toString() ?? '—',
                        '${row['stockQuantity'] ?? 0}',
                        row['status']?.toString() ?? '—',
                      ];
                    }).toList(),
                  ),
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
      final value = await context.read<BackendApi>().getAdminBehaviorAnalytics(
        token,
      );
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
        AdminPageHeader(
          title: 'Hành vi người dùng',
          subtitle: 'Tổng hợp event đã ghi nhận từ khách và phiên truy cập.',
          actions: [
            OutlinedButton.icon(
              onPressed: load,
              icon: const Icon(Icons.refresh),
              label: const Text('Làm mới'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        if (error != null)
          _StateCard(message: error!, onRetry: load)
        else if (data == null)
          const LinearProgressIndicator()
        else ...[
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.md,
            children: [
              AdminStatCard(
                label: 'Tổng event',
                value: '${data!['totalEvents'] ?? 0}',
                icon: Icons.insights_outlined,
              ),
              AdminStatCard(
                label: 'User duy nhất',
                value: '${data!['uniqueUsers'] ?? 0}',
                icon: Icons.people_outline,
              ),
              AdminStatCard(
                label: 'Session duy nhất',
                value: '${data!['uniqueSessions'] ?? 0}',
                icon: Icons.devices_outlined,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          AdminSectionCard(
            title: 'Event theo loại',
            child: events.isEmpty
                ? const _EmptyText('Chưa có behavior event nào.')
                : _ReportTable(
                    columns: const ['Event', 'Số lượng', 'Actor'],
                    rows: events.map((item) {
                      final row = item as Map<String, dynamic>;
                      return [
                        row['eventType']?.toString() ?? '—',
                        '${row['count'] ?? 0}',
                        '${row['actors'] ?? 0}',
                      ];
                    }).toList(),
                  ),
          ),
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
    child: DataTable(
      columns: [for (final column in columns) DataColumn(label: Text(column))],
      rows: [
        for (final row in rows)
          DataRow(cells: [for (final value in row) DataCell(Text(value))]),
      ],
    ),
  );
}

double _asDouble(Object? value) => value is num
    ? value.toDouble()
    : double.tryParse(value?.toString() ?? '') ?? 0;

int _asInt(Object? value) => _asDouble(value).round();

class _ChartRow {
  const _ChartRow({
    required this.label,
    required this.value,
    required this.detail,
  });

  final String label;
  final double value;
  final String detail;
}

class _RevenueChart extends StatelessWidget {
  const _RevenueChart({required this.rows});

  final List<dynamic> rows;

  @override
  Widget build(BuildContext context) {
    final chartRows = rows.map((item) {
      final row = item as Map<String, dynamic>;
      return _ChartRow(
        label: '${row['date'] ?? '—'} · ${row['currency'] ?? ''}',
        value: _asDouble(row['revenue']),
        detail: '${row['orders'] ?? 0} đơn',
      );
    }).toList();
    final currencies = rows
        .map(
          (item) =>
              (item as Map<String, dynamic>)['currency']?.toString() ?? '',
        )
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 248,
          child: CustomPaint(painter: _RevenuePainter(rows: chartRows)),
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.xs,
          children: [
            for (final currency in currencies)
              _ChartLegend(label: currency, color: AdminColors.primaryPurple),
          ],
        ),
      ],
    );
  }
}

class _HorizontalBarChart extends StatelessWidget {
  const _HorizontalBarChart({required this.rows, required this.color});

  final List<_ChartRow> rows;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final maxValue = rows.fold<double>(
      1,
      (max, row) => row.value > max ? row.value : max,
    );
    return SizedBox(
      height: 272,
      child: Column(
        children: [
          for (final row in rows) ...[
            _ChartBar(row: row, color: color, maxValue: maxValue),
            const SizedBox(height: AppSpacing.sm),
          ],
        ],
      ),
    );
  }
}

class _ChartBar extends StatelessWidget {
  const _ChartBar({
    required this.row,
    required this.color,
    required this.maxValue,
  });

  final _ChartRow row;
  final Color color;
  final double maxValue;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Row(
          children: [
            SizedBox(
              width: constraints.maxWidth * .38,
              child: Text(
                row.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: AdminColors.textPrimary),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Stack(
                alignment: Alignment.centerLeft,
                children: [
                  Container(
                    height: 10,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                  ),
                  FractionallySizedBox(
                    widthFactor: (row.value / maxValue).clamp(.08, 1),
                    child: Container(
                      height: 10,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            SizedBox(
              width: 58,
              child: Text(
                row.detail,
                textAlign: TextAlign.right,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AdminColors.textSecondary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ChartLegend extends StatelessWidget {
  const _ChartLegend({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: AppSpacing.xs),
      Text(
        label,
        style: Theme.of(context).textTheme.labelSmall
            ?.copyWith(color: AdminColors.textSecondary),
      ),
    ],
  );
}

class _RevenuePainter extends CustomPainter {
  _RevenuePainter({required this.rows});

  final List<_ChartRow> rows;

  @override
  void paint(Canvas canvas, Size size) {
    if (rows.isEmpty) return;
    const left = 8.0;
    const top = 12.0;
    const bottom = 30.0;
    final chartHeight = size.height - top - bottom;
    final maxValue = rows
        .map((row) => row.value)
        .fold<double>(1, (max, value) => value > max ? value : max);
    final gridPaint = Paint()
      ..color = AdminColors.border.withValues(alpha: .75)
      ..strokeWidth = 1;
    final barPaint = Paint()..color = AdminColors.primaryPurple;
    final slot = (size.width - left * 2) / rows.length;
    for (var i = 0; i < 3; i++) {
      final y = top + chartHeight * i / 2;
      canvas.drawLine(Offset(left, y), Offset(size.width - left, y), gridPaint);
    }
    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      final barHeight = chartHeight * row.value / maxValue;
      final x = left + i * slot + slot * .22;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, top + chartHeight - barHeight, slot * .56, barHeight),
        const Radius.circular(6),
      );
      canvas.drawRRect(rect, barPaint);
      if (rows.length <= 10 || i % 2 == 0) {
        final label = row.label
            .split(' · ')
            .first
            .substring(0, row.label.split(' · ').first.length.clamp(0, 10));
        _drawText(
          canvas,
          label,
          Offset(x, size.height - 22),
          color: AdminColors.textSecondary,
          size: 10,
        );
      }
    }
  }

  void _drawText(
    Canvas canvas,
    String value,
    Offset offset, {
    required Color color,
    required double size,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: value,
        style: TextStyle(color: color, fontSize: size),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout(maxWidth: 72);
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _RevenuePainter oldDelegate) =>
      oldDelegate.rows != rows;
}

class _EmptyText extends StatelessWidget {
  const _EmptyText(this.message);
  final String message;
  @override
  Widget build(BuildContext context) =>
      Text(message, style: Theme.of(context).textTheme.bodyMedium);
}

class _StateCard extends StatelessWidget {
  const _StateCard({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => AdminSectionCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(message),
        const SizedBox(height: AppSpacing.md),
        OutlinedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: const Text('Thử lại'),
        ),
      ],
    ),
  );
}
