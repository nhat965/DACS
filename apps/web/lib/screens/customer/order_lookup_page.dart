import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/design_tokens.dart';
import '../../models/order.dart';
import '../../providers/auth_provider.dart';
import '../../providers/order_provider.dart';
import '../../utils/money.dart';
import '../../widgets/app_footer.dart';
import '../../widgets/app_header.dart';
import '../../widgets/lumi_content_container.dart';
import '../../widgets/lumi_page_background.dart';
import '../../widgets/lumi_states.dart';

class OrderLookupPage extends StatefulWidget {
  const OrderLookupPage({super.key});

  @override
  State<OrderLookupPage> createState() => _OrderLookupPageState();
}

class _OrderLookupPageState extends State<OrderLookupPage> {
  String? loadedToken;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final token = Provider.of<AuthProvider>(context).accessToken;
    if (token != null && token != loadedToken) {
      loadedToken = token;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.read<OrderProvider>().loadOrders();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final orders = context.watch<OrderProvider>();
    return Scaffold(
      body: Column(
        children: [
          const AppHeader(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => context.read<OrderProvider>().loadOrders(),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  LumiContentContainer(
                    verticalPadding: AppSpacing.xl,
                    maxWidth: 1040,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _PageHeading(
                          refreshing: orders.isLoading,
                          onRefresh: () =>
                              context.read<OrderProvider>().loadOrders(),
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        if (orders.isLoading && orders.orders.isEmpty)
                          const _OrderLoading()
                        else if (orders.errorMessage != null)
                          LumiStateCard(
                            icon: Icons.cloud_off_outlined,
                            title: 'Chưa tải được đơn hàng',
                            message: orders.errorMessage!,
                            actionLabel: 'Thử lại',
                            onAction: () =>
                                context.read<OrderProvider>().loadOrders(),
                          )
                        else if (orders.orders.isEmpty)
                          LumiStateCard(
                            icon: Icons.receipt_long_outlined,
                            title: 'Bạn chưa có đơn hàng',
                            message: 'Khi đặt hàng thành công, sản phẩm và trạng thái xử lý sẽ xuất hiện tại đây.',
                            actionLabel: 'Tiếp tục mua sắm',
                            onAction: () => context.go('/'),
                          )
                        else
                          ...orders.orders.map(
                            (order) => Padding(
                              padding: const EdgeInsets.only(
                                bottom: AppSpacing.lg,
                              ),
                              child: _CustomerOrderCard(order: order),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const AppFooter(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PageHeading extends StatelessWidget {
  const _PageHeading({required this.refreshing, required this.onRefresh});

  final bool refreshing;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final heading = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Đơn hàng của tôi',
              style: Theme.of(context).textTheme.displaySmall,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Theo dõi sản phẩm đã đặt và trạng thái xử lý mới nhất từ Lumi.',
              style: Theme.of(context).textTheme.bodyLarge
                  ?.copyWith(color: AppColors.mutedInk),
            ),
          ],
        );
        if (constraints.maxWidth < 620) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              heading,
              const SizedBox(height: AppSpacing.md),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: refreshing ? null : onRefresh,
                  icon: refreshing
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh),
                  label: const Text('Cập nhật trạng thái'),
                ),
              ),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(child: heading),
            OutlinedButton.icon(
              onPressed: refreshing ? null : onRefresh,
              icon: refreshing
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh),
              label: const Text('Cập nhật trạng thái'),
            ),
          ],
        );
      },
    );
  }
}

class _CustomerOrderCard extends StatelessWidget {
  const _CustomerOrderCard({required this.order});

  final CustomerOrder order;

  @override
  Widget build(BuildContext context) {
    return LumiSectionSurface(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final identity = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Đơn #${order.orderId}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    _formatDate(order.createdAt),
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(color: AppColors.mutedInk),
                  ),
                ],
              );
              if (constraints.maxWidth < 560) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    identity,
                    const SizedBox(height: AppSpacing.sm),
                    _OrderStatusBadge(status: order.status),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: identity),
                  _OrderStatusBadge(status: order.status),
                ],
              );
            },
          ),
          const SizedBox(height: AppSpacing.lg),
          _OrderProgress(status: order.status),
          const Divider(height: AppSpacing.xl),
          Text(
            'Sản phẩm đã đặt',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          ...order.items.map(
            (item) => _OrderItemRow(item: item, currency: order.currency),
          ),
          const Divider(height: AppSpacing.xl),
          LayoutBuilder(
            builder: (context, constraints) {
              final delivery = _OrderFact(
                icon: Icons.local_shipping_outlined,
                label: 'Giao đến',
                value:
                    '${order.shippingName} · ${order.shippingPhone}\n${order.shippingAddress}',
              );
              final payment = _OrderFact(
                icon: Icons.payments_outlined,
                label: 'Thanh toán',
                value: order.paymentMethod,
              );
              if (constraints.maxWidth < 680) {
                return Column(
                  children: [
                    delivery,
                    const SizedBox(height: AppSpacing.md),
                    payment,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: delivery),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(flex: 2, child: payment),
                ],
              );
            },
          ),
          const Divider(height: AppSpacing.xl),
          Row(
            children: [
              Text(
                '${order.items.fold<int>(0, (sum, item) => sum + item.quantity)} sản phẩm',
                style: TextStyle(color: AppColors.mutedInk),
              ),
              const Spacer(),
              Text('Tổng cộng', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(width: AppSpacing.sm),
              Text(
                formatMoney(order.totalAmount, order.currency),
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(color: AppColors.rose),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OrderItemRow extends StatelessWidget {
  const _OrderItemRow({required this.item, required this.currency});

  final OrderItem item;
  final String currency;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.lavenderMist,
              borderRadius: BorderRadius.circular(AppRadius.control),
            ),
            child: const Icon(
              Icons.spa_outlined,
              color: AppColors.plum,
              size: 21,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  'Số lượng: ${item.quantity} · ${formatMoney(item.unitPrice, currency)}/sản phẩm',
                  style: TextStyle(color: AppColors.mutedInk),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            formatMoney(item.unitPrice * item.quantity, currency),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _OrderFact extends StatelessWidget {
  const _OrderFact({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.plum, size: 22),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(color: AppColors.mutedInk)),
              const SizedBox(height: AppSpacing.xxs),
              Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
    );
  }
}

class _OrderStatusBadge extends StatelessWidget {
  const _OrderStatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        _statusLabel(status),
        style: TextStyle(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _OrderProgress extends StatelessWidget {
  const _OrderProgress({required this.status});

  final String status;

  static const steps = [
    ('PENDING', 'Đã đặt'),
    ('CONFIRMED', 'Đã xác nhận'),
    ('PROCESSING', 'Chuẩn bị hàng'),
    ('SHIPPING', 'Đang giao'),
    ('COMPLETED', 'Hoàn thành'),
  ];

  @override
  Widget build(BuildContext context) {
    if (status == 'CANCELED') {
      return Row(
        children: [
          const Icon(Icons.cancel_outlined, color: AppColors.error),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Đơn hàng đã được hủy.',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(color: AppColors.error),
            ),
          ),
        ],
      );
    }
    final current = steps.indexWhere((step) => step.$1 == status);
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 620) {
          return Column(
            children: List.generate(steps.length, (index) {
              final reached = current >= index;
              return _VerticalProgressStep(
                label: steps[index].$2,
                reached: reached,
                last: index == steps.length - 1,
              );
            }),
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: List.generate(steps.length * 2 - 1, (index) {
            if (index.isOdd) {
              final completed = current >= (index + 1) ~/ 2;
              return Expanded(
                child: Container(
                  height: 2,
                  margin: const EdgeInsets.only(top: 15),
                  color: completed ? AppColors.rose : AppColors.line,
                ),
              );
            }
            final stepIndex = index ~/ 2;
            final reached = current >= stepIndex;
            return SizedBox(
              width: 94,
              child: Column(
                children: [
                  _ProgressDot(reached: reached),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    steps[stepIndex].$2,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: reached ? FontWeight.w700 : FontWeight.w500,
                      color: reached ? AppColors.ink : AppColors.mutedInk,
                    ),
                  ),
                ],
              ),
            );
          }),
        );
      },
    );
  }
}

class _VerticalProgressStep extends StatelessWidget {
  const _VerticalProgressStep({
    required this.label,
    required this.reached,
    required this.last,
  });

  final String label;
  final bool reached;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            _ProgressDot(reached: reached),
            if (!last)
              Container(
                width: 2,
                height: 24,
                color: reached ? AppColors.rose : AppColors.line,
              ),
          ],
        ),
        const SizedBox(width: AppSpacing.sm),
        Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Text(
            label,
            style: TextStyle(
              fontWeight: reached ? FontWeight.w700 : FontWeight.w500,
              color: reached ? AppColors.ink : AppColors.mutedInk,
            ),
          ),
        ),
      ],
    );
  }
}

class _ProgressDot extends StatelessWidget {
  const _ProgressDot({required this.reached});

  final bool reached;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: AppDurations.feedback,
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: reached ? AppColors.rose : AppColors.surface,
        shape: BoxShape.circle,
        border: Border.all(color: reached ? AppColors.rose : AppColors.line),
      ),
      child: Icon(
        reached ? Icons.check : Icons.circle_outlined,
        size: 17,
        color: reached ? AppColors.surface : AppColors.mutedInk,
      ),
    );
  }
}

class _OrderLoading extends StatelessWidget {
  const _OrderLoading();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        LumiSkeletonBox(height: 280, radius: AppRadius.feature),
        SizedBox(height: AppSpacing.lg),
        LumiSkeletonBox(height: 220, radius: AppRadius.feature),
      ],
    );
  }
}

String _statusLabel(String status) => switch (status.toUpperCase()) {
  'PENDING' => 'Chờ xác nhận',
  'CONFIRMED' => 'Đã xác nhận',
  'PROCESSING' => 'Đang chuẩn bị hàng',
  'SHIPPING' => 'Đang giao hàng',
  'COMPLETED' => 'Đã hoàn thành',
  'CANCELED' => 'Đã hủy',
  _ => status,
};

Color _statusColor(String status) => switch (status.toUpperCase()) {
  'PENDING' => AppColors.warning,
  'CONFIRMED' || 'PROCESSING' => AppColors.focus,
  'SHIPPING' => AppColors.lumiBlue,
  'COMPLETED' => AppColors.success,
  'CANCELED' => AppColors.error,
  _ => AppColors.mutedInk,
};

String _formatDate(DateTime? value) {
  if (value == null) return 'Không có thời gian tạo đơn';
  final local = value.toLocal();
  String two(int number) => number.toString().padLeft(2, '0');
  return 'Đặt lúc ${two(local.hour)}:${two(local.minute)} · ${two(local.day)}/${two(local.month)}/${local.year}';
}
