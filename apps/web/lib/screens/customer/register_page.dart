import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/design_tokens.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/auth_shell.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final success = await context.read<AuthProvider>().register(
      fullName: _nameController.text,
      email: _emailController.text,
      password: _passwordController.text,
    );
    if (mounted && success) context.go('/onboarding');
  }

  void _clearError(String _) {
    final auth = context.read<AuthProvider>();
    if (auth.errorMessage != null) auth.clearError();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      body: AuthShell(
        title: 'Tạo tài khoản Lumi',
        subtitle: 'Bắt đầu với hồ sơ làm đẹp dành riêng cho bạn.',
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AuthTextField(
                controller: _nameController,
                label: 'Họ và tên',
                prefixIcon: Icons.person_outline_rounded,
                autofillHints: const [AutofillHints.name],
                textInputAction: TextInputAction.next,
                onChanged: _clearError,
                validator: (value) => value == null || value.trim().length < 2
                    ? 'Họ tên cần ít nhất 2 ký tự.'
                    : null,
              ),
              const SizedBox(height: AppSpacing.md),
              AuthTextField(
                controller: _emailController,
                label: 'Email',
                prefixIcon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                textInputAction: TextInputAction.next,
                onChanged: _clearError,
                validator: (value) => value != null && value.contains('@')
                    ? null
                    : 'Nhập địa chỉ email hợp lệ.',
              ),
              const SizedBox(height: AppSpacing.md),
              AuthPasswordField(
                controller: _passwordController,
                newPassword: true,
                helperText: 'Tối thiểu 8 ký tự.',
                onChanged: _clearError,
                validator: (value) => value == null || value.length < 8
                    ? 'Mật khẩu cần ít nhất 8 ký tự.'
                    : null,
              ),
              const SizedBox(height: AppSpacing.md),
              AuthPasswordField(
                controller: _confirmPasswordController,
                label: 'Xác nhận mật khẩu',
                newPassword: true,
                onChanged: _clearError,
                onFieldSubmitted: (_) => _submit(),
                validator: (value) => value == _passwordController.text
                    ? null
                    : 'Mật khẩu xác nhận chưa khớp.',
              ),
              AuthMessageBanner(message: auth.errorMessage, isError: true),
              const SizedBox(height: AppSpacing.lg),
              AuthPrimaryButton(
                label: 'Đăng ký và đăng nhập',
                loading: auth.isLoading,
                onPressed: auth.isLoading ? null : _submit,
              ),
              const SizedBox(height: AppSpacing.sm),
              AuthTextLink(
                leadingText: 'Đã có tài khoản?',
                label: 'Đăng nhập',
                enabled: !auth.isLoading,
                onPressed: () => context.go('/login'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
