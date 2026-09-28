import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/order_provider.dart';
import '../../utils/money.dart';

class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<OrderProvider>().loadOrders(admin: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<OrderProvider>();
    if (provider.isLoading && provider.orders.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (provider.errorMessage != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(provider.errorMessage!),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => provider.loadOrders(admin: true),
              child: const Text('Thử lại'),
            ),
          ],
        ),
      );
    }
    if (provider.orders.isEmpty) {
      return const Center(child: Text('Chưa có đơn hàng nào.'));
    }
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Card(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: const [
              DataColumn(label: Text('Mã đơn')),
              DataColumn(label: Text('User ID')),
              DataColumn(label: Text('Người nhận')),
              DataColumn(label: Text('Trạng thái')),
              DataColumn(label: Text('Tổng tiền')),
              DataColumn(label: Text('Thanh toán')),
            ],
            rows: provider.orders
                .map(
                  (order) => DataRow(
                    cells: [
                      DataCell(Text('#${order.orderId}')),
                      DataCell(Text('${order.userId}')),
                      DataCell(Text(order.shippingName)),
                      DataCell(Text(order.status)),
                      DataCell(
                        Text(formatMoney(order.totalAmount, order.currency)),
                      ),
                      DataCell(Text(order.paymentMethod)),
                    ],
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }
}
