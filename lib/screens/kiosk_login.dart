import '../utils/no_anim_route.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:ui';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'kiosk_dashboard.dart';
import '../utils/hardware_monitor.dart';

class KioskLoginPage extends StatefulWidget {
  final bool isEnglish;
  final String kioskId;
  const KioskLoginPage({
    super.key,
    required this.isEnglish,
    this.kioskId = 'KIOSK_01',
  });
  @override
  State<KioskLoginPage> createState() => _KioskLoginPageState();
}

class _KioskLoginPageState extends State<KioskLoginPage>
    with SingleTickerProviderStateMixin {
  bool _isLoading = false;
  bool _isHardwareOnline = false;
  String _statusMessage = "";
  StreamSubscription<DatabaseEvent>? _rfidSubscription;
  StreamSubscription? _hardwareSub;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();

    // ── Seed hardware status synchronously ───────────────────────────────────
    _isHardwareOnline = HardwareMonitor().isOnline;
    _updateStatusMessage();

    // ── Subscribe to hardware state changes ──────────────────────────────────
    _hardwareSub = HardwareMonitor().onlineStream.listen((isOnline) {
      if (!mounted) return;
      setState(() {
        _isHardwareOnline = isOnline;
        if (!isOnline && !_isLoading) _updateStatusMessage();
      });

      // If hardware just came back online and we are not loading, re-init the
      // RFID listener in case it was never started or was paused.
      if (isOnline && _rfidSubscription == null) {
        _initializeHardwareScanner();
      }
    });

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnim = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // ── Only start the RFID listener when hardware is already online ─────────
    if (_isHardwareOnline) {
      _initializeHardwareScanner();
    }
  }

  @override
  void dispose() {
    _rfidSubscription?.cancel();
    _hardwareSub?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  void _updateStatusMessage() {
    if (_isHardwareOnline) {
      _statusMessage = widget.isEnglish
          ? "Please tap your card"
          : "Sila sentuh kad anda";
    } else {
      _statusMessage = widget.isEnglish
          ? "Card Reader Offline"
          : "Pembaca Kad Tidak Aktif";
    }
  }

  Future<void> _initializeHardwareScanner() async {
    // Clear any stale RFID value so a previous scan isn't re-processed.
    await FirebaseDatabase.instance
        .ref('kiosk/${widget.kioskId}/scanned_rfid')
        .set("");

    _rfidSubscription = FirebaseDatabase.instance
        .ref('kiosk/${widget.kioskId}/scanned_rfid')
        .onValue
        .listen((event) async {
          // Guard: do not process scan if hardware is now offline or we're busy.
          if (!_isHardwareOnline) return;

          if (event.snapshot.exists && event.snapshot.value != null) {
            String scannedUid = event.snapshot.value.toString();

            if (scannedUid.isNotEmpty && !_isLoading) {
              setState(() {
                _isLoading = true;
                _statusMessage = widget.isEnglish
                    ? "Verifying ID..."
                    : "Mengesahkan ID...";
              });

              await _handleLogin(scannedUid);
            }
          }
        });
  }

  Future<void> _handleLogin(String nfcId) async {
    try {
      var nfcEvent = await FirebaseDatabase.instance
          .ref('NFC')
          .child(nfcId)
          .once();

      if (nfcEvent.snapshot.exists) {
        var studentId = nfcEvent.snapshot.value.toString();
        var studentEvent = await FirebaseDatabase.instance
            .ref('students')
            .child(studentId)
            .once();

        if (studentEvent.snapshot.exists) {
          var data = studentEvent.snapshot.value as Map<dynamic, dynamic>;

          try {
            await FirebaseDatabase.instance.ref('login_record').push().set({
              'patient_id': studentId,
              'patient_name':
                  data['name'] ?? (widget.isEnglish ? "STUDENT" : "PELAJAR"),
              'is_guest': false,
              'timestamp': ServerValue.timestamp,
              'date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
              'time': DateFormat('hh:mm:ss a').format(DateTime.now()),
            });
          } catch (e) {
            debugPrint("Failed to record student login: $e");
          }

          await FirebaseDatabase.instance
              .ref('kiosk/${widget.kioskId}/scanned_rfid')
              .set("");
          if (!mounted) return;

          Navigator.pushAndRemoveUntil(
            context,
            NoAnimRoute(
              page: KioskDashboard(
                userName:
                    data['name'] ?? (widget.isEnglish ? "STUDENT" : "PELAJAR"),
                userId: studentId,
                isGuest: false,
                isEnglish: widget.isEnglish,
                kioskId: widget.kioskId,
              ),
            ),
            (r) => false,
          );
        } else {
          setState(() {
            _statusMessage = widget.isEnglish
                ? "Student data not found for:\n$studentId"
                : "Data pelajar tidak ditemui untuk:\n$studentId";
          });
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Colors.redAccent,
              content: Text(
                widget.isEnglish
                    ? "Student data missing."
                    : "Data pelajar hilang.",
                style: const TextStyle(color: Colors.white),
              ),
            ),
          );
          await _resetScanner();
        }
      } else {
        setState(() {
          _statusMessage = widget.isEnglish
              ? "Unregistered Card ID:\n$nfcId"
              : "ID Kad Tidak Berdaftar:\n$nfcId";
        });
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.amber,
            content: Text(
              widget.isEnglish ? "Card not recognized." : "Kad tidak dikenali.",
              style: const TextStyle(color: Colors.black87),
            ),
          ),
        );
        await _resetScanner();
      }
    } catch (e) {
      setState(() {
        _statusMessage =
            widget.isEnglish ? "Login Error" : "Ralat Log Masuk";
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text(
            widget.isEnglish ? "Login Error: $e" : "Ralat Log Masuk: $e",
            style: const TextStyle(color: Colors.white),
          ),
        ),
      );
      await _resetScanner();
    }
  }

  Future<void> _resetScanner() async {
    await Future.delayed(const Duration(seconds: 2));
    await FirebaseDatabase.instance
        .ref('kiosk/${widget.kioskId}/scanned_rfid')
        .set("");
    if (mounted) {
      setState(() {
        _isLoading = false;
        _updateStatusMessage();
      });
    }
  }

  // ── Build helpers ──────────────────────────────────────────────────────────

  /// The card icon area — shows a pulsing contactless icon when ready,
  /// a spinner while loading, or an offline icon when the reader is down.
  Widget _buildIconArea() {
    if (_isLoading) {
      return Container(
        padding: const EdgeInsets.all(30),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.05),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.2),
            width: 2,
          ),
        ),
        child: const Icon(
          Icons.contactless_rounded,
          size: 100,
          color: Colors.white54,
        ),
      );
    }

    if (!_isHardwareOnline) {
      return Container(
        padding: const EdgeInsets.all(30),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.orange.withValues(alpha: 0.08),
          border: Border.all(
            color: Colors.orangeAccent.withValues(alpha: 0.5),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.orangeAccent.withValues(alpha: 0.15),
              blurRadius: 30,
              spreadRadius: 10,
            ),
          ],
        ),
        child: const Icon(
          Icons.sensors_off_rounded,
          size: 100,
          color: Colors.orangeAccent,
        ),
      );
    }

    // Default: pulsing contactless icon
    return ScaleTransition(
      scale: _pulseAnim,
      child: Container(
        padding: const EdgeInsets.all(30),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.lightBlueAccent.withValues(alpha: 0.1),
          border: Border.all(
            color: Colors.lightBlueAccent.withValues(alpha: 0.5),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.lightBlueAccent.withValues(alpha: 0.3),
              blurRadius: 30,
              spreadRadius: 10,
            ),
          ],
        ),
        child: const Icon(
          Icons.contactless_rounded,
          size: 100,
          color: Colors.lightBlueAccent,
        ),
      ),
    );
  }

  /// Status row below the icon — spinner when loading, text otherwise.
  Widget _buildStatusRow() {
    if (_isLoading) {
      return const SizedBox(
        width: 48,
        height: 48,
        child: CircularProgressIndicator(
          color: Colors.lightBlueAccent,
          strokeWidth: 3,
        ),
      );
    }

    return Text(
      _statusMessage,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.bold,
        color: _isHardwareOnline
            ? Colors.lightBlueAccent
            : Colors.orangeAccent,
      ),
    );
  }

  /// Instructional subtitle — changes when hardware is offline.
  String get _subtitleText {
    if (!_isHardwareOnline) {
      return widget.isEnglish
          ? 'The card reader is offline. Please go back and use the Mobile App QR login instead.'
          : 'Pembaca kad tidak aktif. Sila kembali dan gunakan log masuk QR Aplikasi Mudah Alih.';
    }
    return widget.isEnglish
        ? 'Please tap your Student Card on the physical scanner'
        : 'Sila sentuh Kad Pelajar anda pada pengimbas fizikal';
  }

  @override
  Widget build(BuildContext context) {
    // Determine border/glow colour based on current hardware state.
    final borderColor = _isHardwareOnline
        ? Colors.lightBlueAccent.withValues(alpha: 0.3)
        : Colors.orangeAccent.withValues(alpha: 0.3);
    final glowColor = _isHardwareOnline
        ? Colors.lightBlueAccent.withValues(alpha: 0.1)
        : Colors.orangeAccent.withValues(alpha: 0.08);

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
                onPressed: () => Navigator.pop(context),
                icon: const Icon(
                  Icons.arrow_back,
                  size: 26,
                  color: Colors.lightBlueAccent,
                ),
                label: Text(
                  widget.isEnglish ? 'Back' : 'Kembali',
                  style: const TextStyle(
                    fontSize: 17,
                    color: Colors.lightBlueAccent,
                  ),
                ),
              ),
            ),
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeInOut,
                    width: 500,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 40,
                      vertical: 50,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: borderColor, width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: glowColor,
                          blurRadius: 40,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.isEnglish
                              ? "STUDENT RFID LOGIN"
                              : "LOG MASUK RFID PELAJAR",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 24,
                            shadows: [
                              Shadow(
                                color: Colors.lightBlueAccent
                                    .withValues(alpha: 0.5),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 30),

                        // ── Icon area (changes based on state) ──────────────
                        _buildIconArea(),

                        const SizedBox(height: 40),

                        // ── Status text / spinner ───────────────────────────
                        _buildStatusRow(),

                        const SizedBox(height: 25),

                        // ── Instructional subtitle ──────────────────────────
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: Text(
                            _subtitleText,
                            key: ValueKey<bool>(_isHardwareOnline),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.white70,
                            ),
                          ),
                        ),

                        // ── Offline action hint ─────────────────────────────
                        if (!_isHardwareOnline && !_isLoading) ...[
                          const SizedBox(height: 20),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.orangeAccent,
                              side: BorderSide(
                                color: Colors.orangeAccent.withValues(alpha: 0.6),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 12,
                              ),
                            ),
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.arrow_back, size: 20),
                            label: Text(
                              widget.isEnglish
                                  ? 'Go Back to Login Options'
                                  : 'Kembali ke Pilihan Log Masuk',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
