import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/design_tokens.dart';
import '../../providers/order_provider.dart';
import '../../utils/money.dart';
import 'admin_components.dart';

class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  final searchController = TextEditingController();
  String status = 'ALL';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<OrderProvider>().loadOrders(admin: true),
    );
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  String date(DateTime? value) {
    if (value == null) return '—';
    String two(int number) => number.toString().padLeft(2, '0');
    return '${two(value.day)}/${two(value.month)}/${value.year} ${two(value.hour)}:${two(value.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<OrderProvider>();
    final query = searchController.text.trim().toLowerCase();
    final visible = provider.orders.where((order) {
      final matchesStatus = status == 'ALL' || order.status == status;
      final matchesQuery =
          query.isEmpty ||
          '${order.orderId}'.contains(query) ||
          order.shippingName.toLowerCase().contains(query) ||
          order.shippingPhone.toLowerCase().contains(query);
      return matchesStatus && matchesQuery;
    }).toList();
    const statuses = [
      'ALL',
      'PENDING',
      'CONFIRMED',
      'PROCESSING',
      'SHIPPING',
      'COMPLETED',
      'CANCELED',
    ];
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        const AdminPageHeader(
          title: 'Đơn hàng',
          subtitle: 'Theo dõi, xác nhận và cập nhật tiến trình xử lý đơn hàng.',
        ),
        const SizedBox(height: AppSpacing.lg),
        AdminSectionCard(
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: searchController,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        hintText:
                            'Tìm theo mã đơn, người nhận hoặc số điện thoại',
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  IconButton(
                    tooltip: 'Tải lại',
                    onPressed: provider.isLoading
                        ? null
                        : () => provider.loadOrders(admin: true),
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Align(
                alignment: Alignment.centerLeft,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SegmentedButton<String>(
                    segments: statuses
                        .map(
                          (item) => ButtonSegment(
                            value: item,
                            label: Text(item == 'ALL' ? 'Tất cả' : item),
                          ),
                        )
                        .toList(),
                    selected: {status},
                    onSelectionChanged: (selection) =>
                        setState(() => status = selection.first),
                    showSelectedIcon: false,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              if (provider.isLoading && provider.orders.isEmpty)
                const AdminLoading(rows: 7)
              else if (provider.errorMessage != null)
                AdminMessageState(
                  icon: Icons.error_outline,
                  title: 'Không thể tải đơn hàng',
                  message: provider.errorMessage!,
                  actionLabel: 'Thử lại',
                  onAction: () => provider.loadOrders(admin: true),
                )
              else if (visible.isEmpty)
                const AdminMessageState(
                  icon: Icons.receipt_long_outlined,
                  title: 'Không có đơn hàng',
                  message: 'Không tìm thấy đơn phù hợp với điều kiện hiện tại.',
                )
              else
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    showCheckboxColumn: false,
                    columns: const [
                      DataColumn(label: Text('Mã đơn')),
                      DataColumn(label: Text('Ngày tạo')),
                      DataColumn(label: Text('Người nhận')),
                      DataColumn(label: Text('Trạng thái')),
                      DataColumn(label: Text('Tổng tiền'), numeric: true),
                      DataColumn(label: Text('Thanh toán')),
                    ],
                    rows: visible
                        .map(
                          (order) => DataRow(
                            onSelectChanged: (_) =>
                                context.go('/admin/orders/${order.orderId}'),
                            cells: [
                              DataCell(
                                Text(
                                  '#${order.orderId}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              DataCell(Text(date(order.createdAt))),
                              DataCell(
                                SizedBox(
                                  width: 180,
                                  child: Text(
                                    order.shippingName,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                              DataCell(AdminStatusBadge(order.status)),
                              DataCell(
                                Text(
                                  formatMoney(
                                    order.totalAmount,
                                    order.currency,
                                  ),
                                ),
                              ),
                              DataCell(Text(order.paymentMethod)),
                            ],
                          ),
                        )
                        .toList(),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
