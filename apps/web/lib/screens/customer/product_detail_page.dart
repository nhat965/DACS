import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/product.dart';
import '../../providers/catalog_provider.dart';
import '../../providers/cart_provider.dart';
import '../../providers/recommendation_provider.dart';
import '../../utils/money.dart';
import '../../widgets/product_card.dart';

class ProductDetailPage extends StatefulWidget {
  final int productId;

  const ProductDetailPage({super.key, required this.productId});

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  int quantity = 1;
  bool _initialized = false;
  late Future<Product?> _productFuture;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    _productFuture = _loadPage();
  }

  Future<Product?> _loadPage() async {
    final catalog = context.read<CatalogProvider>();
    final recommendations = context.read<RecommendationProvider>();
    final productFuture = catalog.loadProduct(widget.productId);
    await recommendations.track(
      eventType: 'view_product',
      productId: widget.productId,
    );
    await recommendations.loadSimilarProducts(widget.productId);
    for (final item in recommendations.similarResult?.items ?? const []) {
      await catalog.loadProduct(item.productId);
    }
    return productFuture;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chi tiết sản phẩm')),
      body: FutureBuilder<Product?>(
        future: _productFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final product = snapshot.data;
          if (product == null) {
            return _ErrorState(
              message:
                  context.watch<CatalogProvider>().errorMessage ??
                  'Không tìm thấy sản phẩm.',
              onRetry: () {
                setState(() {
                  _productFuture = _loadPage();
                });
              },
            );
          }

          return LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 820;
              return SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 20 : 50,
                  vertical: compact ? 24 : 40,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (compact)
                      Column(
                        children: [
                          _ProductImage(product: product, height: 360),
                          const SizedBox(height: 28),
                          _ProductInformation(
                            product: product,
                            quantity: quantity,
                            formattedPrice: formatMoney(
                              product.price,
                              product.currency,
                            ),
                            onDecrease: quantity > 1
                                ? () => setState(() => quantity--)
                                : null,
                            onIncrease:
                                product.stock == null ||
                                    quantity < product.stock!
                                ? () => setState(() => quantity++)
                                : null,
                            onAddToCart: () => _addToCart(product),
                            onBuyNow: () => _buyNow(product),
                          ),
                        ],
                      )
                    else
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _ProductImage(product: product, height: 520),
                          ),
                          const SizedBox(width: 50),
                          Expanded(
                            child: _ProductInformation(
                              product: product,
                              quantity: quantity,
                              formattedPrice: formatMoney(
                                product.price,
                                product.currency,
                              ),
                              onDecrease: quantity > 1
                                  ? () => setState(() => quantity--)
                                  : null,
                              onIncrease:
                                  product.stock == null ||
                                      quantity < product.stock!
                                  ? () => setState(() => quantity++)
                                  : null,
                              onAddToCart: () => _addToCart(product),
                              onBuyNow: () => _buyNow(product),
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 56),
                    _DetailSections(product: product),
                    const SizedBox(height: 56),
                    _RecommendationSection(currentProductId: product.id),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _addToCart(Product product) {
    final error = context.read<CartProvider>().addProduct(
      product,
      quantity: quantity,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error ?? 'Đã thêm $quantity sản phẩm vào giỏ hàng.'),
      ),
    );
  }

  void _buyNow(Product product) {
    final error = context.read<CartProvider>().addProduct(
      product,
      quantity: quantity,
    );
    if (error != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    context.go('/checkout');
  }
}

class _ProductImage extends StatelessWidget {
  const _ProductImage({required this.product, required this.height});

  final Product product;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
      ),
      clipBehavior: Clip.antiAlias,
      child: product.image.isEmpty
          ? const Icon(Icons.image_not_supported_outlined, size: 64)
          : Image.network(
              product.image,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) =>
                  const Icon(Icons.broken_image_outlined, size: 64),
            ),
    );
  }
}

class _ProductInformation extends StatelessWidget {
  const _ProductInformation({
    required this.product,
    required this.quantity,
    required this.formattedPrice,
    required this.onDecrease,
    required this.onIncrease,
    required this.onAddToCart,
    required this.onBuyNow,
  });

  final Product product;
  final int quantity;
  final String formattedPrice;
  final VoidCallback? onDecrease;
  final VoidCallback? onIncrease;
  final VoidCallback onAddToCart;
  final VoidCallback onBuyNow;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          product.brand,
          style: TextStyle(
            color: Colors.pink.shade500,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          product.name,
          style: Theme.of(context).textTheme.headlineMedium
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _InfoChip(label: product.category),
            ...product.skinTypes.map((value) => _InfoChip(label: value)),
            ...product.skinConcerns.map((value) => _InfoChip(label: value)),
          ],
        ),
        const SizedBox(height: 24),
        if (product.stock != null)
          Text(
            product.stock! > 0 ? 'Còn ${product.stock} sản phẩm' : 'Hết hàng',
            style: TextStyle(
              color: product.stock! > 0
                  ? Colors.green.shade700
                  : Theme.of(context).colorScheme.error,
              fontWeight: FontWeight.w700,
            ),
          ),
        if (product.stock != null) const SizedBox(height: 16),
        Text(
          formattedPrice,
          style: TextStyle(
            color: Colors.pink.shade600,
            fontSize: 30,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 24),
        if (product.benefits.isNotEmpty)
          Text(
            product.benefits,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 16, height: 1.6),
          ),
        if (product.keyIngredients.isNotEmpty) ...[
          const SizedBox(height: 20),
          const Text(
            'Thành phần nổi bật',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(product.keyIngredients),
        ],
        const SizedBox(height: 28),
        Row(
          children: [
            const Text(
              'Số lượng:',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(width: 12),
            IconButton(onPressed: onDecrease, icon: const Icon(Icons.remove)),
            Text(
              '$quantity',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            IconButton(onPressed: onIncrease, icon: const Icon(Icons.add)),
          ],
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: onAddToCart,
            icon: const Icon(Icons.shopping_cart_outlined),
            label: const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Text('Thêm vào giỏ hàng'),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: product.stock == 0 ? null : onBuyNow,
            icon: const Icon(Icons.bolt_outlined),
            label: const Text('Mua ngay'),
          ),
        ),
      ],
    );
  }
}

class _DetailSections extends StatelessWidget {
  const _DetailSections({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final sections = <({String title, String value})>[
      if (product.description.isNotEmpty)
        (title: 'Mô tả', value: product.description),
      if (product.benefits.isNotEmpty)
        (title: 'Lợi ích', value: product.benefits),
      if (product.inciIngredients.isNotEmpty)
        (title: 'Thành phần', value: product.inciIngredients),
      if (product.usageInstruction.isNotEmpty)
        (title: 'Cách sử dụng', value: product.usageInstruction),
      if (product.warnings.isNotEmpty)
        (title: 'Lưu ý', value: product.warnings),
      if (product.skinTypes.isNotEmpty)
        (
          title: 'Loại da phù hợp',
          value: product.skinTypes.join(', ').replaceAll('_', ' '),
        ),
      if (product.skinConcerns.isNotEmpty)
        (
          title: 'Vấn đề da',
          value: product.skinConcerns.join(', ').replaceAll('_', ' '),
        ),
      if (product.careGoals.isNotEmpty)
        (
          title: 'Mục tiêu chăm sóc',
          value: product.careGoals.join(', ').replaceAll('_', ' '),
        ),
    ];
    if (sections.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Thông tin sản phẩm',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 16),
        ...sections.map(
          (section) => ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text(
              section.title,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    section.value,
                    style: const TextStyle(height: 1.6),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(label.replaceAll('_', ' ')),
      backgroundColor: Colors.pink.shade50,
      side: BorderSide.none,
    );
  }
}

class _RecommendationSection extends StatelessWidget {
  const _RecommendationSection({required this.currentProductId});

  final int currentProductId;

  @override
  Widget build(BuildContext context) {
    final recommendations = context.watch<RecommendationProvider>();
    final catalog = context.watch<CatalogProvider>();

    if (recommendations.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (recommendations.errorMessage != null) {
      return _ErrorState(
        message: recommendations.errorMessage!,
        onRetry: () => recommendations.loadSimilarProducts(currentProductId),
      );
    }
    final products = (recommendations.similarResult?.items ?? const [])
        .map((item) => catalog.productById(item.productId))
        .whereType<Product>()
        .toList();
    if (products.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Sản phẩm tương tự dành cho bạn',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(
          'Kết quả từ ${recommendations.similarResult?.algorithm ?? 'hệ thống gợi ý'}.',
          style: TextStyle(color: Colors.grey.shade700),
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 360,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: products.length,
            separatorBuilder: (_, _) => const SizedBox(width: 18),
            itemBuilder: (context, index) => SizedBox(
              width: 230,
              child: ProductCard(product: products[index]),
            ),
          ),
        ),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 42),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: const Text('Thử lại')),
          ],
        ),
      ),
    );
  }
}
