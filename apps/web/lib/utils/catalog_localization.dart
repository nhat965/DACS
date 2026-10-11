/// Nhãn tiếng Việt cho các mã chuẩn nội bộ của catalog.
///
/// Mã tiếng Anh vẫn được giữ ở API để recommendation/filter không bị vỡ;
/// chỉ lớp hiển thị được bản địa hóa.
String catalogLabel(String value) {
  final key = value.trim().toLowerCase();
  const labels = <String, String>{
    'skincare': 'Chăm sóc da',
    'skin care': 'Chăm sóc da',
    'makeup': 'Trang điểm',
    'fragrance': 'Nước hoa',
    'bodycare': 'Chăm sóc cơ thể',
    'haircare': 'Chăm sóc tóc',
    'hair care': 'Chăm sóc tóc',
    'lip': 'Son môi',
    'gift': 'Quà tặng',
    'new arrivals': 'Hàng mới',
    'body care': 'Chăm sóc cơ thể',
    'body_care': 'Chăm sóc cơ thể',
    'cleanser': 'Sữa rửa mặt',
    'exfoliant': 'Tẩy tế bào chết',
    'eye care': 'Chăm sóc mắt',
    'eye_care': 'Chăm sóc mắt',
    'lip care': 'Chăm sóc môi',
    'lip_care': 'Chăm sóc môi',
    'makeup remover': 'Tẩy trang',
    'makeup_remover': 'Tẩy trang',
    'mask': 'Mặt nạ',
    'moisturizer': 'Kem dưỡng ẩm',
    'serum': 'Tinh chất',
    'sunscreen': 'Kem chống nắng',
    'toner': 'Nước cân bằng',
    'oily': 'Da dầu',
    'dry': 'Da khô',
    'combination': 'Da hỗn hợp',
    'normal': 'Da thường',
    'sensitive': 'Da nhạy cảm',
    'sensitivity': 'Nhạy cảm',
    'unknown': 'Chưa biết',
    'acne': 'Mụn',
    'oiliness': 'Dầu thừa',
    'dryness': 'Khô da',
    'redness': 'Đỏ và kích ứng',
    'dark spots': 'Thâm nám',
    'dark_spots': 'Thâm nám',
    'dark spot': 'Thâm sạm',
    'dark_spot': 'Thâm sạm',
    'large pores': 'Lỗ chân lông to',
    'large_pores': 'Lỗ chân lông to',
    'dullness': 'Da xỉn màu',
    'uneven texture': 'Bề mặt da không đều',
    'uneven_texture': 'Bề mặt da không đều',
    'aging': 'Lão hóa',
    'pores': 'Lỗ chân lông',
    'uneven tone': 'Không đều màu',
    'uneven_tone': 'Không đều màu',
    'hydrate': 'Cấp ẩm',
    'soothe': 'Làm dịu da',
    'repair': 'Phục hồi da',
    'brighten': 'Làm sáng da',
    'hydration': 'Cấp ẩm',
    'brightening': 'Làm sáng da',
    'oil control': 'Kiểm soát dầu',
    'oil_control': 'Kiểm soát dầu',
    'anti acne': 'Hỗ trợ giảm mụn',
    'anti_acne': 'Hỗ trợ giảm mụn',
    'anti aging': 'Chống lão hóa',
    'anti_aging': 'Chống lão hóa',
    'skin barrier': 'Phục hồi hàng rào da',
    'skin_barrier': 'Phục hồi hàng rào da',
    'sun protection': 'Bảo vệ da trước nắng',
    'sun_protection': 'Bảo vệ da trước nắng',
    'cleanse': 'Làm sạch da',
    'exfoliate': 'Tẩy tế bào chết',
    'balm': 'Sáp dưỡng',
    'cream': 'Kem',
    'gel': 'Gel',
    'lotion': 'Sữa dưỡng',
    'sheet mask': 'Mặt nạ giấy',
    'foam': 'Bọt',
    'liquid': 'Dạng lỏng',
    'essence': 'Tinh chất lỏng',
    'pads': 'Miếng pad',
    'patch': 'Miếng dán',
    'stick': 'Dạng thỏi',
    'mist': 'Xịt dưỡng',
    'gel-cream': 'Gel-cream',
    'powder': 'Phấn',
    'oil': 'Dầu dưỡng',
    'clay': 'Đất sét',
    'milk': 'Sữa',
    'fluid': 'Dạng fluid',
    'water': 'Dạng nước',
    'spray': 'Dạng xịt',
    'powdery': 'Dạng bột',
    'plumping': 'Làm đầy và căng mọng',
    'barrier care': 'Chăm sóc hàng rào da',
    'barrier_care': 'Chăm sóc hàng rào da',
  };
  return labels[key] ?? value;
}

String catalogCurrencyLabel(String currency) {
  switch (currency.trim().toUpperCase()) {
    case 'VND':
      return 'VNĐ';
    case 'USD':
      return 'Đô la Mỹ';
    default:
      return currency;
  }
}

String catalogStatusLabel(String value) => switch (value.trim().toUpperCase()) {
  'PENDING' => 'Chờ xác nhận',
  'CONFIRMED' => 'Đã xác nhận',
  'PROCESSING' => 'Đang xử lý',
  'SHIPPING' => 'Đang giao hàng',
  'COMPLETED' => 'Hoàn tất',
  'CANCELED' || 'CANCELLED' => 'Đã hủy',
  _ => value,
};

String localizeRecommendationReason(String reason) {
  var localized = reason;
  const terms = <String, String>{
    'lip_care': 'Chăm sóc môi',
    'body_care': 'Chăm sóc cơ thể',
    'eye_care': 'Chăm sóc mắt',
    'makeup_remover': 'Tẩy trang',
    'soothe': 'Làm dịu da',
    'repair': 'Phục hồi da',
    'hydrate': 'Cấp ẩm',
    'brighten': 'Làm sáng da',
    'oil_control': 'Kiểm soát dầu',
    'anti_acne': 'Hỗ trợ giảm mụn',
    'anti_aging': 'Chống lão hóa',
    'sun_protection': 'Bảo vệ da trước nắng',
    'dry': 'Da khô',
    'oily': 'Da dầu',
    'combination': 'Da hỗn hợp',
    'normal': 'Da thường',
    'sensitive': 'Da nhạy cảm',
  };
  for (final entry in terms.entries) {
    localized = localized.replaceAll(entry.key, entry.value);
  }
  localized = localized.replaceAllMapped(
    RegExp(r'Phù hợp với loại da ([^\.]+)', caseSensitive: false),
    (match) => 'Phù hợp với ${catalogLabel(match.group(1)!.trim())}',
  );
  localized = localized.replaceAllMapped(
    RegExp(r'Hỗ trợ vấn đề da: ([^\.]+)', caseSensitive: false),
    (match) =>
        'Hỗ trợ vấn đề: ${match.group(1)!.split(',').map((value) => catalogLabel(value.trim())).join(', ')}',
  );
  localized = localized.replaceAllMapped(
    RegExp(r'Khớp mục tiêu chăm sóc: ([^\.]+)', caseSensitive: false),
    (match) =>
        'Khớp mục tiêu: ${match.group(1)!.split(',').map((value) => catalogLabel(value.trim())).join(', ')}',
  );
  return localized.replaceAll('_', ' ');
}

String shortBenefit(String value, {int maxLength = 115}) {
  final cleaned = cleanCatalogText(value)
      .replaceAll(RegExp(r'(^|\s)#[A-Za-z0-9_]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (cleaned.isEmpty) return '';
  final firstSentence = cleaned.split(RegExp(r'(?<=[.!?])\s+')).first.trim();
  final selected = firstSentence.isEmpty ? cleaned : firstSentence;
  if (selected.length <= maxLength) return selected;
  return '${selected.substring(0, maxLength - 1).trimRight()}…';
}

String cleanCatalogText(String value) {
  return value
      .replaceFirst(RegExp(r'^[A-Za-z0-9+_-]{4,}\s+(?=#)'), '')
      .replaceAll(RegExp(r'(^|\s)#[A-Za-z0-9_]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}
