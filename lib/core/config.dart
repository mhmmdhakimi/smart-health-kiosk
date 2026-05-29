import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  static String _getRequired(String key) {
    return dotenv.env[key] ??
        (throw Exception(
            'CRITICAL CONFIG ERROR: "$key" is missing from your root .env file. Please check your environment variables before booting the app.'));
  }

  static String get firebaseApiKey => _getRequired('FIREBASE_API_KEY');
  static String get firebaseAppId => _getRequired('FIREBASE_APP_ID');
  static String get firebaseAppIdWeb =>
      dotenv.env['FIREBASE_APP_ID_WEB'] ?? _getRequired('FIREBASE_APP_ID');
  static String get emailJsPublicKey => _getRequired('EMAILJS_PUBLIC_KEY');
  static String get emailJsServiceId => _getRequired('EMAILJS_SERVICE_ID');
  static String get emailJsTemplateId1 => _getRequired('EMAILJS_TEMPLATE_ID1');
  static String get emailJsTemplateId2 => _getRequired('EMAILJS_TEMPLATE_ID2');
}