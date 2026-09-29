import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/design_tokens.dart';
import '../../../../widgets/app_animations.dart';

class ConcernSection extends StatelessWidget {
  const ConcernSection({super.key});

  static const concerns = <_Concern>[
    _Concern(
      'Da mụn',
      Icons.healing_outlined,
      AppColors.blushPink,
      concern: 'acne',
    ),
    _Concern(
      'Da dầu',
      Icons.water_drop_outlined,
      AppColors.lavenderMist,
      concern: 'oiliness',
    ),
    _Concern(
      'Da khô',
      Icons.dry_outlined,
      AppColors.peachPink,
      concern: 'dryness',
    ),
    _Concern(
      'Da nhạy cảm',
      Icons.eco_outlined,
      AppColors.softRose,
      concern: 'sensitivity',
    ),
    _Concern(
      'Thâm & không đều màu',
      Icons.brightness_6_outlined,
      AppColors.softViolet,
      concern: 'dark_spot',
    ),
    _Concern(
      'Lão hóa',
      Icons.auto_awesome_outlined,
      AppColors.pinkMist,
      concern: 'aging',
    ),
    _Concern(
      'Phục hồi',
      Icons.shield_outlined,
      AppColors.lilac,
      goal: 'repair',
    ),
    _Concern(
      'Cấp ẩm',
      Icons.opacity_outlined,
      AppColors.blushPink,
      goal: 'hydrate',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'Chọn theo nhu cầu làn da',
          subtitle:
              'Tìm nhanh sản phẩm phù hợp với điều làn da bạn đang quan tâm.',
        ),
        const SizedBox(height: AppSpacing.lg),
        SizedBox(
          height: 118,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: concerns.length,
            separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.md),
            itemBuilder: (context, index) {
              final item = concerns[index];
              return SizedBox(
                width: 190,
                child: HoverLift(
                  scale: 1.015,
                  onTap: () => context.go(
                    Uri(
                      path: '/search',
                      queryParameters: {
                        if (item.concern != null) 'concern': item.concern!,
                        if (item.goal != null) 'goal': item.goal!,
                      },
                    ).toString(),
                  ),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: item.color,
                      borderRadius: BorderRadius.circular(AppRadius.feature),
                      boxShadow: AppShadows.soft,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Row(
                        children: [
                          DecoratedBox(
                            decoration: const BoxDecoration(
                              color: Color(0xCCFFFFFF),
                              shape: BoxShape.circle,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(AppSpacing.sm),
                              child: Icon(item.icon, color: AppColors.plum),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Text(
                              item.label,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
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

class _Concern {
  const _Concern(this.label, this.icon, this.color, {this.concern, this.goal});

  final String label;
  final IconData icon;
  final Color color;
  final String? concern;
  final String? goal;
}
