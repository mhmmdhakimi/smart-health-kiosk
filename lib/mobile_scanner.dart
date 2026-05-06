import 'package:flutter/material.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const ScannerApp());
}

class ScannerApp extends StatelessWidget {
  const ScannerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'NFC Relay Scanner',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const MobileScannerPage(),
    );
  }
}

class MobileScannerPage extends StatefulWidget {
  const MobileScannerPage({super.key});

  @override
  State<MobileScannerPage> createState() => _MobileScannerPageState();
}

class _MobileScannerPageState extends State<MobileScannerPage> {
  String _statusMessage = 'Ready to scan.\nTap a card to the back of your phone.';
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _startScanning();
  }

  @override
  void dispose() {
    NfcManager.instance.stopSession();
    super.dispose();
  }

  void _startScanning() async {
    bool isAvailable = await NfcManager.instance.isAvailable();
    if (!isAvailable) {
      setState(() => _statusMessage = 'NFC is not available on this device.');
      return;
    }

    NfcManager.instance.startSession(onDiscovered: (NfcTag tag) async {
      if (_isProcessing) return;
      setState(() {
        _isProcessing = true;
        _statusMessage = 'Reading Tag...';
      });

      String cleanUid = _extractUid(tag);
      
      setState(() => _statusMessage = 'Scanned UID: $cleanUid\nSending to Kiosk...');

      try {
        // Write to the root 'Current_Scan' node
        await FirebaseDatabase.instance.ref('Current_Scan').set({
          'scanned_uid': cleanUid,
          'timestamp': ServerValue.timestamp,
        });
        
        setState(() => _statusMessage = 'Sent $cleanUid successfully!\n\nPlease remove card...');
      } catch (e) {
        setState(() => _statusMessage = 'Error sending to Firebase:\n$e');
      }

      // Prevent rapid double-scanning which freezes the phone
      await Future.delayed(const Duration(seconds: 3));
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _statusMessage = 'Ready to scan.\nTap a card to the back of your phone.';
        });
      }
    });
  }

  String _extractUid(NfcTag tag) {
    List<int>? idBytes;
    if (tag.data.containsKey('nfca')) {
      idBytes = tag.data['nfca']['identifier'];
    } else if (tag.data.containsKey('mifareclassic')) idBytes = tag.data['mifareclassic']['identifier'];
    else if (tag.data.containsKey('isodep')) idBytes = tag.data['isodep']['identifier'];
    else if (tag.data.containsKey('mifareultralight')) idBytes = tag.data['mifareultralight']['identifier'];
    else if (tag.data.containsKey('ndefformatable')) idBytes = tag.data['ndefformatable']['identifier'];

    if (idBytes != null) {
      return idBytes.map((e) => e.toRadixString(16).padLeft(2, '0')).join('').toUpperCase();
    }
    return 'UNKNOWN_TAG';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('NFC Relay Scanner')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.nfc, size: 120, color: Colors.blueAccent),
            const SizedBox(height: 30),
            Text(_statusMessage, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android: return android;
      default: throw UnsupportedError('Platform not supported');
    }
  }
  static const FirebaseOptions web = FirebaseOptions(apiKey: "AIzaSyB0t88bvV3eTZoGLqt3_DOp4AXjwEYTlW4", authDomain: "smart-health-kiosk-193a5.firebaseapp.com", databaseURL: "https://smart-health-kiosk-193a5-default-rtdb.asia-southeast1.firebasedatabase.app", projectId: "smart-health-kiosk-193a5", storageBucket: "smart-health-kiosk-193a5.firebasestorage.app", messagingSenderId: "74365494988", appId: "1:74365494988:web:977ee83752dbb8b7ca4469");
  static const FirebaseOptions android = FirebaseOptions(apiKey: "AIzaSyB0t88bvV3eTZoGLqt3_DOp4AXjwEYTlW4", appId: "1:74365494988:android:977ee83752dbb8b7ca4469", messagingSenderId: "74365494988", projectId: "smart-health-kiosk-193a5", databaseURL: "https://smart-health-kiosk-193a5-default-rtdb.asia-southeast1.firebasedatabase.app", storageBucket: "smart-health-kiosk-193a5.firebasestorage.app");
}