import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/design_tokens.dart';
import '../../models/admin_models.dart';
import '../../providers/auth_provider.dart';
import '../../services/backend_api.dart';
import 'admin_components.dart';

class InventoryPage extends StatefulWidget {
  const InventoryPage({super.key});

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  List<AdminProduct>? products;
  String filter = 'ALL';
  String? error;
  int? updatingId;

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
      final result = await context.read<BackendApi>().getAdminInventory(
        accessToken: token,
      );
      if (mounted) setState(() => products = result);
    } catch (exception) {
      if (mounted) setState(() => error = BackendApi.readableError(exception));
    }
  }

  String stateOf(AdminProduct product) {
    final stock = product.stock ?? 0;
    if (stock == 0) return 'OUT OF STOCK';
    if (stock <= 10) return 'LOW STOCK';
    return 'IN STOCK';
  }

  Future<void> editStock(AdminProduct product) async {
    final controller = TextEditingController(text: '${product.stock ?? 0}');
    final result = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cập nhật tồn kho'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(product.name),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Số lượng mới'),
              onSubmitted: (_) {
                final value = int.tryParse(controller.text.trim());
                if (value != null && value >= 0)
                  Navigator.pop(dialogContext, value);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () {
              final value = int.tryParse(controller.text.trim());
              if (value == null || value < 0) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(
                    content: Text('Tồn kho phải là số nguyên không âm.'),
                  ),
                );
                return;
              }
              Navigator.pop(dialogContext, value);
            },
            child: const Text('Cập nhật'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result == null || !mounted) return;
    final token = context.read<AuthProvider>().accessToken;
    if (token == null) return;
    setState(() => updatingId = product.id);
    try {
      final updated = await context.read<BackendApi>().updateAdminProductStock(
        accessToken: token,
        productId: product.id,
        stockQuantity: result,
      );
      if (!mounted) return;
      setState(() {
        products = products!
            .map((item) => item.id == updated.id ? updated : item)
            .toList();
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Đã cập nhật tồn kho.')));
    } catch (exception) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(BackendApi.readableError(exception))),
        );
      }
    } finally {
      if (mounted) setState(() => updatingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = products ?? const <AdminProduct>[];
    final counts = {
      'ALL': items.length,
      'IN STOCK': items.where((item) => stateOf(item) == 'IN STOCK').length,
      'LOW STOCK': items.where((item) => stateOf(item) == 'LOW STOCK').length,
      'OUT OF STOCK': items
          .where((item) => stateOf(item) == 'OUT OF STOCK')
          .length,
    };
    final visible = filter == 'ALL'
        ? items
        : items.where((item) => stateOf(item) == filter).toList();
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        const AdminPageHeader(
          title: 'Kho hàng',
          subtitle: 'Theo dõi tồn kho thực tế và cập nhật số lượng theo từng sản phẩm.',
        ),
        const SizedBox(height: AppSpacing.lg),
        LayoutBuilder(
          builder: (context, constraints) => GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: constraints.maxWidth >= 1050
                ? 4
                : constraints.maxWidth >= 620
                ? 2
                : 1,
            childAspectRatio: 2.6,
            crossAxisSpacing: AppSpacing.md,
            mainAxisSpacing: AppSpacing.md,
            children: [
              AdminStatCard(
                label: 'Tổng sản phẩm',
                value: '${counts['ALL']}',
                icon: Icons.inventory_2_outlined,
              ),
              AdminStatCard(
                label: 'Còn hàng',
                value: '${counts['IN STOCK']}',
                icon: Icons.check_circle_outline,
                color: AdminColors.success,
              ),
              AdminStatCard(
                label: 'Sắp hết',
                value: '${counts['LOW STOCK']}',
                icon: Icons.warning_amber_outlined,
                color: AdminColors.warning,
              ),
              AdminStatCard(
                label: 'Hết hàng',
                value: '${counts['OUT OF STOCK']}',
                icon: Icons.remove_shopping_cart_outlined,
                color: AdminColors.danger,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        AdminSectionCard(
          title: 'Danh sách tồn kho',
          trailing: PopupMenuButton<String>(
            tooltip: 'Lọc trạng thái kho',
            initialValue: filter,
            onSelected: (value) => setState(() => filter = value),
            itemBuilder: (_) => counts.entries
                .map(
                  (entry) => PopupMenuItem(
                    value: entry.key,
                    child: Text('${entry.key} (${entry.value})'),
                  ),
                )
                .toList(),
            child: Chip(label: Text(filter == 'ALL' ? 'Tất cả' : filter)),
          ),
          child: error != null
              ? AdminMessageState(
                  icon: Icons.error_outline,
                  title: 'Không thể tải kho hàng',
                  message: error!,
                  actionLabel: 'Thử lại',
                  onAction: load,
                )
              : products == null
              ? const AdminLoading(rows: 7)
              : visible.isEmpty
              ? const AdminMessageState(
                  icon: Icons.inventory_2_outlined,
                  title: 'Không có sản phẩm',
                  message: 'Không có sản phẩm phù hợp với bộ lọc hiện tại.',
                )
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('Sản phẩm')),
                      DataColumn(label: Text('SKU')),
                      DataColumn(label: Text('Tồn kho'), numeric: true),
                      DataColumn(label: Text('Trạng thái')),
                      DataColumn(label: Text('Cập nhật')),
                    ],
                    rows: visible
                        .map(
                          (product) => DataRow(
                            cells: [
                              DataCell(
                                SizedBox(
                                  width: 280,
                                  child: Text(
                                    product.name,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                              DataCell(Text(product.sku)),
                              DataCell(Text('${product.stock ?? 0}')),
                              DataCell(AdminStatusBadge(stateOf(product))),
                              DataCell(
                                IconButton(
                                  tooltip: 'Cập nhật tồn kho',
                                  onPressed: updatingId == null
                                      ? () => editStock(product)
                                      : null,
                                  icon: updatingId == product.id
                                      ? const SizedBox.square(
                                          dimension: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(Icons.edit_outlined),
                                ),
                              ),
                            ],
                          ),
                        )
                        .toList(),
                  ),
                ),
        ),
      ],
    );
  }
}
