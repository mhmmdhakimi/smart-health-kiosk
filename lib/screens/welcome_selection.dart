import '../utils/no_anim_route.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:ui';
import 'kiosk_login.dart';
import 'app_login_qr.dart';
import 'language_selection.dart';
import 'guest_qr.dart';
import '../utils/hardware_monitor.dart';
import '../utils/network_monitor.dart';

class WelcomeSelectionScreen extends StatefulWidget {
  final bool isEnglish;
  const WelcomeSelectionScreen({super.key, required this.isEnglish});

  @override
  State<WelcomeSelectionScreen> createState() => _WelcomeSelectionScreenState();
}

class _WelcomeSelectionScreenState extends State<WelcomeSelectionScreen> {
  bool _isHardwareOnline = false;
  StreamSubscription? _hardwareSub;

  bool _isNetworkOnline = true;
  StreamSubscription<bool>? _networkSub;

  @override
  void initState() {
    super.initState();
    // Seed the current value synchronously, then subscribe for updates.
    _isHardwareOnline = HardwareMonitor().isOnline;
    _hardwareSub = HardwareMonitor().onlineStream.listen((isOnline) {
      if (mounted) setState(() => _isHardwareOnline = isOnline);
    });

    // Seed network state synchronously and subscribe for changes.
    _isNetworkOnline = NetworkMonitor().isOnline;
    _networkSub = NetworkMonitor().onlineStream.listen((isOnline) {
      if (mounted) setState(() => _isNetworkOnline = isOnline);
    });
  }

  @override
  void dispose() {
    _hardwareSub?.cancel();
    _networkSub?.cancel();
    super.dispose();
  }

  // ── Software offline notice banner ─────────────────────────────────────────
  Widget _buildNetworkOfflineBanner() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 28),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.redAccent.withValues(alpha: 0.5),
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.cloud_off_rounded, color: Colors.redAccent, size: 26),
          const SizedBox(width: 14),
          Flexible(
            child: Text(
              widget.isEnglish
                  ? 'The system is currently offline, sorry for the inconvenience. Please come again later.'
                  : 'Sistem sedang tidak aktif, maaf atas kesulitan yang berlaku. Sila cuba lagi kemudian.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.redAccent,
                fontSize: 15,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(width: 14),
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.redAccent,
            ),
          ),
        ],
      ),
    );
  }

  void _showHardwareOfflineDialog() {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: const Color(0xFF0D1B3E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: Colors.orangeAccent.withValues(alpha: 0.6),
            width: 1.5,
          ),
        ),
        title: Row(
          children: [
            const Icon(
              Icons.sensors_off_rounded,
              color: Colors.orangeAccent,
              size: 30,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                widget.isEnglish
                    ? 'Card Reader Unavailable'
                    : 'Pembaca Kad Tidak Tersedia',
                style: const TextStyle(
                  color: Colors.orangeAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          widget.isEnglish
              ? 'The RFID card reader hardware is currently offline or not responding.\n\n'
                'Please use the Mobile App QR login instead, or contact clinic staff for assistance.'
              : 'Perkakasan pembaca kad RFID sedang tidak aktif atau tidak bertindak balas.\n\n'
                'Sila gunakan log masuk QR Aplikasi Mudah Alih, atau hubungi kakitangan klinik untuk bantuan.',
          style: const TextStyle(
            fontSize: 15,
            color: Colors.white70,
            height: 1.5,
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orangeAccent.withValues(alpha: 0.15),
              foregroundColor: Colors.orangeAccent,
              side: BorderSide(
                color: Colors.orangeAccent.withValues(alpha: 0.5),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => Navigator.pop(c),
            child: Text(
              widget.isEnglish ? 'OK, UNDERSTOOD' : 'OK, FAHAM',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
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
            Positioned(
              top: 20,
              left: 20,
              child: TextButton.icon(
                onPressed: () => Navigator.pushReplacement(
                  context,
                  NoAnimRoute(page: const LanguageSelectionPage()),
                ),
                icon: const Icon(
                  Icons.arrow_back,
                  size: 28,
                  color: Colors.white,
                ),
                label: Text(
                  widget.isEnglish ? 'Back' : 'Kembali',
                  style: const TextStyle(fontSize: 18, color: Colors.white),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    widget.isEnglish
                        ? "Select Login Method"
                        : "Pilih Kaedah Log Masuk",
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    widget.isEnglish
                        ? "How would you like to log in?"
                        : "Bagaimana anda ingin log masuk?",
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 20,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 60),
                  // ── Network offline notice (shown above cards when offline) ─
                  if (!_isNetworkOnline) _buildNetworkOfflineBanner(),
                  // ── Login option cards ─────────────────────────────────────
                  // When network is offline all cards are grayed and non-interactive.
                  Opacity(
                    opacity: _isNetworkOnline ? 1.0 : 0.35,
                    child: IgnorePointer(
                      ignoring: !_isNetworkOnline,
                      child: Row(
                        children: [
                          // ── Student Card login ────────────────────────────
                          Expanded(
                            child: _BentoLoginCard(
                              title: widget.isEnglish
                                  ? "Student Card"
                                  : "Kad Pelajar",
                              subtext: _isHardwareOnline
                                  ? (widget.isEnglish
                                      ? "TAP PHYSICAL CARD ON SCANNER"
                                      : "SENTUH KAD FIZIKAL PADA PENGIMBAS")
                                  : (widget.isEnglish
                                      ? "CARD READER OFFLINE"
                                      : "PEMBACA KAD TIDAK AKTIF"),
                              icon: Icons.vignette_rounded,
                              auraColor: _isHardwareOnline
                                  ? const Color(0xFF1B64F2)
                                  : Colors.orangeAccent,
                              isDisabled: !_isHardwareOnline,
                              onTap: _isHardwareOnline
                                  ? () => Navigator.push(
                                      context,
                                      NoAnimRoute(
                                        page: KioskLoginPage(
                                            isEnglish: widget.isEnglish),
                                      ),
                                    )
                                  : _showHardwareOfflineDialog,
                            ),
                          ),
                          const SizedBox(width: 24),
                          // ── Mobile App QR login ───────────────────────────
                          Expanded(
                            child: _BentoLoginCard(
                              title: widget.isEnglish
                                  ? "Mobile App"
                                  : "Aplikasi Mudah Alih",
                              subtext: widget.isEnglish
                                  ? "SCAN QR LINK WITH PHONE"
                                  : "IMBAS KOD QR DENGAN TELEFON",
                              icon: Icons.phonelink_setup_rounded,
                              auraColor: const Color(0xFF8B5CF6),
                              onTap: () => Navigator.push(
                                context,
                                NoAnimRoute(
                                  page: AppLoginQrPage(
                                      isEnglish: widget.isEnglish),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 24),
                          // ── Guest access ──────────────────────────────────
                          Expanded(
                            child: _BentoLoginCard(
                              title: widget.isEnglish
                                  ? "Guest Access"
                                  : "Akses Tetamu",
                              subtext: widget.isEnglish
                                  ? "PROCEED WITHOUT ACCOUNT"
                                  : "TERUSKAN TANPA AKAUN",
                              icon: Icons.person_outline_rounded,
                              auraColor: const Color(0xFF10B981),
                              onTap: () => Navigator.push(
                                context,
                                NoAnimRoute(
                                  page: GuestQrPage(isEnglish: widget.isEnglish),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// _BentoLoginCard
// ────────────────────────────────────────────────────────────────────────────
class _BentoLoginCard extends StatefulWidget {
  final String title;
  final String subtext;
  final IconData icon;
  final Color auraColor;
  final VoidCallback onTap;
  final bool isDisabled;

  const _BentoLoginCard({
    required this.title,
    required this.subtext,
    required this.icon,
    required this.auraColor,
    required this.onTap,
    this.isDisabled = false,
  });

  @override
  State<_BentoLoginCard> createState() => _BentoLoginCardState();
}

class _BentoLoginCardState extends State<_BentoLoginCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final effectiveAura = widget.isDisabled
        ? widget.auraColor.withValues(alpha: 0.5)
        : widget.auraColor;

    return Opacity(
      opacity: widget.isDisabled ? 0.55 : 1.0,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) {
          setState(() => _isPressed = false);
          widget.onTap();
        },
        onTapCancel: () => setState(() => _isPressed = false),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              height: 380,
              constraints: const BoxConstraints(minHeight: 250),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: _isPressed
                      ? effectiveAura
                      : Colors.white.withValues(alpha: 0.1),
                  width: _isPressed ? 2 : 1,
                ),
                boxShadow: _isPressed
                    ? [
                        BoxShadow(
                          color: effectiveAura.withValues(alpha: 0.4),
                          blurRadius: 40,
                          spreadRadius: 5,
                        ),
                      ]
                    : [],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: effectiveAura.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      widget.isDisabled
                          ? Icons.sensors_off_rounded
                          : widget.icon,
                      color: effectiveAura,
                      size: 70,
                    ),
                  ),
                  const SizedBox(height: 30),
                  Text(
                    widget.title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.subtext,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.6),
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
