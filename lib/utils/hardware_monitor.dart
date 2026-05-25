// lib/utils/hardware_monitor.dart
//
// Global singleton that monitors whether the physical kiosk hardware
// (RFID card reader + health sensors) is online.
//
// The hardware-side firmware periodically writes a heartbeat value to
//   kiosk/<kioskId>/heartbeat
// in Firebase Realtime Database.  If no write is received within
// [_timeoutSeconds] seconds the hardware is considered offline.
//
// Usage:
//   HardwareMonitor().startMonitoring();          // once at app start
//   HardwareMonitor().isOnline                    // synchronous snapshot
//   HardwareMonitor().onlineStream.listen(...)    // reactive stream
//   HardwareMonitor().dispose();                  // if you ever need to stop

import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

class HardwareMonitor {
  // ── Singleton boilerplate ─────────────────────────────────────────────────
  static final HardwareMonitor _instance = HardwareMonitor._internal();
  factory HardwareMonitor() => _instance;
  HardwareMonitor._internal();

  // ── Configuration ─────────────────────────────────────────────────────────
  static const int _timeoutSeconds = 5;
  static const String _defaultKioskId = 'KIOSK_01';

  // ── Internal state ────────────────────────────────────────────────────────
  final _controller = StreamController<bool>.broadcast();
  StreamSubscription? _heartbeatSub;
  Timer? _watchdog;

  DateTime _lastPing = DateTime.now();
  bool _isOnline = false; // pessimistic default until first heartbeat
  bool _started = false;

  // ── Public API ────────────────────────────────────────────────────────────

  /// Whether the hardware is currently reachable.
  bool get isOnline => _isOnline;

  /// Reactive stream; fires every time the online/offline state changes.
  Stream<bool> get onlineStream => _controller.stream;

  /// Begin listening to the Firebase heartbeat node and the local watchdog.
  /// Safe to call multiple times — subsequent calls are no-ops.
  void startMonitoring({String kioskId = _defaultKioskId}) {
    if (_started) return;
    _started = true;

    // ── 1. Firebase heartbeat listener ───────────────────────────────────────
    _heartbeatSub = FirebaseDatabase.instance
        .ref('kiosk/$kioskId/heartbeat')
        .onValue
        .listen((event) {
      if (event.snapshot.exists) {
        _lastPing = DateTime.now();
        _setStatus(true);
      }
    }, onError: (e) {
      debugPrint('HardwareMonitor: Firebase error — $e');
    });

    // ── 2. Watchdog timer (checks every second) ──────────────────────────────
    _watchdog = Timer.periodic(const Duration(seconds: 1), (_) {
      final elapsed = DateTime.now().difference(_lastPing).inSeconds;
      if (elapsed > _timeoutSeconds && _isOnline) {
        _setStatus(false);
      }
    });

    debugPrint('HardwareMonitor: monitoring started (kiosk=$kioskId)');
  }

  void _setStatus(bool online) {
    if (_isOnline == online) return;
    _isOnline = online;
    _controller.add(online);
    debugPrint('HardwareMonitor: hardware is now ${online ? "ONLINE" : "OFFLINE"}');
  }

  /// Release all resources.
  void dispose() {
    _heartbeatSub?.cancel();
    _watchdog?.cancel();
    _controller.close();
  }
}
