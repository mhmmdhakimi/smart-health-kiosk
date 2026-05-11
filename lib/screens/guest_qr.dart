import 'package:flutter/material.dart';
import 'dart:async';
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

class _GuestQrPageState extends State<GuestQrPage> {
  StreamSubscription<DatabaseEvent>? _subscription;
  static const String kioskId = 'KIOSK_01';
  bool _isProcessing = false;
  late String _sessionId;
  Timer? _timeoutTimer;
  int _timeLeft = 120; // 2 minutes timeout

  @override
  void initState() {
    super.initState();
    _sessionId = "SESS_${DateTime.now().millisecondsSinceEpoch}";
    _initializeSession();
    _startListening();
    _startTimer();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _timeoutTimer?.cancel();
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
    await FirebaseDatabase.instance.ref('pending_registrations/$kioskId').remove();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (c) => const LanguageSelectionPage()),
        (route) => false,
      );
    }
  }


  void _startListening() {
    _subscription = FirebaseDatabase.instance.ref('pending_registrations/$kioskId').onValue.listen((event) async {
      if (_isProcessing) return;

      if (event.snapshot.exists && event.snapshot.value != null) {
        var data = Map<String, dynamic>.from(event.snapshot.value as Map);
        
        if (data['session'] == _sessionId && data['status'] == 'completed') {
          setState(() => _isProcessing = true);
          _timeoutTimer?.cancel();
          
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (c) => AlertDialog(
              content: Row(
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(width: 20),
                  Text(widget.isEnglish ? "Processing login..." : "Memproses log masuk..."),
                ],
              ),
            ),
          );

          try {
            String name = data['name']?.toString() ?? 'Guest';
            String phone = data['phone']?.toString() ?? 'N/A';
            String gender = data['gender']?.toString() ?? 'Unknown';
            String uniqueGuestId = "GUEST_${DateTime.now().millisecondsSinceEpoch}";

            await FirebaseDatabase.instance.ref('pending_registrations/$kioskId').remove();

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
                MaterialPageRoute(builder: (c) => KioskDashboard(
                  userName: name.toUpperCase(),
                  userId: uniqueGuestId,
                  isGuest: true,
                  isEnglish: widget.isEnglish,
                  guestPhone: phone,
                )),
                (r) => false
              );
            }
          } catch (e) {
            if (mounted) Navigator.pop(context);
            setState(() => _isProcessing = false);
            debugPrint("Error processing guest login: $e");
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(widget.isEnglish ? "An error occurred." : "Berlaku ralat.")));
            }
          }
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    const String webAppUrl = 'https://smart-health-kiosk-193a5.web.app';
    final String qrData = '$webAppUrl/#/checkin?kioskId=$kioskId&session=$_sessionId';

    return Scaffold(
      backgroundColor: const Color(0xFFF4F9FF),
      body: Stack(
        children: [
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  widget.isEnglish ? "Guest Check-in" : "Daftar Masuk Tetamu",
                  style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF133F85)),
                ),
                const SizedBox(height: 20),
                Text(
                  widget.isEnglish
                      ? "Scan the QR code with your phone to register."
                      : "Imbas kod QR dengan telefon anda untuk mendaftar.",
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 18, color: Colors.blueGrey),
                ),
                const SizedBox(height: 15),
                Text(
                  widget.isEnglish
                      ? "QR Code expires in: $_timeLeft seconds"
                      : "Kod QR tamat tempoh dalam: $_timeLeft saat",
                  style: const TextStyle(fontSize: 16, color: Colors.red, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 25),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 5))]),
                  child: QrImageView(data: qrData, version: QrVersions.auto, size: 280.0),
                ),
                const SizedBox(height: 40),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15)),
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.cancel_outlined),
                  label: Text(widget.isEnglish ? "CANCEL" : "BATAL", style: const TextStyle(fontSize: 16)),
                ),
              ],
            ),
          ),
          Align(alignment: Alignment.bottomCenter, child: EmergencyHelpButton(isEnglish: widget.isEnglish)),
        ],
      ),
    );
  }
}