import '../utils/no_anim_route.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:ui';
import 'package:firebase_database/firebase_database.dart';
import 'language_selection.dart';

// Import our new modular screens
import 'self_checkup_screen.dart';
import 'walk_in_screen.dart';
import 'consultation_screen.dart';
import 'equipment_screen.dart';
import 'history_screen.dart';
import 'appointment_page.dart';
import '../utils/network_monitor.dart';
import '../utils/hardware_monitor.dart';

class KioskDashboard extends StatefulWidget {
  final String userName;
  final String userId;
  final bool isGuest;
  final String? guestPhone;
  final bool isEnglish;
  final String kioskId;

  const KioskDashboard({
    super.key,
    required this.userName,
    required this.userId,
    required this.isGuest,
    this.guestPhone,
    required this.isEnglish,
    this.kioskId = 'KIOSK_01',
  });

  @override
  State<KioskDashboard> createState() => _KioskDashboardState();
}

class _KioskDashboardState extends State<KioskDashboard> {
  String _currentView = "HOME";
  bool _isCheckupActive = false;

  Timer? _idleTimer;
  Timer? _warningTimer;
  bool _isWarningDialogVisible = false;

  // Global hardware monitor subscription
  StreamSubscription? _hardwareSub;
  bool _isHardwareOnline = false;

  // Network monitoring
  bool _isNetworkOnline = true;

  @override
  void initState() {
    super.initState();
    _resetIdleTimer();
    _initNetworkMonitoring();
    _initHardwareMonitoring();
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    _warningTimer?.cancel();
    _hardwareSub?.cancel();
    super.dispose();
  }

  void _resetIdleTimer() {
    _idleTimer?.cancel();
    _warningTimer?.cancel();

    if (_isCheckupActive) return; // Never timeout during a checkup

    if (_isWarningDialogVisible) {
      Navigator.of(context, rootNavigator: true).pop();
      _isWarningDialogVisible = false;
    }

    _idleTimer = Timer(const Duration(seconds: 45), _showIdleWarningDialog);
  }

  void _initNetworkMonitoring() {
    _isNetworkOnline = NetworkMonitor().isOnline;
    NetworkMonitor().onlineStream.listen((isOnline) {
      if (mounted) {
        setState(() => _isNetworkOnline = isOnline);
      }
    });
  }

  void _initHardwareMonitoring() {
    // Seed synchronously so the UI is correct before the first stream event.
    _isHardwareOnline = HardwareMonitor().isOnline;
    _hardwareSub = HardwareMonitor().onlineStream.listen((isOnline) {
      if (mounted) {
        setState(() => _isHardwareOnline = isOnline);
      }
    });
  }

  void _showIdleWarningDialog() {
    setState(() => _isWarningDialogVisible = true);
    _warningTimer = Timer(const Duration(seconds: 15), _autoLogOut);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => AlertDialog(
        backgroundColor: const Color(0xFF133F85),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
          side: const BorderSide(color: Colors.amber),
        ),
        title: Row(
          children: [
            const Icon(Icons.timer, color: Colors.amber, size: 30),
            const SizedBox(width: 10),
            Text(
              widget.isEnglish
                  ? "Are you still there?"
                  : "Adakah anda masih di sana?",
              style: const TextStyle(
                color: Colors.amber,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Text(
          widget.isEnglish
              ? "You have been idle for a while.\n\nFor your security, you will be automatically logged out in 15 seconds if there is no activity."
              : "Anda telah melahu sebentar.\n\nUntuk keselamatan anda, anda akan dilog keluar secara automatik dalam 15 saat jika tiada aktiviti.",
          style: const TextStyle(fontSize: 16, color: Colors.white),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber.withValues(alpha: 0.2),
              foregroundColor: Colors.amber,
              side: const BorderSide(color: Colors.amber),
            ),
            onPressed: () => _resetIdleTimer(),
            child: Text(
              widget.isEnglish ? "I'M STILL HERE" : "SAYA MASIH DI SINI",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _autoLogOut() {
    _idleTimer?.cancel();
    _warningTimer?.cancel();

    FirebaseDatabase.instance
        .ref('kiosk/${widget.kioskId}/session_active')
        .set(false);

    if (mounted) {
      // Reset all nested state layout variables explicitly
      setState(() {
        _currentView = "HOME";
        _isCheckupActive = false;
        _isWarningDialogVisible = false;
      });

      // Cleanly close active context overlays to clear potential background dialog leakages
      while (Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    }

    Navigator.pushAndRemoveUntil(
      context,
      NoAnimRoute(page: const LanguageSelectionPage()),
      (r) => false,
    );
  }

  Widget _getContent() {
    switch (_currentView) {
      case "SELF_CHECKUP":
        return SelfCheckupScreen(
          userId: widget.userId,
          userName: widget.userName,
          isEnglish: widget.isEnglish,
          onBack: () => setState(() => _currentView = "HOME"),
          onStateChanged: (isActive) {
            setState(() => _isCheckupActive = isActive);
            _resetIdleTimer();
          },
        );
      case "SEE_DOCTOR_OPT":
        return ConsultationScreen(
          userId: widget.userId,
          userName: widget.userName,
          isGuest: widget.isGuest,
          isEnglish: widget.isEnglish,
          onBack: () => setState(() => _currentView = "HOME"),
          onWalkIn: () => setState(() => _currentView = "WALK_IN_TRIAGE"),
          onLogOut: _autoLogOut,
        );
      case "WALK_IN_TRIAGE":
        return WalkInScreen(
          userId: widget.userId,
          userName: widget.userName,
          isGuest: widget.isGuest,
          guestPhone: widget.guestPhone,
          isEnglish: widget.isEnglish,
          onBack: () => setState(() => _currentView = "HOME"),
          onLogOut: _autoLogOut,
        );
      case "EQUIP_RES":
        return EquipmentScreen(
          userId: widget.userId,
          userName: widget.userName,
          isEnglish: widget.isEnglish,
          onBack: () => setState(() => _currentView = "HOME"),
          onLogOut: _autoLogOut,
        );
      case "CHECKUP_HIST":
        return HistoryScreen(
          userId: widget.userId,
          isEnglish: widget.isEnglish,
          historyType: "CHECKUP",
          onBack: () => setState(() => _currentView = "HOME"),
        );
      case "APPT_HIST":
        return HistoryScreen(
          userId: widget.userId,
          isEnglish: widget.isEnglish,
          historyType: "APPOINTMENT",
          onBack: () => setState(() => _currentView = "HOME"),
        );
      case "APPT_BOOK":
        return AppointmentPage(
          userId: widget.userId,
          userName: widget.userName,
          isGuest: widget.isGuest,
          guestPhone: widget.guestPhone,
          isEnglish: widget.isEnglish,
          onBack: () => setState(() => _currentView = "HOME"),
          onLogOut: _autoLogOut,
        );
      case "EQUIP_HIST":
        return HistoryScreen(
          userId: widget.userId,
          isEnglish: widget.isEnglish,
          historyType: "EQUIPMENT",
          onBack: () => setState(() => _currentView = "HOME"),
        );
      default:
        return _buildHome();
    }
  }

  // ── Disabled reason enum ──────────────────────────────────────────────────
  void _showDisabledDialog({required String title, required String message, required IconData icon, required Color color}) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: const Color(0xFF0D1B3E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: color.withValues(alpha: 0.6), width: 1.5),
        ),
        title: Row(
          children: [
            Icon(icon, color: color, size: 30),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(fontSize: 15, color: Colors.white70, height: 1.5),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: color.withValues(alpha: 0.15),
              foregroundColor: color,
              side: BorderSide(color: color.withValues(alpha: 0.5)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(c),
            child: Text(
              widget.isEnglish ? "OK, UNDERSTOOD" : "OK, FAHAM",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBentoCard({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isRestricted = false,
    // isHardwareDependent = only grayed when hardware is offline
    // isNetworkDependent  = grayed when network is offline (default for all)
    bool isHardwareDependent = false,
  }) {
    // Network offline → everything is disabled
    if (!_isNetworkOnline) {
      return Opacity(
        opacity: 0.35,
        child: GlassBentoCard(icon: icon, title: title, onTap: () {}),
      );
    }

    // Hardware offline → only hardware-dependent features are disabled
    if (isHardwareDependent && !_isHardwareOnline) {
      return Opacity(
        opacity: 0.45,
        child: GlassBentoCard(
          icon: icon,
          title: title,
          onTap: () => _showDisabledDialog(
            icon: Icons.sensors_off_rounded,
            color: Colors.orangeAccent,
            title: widget.isEnglish ? 'Hardware Offline' : 'Perkakasan Tidak Aktif',
            message: widget.isEnglish
                ? 'The health scanning hardware is currently offline or not responding.\n\nPlease wait for the hardware to reconnect, or contact clinic staff for assistance.'
                : 'Perkakasan imbasan kesihatan sedang tidak aktif atau tidak bertindak balas.\n\nSila tunggu sehingga perkakasan disambung semula, atau hubungi kakitangan klinik untuk bantuan.',
          ),
        ),
      );
    }

    // Access restricted (guest trying to use student-only feature)
    if (isRestricted) {
      return Opacity(
        opacity: 0.45,
        child: GlassBentoCard(
          icon: icon,
          title: title,
          onTap: () => _showDisabledDialog(
            icon: Icons.lock_outline_rounded,
            color: Colors.lightBlueAccent,
            title: widget.isEnglish ? 'Access Restricted' : 'Akses Terhad',
            message: widget.isEnglish
                ? 'This feature requires an official UniMAP Student Account.\n\nPlease scan your Student ID card at the login portal to continue.'
                : 'Ciri ini memerlukan Akaun Pelajar UniMAP rasmi.\n\nSila imbas kad ID pelajar anda di portal log masuk untuk meneruskan.',
          ),
        ),
      );
    }

    return GlassBentoCard(icon: icon, title: title, onTap: onTap);
  }

  Widget _buildHome() {
    // ── Software (network) offline → full-screen unavailable message ──────────
    if (!_isNetworkOnline) {
      return _buildSystemOfflineScreen();
    }

    return Column(
      children: [
        // ── Header ─────────────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.only(bottom: 24.0),
          child: Column(
            children: [
              // Hardware offline notice strip
              if (!_isHardwareOnline) _buildHardwareOfflineBanner(),
              if (!_isHardwareOnline) const SizedBox(height: 10),
              Text(
                widget.isEnglish
                    ? 'WELCOME, ${widget.userName.toUpperCase()}!'
                    : 'SELAMAT DATANG, ${widget.userName.toUpperCase()}!',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  shadows: [
                    Shadow(
                      color: Colors.lightBlueAccent.withValues(alpha: 0.5),
                      blurRadius: 10,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Text(
                widget.isEnglish
                    ? 'PLEASE CHOOSE AN OPTION BELOW TO BEGIN.'
                    : 'SILA PILIH PILIHAN DI BAWAH UNTUK BERMULA.',
                style: const TextStyle(
                  fontSize: 18,
                  color: Colors.white70,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
        ),
        // ── Bento Grid ─────────────────────────────────────────────────────────
        Expanded(
          child: Column(
            children: [
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _buildBentoCard(
                        icon: Icons.monitor_heart_outlined,
                        title: widget.isEnglish
                            ? 'SELF-CHECKUP'
                            : 'PEMERIKSAAN\nKENDIRI',
                        onTap: () =>
                            setState(() => _currentView = "SELF_CHECKUP"),
                        // Self-checkup needs hardware to be functional
                        isHardwareDependent: true,
                      ),
                    ),
                    const SizedBox(width: 25),
                    Expanded(
                      child: _buildBentoCard(
                        icon: Icons.person_search_outlined,
                        title: widget.isEnglish
                            ? 'MEDICAL\nCONSULTATION'
                            : 'RUNDINGAN\nPERUBATAN',
                        onTap: () =>
                            setState(() => _currentView = "SEE_DOCTOR_OPT"),
                        isRestricted: widget.isGuest,
                      ),
                    ),
                    const SizedBox(width: 25),
                    Expanded(
                      child: _buildBentoCard(
                        icon: Icons.wheelchair_pickup_outlined,
                        title: widget.isEnglish
                            ? 'MEDICAL EQUIPMENT\nRESERVATION'
                            : 'TEMPAHAN PERALATAN\nPERUBATAN',
                        onTap: () => setState(() => _currentView = "EQUIP_RES"),
                        isRestricted: widget.isGuest,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 25),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _buildBentoCard(
                        icon: widget.isGuest
                            ? Icons.directions_walk_outlined
                            : Icons.history_outlined,
                        title: widget.isGuest
                            ? (widget.isEnglish
                                  ? 'WALK-IN'
                                  : 'WALK-IN (TIDAK\nBERJADUAL)')
                            : (widget.isEnglish
                                  ? 'HEALTH RECORD'
                                  : 'REKOD KESIHATAN'),
                        onTap: () => setState(
                          () => _currentView = widget.isGuest
                              ? "WALK_IN_TRIAGE"
                              : "CHECKUP_HIST",
                        ),
                      ),
                    ),
                    const SizedBox(width: 25),
                    Expanded(
                      child: _buildBentoCard(
                        icon: Icons.event_available_outlined,
                        title: widget.isEnglish ? 'APPOINTMENT' : 'TEMU JANJI',
                        onTap: () => setState(() => _currentView = "APPT_HIST"),
                        isRestricted: widget.isGuest,
                      ),
                    ),
                    const SizedBox(width: 25),
                    Expanded(
                      child: _buildBentoCard(
                        icon: Icons.biotech_outlined,
                        title: widget.isEnglish
                            ? 'RESERVATION\nSTATUS'
                            : 'STATUS\nTEMPAHAN',
                        onTap: () =>
                            setState(() => _currentView = "EQUIP_HIST"),
                        isRestricted: widget.isGuest,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Full-screen software offline screen ──────────────────────────────────
  Widget _buildSystemOfflineScreen() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Animated icon container
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
          Text(
            widget.isEnglish
                ? 'System Temporarily Unavailable'
                : 'Sistem Tidak Tersedia Buat Masa Ini',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: 520,
            child: Text(
              widget.isEnglish
                  ? 'We apologise for the inconvenience. The kiosk system is currently offline and all services are unavailable at this time.\n\nPlease visit us again shortly, or speak to our clinic staff for immediate assistance.'
                  : 'Kami memohon maaf atas kesulitan ini. Sistem kiosk sedang tidak dapat disambungkan dan semua perkhidmatan tidak tersedia buat masa ini.\n\nSila kunjungi semula sebentar lagi, atau berjumpa dengan kakitangan klinik kami untuk bantuan segera.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.white54,
                height: 1.6,
              ),
            ),
          ),
          const SizedBox(height: 36),
          // Pulsing reconnecting indicator
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
              Text(
                widget.isEnglish ? 'Attempting to reconnect...' : 'Cuba menyambung semula...',
                style: const TextStyle(
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

  // ── Hardware offline notice banner ───────────────────────────────────────
  Widget _buildHardwareOfflineBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.orangeAccent.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.sensors_off_rounded, color: Colors.orangeAccent, size: 20),
          const SizedBox(width: 10),
          Text(
            widget.isEnglish
                ? 'Health scanner offline — Self-Checkup is unavailable.'
                : 'Pengimbas kesihatan tidak aktif — Pemeriksaan Kendiri tidak tersedia.',
            style: const TextStyle(
              color: Colors.orangeAccent,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }



  Widget _buildTopBar() {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          height: 80,
          padding: const EdgeInsets.symmetric(horizontal: 30),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            border: Border(
              bottom: BorderSide(
                color: Colors.white.withValues(alpha: 0.1),
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              InkWell(
                onTap: () => setState(() => _currentView = "HOME"),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.lightBlueAccent.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.lightBlueAccent.withValues(alpha: 0.3),
                        ),
                      ),
                      child: const Icon(
                        Icons.health_and_safety,
                        color: Colors.lightBlueAccent,
                        size: 30,
                      ),
                    ),
                    const SizedBox(width: 15),
                    Text(
                      "SMART HEALTH KIOSK",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 22,
                        letterSpacing: 2.0,
                        shadows: [
                          Shadow(
                            color: Colors.lightBlueAccent.withValues(
                              alpha: 0.5,
                            ),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 30),
              Container(
                height: 40,
                width: 1,
                color: Colors.white.withValues(alpha: 0.2),
              ),
              const SizedBox(width: 30),
              Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: _isHardwareOnline
                          ? Colors.lightBlueAccent
                          : Colors.redAccent,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: _isHardwareOnline
                              ? Colors.lightBlueAccent
                              : Colors.redAccent,
                          blurRadius: 10,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: Text(
                      _isHardwareOnline
                          ? "Hardware Status: Online"
                          : "Hardware Status: Offline",
                      key: ValueKey<bool>(_isHardwareOnline),
                      style: TextStyle(
                        color: _isHardwareOnline
                            ? Colors.lightBlueAccent
                            : Colors.redAccent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Container(
                height: 40,
                width: 1,
                color: Colors.white.withValues(alpha: 0.2),
              ),
              const SizedBox(width: 30),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  side: BorderSide(
                    color: Colors.redAccent.withValues(alpha: 0.5),
                    width: 1,
                  ),
                  backgroundColor: Colors.redAccent.withValues(alpha: 0.1),
                  foregroundColor: Colors.redAccent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                icon: const Icon(Icons.power_settings_new),
                label: Text(
                  widget.isEnglish ? "LOG OUT" : "LOG KELUAR",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                onPressed: () => _autoLogOut(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _resetIdleTimer(),
      onPointerMove: (_) => _resetIdleTimer(),
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0A2249), Color(0xFF133F85)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Column(
            children: [
              _buildTopBar(),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(35),
                  child: _getContent(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// GlassBentoCard: Custom Widget for Bento Grid
// ────────────────────────────────────────────────────────────────────────────
class GlassBentoCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final bool isNetworkDependent;
  final bool isHardwareOnline;

  const GlassBentoCard({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.isNetworkDependent = true,
    this.isHardwareOnline = true,
  });

  @override
  State<GlassBentoCard> createState() => _GlassBentoCardState();
}

class _GlassBentoCardState extends State<GlassBentoCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeInOut,
        transform: Matrix4.diagonal3Values(_isPressed ? 0.98 : 1.0, _isPressed ? 0.98 : 1.0, 1.0),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: _isPressed
                      ? const Color(0xFF0EA5E9)
                      : const Color(0xFF1E293B),
                  width: _isPressed ? 2.0 : 1.0,
                ),
                boxShadow: _isPressed
                    ? [
                        BoxShadow(
                          color: const Color(0xFF0EA5E9).withValues(alpha: 0.3),
                          blurRadius: 30,
                          spreadRadius: 5,
                        ),
                      ]
                    : [],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(
                    widget.icon,
                    size: 80,
                    color: _isPressed
                        ? const Color(0xFF0EA5E9)
                        : Colors.lightBlueAccent.withValues(alpha: 0.8),
                    shadows: [
                      Shadow(
                        color: const Color(0xFF0EA5E9).withValues(alpha: 0.5),
                        blurRadius: _isPressed ? 20 : 10,
                      ),
                    ],
                  ),
                  const SizedBox(height: 25),
                  Text(
                    widget.title.toUpperCase(),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 1.2,
                      shadows: _isPressed
                          ? [
                              Shadow(
                                color: const Color(
                                  0xFF0EA5E9,
                                ).withValues(alpha: 0.8),
                                blurRadius: 10,
                              ),
                            ]
                          : [],
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
