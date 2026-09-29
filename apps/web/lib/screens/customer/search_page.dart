import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/design_tokens.dart';
import '../../models/product.dart';
import '../../providers/catalog_provider.dart';
import '../../providers/recommendation_provider.dart';
import '../../services/backend_api.dart';
import '../../widgets/app_header.dart';
import '../../widgets/product_card.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({
    super.key,
    this.initialQuery = '',
    this.initialConcern,
    this.initialGoal,
  });

  final String initialQuery;
  final String? initialConcern;
  final String? initialGoal;

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  static const pageSize = 24;

  final controller = TextEditingController();
  Timer? debounce;
  List<Product> products = const [];
  int total = 0;
  int offset = 0;
  bool loading = false;
  String? error;
  String? category;
  String? brand;
  String? concern;
  String? goal;
  String sort = 'name_asc';
  bool initialized = false;

  @override
  void initState() {
    super.initState();
    controller.text = widget.initialQuery;
    concern = widget.initialConcern;
    goal = widget.initialGoal;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!initialized) {
      initialized = true;
      load();
    }
  }

  @override
  void didUpdateWidget(covariant SearchPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialQuery != widget.initialQuery ||
        oldWidget.initialConcern != widget.initialConcern ||
        oldWidget.initialGoal != widget.initialGoal) {
      controller.text = widget.initialQuery;
      concern = widget.initialConcern;
      goal = widget.initialGoal;
      offset = 0;
      load();
    }
  }

  @override
  void dispose() {
    debounce?.cancel();
    controller.dispose();
    super.dispose();
  }

  void onQueryChanged(String value) {
    debounce?.cancel();
    debounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      offset = 0;
      final query = value.trim();
      _syncRoute(query: query);
      load(trackSearch: query.isNotEmpty);
    });
  }

  void _syncRoute({String? query}) {
    final parameters = <String, String>{
      if ((query ?? controller.text).trim().isNotEmpty)
        'q': (query ?? controller.text).trim(),
      if (concern != null && concern!.isNotEmpty) 'concern': concern!,
      if (goal != null && goal!.isNotEmpty) 'goal': goal!,
    };
    context.replace(
      Uri(
        path: '/search',
        queryParameters: parameters.isEmpty ? null : parameters,
      ).toString(),
    );
  }

  Future<void> load({bool trackSearch = false}) async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final page = await context.read<BackendApi>().getProductPage(
        search: controller.text,
        category: category,
        brand: brand,
        concern: concern,
        goal: goal,
        sort: sort,
        limit: pageSize,
        offset: offset,
      );
      if (!mounted) return;
      setState(() {
        products = page.items;
        total = page.total;
      });
      if (trackSearch) {
        context.read<RecommendationProvider>().track(
          eventType: 'search_keyword',
          metadata: {
            'query': controller.text.trim(),
            'resultCount': page.total,
          },
        );
      }
    } catch (exception) {
      if (!mounted) return;
      setState(() => error = BackendApi.readableError(exception));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> applyFilter({String? nextCategory, String? nextBrand}) async {
    setState(() {
      category = nextCategory;
      brand = nextBrand;
      offset = 0;
    });
    context.read<RecommendationProvider>().track(
      eventType: 'filter_used',
      metadata: {'category': category, 'brand': brand, 'sort': sort},
    );
    _syncRoute();
    await load();
  }

  void clearAll() {
    controller.clear();
    setState(() {
      category = null;
      brand = null;
      concern = null;
      goal = null;
      sort = 'name_asc';
      offset = 0;
    });
    context.replace('/search');
    load();
  }

  @override
  Widget build(BuildContext context) {
    final catalog = context.watch<CatalogProvider>();
    final categories =
        catalog.products.map((item) => item.category).toSet().toList()..sort();
    final brands =
        catalog.products
            .map((item) => item.brand)
            .where((item) => item.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    return Scaffold(
      body: Column(
        children: [
          const AppHeader(),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final mobile = constraints.maxWidth < AppBreakpoints.navigation;
                final content = _SearchResults(
                  controller: controller,
                  products: products,
                  total: total,
                  offset: offset,
                  loading: loading,
                  error: error,
                  category: category,
                  brand: brand,
                  concern: concern,
                  goal: goal,
                  sort: sort,
                  mobile: mobile,
                  onQueryChanged: onQueryChanged,
                  onRetry: load,
                  onClear: clearAll,
                  onPrevious: offset <= 0
                      ? null
                      : () {
                          setState(
                            () => offset = (offset - pageSize).clamp(0, total),
                          );
                          load();
                        },
                  onNext: offset + products.length >= total
                      ? null
                      : () {
                          setState(() => offset += pageSize);
                          load();
                        },
                  onSort: (value) {
                    setState(() {
                      sort = value;
                      offset = 0;
                    });
                    applyFilter(nextCategory: category, nextBrand: brand);
                  },
                  onOpenFilters: () =>
                      _showFilters(context, categories, brands),
                );
                if (mobile) return content;
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 280,
                      child: _FilterPanel(
                        categories: categories,
                        brands: brands,
                        category: category,
                        brand: brand,
                        onApply: applyFilter,
                        onClear: clearAll,
                      ),
                    ),
                    Expanded(child: content),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showFilters(
    BuildContext context,
    List<String> categories,
    List<String> brands,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: _FilterPanel(
          categories: categories,
          brands: brands,
          category: category,
          brand: brand,
          onApply: ({nextCategory, nextBrand}) async {
            Navigator.of(sheetContext).pop();
            await applyFilter(nextCategory: nextCategory, nextBrand: nextBrand);
          },
          onClear: () {
            Navigator.of(sheetContext).pop();
            clearAll();
          },
        ),
      ),
    );
  }
}

typedef ApplyFilter = Future<void> Function({
  String? nextCategory,
  String? nextBrand,
});

class _FilterPanel extends StatelessWidget {
  const _FilterPanel({
    required this.categories,
    required this.brands,
    required this.category,
    required this.brand,
    required this.onApply,
    required this.onClear,
  });

  final List<String> categories;
  final List<String> brands;
  final String? category;
  final String? brand;
  final ApplyFilter onApply;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Bộ lọc',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              TextButton(onPressed: onClear, child: const Text('Xóa tất cả')),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text('Danh mục', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          ...categories.map(
            (value) => ListTile(
              selected: category == value,
              leading: Icon(
                category == value
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
              ),
              title: Text(value.replaceAll('_', ' ')),
              contentPadding: EdgeInsets.zero,
              onTap: () => onApply(nextCategory: value, nextBrand: brand),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text('Thương hiệu', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          ...brands.map(
            (value) => ListTile(
              selected: brand == value,
              leading: Icon(
                brand == value
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
              ),
              title: Text(value),
              contentPadding: EdgeInsets.zero,
              onTap: () => onApply(nextCategory: category, nextBrand: value),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchResults extends StatelessWidget {
  const _SearchResults({
    required this.controller,
    required this.products,
    required this.total,
    required this.offset,
    required this.loading,
    required this.error,
    required this.category,
    required this.brand,
    required this.concern,
    required this.goal,
    required this.sort,
    required this.mobile,
    required this.onQueryChanged,
    required this.onRetry,
    required this.onClear,
    required this.onPrevious,
    required this.onNext,
    required this.onSort,
    required this.onOpenFilters,
  });

  final TextEditingController controller;
  final List<Product> products;
  final int total;
  final int offset;
  final bool loading;
  final String? error;
  final String? category;
  final String? brand;
  final String? concern;
  final String? goal;
  final String sort;
  final bool mobile;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onRetry;
  final VoidCallback onClear;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final ValueChanged<String> onSort;
  final VoidCallback onOpenFilters;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppBreakpoints.content),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tìm sản phẩm',
                style: Theme.of(context).textTheme.displaySmall,
              ),
              const SizedBox(height: AppSpacing.lg),
              TextField(
                controller: controller,
                onChanged: onQueryChanged,
                onSubmitted: (_) => onQueryChanged(controller.text),
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Tên sản phẩm, thương hiệu, danh mục…',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: controller.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Xóa từ khóa',
                          onPressed: onClear,
                          icon: const Icon(Icons.clear),
                        ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (mobile)
                    OutlinedButton.icon(
                      onPressed: onOpenFilters,
                      icon: const Icon(Icons.tune),
                      label: const Text('Bộ lọc'),
                    ),
                  SizedBox(
                    width: 210,
                    child: DropdownButtonFormField<String>(
                      initialValue: sort,
                      decoration: const InputDecoration(labelText: 'Sắp xếp'),
                      items: const [
                        DropdownMenuItem(
                          value: 'name_asc',
                          child: Text('Tên A–Z'),
                        ),
                        DropdownMenuItem(
                          value: 'price_asc',
                          child: Text('Giá tăng dần'),
                        ),
                        DropdownMenuItem(
                          value: 'price_desc',
                          child: Text('Giá giảm dần'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) onSort(value);
                      },
                    ),
                  ),
                  if (category != null)
                    Chip(label: Text(category!.replaceAll('_', ' '))),
                  if (brand != null) Chip(label: Text(brand!)),
                  if (concern != null)
                    Chip(label: Text(_friendlyFilterLabel(concern!))),
                  if (goal != null)
                    Chip(label: Text(_friendlyFilterLabel(goal!))),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                '$total sản phẩm',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.lg),
              if (loading)
                const _SearchSkeleton()
              else if (error != null)
                _SearchMessage(
                  icon: Icons.cloud_off_outlined,
                  title: 'Không thể tải kết quả',
                  message: error!,
                  action: 'Thử lại',
                  onAction: onRetry,
                )
              else if (products.isEmpty)
                _SearchMessage(
                  icon: Icons.search_off_outlined,
                  title: 'Không tìm thấy sản phẩm phù hợp.',
                  message: 'Thử từ khóa khác hoặc xóa bộ lọc hiện tại.',
                  action: 'Xóa bộ lọc',
                  onAction: onClear,
                )
              else ...[
                LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = constraints.maxWidth >= 1100
                        ? 4
                        : constraints.maxWidth >= 720
                        ? 3
                        : constraints.maxWidth >= 320
                        ? 2
                        : 1;
                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: products.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        crossAxisSpacing: AppSpacing.md,
                        mainAxisSpacing: AppSpacing.lg,
                        childAspectRatio: columns == 1 ? 0.9 : 0.64,
                      ),
                      itemBuilder: (context, index) =>
                          ProductCard(product: products[index]),
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.xl),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    OutlinedButton(
                      onPressed: onPrevious,
                      child: const Text('Trang trước'),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                      ),
                      child: Text(
                        '${offset + 1}–${offset + products.length} / $total',
                      ),
                    ),
                    FilledButton(
                      onPressed: onNext,
                      child: const Text('Trang sau'),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

String _friendlyFilterLabel(String value) {
  const labels = <String, String>{
    'acne': 'Da mụn',
    'oiliness': 'Da dầu',
    'dryness': 'Da khô',
    'sensitivity': 'Da nhạy cảm',
    'dark_spot': 'Thâm & không đều màu',
    'aging': 'Lão hóa',
    'repair': 'Phục hồi',
    'hydrate': 'Cấp ẩm',
  };
  return labels[value] ?? value.replaceAll('_', ' ');
}

class _SearchSkeleton extends StatelessWidget {
  const _SearchSkeleton();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.md,
      children: List.generate(
        8,
        (_) => Container(
          width: 220,
          height: 330,
          decoration: BoxDecoration(
            color: AppColors.paleRose,
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
        ),
      ),
    );
  }
}

class _SearchMessage extends StatelessWidget {
  const _SearchMessage({
    required this.icon,
    required this.title,
    required this.message,
    required this.action,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String action;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.section),
        child: Column(
          children: [
            Icon(icon, size: 52, color: AppColors.mutedInk),
            const SizedBox(height: AppSpacing.md),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.lg),
            OutlinedButton(onPressed: onAction, child: Text(action)),
          ],
        ),
      ),
    );
  }
}
