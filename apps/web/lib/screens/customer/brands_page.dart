import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/design_tokens.dart';
import '../../providers/catalog_provider.dart';
import '../../widgets/app_animations.dart';
import '../../widgets/app_footer.dart';
import '../../widgets/app_header.dart';
import '../../widgets/lumi_states.dart';

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
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.xxl,
              AppSpacing.lg,
              AppSpacing.section,
            ),
            sliver: SliverToBoxAdapter(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: AppBreakpoints.content,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Thương hiệu',
                        style: Theme.of(context).textTheme.displaySmall,
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      if (catalog.isLoading && brands.isEmpty)
                        const LumiProductGridSkeleton(count: 4)
                      else if (brands.isEmpty)
                        const LumiStateCard(
                          icon: Icons.diamond_outlined,
                          title: 'Chưa có thương hiệu để hiển thị.',
                          message: 'Vui lòng quay lại sau khi danh sách được cập nhật.',
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
                                  child: HoverLift(
                                    onTap: () => context.go(
                                      '/brand/${Uri.encodeComponent(brand)}',
                                    ),
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        color: AppColors.surface,
                                        borderRadius: BorderRadius.circular(
                                          AppRadius.card,
                                        ),
                                        boxShadow: AppShadows.soft,
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
