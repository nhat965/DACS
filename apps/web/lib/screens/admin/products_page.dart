import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/catalog_provider.dart';
import '../../utils/money.dart';

class ProductsPage extends StatelessWidget {
  const ProductsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final catalog = context.watch<CatalogProvider>();
    if (catalog.isLoading && catalog.products.isEmpty) {
      return const Center(child: CircularProgressIndicator());
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
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Card(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: const [
              DataColumn(label: Text('ID')),
              DataColumn(label: Text('Sản phẩm')),
              DataColumn(label: Text('Thương hiệu')),
              DataColumn(label: Text('Danh mục')),
              DataColumn(label: Text('Giá')),
              DataColumn(label: Text('Tồn kho')),
            ],
            rows: catalog.products
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
                      DataCell(Text(product.brand)),
                      DataCell(Text(product.category)),
                      DataCell(
                        Text(formatMoney(product.price, product.currency)),
                      ),
                      DataCell(Text(product.stock?.toString() ?? '—')),
                    ],
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }
}
