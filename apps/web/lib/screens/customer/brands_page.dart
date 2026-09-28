import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/catalog_provider.dart';
import '../../widgets/app_footer.dart';
import '../../widgets/app_header.dart';

class BrandsPage extends StatelessWidget {
  const BrandsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final catalog = context.watch<CatalogProvider>();
    final brands =
        catalog.products
            .map((product) => product.brand)
            .where((brand) => brand.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          const SliverToBoxAdapter(child: AppHeader()),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 48, 24, 64),
            sliver: SliverToBoxAdapter(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1280),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Thương hiệu',
                        style: Theme.of(context).textTheme.displaySmall,
                      ),
                      const SizedBox(height: 28),
                      if (catalog.isLoading && brands.isEmpty)
                        const Center(child: CircularProgressIndicator())
                      else if (brands.isEmpty)
                        const Text(
                          'Chưa có thương hiệu trong catalog hiện tại.',
                        )
                      else
                        Wrap(
                          spacing: 16,
                          runSpacing: 16,
                          children: brands
                              .map(
                                (brand) => SizedBox(
                                  width: 260,
                                  height: 116,
                                  child: Card(
                                    clipBehavior: Clip.antiAlias,
                                    child: InkWell(
                                      onTap: () => context.go(
                                        '/brand/${Uri.encodeComponent(brand)}',
                                      ),
                                      child: Center(
                                        child: Padding(
                                          padding: const EdgeInsets.all(20),
                                          child: Text(
                                            brand,
                                            textAlign: TextAlign.center,
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleLarge,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: AppFooter()),
        ],
      ),
    );
  }
}
