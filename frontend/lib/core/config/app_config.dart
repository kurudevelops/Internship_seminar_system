class AppConfig {
  static String apiBaseUrl = const String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://localhost:8000',
  );

  static double defaultSeminarFee = 150.0;

  static void setApiUrl(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return;
    apiBaseUrl = trimmed.endsWith('/')
        ? trimmed.substring(0, trimmed.length - 1)
        : trimmed;
  }
}