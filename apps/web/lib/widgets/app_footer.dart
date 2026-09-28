import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app/design_tokens.dart';

class AppFooter extends StatelessWidget {
  const AppFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.ink,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.xxl,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppBreakpoints.content),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact =
                    constraints.maxWidth < AppBreakpoints.navigation;
                final about = _AboutBlock(compact: compact);
                final navigation = const _FooterNavigation();
                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      about,
                      const SizedBox(height: AppSpacing.xl),
                      navigation,
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: about),
                    navigation,
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _AboutBlock extends StatelessWidget {
  const _AboutBlock({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: compact ? double.infinity : 520),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'LUMI BEAUTY',
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(color: AppColors.paper, letterSpacing: 1.4),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Khám phá mỹ phẩm từ catalog thật và nhận gợi ý dựa trên hồ sơ làm đẹp của riêng bạn.',
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: AppColors.paper.withValues(alpha: 0.74)),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            '© ${DateTime.now().year} Lumi Beauty',
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: AppColors.paper.withValues(alpha: 0.6)),
          ),
        ],
      ),
    );
  }
}

class _FooterNavigation extends StatelessWidget {
  const _FooterNavigation();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.xl,
      runSpacing: AppSpacing.xs,
      children: const [
        _FooterLink(label: 'Danh mục', route: '/categories'),
        _FooterLink(label: 'Thương hiệu', route: '/brands'),
        _FooterLink(label: 'Tìm kiếm', route: '/search'),
        _FooterLink(label: 'Tài khoản', route: '/profile'),
        _FooterLink(label: 'Giỏ hàng', route: '/cart'),
      ],
    );
  }
}

class _FooterLink extends StatelessWidget {
  const _FooterLink({required this.label, required this.route});

  final String label;
  final String route;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: () => context.go(route),
      style: TextButton.styleFrom(foregroundColor: AppColors.paper),
      child: Text(label),
    );
  }
}
