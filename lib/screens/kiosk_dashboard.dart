import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:ui';
import 'package:firebase_database/firebase_database.dart';
import '../widgets/emergency_button.dart';
import 'language_selection.dart';

// Import our new modular screens
import 'self_checkup_screen.dart';
import 'walk_in_screen.dart';
import 'consultation_screen.dart';
import 'equipment_screen.dart';
import 'history_screen.dart';
import 'appointment_page.dart';

class KioskDashboard extends StatefulWidget {
  final String userName;
  final String userId;
  final bool isGuest;
  final String? guestPhone;
  final bool isEnglish;

  const KioskDashboard({
    super.key,
    required this.userName,
    required this.userId,
    required this.isGuest,
    this.guestPhone,
    required this.isEnglish,
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

  @override
  void initState() {
    super.initState();
    _resetIdleTimer();
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    _warningTimer?.cancel();
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

  void _showIdleWarningDialog() {
    setState(() => _isWarningDialogVisible = true);
    _warningTimer = Timer(const Duration(seconds: 15), _autoLogOut);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => AlertDialog(
        backgroundColor: const Color(0xFF111827),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
          side: const BorderSide(color: Colors.amberAccent),
        ),
        title: Row(
          children: [
            const Icon(Icons.timer, color: Colors.amberAccent, size: 30),
            const SizedBox(width: 10),
            Text(
              widget.isEnglish
                  ? "Are you still there?"
                  : "Adakah anda masih di sana?",
              style: const TextStyle(
                color: Colors.amberAccent,
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
              backgroundColor: Colors.amberAccent.withOpacity(0.2),
              foregroundColor: Colors.amberAccent,
              side: const BorderSide(color: Colors.amberAccent),
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

    FirebaseDatabase.instance.ref('kiosk_control/session_active').set(false);

    if (_isWarningDialogVisible && mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (c) => const LanguageSelectionPage()),
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

  Widget _buildHome() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 30.0),
          child: Column(
            children: [
              Text(
                widget.isEnglish
                    ? 'WELCOME! SELECT A SERVICE'
                    : 'SELAMAT DATANG! PILIH PERKHIDMATAN',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  shadows: [
                    Shadow(
                      color: Colors.cyanAccent.withOpacity(0.5),
                      blurRadius: 10,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
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
        Expanded(
          child: widget.isGuest
              ? Column(
                  children: [
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Spacer(flex: 1),
                          Expanded(
                            flex: 2,
                            child: GlassBentoCard(
                              icon: Icons.monitor_heart_outlined,
                              title: widget.isEnglish
                                  ? 'SELF-CHECKUP'
                                  : 'PEMERIKSAAN\nKENDIRI',
                              onTap: () =>
                                  setState(() => _currentView = "SELF_CHECKUP"),
                            ),
                          ),
                          const SizedBox(width: 30),
                          Expanded(
                            flex: 2,
                            child: GlassBentoCard(
                              icon: Icons.directions_walk_outlined,
                              title: widget.isEnglish
                                  ? 'WALK-IN'
                                  : 'WALK-IN (TIDAK\nBERJADUAL)',
                              onTap: () => setState(
                                () => _currentView = "WALK_IN_TRIAGE",
                              ),
                            ),
                          ),
                          const Spacer(flex: 1),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),
                    const Expanded(child: SizedBox()),
                  ],
                )
              : Column(
                  children: [
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: GlassBentoCard(
                              icon: Icons.monitor_heart_outlined,
                              title: widget.isEnglish
                                  ? 'SELF-CHECKUP'
                                  : 'PEMERIKSAAN\nKENDIRI',
                              onTap: () =>
                                  setState(() => _currentView = "SELF_CHECKUP"),
                            ),
                          ),
                          const SizedBox(width: 25),
                          Expanded(
                            child: GlassBentoCard(
                              icon: Icons.person_search_outlined,
                              title: widget.isEnglish
                                  ? 'MEDICAL\nCONSULTATION'
                                  : 'RUNDINGAN\nPERUBATAN',
                              onTap: () => setState(
                                () => _currentView = "SEE_DOCTOR_OPT",
                              ),
                            ),
                          ),
                          const SizedBox(width: 25),
                          Expanded(
                            child: GlassBentoCard(
                              icon: Icons.wheelchair_pickup_outlined,
                              title: widget.isEnglish
                                  ? 'MEDICAL EQUIPMENT\nRESERVATION'
                                  : 'TEMPAHAN PERALATAN\nPERUBATAN',
                              onTap: () =>
                                  setState(() => _currentView = "EQUIP_RES"),
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
                            child: GlassBentoCard(
                              icon: Icons.history_outlined,
                              title: widget.isEnglish
                                  ? 'HEALTH RECORD'
                                  : 'REKOD KESIHATAN',
                              onTap: () =>
                                  setState(() => _currentView = "CHECKUP_HIST"),
                            ),
                          ),
                          const SizedBox(width: 25),
                          Expanded(
                            child: GlassBentoCard(
                              icon: Icons.event_available_outlined,
                              title: widget.isEnglish
                                  ? 'APPOINTMENT'
                                  : 'TEMU JANJI',
                              onTap: () =>
                                  setState(() => _currentView = "APPT_HIST"),
                            ),
                          ),
                          const SizedBox(width: 25),
                          Expanded(
                            child: GlassBentoCard(
                              icon: Icons.biotech_outlined,
                              title: widget.isEnglish
                                  ? 'RESERVATION\nSTATUS'
                                  : 'STATUS\nTEMPAHAN',
                              onTap: () =>
                                  setState(() => _currentView = "EQUIP_HIST"),
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

  Widget _buildTopBar() {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          height: 80,
          padding: const EdgeInsets.symmetric(horizontal: 30),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.04),
            border: Border(
              bottom: BorderSide(
                color: Colors.white.withOpacity(0.1),
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
                        color: Colors.cyanAccent.withOpacity(0.1),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.cyanAccent.withOpacity(0.3),
                        ),
                      ),
                      child: const Icon(
                        Icons.health_and_safety,
                        color: Colors.cyanAccent,
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
                            color: Colors.cyanAccent.withOpacity(0.5),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: Colors.cyanAccent,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: Colors.cyanAccent, blurRadius: 10),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    "Status: Online",
                    style: TextStyle(
                      color: Colors.cyanAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 30),
              Container(
                height: 40,
                width: 1,
                color: Colors.white.withOpacity(0.2),
              ),
              const SizedBox(width: 30),
              Text(
                widget.userName.toUpperCase(),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 20),
              const CircleAvatar(
                radius: 22,
                backgroundColor: Color(0xFF1B64F2),
                child: Icon(Icons.person, color: Colors.white, size: 26),
              ),
              const SizedBox(width: 30),
              Container(
                height: 40,
                width: 1,
                color: Colors.white.withOpacity(0.2),
              ),
              const SizedBox(width: 30),
              EmergencyHelpButton(
                isEnglish: widget.isEnglish,
                patientName: widget.userName.toUpperCase(),
                patientId: widget.userId,
                location: 'Kiosk Top Bar',
                customText: widget.isEnglish ? "EMERGENCY" : "KECEMASAN",
                isCompact: true,
              ),
              const SizedBox(width: 30),
              Container(
                height: 40,
                width: 1,
                color: Colors.white.withOpacity(0.2),
              ),
              const SizedBox(width: 30),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  side: BorderSide(
                    color: Colors.redAccent.withOpacity(0.5),
                    width: 1,
                  ),
                  backgroundColor: Colors.redAccent.withOpacity(0.1),
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
    bool isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    return Listener(
      onPointerDown: (_) => _resetIdleTimer(),
      onPointerMove: (_) => _resetIdleTimer(),
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0B0F19), Color(0xFF111827)],
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

  const GlassBentoCard({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
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
        transform: Matrix4.identity()..scale(_isPressed ? 0.98 : 1.0),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: _isPressed
                      ? const Color(0xFF06B6D4)
                      : Colors.white.withOpacity(0.1),
                  width: _isPressed ? 2 : 1,
                ),
                boxShadow: _isPressed
                    ? [
                        BoxShadow(
                          color: const Color(0xFF06B6D4).withOpacity(0.3),
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
                        ? const Color(0xFF06B6D4)
                        : Colors.cyanAccent.withOpacity(0.8),
                    shadows: [
                      Shadow(
                        color: const Color(0xFF06B6D4).withOpacity(0.5),
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
                                color: const Color(0xFF06B6D4).withOpacity(0.8),
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
