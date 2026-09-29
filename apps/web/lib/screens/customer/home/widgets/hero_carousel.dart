import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/design_tokens.dart';
import '../../../../widgets/app_animations.dart';

class _HeroSlide {
  const _HeroSlide({
    required this.imageUrl,
    required this.title,
    required this.subtitle,
    required this.action,
    required this.route,
  });

  final String imageUrl;
  final String title;
  final String subtitle;
  final String action;
  final String route;
}

const _slides = [
  _HeroSlide(
    imageUrl: 'https://images.unsplash.com/photo-1556228720-195a672e8a03?auto=format&fit=crop&w=1800&q=85',
    title: 'Routine dịu nhẹ cho da dầu mụn',
    subtitle:
        'Những lựa chọn làm sạch và chăm sóc phù hợp cho làn da dễ nổi mụn.',
    action: 'Tìm sản phẩm',
    route: '/search?concern=acne',
  ),
  _HeroSlide(
    imageUrl: 'https://images.unsplash.com/photo-1612817288484-6f916006741a?auto=format&fit=crop&w=1800&q=85',
    title: 'Chăm sóc da theo nhu cầu',
    subtitle: 'Khám phá routine từ làm sạch, dưỡng ẩm đến bảo vệ da mỗi ngày.',
    action: 'Khám phá danh mục',
    route: '/categories',
  ),
  _HeroSlide(
    imageUrl: 'https://images.unsplash.com/photo-1598440947619-2c35fc9aa908?auto=format&fit=crop&w=1800&q=85',
    title: 'Khám phá COSRX',
    subtitle: 'Khám phá những lựa chọn chăm sóc da được yêu thích từ COSRX.',
    action: 'Xem thương hiệu',
    route: '/brand/COSRX',
  ),
  _HeroSlide(
    imageUrl: 'https://images.unsplash.com/photo-1570172619644-dfd03ed5d881?auto=format&fit=crop&w=1800&q=85',
    title: 'Gợi ý dành riêng cho bạn',
    subtitle:
        'Hoàn thiện hồ sơ làm đẹp để Lumi hiểu làn da và sở thích của bạn.',
    action: 'Mở hồ sơ',
    route: '/profile',
  ),
  _HeroSlide(
    imageUrl: 'https://images.unsplash.com/photo-1620916566398-39f1143ab7be?auto=format&fit=crop&w=1800&q=85',
    title: 'Tìm routine cấp ẩm',
    subtitle: 'Khám phá những sản phẩm giúp làn da mềm mại và đủ ẩm mỗi ngày.',
    action: 'Tìm kiếm ngay',
    route: '/search?goal=hydrate',
  ),
];

class HeroCarousel extends StatefulWidget {
  const HeroCarousel({super.key});

  @override
  State<HeroCarousel> createState() => _HeroCarouselState();
}

class _HeroCarouselState extends State<HeroCarousel> {
  final controller = PageController();
  Timer? timer;
  int index = 0;
  bool hovered = false;

  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(AppDurations.carousel, (_) {
      if (!mounted || hovered || MediaQuery.disableAnimationsOf(context)) {
        return;
      }
      goTo((index + 1) % _slides.length);
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    controller.dispose();
    super.dispose();
  }

  void goTo(int target) {
    controller.animateToPage(
      target,
      duration: AppDurations.section,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => hovered = true),
      onExit: (_) => setState(() => hovered = false),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final mobile = constraints.maxWidth < 800;
          final mainBanner = SizedBox(
            height: mobile ? 420 : 420,
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.feature),
                  child: PageView.builder(
                    controller: controller,
                    itemCount: _slides.length,
                    onPageChanged: (value) => setState(() => index = value),
                    itemBuilder: (context, slideIndex) => _SlideContent(
                      slide: _slides[slideIndex],
                      mobile: mobile,
                    ),
                  ),
                ),
                if (!mobile) ...[
                  Positioned(
                    left: AppSpacing.md,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: _ArrowButton(
                        tooltip: 'Banner trước',
                        icon: Icons.chevron_left,
                        onPressed: () =>
                            goTo((index - 1 + _slides.length) % _slides.length),
                      ),
                    ),
                  ),
                  Positioned(
                    right: AppSpacing.md,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: _ArrowButton(
                        tooltip: 'Banner tiếp theo',
                        icon: Icons.chevron_right,
                        onPressed: () => goTo((index + 1) % _slides.length),
                      ),
                    ),
                  ),
                ],
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: AppSpacing.md,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _slides.length,
                      (dot) => Semantics(
                        button: true,
                        label: 'Mở banner ${dot + 1}',
                        child: InkWell(
                          onTap: () => goTo(dot),
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                          child: AnimatedContainer(
                            duration: AppDurations.feedback,
                            width: dot == index ? 28 : 9,
                            height: 9,
                            margin: const EdgeInsets.all(AppSpacing.xs),
                            decoration: BoxDecoration(
                              color: dot == index
                                  ? AppColors.paper
                                  : AppColors.paper.withValues(alpha: 0.55),
                              borderRadius: BorderRadius.circular(
                                AppRadius.pill,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
          if (mobile) {
            return Column(
              children: [
                mainBanner,
                const SizedBox(height: AppSpacing.sm),
                const SizedBox(
                  height: 150,
                  child: Row(
                    children: [
                      Expanded(
                        child: _SideBanner(
                          title: 'Khám phá COSRX',
                          subtitle: 'Chăm sóc da mỗi ngày',
                          route: '/brand/COSRX',
                          imageUrl: 'https://images.unsplash.com/photo-1556228578-8c89e6adf883?auto=format&fit=crop&w=900&q=82',
                        ),
                      ),
                      SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: _SideBanner(
                          title: 'Gợi ý riêng cho bạn',
                          subtitle: 'Khảo sát nhanh 30 giây',
                          route: '/onboarding',
                          imageUrl: 'https://images.unsplash.com/photo-1541643600914-78b084683601?auto=format&fit=crop&w=900&q=82',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }
          return SizedBox(
            height: 420,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 2, child: mainBanner),
                const SizedBox(width: AppSpacing.lg),
                const Expanded(
                  child: Column(
                    children: [
                      Expanded(
                        child: _SideBanner(
                          title: 'Khám phá COSRX',
                          subtitle: 'Chăm sóc da mỗi ngày',
                          route: '/brand/COSRX',
                          imageUrl: 'https://images.unsplash.com/photo-1556228578-8c89e6adf883?auto=format&fit=crop&w=900&q=82',
                        ),
                      ),
                      SizedBox(height: AppSpacing.lg),
                      Expanded(
                        child: _SideBanner(
                          title: 'Gợi ý riêng cho bạn',
                          subtitle: 'Khảo sát nhanh 30 giây',
                          route: '/onboarding',
                          imageUrl: 'https://images.unsplash.com/photo-1541643600914-78b084683601?auto=format&fit=crop&w=900&q=82',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SideBanner extends StatelessWidget {
  const _SideBanner({
    required this.title,
    required this.subtitle,
    required this.route,
    required this.imageUrl,
  });

  final String title;
  final String subtitle;
  final String route;
  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return HoverLift(
      scale: 1.012,
      onTap: () => context.go(route),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              imageUrl,
              fit: BoxFit.cover,
              cacheWidth: (900 * MediaQuery.devicePixelRatioOf(context))
                  .round(),
              errorBuilder: (_, _, _) => const DecoratedBox(
                decoration: BoxDecoration(gradient: AppGradients.brandHeader),
              ),
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Color(0xCC43243A), Color(0x1243243A)],
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomLeft,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge
                          ?.copyWith(color: AppColors.surface),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.surface.withValues(alpha: 0.88),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SlideContent extends StatelessWidget {
  const _SlideContent({required this.slide, required this.mobile});

  final _HeroSlide slide;
  final bool mobile;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.network(
          slide.imageUrl,
          fit: BoxFit.cover,
          cacheWidth: (1800 * MediaQuery.devicePixelRatioOf(context)).round(),
          errorBuilder: (_, _, _) => const DecoratedBox(
            decoration: BoxDecoration(gradient: AppGradients.brand),
            child: Center(
              child: Icon(
                Icons.spa_outlined,
                size: 84,
                color: Color(0x66FFFFFF),
              ),
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: mobile
                ? const LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Color(0xEB43243A), Color(0x1AD85A8A)],
                  )
                : AppGradients.heroOverlay,
          ),
        ),
        Align(
          alignment: mobile ? Alignment.bottomLeft : Alignment.centerLeft,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              mobile ? AppSpacing.lg : AppSpacing.hero,
              AppSpacing.xl,
              mobile ? AppSpacing.lg : AppSpacing.hero,
              mobile ? AppSpacing.section : AppSpacing.xl,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 580),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    slide.title,
                    style:
                        (mobile
                                ? Theme.of(context).textTheme.displaySmall
                                : Theme.of(context).textTheme.displayLarge)
                            ?.copyWith(color: AppColors.paper),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    slide.subtitle,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.paper.withValues(alpha: 0.9),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  FilledButton(
                    onPressed: () => context.go(slide.route),
                    child: Text(slide.action),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ArrowButton extends StatelessWidget {
  const _ArrowButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton.filledTonal(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon),
      style: IconButton.styleFrom(
        backgroundColor: AppColors.paper.withValues(alpha: 0.9),
        foregroundColor: AppColors.ink,
      ),
    );
  }
}
