class AppConfig {
  /// Production API (same one the web app uses).
  static const String baseUrl = 'https://reactapi.ricehr.com/api';

  /// For local testing on the Android emulator use:
  ///   http://10.0.2.2:3000/api
  /// On a real phone use your computer's LAN IP, e.g. http://192.168.1.10:3000/api
  // static const String baseUrl = 'http://10.0.2.2:3000/api';

  static const int campaignId = 1;
  static const int batchNumber = 1;
}
