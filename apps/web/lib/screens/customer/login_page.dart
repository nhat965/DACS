import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

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
  bool _obscurePassword = true;

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
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                validator: (value) => value != null && value.contains('@')
                    ? null
                    : 'Nhập địa chỉ email hợp lệ.',
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                autofillHints: const [AutofillHints.password],
                decoration: InputDecoration(
                  labelText: 'Mật khẩu',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    tooltip: _obscurePassword ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
                onFieldSubmitted: (_) => _submit(),
                validator: (value) =>
                    value == null || value.isEmpty ? 'Nhập mật khẩu.' : null,
              ),
              if (auth.errorMessage != null) ...[
                const SizedBox(height: 16),
                Text(
                  auth.errorMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: auth.isLoading
                      ? null
                      : () => context.go('/forgot-password'),
                  child: const Text('Quên mật khẩu?'),
                ),
              ),
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
                      : const Text('Đăng nhập'),
                ),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: auth.isLoading
                    ? null
                    : () => context.go('/register'),
                child: const Text('Chưa có tài khoản? Đăng ký'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
