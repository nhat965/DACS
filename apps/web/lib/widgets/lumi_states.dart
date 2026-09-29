import 'package:flutter/material.dart';

import '../app/design_tokens.dart';

class LumiSkeletonBox extends StatefulWidget {
  const LumiSkeletonBox({
    super.key,
    required this.height,
    this.width = double.infinity,
    this.radius = AppRadius.card,
  });

  final double height;
  final double width;
  final double radius;

  @override
  State<LumiSkeletonBox> createState() => _LumiSkeletonBoxState();
}

class _LumiSkeletonBoxState extends State<LumiSkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return _box(AppColors.paleRose);
    }
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) => _box(
        Color.lerp(
          AppColors.paleRose,
          AppColors.lavenderMist,
          controller.value,
        )!,
      ),
    );
  }

  Widget _box(Color color) => Container(
    width: widget.width,
    height: widget.height,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(widget.radius),
    ),
  );
}

class LumiProductGridSkeleton extends StatelessWidget {
  const LumiProductGridSkeleton({super.key, this.count = 8});

  final int count;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= AppBreakpoints.desktop
            ? 4
            : constraints.maxWidth >= AppBreakpoints.mobile
            ? 3
            : 2;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: count,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: AppSpacing.md,
            mainAxisSpacing: AppSpacing.md,
            childAspectRatio: 0.64,
          ),
          itemBuilder: (_, _) => const LumiSkeletonBox(height: 320),
        );
      },
    );
  }
}

class LumiStateCard extends StatelessWidget {
  const LumiStateCard({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(AppRadius.feature),
        boxShadow: AppShadows.soft,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 48, color: AppColors.rose),
              const SizedBox(height: AppSpacing.md),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(message, textAlign: TextAlign.center),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: AppSpacing.lg),
                OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
