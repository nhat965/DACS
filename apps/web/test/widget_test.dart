import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumi_beauty/app/app.dart';
import 'package:provider/provider.dart';
import 'package:lumi_beauty/models/product.dart';
import 'package:lumi_beauty/providers/auth_provider.dart';
import 'package:lumi_beauty/screens/admin/admin_layout.dart';
import 'package:lumi_beauty/services/backend_api.dart';

class _FakeBackendApi extends BackendApi {
  @override
  Future<List<Product>> getProducts({
    String? search,
    String? category,
    String? brand,
    String? concern,
    String? goal,
    int limit = 100,
    int offset = 0,
  }) async {
    return const [];
  }
}

void main() {
  testWidgets('Lumi Beauty app test', (WidgetTester tester) async {
    await tester.pumpWidget(LumiBeautyApp(backendApi: _FakeBackendApi()));
    await tester.pumpAndSettle();

    expect(find.text('LUMI BEAUTY'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Admin layout renders without missing Material ancestor', (
    WidgetTester tester,
  ) async {
    final auth = AuthProvider(BackendApi());

    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider<AuthProvider>.value(
          value: auth,
          child: const AdminLayout(
            currentPath: '/admin/dashboard',
            child: SizedBox.shrink(),
            title: 'Dashboard',
          ),
        ),
      ),
    );

    expect(find.text('Dashboard'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
