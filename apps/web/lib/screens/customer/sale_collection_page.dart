import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/design_tokens.dart';
import '../../models/product.dart';
import '../../services/backend_api.dart';
import '../../widgets/app_footer.dart';
import '../../widgets/app_header.dart';
import '../../widgets/lumi_content_container.dart';
import '../../widgets/lumi_states.dart';
import '../../widgets/product_card.dart';

class SaleCollectionPage extends StatefulWidget {
  const SaleCollectionPage({super.key, required this.title});

  final String title;

  @override
  State<SaleCollectionPage> createState() => _SaleCollectionPageState();
}

class _SaleCollectionPageState extends State<SaleCollectionPage> {
  List<Product> products = const [];
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final items = await context.read<BackendApi>().getActivePromotions();
      if (mounted) setState(() { products = items; loading = false; });
    } catch (exception) {
      if (mounted) setState(() { error = BackendApi.readableError(exception); loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const AppHeader(),
          Expanded(
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: LumiContentContainer(
                    verticalPadding: AppSpacing.xxl,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: Theme.of(context).textTheme.displaySmall,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          '${products.length} sản phẩm đang có ưu đãi',
                          style: const TextStyle(color: AppColors.mutedInk),
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        if (loading && products.isEmpty)
                          const LumiProductGridSkeleton()
                        else if (error != null)
                          LumiStateCard(icon: Icons.error_outline, title: 'Không tải được khuyến mại', message: error!, actionLabel: 'Thử lại', onAction: load)
                        else if (products.isEmpty)
                          const LumiStateCard(
                            icon: Icons.local_offer_outlined,
                            title: 'Ưu đãi mới đang được cập nhật.',
                            message: 'Hãy quay lại sớm để khám phá chương trình tiếp theo.',
                          )
                        else
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final columns = constraints.maxWidth >= 1100
                                  ? 4
                                  : constraints.maxWidth >= 720
                                  ? 3
                                  : 2;
                              return GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: products.length,
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: columns,
                                      crossAxisSpacing: AppSpacing.md,
                                      mainAxisSpacing: AppSpacing.lg,
                                      childAspectRatio: 0.64,
                                    ),
                                itemBuilder: (_, index) =>
                                    ProductCard(product: products[index]),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: AppFooter()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
