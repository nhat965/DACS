import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/design_tokens.dart';
import '../../../../config/catalog_routes.dart';
import '../../../../widgets/app_animations.dart';

class CategorySection extends StatelessWidget {
  const CategorySection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Mua sắm theo danh mục',
          subtitle: 'Chọn nhanh nhóm sản phẩm bạn đang quan tâm.',
          actionLabel: 'Xem tất cả',
          onAction: () => context.go('/categories'),
        ),
        const SizedBox(height: AppSpacing.lg),
        SizedBox(
          height: 150,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: CatalogRoutes.destinations.length,
            separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.md),
            itemBuilder: (context, index) {
              final item = CatalogRoutes.destinations[index];
              return SizedBox(
                width: 152,
                child: HoverLift(
                  onTap: () => context.go(item.route),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: index.isEven
                          ? AppColors.paleRose
                          : AppColors.paper,
                      borderRadius: BorderRadius.circular(AppRadius.card),
                      boxShadow: AppShadows.soft,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(item.icon, size: 34, color: AppColors.rose),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            item.label,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
