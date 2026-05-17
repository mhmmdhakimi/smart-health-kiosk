import '../utils/no_anim_route.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:ui';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import '../widgets/emergency_button.dart';
import 'kiosk_dashboard.dart';

class KioskLoginPage extends StatefulWidget {
  final bool isEnglish;
  final String kioskId;
  const KioskLoginPage({super.key, required this.isEnglish, this.kioskId = 'KIOSK_01'});
  @override
  State<KioskLoginPage> createState() => _KioskLoginPageState();
}

class _KioskLoginPageState extends State<KioskLoginPage> with SingleTickerProviderStateMixin {
  bool _isLoading = false;
  String _statusMessage = "";
  StreamSubscription<DatabaseEvent>? _rfidSubscription;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _statusMessage = widget.isEnglish ? "Please tap your card" : "Sila sentuh kad anda";
    
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnim = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _initializeHardwareScanner();
  }

  @override
  void dispose() {
    _rfidSubscription?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _initializeHardwareScanner() async {
    await FirebaseDatabase.instance.ref('kiosk/${widget.kioskId}/scanned_rfid').set("");
    
    _rfidSubscription = FirebaseDatabase.instance.ref('kiosk/${widget.kioskId}/scanned_rfid').onValue.listen((event) async {
      if (event.snapshot.exists && event.snapshot.value != null) {
        String scannedUid = event.snapshot.value.toString();
        
        if (scannedUid.isNotEmpty && !_isLoading) {
          setState(() {
            _isLoading = true;
            _statusMessage = widget.isEnglish ? "Verifying ID..." : "Mengesahkan ID...";
          });
          
          await _handleLogin(scannedUid);
        }
      }
    });
  }

  Future<void> _handleLogin(String nfcId) async {
    try {
      var nfcEvent = await FirebaseDatabase.instance.ref('NFC').child(nfcId).once();
          
      if (nfcEvent.snapshot.exists) {
        var studentId = nfcEvent.snapshot.value.toString();
        var studentEvent = await FirebaseDatabase.instance.ref('students').child(studentId).once();
        
        if (studentEvent.snapshot.exists) {
          var data = studentEvent.snapshot.value as Map<dynamic, dynamic>;
        
          try {
            await FirebaseDatabase.instance.ref('login_record').push().set({
              'patient_id': studentId,
              'patient_name': data['name'] ?? (widget.isEnglish ? "STUDENT" : "PELAJAR"),
              'is_guest': false,
              'timestamp': ServerValue.timestamp,
              'date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
              'time': DateFormat('hh:mm:ss a').format(DateTime.now()),
            });
          } catch (e) {
            debugPrint("Failed to record student login: $e");
          }

          await FirebaseDatabase.instance.ref('kiosk/${widget.kioskId}/scanned_rfid').set("");
          if (!mounted) return;
          
          Navigator.pushAndRemoveUntil(
            context, 
            NoAnimRoute(page: KioskDashboard(
              userName: data['name'] ?? (widget.isEnglish ? "STUDENT" : "PELAJAR"),
              userId: studentId,
              isGuest: false,
              isEnglish: widget.isEnglish,
              kioskId: widget.kioskId,
            )),
            (r) => false
          );
        } else {
          setState(() {
            _statusMessage = widget.isEnglish ? "Student data not found for:\n$studentId" : "Data pelajar tidak ditemui untuk:\n$studentId";
          });
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            backgroundColor: Colors.redAccent,
            content: Text(
              widget.isEnglish ? "Student data missing." : "Data pelajar hilang.",
              style: const TextStyle(color: Colors.white),
            )
          ));
          await _resetScanner();
        }
      } else {
        setState(() {
          _statusMessage = widget.isEnglish ? "Unregistered Card ID:\n$nfcId" : "ID Kad Tidak Berdaftar:\n$nfcId";
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: Colors.amberAccent,
          content: Text(
            widget.isEnglish ? "Card not recognized." : "Kad tidak dikenali.",
            style: const TextStyle(color: Colors.black87),
          )
        ));
        await _resetScanner();
      }
    } catch (e) {
      setState(() {
        _statusMessage = widget.isEnglish ? "Login Error" : "Ralat Log Masuk";
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: Colors.redAccent,
        content: Text(
          widget.isEnglish ? "Login Error: $e" : "Ralat Log Masuk: $e",
          style: const TextStyle(color: Colors.white),
        )
      ));
      await _resetScanner();
    }
  }

  Future<void> _resetScanner() async {
    await Future.delayed(const Duration(seconds: 2));
    await FirebaseDatabase.instance.ref('kiosk/${widget.kioskId}/scanned_rfid').set("");
    if (mounted) {
      setState(() {
        _isLoading = false;
        _statusMessage = widget.isEnglish ? "Please tap your card" : "Sila sentuh kad anda";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

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
            Positioned(
              top: 20,
              left: 20,
              child: TextButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back, size: 26, color: Colors.cyanAccent),
                label: Text(
                  widget.isEnglish ? 'Back' : 'Kembali',
                  style: const TextStyle(fontSize: 17, color: Colors.cyanAccent),
                ),
              ),
            ),
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                  child: Container(
                    width: 500,
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 50),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.cyanAccent.withOpacity(0.3), width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.cyanAccent.withOpacity(0.1),
                          blurRadius: 40,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.isEnglish ? "STUDENT RFID LOGIN" : "LOG MASUK RFID PELAJAR", 
                          textAlign: TextAlign.center, 
                          style: TextStyle(
                            color: Colors.white, 
                            fontWeight: FontWeight.bold, 
                            fontSize: 24,
                            shadows: [Shadow(color: Colors.cyanAccent.withOpacity(0.5), blurRadius: 10)]
                          )
                        ),
                        const SizedBox(height: 30),
                        
                        // Glowing Contactless Icon
                        ScaleTransition(
                          scale: _isLoading ? const AlwaysStoppedAnimation(1.0) : _pulseAnim,
                          child: Container(
                            padding: const EdgeInsets.all(30),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _isLoading ? Colors.white.withOpacity(0.05) : Colors.cyanAccent.withOpacity(0.1),
                              border: Border.all(
                                color: _isLoading ? Colors.white.withOpacity(0.2) : Colors.cyanAccent.withOpacity(0.5), 
                                width: 2
                              ),
                              boxShadow: _isLoading ? [] : [
                                BoxShadow(color: Colors.cyanAccent.withOpacity(0.3), blurRadius: 30, spreadRadius: 10)
                              ],
                            ),
                            child: Icon(
                              Icons.contactless_rounded, 
                              size: 100, 
                              color: _isLoading ? Colors.white54 : Colors.cyanAccent
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 40),
                        
                        if (_isLoading)
                          const CircularProgressIndicator(color: Colors.cyanAccent)
                        else
                          Text(
                            _statusMessage,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.cyanAccent)
                          ),
                        
                        const SizedBox(height: 25),
                        Text(
                          widget.isEnglish 
                            ? "Please tap your Student Card on the physical scanner" 
                            : "Sila sentuh Kad Pelajar anda pada pengimbas fizikal",
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 16, color: Colors.white70)
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (!isKeyboardOpen)
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