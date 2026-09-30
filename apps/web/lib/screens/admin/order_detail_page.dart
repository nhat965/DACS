import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/design_tokens.dart';
import '../../models/order.dart';
import '../../providers/auth_provider.dart';
import '../../services/backend_api.dart';
import '../../utils/money.dart';
import 'admin_components.dart';

class OrderDetailPage extends StatefulWidget {
  const OrderDetailPage({super.key, required this.orderId});
  final int orderId;

  @override
  State<OrderDetailPage> createState() => _OrderDetailPageState();
}

class _OrderDetailPageState extends State<OrderDetailPage> {
  static const transitions = <String, List<String>>{
    'PENDING': ['CONFIRMED', 'CANCELED'],
    'CONFIRMED': ['PROCESSING', 'CANCELED'],
    'PROCESSING': ['SHIPPING', 'CANCELED'],
    'SHIPPING': ['COMPLETED'],
  };
  CustomerOrder? order;
  String? error;
  bool updating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => load());
  }

  Future<void> load() async {
    final token = context.read<AuthProvider>().accessToken;
    if (token == null) return;
    setState(() => error = null);
    try {
      final value = await context.read<BackendApi>().getAdminOrder(
        accessToken: token,
        orderId: widget.orderId,
      );
      if (mounted) setState(() => order = value);
    } catch (exception) {
      if (mounted) setState(() => error = BackendApi.readableError(exception));
    }
  }

  Future<void> changeStatus(String next) async {
    if (next == 'CANCELED') {
      final accepted = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Hủy đơn hàng?'),
          content: const Text(
            'Thao tác này kết thúc đơn hàng và không thể chuyển sang trạng thái khác.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Quay lại'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Xác nhận hủy'),
            ),
          ],
        ),
      );
      if (accepted != true) return;
    }
    final token = context.read<AuthProvider>().accessToken;
    if (token == null) return;
    setState(() => updating = true);
    try {
      final value = await context.read<BackendApi>().updateAdminOrderStatus(
        accessToken: token,
        orderId: widget.orderId,
        status: next,
      );
      if (!mounted) return;
      setState(() => order = value);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã cập nhật trạng thái đơn hàng.')),
      );
    } catch (exception) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(BackendApi.readableError(exception))),
        );
    } finally {
      if (mounted) setState(() => updating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (error != null)
      return Center(
        child: AdminMessageState(
          icon: Icons.error_outline,
          title: 'Không thể tải đơn hàng',
          message: error!,
          actionLabel: 'Thử lại',
          onAction: load,
        ),
      );
    if (order == null)
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: AdminLoading(rows: 8),
      );
    final item = order!;
    final nextStates = transitions[item.status] ?? const <String>[];
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        AdminPageHeader(
          title: 'Đơn hàng #${item.orderId}',
          subtitle: 'Thông tin giao nhận, thanh toán và sản phẩm trong đơn.',
          actions: [
            OutlinedButton.icon(
              onPressed: () => context.go('/admin/orders'),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Danh sách'),
            ),
            if (nextStates.isNotEmpty)
              PopupMenuButton<String>(
                enabled: !updating,
                onSelected: changeStatus,
                itemBuilder: (_) => nextStates
                    .map(
                      (state) => PopupMenuItem(
                        value: state,
                        child: Text(
                          state == 'CANCELED'
                              ? 'Hủy đơn'
                              : 'Chuyển sang $state',
                        ),
                      ),
                    )
                    .toList(),
                child: IgnorePointer(
                  child: FilledButton.icon(
                    onPressed: () {},
                    icon: updating
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.sync),
                    label: const Text('Cập nhật trạng thái'),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: [
            SizedBox(
              width: 360,
              child: AdminSectionCard(
                title: 'Trạng thái',
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: AdminStatusBadge(item.status),
                ),
              ),
            ),
            SizedBox(
              width: 360,
              child: AdminSectionCard(
                title: 'Thanh toán',
                child: Text(
                  '${item.paymentMethod} · ${formatMoney(item.totalAmount, item.currency)}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth >= 900
                ? (constraints.maxWidth - AppSpacing.md) / 2
                : constraints.maxWidth;
            return Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.md,
              children: [
                SizedBox(
                  width: width,
                  child: AdminSectionCard(
                    title: 'Khách hàng & giao nhận',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.shippingName,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        SelectableText(item.shippingPhone),
                        const SizedBox(height: AppSpacing.xs),
                        Text(item.shippingAddress),
                        if (item.note != null &&
                            item.note!.trim().isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.md),
                          Text('Ghi chú: ${item.note}'),
                        ],
                      ],
                    ),
                  ),
                ),
                SizedBox(
                  width: width,
                  child: AdminSectionCard(
                    title: 'Thông tin đơn',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('User ID: ${item.userId}'),
                        const SizedBox(height: AppSpacing.xs),
                        Text('Số mặt hàng: ${item.items.length}'),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'Tổng số lượng: ${item.items.fold<int>(0, (sum, line) => sum + line.quantity)}',
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: AppSpacing.md),
        AdminSectionCard(
          title: 'Sản phẩm',
          child: Column(
            children: item.items
                .map(
                  (line) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(line.productName),
                    subtitle: Text(
                      'Mã sản phẩm: ${line.productId} · Số lượng: ${line.quantity}',
                    ),
                    trailing: Text(
                      formatMoney(
                        line.unitPrice * line.quantity,
                        item.currency,
                      ),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }
}
