import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../services/backend_api.dart';
import '../../widgets/auth_shell.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final formKey = GlobalKey<FormState>();
  final emailController = TextEditingController();
  bool loading = false;
  String? message;

  @override
  void dispose() {
    emailController.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (!formKey.currentState!.validate()) return;
    setState(() {
      loading = true;
      message = null;
    });
    final result = await context.read<BackendApi>().requestPasswordReset(
      emailController.text.trim(),
    );
    if (!mounted) return;
    setState(() {
      loading = false;
      message = switch (result) {
        PasswordResetRequestResult.notAvailable =>
          'Tính năng đặt lại mật khẩu đang được chuẩn bị.',
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AuthShell(
        title: 'Quên mật khẩu?',
        subtitle: 'Nhập email đã đăng ký để bắt đầu yêu cầu đặt lại mật khẩu.',
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: emailController,
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
              if (message != null) ...[
                const SizedBox(height: 16),
                Text(message!, textAlign: TextAlign.center),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: loading ? null : submit,
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 13),
                  child: Text('Gửi yêu cầu đặt lại mật khẩu'),
                ),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () => context.go('/login'),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Quay lại đăng nhập'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
