import 'package:flutter/material.dart';
import 'dart:async';
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

    _pulseAnim = Tween<double>(begin: 1.0, end: 1.04).animate(
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
    // Clean up the session node if we're leaving without success
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
        MaterialPageRoute(builder: (_) => const LanguageSelectionPage()),
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

        // Show processing dialog
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (_) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              content: Row(
                children: [
                  const CircularProgressIndicator(color: Color(0xFF1B64F2)),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Text(
                      widget.isEnglish
                          ? 'Signing you in...'
                          : 'Sedang log masuk...',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        try {
          // Record the login
          await FirebaseDatabase.instance.ref('login_record').push().set({
            'patient_id': studentId,
            'patient_name': studentName.toUpperCase(),
            'is_guest': false,
            'login_method': 'app_qr',
            'timestamp': ServerValue.timestamp,
            'date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
            'time': DateFormat('hh:mm:ss a').format(DateTime.now()),
          });

          // Clean up the session node
          await FirebaseDatabase.instance.ref('app_logins/$_sessionId').remove();

          if (mounted) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(
                builder: (_) => KioskDashboard(
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
          // Pop the loading dialog
          if (mounted) Navigator.pop(context);
          setState(() => _isProcessing = false);
          debugPrint('AppLoginQrPage: login error: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(
                widget.isEnglish ? 'Login error. Please try again.' : 'Ralat log masuk. Cuba lagi.',
              ),
            ));
          }
        }
      }
    });
  }

  // ── UI helpers ───────────────────────────────────────────────────────────
  Color get _timerColor {
    if (_timeLeft > 60) return const Color(0xFF1B64F2);
    if (_timeLeft > 30) return Colors.orange;
    return Colors.red;
  }

  String get _qrData =>
      'unimaphealth://auth?kioskId=$_kioskId&sessionId=$_sessionId';

  // ── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F9FF),
      body: Stack(
        children: [
          // ── Background gradient accent ──────────────────────────────────
          Positioned(
            top: -120,
            right: -120,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF1B64F2).withOpacity(0.06),
              ),
            ),
          ),
          Positioned(
            bottom: -80,
            left: -80,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF133F85).withOpacity(0.05),
              ),
            ),
          ),

          // ── Back button ─────────────────────────────────────────────────
          Positioned(
            top: 20,
            left: 20,
            child: TextButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back, size: 26, color: Color(0xFF133F85)),
              label: Text(
                widget.isEnglish ? 'Back' : 'Kembali',
                style: const TextStyle(fontSize: 17, color: Color(0xFF133F85)),
              ),
            ),
          ),

          // ── Main content ─────────────────────────────────────────────────
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 60),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Title
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.smartphone_rounded,
                          color: Color(0xFF1B64F2), size: 36),
                      const SizedBox(width: 12),
                      Text(
                        widget.isEnglish
                            ? 'Login via UniMAP Health App'
                            : 'Log Masuk via Aplikasi UniMAP Health',
                        style: const TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF133F85),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  Text(
                    widget.isEnglish
                        ? 'Open the UniMAP Health app and scan this QR code to log in.'
                        : 'Buka aplikasi UniMAP Health dan imbas kod QR ini untuk log masuk.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 17, color: Colors.blueGrey),
                  ),

                  const SizedBox(height: 28),

                  // ── Countdown pill ────────────────────────────────────
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: _timerColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: _timerColor.withOpacity(0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.timer_outlined, color: _timerColor, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          widget.isEnglish
                              ? 'Expires in: $_timeLeft seconds'
                              : 'Tamat dalam: $_timeLeft saat',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: _timerColor,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),

                  // ── QR Code card ──────────────────────────────────────
                  ScaleTransition(
                    scale: _pulseAnim,
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF1B64F2).withOpacity(0.15),
                            blurRadius: 30,
                            offset: const Offset(0, 10),
                          ),
                          const BoxShadow(
                            color: Colors.black12,
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // QR code
                          QrImageView(
                            data: _qrData,
                            version: QrVersions.auto,
                            size: 260.0,
                            backgroundColor: Colors.white,
                          ),
                          const SizedBox(height: 14),
                          // Session ID label
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF4F9FF),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _sessionId,
                              style: const TextStyle(
                                fontSize: 11,
                                letterSpacing: 1.2,
                                color: Colors.blueGrey,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // ── Instructions ──────────────────────────────────────
                  _InstructionRow(
                    step: '1',
                    text: widget.isEnglish
                        ? 'Open the UniMAP Health App on your phone.'
                        : 'Buka Aplikasi UniMAP Health di telefon anda.',
                    color: const Color(0xFF1B64F2),
                  ),
                  const SizedBox(height: 10),
                  _InstructionRow(
                    step: '2',
                    text: widget.isEnglish
                        ? 'Tap "Kiosk Login" and point your camera at the QR code.'
                        : 'Ketik "Log Masuk Kiosk" dan arahkan kamera ke kod QR.',
                    color: const Color(0xFF1B64F2),
                  ),
                  const SizedBox(height: 10),
                  _InstructionRow(
                    step: '3',
                    text: widget.isEnglish
                        ? 'Confirm the login on your phone to proceed.'
                        : 'Sahkan log masuk di telefon anda untuk meneruskan.',
                    color: const Color(0xFF1B64F2),
                  ),

                  const SizedBox(height: 36),

                  // ── Cancel button ──────────────────────────────────────
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF133F85),
                      side: const BorderSide(color: Color(0xFF133F85), width: 1.5),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32, vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30)),
                    ),
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.cancel_outlined),
                    label: Text(
                      widget.isEnglish ? 'CANCEL' : 'BATAL',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
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
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Numbered instruction row
// ────────────────────────────────────────────────────────────────────────────
class _InstructionRow extends StatelessWidget {
  final String step;
  final String text;
  final Color color;

  const _InstructionRow({
    required this.step,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          alignment: Alignment.center,
          child: Text(
            step,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 340,
          child: Text(
            text,
            style: const TextStyle(fontSize: 15, color: Colors.black87, height: 1.4),
          ),
        ),
      ],
    );
  }
}
