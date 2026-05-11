import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'config.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android: return android;
      default: throw UnsupportedError('Platform not supported');
    }
  }

  static FirebaseOptions get web => FirebaseOptions(
    apiKey: AppConfig.firebaseApiKey,
    authDomain: "smart-health-kiosk-193a5.firebaseapp.com",
    databaseURL: "https://smart-health-kiosk-193a5-default-rtdb.asia-southeast1.firebasedatabase.app",
    projectId: "smart-health-kiosk-193a5",
    storageBucket: "smart-health-kiosk-193a5.firebasestorage.app",
    messagingSenderId: "74365494988",
    appId: "1:74365494988:web:977ee83752dbb8b7ca4469"
  );

  static FirebaseOptions get android => FirebaseOptions(
    apiKey: AppConfig.firebaseApiKey,
    appId: "1:74365494988:android:977ee83752dbb8b7ca4469",
    messagingSenderId: "74365494988",
    projectId: "smart-health-kiosk-193a5",
    databaseURL: "https://smart-health-kiosk-193a5-default-rtdb.asia-southeast1.firebasedatabase.app",
    storageBucket: "smart-health-kiosk-193a5.firebasestorage.app"
  );
}