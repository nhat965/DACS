import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

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
              TextFormField(
                controller: _nameController,
                autofillHints: const [AutofillHints.name],
                decoration: const InputDecoration(labelText: 'Họ và tên'),
                validator: (value) => value == null || value.trim().length < 2
                    ? 'Họ tên cần ít nhất 2 ký tự.'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                decoration: const InputDecoration(labelText: 'Email'),
                validator: (value) => value != null && value.contains('@')
                    ? null
                    : 'Nhập địa chỉ email hợp lệ.',
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                autofillHints: const [AutofillHints.newPassword],
                decoration: const InputDecoration(
                  labelText: 'Mật khẩu',
                  helperText: 'Tối thiểu 8 ký tự.',
                ),
                validator: (value) => value == null || value.length < 8
                    ? 'Mật khẩu cần ít nhất 8 ký tự.'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _confirmPasswordController,
                obscureText: true,
                autofillHints: const [AutofillHints.newPassword],
                decoration: const InputDecoration(
                  labelText: 'Xác nhận mật khẩu',
                ),
                validator: (value) => value == _passwordController.text
                    ? null
                    : 'Mật khẩu xác nhận chưa khớp.',
              ),
              if (auth.errorMessage != null) ...[
                const SizedBox(height: 16),
                Text(
                  auth.errorMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: auth.isLoading ? null : _submit,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  child: auth.isLoading
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Đăng ký và đăng nhập'),
                ),
              ),
              TextButton(
                onPressed: auth.isLoading ? null : () => context.go('/login'),
                child: const Text('Đã có tài khoản? Đăng nhập'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
