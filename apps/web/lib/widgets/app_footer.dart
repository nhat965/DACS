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
                final support = const _FooterNavigation();
                final social = const _SocialLinks();
                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      about,
                      const SizedBox(height: AppSpacing.xl),
                      Wrap(
                        spacing: AppSpacing.xxl,
                        runSpacing: AppSpacing.xl,
                        children: [support, social],
                      ),
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: about),
                    support,
                    const SizedBox(width: AppSpacing.xxl),
                    social,
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
            'Khám phá mỹ phẩm và nhận gợi ý dựa trên hồ sơ làm đẹp của riêng bạn.',
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
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FooterHeading('Hỗ trợ'),
        _FooterLink(label: 'Liên hệ', route: '/stores'),
        _FooterLink(label: 'Chính sách', route: '/blog'),
        _FooterLink(label: 'Đổi trả', route: '/order-lookup'),
      ],
    );
  }
}

class _SocialLinks extends StatelessWidget {
  const _SocialLinks();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FooterHeading('Theo dõi chúng tôi'),
        _FooterLink(label: 'Facebook', route: '/social/facebook'),
        _FooterLink(label: 'Instagram', route: '/social/instagram'),
        _FooterLink(label: 'TikTok', route: '/social/tiktok'),
      ],
    );
  }
}

class _FooterHeading extends StatelessWidget {
  const _FooterHeading(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Text(
        label,
        style: Theme.of(context).textTheme.titleMedium
            ?.copyWith(color: AppColors.surface),
      ),
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
