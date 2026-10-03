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

class NewArrivalsPage extends StatefulWidget {
  const NewArrivalsPage({super.key});

  @override
  State<NewArrivalsPage> createState() => _NewArrivalsPageState();
}

class _NewArrivalsPageState extends State<NewArrivalsPage> {
  List<Product> products = const [];
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() { loading = true; error = null; });
    try {
      final page = await context.read<BackendApi>().getProductPage(sort: 'newest', limit: 24);
      if (mounted) setState(() => products = page.items);
    } catch (exception) {
      if (mounted) setState(() => error = BackendApi.readableError(exception));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Column(children: [
          const AppHeader(),
          Expanded(child: CustomScrollView(slivers: [
            SliverToBoxAdapter(child: LumiContentContainer(verticalPadding: AppSpacing.xxl, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Hàng mới về', style: Theme.of(context).textTheme.displaySmall),
              const SizedBox(height: AppSpacing.xs),
              const Text('Sản phẩm được sắp xếp theo thời điểm tạo trong catalog.'),
              const SizedBox(height: AppSpacing.xl),
              if (error != null) LumiStateCard(icon: Icons.error_outline, title: 'Không tải được hàng mới', message: error!, actionLabel: 'Thử lại', onAction: load)
              else if (loading) const LumiProductGridSkeleton()
              else if (products.isEmpty) const LumiStateCard(icon: Icons.auto_awesome_outlined, title: 'Chưa có sản phẩm mới', message: 'Catalog chưa có sản phẩm nào có ngày tạo để hiển thị.')
              else LayoutBuilder(builder: (context, constraints) { final columns = constraints.maxWidth >= 1100 ? 4 : constraints.maxWidth >= 720 ? 3 : 2; return GridView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: products.length, gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: columns, crossAxisSpacing: AppSpacing.md, mainAxisSpacing: AppSpacing.lg, childAspectRatio: .64), itemBuilder: (_, index) => ProductCard(product: products[index])); }),
            ]))),
            const SliverToBoxAdapter(child: AppFooter()),
          ])),
        ]),
      );
}
