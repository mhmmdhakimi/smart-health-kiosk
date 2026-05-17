import '../utils/no_anim_route.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:ui';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../widgets/emergency_button.dart';
import 'language_selection.dart';
import 'kiosk_dashboard.dart';

class AppLoginQrPage extends StatefulWidget {
  final bool isEnglish;
  const AppLoginQrPage({super.key, required this.isEnglish});

  @override
  State<AppLoginQrPage> createState() => _AppLoginQrPageState();
}

class _AppLoginQrPageState extends State<AppLoginQrPage>
    with SingleTickerProviderStateMixin {
  // ── Constants ────────────────────────────────────────────────────────────
  static const String _kioskId = 'KIOSK_01';
  static const int _timeoutSeconds = 90;

  // ── State ────────────────────────────────────────────────────────────────
  late final String _sessionId;
  bool _isProcessing = false;
  int _timeLeft = _timeoutSeconds;

  Timer? _countdownTimer;
  StreamSubscription<DatabaseEvent>? _firebaseSubscription;

  // Pulse animation for the QR container
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  // ── Lifecycle ────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _sessionId = 'APP_SESS_${DateTime.now().millisecondsSinceEpoch}';

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _pulseAnim = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _startCountdown();
    _listenForAppLogin();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _firebaseSubscription?.cancel();
    _pulseController.dispose();
    if (!_isProcessing) {
      FirebaseDatabase.instance.ref('app_logins/$_sessionId').remove();
    }
    super.dispose();
  }

  // ── Timer ────────────────────────────────────────────────────────────────
  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_timeLeft > 0) {
        setState(() => _timeLeft--);
      } else {
        timer.cancel();
        if (!_isProcessing) _handleTimeout();
      }
    });
  }

  Future<void> _handleTimeout() async {
    await FirebaseDatabase.instance.ref('app_logins/$_sessionId').remove();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        NoAnimRoute(page: const LanguageSelectionPage()),
        (_) => false,
      );
    }
  }

  // ── Firebase listener ────────────────────────────────────────────────────
  void _listenForAppLogin() {
    _firebaseSubscription = FirebaseDatabase.instance
        .ref('app_logins/$_sessionId')
        .onValue
        .listen((event) async {
      if (_isProcessing || !event.snapshot.exists || event.snapshot.value == null) return;

      final raw = event.snapshot.value;
      if (raw is! Map) return;

      final data = Map<String, dynamic>.from(raw);

      if (data['status'] == 'success') {
        setState(() => _isProcessing = true);
        _countdownTimer?.cancel();

        final studentId = data['studentId']?.toString() ?? 'STUDENT';
        final studentName = data['studentName']?.toString() ?? 'STUDENT';

        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (_) => AlertDialog(
              backgroundColor: const Color(0xFF111827),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: Colors.cyan)),
              content: Row(
                children: [
                  const CircularProgressIndicator(color: Colors.cyanAccent),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Text(
                      widget.isEnglish
                          ? 'Signing you in...'
                          : 'Sedang log masuk...',
                      style: const TextStyle(fontSize: 16, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        try {
          await FirebaseDatabase.instance.ref('login_record').push().set({
            'patient_id': studentId,
            'patient_name': studentName.toUpperCase(),
            'is_guest': false,
            'login_method': 'app_qr',
            'timestamp': ServerValue.timestamp,
            'date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
            'time': DateFormat('hh:mm:ss a').format(DateTime.now()),
          });

          await FirebaseDatabase.instance.ref('app_logins/$_sessionId').remove();

          if (mounted) {
            Navigator.pushAndRemoveUntil(
              context,
              NoAnimRoute(page: KioskDashboard(
                  userName: studentName.toUpperCase(),
                  userId: studentId,
                  isGuest: false,
                  isEnglish: widget.isEnglish,
                ),
              ),
              (_) => false,
            );
          }
        } catch (e) {
          if (mounted) Navigator.pop(context);
          setState(() => _isProcessing = false);
          debugPrint('AppLoginQrPage: login error: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              backgroundColor: Colors.redAccent,
              content: Text(
                widget.isEnglish ? 'Login error. Please try again.' : 'Ralat log masuk. Cuba lagi.',
                style: const TextStyle(color: Colors.white),
              ),
            ));
          }
        }
      }
    });
  }

  // ── UI helpers ───────────────────────────────────────────────────────────
  Color get _timerColor {
    if (_timeLeft > 60) return Colors.cyanAccent;
    if (_timeLeft > 30) return Colors.amberAccent;
    return Colors.redAccent;
  }

  String get _qrData =>
      'unimaphealth://auth?kioskId=$_kioskId&sessionId=$_sessionId';

  // ── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0B0F19), Color(0xFF111827)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          )
        ),
        child: Stack(
          children: [
            // ── Main content ─────────────────────────────────────────────────
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Left Column: Timer & QR
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // ── Countdown Circular Progress ────────────────────────────────────
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              width: 70,
                              height: 70,
                              child: CircularProgressIndicator(
                                value: _timeLeft / _timeoutSeconds,
                                strokeWidth: 6,
                                color: _timerColor,
                                backgroundColor: Colors.white.withOpacity(0.1),
                              ),
                            ),
                            Text(
                              '$_timeLeft',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: _timerColor,
                                shadows: [Shadow(color: _timerColor.withOpacity(0.8), blurRadius: 8)],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),

                        // ── QR Code Scanner Frame ──────────────────────────────────────
                        ScaleTransition(
                          scale: _pulseAnim,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(30),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                              child: Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.04),
                                  borderRadius: BorderRadius.circular(30),
                                  border: Border.all(color: Colors.cyanAccent.withOpacity(0.5), width: 2),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.cyanAccent.withOpacity(0.2),
                                      blurRadius: 30,
                                      spreadRadius: 5,
                                    ),
                                  ],
                                ),
                                child: Column(
                                  children: [
                                    // Pure white container for QR so it is scannable
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: QrImageView(
                                        data: _qrData,
                                        version: QrVersions.auto,
                                        size: 200.0,
                                        backgroundColor: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 15),
                                    // Session ID label
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 14, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: Colors.white.withOpacity(0.2)),
                                      ),
                                      child: Text(
                                        _sessionId,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          letterSpacing: 1.5,
                                          color: Colors.white70,
                                          fontFamily: 'monospace',
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Right Column: Instructions & Cancel
                    SizedBox(
                      width: 450,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.smartphone_rounded,
                                  color: Colors.cyanAccent, size: 36),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  widget.isEnglish
                                      ? 'Login via UniMAP Health App'
                                      : 'Log Masuk via Aplikasi UniMAP Health',
                                  style: TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    shadows: [Shadow(color: Colors.cyanAccent.withOpacity(0.5), blurRadius: 10)],
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 15),

                          Text(
                            widget.isEnglish
                                ? 'Open the UniMAP Health app and scan the QR code to log in.'
                                : 'Buka aplikasi UniMAP Health dan imbas kod QR ini untuk log masuk.',
                            style: const TextStyle(fontSize: 16, color: Colors.white70),
                          ),

                          const SizedBox(height: 30),

                          // ── Instructions ──────────────────────────────────────
                          _InstructionRow(
                            step: '1',
                            text: widget.isEnglish
                                ? 'Open the UniMAP Health App on your phone.'
                                : 'Buka Aplikasi UniMAP Health di telefon anda.',
                          ),
                          const SizedBox(height: 15),
                          _InstructionRow(
                            step: '2',
                            text: widget.isEnglish
                                ? 'Tap "Kiosk Login" and point your camera at the QR code.'
                                : 'Ketik "Log Masuk Kiosk" dan arahkan kamera ke kod QR.',
                          ),
                          const SizedBox(height: 15),
                          _InstructionRow(
                            step: '3',
                            text: widget.isEnglish
                                ? 'Confirm the login on your phone to proceed.'
                                : 'Sahkan log masuk di telefon anda untuk meneruskan.',
                          ),

                          const SizedBox(height: 40),

                          // ── Cancel button ──────────────────────────────────────
                          Center(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.cyanAccent,
                                side: BorderSide(color: Colors.cyanAccent.withOpacity(0.5), width: 1.5),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 40, vertical: 16),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30)),
                                backgroundColor: Colors.cyanAccent.withOpacity(0.1),
                              ),
                              onPressed: () {
                                Navigator.pop(context);
                              },
                              icon: const Icon(Icons.cancel_outlined),
                              label: Text(
                                widget.isEnglish ? 'CANCEL' : 'BATAL',
                                style: const TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Emergency button ─────────────────────────────────────────────
            Align(
              alignment: Alignment.bottomCenter,
              child: EmergencyHelpButton(isEnglish: widget.isEnglish),
            ),
          ],
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Numbered instruction row
// ────────────────────────────────────────────────────────────────────────────
class _InstructionRow extends StatelessWidget {
  final String step;
  final String text;

  const _InstructionRow({
    required this.step,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: Colors.cyanAccent.withOpacity(0.2), 
            shape: BoxShape.circle,
            border: Border.all(color: Colors.cyanAccent.withOpacity(0.5)),
          ),
          alignment: Alignment.center,
          child: Text(
            step,
            style: const TextStyle(
              color: Colors.cyanAccent,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
        const SizedBox(width: 15),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 16, color: Colors.white, height: 1.4),
          ),
        ),
      ],
    );
  }
}
