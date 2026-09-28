import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../app/design_tokens.dart';
import '../models/product.dart';
import '../models/recommendation.dart';
import '../providers/catalog_provider.dart';
import '../providers/recommendation_provider.dart';
import '../utils/money.dart';

class AiChatBox extends StatefulWidget {
  const AiChatBox({super.key});

  @override
  State<AiChatBox> createState() => _AiChatBoxState();
}

class _ChatMessage {
  const _ChatMessage({
    required this.user,
    required this.text,
    this.products = const [],
  });

  final bool user;
  final String text;
  final List<Product> products;
}

class _AiChatBoxState extends State<AiChatBox> {
  bool isOpen = false;
  bool loading = false;
  final controller = TextEditingController();
  final scrollController = ScrollController();
  final messages = <_ChatMessage>[
    const _ChatMessage(
      user: false,
      text: 'Mình có thể tìm sản phẩm từ catalog thật theo loại da, concern và mục tiêu của bạn.',
    ),
  ];

  @override
  void dispose() {
    controller.dispose();
    scrollController.dispose();
    super.dispose();
  }

  Future<void> sendMessage() async {
    final message = controller.text.trim();
    if (message.isEmpty || loading) return;
    controller.clear();
    setState(() {
      messages.add(_ChatMessage(user: true, text: message));
      loading = true;
    });
    _scrollToEnd();
    final recommendation = context.read<RecommendationProvider>();
    await recommendation.track(
      eventType: 'chatbot_message',
      metadata: {'messageLength': message.length},
    );
    final contextData = _extractContext(message);
    if (contextData.isEmpty) {
      if (!mounted) return;
      setState(() {
        messages.add(
          const _ChatMessage(
            user: false,
            text: 'Mình chưa đủ tín hiệu để lọc mà không đoán. Hãy cho biết loại da, vấn đề hoặc nhóm sản phẩm, ví dụ: “da dầu mụn, cần serum”.',
          ),
        );
        loading = false;
      });
      _scrollToEnd();
      return;
    }
    await recommendation.loadPersonalized(context: contextData);
    if (!mounted) return;
    final catalog = context.read<CatalogProvider>();
    final recommendationItems =
        recommendation.personalizedResult?.items.take(3).toList() ??
        const <RecommendedProduct>[];
    for (final item in recommendationItems) {
      await catalog.loadProduct(item.productId);
    }
    if (!mounted) return;
    final products = recommendationItems
        .map((item) => catalog.productById(item.productId))
        .whereType<Product>()
        .toList();
    setState(() {
      messages.add(
        _ChatMessage(
          user: false,
          text: products.isEmpty
              ? 'Backend không tìm thấy sản phẩm đủ điểm phù hợp với các điều kiện này.'
              : 'Mình tìm thấy ${products.length} sản phẩm từ recommendation backend. Giá và tên bên dưới lấy trực tiếp từ catalog.',
          products: products,
        ),
      );
      loading = false;
    });
    _scrollToEnd();
  }

  Map<String, dynamic> _extractContext(String input) {
    final text = input.toLowerCase();
    String? skinType;
    if (text.contains('da dầu') || text.contains('dầu')) skinType = 'oily';
    if (text.contains('da khô')) skinType = 'dry';
    if (text.contains('hỗn hợp')) skinType = 'combination';
    if (text.contains('nhạy cảm')) skinType = 'sensitive';
    final concerns = <String>[
      if (text.contains('mụn')) 'acne',
      if (text.contains('khô')) 'dryness',
      if (text.contains('đỏ')) 'redness',
      if (text.contains('thâm')) 'dark_spot',
      if (text.contains('lão hóa')) 'aging',
      if (text.contains('lỗ chân lông')) 'large_pores',
    ];
    final goals = <String>[
      if (text.contains('cấp ẩm') || text.contains('dưỡng ẩm')) 'hydrate',
      if (text.contains('làm sáng')) 'brighten',
      if (text.contains('kiểm soát dầu')) 'oil_control',
      if (text.contains('mụn')) 'anti_acne',
      if (text.contains('chống nắng')) 'sun_protection',
    ];
    final categories = <String>[
      if (text.contains('serum')) 'serum',
      if (text.contains('sữa rửa mặt')) 'cleanser',
      if (text.contains('toner')) 'toner',
      if (text.contains('kem dưỡng')) 'moisturizer',
      if (text.contains('mặt nạ')) 'mask',
      if (text.contains('son')) 'lip_care',
    ];
    if (skinType == null &&
        concerns.isEmpty &&
        goals.isEmpty &&
        categories.isEmpty) {
      return const {};
    }
    return {
      'skinType': ?skinType,
      'skinConcerns': concerns,
      'careGoals': goals,
      'preferredCategories': categories,
    };
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!scrollController.hasClients) {
        return;
      }
      scrollController.animateTo(
        scrollController.position.maxScrollExtent,
        duration: AppDurations.component,
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: AppSpacing.lg,
      bottom: AppSpacing.lg,
      child: isOpen ? _buildChatWindow() : _buildChatButton(),
    );
  }

  Widget _buildChatButton() {
    final compact = MediaQuery.sizeOf(context).width < 600;
    if (compact) {
      return FloatingActionButton.small(
        tooltip: 'Mở trợ lý Lumi AI',
        onPressed: () => setState(() => isOpen = true),
        child: const Icon(Icons.auto_awesome_outlined),
      );
    }
    return FloatingActionButton.extended(
      onPressed: () => setState(() => isOpen = true),
      icon: const Icon(Icons.auto_awesome_outlined),
      label: const Text('LUMI AI'),
    );
  }

  Widget _buildChatWindow() {
    final screen = MediaQuery.sizeOf(context);
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(AppRadius.feature),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: screen.width < 430 ? screen.width - AppSpacing.xl : 390,
        height: screen.height < 650 ? screen.height - 80 : 560,
        child: Column(
          children: [
            ColoredBox(
              color: AppColors.plum,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.auto_awesome_outlined,
                      color: AppColors.paper,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'Lumi Beauty Assistant',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(color: AppColors.paper),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Đóng',
                      onPressed: () => setState(() => isOpen = false),
                      icon: const Icon(Icons.close, color: AppColors.paper),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                padding: const EdgeInsets.all(AppSpacing.md),
                itemCount: messages.length + (loading ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == messages.length) {
                    return const Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: EdgeInsets.all(AppSpacing.sm),
                        child: SizedBox.square(
                          dimension: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    );
                  }
                  return _MessageBubble(message: messages[index]);
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      enabled: !loading,
                      onSubmitted: (_) => sendMessage(),
                      decoration: const InputDecoration(
                        hintText: 'Ví dụ: da dầu mụn, cần serum',
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  IconButton.filled(
                    tooltip: 'Gửi',
                    onPressed: loading ? null : sendMessage,
                    icon: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final _ChatMessage message;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: message.user ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: const EdgeInsets.all(AppSpacing.sm),
        constraints: const BoxConstraints(maxWidth: 310),
        decoration: BoxDecoration(
          color: message.user ? AppColors.paleRose : AppColors.ivory,
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message.text),
            ...message.products.map(
              (product) => ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  product.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(formatMoney(product.price, product.currency)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.go('/product/${product.id}'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
