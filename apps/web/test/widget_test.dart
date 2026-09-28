import 'package:flutter_test/flutter_test.dart';
import 'package:lumi_beauty/app/app.dart';
import 'package:lumi_beauty/models/product.dart';
import 'package:lumi_beauty/services/backend_api.dart';

class _FakeBackendApi extends BackendApi {
  @override
  Future<List<Product>> getProducts({
    String? search,
    String? category,
    String? brand,
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
  });
}
