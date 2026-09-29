import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/design_tokens.dart';
import '../../providers/catalog_provider.dart';
import '../../config/catalog_routes.dart';
import '../../widgets/app_header.dart';
import '../../widgets/product_card.dart';
import '../../widgets/lumi_states.dart';

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
                MediaQuery.sizeOf(context).width < AppBreakpoints.mobile
                    ? AppSpacing.lg
                    : AppSpacing.xxl,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: AppBreakpoints.content,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pageTitle,
                        style: Theme.of(context).textTheme.displaySmall,
                      ),

                      const SizedBox(height: 10),

                      Text(
                        '${products.length} sản phẩm',
                        style: const TextStyle(color: AppColors.mutedInk),
                      ),

                      const SizedBox(height: 30),

                      catalog.isLoading && catalog.products.isEmpty
                          ? const LumiProductGridSkeleton()
                          : products.isEmpty
                          ? const LumiStateCard(
                              icon: Icons.search_off_outlined,
                              title: 'Chưa có sản phẩm trong danh mục này.',
                              message:
                                  'Hãy thử một danh mục hoặc thương hiệu khác.',
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
                                        childAspectRatio: columns == 1
                                            ? 0.9
                                            : 0.6,
                                      ),
                                  itemBuilder: (context, index) {
                                    return ProductCard(
                                      product: products[index],
                                    );
                                  },
                                );
                              },
                            ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
