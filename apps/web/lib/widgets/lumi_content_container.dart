import 'package:flutter/material.dart';

import '../app/design_tokens.dart';

class LumiContentContainer extends StatelessWidget {
  const LumiContentContainer({
    super.key,
    required this.child,
    this.verticalPadding = 0,
    this.maxWidth = AppBreakpoints.content,
  });

  final Widget child;
  final double verticalPadding;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final horizontalPadding = width < AppBreakpoints.mobile
        ? AppSpacing.md
        : width < AppBreakpoints.navigation
        ? AppSpacing.lg
        : AppSpacing.xl;
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: verticalPadding,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: child,
        ),
      ),
    );
  }
}
