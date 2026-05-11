class AppConfig {
  // These will be passed during build/run using --dart-define
  static const String firebaseApiKey = String.fromEnvironment('FIREBASE_API_KEY', defaultValue: 'AIzaSyB0t88bvV3eTZoGLqt3_DOp4AXjwEYTlW4');
  static const String emailJsPublicKey = String.fromEnvironment('EMAILJS_PUBLIC_KEY', defaultValue: '73WBQxNlkGUqMf2r9');
  static const String emailJsServiceId = String.fromEnvironment('EMAILJS_SERVICE_ID', defaultValue: 'service_f3mmtjj');
}