import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../widgets/app_footer.dart';
import '../../widgets/app_header.dart';

class CatalogStatusPage extends StatelessWidget {
  const CatalogStatusPage({
    super.key,
    required this.title,
    required this.message,
    required this.icon,
    this.actionLabel = 'Khám phá danh mục',
    this.actionRoute = '/categories',
  });

  final String title;
  final String message;
  final IconData icon;
  final String actionLabel;
  final String actionRoute;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const AppHeader(),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 620),
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        icon,
                        size: 58,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        message,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 28),
                      FilledButton.icon(
                        onPressed: () => context.go(actionRoute),
                        icon: const Icon(Icons.arrow_forward),
                        label: Text(actionLabel),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const AppFooter(),
        ],
      ),
    );
  }
}
