import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/cart_provider.dart';
import '../../providers/order_provider.dart';
import '../../utils/money.dart';

class CheckoutPage extends StatefulWidget {
  const CheckoutPage({super.key});

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _noteController = TextEditingController();
  String _paymentMethod = 'COD';

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: context.read<AuthProvider>().user?.fullName ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final success = await context.read<OrderProvider>().placeOrder(
      cart: context.read<CartProvider>(),
      shippingName: _nameController.text,
      shippingPhone: _phoneController.text,
      shippingAddress: _addressController.text,
      note: _noteController.text,
      paymentMethod: _paymentMethod,
    );
    if (!mounted || !success) return;
    final order = context.read<OrderProvider>().latestOrder!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Đã tạo đơn hàng #${order.orderId}.')),
    );
    context.go('/profile');
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final orders = context.watch<OrderProvider>();
    if (cart.isEmpty && orders.latestOrder == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Đặt hàng')),
        body: Center(
          child: FilledButton(
            onPressed: () => context.go('/'),
            child: const Text('Giỏ hàng trống — quay lại mua sắm'),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Đặt hàng')),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 850;
          final form = _ShippingForm(
            formKey: _formKey,
            nameController: _nameController,
            phoneController: _phoneController,
            addressController: _addressController,
            noteController: _noteController,
            paymentMethod: _paymentMethod,
            onPaymentChanged: (value) => setState(() => _paymentMethod = value),
          );
          final summary = _CheckoutSummary(
            cart: cart,
            isLoading: orders.isLoading,
            errorMessage: orders.errorMessage,
            onSubmit: _submit,
          );
          return SingleChildScrollView(
            padding: EdgeInsets.all(compact ? 20 : 40),
            child: compact
                ? Column(children: [form, const SizedBox(height: 24), summary])
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 2, child: form),
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

class _ShippingForm extends StatelessWidget {
  const _ShippingForm({
    required this.formKey,
    required this.nameController,
    required this.phoneController,
    required this.addressController,
    required this.noteController,
    required this.paymentMethod,
    required this.onPaymentChanged,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController nameController;
  final TextEditingController phoneController;
  final TextEditingController addressController;
  final TextEditingController noteController;
  final String paymentMethod;
  final ValueChanged<String> onPaymentChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(26),
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Thông tin giao hàng',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 22),
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Họ và tên'),
                validator: (value) => value == null || value.trim().length < 2
                    ? 'Nhập tên người nhận.'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Số điện thoại'),
                validator: (value) => value == null || value.trim().length < 8
                    ? 'Nhập số điện thoại hợp lệ.'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: addressController,
                decoration: const InputDecoration(labelText: 'Địa chỉ'),
                validator: (value) => value == null || value.trim().length < 5
                    ? 'Nhập địa chỉ giao hàng.'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: noteController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Ghi chú (không bắt buộc)',
                ),
              ),
              const SizedBox(height: 26),
              const Text(
                'Phương thức thanh toán',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'COD',
                    icon: Icon(Icons.local_shipping_outlined),
                    label: Text('COD'),
                  ),
                  ButtonSegment(
                    value: 'BANK_TRANSFER',
                    icon: Icon(Icons.account_balance_outlined),
                    label: Text('Chuyển khoản'),
                  ),
                ],
                selected: {paymentMethod},
                onSelectionChanged: (selection) {
                  onPaymentChanged(selection.first);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CheckoutSummary extends StatelessWidget {
  const _CheckoutSummary({
    required this.cart,
    required this.isLoading,
    required this.errorMessage,
    required this.onSubmit,
  });

  final CartProvider cart;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Xác nhận đơn hàng',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 18),
            ...cart.lines.map(
              (line) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${line.product.name} × ${line.quantity}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(formatMoney(line.lineTotal, line.product.currency)),
                  ],
                ),
              ),
            ),
            const Divider(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Tổng dự kiến',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  formatMoney(cart.subtotal, cart.currency ?? ''),
                  style: TextStyle(
                    color: Colors.pink.shade700,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Backend sẽ kiểm tra lại giá, currency và tồn kho khi tạo đơn.',
              style: TextStyle(fontSize: 12),
            ),
            if (errorMessage != null) ...[
              const SizedBox(height: 16),
              Text(
                errorMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: isLoading ? null : onSubmit,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 13),
                child: isLoading
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Tạo đơn hàng'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
