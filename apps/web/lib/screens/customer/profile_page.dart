import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/order_provider.dart';
import '../../providers/preferences_provider.dart';
import '../../models/beauty_preferences.dart';
import '../../app/design_tokens.dart';
import '../../utils/money.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<OrderProvider>().loadOrders();
      context.read<PreferencesProvider>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final orders = context.watch<OrderProvider>();
    final preferences = context.watch<PreferencesProvider>();
    final user = auth.user!;

    return Scaffold(
      appBar: AppBar(title: const Text('Tài khoản cá nhân')),
      body: RefreshIndicator(
        onRefresh: () => context.read<OrderProvider>().loadOrders(),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(26),
                        child: Row(
                          children: [
                            const CircleAvatar(
                              radius: 38,
                              child: Icon(Icons.person_outline, size: 38),
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    user.fullName,
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(user.email),
                                  const SizedBox(height: 4),
                                  Text(
                                    user.role,
                                    style: TextStyle(
                                      color: Colors.pink.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            OutlinedButton.icon(
                              onPressed: () async {
                                await auth.logout();
                                if (!context.mounted) return;
                                context.go('/');
                              },
                              icon: const Icon(Icons.logout),
                              label: const Text('Đăng xuất'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    _BeautyProfileCard(state: preferences),
                    const SizedBox(height: 28),
                    const Text(
                      'Đơn hàng của tôi',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (orders.isLoading && orders.orders.isEmpty)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(36),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    else if (orders.errorMessage != null)
                      _OrderMessage(
                        message: orders.errorMessage!,
                        actionLabel: 'Thử lại',
                        onAction: () => orders.loadOrders(),
                      )
                    else if (orders.orders.isEmpty)
                      _OrderMessage(
                        message: 'Bạn chưa có đơn hàng nào.',
                        actionLabel: 'Mua sắm ngay',
                        onAction: () => context.go('/'),
                      )
                    else
                      ...orders.orders.map(
                        (order) => Card(
                          margin: const EdgeInsets.only(bottom: 14),
                          child: ExpansionTile(
                            title: Text(
                              'Đơn #${order.orderId}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            subtitle: Text(
                              '${order.status} · ${formatMoney(order.totalAmount, order.currency)}',
                            ),
                            children: order.items
                                .map(
                                  (item) => ListTile(
                                    title: Text(item.productName),
                                    subtitle: Text(
                                      'Số lượng: ${item.quantity}',
                                    ),
                                    trailing: Text(
                                      formatMoney(
                                        item.unitPrice * item.quantity,
                                        order.currency,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BeautyProfileCard extends StatelessWidget {
  const _BeautyProfileCard({required this.state});

  final PreferencesProvider state;

  @override
  Widget build(BuildContext context) {
    final preferences = state.preferences;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Hồ sơ làm đẹp của tôi',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () => context.go('/onboarding'),
                  icon: const Icon(Icons.edit_outlined),
                  label: Text(
                    preferences?.completed == true ? 'Chỉnh sửa' : 'Hoàn thiện',
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            if (state.isLoading && preferences == null)
              const Center(child: CircularProgressIndicator())
            else if (state.errorMessage != null)
              Text(
                state.errorMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              )
            else if (preferences == null || !preferences.completed)
              const Text('Bạn chưa lưu thông tin loại da và mục tiêu chăm sóc.')
            else
              _PreferenceDetails(preferences: preferences),
            if (preferences?.completed == true) ...[
              const SizedBox(height: AppSpacing.lg),
              FilledButton.icon(
                onPressed: () => context.go('/recommendations'),
                icon: const Icon(Icons.auto_awesome_outlined),
                label: const Text('Xem sản phẩm dành cho tôi'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PreferenceDetails extends StatelessWidget {
  const _PreferenceDetails({required this.preferences});

  final BeautyPreferences preferences;

  @override
  Widget build(BuildContext context) {
    final values = <String>[
      if (preferences.skinType != null) 'Da: ${preferences.skinType}',
      ...preferences.skinConcerns.map(
        (value) => 'Concern: ${value.replaceAll('_', ' ')}',
      ),
      ...preferences.careGoals.map(
        (value) => 'Mục tiêu: ${value.replaceAll('_', ' ')}',
      ),
      ...preferences.preferredCategories.map(
        (value) => 'Danh mục: ${value.replaceAll('_', ' ')}',
      ),
      if (preferences.budgetMin != null || preferences.budgetMax != null)
        'Ngân sách: ${preferences.budgetMin?.toStringAsFixed(0) ?? '0'}–${preferences.budgetMax?.toStringAsFixed(0) ?? '∞'} ${preferences.currency}',
    ];
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: values.map((value) => Chip(label: Text(value))).toList(),
    );
  }
}

class _OrderMessage extends StatelessWidget {
  const _OrderMessage({
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36),
      child: Column(
        children: [
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onAction, child: Text(actionLabel)),
        ],
      ),
    );
  }
}
