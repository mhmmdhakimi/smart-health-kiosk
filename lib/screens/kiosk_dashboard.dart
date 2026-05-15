// lib/screens/kiosk_dashboard.dart
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import '../widgets/emergency_button.dart';
import 'language_selection.dart';

// Import our new modular screens
import 'self_checkup_screen.dart';
import 'walk_in_screen.dart';
import 'consultation_screen.dart';
import 'equipment_screen.dart';
import 'history_screen.dart';

class KioskDashboard extends StatefulWidget {
  final String userName;
  final String userId;
  final bool isGuest;
  final String? guestPhone; 
  final bool isEnglish;
  
  const KioskDashboard({super.key, required this.userName, required this.userId, required this.isGuest, this.guestPhone, required this.isEnglish});

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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Row(
          children: [
            const Icon(Icons.timer, color: Colors.orange, size: 30),
            const SizedBox(width: 10),
            Text(widget.isEnglish ? "Are you still there?" : "Adakah anda masih di sana?", style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(widget.isEnglish ? "You have been idle for a while.\n\nFor your security, you will be automatically logged out in 15 seconds if there is no activity." : "Anda telah melahu sebentar.\n\nUntuk keselamatan anda, anda akan dilog keluar secara automatik dalam 15 saat jika tiada aktiviti.", style: const TextStyle(fontSize: 16)),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF133F85), foregroundColor: Colors.white),
            onPressed: () => _resetIdleTimer(),
            child: Text(widget.isEnglish ? "I'M STILL HERE" : "SAYA MASIH DI SINI", style: const TextStyle(fontWeight: FontWeight.bold)),
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
    Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (c) => const LanguageSelectionPage()), (r) => false);
  }

  Widget _getContent() {
    switch (_currentView) {
      case "SELF_CHECKUP": 
        return SelfCheckupScreen(
          userId: widget.userId, userName: widget.userName, isEnglish: widget.isEnglish,
          onBack: () => setState(() => _currentView = "HOME"),
          onStateChanged: (isActive) { setState(() => _isCheckupActive = isActive); _resetIdleTimer(); }
        );
      case "SEE_DOCTOR_OPT": 
        return ConsultationScreen(
          userId: widget.userId, userName: widget.userName, isGuest: widget.isGuest, isEnglish: widget.isEnglish,
          onBack: () => setState(() => _currentView = "HOME"), onWalkIn: () => setState(() => _currentView = "WALK_IN_TRIAGE"), onLogOut: _autoLogOut
        );
      case "WALK_IN_TRIAGE": 
        return WalkInScreen(
          userId: widget.userId, userName: widget.userName, isGuest: widget.isGuest, guestPhone: widget.guestPhone, isEnglish: widget.isEnglish,
          onBack: () => setState(() => _currentView = "HOME"), onLogOut: _autoLogOut
        );
      case "EQUIP_RES": 
        return EquipmentScreen(
          userId: widget.userId, userName: widget.userName, isEnglish: widget.isEnglish,
          onBack: () => setState(() => _currentView = "HOME"), onLogOut: _autoLogOut
        );
      case "CHECKUP_HIST": 
        return HistoryScreen(userId: widget.userId, isEnglish: widget.isEnglish, historyType: "CHECKUP", onBack: () => setState(() => _currentView = "HOME"));
      case "APPT_HIST": 
        return HistoryScreen(userId: widget.userId, isEnglish: widget.isEnglish, historyType: "APPOINTMENT", onBack: () => setState(() => _currentView = "HOME"));
      case "EQUIP_HIST": 
        return HistoryScreen(userId: widget.userId, isEnglish: widget.isEnglish, historyType: "EQUIPMENT", onBack: () => setState(() => _currentView = "HOME"));
      default: 
        return _buildHome();
    }
  }

  Widget _buildHome() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 20.0),
          child: Column(
            children: [
              Text(widget.isEnglish ? 'WELCOME! SELECT A SERVICE' : 'SELAMAT DATANG! PILIH PERKHIDMATAN', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF133F85))),
              const SizedBox(height: 8),
              Text(widget.isEnglish ? 'PLEASE CHOOSE AN OPTION BELOW TO BEGIN.' : 'SILA PILIH PILIHAN DI BAWAH UNTUK BERMULA.', style: const TextStyle(fontSize: 16, color: Colors.black54)),
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
                        Expanded(flex: 2, child: _buildMenuCard(Icons.medical_services_outlined, widget.isEnglish ? 'SELF-CHECKUP' : 'PEMERIKSAAN\nKENDIRI', () => setState(() => _currentView = "SELF_CHECKUP"))),
                        const SizedBox(width: 30),
                        Expanded(flex: 2, child: _buildMenuCard(Icons.directions_walk, widget.isEnglish ? 'WALK-IN' : 'WALK-IN (TIDAK\nBERJADUAL)', () => setState(() => _currentView = "WALK_IN_TRIAGE"))),
                        const Spacer(flex: 1), 
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Expanded(child: SizedBox()), 
                ],
              )
            : Column(
                children: [
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: _buildMenuCard(Icons.medical_services_outlined, widget.isEnglish ? 'SELF-CHECKUP' : 'PEMERIKSAAN\nKENDIRI', () => setState(() => _currentView = "SELF_CHECKUP"))),
                        const SizedBox(width: 16),
                        Expanded(child: _buildMenuCard(Icons.person_search_outlined, widget.isEnglish ? 'MEDICAL\nCONSULTATION' : 'RUNDINGAN\nPERUBATAN', () => setState(() => _currentView = "SEE_DOCTOR_OPT"))),
                        const SizedBox(width: 16),
                        Expanded(child: _buildMenuCard(Icons.wheelchair_pickup_outlined, widget.isEnglish ? 'MEDICAL EQUIPMENT\nRESERVATION' : 'TEMPAHAN PERALATAN\nPERUBATAN', () => setState(() => _currentView = "EQUIP_RES"))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: _buildMenuCard(Icons.history_outlined, widget.isEnglish ? 'CHECKUP RECORD' : 'REKOD PEMERIKSAAN', () => setState(() => _currentView = "CHECKUP_HIST"))),
                        const SizedBox(width: 16),
                        Expanded(child: _buildMenuCard(Icons.event_available_outlined, widget.isEnglish ? 'APPOINTMENT' : 'TEMU JANJI', () => setState(() => _currentView = "APPT_HIST"))),
                        const SizedBox(width: 16),
                        Expanded(child: _buildMenuCard(Icons.handyman_outlined, widget.isEnglish ? 'RESERVATION\nSTATUS' : 'STATUS\nTEMPAHAN', () => setState(() => _currentView = "EQUIP_HIST"))),
                      ],
                    ),
                  ),
                ],
              ),
        ),
      ],
    );
  }

  Widget _buildMenuCard(IconData icon, String title, VoidCallback onTap) {
    return Card(
      color: const Color(0xFF133F85),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(icon, size: 50, color: const Color(0xFF00C7C7)),
              const SizedBox(height: 12),
              Text(title.toUpperCase(), textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white, height: 1.2)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      height: 70,
      padding: const EdgeInsets.symmetric(horizontal: 25),
      decoration: const BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)]),
      child: Row(
        children: [
          InkWell(
            onTap: () => setState(() => _currentView = "HOME"),
            child: Row(
              children: [
                const Icon(Icons.health_and_safety, color: Color(0xFF133F85), size: 35),
                const SizedBox(width: 15),
                const Text("SMART HEALTH KIOSK", style: TextStyle(color: Color(0xFF133F85), fontWeight: FontWeight.bold, fontSize: 20, letterSpacing: 1.2)),
              ],
            ),
          ),
          const Spacer(),
          Text(widget.userName.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(width: 15),
          const CircleAvatar(radius: 20, backgroundColor: Colors.orange, child: Icon(Icons.person, color: Colors.white, size: 24)),
          const SizedBox(width: 25),
          Container(height: 40, width: 1.5, color: Colors.grey.shade300),
          const SizedBox(width: 25),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade50, foregroundColor: Colors.red.shade800, elevation: 0),
            icon: const Icon(Icons.power_settings_new),
            label: Text(widget.isEnglish ? "LOG OUT" : "LOG KELUAR", style: const TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () => _autoLogOut(), 
          )
        ],
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
        body: Column(
          children: [
            _buildTopBar(),
            Expanded(child: Padding(padding: const EdgeInsets.all(25), child: _getContent())),
            if (!isKeyboardOpen) EmergencyHelpButton(isEnglish: widget.isEnglish, patientName: widget.userName.toUpperCase(), patientId: widget.userId, location: 'Kiosk Main'),
          ],
        ),
      ),
    );
  }
}