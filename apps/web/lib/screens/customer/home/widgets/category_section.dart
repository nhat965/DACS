import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/design_tokens.dart';
import '../../../../config/catalog_routes.dart';
import '../../../../widgets/app_animations.dart';

class CategorySection extends StatelessWidget {
  const CategorySection({super.key});

  @override
  Widget build(BuildContext context) {
    const order = [
      'Son môi',
      'Hàng mới',
      'Quà tặng',
      'Makeup',
      'Skincare',
      'Nước hoa',
      'Bodycare',
      'Blog',
    ];
    final items = order
        .map(
          (label) => CatalogRoutes.destinations.firstWhere(
            (item) => item.label == label,
          ),
        )
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 126,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.lg),
            itemBuilder: (context, index) {
              final item = items[index];
              return SizedBox(
                width: 106,
                child: HoverLift(
                  scale: 1.04,
                  onTap: () => context.go(item.route),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      DecoratedBox(
                        decoration: const BoxDecoration(
                          color: AppColors.softPink,
                          shape: BoxShape.circle,
                        ),
                        child: SizedBox.square(
                          dimension: 68,
                          child: Icon(
                            item.icon,
                            size: 34,
                            color: AppColors.rose,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        item.label,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ],
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
