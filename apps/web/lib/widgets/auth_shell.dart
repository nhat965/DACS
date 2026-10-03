import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app/design_tokens.dart';

const _authImagePath = 'assets/images/auth/login_beauty.webp';

class AuthShell extends StatefulWidget {
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
  State<AuthShell> createState() => _AuthShellState();
}

class _AuthShellState extends State<AuthShell> with TickerProviderStateMixin {
  late final AnimationController _ambientController;
  late final AnimationController _entranceController;
  bool? _motionDisabled;

  @override
  void initState() {
    super.initState();
    _ambientController = AnimationController(
      vsync: this,
      duration: AppDurations.authAmbient,
    );
    _entranceController = AnimationController(
      vsync: this,
      duration: AppDurations.authBrandEntrance,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final disabled = MediaQuery.disableAnimationsOf(context);
    if (_motionDisabled == disabled) return;
    _motionDisabled = disabled;
    if (disabled) {
      _ambientController.stop();
      _ambientController.value = 0;
      _entranceController.value = 1;
    } else {
      _ambientController.repeat();
      _entranceController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _ambientController.dispose();
    _entranceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final formCurve = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.12, 0.86, curve: Curves.easeOutCubic),
    );
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: AppGradients.authCanvas),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final desktop = constraints.maxWidth >= AppBreakpoints.navigation;
          final visual = AuthVisualPanel(
            ambientAnimation: _ambientController,
            entranceAnimation: _entranceController,
            compact: !desktop,
          );
          final form = _AuthFormPane(
            title: widget.title,
            subtitle: widget.subtitle,
            entranceAnimation: formCurve,
            scrollable: desktop,
            child: widget.child,
          );

          if (!desktop) {
            return SingleChildScrollView(
              child: Column(
                children: [
                  SizedBox(
                    height: constraints.maxWidth < 430 ? 260 : 300,
                    child: visual,
                  ),
                  form,
                ],
              ),
            );
          }

          return Row(
            children: [
              Expanded(
                flex: constraints.maxWidth >= 1280 ? 10 : 9,
                child: visual,
              ),
              Expanded(flex: 11, child: form),
            ],
          );
        },
      ),
    );
  }
}

class AuthVisualPanel extends StatelessWidget {
  const AuthVisualPanel({
    super.key,
    required this.ambientAnimation,
    required this.entranceAnimation,
    required this.compact,
  });

  final Animation<double> ambientAnimation;
  final Animation<double> entranceAnimation;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final brandCurve = CurvedAnimation(
      parent: entranceAnimation,
      curve: const Interval(0, 0.78, curve: Curves.easeOutCubic),
    );
    final taglineCurve = CurvedAnimation(
      parent: entranceAnimation,
      curve: const Interval(0.24, 1, curve: Curves.easeOutCubic),
    );
    return ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedBuilder(
            animation: ambientAnimation,
            builder: (context, child) {
              final scale = TweenSequence<double>([
                TweenSequenceItem(
                  tween: Tween(begin: 1, end: 1.04),
                  weight: 50,
                ),
                TweenSequenceItem(
                  tween: Tween(begin: 1.04, end: 1),
                  weight: 50,
                ),
              ]).transform(ambientAnimation.value);
              return Transform.scale(scale: scale, child: child);
            },
            child: Image.asset(
              _authImagePath,
              fit: BoxFit.cover,
              alignment: compact
                  ? const Alignment(0.38, -0.12)
                  : Alignment.center,
              filterQuality: FilterQuality.medium,
            ),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(gradient: AppGradients.authOverlay),
          ),
          _AmbientGlow(
            animation: ambientAnimation,
            alignment: const Alignment(-1.05, -0.9),
            colors: const [Color(0x4DFF8DB8), Color(0x00FF8DB8)],
            travel: const Offset(14, 10),
            size: compact ? 240 : 360,
          ),
          _AmbientGlow(
            animation: ambientAnimation,
            alignment: const Alignment(0.95, 0.8),
            colors: const [Color(0x3DAD8AF5), Color(0x00AD8AF5)],
            travel: const Offset(-16, -12),
            size: compact ? 220 : 340,
          ),
          SafeArea(
            child: Padding(
              padding: EdgeInsets.all(compact ? AppSpacing.lg : AppSpacing.xxl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  FadeTransition(
                    opacity: brandCurve,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.18),
                        end: Offset.zero,
                      ).animate(brandCurve),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(AppRadius.control),
                        onTap: () => context.go('/'),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.xs,
                          ),
                          child: Text(
                            'LUMI BEAUTY',
                            style:
                                (compact
                                        ? Theme.of(context)
                                              .textTheme
                                              .headlineMedium
                                        : Theme.of(context)
                                              .textTheme
                                              .displaySmall)
                                    ?.copyWith(
                                      color: AppColors.surface,
                                      letterSpacing: compact ? 1.5 : 2.2,
                                      fontWeight: FontWeight.w800,
                                      shadows: const [
                                        Shadow(
                                          color: Color(0x5943243A),
                                          blurRadius: 18,
                                          offset: Offset(0, 4),
                                        ),
                                      ],
                                    ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: compact ? AppSpacing.xs : AppSpacing.md),
                  FadeTransition(
                    opacity: taglineCurve,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.16),
                        end: Offset.zero,
                      ).animate(taglineCurve),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 520),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Vẻ đẹp bắt đầu từ sự thấu hiểu làn da của bạn.',
                              maxLines: compact ? 2 : 3,
                              overflow: TextOverflow.ellipsis,
                              style:
                                  (compact
                                          ? Theme.of(context)
                                                .textTheme
                                                .titleLarge
                                          : Theme.of(context)
                                                .textTheme
                                                .headlineMedium)
                                      ?.copyWith(
                                        color: AppColors.surface,
                                        height: 1.2,
                                      ),
                            ),
                            if (!compact) ...[
                              const SizedBox(height: AppSpacing.sm),
                              Text(
                                'Khám phá sản phẩm phù hợp với riêng bạn.',
                                style: Theme.of(context).textTheme.bodyLarge
                                    ?.copyWith(
                                      color: AppColors.surface.withValues(
                                        alpha: 0.86,
                                      ),
                                    ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AmbientGlow extends StatelessWidget {
  const _AmbientGlow({
    required this.animation,
    required this.alignment,
    required this.colors,
    required this.travel,
    required this.size,
  });

  final Animation<double> animation;
  final Alignment alignment;
  final List<Color> colors;
  final Offset travel;
  final double size;

  @override
  Widget build(BuildContext context) => Align(
    alignment: alignment,
    child: IgnorePointer(
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, child) {
          final movement = TweenSequence<double>([
            TweenSequenceItem(tween: Tween(begin: 0, end: 1), weight: 50),
            TweenSequenceItem(tween: Tween(begin: 1, end: 0), weight: 50),
          ]).transform(animation.value);
          return Transform.translate(offset: travel * movement, child: child);
        },
        child: SizedBox.square(
          dimension: size,
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: colors),
            ),
          ),
        ),
      ),
    ),
  );
}

class _AuthFormPane extends StatelessWidget {
  const _AuthFormPane({
    required this.title,
    required this.subtitle,
    required this.entranceAnimation,
    required this.scrollable,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Animation<double> entranceAnimation;
  final bool scrollable;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final card = FadeTransition(
      opacity: entranceAnimation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0.045, 0),
          end: Offset.zero,
        ).animate(entranceAnimation),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: AuthFormCard(title: title, subtitle: subtitle, child: child),
          ),
        ),
      ),
    );
    const padding = EdgeInsets.symmetric(
      horizontal: AppSpacing.lg,
      vertical: AppSpacing.xl,
    );
    if (!scrollable) return Padding(padding: padding, child: card);
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: padding,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: constraints.maxHeight - (AppSpacing.xl * 2),
          ),
          child: card,
        ),
      ),
    );
  }
}

class AuthFormCard extends StatelessWidget {
  const AuthFormCard({
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
    final narrow = MediaQuery.sizeOf(context).width < AppBreakpoints.mobile;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.98),
        borderRadius: BorderRadius.circular(AppRadius.authCard),
        boxShadow: AppShadows.authCard,
      ),
      child: Padding(
        padding: EdgeInsets.all(narrow ? AppSpacing.lg : AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: AppSpacing.xs),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodyLarge
                  ?.copyWith(color: AppColors.mutedInk),
            ),
            const SizedBox(height: AppSpacing.xl),
            child,
          ],
        ),
      ),
    );
  }
}

class AuthTextField extends StatefulWidget {
  const AuthTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.prefixIcon,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.obscureText = false,
    this.helperText,
    this.suffixIcon,
    this.validator,
    this.onFieldSubmitted,
    this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final IconData prefixIcon;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final bool obscureText;
  final String? helperText;
  final Widget? suffixIcon;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onFieldSubmitted;
  final ValueChanged<String>? onChanged;

  @override
  State<AuthTextField> createState() => _AuthTextFieldState();
}

class _AuthTextFieldState extends State<AuthTextField> {
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChanged);
  }

  void _onFocusChanged() => setState(() {});

  @override
  void dispose() {
    _focusNode
      ..removeListener(_onFocusChanged)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: AppDurations.feedback,
    curve: Curves.easeOutCubic,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(AppRadius.control),
      boxShadow: _focusNode.hasFocus
          ? const [
              BoxShadow(
                color: Color(0x1F8358B8),
                blurRadius: 16,
                offset: Offset(0, 6),
              ),
            ]
          : const [],
    ),
    child: TextFormField(
      controller: widget.controller,
      focusNode: _focusNode,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      autofillHints: widget.autofillHints,
      obscureText: widget.obscureText,
      validator: widget.validator,
      onFieldSubmitted: widget.onFieldSubmitted,
      onChanged: widget.onChanged,
      decoration: InputDecoration(
        labelText: widget.label,
        helperText: widget.helperText,
        prefixIcon: AnimatedSwitcher(
          duration: AppDurations.feedback,
          child: Icon(
            widget.prefixIcon,
            key: ValueKey(_focusNode.hasFocus),
            color: _focusNode.hasFocus ? AppColors.focus : AppColors.mutedInk,
          ),
        ),
        suffixIcon: widget.suffixIcon,
      ),
    ),
  );
}

class AuthPasswordField extends StatefulWidget {
  const AuthPasswordField({
    super.key,
    required this.controller,
    this.label = 'Mật khẩu',
    this.helperText,
    this.newPassword = false,
    this.validator,
    this.onFieldSubmitted,
    this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final String? helperText;
  final bool newPassword;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onFieldSubmitted;
  final ValueChanged<String>? onChanged;

  @override
  State<AuthPasswordField> createState() => _AuthPasswordFieldState();
}

class _AuthPasswordFieldState extends State<AuthPasswordField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) => AuthTextField(
    controller: widget.controller,
    label: widget.label,
    prefixIcon: Icons.lock_outline_rounded,
    obscureText: _obscure,
    helperText: widget.helperText,
    autofillHints: [
      widget.newPassword ? AutofillHints.newPassword : AutofillHints.password,
    ],
    textInputAction: TextInputAction.done,
    validator: widget.validator,
    onFieldSubmitted: widget.onFieldSubmitted,
    onChanged: widget.onChanged,
    suffixIcon: IconButton(
      tooltip: _obscure ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
      onPressed: () => setState(() => _obscure = !_obscure),
      icon: AnimatedSwitcher(
        duration: AppDurations.feedback,
        transitionBuilder: (child, animation) => RotationTransition(
          turns: Tween(begin: 0.92, end: 1.0).animate(animation),
          child: FadeTransition(opacity: animation, child: child),
        ),
        child: Icon(
          _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
          key: ValueKey(_obscure),
        ),
      ),
    ),
  );
}

class AuthPrimaryButton extends StatefulWidget {
  const AuthPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  State<AuthPrimaryButton> createState() => _AuthPrimaryButtonState();
}

class _AuthPrimaryButtonState extends State<AuthPrimaryButton> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null && !widget.loading;
    final visuallyActive = enabled || widget.loading;
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: enabled ? (_) => setState(() => _hovered = true) : null,
      onExit: (_) => setState(() {
        _hovered = false;
        _pressed = false;
      }),
      child: Listener(
        onPointerDown: enabled ? (_) => setState(() => _pressed = true) : null,
        onPointerUp: (_) => setState(() => _pressed = false),
        onPointerCancel: (_) => setState(() => _pressed = false),
        child: AnimatedScale(
          duration: AppDurations.feedback,
          curve: Curves.easeOutCubic,
          scale: _pressed ? 0.98 : (_hovered ? 1.01 : 1),
          child: AnimatedContainer(
            duration: AppDurations.feedback,
            transform: Matrix4.translationValues(
              0,
              _hovered && !_pressed ? -1 : 0,
              0,
            ),
            decoration: BoxDecoration(
              gradient: visuallyActive ? AppGradients.authCta : null,
              color: visuallyActive ? null : AppColors.line,
              borderRadius: BorderRadius.circular(AppRadius.control),
              boxShadow: visuallyActive
                  ? (_hovered
                        ? AppShadows.authButtonHover
                        : AppShadows.authButton)
                  : const [],
            ),
            child: FilledButton(
              onPressed: enabled ? widget.onPressed : null,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(54),
                backgroundColor: Colors.transparent,
                disabledBackgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                foregroundColor: AppColors.surface,
                disabledForegroundColor: AppColors.mutedInk,
              ),
              child: AnimatedSwitcher(
                duration: AppDurations.feedback,
                child: widget.loading
                    ? Row(
                        key: const ValueKey('loading'),
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.surface,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Text('${widget.label}...'),
                        ],
                      )
                    : Text(widget.label, key: const ValueKey('label')),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AuthMessageBanner extends StatelessWidget {
  const AuthMessageBanner({
    super.key,
    required this.message,
    this.isError = false,
  });

  final String? message;
  final bool isError;

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: AppDurations.component,
    transitionBuilder: (child, animation) => FadeTransition(
      opacity: animation,
      child: SizeTransition(sizeFactor: animation, child: child),
    ),
    child: message == null
        ? const SizedBox.shrink(key: ValueKey('empty-message'))
        : Container(
            key: ValueKey(message),
            margin: const EdgeInsets.only(top: AppSpacing.md),
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: isError
                  ? AppColors.authErrorSurface
                  : AppColors.lavenderMist,
              borderRadius: BorderRadius.circular(AppRadius.control),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  isError
                      ? Icons.error_outline_rounded
                      : Icons.info_outline_rounded,
                  size: 20,
                  color: isError ? AppColors.authErrorText : AppColors.focus,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    message!,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: isError ? AppColors.authErrorText : AppColors.plum,
                    ),
                  ),
                ),
              ],
            ),
          ),
  );
}

class AuthTextLink extends StatelessWidget {
  const AuthTextLink({
    super.key,
    required this.label,
    required this.onPressed,
    this.leadingText,
    this.enabled = true,
    this.alignment = MainAxisAlignment.center,
  });

  final String label;
  final String? leadingText;
  final VoidCallback onPressed;
  final bool enabled;
  final MainAxisAlignment alignment;

  @override
  Widget build(BuildContext context) => Wrap(
    alignment: alignment == MainAxisAlignment.end
        ? WrapAlignment.end
        : WrapAlignment.center,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      if (leadingText != null)
        Text(
          leadingText!,
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: AppColors.mutedInk),
        ),
      TextButton(
        onPressed: enabled ? onPressed : null,
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.hovered)
                ? AppColors.focus
                : AppColors.rose,
          ),
          textStyle: WidgetStateProperty.resolveWith(
            (states) => Theme.of(context).textTheme.labelLarge?.copyWith(
              decoration: states.contains(WidgetState.hovered)
                  ? TextDecoration.underline
                  : TextDecoration.none,
              decorationThickness: 1.2,
              decorationColor: AppColors.focus,
            ),
          ),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          ),
        ),
        child: Text(label),
      ),
    ],
  );
}
