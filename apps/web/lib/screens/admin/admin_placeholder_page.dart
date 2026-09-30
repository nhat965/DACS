import 'package:flutter/material.dart';

import '../../app/design_tokens.dart';
import 'admin_components.dart';

class AdminPlaceholderPage extends StatelessWidget {
  const AdminPlaceholderPage({
    super.key,
    required this.title,
    required this.message,
    required this.icon,
  });

  final String title;
  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(AppSpacing.lg),
    children: [
      AdminPageHeader(title: title, subtitle: message),
      const SizedBox(height: AppSpacing.lg),
      AdminSectionCard(
        child: AdminMessageState(
          icon: icon,
          title: 'Chưa đủ dữ liệu để hiển thị',
          message: 'Màn hình được giữ rõ trạng thái thay vì tạo số liệu hoặc biểu đồ giả.',
        ),
      ),
    ],
  );
}
