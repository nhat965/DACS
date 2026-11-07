class AppConfig {
  const AppConfig._();

  /// Override at runtime with:
  /// flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8001
  /// Vercel Production configures API_BASE_URL to the deployed Lumi API.
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );
}
