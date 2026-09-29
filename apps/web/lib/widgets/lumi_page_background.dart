import 'package:flutter/material.dart';

import '../app/design_tokens.dart';

class LumiPageBackground extends StatelessWidget {
  const LumiPageBackground({
    super.key,
    required this.child,
    this.intensity = LumiBackgroundIntensity.standard,
    this.showGlow = true,
  });

  final Widget child;
  final LumiBackgroundIntensity intensity;
  final bool showGlow;

  @override
  Widget build(BuildContext context) {
    final overlay = switch (intensity) {
      LumiBackgroundIntensity.soft => AppColors.surface.withValues(alpha: 0.34),
      LumiBackgroundIntensity.standard => Colors.transparent,
      LumiBackgroundIntensity.vivid => AppColors.softPurple.withValues(
        alpha: 0.10,
      ),
    };
    return ColoredBox(
      color: AppColors.backgroundBase,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(gradient: AppGradients.ambient),
          ),
          if (showGlow) ...[
            const Positioned(
              top: -180,
              right: -100,
              child: _AmbientGlow(color: AppColors.softPurple, size: 460),
            ),
            const Positioned(
              top: 520,
              left: -180,
              child: _AmbientGlow(color: AppColors.pinkMist, size: 520),
            ),
          ],
          if (overlay != Colors.transparent) ColoredBox(color: overlay),
          child,
        ],
      ),
    );
  }
}

enum LumiBackgroundIntensity { soft, standard, vivid }

class _AmbientGlow extends StatelessWidget {
  const _AmbientGlow({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SizedBox.square(
        dimension: size,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                color.withValues(alpha: 0.52),
                color.withValues(alpha: 0),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class LumiSectionSurface extends StatelessWidget {
  const LumiSectionSurface({
    super.key,
    required this.child,
    this.color = AppColors.surface,
    this.padding = const EdgeInsets.all(AppSpacing.xl),
  });

  final Widget child;
  final Color color;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(AppRadius.feature),
        boxShadow: AppShadows.soft,
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}
