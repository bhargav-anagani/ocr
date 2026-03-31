class AppConstants {
  AppConstants._();

  // API base URL - change to your backend URL
  static const String baseUrl = 'https://ocr-avml.onrender.com';

  // API endpoints
  static const String registerEndpoint = '/api/auth/register';
  static const String loginEndpoint = '/api/auth/login';
  static const String ocrUploadEndpoint = '/api/ocr/upload';
  static const String ocrHistoryEndpoint = '/api/ocr/history';
  static const String ocrStatsEndpoint = '/api/ocr/stats/summary';

  // Storage keys
  static const String tokenKey = 'access_token';
  static const String userKey = 'user_data';

  // Supported formats display
  static const List<String> supportedFormats = ['JPG', 'JPEG', 'PNG', 'BMP', 'TIFF', 'WEBP', 'PDF'];

  // App info
  static const String appName = 'OcrVision';
  static const String appTagline = 'AI-Powered Text Recognition';
  static const String appVersion = '1.0.0';

  // Pagination
  static const int historyPerPage = 10;

  // Animation durations
  static const Duration shortAnim = Duration(milliseconds: 200);
  static const Duration mediumAnim = Duration(milliseconds: 400);
  static const Duration longAnim = Duration(milliseconds: 800);
}
