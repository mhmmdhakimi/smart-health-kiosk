import '../utils/no_anim_route.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:ui';
import 'welcome_selection.dart';
import '../utils/network_monitor.dart';

class LanguageSelectionPage extends StatefulWidget {
  const LanguageSelectionPage({super.key});

  @override
  State<LanguageSelectionPage> createState() => _LanguageSelectionPageState();
}

class _LanguageSelectionPageState extends State<LanguageSelectionPage> {
  bool _isNetworkOnline = true;
  StreamSubscription<bool>? _networkSub;

  @override
  void initState() {
    super.initState();
    // Seed synchronously so the first frame is already correct.
    _isNetworkOnline = NetworkMonitor().isOnline;
    _networkSub = NetworkMonitor().onlineStream.listen((isOnline) {
      if (mounted) setState(() => _isNetworkOnline = isOnline);
    });
  }

  @override
  void dispose() {
    _networkSub?.cancel();
    super.dispose();
  }

  // ── Full-screen bilingual system offline screen ───────────────────────────
  Widget _buildSystemOfflineScreen() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 130,
            height: 130,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.red.withValues(alpha: 0.08),
              border: Border.all(
                color: Colors.redAccent.withValues(alpha: 0.4),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.redAccent.withValues(alpha: 0.15),
                  blurRadius: 40,
                  spreadRadius: 10,
                ),
              ],
            ),
            child: const Icon(
              Icons.cloud_off_rounded,
              size: 64,
              color: Colors.redAccent,
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            'System Temporarily Unavailable\nSistem Tidak Tersedia Buat Masa Ini',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 0.5,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          const SizedBox(
            width: 560,
            child: Text(
              'We apologise for the inconvenience. The kiosk system is currently offline and all services are unavailable at this time. Please visit us again shortly, or speak to our clinic staff for immediate assistance.\n\n'
              'Kami memohon maaf atas kesulitan ini. Sistem kiosk sedang tidak dapat disambungkan dan semua perkhidmatan tidak tersedia buat masa ini. Sila kunjungi semula sebentar lagi, atau berjumpa dengan kakitangan klinik kami untuk bantuan segera.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: Colors.white54,
                height: 1.6,
              ),
            ),
          ),
          const SizedBox(height: 36),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.redAccent,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Attempting to reconnect... / Cuba menyambung semula...',
                style: TextStyle(
                  color: Colors.redAccent,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0A2249), Color(0xFF133F85)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Stack(
          children: [
            // ── Normal language selection UI (unchanged) ────────────────────
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "Smart Health Kiosk",
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          color: Colors.lightBlue.withValues(alpha: 0.5),
                          blurRadius: 20,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "Select Language / Pilih Bahasa",
                    style: TextStyle(fontSize: 24, color: Colors.white70),
                  ),
                  const SizedBox(height: 60),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _LanguageCard(
                        title: "ENGLISH",
                        icon: Icons.language,
                        onTap: () => Navigator.pushReplacement(
                          context,
                          NoAnimRoute(
                            page: const WelcomeSelectionScreen(isEnglish: true),
                          ),
                        ),
                      ),
                      const SizedBox(width: 40),
                      _LanguageCard(
                        title: "BAHASA MELAYU",
                        icon: Icons.translate,
                        onTap: () => Navigator.pushReplacement(
                          context,
                          NoAnimRoute(
                            page: const WelcomeSelectionScreen(
                              isEnglish: false,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // ── Software offline overlay — sits on top when network is down ─
            if (!_isNetworkOnline)
              Container(
                color: const Color(0xFF0A2249).withValues(alpha: 0.97),
                child: _buildSystemOfflineScreen(),
              ),
          ],
        ),
      ),
    );
  }
}

class _LanguageCard extends StatefulWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  const _LanguageCard({
    required this.title,
    required this.icon,
    required this.onTap,
  });

  @override
  State<_LanguageCard> createState() => _LanguageCardState();
}

class _LanguageCardState extends State<_LanguageCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    Color borderColor = _isPressed
        ? const Color(0xFF1B64F2)
        : Colors.white.withValues(alpha: 0.1);

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 320,
            height: 350,
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: borderColor, width: _isPressed ? 2 : 1),
              boxShadow: _isPressed
                  ? [
                      BoxShadow(
                        color: const Color(0xFF1B64F2).withValues(alpha: 0.3),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                    ]
                  : [],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(widget.icon, color: Colors.white, size: 80),
                const SizedBox(height: 40),
                Text(
                  widget.title,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
