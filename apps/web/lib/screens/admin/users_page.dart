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

class UsersPage extends StatefulWidget {
  const UsersPage({super.key});

  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  final searchController = TextEditingController();
  List<AdminUser>? users;
  String? error;
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

  void search(String _) {
    debounce?.cancel();
    debounce = Timer(const Duration(milliseconds: 400), load);
  }

  Future<void> load() async {
    final token = context.read<AuthProvider>().accessToken;
    if (token == null) return;
    setState(() => error = null);
    try {
      final result = await context.read<BackendApi>().getAdminUsers(
        accessToken: token,
        search: searchController.text,
      );
      if (mounted) setState(() => users = result);
    } catch (exception) {
      if (mounted) setState(() => error = BackendApi.readableError(exception));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        const AdminPageHeader(
          title: 'Người dùng',
          subtitle: 'Tra cứu tài khoản, hồ sơ làm đẹp và lịch sử mua hàng.',
        ),
        const SizedBox(height: AppSpacing.lg),
        AdminSectionCard(
          child: Column(
            children: [
              TextField(
                controller: searchController,
                onChanged: search,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: 'Tìm theo tên hoặc email',
                  suffixIcon: searchController.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Xóa tìm kiếm',
                          onPressed: () {
                            searchController.clear();
                            load();
                          },
                          icon: const Icon(Icons.close),
                        ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              if (error != null)
                AdminMessageState(
                  icon: Icons.error_outline,
                  title: 'Không thể tải người dùng',
                  message: error!,
                  actionLabel: 'Thử lại',
                  onAction: load,
                )
              else if (users == null)
                const AdminLoading(rows: 7)
              else if (users!.isEmpty)
                const AdminMessageState(
                  icon: Icons.people_outline,
                  title: 'Không tìm thấy người dùng',
                  message: 'Hãy thử một từ khóa khác.',
                )
              else
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    showCheckboxColumn: false,
                    columns: const [
                      DataColumn(label: Text('Người dùng')),
                      DataColumn(label: Text('Email')),
                      DataColumn(label: Text('Vai trò')),
                      DataColumn(label: Text('Loại da')),
                      DataColumn(label: Text('Đơn hàng'), numeric: true),
                    ],
                    rows: users!
                        .map(
                          (user) => DataRow(
                            onSelectChanged: (_) =>
                                context.go('/admin/users/${user.userId}'),
                            cells: [
                              DataCell(
                                SizedBox(
                                  width: 180,
                                  child: Text(
                                    user.fullName,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                              DataCell(SelectableText(user.email)),
                              DataCell(AdminStatusBadge(user.role)),
                              DataCell(Text(user.skinType ?? 'Chưa cập nhật')),
                              DataCell(Text('${user.orderCount}')),
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

class UserDetailPage extends StatefulWidget {
  const UserDetailPage({super.key, required this.userId});
  final int userId;

  @override
  State<UserDetailPage> createState() => _UserDetailPageState();
}

class _UserDetailPageState extends State<UserDetailPage> {
  AdminUser? user;
  String? error;

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
      final result = await context.read<BackendApi>().getAdminUser(
        accessToken: token,
        userId: widget.userId,
      );
      if (mounted) setState(() => user = result);
    } catch (exception) {
      if (mounted) setState(() => error = BackendApi.readableError(exception));
    }
  }

  String preferenceLabel(Object? value) {
    if (value == null) return 'Chưa cập nhật';
    if (value is List)
      return value.isEmpty ? 'Chưa cập nhật' : value.join(', ');
    if (value is bool) return value ? 'Đã hoàn thành' : 'Chưa hoàn thành';
    return value.toString();
  }

  @override
  Widget build(BuildContext context) {
    if (error != null)
      return Center(
        child: AdminMessageState(
          icon: Icons.error_outline,
          title: 'Không thể tải hồ sơ',
          message: error!,
          actionLabel: 'Thử lại',
          onAction: load,
        ),
      );
    if (user == null)
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: AdminLoading(rows: 8),
      );
    final item = user!;
    const labels = <String, String>{
      'skinType': 'Loại da',
      'skinConcerns': 'Vấn đề da',
      'careGoals': 'Mục tiêu chăm sóc',
      'preferredCategories': 'Danh mục yêu thích',
      'preferredBrands': 'Thương hiệu yêu thích',
      'avoidIngredients': 'Thành phần cần tránh',
      'budgetMin': 'Ngân sách tối thiểu',
      'budgetMax': 'Ngân sách tối đa',
      'currency': 'Tiền tệ',
    };
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        AdminPageHeader(
          title: item.fullName,
          subtitle: 'User ID ${item.userId} · ${item.role}',
          actions: [
            OutlinedButton.icon(
              onPressed: () => context.go('/admin/users'),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Danh sách'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
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
                    title: 'Tài khoản',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SelectableText(
                          item.email,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        AdminStatusBadge(item.role),
                        const SizedBox(height: AppSpacing.sm),
                        Text('${item.orderCount} đơn hàng'),
                      ],
                    ),
                  ),
                ),
                SizedBox(
                  width: width,
                  child: AdminSectionCard(
                    title: 'Hồ sơ làm đẹp',
                    child: item.preferences.isEmpty
                        ? const Text(
                            'Người dùng chưa hoàn thành hồ sơ làm đẹp.',
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: labels.entries
                                .map(
                                  (entry) => Padding(
                                    padding: const EdgeInsets.only(
                                      bottom: AppSpacing.sm,
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        SizedBox(
                                          width: 160,
                                          child: Text(
                                            entry.value,
                                            style: const TextStyle(
                                              color: AdminColors.textSecondary,
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          child: Text(
                                            preferenceLabel(
                                              item.preferences[entry.key],
                                            ),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: AppSpacing.md),
        AdminSectionCard(
          title: 'Lịch sử đơn hàng',
          child: item.orders.isEmpty
              ? const AdminMessageState(
                  icon: Icons.receipt_long_outlined,
                  title: 'Chưa có đơn hàng',
                  message: 'Tài khoản này chưa phát sinh đơn hàng.',
                )
              : Column(
                  children: item.orders
                      .map(
                        (order) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          onTap: () =>
                              context.go('/admin/orders/${order.orderId}'),
                          title: Text(
                            '#${order.orderId}',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(
                            '${order.items.length} mặt hàng · ${order.paymentMethod}',
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              AdminStatusBadge(order.status),
                              const SizedBox(height: 4),
                              Text(
                                formatMoney(order.totalAmount, order.currency),
                              ),
                            ],
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
