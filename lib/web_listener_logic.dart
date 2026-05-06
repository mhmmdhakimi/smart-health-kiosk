import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

class NfcWebListener {
  StreamSubscription<DatabaseEvent>? _subscription;

  /// Starts listening to the Firebase Relay node.
  /// Pass your actual login processing function as the callback.
  void startListening(Function(String uid) processNfcLogin) {
    _subscription = FirebaseDatabase.instance.ref('Current_Scan/scanned_uid').onValue.listen((event) async {
      if (event.snapshot.exists && event.snapshot.value != null) {
        String scannedUid = event.snapshot.value.toString();
        
        try {
          // 1. Trigger the Kiosk's login logic with the intercepted UID FIRST
          processNfcLogin(scannedUid);

          // 2. Safely delete the data afterwards to prevent racing/sync locks
          await FirebaseDatabase.instance.ref('Current_Scan').remove();
          
        } catch (e) {
          debugPrint("Error clearing Current_Scan or processing login: $e");
        }
      }
    });
  }

  /// Call this inside the dispose() method of your Kiosk Login Page
  /// to prevent memory leaks when navigating away.
  void stopListening() {
    _subscription?.cancel();
  }
}
