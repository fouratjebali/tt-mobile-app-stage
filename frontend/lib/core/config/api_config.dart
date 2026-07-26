class ApiConfig {
  /// Override at build time with:
  /// flutter run --dart-define=API_BASE_URL=https://your-host/api/v1
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000/api/v1',
  );
}