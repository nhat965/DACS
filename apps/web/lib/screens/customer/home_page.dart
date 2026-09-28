import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/design_tokens.dart';
import '../../providers/catalog_provider.dart';
import '../../widgets/ai_chat_box.dart';
import '../../widgets/app_animations.dart';
import '../../widgets/app_footer.dart';
import '../../widgets/app_header.dart';
import 'home/widgets/category_section.dart';
import 'home/widgets/hero_carousel.dart';
import 'home/widgets/home_sections.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final catalog = context.watch<CatalogProvider>();
    final featured = catalog.products.take(8).toList();
    final brands =
        catalog.products
            .map((product) => product.brand)
            .where((brand) => brand.isNotEmpty)
            .toSet()
            .toList()
          ..sort();

    return Scaffold(
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              const SliverToBoxAdapter(child: AppHeader()),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.section,
                ),
                sliver: SliverToBoxAdapter(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: AppBreakpoints.large,
                      ),
                      child: Column(
                        children: [
                          const FadeSlideIn(child: HeroCarousel()),
                          if (catalog.errorMessage != null) ...[
                            const SizedBox(height: AppSpacing.lg),
                            _BackendNotice(catalog: catalog),
                          ],
                          const SizedBox(height: AppSpacing.section),
                          const FadeSlideIn(
                            delay: Duration(milliseconds: 80),
                            child: CategorySection(),
                          ),
                          const SizedBox(height: AppSpacing.section),
                          FadeSlideIn(
                            delay: const Duration(milliseconds: 120),
                            child: const PersonalizedHomePreview(),
                          ),
                          const SizedBox(height: AppSpacing.section),
                          if (catalog.isLoading && featured.isEmpty)
                            const _CatalogLoading()
                          else if (featured.isEmpty)
                            const _CatalogEmpty()
                          else
                            FadeSlideIn(
                              delay: const Duration(milliseconds: 160),
                              child: ProductGridSection(
                                title: 'Sản phẩm nổi bật',
                                subtitle: 'Danh sách sản phẩm đang hoạt động và AI-ready trong catalog.',
                                products: featured,
                                actionLabel: 'Xem thêm',
                                onAction: () => context.go('/search'),
                              ),
                            ),
                          const SizedBox(height: AppSpacing.section),
                          BrandShowcase(brands: brands),
                          const SizedBox(height: AppSpacing.section),
                          const TrustSection(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: AppFooter()),
            ],
          ),
          const AiChatBox(),
        ],
      ),
    );
  }
}

class _BackendNotice extends StatelessWidget {
  const _BackendNotice({required this.catalog});

  final CatalogProvider catalog;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4E5),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            const Icon(Icons.cloud_off_outlined, color: AppColors.warning),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: Text(catalog.errorMessage!)),
            TextButton(
              onPressed: () => catalog.loadProducts(force: true),
              child: const Text('Thử lại'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CatalogLoading extends StatelessWidget {
  const _CatalogLoading();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 280,
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class _CatalogEmpty extends StatelessWidget {
  const _CatalogEmpty();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.section),
      child: Column(
        children: [
          const Icon(Icons.inventory_2_outlined, size: 52),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Chưa có sản phẩm để hiển thị.',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.md),
          OutlinedButton(
            onPressed: () => context.go('/categories'),
            child: const Text('Xem danh mục'),
          ),
        ],
      ),
    );
  }
}
