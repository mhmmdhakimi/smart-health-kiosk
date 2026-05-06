import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android: return android;
      // Add iOS/others if needed
      default: throw UnsupportedError('Platform not supported');
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: "AIzaSyB0t88bvV3eTZoGLqt3_DOp4AXjwEYTlW4",
    appId: "1:74365494988:web:977ee83752dbb8b7ca4469",
    messagingSenderId: "74365494988",
    projectId: 'smart-health-kiosk-193a5',
    authDomain: "smart-health-kiosk-193a5.firebaseapp.com",
    storageBucket: "smart-health-kiosk-193a5.firebasestorage.app",
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'YOUR_ANDROID_API_KEY',
    appId: 'YOUR_ANDROID_APP_ID',
    messagingSenderId: '...',
    projectId: 'smart-health-kiosk-777e1',
    storageBucket: 'smart-health-kiosk-777e1.appspot.com',
  );
}