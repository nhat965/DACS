import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../app/design_tokens.dart';
import '../models/product_review.dart';
import '../providers/auth_provider.dart';
import '../services/backend_api.dart';

class ProductReviewsSection extends StatefulWidget {
  const ProductReviewsSection({super.key, required this.productId});

  final int productId;

  @override
  State<ProductReviewsSection> createState() => _ProductReviewsSectionState();
}

class _ProductReviewsSectionState extends State<ProductReviewsSection> {
  final commentController = TextEditingController();
  ProductReviewPage? page;
  String? loadedToken;
  String? errorMessage;
  int selectedRating = 0;
  bool loading = true;
  bool submitting = false;

  @override
  void dispose() {
    commentController.dispose();
    super.dispose();
  }

  Future<void> load({bool force = false}) async {
    final token = context.read<AuthProvider>().accessToken;
    if (!force && token == loadedToken && page != null) return;
    setState(() {
      loading = true;
      errorMessage = null;
    });
    try {
      final result = await context.read<BackendApi>().getProductReviews(
        productId: widget.productId,
        accessToken: token,
      );
      if (!mounted) return;
      final mine = result.items.where((item) => item.isMine).firstOrNull;
      setState(() {
        page = result;
        loadedToken = token;
        if (mine != null) {
          selectedRating = mine.rating;
          commentController.text = mine.comment;
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => errorMessage = BackendApi.readableError(error));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> submit() async {
    final auth = context.read<AuthProvider>();
    final comment = commentController.text.trim();
    if (selectedRating == 0 || comment.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Hãy chọn số sao và nhập nhận xét từ 3 ký tự.'),
        ),
      );
      return;
    }
    setState(() => submitting = true);
    try {
      await context.read<BackendApi>().saveProductReview(
        productId: widget.productId,
        accessToken: auth.accessToken!,
        rating: selectedRating,
        comment: comment,
      );
      if (!mounted) return;
      await load(force: true);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đánh giá của bạn đã được lưu.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(BackendApi.readableError(error))));
    } finally {
      if (mounted) setState(() => submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final token = context.watch<AuthProvider>().accessToken;
    if (token != loadedToken && !loading) {
      WidgetsBinding.instance.addPostFrameCallback((_) => load());
    } else if (page == null && loading) {
      WidgetsBinding.instance.addPostFrameCallback((_) => load(force: true));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Đánh giá từ khách hàng',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: AppSpacing.xs),
        const Text(
          'Chia sẻ trải nghiệm thực tế để cộng đồng Lumi lựa chọn dễ dàng hơn.',
          style: TextStyle(color: AppColors.mutedInk),
        ),
        const SizedBox(height: AppSpacing.lg),
        if (loading && page == null)
          const _ReviewSkeleton()
        else if (errorMessage != null && page == null)
          _ReviewError(message: errorMessage!, onRetry: () => load(force: true))
        else ...[
          LayoutBuilder(
            builder: (context, constraints) {
              final summary = _ReviewSummary(page: page!);
              final form = _ReviewForm(
                selectedRating: selectedRating,
                controller: commentController,
                submitting: submitting,
                isAuthenticated: token != null,
                isEditing: page!.items.any((item) => item.isMine),
                onRatingChanged: (value) =>
                    setState(() => selectedRating = value),
                onSubmit: submit,
                onLogin: () => context.go(
                  '/login?redirect=${Uri.encodeComponent('/product/${widget.productId}')}',
                ),
              );
              if (constraints.maxWidth < 780) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    summary,
                    const SizedBox(height: AppSpacing.md),
                    form,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 250, child: summary),
                  const SizedBox(width: AppSpacing.xl),
                  Expanded(child: form),
                ],
              );
            },
          ),
          const SizedBox(height: AppSpacing.xl),
          if (page!.items.isEmpty)
            const _EmptyReviews()
          else
            ...page!.items.map((review) => _ReviewTile(review: review)),
        ],
      ],
    );
  }
}

class _ReviewSummary extends StatelessWidget {
  const _ReviewSummary({required this.page});

  final ProductReviewPage page;

  @override
  Widget build(BuildContext context) {
    final average = page.averageRating;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.softPink,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              average == null ? 'Chưa có điểm' : average.toStringAsFixed(1),
              style: Theme.of(context).textTheme.displaySmall
                  ?.copyWith(color: AppColors.plum),
            ),
            const SizedBox(height: AppSpacing.xs),
            _StaticStars(value: average ?? 0),
            const SizedBox(height: AppSpacing.xs),
            Text(
              page.total == 0 ? 'Chưa có đánh giá' : '${page.total} đánh giá',
              style: const TextStyle(color: AppColors.mutedInk),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReviewForm extends StatelessWidget {
  const _ReviewForm({
    required this.selectedRating,
    required this.controller,
    required this.submitting,
    required this.isAuthenticated,
    required this.isEditing,
    required this.onRatingChanged,
    required this.onSubmit,
    required this.onLogin,
  });

  final int selectedRating;
  final TextEditingController controller;
  final bool submitting;
  final bool isAuthenticated;
  final bool isEditing;
  final ValueChanged<int> onRatingChanged;
  final VoidCallback onSubmit;
  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: AppShadows.soft,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: isAuthenticated
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isEditing
                        ? 'Cập nhật đánh giá của bạn'
                        : 'Bạn thấy sản phẩm thế nào?',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _RatingInput(
                    value: selectedRating,
                    onChanged: onRatingChanged,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: controller,
                    minLines: 3,
                    maxLines: 6,
                    maxLength: 2000,
                    decoration: const InputDecoration(
                      labelText: 'Nhận xét của bạn',
                      hintText: 'Sản phẩm phù hợp với bạn ở điểm nào?',
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  FilledButton.icon(
                    onPressed: submitting ? null : onSubmit,
                    icon: submitting
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.rate_review_outlined),
                    label: Text(isEditing ? 'Lưu thay đổi' : 'Gửi đánh giá'),
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Đăng nhập để viết đánh giá',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  const Text(
                    'Bạn vẫn có thể đọc toàn bộ nhận xét của khách hàng bên dưới.',
                    style: TextStyle(color: AppColors.mutedInk),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  OutlinedButton.icon(
                    onPressed: onLogin,
                    icon: const Icon(Icons.login),
                    label: const Text('Đăng nhập để đánh giá'),
                  ),
                ],
              ),
      ),
    );
  }
}

class _RatingInput extends StatelessWidget {
  const _RatingInput({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: value == 0 ? 'Chưa chọn số sao' : 'Đã chọn $value trên 5 sao',
      child: Wrap(
        spacing: AppSpacing.xxs,
        children: List.generate(5, (index) {
          final rating = index + 1;
          return IconButton(
            tooltip: '$rating sao',
            onPressed: () => onChanged(rating),
            color: rating <= value ? AppColors.warning : AppColors.line,
            iconSize: 32,
            icon: Icon(rating <= value ? Icons.star : Icons.star_border),
          );
        }),
      ),
    );
  }
}

class _StaticStars extends StatelessWidget {
  const _StaticStars({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final filled = value >= index + 0.75;
        final half = !filled && value >= index + 0.25;
        return Icon(
          filled
              ? Icons.star
              : half
              ? Icons.star_half
              : Icons.star_border,
          size: 20,
          color: AppColors.warning,
        );
      }),
    );
  }
}

class _ReviewTile extends StatelessWidget {
  const _ReviewTile({required this.review});

  final ProductReview review;

  @override
  Widget build(BuildContext context) {
    final date = review.updatedAt.toLocal();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: AppColors.softViolet,
            foregroundColor: AppColors.plum,
            child: Text(
              review.authorName.trim().isEmpty
                  ? 'L'
                  : review.authorName.trim()[0].toUpperCase(),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: AppSpacing.xs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      review.authorName,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    if (review.isMine)
                      const Chip(
                        label: Text('Đánh giá của bạn'),
                        visualDensity: VisualDensity.compact,
                      ),
                    Text(
                      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}',
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: AppColors.mutedInk),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xxs),
                _StaticStars(value: review.rating.toDouble()),
                const SizedBox(height: AppSpacing.xs),
                Text(review.comment, style: const TextStyle(height: 1.55)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyReviews extends StatelessWidget {
  const _EmptyReviews();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
      child: Center(
        child: Text(
          'Chưa có bình luận nào. Hãy là người đầu tiên chia sẻ trải nghiệm.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.mutedInk),
        ),
      ),
    );
  }
}

class _ReviewSkeleton extends StatelessWidget {
  const _ReviewSkeleton();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 140,
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class _ReviewError extends StatelessWidget {
  const _ReviewError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.error_outline, color: AppColors.error),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: Text(message)),
        TextButton(onPressed: onRetry, child: const Text('Thử lại')),
      ],
    );
  }
}
