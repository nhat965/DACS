import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/design_tokens.dart';
import '../../models/admin_models.dart';
import '../../providers/auth_provider.dart';
import '../../services/backend_api.dart';
import '../../utils/money.dart';
import 'admin_components.dart';

class ProductsPage extends StatefulWidget {
  const ProductsPage({super.key});

  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
  static const pageSize = 20;
  final searchController = TextEditingController();
  AdminProductPage? result;
  String? status;
  String? error;
  bool loading = true;
  int page = 0;
  Timer? debounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => load());
  }

  @override
  void dispose() {
    debounce?.cancel();
    searchController.dispose();
    super.dispose();
  }

  Future<void> load() async {
    final token = context.read<AuthProvider>().accessToken;
    if (token == null) return;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final value = await context.read<BackendApi>().getAdminProducts(
        accessToken: token,
        search: searchController.text,
        status: status,
        limit: pageSize,
        offset: page * pageSize,
      );
      if (mounted) setState(() => result = value);
    } catch (exception) {
      if (mounted) setState(() => error = BackendApi.readableError(exception));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void searchChanged(String _) {
    debounce?.cancel();
    debounce = Timer(const Duration(milliseconds: 400), () {
      page = 0;
      load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final items = result?.items ?? const <AdminProduct>[];
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        AdminPageHeader(
          title: 'Sản phẩm',
          subtitle: 'Quản lý catalog, trạng thái dữ liệu và tồn kho.',
          actions: [
            FilledButton.icon(
              onPressed: () => context.go('/admin/products/new'),
              icon: const Icon(Icons.add),
              label: const Text('Thêm sản phẩm'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        AdminSectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.md,
                children: [
                  SizedBox(
                    width: 320,
                    child: TextField(
                      controller: searchController,
                      onChanged: searchChanged,
                      decoration: const InputDecoration(
                        labelText: 'Tìm sản phẩm',
                        hintText: 'Tên, SKU hoặc thương hiệu',
                        prefixIcon: Icon(Icons.search),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 210,
                    child: DropdownButtonFormField<String?>(
                      initialValue: status,
                      decoration: const InputDecoration(
                        labelText: 'Trạng thái',
                      ),
                      items: const [
                        DropdownMenuItem(value: null, child: Text('Tất cả')),
                        DropdownMenuItem(
                          value: 'ACTIVE',
                          child: Text('Active'),
                        ),
                        DropdownMenuItem(
                          value: 'INACTIVE',
                          child: Text('Inactive'),
                        ),
                        DropdownMenuItem(value: 'DRAFT', child: Text('Draft')),
                        DropdownMenuItem(
                          value: 'ARCHIVED',
                          child: Text('Archived'),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          status = value;
                          page = 0;
                        });
                        load();
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              if (loading && result == null)
                const AdminLoading(rows: 7)
              else if (error != null)
                AdminMessageState(
                  icon: Icons.cloud_off_outlined,
                  title: 'Không thể tải sản phẩm',
                  message: error!,
                  actionLabel: 'Thử lại',
                  onAction: load,
                )
              else if (items.isEmpty)
                AdminMessageState(
                  icon: Icons.inventory_2_outlined,
                  title: 'Không tìm thấy sản phẩm phù hợp',
                  message: 'Hãy thay đổi từ khóa hoặc bộ lọc trạng thái.',
                  actionLabel: 'Xóa bộ lọc',
                  onAction: () {
                    searchController.clear();
                    setState(() => status = null);
                    load();
                  },
                )
              else ...[
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor: const WidgetStatePropertyAll(
                      AdminColors.softLavender,
                    ),
                    columns: const [
                      DataColumn(label: Text('Sản phẩm')),
                      DataColumn(label: Text('SKU')),
                      DataColumn(label: Text('Brand')),
                      DataColumn(label: Text('Danh mục')),
                      DataColumn(label: Text('Giá')),
                      DataColumn(label: Text('Tồn kho')),
                      DataColumn(label: Text('Trạng thái')),
                      DataColumn(label: Text('AI-ready')),
                      DataColumn(label: Text('')),
                    ],
                    rows: items
                        .map(
                          (product) => DataRow(
                            cells: [
                              DataCell(
                                SizedBox(
                                  width: 230,
                                  child: Text(
                                    product.name,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                              DataCell(Text(product.sku)),
                              DataCell(Text(product.brand)),
                              DataCell(Text(product.category)),
                              DataCell(
                                Text(
                                  formatMoney(product.price, product.currency),
                                ),
                              ),
                              DataCell(Text('${product.stock ?? 0}')),
                              DataCell(AdminStatusBadge(product.status)),
                              DataCell(
                                Icon(
                                  product.aiReady
                                      ? Icons.check_circle
                                      : Icons.remove_circle_outline,
                                  color: product.aiReady
                                      ? AdminColors.success
                                      : AdminColors.textSecondary,
                                ),
                              ),
                              DataCell(
                                PopupMenuButton<String>(
                                  tooltip: 'Thao tác',
                                  onSelected: (value) {
                                    if (value == 'view')
                                      context.go(
                                        '/admin/products/${product.id}',
                                      );
                                    if (value == 'edit')
                                      context.go(
                                        '/admin/products/${product.id}/edit',
                                      );
                                  },
                                  itemBuilder: (_) => const [
                                    PopupMenuItem(
                                      value: 'view',
                                      child: Text('Xem chi tiết'),
                                    ),
                                    PopupMenuItem(
                                      value: 'edit',
                                      child: Text('Chỉnh sửa'),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        )
                        .toList(),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Text('${result!.total} sản phẩm'),
                    const Spacer(),
                    IconButton(
                      tooltip: 'Trang trước',
                      onPressed: page == 0
                          ? null
                          : () {
                              setState(() => page--);
                              load();
                            },
                      icon: const Icon(Icons.chevron_left),
                    ),
                    Text('Trang ${page + 1}'),
                    IconButton(
                      tooltip: 'Trang sau',
                      onPressed: (page + 1) * pageSize >= result!.total
                          ? null
                          : () {
                              setState(() => page++);
                              load();
                            },
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
