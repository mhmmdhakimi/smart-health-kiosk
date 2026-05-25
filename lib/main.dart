import 'package:flutter/material.dart';
import 'utils/no_anim_route.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'core/firebase_option.dart';
import 'screens/language_selection.dart';
import 'screens/mobile_checkin.dart';
import 'utils/network_monitor.dart';
import 'utils/hardware_monitor.dart';

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

  // Start global monitors AFTER Firebase is ready so Firebase streams work.
  NetworkMonitor().startMonitoring();
  HardwareMonitor().startMonitoring();

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
        // Primary brand color synced with UniMAP Health student dashboard
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF133F85),
          brightness: Brightness.dark,
          primary: const Color(0xFF133F85),
          secondary: const Color(0xFF0EA5E9), // sky-blue accent (replaces cyanAccent)
          tertiary: const Color(0xFFA855F7),  // purple accent (matches dashboard)
          surface: const Color(0xFF133F85),
          onSurface: Colors.white,
        ),
        scaffoldBackgroundColor: const Color(0xFF0A2249),
        useMaterial3: true,
        // Consistent text styling across kiosk screens
        textTheme: const TextTheme(
          displayLarge: TextStyle(color: Colors.white),
          displayMedium: TextStyle(color: Colors.white),
          bodyLarge: TextStyle(color: Colors.white),
          bodyMedium: TextStyle(color: Colors.white70),
        ),
        // Elevated button style
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF133F85),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(14)),
            ),
          ),
        ),
        // Outlined button style
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF0EA5E9),
            side: BorderSide(color: Color(0xFF0EA5E9)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(14)),
            ),
          ),
        ),
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
