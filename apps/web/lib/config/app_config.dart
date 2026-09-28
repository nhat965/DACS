class AppConfig {
  const AppConfig._();

  /// Override at runtime with:
  /// flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8001
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8001',
  );
}
