import 'package:flutter_test/flutter_test.dart';
import 'package:lumi_beauty/models/ai_chat.dart';

void main() {
  test('parses structured Lumi AI routine and cautions', () {
    final response = AiChatResponse.fromJson({
      'response': 'Routine tối giản cho da khô.',
      'recommendations': <dynamic>[],
      'followUpQuestions': ['Da bạn có dễ kích ứng không?'],
      'consultationType': 'routine',
      'routine': [
        {
          'order': 1,
          'timeOfDay': 'both',
          'label': 'Cấp ẩm',
          'productId': 216,
          'product': {
            'productId': 216,
            'sku': 'TEST-216',
            'name': 'Toner cấp ẩm',
            'brand': 'Lumi',
            'category': 'toner',
            'price': 300000,
            'currency': 'VND',
            'skinTypes': ['dry'],
            'skinConcerns': ['dryness'],
            'careGoals': ['hydrate'],
          },
          'instruction': 'Vỗ nhẹ trên da.',
          'reason': 'Hỗ trợ cấp ẩm.',
        },
      ],
      'cautions': [
        {
          'severity': 'info',
          'title': 'Kiểm tra kích ứng',
          'detail': 'Thử trên một vùng da nhỏ trước.',
        },
      ],
      'missingInformation': ['Mức độ nhạy cảm'],
    });

    expect(response.consultationType, 'routine');
    expect(response.routine, hasLength(1));
    expect(response.routine.single.product?.id, 216);
    expect(response.cautions.single.title, 'Kiểm tra kích ứng');
    expect(response.missingInformation, ['Mức độ nhạy cảm']);
  });
}
