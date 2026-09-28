import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/design_tokens.dart';
import '../../models/beauty_preferences.dart';
import '../../providers/preferences_provider.dart';
import '../../providers/recommendation_provider.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final controller = PageController();
  int step = 0;
  final categories = <String>{};
  String? skinType;
  final concerns = <String>{};
  final goals = <String>{};
  double? budgetMin;
  double? budgetMax;

  static const categoryOptions =
      <({String label, List<String> values, IconData icon})>[
        (
          label: 'Skincare',
          values: [
            'cleanser',
            'toner',
            'serum',
            'moisturizer',
            'sunscreen',
            'exfoliant',
            'mask',
            'eye_care',
          ],
          icon: Icons.spa_outlined,
        ),
        (label: 'Makeup', values: ['makeup'], icon: Icons.brush_outlined),
        (label: 'Son môi', values: ['lip_care'], icon: Icons.colorize_outlined),
        (
          label: 'Nước hoa',
          values: ['fragrance'],
          icon: Icons.water_drop_outlined,
        ),
        (
          label: 'Body care',
          values: ['body_care'],
          icon: Icons.self_improvement_outlined,
        ),
      ];

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void next() {
    if (step == 4) {
      save();
      return;
    }
    controller.nextPage(
      duration: AppDurations.component,
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> save() async {
    final value = BeautyPreferences(
      skinType: skinType,
      skinConcerns: concerns.toList(),
      careGoals: goals.toList(),
      preferredCategories: categories.toList(),
      budgetMin: budgetMin,
      budgetMax: budgetMax,
      currency: 'USD',
      completed: true,
    );
    final success = await context.read<PreferencesProvider>().save(value);
    if (!mounted || !success) return;
    await context.read<RecommendationProvider>().loadPersonalized(
      context: value.toRecommendationContext(),
    );
    if (mounted) context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<PreferencesProvider>();
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 920),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                children: [
                  Row(
                    children: [
                      Text(
                        'LUMI BEAUTY',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () => context.go('/'),
                        child: const Text('Bỏ qua'),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    child: LinearProgressIndicator(
                      value: (step + 1) / 5,
                      minHeight: 8,
                      backgroundColor: AppColors.paleRose,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text('${step + 1}/5'),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Expanded(
                    child: PageView(
                      controller: controller,
                      physics: const NeverScrollableScrollPhysics(),
                      onPageChanged: (value) => setState(() => step = value),
                      children: [
                        _SelectionStep(
                          title: 'Bạn quan tâm sản phẩm gì?',
                          subtitle: 'Chọn một hoặc nhiều nhóm.',
                          children: categoryOptions.map((option) {
                            final selected = option.values.any(
                              categories.contains,
                            );
                            return _ChoiceCard(
                              label: option.label,
                              icon: option.icon,
                              selected: selected,
                              onTap: () => setState(() {
                                if (selected) {
                                  categories.removeAll(option.values);
                                } else {
                                  categories.addAll(option.values);
                                }
                              }),
                            );
                          }).toList(),
                        ),
                        _SelectionStep(
                          title: 'Loại da của bạn?',
                          subtitle: 'Nếu chưa chắc, bạn có thể chọn Chưa biết.',
                          children:
                              const {
                                    'oily': 'Da dầu',
                                    'dry': 'Da khô',
                                    'combination': 'Da hỗn hợp',
                                    'normal': 'Da thường',
                                    'sensitive': 'Da nhạy cảm',
                                    'unknown': 'Chưa biết',
                                  }.entries
                                  .map(
                                    (option) => _ChoiceCard(
                                      label: option.value,
                                      selected: skinType == option.key,
                                      onTap: () =>
                                          setState(() => skinType = option.key),
                                    ),
                                  )
                                  .toList(),
                        ),
                        _SelectionStep(
                          title: 'Vấn đề bạn quan tâm?',
                          subtitle:
                              'Chọn tất cả những điều đang ảnh hưởng đến da.',
                          children:
                              const {
                                    'acne': 'Mụn',
                                    'oiliness': 'Dầu thừa',
                                    'dryness': 'Khô da',
                                    'sensitivity': 'Nhạy cảm',
                                    'redness': 'Ủng đỏ',
                                    'dark_spot': 'Thâm sạm',
                                    'aging': 'Lão hóa',
                                    'large_pores': 'Lỗ chân lông',
                                    'dullness': 'Da xỉn màu',
                                  }.entries
                                  .map(
                                    (option) => _ChoiceCard(
                                      label: option.value,
                                      selected: concerns.contains(option.key),
                                      onTap: () => setState(
                                        () => concerns.contains(option.key)
                                            ? concerns.remove(option.key)
                                            : concerns.add(option.key),
                                      ),
                                    ),
                                  )
                                  .toList(),
                        ),
                        _SelectionStep(
                          title: 'Mục tiêu chăm sóc?',
                          subtitle:
                              'Lumi dùng các mục tiêu này để xếp hạng gợi ý.',
                          children:
                              const {
                                    'hydrate': 'Cấp ẩm',
                                    'brighten': 'Làm sáng',
                                    'oil_control': 'Kiểm soát dầu',
                                    'anti_acne': 'Hỗ trợ mụn',
                                    'anti_aging': 'Chống lão hóa',
                                    'repair': 'Phục hồi hàng rào',
                                    'sun_protection': 'Chống nắng',
                                  }.entries
                                  .map(
                                    (option) => _ChoiceCard(
                                      label: option.value,
                                      selected: goals.contains(option.key),
                                      onTap: () => setState(
                                        () => goals.contains(option.key)
                                            ? goals.remove(option.key)
                                            : goals.add(option.key),
                                      ),
                                    ),
                                  )
                                  .toList(),
                        ),
                        _SelectionStep(
                          title: 'Ngân sách cho mỗi sản phẩm?',
                          subtitle: 'Catalog hiện tại dùng USD; bộ lọc sẽ giữ đúng currency.',
                          children: [
                            _BudgetChoice(
                              label: 'Dưới 25 USD',
                              min: null,
                              max: 25,
                              selectedMin: budgetMin,
                              selectedMax: budgetMax,
                              onTap: selectBudget,
                            ),
                            _BudgetChoice(
                              label: '25–50 USD',
                              min: 25,
                              max: 50,
                              selectedMin: budgetMin,
                              selectedMax: budgetMax,
                              onTap: selectBudget,
                            ),
                            _BudgetChoice(
                              label: '50–100 USD',
                              min: 50,
                              max: 100,
                              selectedMin: budgetMin,
                              selectedMax: budgetMax,
                              onTap: selectBudget,
                            ),
                            _BudgetChoice(
                              label: 'Không giới hạn',
                              min: null,
                              max: null,
                              selectedMin: budgetMin,
                              selectedMax: budgetMax,
                              onTap: selectBudget,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (state.errorMessage != null) ...[
                    Text(
                      state.errorMessage!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                  Row(
                    children: [
                      if (step > 0)
                        OutlinedButton(
                          onPressed: state.isLoading
                              ? null
                              : () => controller.previousPage(
                                  duration: AppDurations.component,
                                  curve: Curves.easeOutCubic,
                                ),
                          child: const Text('Quay lại'),
                        ),
                      const Spacer(),
                      FilledButton.icon(
                        onPressed: state.isLoading ? null : next,
                        iconAlignment: IconAlignment.end,
                        icon: state.isLoading
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Icon(
                                step == 4 ? Icons.check : Icons.arrow_forward,
                              ),
                        label: Text(step == 4 ? 'Lưu hồ sơ' : 'Tiếp tục'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void selectBudget(double? min, double? max) {
    setState(() {
      budgetMin = min;
      budgetMax = max;
    });
  }
}

class _SelectionStep extends StatelessWidget {
  const _SelectionStep({
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.displaySmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: AppSpacing.xl),
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.md,
            alignment: WrapAlignment.center,
            children: children,
          ),
        ],
      ),
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: AnimatedContainer(
          duration: AppDurations.feedback,
          width: 178,
          height: 112,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: selected ? AppColors.paleRose : AppColors.paper,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(
              color: selected ? AppColors.rose : AppColors.line,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null)
                Icon(icon, color: selected ? AppColors.rose : AppColors.ink),
              if (icon != null) const SizedBox(height: AppSpacing.xs),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(child: Text(label, textAlign: TextAlign.center)),
                  if (selected) ...[
                    const SizedBox(width: AppSpacing.xs),
                    const Icon(
                      Icons.check_circle,
                      size: 18,
                      color: AppColors.rose,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BudgetChoice extends StatelessWidget {
  const _BudgetChoice({
    required this.label,
    required this.min,
    required this.max,
    required this.selectedMin,
    required this.selectedMax,
    required this.onTap,
  });

  final String label;
  final double? min;
  final double? max;
  final double? selectedMin;
  final double? selectedMax;
  final void Function(double?, double?) onTap;

  @override
  Widget build(BuildContext context) {
    return _ChoiceCard(
      label: label,
      selected: min == selectedMin && max == selectedMax,
      onTap: () => onTap(min, max),
    );
  }
}
