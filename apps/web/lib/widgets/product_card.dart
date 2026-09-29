import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../app/design_tokens.dart';
import '../models/product.dart';
import '../providers/cart_provider.dart';
import '../utils/money.dart';

class ProductCard extends StatefulWidget {
  const ProductCard({
    super.key,
    required this.product,
    this.matchScore,
    this.matchReason,
    this.onOpen,
  });

  final Product product;
  final double? matchScore;
  final String? matchReason;
  final VoidCallback? onOpen;

  @override
  State<ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<ProductCard> {
  bool hovered = false;

  void addToCart() {
    final message = context.read<CartProvider>().addProduct(widget.product);
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message ?? 'Đã thêm ${widget.product.name} vào giỏ.'),
        action: message == null
            ? SnackBarAction(
                label: 'Xem giỏ',
                onPressed: () => context.go('/cart'),
              )
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final sale = product.oldPrice != null && product.oldPrice! > product.price;
    final discount = sale
        ? ((1 - product.price / product.oldPrice!) * 100).round()
        : null;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => hovered = true),
      onExit: (_) => setState(() => hovered = false),
      child: AnimatedScale(
        duration: reduceMotion ? Duration.zero : AppDurations.component,
        scale: hovered && !reduceMotion ? 1.012 : 1,
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: reduceMotion ? Duration.zero : AppDurations.component,
          transform: Matrix4.translationValues(
            0,
            hovered && !reduceMotion ? -5 : 0,
            0,
          ),
          decoration: BoxDecoration(
            color: AppColors.paper,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: hovered ? Border.all(color: AppColors.softRose) : null,
            boxShadow: hovered ? AppShadows.lifted : AppShadows.soft,
          ),
          clipBehavior: Clip.antiAlias,
          child: Semantics(
            button: true,
            label: '${product.brand} ${product.name}',
            child: InkWell(
              onTap: () {
                widget.onOpen?.call();
                context.go('/product/${product.id}');
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ClipRect(
                          child: AnimatedScale(
                            duration: reduceMotion
                                ? Duration.zero
                                : AppDurations.component,
                            scale: hovered && !reduceMotion ? 1.045 : 1,
                            curve: Curves.easeOutCubic,
                            child: _ProductImage(url: product.image),
                          ),
                        ),
                        if (discount != null)
                          Positioned(
                            left: AppSpacing.sm,
                            top: AppSpacing.sm,
                            child: _Badge(label: '-$discount%'),
                          ),
                        if (widget.matchScore != null)
                          Positioned(
                            right: AppSpacing.sm,
                            top: AppSpacing.sm,
                            child: _Badge(
                              label:
                                  '${(widget.matchScore! * 100).round()}% phù hợp',
                              background: AppColors.plum,
                            ),
                          ),
                        Positioned(
                          left: AppSpacing.sm,
                          right: AppSpacing.sm,
                          bottom: AppSpacing.sm,
                          child: IgnorePointer(
                            ignoring: !hovered,
                            child: AnimatedSlide(
                              duration: reduceMotion
                                  ? Duration.zero
                                  : AppDurations.feedback,
                              offset: hovered
                                  ? Offset.zero
                                  : const Offset(0, 0.3),
                              child: AnimatedOpacity(
                                duration: reduceMotion
                                    ? Duration.zero
                                    : AppDurations.feedback,
                                opacity: hovered ? 1 : 0,
                                child: FilledButton.icon(
                                  onPressed: product.stock == 0
                                      ? null
                                      : addToCart,
                                  icon: const Icon(
                                    Icons.add_shopping_cart,
                                    size: 18,
                                  ),
                                  label: Text(
                                    product.stock == 0
                                        ? 'Hết hàng'
                                        : 'Thêm vào giỏ',
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.brand.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: AppColors.rose,
                                letterSpacing: 0.8,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          product.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        if (widget.matchReason != null) ...[
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            widget.matchReason!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                        if (product.rating != null || product.sold != null) ...[
                          const SizedBox(height: AppSpacing.sm),
                          Row(
                            children: [
                              if (product.rating != null) ...[
                                const Icon(
                                  Icons.star,
                                  size: 16,
                                  color: Color(0xFFC27A19),
                                ),
                                Text(' ${product.rating!.toStringAsFixed(1)}'),
                              ],
                              if (product.rating != null &&
                                  product.sold != null)
                                const Spacer(),
                              if (product.sold != null)
                                Text('${product.sold} đã bán'),
                            ],
                          ),
                        ],
                        const SizedBox(height: AppSpacing.sm),
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.xxs,
                          children: [
                            Text(
                              formatMoney(product.price, product.currency),
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(color: AppColors.rose),
                            ),
                            if (sale)
                              Text(
                                formatMoney(
                                  product.oldPrice!,
                                  product.currency,
                                ),
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: AppColors.mutedInk,
                                      decoration: TextDecoration.lineThrough,
                                    ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProductImage extends StatelessWidget {
  const _ProductImage({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) return const _ImageFallback();
    return Image.network(
      url,
      width: double.infinity,
      fit: BoxFit.cover,
      cacheWidth: (520 * MediaQuery.devicePixelRatioOf(context)).round(),
      errorBuilder: (_, _, _) => const _ImageFallback(),
    );
  }
}

class _ImageFallback extends StatelessWidget {
  const _ImageFallback();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: AppColors.paleRose,
      child: Center(
        child: Icon(
          Icons.image_not_supported_outlined,
          size: 40,
          color: AppColors.mutedInk,
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, this.background = AppColors.rose});

  final String label;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.control),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall
              ?.copyWith(color: AppColors.paper),
        ),
      ),
    );
  }
}
