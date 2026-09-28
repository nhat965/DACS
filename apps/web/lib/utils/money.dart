String formatMoney(double amount, String currency) {
  final normalizedCurrency = currency.isEmpty ? '—' : currency.toUpperCase();
  final raw = amount.toStringAsFixed(normalizedCurrency == 'VND' ? 0 : 2);
  final parts = raw.split('.');
  final grouped = parts.first.replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => '.',
  );
  final number = parts.length == 2 ? '$grouped,${parts[1]}' : grouped;
  return normalizedCurrency == 'VND'
      ? '$number\u0111'
      : '$number $normalizedCurrency';
}
