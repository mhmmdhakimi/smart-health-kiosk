import 'package:flutter/material.dart';
import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import '../widgets/emergency_button.dart';
import 'kiosk_dashboard.dart';

class KioskLoginPage extends StatefulWidget {
  final bool isEnglish;
  const KioskLoginPage({super.key, required this.isEnglish});
  @override
  State<KioskLoginPage> createState() => _KioskLoginPageState();
}

class _KioskLoginPageState extends State<KioskLoginPage> {
  bool _isLoading = false;
  String _statusMessage = "";
  StreamSubscription<DatabaseEvent>? _rfidSubscription;

  @override
  void initState() {
    super.initState();
    _statusMessage = widget.isEnglish ? "Please tap your card" : "Sila sentuh kad anda";
    _initializeHardwareScanner();
  }

  @override
  void dispose() {
    _rfidSubscription?.cancel();
    super.dispose();
  }

  // Listens to the ESP32 Hardware at the ROOT level
  Future<void> _initializeHardwareScanner() async {
    // 1. Ensure node is clean on boot
    await FirebaseDatabase.instance.ref('scanned_rfid').set("");
    
    // 2. Listen for a new UID push from the ESP32
    _rfidSubscription = FirebaseDatabase.instance.ref('scanned_rfid').onValue.listen((event) async {
      if (event.snapshot.exists && event.snapshot.value != null) {
        String scannedUid = event.snapshot.value.toString();
        
        // Only trigger if it's a real ID and we aren't already loading
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
      // 1. Check the NFC lookup table
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

          // SUCCESS: Wipe the ID and move to dashboard
          await FirebaseDatabase.instance.ref('scanned_rfid').set("");
          if (!mounted) return;
          
          Navigator.pushAndRemoveUntil(
            context, 
            MaterialPageRoute(builder: (context) => KioskDashboard(
              userName: data['name'] ?? (widget.isEnglish ? "STUDENT" : "PELAJAR"),
              userId: studentId,
              isGuest: false,
              isEnglish: widget.isEnglish,
            )),
            (r) => false
          );
        } else {
          // FAIL: Student Profile Missing
          setState(() {
            _statusMessage = widget.isEnglish ? "Student data not found for:\n$studentId" : "Data pelajar tidak ditemui untuk:\n$studentId";
          });
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(widget.isEnglish ? "Student data missing." : "Data pelajar hilang.")));
          await _resetScanner();
        }
      } else {
        // FAIL: Unregistered Card
        setState(() {
          _statusMessage = widget.isEnglish ? "Unregistered Card ID:\n$nfcId" : "ID Kad Tidak Berdaftar:\n$nfcId";
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(widget.isEnglish ? "Card not recognized." : "Kad tidak dikenali.")));
        await _resetScanner();
      }
    } catch (e) {
      // FAIL: Database Error
      setState(() {
        _statusMessage = widget.isEnglish ? "Login Error" : "Ralat Log Masuk";
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(widget.isEnglish ? "Login Error: $e" : "Ralat Log Masuk: $e")));
      await _resetScanner();
    }
  }

  // Helper function to safely reset the scanner if a login fails
  Future<void> _resetScanner() async {
    await Future.delayed(const Duration(seconds: 2)); // Give user time to read the error
    await FirebaseDatabase.instance.ref('scanned_rfid').set("");
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
      backgroundColor: const Color(0xFF133F85),
      body: Stack(
        children: [
          Center(
            child: Container(
              width: 450,
              padding: const EdgeInsets.all(40),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
                      Expanded(
                        child: Text(
                          widget.isEnglish ? "STUDENT RFID LOGIN" : "LOG MASUK RFID PELAJAR", 
                          textAlign: TextAlign.center, 
                          style: const TextStyle(color: Color(0xFF133F85), fontWeight: FontWeight.bold, fontSize: 20)
                        )
                      ),
                      const SizedBox(width: 48), 
                    ],
                  ),
                  const Divider(height: 40),
                  
                  Icon(Icons.contactless, size: 100, color: _isLoading ? Colors.grey : const Color(0xFF1B64F2)),
                  const SizedBox(height: 20),
                  
                  _isLoading
                    ? const CircularProgressIndicator()
                    : Text(
                        _statusMessage,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey)
                      ),
                  
                  const SizedBox(height: 30),
                  Text(
                    widget.isEnglish 
                      ? "Please tap your Student Card on the physical scanner" 
                      : "Sila sentuh Kad Pelajar anda pada pengimbas fizikal",
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 14, color: Colors.grey)
                  ),
                ],
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
    );
  }
}