import 'dart:async';

import 'package:flutter/material.dart';

import '../app/design_tokens.dart';

class FadeSlideIn extends StatelessWidget {
  const FadeSlideIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
  });

  final Widget child;
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    return RevealOnScroll(delay: delay, child: child);
  }
}

class RevealOnScroll extends StatefulWidget {
  const RevealOnScroll({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.visibleFraction = 0.15,
    this.offset = 20,
  });

  final Widget child;
  final Duration delay;
  final double visibleFraction;
  final double offset;

  @override
  State<RevealOnScroll> createState() => _RevealOnScrollState();
}

class _RevealOnScrollState extends State<RevealOnScroll>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller;
  ScrollPosition? position;
  bool revealed = false;
  Timer? visibilityProbe;
  Timer? visibilityFallback;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(
      vsync: this,
      duration: AppDurations.section,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
    // Web renderers can expose the final viewport geometry a few frames after
    // the first paint (notably after a GoRouter page transition). Probe briefly
    // instead of leaving a section permanently transparent when that happens.
    visibilityProbe = Timer.periodic(
      const Duration(milliseconds: 100),
      (_) => _measure(),
    );
    visibilityFallback = Timer(const Duration(milliseconds: 1200), () {
      if (!mounted || revealed) return;
      _reveal();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nextPosition = Scrollable.maybeOf(context)?.position;
    if (identical(position, nextPosition)) return;
    position?.removeListener(_measure);
    position = nextPosition;
    position?.addListener(_measure);
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  void _measure() {
    if (!mounted || revealed) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _reveal(immediately: true);
      return;
    }
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return;
    final top = renderObject.localToGlobal(Offset.zero).dy;
    final bottom = top + renderObject.size.height;
    final viewportHeight = MediaQuery.sizeOf(context).height;
    final visibleHeight =
        (bottom.clamp(0, viewportHeight) - top.clamp(0, viewportHeight)).clamp(
          0.0,
          renderObject.size.height,
        );
    final fraction = renderObject.size.height == 0
        ? 1.0
        : visibleHeight / renderObject.size.height;
    if (fraction < widget.visibleFraction) return;
    _reveal();
  }

  void _reveal({bool immediately = false}) {
    if (revealed) return;
    revealed = true;
    visibilityProbe?.cancel();
    visibilityFallback?.cancel();
    if (immediately) {
      controller.value = 1;
      return;
    }
    Future<void>.delayed(widget.delay, () {
      if (mounted) controller.forward();
    });
  }

  @override
  void dispose() {
    position?.removeListener(_measure);
    visibilityProbe?.cancel();
    visibilityFallback?.cancel();
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return widget.child;
    final curved = CurvedAnimation(
      parent: controller,
      curve: Curves.easeOutCubic,
    );
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: Offset(0, widget.offset / 600),
          end: Offset.zero,
        ).animate(curved),
        child: widget.child,
      ),
    );
  }
}

class HoverLift extends StatefulWidget {
  const HoverLift({
    super.key,
    required this.child,
    this.onTap,
    this.scale = 1.02,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double scale;

  @override
  State<HoverLift> createState() => _HoverLiftState();
}

class _HoverLiftState extends State<HoverLift> {
  bool hovered = false;
  bool pressed = false;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final targetScale = reduceMotion
        ? 1.0
        : pressed
        ? 0.99
        : hovered
        ? widget.scale
        : 1.0;
    return MouseRegion(
      cursor: widget.onTap == null
          ? MouseCursor.defer
          : SystemMouseCursors.click,
      onEnter: (_) => setState(() => hovered = true),
      onExit: (_) => setState(() {
        hovered = false;
        pressed = false;
      }),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: widget.onTap == null
            ? null
            : (_) => setState(() => pressed = true),
        onTapCancel: widget.onTap == null
            ? null
            : () => setState(() => pressed = false),
        onTapUp: widget.onTap == null
            ? null
            : (_) => setState(() => pressed = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: targetScale,
          duration: AppDurations.feedback,
          curve: Curves.easeOutCubic,
          child: widget.child,
        ),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < AppBreakpoints.mobile;
        final heading = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.headlineMedium),
            if (subtitle != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(subtitle!, style: Theme.of(context).textTheme.bodyLarge),
            ],
          ],
        );
        final action = actionLabel != null && onAction != null
            ? TextButton.icon(
                onPressed: onAction,
                iconAlignment: IconAlignment.end,
                icon: const Icon(Icons.arrow_forward),
                label: Text(actionLabel!),
              )
            : null;
        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              heading,
              if (action != null) ...[
                const SizedBox(height: AppSpacing.sm),
                action,
              ],
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(child: heading),
            ?action,
          ],
        );
      },
    );
  }
}
