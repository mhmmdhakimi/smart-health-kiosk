// lib/utils/network_monitor.dart
import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

class NetworkMonitor {
  static final NetworkMonitor _instance = NetworkMonitor._internal();
  factory NetworkMonitor() => _instance;
  NetworkMonitor._internal();

  final Connectivity _connectivity = Connectivity();
  final DatabaseReference _connectedRef = FirebaseDatabase.instance.ref(
    '.info/connected',
  );

  final _onlineController = StreamController<bool>.broadcast();
  Stream<bool> get onlineStream => _onlineController.stream;

  bool _isOnline = true;
  bool get isOnline => _isOnline;

  StreamSubscription? _connectivitySubscription;
  StreamSubscription? _firebaseSubscription;

  void startMonitoring() {
    // Listen to Firebase real‑time connection state
    _firebaseSubscription = _connectedRef.onValue.listen((event) {
      final bool connected = event.snapshot.value == true;
      _updateStatus(connected);
    });

    // Listen to platform connectivity changes (Wi‑Fi / mobile data)
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((
      result,
    ) {
      final bool hasNetwork = result.isNotEmpty &&
          !result.every((r) => r == ConnectivityResult.none);
      if (!hasNetwork) {
        _updateStatus(false);
      }
    });

    _checkInitialStatus();
  }

  Future<void> _checkInitialStatus() async {
    final connectivityResult = await _connectivity.checkConnectivity();
    final bool hasNetwork = connectivityResult.isNotEmpty &&
        !connectivityResult.every((r) => r == ConnectivityResult.none);
    if (!hasNetwork) {
      _updateStatus(false);
    } else {
      // Give Firebase a moment to report .info/connected
      Future.delayed(const Duration(milliseconds: 500), () {
        if (!_onlineController.hasListener) return;
        _connectedRef.get().then((snap) {
          _updateStatus(snap.value == true);
        });
      });
    }
  }

  void _updateStatus(bool online) {
    if (_isOnline == online) return;
    _isOnline = online;
    _onlineController.add(online);
    debugPrint('Network status changed: ${online ? "ONLINE" : "OFFLINE"}');
  }

  void dispose() {
    _connectivitySubscription?.cancel();
    _firebaseSubscription?.cancel();
    _onlineController.close();
  }
}
