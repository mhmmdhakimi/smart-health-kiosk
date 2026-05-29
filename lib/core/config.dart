import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  static String get firebaseApiKey => dotenv.env['FIREBASE_API_KEY']!;
  static String get firebaseAppId => dotenv.env['FIREBASE_APP_ID']!;
  static String get emailJsPublicKey => dotenv.env['EMAILJS_PUBLIC_KEY']!;
  static String get emailJsServiceId => dotenv.env['EMAILJS_SERVICE_ID']!;
  static String get emailJsTemplateId1 => dotenv.env['EMAILJS_TEMPLATE_ID1']!;
  static String get emailJsTemplateId2 => dotenv.env['EMAILJS_TEMPLATE_ID2']!;
}