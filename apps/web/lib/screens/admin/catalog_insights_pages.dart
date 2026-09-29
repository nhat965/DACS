import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/design_tokens.dart';
import '../../models/product.dart';
import '../../providers/auth_provider.dart';
import '../../providers/catalog_provider.dart';
import '../../services/backend_api.dart';

class AdminCategoriesPage extends StatelessWidget {
  const AdminCategoriesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final products = context.watch<CatalogProvider>().products;
    return _CountList(
      title: 'Danh mục',
      icon: Icons.category_outlined,
      counts: _counts(products.map((item) => item.category)),
    );
  }
}

class AdminBrandsPage extends StatelessWidget {
  const AdminBrandsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final products = context.watch<CatalogProvider>().products;
    return _CountList(
      title: 'Thương hiệu',
      icon: Icons.storefront_outlined,
      counts: _counts(products.map((item) => item.brand)),
    );
  }
}

Map<String, int> _counts(Iterable<String> values) {
  final result = <String, int>{};
  for (final value in values.where((item) => item.trim().isNotEmpty)) {
    result.update(value, (count) => count + 1, ifAbsent: () => 1);
  }
  return Map.fromEntries(
    result.entries.toList()..sort((a, b) => b.value.compareTo(a.value)),
  );
}

class _CountList extends StatelessWidget {
  const _CountList({
    required this.title,
    required this.icon,
    required this.counts,
  });

  final String title;
  final IconData icon;
  final Map<String, int> counts;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Text(title, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: AppSpacing.lg),
        if (counts.isEmpty)
          const _AdminEmpty('Chưa có dữ liệu để hiển thị.')
        else
          ...counts.entries.map(
            (entry) => Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.lavenderMist,
                  child: Icon(icon, color: AppColors.plum),
                ),
                title: Text(entry.key),
                trailing: Text('${entry.value} sản phẩm'),
              ),
            ),
          ),
      ],
    );
  }
}

class DataQualityPage extends StatelessWidget {
  const DataQualityPage({super.key});

  @override
  Widget build(BuildContext context) {
    final products = context.watch<CatalogProvider>().products;
    final total = products.length;
    int covered(bool Function(Product product) test) =>
        products.where(test).length;
    String rate(int count) =>
        total == 0 ? '—' : '${(count * 100 / total).toStringAsFixed(1)}%';
    final metrics = <String, String>{
      'Tổng sản phẩm': '$total',
      'INCI coverage': rate(covered((p) => p.inciIngredients.isNotEmpty)),
      'Skin type coverage': rate(covered((p) => p.skinTypes.isNotEmpty)),
      'Concern coverage': rate(covered((p) => p.skinConcerns.isNotEmpty)),
      'Care goal coverage': rate(covered((p) => p.careGoals.isNotEmpty)),
      'Image coverage': rate(covered((p) => p.image.isNotEmpty)),
      'Price coverage': rate(covered((p) => p.price > 0)),
    };
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Text('Data Quality', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: AppSpacing.lg),
        LayoutBuilder(
          builder: (context, constraints) => GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: constraints.maxWidth >= 900
                ? 4
                : constraints.maxWidth >= 520
                ? 2
                : 1,
            childAspectRatio: 2.2,
            crossAxisSpacing: AppSpacing.md,
            mainAxisSpacing: AppSpacing.md,
            children: metrics.entries
                .map(
                  (entry) => Card(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(entry.key),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            entry.value,
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                        ],
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }
}

class AdminMetricPage extends StatefulWidget {
  const AdminMetricPage({super.key, required this.kind});

  final AdminMetricKind kind;

  @override
  State<AdminMetricPage> createState() => _AdminMetricPageState();
}

enum AdminMetricKind { users, recommendations }

class _AdminMetricPageState extends State<AdminMetricPage> {
  Map<String, int>? metrics;
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
      final value = await context.read<BackendApi>().getAdminMetrics(token);
      if (mounted) setState(() => metrics = value);
    } catch (exception) {
      if (mounted) setState(() => error = BackendApi.readableError(exception));
    }
  }

  @override
  Widget build(BuildContext context) {
    final users = widget.kind == AdminMetricKind.users;
    final title = users ? 'Người dùng' : 'Recommendation Analytics';
    final value = users
        ? (metrics?['users'])
        : (metrics?['recommendationRequests']);
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Text(title, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: AppSpacing.lg),
        if (error != null)
          _AdminEmpty(error!)
        else if (metrics == null)
          const LinearProgressIndicator()
        else ...[
          Card(
            child: ListTile(
              leading: Icon(
                users ? Icons.people_outline : Icons.auto_awesome_outlined,
                color: AppColors.plum,
              ),
              title: Text(
                users ? 'Tổng người dùng' : 'Recommendation requests',
              ),
              trailing: Text(
                value?.toString() ?? '—',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _AdminEmpty(
            users
                ? 'Danh sách chi tiết sẽ hiển thị khi API quản lý người dùng sẵn sàng.'
                : 'Chưa có đủ dữ liệu click và CTR để dựng biểu đồ đáng tin cậy.',
          ),
        ],
      ],
    );
  }
}

class _AdminEmpty extends StatelessWidget {
  const _AdminEmpty(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Text(message, textAlign: TextAlign.center),
      ),
    );
  }
}
