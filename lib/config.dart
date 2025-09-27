class AppConfig {
  // Default to Android emulator loopback. Change if running on device/network.
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://77.37.96.71:8001',
  );
}

