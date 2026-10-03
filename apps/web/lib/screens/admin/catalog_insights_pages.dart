import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/design_tokens.dart';
import '../../providers/auth_provider.dart';
import '../../providers/catalog_provider.dart';
import '../../services/backend_api.dart';
import 'admin_components.dart';

class AdminCategoriesPage extends StatelessWidget {
  const AdminCategoriesPage({super.key});

  @override
  Widget build(BuildContext context) => const _CatalogGroupPage(
    title: 'Danh mục',
    subtitle: 'Chọn một danh mục để xem toàn bộ sản phẩm thuộc nhóm đó.',
    icon: Icons.category_outlined,
    useBrand: false,
  );
}

class AdminBrandsPage extends StatelessWidget {
  const AdminBrandsPage({super.key});

  @override
  Widget build(BuildContext context) => const _CatalogGroupPage(
    title: 'Thương hiệu',
    subtitle: 'Chọn một thương hiệu để xem danh sách sản phẩm tương ứng.',
    icon: Icons.storefront_outlined,
    useBrand: true,
  );
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

class _CatalogGroupPage extends StatefulWidget {
  const _CatalogGroupPage({required this.title, required this.subtitle, required this.icon, required this.useBrand});

  final String title;
  final String subtitle;
  final IconData icon;
  final bool useBrand;

  @override
  State<_CatalogGroupPage> createState() => _CatalogGroupPageState();
}

class _CatalogGroupPageState extends State<_CatalogGroupPage> {
  String? selected;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CatalogProvider>().loadProducts();
    });
  }

  @override
  Widget build(BuildContext context) {
    final catalog = context.watch<CatalogProvider>();
    final products = catalog.products;
    final groups = _counts(products.map((item) => widget.useBrand ? item.brand : item.category));
    final selectedProducts = selected == null
        ? const []
        : products.where((product) => (widget.useBrand ? product.brand : product.category) == selected).toList();
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Text(widget.title, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: AppSpacing.xs),
        Text(widget.subtitle),
        const SizedBox(height: AppSpacing.lg),
        if (catalog.isLoading && products.isEmpty)
          const LinearProgressIndicator()
        else if (catalog.errorMessage != null)
          _AdminEmpty(catalog.errorMessage!)
        else if (groups.isEmpty)
          const _AdminEmpty('Chưa có dữ liệu để hiển thị.')
        else
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: groups.entries.map((entry) => ChoiceChip(
              selected: selected == entry.key,
              avatar: Icon(widget.icon, size: 18),
              label: Text('${entry.key} (${entry.value})'),
              onSelected: (_) => setState(() => selected = entry.key),
            )).toList(),
          ),
        if (selected != null) ...[
          const SizedBox(height: AppSpacing.lg),
          AdminSectionCard(
            title: '$selected (${selectedProducts.length} sản phẩm)',
            child: selectedProducts.isEmpty
                ? const _AdminEmpty('Không có sản phẩm trong mục này.')
                : Column(
                    children: selectedProducts.map((product) => ListTile(
                      leading: SizedBox(width: 52, height: 52, child: product.image.isEmpty ? const Icon(Icons.image_not_supported_outlined) : Image.network(product.image, fit: BoxFit.cover, errorBuilder: (_, _, _) => const Icon(Icons.broken_image_outlined))),
                      title: Text(product.name, maxLines: 2, overflow: TextOverflow.ellipsis),
                      subtitle: Text('${product.sku} · ${product.currency} ${product.price.toStringAsFixed(2)}'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.go('/admin/products/${product.id}'),
                    )).toList(),
                  ),
          ),
        ],
      ],
    );
  }
}

class DataQualityPage extends StatefulWidget {
  const DataQualityPage({super.key});

  @override
  State<DataQualityPage> createState() => _DataQualityPageState();
}

class _DataQualityPageState extends State<DataQualityPage> {
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
    setState(() => error = null);
    try {
      final value = await context.read<BackendApi>().getAdminDataQuality(token);
      if (mounted) setState(() => metrics = value);
    } catch (exception) {
      if (mounted) setState(() => error = BackendApi.readableError(exception));
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = metrics?['totalProducts'] ?? 0;
    String rate(String key) => total == 0
        ? '—'
        : '${((metrics?[key] ?? 0) * 100 / total).toStringAsFixed(1)}%';
    final values = <String, String>{
      'Tổng sản phẩm': metrics == null ? '—' : '$total',
      'AI-ready': rate('aiReadyProducts'),
      'INCI coverage': rate('inciComplete'),
      'Skin type coverage': rate('skinTypeComplete'),
      'Concern coverage': rate('concernComplete'),
      'Care goal coverage': rate('careGoalComplete'),
      'Image coverage': rate('imageComplete'),
      'Price coverage': rate('priceComplete'),
    };
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Text('Data Quality', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: AppSpacing.lg),
        if (error != null)
          _AdminEmpty(error!)
        else if (metrics == null)
          const LinearProgressIndicator()
        else
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
              children: values.entries
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
  Map<String, dynamic>? recommendationData;
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
      if (widget.kind == AdminMetricKind.recommendations) {
        final value = await context.read<BackendApi>().getAdminRecommendationAnalytics(token);
        if (mounted) setState(() => recommendationData = value);
      } else {
        final value = await context.read<BackendApi>().getAdminMetrics(token);
        if (mounted) setState(() => metrics = value);
      }
    } catch (exception) {
      if (mounted) setState(() => error = BackendApi.readableError(exception));
    }
  }

  @override
  Widget build(BuildContext context) {
    final users = widget.kind == AdminMetricKind.users;
    final title = users ? 'Người dùng' : 'Recommendation Analytics';
    final value = users ? (metrics?['users']) : (recommendationData?['totalRequests']);
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Text(title, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: AppSpacing.lg),
        if (error != null)
          _AdminEmpty(error!)
        else if (users ? metrics == null : recommendationData == null)
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
          if (!users) ...[
            Card(
              child: ListTile(
                leading: const Icon(Icons.auto_awesome_outlined, color: AppColors.plum),
                title: const Text('Kết quả recommendation'),
                trailing: Text('${recommendationData?['totalResults'] ?? 0}'),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _AdminEmpty(recommendationData?['clickThroughRateNote']?.toString() ?? 'Chưa có dữ liệu CTR.'),
          ] else
            const _AdminEmpty('Danh sách chi tiết sẽ hiển thị khi API quản lý người dùng sẵn sàng.'),
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
