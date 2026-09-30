import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/design_tokens.dart';
import '../../models/admin_models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/catalog_provider.dart';
import '../../services/backend_api.dart';
import '../../utils/money.dart';
import 'admin_components.dart';

class ProductFormPage extends StatefulWidget {
  const ProductFormPage({super.key, this.productId});
  final int? productId;

  @override
  State<ProductFormPage> createState() => _ProductFormPageState();
}

class _ProductFormPageState extends State<ProductFormPage> {
  final formKey = GlobalKey<FormState>();
  final controllers = <String, TextEditingController>{
    for (final key in [
      'name',
      'sku',
      'price',
      'stock',
      'description',
      'benefits',
      'image',
      'source',
      'inci',
      'keyIngredients',
      'skinTypes',
      'concerns',
      'goals',
      'texture',
      'usage',
      'warnings',
    ])
      key: TextEditingController(),
  };
  String? brand;
  String? category;
  String currency = 'USD';
  String status = 'DRAFT';
  bool aiReady = false;
  bool loading = false;
  bool loadingInitial = false;
  String? error;

  bool get editing => widget.productId != null;

  @override
  void initState() {
    super.initState();
    if (editing) {
      loadingInitial = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => load());
    }
  }

  @override
  void dispose() {
    for (final controller in controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> load() async {
    final token = context.read<AuthProvider>().accessToken;
    if (token == null) return;
    try {
      final product = await context.read<BackendApi>().getAdminProduct(
        accessToken: token,
        productId: widget.productId!,
      );
      controllers['name']!.text = product.name;
      controllers['sku']!.text = product.sku;
      controllers['price']!.text = product.price.toString();
      controllers['stock']!.text = (product.stock ?? 0).toString();
      controllers['description']!.text = product.description;
      controllers['benefits']!.text = product.benefits;
      controllers['image']!.text = product.image;
      controllers['source']!.text = product.sourceUrl;
      controllers['inci']!.text = product.inciIngredients;
      controllers['keyIngredients']!.text = product.keyIngredients;
      controllers['skinTypes']!.text = product.skinTypes.join(', ');
      controllers['concerns']!.text = product.skinConcerns.join(', ');
      controllers['goals']!.text = product.careGoals.join(', ');
      controllers['texture']!.text = product.texture;
      controllers['usage']!.text = product.usageInstruction;
      controllers['warnings']!.text = product.warnings;
      if (mounted) {
        setState(() {
          brand = product.brand;
          category = product.category;
          currency = product.currency;
          status = product.status;
          aiReady = product.aiReady;
        });
      }
    } catch (exception) {
      if (mounted) setState(() => error = BackendApi.readableError(exception));
    } finally {
      if (mounted) setState(() => loadingInitial = false);
    }
  }

  List<String> terms(String key) => controllers[key]!.text
      .split(',')
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList();

  Future<void> save() async {
    if (!formKey.currentState!.validate() ||
        brand == null ||
        category == null) {
      setState(() => error = 'Vui lòng hoàn thành các trường bắt buộc.');
      return;
    }
    final token = context.read<AuthProvider>().accessToken;
    if (token == null) return;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final saved = await context.read<BackendApi>().saveAdminProduct(
        accessToken: token,
        productId: widget.productId,
        data: {
          'name': controllers['name']!.text.trim(),
          'sku': controllers['sku']!.text.trim(),
          'brand': brand,
          'category': category,
          'price': double.parse(controllers['price']!.text),
          'stockQuantity': int.parse(controllers['stock']!.text),
          'currency': currency,
          'status': status,
          'aiReady': aiReady,
          'description': controllers['description']!.text.trim(),
          'benefits': controllers['benefits']!.text.trim(),
          'imageUrl': controllers['image']!.text.trim(),
          'sourceUrl': controllers['source']!.text.trim(),
          'inciIngredients': controllers['inci']!.text.trim(),
          'keyIngredients': controllers['keyIngredients']!.text.trim(),
          'skinTypes': terms('skinTypes'),
          'skinConcerns': terms('concerns'),
          'careGoals': terms('goals'),
          'texture': controllers['texture']!.text.trim(),
          'usageInstruction': controllers['usage']!.text.trim(),
          'warnings': controllers['warnings']!.text.trim(),
        },
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            editing
                ? 'Cập nhật sản phẩm thành công.'
                : 'Tạo sản phẩm thành công.',
          ),
        ),
      );
      context.go('/admin/products/${saved.id}');
    } catch (exception) {
      if (mounted) setState(() => error = BackendApi.readableError(exception));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final products = context.watch<CatalogProvider>().products;
    final brands =
        products
            .map((item) => item.brand)
            .where((item) => item.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    final categories =
        products
            .map((item) => item.category)
            .where((item) => item.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    if (brand != null && !brands.contains(brand)) brands.add(brand!);
    if (category != null && !categories.contains(category))
      categories.add(category!);
    if (loadingInitial) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: AdminLoading(rows: 8),
      );
    }
    return Form(
      key: formKey,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          AdminPageHeader(
            title: editing ? 'Chỉnh sửa sản phẩm' : 'Thêm sản phẩm',
            subtitle: 'Dữ liệu factual được lưu trực tiếp; AI-ready chỉ hợp lệ khi đủ trường recommendation.',
            actions: [
              OutlinedButton(
                onPressed: loading ? null : () => context.go('/admin/products'),
                child: const Text('Hủy'),
              ),
              FilledButton.icon(
                onPressed: loading ? null : save,
                icon: loading
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: const Text('Lưu sản phẩm'),
              ),
            ],
          ),
          if (error != null) ...[
            const SizedBox(height: AppSpacing.md),
            MaterialBanner(
              content: Text(error!),
              leading: const Icon(
                Icons.error_outline,
                color: AdminColors.danger,
              ),
              actions: [
                TextButton(
                  onPressed: () => setState(() => error = null),
                  child: const Text('Đóng'),
                ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          _FormSection(
            title: 'Thông tin cơ bản',
            children: [
              _field('name', 'Tên sản phẩm', required: true),
              _field('sku', 'SKU', required: true),
              _dropdown(
                'Brand',
                brand,
                brands,
                (value) => setState(() => brand = value),
              ),
              _dropdown(
                'Danh mục',
                category,
                categories,
                (value) => setState(() => category = value),
              ),
              _field('description', 'Mô tả đầy đủ', lines: 4),
              _field('benefits', 'Lợi ích ngắn', lines: 3),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _FormSection(
            title: 'Giá & kho',
            children: [
              _field(
                'price',
                'Giá',
                required: true,
                number: true,
                positive: true,
              ),
              _dropdown('Tiền tệ', currency, const [
                'USD',
                'VND',
              ], (value) => setState(() => currency = value!)),
              _field(
                'stock',
                'Tồn kho',
                required: true,
                number: true,
                integer: true,
              ),
              _dropdown('Trạng thái', status, const [
                'DRAFT',
                'ACTIVE',
                'INACTIVE',
                'ARCHIVED',
              ], (value) => setState(() => status = value!)),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _FormSection(
            title: 'Media',
            children: [
              _field('image', 'Ảnh chính (URL)'),
              _field('source', 'Nguồn dữ liệu (URL)'),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _FormSection(
            title: 'Thông tin làm đẹp',
            children: [
              _field('skinTypes', 'Loại da', helper: 'Phân cách bằng dấu phẩy'),
              _field(
                'concerns',
                'Vấn đề da',
                helper: 'Phân cách bằng dấu phẩy',
              ),
              _field(
                'goals',
                'Mục tiêu chăm sóc',
                helper: 'Phân cách bằng dấu phẩy',
              ),
              _field('keyIngredients', 'Thành phần nổi bật', lines: 2),
              _field('inci', 'INCI Ingredients', lines: 4),
              _field('texture', 'Kết cấu'),
              _field('usage', 'Hướng dẫn sử dụng', lines: 3),
              _field('warnings', 'Cảnh báo', lines: 3),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          AdminSectionCard(
            title: 'AI / Data status',
            child: SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('AI-ready'),
              subtitle: const Text(
                'Backend sẽ từ chối nếu thiếu mô tả, ảnh, loại da, concern hoặc care goal.',
              ),
              value: aiReady,
              onChanged: (value) => setState(() => aiReady = value),
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(
    String key,
    String label, {
    bool required = false,
    bool number = false,
    bool positive = false,
    bool integer = false,
    int lines = 1,
    String? helper,
  }) {
    return TextFormField(
      controller: controllers[key],
      maxLines: lines,
      keyboardType: number ? TextInputType.number : null,
      decoration: InputDecoration(labelText: label, helperText: helper),
      validator: (value) {
        if (required && (value == null || value.trim().isEmpty))
          return '$label là bắt buộc';
        if (number && value != null && value.isNotEmpty) {
          final parsed = integer ? int.tryParse(value) : double.tryParse(value);
          if (parsed == null || parsed < 0 || (positive && parsed <= 0))
            return '$label không hợp lệ';
        }
        return null;
      },
    );
  }

  Widget _dropdown(
    String label,
    String? value,
    List<String> values,
    ValueChanged<String?> onChanged,
  ) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(labelText: label),
      items: values
          .map((item) => DropdownMenuItem(value: item, child: Text(item)))
          .toList(),
      onChanged: onChanged,
      validator: (value) =>
          value == null || value.isEmpty ? '$label là bắt buộc' : null,
    );
  }
}

class _FormSection extends StatelessWidget {
  const _FormSection({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => AdminSectionCard(
    title: title,
    child: LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 780 ? 2 : 1;
        final width = columns == 2
            ? (constraints.maxWidth - AppSpacing.md) / 2
            : constraints.maxWidth;
        return Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: children
              .map((child) => SizedBox(width: width, child: child))
              .toList(),
        );
      },
    ),
  );
}

class ProductAdminDetailPage extends StatefulWidget {
  const ProductAdminDetailPage({super.key, required this.productId});
  final int productId;

  @override
  State<ProductAdminDetailPage> createState() => _ProductAdminDetailPageState();
}

class _ProductAdminDetailPageState extends State<ProductAdminDetailPage> {
  AdminProduct? product;
  String? error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => load());
  }

  Future<void> load() async {
    final token = context.read<AuthProvider>().accessToken;
    if (token == null) return;
    try {
      final value = await context.read<BackendApi>().getAdminProduct(
        accessToken: token,
        productId: widget.productId,
      );
      if (mounted) setState(() => product = value);
    } catch (exception) {
      if (mounted) setState(() => error = BackendApi.readableError(exception));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (error != null)
      return Center(
        child: AdminMessageState(
          icon: Icons.error_outline,
          title: 'Không thể tải sản phẩm',
          message: error!,
          actionLabel: 'Thử lại',
          onAction: load,
        ),
      );
    if (product == null)
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: AdminLoading(rows: 7),
      );
    final item = product!;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        AdminPageHeader(
          title: item.name,
          subtitle: '${item.sku} · ${item.brand} · ${item.category}',
          actions: [
            FilledButton.icon(
              onPressed: () => context.go('/admin/products/${item.id}/edit'),
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Chỉnh sửa'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        AdminSectionCard(
          child: Wrap(
            spacing: AppSpacing.xl,
            runSpacing: AppSpacing.lg,
            children: [
              _fact('Giá', formatMoney(item.price, item.currency)),
              _fact('Tồn kho', '${item.stock ?? 0}'),
              _fact('Trạng thái', item.status),
              _fact('AI-ready', item.aiReady ? 'Có' : 'Chưa'),
              _fact('Loại da', item.skinTypes.join(', ')),
              _fact('Concern', item.skinConcerns.join(', ')),
              _fact('Care goals', item.careGoals.join(', ')),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        if (item.description.isNotEmpty)
          AdminSectionCard(title: 'Mô tả', child: Text(item.description)),
        if (item.inciIngredients.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          AdminSectionCard(
            title: 'INCI Ingredients',
            child: Text(item.inciIngredients),
          ),
        ],
        if (item.usageInstruction.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          AdminSectionCard(
            title: 'Hướng dẫn sử dụng',
            child: Text(item.usageInstruction),
          ),
        ],
        if (item.warnings.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          AdminSectionCard(title: 'Cảnh báo', child: Text(item.warnings)),
        ],
      ],
    );
  }

  Widget _fact(String label, String value) => SizedBox(
    width: 220,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AdminColors.textSecondary)),
        const SizedBox(height: 4),
        Text(
          value.isEmpty ? '—' : value,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );
}
