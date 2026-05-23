import '../utils/no_anim_route.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:ui';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:firebase_database/firebase_database.dart';
import '../widgets/emergency_button.dart';
import 'language_selection.dart';
import 'kiosk_dashboard.dart';

class GuestQrPage extends StatefulWidget {
  final bool isEnglish;
  const GuestQrPage({super.key, required this.isEnglish});

  @override
  State<GuestQrPage> createState() => _GuestQrPageState();
}

class _GuestQrPageState extends State<GuestQrPage>
    with SingleTickerProviderStateMixin {
  StreamSubscription<DatabaseEvent>? _subscription;
  static const String kioskId = 'KIOSK_01';
  bool _isProcessing = false;
  late String _sessionId;
  Timer? _timeoutTimer;
  int _timeLeft = 120; // 2 minutes timeout

  // Pulse animation for the QR container
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _sessionId = "SESS_${DateTime.now().millisecondsSinceEpoch}";

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _pulseAnim = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _initializeSession();
    _startListening();
    _startTimer();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _timeoutTimer?.cancel();
    _pulseController.dispose();
    if (!_isProcessing) {
      FirebaseDatabase.instance.ref('pending_registrations/$kioskId').remove();
    }
    super.dispose();
  }

  Future<void> _initializeSession() async {
    await FirebaseDatabase.instance.ref('pending_registrations/$kioskId').set({
      'session': _sessionId,
      'status': 'waiting',
      'timestamp': ServerValue.timestamp,
    });
  }

  void _startTimer() {
    _timeoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        if (_timeLeft > 0) {
          setState(() => _timeLeft--);
        } else {
          timer.cancel();
          if (!_isProcessing) {
            _handleTimeout();
          }
        }
      }
    });
  }

  void _handleTimeout() async {
    await FirebaseDatabase.instance
        .ref('pending_registrations/$kioskId')
        .remove();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        NoAnimRoute(page: const LanguageSelectionPage()),
        (route) => false,
      );
    }
  }

  void _startListening() {
    _subscription = FirebaseDatabase.instance
        .ref('pending_registrations/$kioskId')
        .onValue
        .listen((event) async {
          if (_isProcessing) return;

          if (event.snapshot.exists && event.snapshot.value != null) {
            var data = Map<String, dynamic>.from(event.snapshot.value as Map);

            if (data['session'] == _sessionId &&
                data['status'] == 'completed') {
              setState(() => _isProcessing = true);
              _timeoutTimer?.cancel();

              if (mounted) {
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (c) => AlertDialog(
                    backgroundColor: const Color(0xFF133F85),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: Colors.lightBlueAccent),
                    ),
                    content: Row(
                      children: [
                        const CircularProgressIndicator(
                          color: Colors.lightBlueAccent,
                        ),
                        const SizedBox(width: 20),
                        Text(
                          widget.isEnglish
                              ? "Processing login..."
                              : "Memproses log masuk...",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              try {
                String name = data['name']?.toString() ?? 'Guest';
                String phone = data['phone']?.toString() ?? 'N/A';
                String gender = data['gender']?.toString() ?? 'Unknown';
                String uniqueGuestId =
                    "GUEST_${DateTime.now().millisecondsSinceEpoch}";

                await FirebaseDatabase.instance
                    .ref('pending_registrations/$kioskId')
                    .remove();

                await FirebaseDatabase.instance.ref('login_record').push().set({
                  'patient_id': uniqueGuestId,
                  'patient_name': name.toUpperCase(),
                  'phone': phone,
                  'gender': gender,
                  'is_guest': true,
                  'timestamp': ServerValue.timestamp,
                  'date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
                  'time': DateFormat('hh:mm:ss a').format(DateTime.now()),
                });

                if (mounted) {
                  Navigator.pushAndRemoveUntil(
                    context,
                    NoAnimRoute(
                      page: KioskDashboard(
                        userName: name.toUpperCase(),
                        userId: uniqueGuestId,
                        isGuest: true,
                        isEnglish: widget.isEnglish,
                        guestPhone: phone,
                      ),
                    ),
                    (r) => false,
                  );
                }
              } catch (e) {
                if (mounted) Navigator.pop(context);
                setState(() => _isProcessing = false);
                debugPrint("Error processing guest login: $e");
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: Colors.redAccent,
                      content: Text(
                        widget.isEnglish
                            ? "An error occurred."
                            : "Berlaku ralat.",
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  );
                }
              }
            }
          }
        });
  }

  Color get _timerColor {
    if (_timeLeft > 60) return Colors.lightBlueAccent;
    if (_timeLeft > 30) return Colors.amber;
    return Colors.redAccent;
  }

  @override
  Widget build(BuildContext context) {
    const String webAppUrl = 'https://smart-health-kiosk-193a5.web.app';
    final String qrData =
        '$webAppUrl/#/checkin?kioskId=$kioskId&session=$_sessionId';

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
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 40,
                  vertical: 20,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Left Column: Timer & QR Code
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
                                value: _timeLeft / 120.0,
                                strokeWidth: 6,
                                color: _timerColor,
                                backgroundColor: Colors.white.withValues(
                                  alpha: 0.1,
                                ),
                              ),
                            ),
                            Text(
                              '$_timeLeft',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: _timerColor,
                                shadows: [
                                  Shadow(
                                    color: _timerColor.withValues(alpha: 0.8),
                                    blurRadius: 8,
                                  ),
                                ],
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
                                  color: Colors.white.withValues(alpha: 0.04),
                                  borderRadius: BorderRadius.circular(30),
                                  border: Border.all(
                                    color: Colors.lightBlueAccent.withValues(
                                      alpha: 0.5,
                                    ),
                                    width: 2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.lightBlueAccent.withValues(
                                        alpha: 0.2,
                                      ),
                                      blurRadius: 30,
                                      spreadRadius: 5,
                                    ),
                                  ],
                                ),
                                child: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: QrImageView(
                                    data: qrData,
                                    version: QrVersions.auto,
                                    size: 220.0,
                                    backgroundColor: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Right Column: Title, Instructions, Cancel Button
                    SizedBox(
                      width: 450,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.isEnglish
                                ? "Guest Check-in"
                                : "Daftar Masuk Tetamu",
                            style: TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
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
                          const SizedBox(height: 20),
                          Text(
                            widget.isEnglish
                                ? "Scan the QR code with your phone to register. Complete the registration form on your device."
                                : "Imbas kod QR dengan telefon anda untuk mendaftar. Lengkapkan borang pendaftaran di peranti anda.",
                            style: const TextStyle(
                              fontSize: 18,
                              color: Colors.white70,
                              height: 1.4,
                            ),
                          ),

                          const SizedBox(height: 50),

                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.lightBlueAccent,
                              side: BorderSide(
                                color: Colors.lightBlueAccent.withValues(alpha: 0.5),
                                width: 1.5,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 40,
                                vertical: 16,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                              backgroundColor: Colors.lightBlueAccent.withValues(
                                alpha: 0.1,
                              ),
                            ),
                            onPressed: () {
                              Navigator.pop(context);
                            },
                            icon: const Icon(Icons.cancel_outlined),
                            label: Text(
                              widget.isEnglish ? "CANCEL" : "BATAL",
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
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
