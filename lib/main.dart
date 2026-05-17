import 'package:flutter/material.dart';
import 'utils/no_anim_route.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'core/firebase_option.dart';
import 'screens/language_selection.dart';
import 'screens/mobile_checkin.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // KIOSK MODE: Force Landscape & Immersive Fullscreen
  // Ensure these are only called on supported platforms (Android/iOS) to prevent exceptions on Desktop/Web
  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS)) {
    try {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeRight,
        DeviceOrientation.landscapeLeft,
      ]);
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } catch (e) {
      debugPrint('Failed to set SystemUI mode: $e');
    }
  }

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const SmartHealthKioskApp());
}

class SmartHealthKioskApp extends StatelessWidget {
  const SmartHealthKioskApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'UniMAP Smart Health Kiosk',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF133F85)),
        scaffoldBackgroundColor: Colors.white,
        useMaterial3: true,
      ),
      initialRoute: '/',
      onGenerateRoute: (settings) {
        // Handle the deep link from the mobile QR scan
        Uri uri = Uri.parse(settings.name ?? '/');
        if (uri.path == '/checkin') {
          String kioskId = uri.queryParameters['kioskId'] ?? 'KIOSK_01';
          String sessionId = uri.queryParameters['session'] ?? '';
          return NoAnimRoute(
            settings: settings,
            page: MobileCheckInPage(kioskId: kioskId, sessionId: sessionId),
          );
        }
        // Default to the kiosk welcome screen
        return NoAnimRoute(
          settings: settings,
          page: const LanguageSelectionPage(),
        );
      },
    );
  }
}
