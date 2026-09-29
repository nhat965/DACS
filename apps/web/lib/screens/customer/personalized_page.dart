import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/design_tokens.dart';
import '../../models/product.dart';
import '../../models/recommendation.dart';
import '../../providers/auth_provider.dart';
import '../../providers/catalog_provider.dart';
import '../../providers/preferences_provider.dart';
import '../../providers/recommendation_provider.dart';
import '../../services/backend_api.dart';
import '../../widgets/app_footer.dart';
import '../../widgets/app_header.dart';
import '../../widgets/product_card.dart';

class PersonalizedPage extends StatefulWidget {
  const PersonalizedPage({super.key});

  @override
  State<PersonalizedPage> createState() => _PersonalizedPageState();
}

class _PersonalizedPageState extends State<PersonalizedPage> {
  bool loadingProducts = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => load());
  }

  Future<void> load() async {
    final preferences = context.read<PreferencesProvider>();
    if (preferences.preferences == null) await preferences.load();
    if (!mounted || !preferences.isComplete) return;
    final recommendation = context.read<RecommendationProvider>();
    await recommendation.loadPersonalized(
      context: preferences.preferences!.toRecommendationContext(),
    );
    if (!mounted) return;
    setState(() => loadingProducts = true);
    final catalog = context.read<CatalogProvider>();
    for (final item
        in recommendation.personalizedResult?.items ??
            const <RecommendedProduct>[]) {
      await catalog.loadProduct(item.productId);
    }
    if (mounted) setState(() => loadingProducts = false);
  }

  @override
  Widget build(BuildContext context) {
    final preferences = context.watch<PreferencesProvider>();
    final recommendation = context.watch<RecommendationProvider>();
    final catalog = context.watch<CatalogProvider>();
    final items =
        recommendation.personalizedResult?.items ??
        const <RecommendedProduct>[];
    final products = <({Product product, RecommendedProduct recommendation})>[];
    for (final item in items) {
      final product = catalog.productById(item.productId);
      if (product != null) {
        products.add((product: product, recommendation: item));
      }
    }
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
                        'Gợi ý dành riêng cho bạn',
                        style: Theme.of(context).textTheme.displaySmall,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        _subtitle(preferences),
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      if (preferences.isLoading ||
                          recommendation.isLoading ||
                          loadingProducts)
                        const SizedBox(
                          height: 320,
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (!preferences.isComplete)
                        _Message(
                          icon: Icons.tune_outlined,
                          title: 'Cần hồ sơ làm đẹp',
                          message: 'Hoàn thành khảo sát để Lumi hiểu làn da và ưu tiên của bạn.',
                          action: 'Hoàn thành hồ sơ',
                          onAction: () => context.go('/onboarding'),
                        )
                      else if (recommendation.errorMessage != null)
                        _Message(
                          icon: Icons.cloud_off_outlined,
                          title: 'Chưa thể tạo gợi ý',
                          message: recommendation.errorMessage!,
                          action: 'Thử lại',
                          onAction: load,
                        )
                      else if (products.isEmpty)
                        _Message(
                          icon: Icons.auto_awesome_outlined,
                          title: 'Chưa có sản phẩm đủ điểm phù hợp',
                          message: 'Hãy nới rộng ngân sách hoặc cập nhật mục tiêu chăm sóc.',
                          action: 'Chỉnh sửa hồ sơ',
                          onAction: () => context.go('/onboarding'),
                        )
                      else
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
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: columns,
                                    crossAxisSpacing: AppSpacing.md,
                                    mainAxisSpacing: AppSpacing.lg,
                                    childAspectRatio: columns == 1 ? 0.9 : 0.61,
                                  ),
                              itemBuilder: (context, index) {
                                final entry = products[index];
                                return Column(
                                  children: [
                                    Expanded(
                                      child: ProductCard(
                                        product: entry.product,
                                        matchScore: entry.recommendation.score,
                                        matchReason:
                                            entry.recommendation.reasons.isEmpty
                                            ? null
                                            : entry
                                                  .recommendation
                                                  .reasons
                                                  .first,
                                        onOpen: () => context
                                            .read<RecommendationProvider>()
                                            .track(
                                              eventType: 'click_recommendation',
                                              productId: entry.product.id,
                                            ),
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () => _showExplanation(
                                        context,
                                        entry.product,
                                      ),
                                      child: const Text(
                                        'Vì sao phù hợp với tôi?',
                                      ),
                                    ),
                                  ],
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
          const SliverToBoxAdapter(child: AppFooter()),
        ],
      ),
    );
  }

  String _subtitle(PreferencesProvider state) {
    final value = state.preferences;
    if (value == null || !value.completed) {
      return 'Dựa trên hồ sơ và tín hiệu hành vi của bạn.';
    }
    final parts = <String>[
      if (value.skinType != null) value.skinType!,
      ...value.skinConcerns.take(2),
      ...value.careGoals.take(1),
    ];
    return parts.isEmpty
        ? 'Dựa trên hồ sơ đã lưu.'
        : 'Dựa trên ${parts.join(' · ').replaceAll('_', ' ')}';
  }

  Future<void> _showExplanation(BuildContext context, Product product) async {
    final auth = context.read<AuthProvider>();
    final preferences = context.read<PreferencesProvider>().preferences;
    final recommendation = context.read<RecommendationProvider>();
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => FutureBuilder<RecommendedProduct>(
        future: context.read<BackendApi>().explainRecommendation(
          productId: product.id,
          sessionId: recommendation.sessionId,
          accessToken: auth.accessToken,
          context: preferences?.toRecommendationContext() ?? const {},
        ),
        builder: (context, snapshot) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.xl,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpacing.md),
                if (snapshot.connectionState == ConnectionState.waiting)
                  const Center(child: CircularProgressIndicator())
                else if (snapshot.hasError)
                  Text(BackendApi.readableError(snapshot.error!))
                else
                  ...(snapshot.data?.reasons ?? const <String>[]).map(
                    (reason) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(
                        Icons.check_circle_outline,
                        color: AppColors.success,
                      ),
                      title: Text(reason),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
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
            Icon(icon, size: 52, color: AppColors.rose),
            const SizedBox(height: AppSpacing.md),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(onPressed: onAction, child: Text(action)),
          ],
        ),
      ),
    );
  }
}
