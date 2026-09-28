import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/catalog_provider.dart';
import '../../config/catalog_routes.dart';
import '../../widgets/app_header.dart';
import '../../widgets/product_card.dart';

class CategoryPage extends StatelessWidget {
  final String category;

  const CategoryPage({super.key, required this.category});

  @override
  Widget build(BuildContext context) {
    final catalog = context.watch<CatalogProvider>();
    final isBrand = category.startsWith('brand:');
    final brand = isBrand ? category.substring('brand:'.length) : null;
    final destination = isBrand ? null : CatalogRoutes.fromSlug(category);
    final acceptedCategories =
        destination?.backendCategories.toSet() ?? {category.toLowerCase()};
    final pageTitle = brand ?? destination?.label ?? category;
    final products = catalog.products
        .where(
          (product) => isBrand
              ? product.brand.toLowerCase() == brand!.toLowerCase()
              : acceptedCategories.contains(product.category.toLowerCase()),
        )
        .toList();

    return Scaffold(
      body: Column(
        children: [
          const AppHeader(),

          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(
                MediaQuery.sizeOf(context).width < 600 ? 24 : 40,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pageTitle,
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 10),

                  Text(
                    '${products.length} sản phẩm',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),

                  const SizedBox(height: 30),

                  catalog.isLoading && catalog.products.isEmpty
                      ? const Center(child: CircularProgressIndicator())
                      : products.isEmpty
                      ? const Center(
                          child: Text('Không có sản phẩm trong danh mục này.'),
                        )
                      : LayoutBuilder(
                          builder: (context, constraints) {
                            final columns = constraints.maxWidth >= 1200
                                ? 5
                                : constraints.maxWidth >= 900
                                ? 4
                                : constraints.maxWidth >= 600
                                ? 3
                                : constraints.maxWidth >= 320
                                ? 2
                                : 1;
                            return GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: products.length,
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: columns,
                                    crossAxisSpacing: 20,
                                    mainAxisSpacing: 20,
                                    childAspectRatio: columns == 1 ? 0.9 : 0.6,
                                  ),
                              itemBuilder: (context, index) {
                                return ProductCard(product: products[index]);
                              },
                            );
                          },
                        ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
