import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../config/catalog_routes.dart';
import '../../widgets/app_footer.dart';
import '../../widgets/app_header.dart';

class CategoriesPage extends StatelessWidget {
  const CategoriesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
                        'Khám phá danh mục',
                        style: theme.textTheme.displaySmall,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Tìm nhanh routine và nhóm sản phẩm phù hợp với nhu cầu của bạn.',
                        style: theme.textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 32),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final columns = constraints.maxWidth >= 1000
                              ? 4
                              : constraints.maxWidth >= 640
                              ? 3
                              : 2;
                          return GridView.count(
                            crossAxisCount: columns,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                            childAspectRatio: columns == 2 ? 1.05 : 1.25,
                            children: CatalogRoutes.destinations
                                .map((item) => _CategoryTile(item: item))
                                .toList(),
                          );
                        },
                      ),
                      const SizedBox(height: 56),
                      Text(
                        'Chăm sóc da theo bước',
                        style: theme.textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 24),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: CatalogRoutes.subcategories
                            .map(
                              (item) => ActionChip(
                                avatar: Icon(item.icon, size: 18),
                                label: Text(item.label),
                                onPressed: () => context.go(item.route),
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

class _CategoryTile extends StatefulWidget {
  const _CategoryTile({required this.item});

  final CatalogDestination item;

  @override
  State<_CategoryTile> createState() => _CategoryTileState();
}

class _CategoryTileState extends State<_CategoryTile> {
  bool hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => hovered = true),
      onExit: (_) => setState(() => hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        transform: Matrix4.translationValues(0, hovered ? -4 : 0, 0),
        decoration: BoxDecoration(
          color: colors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(18),
          boxShadow: hovered
              ? [
                  BoxShadow(
                    color: colors.shadow.withValues(alpha: 0.12),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ]
              : const [],
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => context.go(widget.item.route),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(widget.item.icon, size: 40, color: colors.primary),
                const SizedBox(height: 18),
                Text(
                  widget.item.label,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
