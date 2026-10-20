import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../app/design_tokens.dart';
import '../models/ai_chat.dart';
import '../providers/ai_chat_provider.dart';
import '../utils/money.dart';

class AiChatBox extends StatefulWidget {
  const AiChatBox({super.key});

  @override
  State<AiChatBox> createState() => _AiChatBoxState();
}

class _AiChatBoxState extends State<AiChatBox> {
  bool isOpen = false;
  final controller = TextEditingController();
  final scrollController = ScrollController();

  @override
  void dispose() {
    controller.dispose();
    scrollController.dispose();
    super.dispose();
  }

  Future<void> sendMessage([String? suggestedMessage]) async {
    final message = (suggestedMessage ?? controller.text).trim();
    if (message.isEmpty) return;
    controller.clear();
    await context.read<AiChatProvider>().send(message);
    _scrollToEnd();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!scrollController.hasClients) return;
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
        tooltip: 'Mở chuyên viên tư vấn Lumi AI',
        onPressed: () => setState(() => isOpen = true),
        child: const Icon(Icons.auto_awesome_outlined),
      );
    }
    return FloatingActionButton.extended(
      tooltip: 'Mở chuyên viên tư vấn Lumi AI',
      onPressed: () => setState(() => isOpen = true),
      icon: const Icon(Icons.auto_awesome_outlined),
      label: const Text('Tư vấn cùng Lumi AI'),
    );
  }

  Widget _buildChatWindow() {
    final screen = MediaQuery.sizeOf(context);
    return Material(
      elevation: 8,
      shadowColor: AppColors.ink.withValues(alpha: 0.18),
      borderRadius: BorderRadius.circular(AppRadius.feature),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: screen.width < 430 ? screen.width - AppSpacing.xl : 410,
        height: screen.height < 650 ? screen.height - 80 : 600,
        child: Consumer<AiChatProvider>(
          builder: (context, chat, _) {
            WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToEnd());
            return Column(
              children: [
                _ChatHeader(onClose: () => setState(() => isOpen = false)),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.all(AppSpacing.md),
                    itemCount: chat.messages.length + (chat.isLoading ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == chat.messages.length) {
                        return const _ThinkingIndicator();
                      }
                      return _MessageBubble(
                        message: chat.messages[index],
                        onSuggestionTap: sendMessage,
                      );
                    },
                  ),
                ),
                if (chat.errorMessage != null)
                  _ChatError(
                    message: chat.errorMessage!,
                    onRetry: () {
                      final lastUser = chat.messages.lastWhere(
                        (message) => message.isUser,
                      );
                      chat.clearError();
                      sendMessage(lastUser.text);
                    },
                  ),
                _ChatComposer(
                  controller: controller,
                  loading: chat.isLoading,
                  onSend: sendMessage,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ChatHeader extends StatelessWidget {
  const _ChatHeader({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.plum,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            const Icon(Icons.auto_awesome_outlined, color: AppColors.paper),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Lumi AI',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.paper,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    'Tư vấn từ catalog Lumi Beauty',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.paper.withValues(alpha: 0.82),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Đóng tư vấn',
              onPressed: onClose,
              icon: const Icon(Icons.close, color: AppColors.paper),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatComposer extends StatelessWidget {
  const _ChatComposer({
    required this.controller,
    required this.loading,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool loading;
  final Future<void> Function([String?]) onSend;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                enabled: !loading,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                decoration: const InputDecoration(
                  hintText: 'Ví dụ: Da khô, cần làm dịu, dưới 500k…',
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            IconButton.filled(
              tooltip: 'Gửi câu hỏi',
              onPressed: loading ? null : () => onSend(),
              icon: const Icon(Icons.send_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThinkingIndicator extends StatelessWidget {
  const _ThinkingIndicator();

  @override
  Widget build(BuildContext context) {
    return const Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: EdgeInsets.only(bottom: AppSpacing.sm),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.ivory,
            borderRadius: BorderRadius.all(Radius.circular(AppRadius.card)),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: AppSpacing.sm),
                Text('Đang đối chiếu sản phẩm…'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ChatError extends StatelessWidget {
  const _ChatError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.sm,
        0,
        AppSpacing.sm,
        AppSpacing.xs,
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppColors.paleRose,
          borderRadius: BorderRadius.circular(AppRadius.control),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline, size: 20, color: AppColors.plum),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: Text(message)),
            TextButton(onPressed: onRetry, child: const Text('Thử lại')),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.onSuggestionTap});

  final AiChatMessage message;
  final ValueChanged<String> onSuggestionTap;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: const EdgeInsets.all(AppSpacing.sm),
        constraints: const BoxConstraints(maxWidth: 340),
        decoration: BoxDecoration(
          color: message.isUser ? AppColors.paleRose : AppColors.ivory,
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SelectableText(message.text),
            if (message.missingInformation.isNotEmpty)
              _MissingInformation(items: message.missingInformation),
            if (message.routine.isNotEmpty)
              _RoutinePlan(steps: message.routine),
            if (message.cautions.isNotEmpty)
              _CautionList(items: message.cautions),
            ...message.recommendations.map(
              (item) => _RecommendedProductTile(item: item),
            ),
            if (message.followUpQuestions.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: message.followUpQuestions
                    .map(
                      (question) => ActionChip(
                        label: Text(question),
                        onPressed: () => onSuggestionTap(question),
                      ),
                    )
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MissingInformation extends StatelessWidget {
  const _MissingInformation({required this.items});

  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Mình cần biết thêm',
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: AppColors.plum, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.xs),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.help_outline_rounded,
                    size: 17,
                    color: AppColors.rose,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(child: Text(item)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoutinePlan extends StatelessWidget {
  const _RoutinePlan({required this.steps});

  final List<AiRoutineStep> steps;

  String _timeLabel(String value) => switch (value) {
    'morning' => 'Buổi sáng',
    'evening' => 'Buổi tối',
    'weekly' => 'Hàng tuần',
    _ => 'Sáng và tối',
  };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.checklist_rounded,
                size: 19,
                color: AppColors.plum,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                'Routine đề xuất',
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ...steps.map(
            (step) => _RoutineStepRow(
              step: step,
              timeLabel: _timeLabel(step.timeOfDay),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoutineStepRow extends StatelessWidget {
  const _RoutineStepRow({required this.step, required this.timeLabel});

  final AiRoutineStep step;
  final String timeLabel;

  @override
  Widget build(BuildContext context) {
    final product = step.product;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: InkWell(
        onTap: product == null
            ? null
            : () => context.go('/product/${product.id}'),
        borderRadius: BorderRadius.circular(AppRadius.control),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: AppColors.paleRose,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${step.order}',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppColors.plum,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${step.label} · $timeLabel',
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    if (product != null)
                      Text(
                        product.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: AppColors.rose),
                      ),
                    Text(step.instruction),
                    if (step.reason.isNotEmpty)
                      Text(
                        step.reason,
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: AppColors.mutedInk),
                      ),
                  ],
                ),
              ),
              if (product != null) const Icon(Icons.chevron_right, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _CautionList extends StatelessWidget {
  const _CautionList({required this.items});

  final List<AiChatCaution> items;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Column(
        children: items.map((item) {
          final medical = item.severity == 'medical';
          return Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: AppSpacing.xs),
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: medical ? AppColors.paleRose : AppColors.paper,
              borderRadius: BorderRadius.circular(AppRadius.control),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  medical
                      ? Icons.health_and_safety_outlined
                      : Icons.info_outline_rounded,
                  size: 19,
                  color: medical ? AppColors.rose : AppColors.plum,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      Text(item.detail),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _RecommendedProductTile extends StatelessWidget {
  const _RecommendedProductTile({required this.item});

  final AiChatRecommendation item;

  @override
  Widget build(BuildContext context) {
    final product = item.product;
    return InkWell(
      onTap: () => context.go('/product/${product.id}'),
      borderRadius: BorderRadius.circular(AppRadius.control),
      child: Padding(
        padding: const EdgeInsets.only(top: AppSpacing.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.control),
              child: SizedBox.square(
                dimension: 56,
                child: product.image.isEmpty
                    ? const ColoredBox(
                        color: AppColors.paleRose,
                        child: Icon(Icons.spa_outlined),
                      )
                    : Image.network(
                        product.image,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const ColoredBox(
                          color: AppColors.paleRose,
                          child: Icon(Icons.spa_outlined),
                        ),
                      ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    formatMoney(product.price, product.currency),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.rose,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (item.explanation.isNotEmpty)
                    Text(
                      item.explanation,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: AppColors.mutedInk),
                    ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 20),
          ],
        ),
      ),
    );
  }
}
