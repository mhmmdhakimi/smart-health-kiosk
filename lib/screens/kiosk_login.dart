import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../widgets/emergency_button.dart';
import '../web_listener_logic.dart'; // Ensure this path is correct based on your setup
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
  final NfcWebListener _webListener = NfcWebListener();
  
  // RFID Scanner Variables
  final FocusNode _rfidFocusNode = FocusNode();
  String _rfidBuffer = "";
  DateTime _lastKeyPress = DateTime.now();

  @override
  void initState() {
    super.initState();
    _statusMessage = widget.isEnglish ? "Please tap your card" : "Sila sentuh kad anda";
    _startNFC();
    
    _webListener.startListening((String uid) {
      if (mounted && !_isLoading) {
        setState(() => _isLoading = true);
        _handleLogin(uid);
      }
    });

    Future.delayed(Duration.zero, () => _rfidFocusNode.requestFocus());
  }

  @override
  void dispose() {
    if (!kIsWeb) {
      try { NfcManager.instance.stopSession(); } catch (_) {}
    }
    _webListener.stopListening();
    _rfidFocusNode.dispose();
    super.dispose();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent) {
      final now = DateTime.now();
      if (now.difference(_lastKeyPress).inMilliseconds > 150) _rfidBuffer = "";
      _lastKeyPress = now;

      if (event.logicalKey == LogicalKeyboardKey.enter) {
        if (_rfidBuffer.isNotEmpty && !_isLoading) {
          String scannedUid = _rfidBuffer.toUpperCase();
          _rfidBuffer = "";
          setState(() => _isLoading = true);
          _handleLogin(scannedUid);
        }
        return KeyEventResult.handled;
      } else {
        String char = event.character ?? "";
        if (char.isEmpty && event.logicalKey.keyLabel.length == 1) char = event.logicalKey.keyLabel;
        if (char.isNotEmpty) _rfidBuffer += char;
      }
    }
    return KeyEventResult.ignored;
  }

  void _startNFC() async {
    if (kIsWeb) return; 
    try {
      bool isAvailable = await NfcManager.instance.isAvailable();
      if (!isAvailable) {
        return;
      }

      NfcManager.instance.startSession(onDiscovered: (NfcTag tag) async {
        if (_isLoading) return;
        setState(() => _isLoading = true);
        
        String nfcId = _extractTagId(tag);
        await _handleLogin(nfcId);
      });
    } catch (e) {
      // Fail silently
    }
  }

  String _extractTagId(NfcTag tag) {
    try {
      List<int>? idBytes;
      if (tag.data.containsKey('nfca')) {
        idBytes = tag.data['nfca']['identifier'];
      } else if (tag.data.containsKey('mifareclassic')) {
        idBytes = tag.data['mifareclassic']['identifier'];
      } else if (tag.data.containsKey('isodep')) {
        idBytes = tag.data['isodep']['identifier'];
      } else if (tag.data.containsKey('mifareultralight')) {
        idBytes = tag.data['mifareultralight']['identifier'];
      } else if (tag.data.containsKey('ndefformatable')) {
        idBytes = tag.data['ndefformatable']['identifier'];
      }
      
      if (idBytes != null) {
        return idBytes.map((e) => e.toRadixString(16).padLeft(2, '0')).join('').toUpperCase();
      }
      return tag.data.toString().hashCode.toString();
    } catch (e) {
      return "UNKNOWN_TAG";
    }
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

        if (!mounted) return;
        if (!kIsWeb) {
          try { NfcManager.instance.stopSession(); } catch (_) {}
        }
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
          setState(() {
            _statusMessage = widget.isEnglish ? "Student data not found for:\n$studentId" : "Data pelajar tidak ditemui untuk:\n$studentId";
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(widget.isEnglish ? "Student data missing." : "Data pelajar hilang.")));
        }
      } else {
        setState(() {
          _statusMessage = widget.isEnglish ? "Unregistered Card ID:\n$nfcId" : "ID Kad Tidak Berdaftar:\n$nfcId";
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(widget.isEnglish ? "Card not recognized." : "Kad tidak dikenali.")));
      }
    } catch (e) {
      setState(() {
        _statusMessage = widget.isEnglish ? "Login Error" : "Ralat Log Masuk";
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(widget.isEnglish ? "Login Error: $e" : "Ralat Log Masuk: $e")));
    }
    
    if (mounted) _rfidFocusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    bool isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    return Focus(
      focusNode: _rfidFocusNode,
      onKeyEvent: _handleKeyEvent,
      autofocus: true,
      child: Scaffold(
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
                          Expanded(child: Text(widget.isEnglish ? "STUDENT NFC LOGIN" : "LOG MASUK NFC PELAJAR", textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF133F85), fontWeight: FontWeight.bold, fontSize: 20))),
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
                          ? "Please tap your Student Card to the reader" 
                          : "Sila sentuh Kad Pelajar anda pada pembaca",
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
      ),
    );
  }
}