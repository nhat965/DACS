import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../app/design_tokens.dart';
import '../../../../models/product.dart';
import '../../../../models/recommendation.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../providers/catalog_provider.dart';
import '../../../../providers/preferences_provider.dart';
import '../../../../providers/recommendation_provider.dart';
import '../../../../widgets/app_animations.dart';
import '../../../../widgets/product_card.dart';

class ProductGridSection extends StatelessWidget {
  const ProductGridSection({
    super.key,
    required this.title,
    required this.subtitle,
    required this.products,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String subtitle;
  final List<Product> products;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: title,
          subtitle: subtitle,
          actionLabel: actionLabel,
          onAction: onAction,
        ),
        const SizedBox(height: AppSpacing.lg),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= AppBreakpoints.large
                ? 5
                : constraints.maxWidth >= AppBreakpoints.desktop
                ? 4
                : constraints.maxWidth >= AppBreakpoints.mobile
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
                childAspectRatio: columns == 1 ? 0.9 : 0.6,
              ),
              itemBuilder: (context, index) =>
                  ProductCard(product: products[index]),
            );
          },
        ),
      ],
    );
  }
}

class FlashSaleSection extends StatelessWidget {
  const FlashSaleSection({super.key, required this.products});

  final List<Product> products;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.feature),
      child: DecoratedBox(
        decoration: const BoxDecoration(color: AppColors.surface),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              decoration: const BoxDecoration(gradient: AppGradients.flashSale),
              child: Text(
                '⚡ FLASH SALE ⚡',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: AppColors.surface,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: products.isEmpty
                  ? const SizedBox(
                      height: 120,
                      child: Center(
                        child: Text(
                          'Ưu đãi mới đang được cập nhật. Hãy quay lại sớm nhé!',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : SizedBox(
                      height: 370,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: products.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(width: AppSpacing.md),
                        itemBuilder: (context, index) => SizedBox(
                          width: 225,
                          child: ProductCard(product: products[index]),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class PersonalizationCallout extends StatelessWidget {
  const PersonalizationCallout({super.key, required this.authenticated});

  final bool authenticated;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: AppGradients.brand,
        borderRadius: BorderRadius.circular(AppRadius.feature),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: AppSpacing.xl,
          runSpacing: AppSpacing.lg,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    authenticated
                        ? 'Hoàn thiện hồ sơ làm đẹp'
                        : 'Gợi ý phù hợp hơn với bạn',
                    style: Theme.of(context).textTheme.headlineMedium
                        ?.copyWith(color: AppColors.paper),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    authenticated
                        ? 'Cập nhật loại da và mục tiêu để Lumi hiểu bạn hơn.'
                        : 'Làm khảo sát 30 giây để nhận gợi ý phù hợp với làn da của bạn.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.paper.withValues(alpha: 0.82),
                    ),
                  ),
                ],
              ),
            ),
            FilledButton.tonal(
              onPressed: () =>
                  context.go(authenticated ? '/profile' : '/register'),
              child: Text(authenticated ? 'Mở hồ sơ' : 'Bắt đầu'),
            ),
          ],
        ),
      ),
    );
  }
}

class PersonalizedHomePreview extends StatefulWidget {
  const PersonalizedHomePreview({super.key});

  @override
  State<PersonalizedHomePreview> createState() =>
      _PersonalizedHomePreviewState();
}

class _PersonalizedHomePreviewState extends State<PersonalizedHomePreview> {
  bool resolving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => load());
  }

  Future<void> load() async {
    if (!context.read<AuthProvider>().isAuthenticated) {
      return;
    }
    final preferences = context.read<PreferencesProvider>();
    if (preferences.preferences == null) {
      await preferences.load();
    }
    if (!mounted || !preferences.isComplete) {
      return;
    }
    final recommendations = context.read<RecommendationProvider>();
    await recommendations.loadPersonalized(
      context: preferences.preferences!.toRecommendationContext(),
    );
    if (!mounted) return;
    setState(() => resolving = true);
    final catalog = context.read<CatalogProvider>();
    for (final item
        in recommendations.personalizedResult?.items.take(4) ??
            const <RecommendedProduct>[]) {
      await catalog.loadProduct(item.productId);
    }
    if (mounted) setState(() => resolving = false);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final preferences = context.watch<PreferencesProvider>();
    final recommendations = context.watch<RecommendationProvider>();
    final catalog = context.watch<CatalogProvider>();
    if (!auth.isAuthenticated) {
      return const PersonalizationCallout(authenticated: false);
    }
    if (preferences.isLoading || recommendations.isLoading || resolving) {
      return const SizedBox(
        height: 220,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (!preferences.isComplete) {
      return const PersonalizationCallout(authenticated: true);
    }
    final entries = <({Product product, RecommendedProduct recommendation})>[];
    for (final item
        in recommendations.personalizedResult?.items.take(4) ??
            const <RecommendedProduct>[]) {
      final product = catalog.productById(item.productId);
      if (product != null) {
        entries.add((product: product, recommendation: item));
      }
    }
    if (entries.isEmpty) {
      return const PersonalizationCallout(authenticated: true);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Gợi ý dành riêng cho bạn',
          subtitle: 'Dành riêng cho làn da và sở thích của bạn.',
          actionLabel: 'Xem tất cả',
          onAction: () => context.go('/recommendations'),
        ),
        const SizedBox(height: AppSpacing.lg),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= AppBreakpoints.desktop
                ? 4
                : constraints.maxWidth >= AppBreakpoints.mobile
                ? 3
                : constraints.maxWidth >= 320
                ? 2
                : 1;
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: entries.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                crossAxisSpacing: AppSpacing.md,
                mainAxisSpacing: AppSpacing.lg,
                childAspectRatio: 0.61,
              ),
              itemBuilder: (context, index) {
                final entry = entries[index];
                return ProductCard(
                  product: entry.product,
                  matchScore: entry.recommendation.score,
                  matchReason: entry.recommendation.reasons.isEmpty
                      ? null
                      : entry.recommendation.reasons.first,
                  onOpen: () => context.read<RecommendationProvider>().track(
                    eventType: 'click_recommendation',
                    productId: entry.product.id,
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }
}

class BrandShowcase extends StatelessWidget {
  const BrandShowcase({super.key, required this.brands});

  final List<String> brands;

  @override
  Widget build(BuildContext context) {
    if (brands.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Thương hiệu nổi bật',
          subtitle: 'Khám phá những thương hiệu được yêu thích tại Lumi.',
          actionLabel: 'Xem thương hiệu',
          onAction: () => context.go('/brands'),
        ),
        const SizedBox(height: AppSpacing.lg),
        Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: brands
              .map(
                (brand) => ActionChip(
                  label: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                    ),
                    child: Text(brand),
                  ),
                  onPressed: () =>
                      context.go('/brand/${Uri.encodeComponent(brand)}'),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

class TrustSection extends StatelessWidget {
  const TrustSection({super.key});

  @override
  Widget build(BuildContext context) {
    const items = [
      (
        Icons.fact_check_outlined,
        'Thông tin rõ ràng',
        'Thông tin sản phẩm đầy đủ và dễ kiểm tra.',
      ),
      (
        Icons.tune_outlined,
        'Gợi ý dành riêng',
        'Theo làn da, nhu cầu và sở thích của bạn.',
      ),
      (
        Icons.shield_outlined,
        'Mua sắm tự tin',
        'Giá và tình trạng sản phẩm luôn được hiển thị minh bạch.',
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final vertical = constraints.maxWidth < AppBreakpoints.mobile;
        final children = items
            .map(
              (item) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(item.$1, color: AppColors.rose),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        item.$2,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(item.$3),
                    ],
                  ),
                ),
              ),
            )
            .toList();
        return DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.paper,
            borderRadius: BorderRadius.circular(AppRadius.feature),
          ),
          child: vertical
              ? Column(
                  children: children
                      .map(
                        (child) => SizedBox(
                          width: double.infinity,
                          child: child.child,
                        ),
                      )
                      .toList(),
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: children,
                ),
        );
      },
    );
  }
}
