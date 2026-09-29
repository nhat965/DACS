import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/design_tokens.dart';
import '../../providers/catalog_provider.dart';
import '../../utils/money.dart';
import '../../widgets/lumi_states.dart';

class ProductsPage extends StatefulWidget {
  const ProductsPage({super.key});

  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
  static const pageSize = 20;
  final searchController = TextEditingController();
  String query = '';
  String? category;
  String? brand;
  int page = 0;

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final catalog = context.watch<CatalogProvider>();
    if (catalog.isLoading && catalog.products.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: LumiProductGridSkeleton(count: 6),
      );
    }
    if (catalog.errorMessage != null && catalog.products.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(catalog.errorMessage!),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => catalog.loadProducts(force: true),
              child: const Text('Thử lại'),
            ),
          ],
        ),
      );
    }
    final categories =
        catalog.products.map((item) => item.category).toSet().toList()..sort();
    final brands = catalog.products.map((item) => item.brand).toSet().toList()
      ..sort();
    final filtered = catalog.products.where((product) {
      final term = query.toLowerCase();
      return (term.isEmpty ||
              product.name.toLowerCase().contains(term) ||
              product.sku.toLowerCase().contains(term)) &&
          (category == null || product.category == category) &&
          (brand == null || product.brand == brand);
    }).toList();
    final maxPage = filtered.isEmpty ? 0 : (filtered.length - 1) ~/ pageSize;
    if (page > maxPage) page = maxPage;
    final start = page * pageSize;
    final visible = filtered.skip(start).take(pageSize).toList();
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: [
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.md,
            children: [
              SizedBox(
                width: 300,
                child: TextField(
                  controller: searchController,
                  decoration: const InputDecoration(
                    hintText: 'Tìm tên hoặc SKU…',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (value) => setState(() {
                    query = value.trim();
                    page = 0;
                  }),
                ),
              ),
              SizedBox(
                width: 210,
                child: DropdownButtonFormField<String?>(
                  initialValue: category,
                  decoration: const InputDecoration(labelText: 'Danh mục'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Tất cả')),
                    ...categories.map(
                      (value) =>
                          DropdownMenuItem(value: value, child: Text(value)),
                    ),
                  ],
                  onChanged: (value) => setState(() {
                    category = value;
                    page = 0;
                  }),
                ),
              ),
              SizedBox(
                width: 210,
                child: DropdownButtonFormField<String?>(
                  initialValue: brand,
                  decoration: const InputDecoration(labelText: 'Thương hiệu'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Tất cả')),
                    ...brands.map(
                      (value) =>
                          DropdownMenuItem(value: value, child: Text(value)),
                    ),
                  ],
                  onChanged: (value) => setState(() {
                    brand = value;
                    page = 0;
                  }),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: Card(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SingleChildScrollView(
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('ID')),
                      DataColumn(label: Text('Sản phẩm')),
                      DataColumn(label: Text('SKU')),
                      DataColumn(label: Text('Thương hiệu')),
                      DataColumn(label: Text('Danh mục')),
                      DataColumn(label: Text('Giá')),
                      DataColumn(label: Text('Tồn kho')),
                      DataColumn(label: Text('AI-ready')),
                      DataColumn(label: Text('Thao tác')),
                    ],
                    rows: visible
                        .map(
                          (product) => DataRow(
                            cells: [
                              DataCell(Text('${product.id}')),
                              DataCell(
                                SizedBox(
                                  width: 260,
                                  child: Text(
                                    product.name,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                              DataCell(
                                Text(product.sku.isEmpty ? '—' : product.sku),
                              ),
                              DataCell(Text(product.brand)),
                              DataCell(Text(product.category)),
                              DataCell(
                                Text(
                                  formatMoney(product.price, product.currency),
                                ),
                              ),
                              DataCell(Text(product.stock?.toString() ?? '—')),
                              DataCell(
                                Icon(
                                  product.skinConcerns.isNotEmpty &&
                                          product.careGoals.isNotEmpty
                                      ? Icons.check_circle
                                      : Icons.remove_circle_outline,
                                  color:
                                      product.skinConcerns.isNotEmpty &&
                                          product.careGoals.isNotEmpty
                                      ? AppColors.success
                                      : AppColors.mutedInk,
                                ),
                              ),
                              DataCell(
                                IconButton(
                                  tooltip: 'Xem sản phẩm',
                                  onPressed: () =>
                                      context.go('/product/${product.id}'),
                                  icon: const Icon(Icons.visibility_outlined),
                                ),
                              ),
                            ],
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                '${filtered.length} sản phẩm · Trang ${page + 1}/${maxPage + 1}',
              ),
              const SizedBox(width: AppSpacing.md),
              IconButton(
                tooltip: 'Trang trước',
                onPressed: page == 0 ? null : () => setState(() => page--),
                icon: const Icon(Icons.chevron_left),
              ),
              IconButton(
                tooltip: 'Trang sau',
                onPressed: page >= maxPage
                    ? null
                    : () => setState(() => page++),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
