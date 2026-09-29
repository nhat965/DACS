import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app/design_tokens.dart';

class AuthShell extends StatelessWidget {
  const AuthShell({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= AppBreakpoints.navigation;
        final brandPanel = Container(
          constraints: BoxConstraints(
            minHeight: desktop ? constraints.maxHeight : 210,
          ),
          padding: const EdgeInsets.all(AppSpacing.xxl),
          decoration: const BoxDecoration(gradient: AppGradients.brandHeader),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                onTap: () => context.go('/'),
                child: Text(
                  'LUMI BEAUTY',
                  style: Theme.of(context).textTheme.headlineMedium
                      ?.copyWith(color: AppColors.surface, letterSpacing: 1.4),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                'Vẻ đẹp của bạn,\nđược thấu hiểu.',
                style: Theme.of(context).textTheme.displaySmall
                    ?.copyWith(color: AppColors.surface),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Khám phá sản phẩm và routine phù hợp với làn da của riêng bạn.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppColors.surface.withValues(alpha: 0.84),
                ),
              ),
            ],
          ),
        );
        final form = SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.surface.withValues(alpha: 0.94),
                  borderRadius: BorderRadius.circular(AppRadius.feature),
                  boxShadow: AppShadows.lifted,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      child,
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        if (!desktop) {
          return SingleChildScrollView(
            child: Column(children: [brandPanel, form]),
          );
        }
        return Row(
          children: [
            Expanded(flex: 5, child: brandPanel),
            Expanded(flex: 6, child: form),
          ],
        );
      },
    );
  }
}
