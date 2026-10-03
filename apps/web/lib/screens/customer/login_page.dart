import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/design_tokens.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/auth_shell.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, this.redirectPath});

  final String? redirectPath;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final success = await auth.login(
      email: _emailController.text,
      password: _passwordController.text,
    );
    if (!mounted || !success) return;
    final target = widget.redirectPath;
    context.go(
      target != null && target.startsWith('/')
          ? target
          : auth.isAdmin
          ? '/admin'
          : '/',
    );
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
        title: 'Chào mừng bạn trở lại',
        subtitle: 'Đăng nhập để tiếp tục hành trình làm đẹp cùng Lumi.',
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AuthTextField(
                controller: _emailController,
                label: 'Email',
                prefixIcon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                onChanged: _clearError,
                validator: (value) => value != null && value.contains('@')
                    ? null
                    : 'Nhập địa chỉ email hợp lệ.',
              ),
              const SizedBox(height: AppSpacing.md),
              AuthPasswordField(
                controller: _passwordController,
                onChanged: _clearError,
                onFieldSubmitted: (_) => _submit(),
                validator: (value) =>
                    value == null || value.isEmpty ? 'Nhập mật khẩu.' : null,
              ),
              AuthMessageBanner(message: auth.errorMessage, isError: true),
              AuthTextLink(
                label: 'Quên mật khẩu?',
                enabled: !auth.isLoading,
                alignment: MainAxisAlignment.end,
                onPressed: () => context.go('/forgot-password'),
              ),
              const SizedBox(height: AppSpacing.sm),
              AuthPrimaryButton(
                label: 'Đăng nhập',
                loading: auth.isLoading,
                onPressed: auth.isLoading ? null : _submit,
              ),
              const SizedBox(height: AppSpacing.sm),
              AuthTextLink(
                leadingText: 'Chưa có tài khoản?',
                label: 'Đăng ký ngay',
                enabled: !auth.isLoading,
                onPressed: () => context.go('/register'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
