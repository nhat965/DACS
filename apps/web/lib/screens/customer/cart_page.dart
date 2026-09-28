import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/cart_provider.dart';
import '../../utils/money.dart';

class CartPage extends StatelessWidget {
  const CartPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    return Scaffold(
      appBar: AppBar(title: Text('Giỏ hàng (${cart.itemCount})')),
      body: cart.isEmpty
          ? _EmptyCart(onBrowse: () => context.go('/'))
          : LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 850;
                final lines = _CartLines(cart: cart);
                final summary = _CartSummary(cart: cart);
                return SingleChildScrollView(
                  padding: EdgeInsets.all(compact ? 20 : 40),
                  child: compact
                      ? Column(
                          children: [
                            lines,
                            const SizedBox(height: 24),
                            summary,
                          ],
                        )
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 2, child: lines),
                            const SizedBox(width: 30),
                            Expanded(child: summary),
                          ],
                        ),
                );
              },
            ),
    );
  }
}

class _CartLines extends StatelessWidget {
  const _CartLines({required this.cart});

  final CartProvider cart;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: cart.lines.map((line) {
        final product = line.product;
        return Card(
          margin: const EdgeInsets.only(bottom: 14),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: product.image.isEmpty
                      ? Container(
                          width: 82,
                          height: 82,
                          color: Colors.grey.shade100,
                          child: const Icon(Icons.image_not_supported_outlined),
                        )
                      : Image.network(
                          product.image,
                          width: 82,
                          height: 82,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const SizedBox(
                            width: 82,
                            height: 82,
                            child: Icon(Icons.broken_image_outlined),
                          ),
                        ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        formatMoney(product.price, product.currency),
                        style: TextStyle(color: Colors.pink.shade700),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            onPressed: () =>
                                cart.setQuantity(product.id, line.quantity - 1),
                            icon: const Icon(Icons.remove_circle_outline),
                          ),
                          Text(
                            '${line.quantity}',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            onPressed: () {
                              final error = cart.setQuantity(
                                product.id,
                                line.quantity + 1,
                              );
                              if (error != null) {
                                ScaffoldMessenger.of(
                                  context,
                                ).showSnackBar(SnackBar(content: Text(error)));
                              }
                            },
                            icon: const Icon(Icons.add_circle_outline),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      formatMoney(line.lineTotal, product.currency),
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    IconButton(
                      tooltip: 'Xóa khỏi giỏ hàng',
                      onPressed: () => cart.removeProduct(product.id),
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _CartSummary extends StatelessWidget {
  const _CartSummary({required this.cart});

  final CartProvider cart;

  @override
  Widget build(BuildContext context) {
    final currency = cart.currency ?? '';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Tóm tắt đơn hàng',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 22),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${cart.itemCount} sản phẩm'),
                Text(formatMoney(cart.subtotal, currency)),
              ],
            ),
            const Divider(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Tổng cộng',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  formatMoney(cart.subtotal, currency),
                  style: TextStyle(
                    color: Colors.pink.shade700,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => context.go('/checkout'),
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 13),
                child: Text('Tiến hành đặt hàng'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyCart extends StatelessWidget {
  const _EmptyCart({required this.onBrowse});

  final VoidCallback onBrowse;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.shopping_bag_outlined,
              size: 68,
              color: Colors.pink.shade200,
            ),
            const SizedBox(height: 18),
            const Text(
              'Giỏ hàng đang trống',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text('Khám phá catalog và chọn sản phẩm phù hợp với bạn.'),
            const SizedBox(height: 22),
            FilledButton(
              onPressed: onBrowse,
              child: const Text('Xem sản phẩm'),
            ),
          ],
        ),
      ),
    );
  }
}
