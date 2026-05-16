import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:ui';
import 'package:firebase_database/firebase_database.dart';
import 'appointment_page.dart';

class ConsultationScreen extends StatefulWidget {
  final String userId;
  final String userName;
  final bool isGuest;
  final bool isEnglish;
  final VoidCallback onBack;
  final VoidCallback onWalkIn;
  final VoidCallback onLogOut;

  const ConsultationScreen({
    super.key,
    required this.userId,
    required this.userName,
    required this.isGuest,
    required this.isEnglish,
    required this.onBack,
    required this.onWalkIn,
    required this.onLogOut,
  });

  @override
  State<ConsultationScreen> createState() => _ConsultationScreenState();
}

class _ConsultationScreenState extends State<ConsultationScreen> {
  Future<void> _preCheckAppointment(String dept) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => const Center(child: CircularProgressIndicator(color: Colors.cyanAccent)),
    );
    DateTime now = DateTime.now();
    var q = await FirebaseDatabase.instance.ref('appointments').once();
    bool hasActive = false;
    int consecutiveExpired = 0;
    List<Map<dynamic, dynamic>> userAppts = [];

    if (q.snapshot.exists) {
      var map = q.snapshot.value as Map<dynamic, dynamic>;
      for (var deptKey in map.keys) {
        if (map[deptKey] is Map) {
          for (var key in map[deptKey].keys) {
            var v = map[deptKey][key];
            if (v is Map) {
              if (v['status'] == 'Booked') {
                try {
                  DateTime apptDT = DateFormat(
                    'yyyy-MM-dd hh:mm a',
                  ).parse('${v['date']} ${v['time']}');
                  if (apptDT.isBefore(now))
                    FirebaseDatabase.instance
                        .ref('appointments')
                        .child(deptKey.toString())
                        .child(key.toString())
                        .update({'status': 'Expired'});
                } catch (e) {}
              }
              if (v['patient_id'] == widget.userId) {
                userAppts.add(v);
                if (v['status'] == 'Booked') hasActive = true;
              }
            }
          }
        }
      }
    }

    userAppts.sort(
      (a, b) => (b['timestamp'] ?? 0).compareTo(a['timestamp'] ?? 0),
    );
    for (var appt in userAppts) {
      if (appt['status'] == 'Expired' || appt['status'] == 'Cancelled') {
        consecutiveExpired++;
      } else if (appt['status'] == 'Booked')
        continue;
      else
        break;
    }

    if (mounted) Navigator.of(context, rootNavigator: true).pop();

    if (consecutiveExpired >= 3) {
      showDialog(
        context: context,
        builder: (c) => AlertDialog(
          backgroundColor: const Color(0xFF111827),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
              side: const BorderSide(color: Colors.redAccent)),
          title: Row(
            children: [
              const Icon(Icons.block, color: Colors.redAccent),
              const SizedBox(width: 10),
              Text(
                widget.isEnglish ? "Booking Blocked" : "Tempahan Disekat",
                style: const TextStyle(color: Colors.redAccent),
              ),
            ],
          ),
          content: Text(
            widget.isEnglish
                ? "You missed 3 appointments. Please make your appointment at the clinic."
                : "Anda terlepas 3 temu janji. Sila buat temu janji di klinik.",
            style: const TextStyle(color: Colors.white),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent.withOpacity(0.2),
                foregroundColor: Colors.redAccent,
                side: const BorderSide(color: Colors.redAccent),
              ),
              onPressed: () => Navigator.pop(c),
              child: const Text("OK"),
            ),
          ],
        ),
      );
      return;
    }

    if (hasActive) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (c) => AlertDialog(
          backgroundColor: const Color(0xFF111827),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
              side: BorderSide(color: Colors.cyanAccent.withOpacity(0.5))),
          title: Text(
            widget.isEnglish
                ? "Active Appointment Found"
                : "Temu Janji Aktif Ditemui",
            style: const TextStyle(color: Colors.cyanAccent),
          ),
          content: Text(
            widget.isEnglish
                ? "You already have an active appointment. Proceed?"
                : "Anda sudah mempunyai temu janji aktif. Teruskan?",
            style: const TextStyle(color: Colors.white),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: Text(widget.isEnglish ? "Go Back" : "Kembali", style: const TextStyle(color: Colors.white70)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.cyanAccent.withOpacity(0.2),
                foregroundColor: Colors.cyanAccent,
                side: const BorderSide(color: Colors.cyanAccent),
              ),
              onPressed: () {
                Navigator.pop(c);
                _handleDeptClick(dept);
              },
              child: Text(
                widget.isEnglish ? "Proceed anyway" : "Teruskan juga",
              ),
            ),
          ],
        ),
      );
    } else {
      _handleDeptClick(dept);
    }
  }

  void _handleDeptClick(String dept) async {
    String? result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (c) => AppointmentPage(
          department: dept,
          userName: widget.userName.toUpperCase(),
          userId: widget.userId,
          isGuest: false,
          onLogOut: widget.onLogOut,
          isEnglish: widget.isEnglish,
        ),
      ),
    );
    if (result == "HOME" && mounted) widget.onBack();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: widget.onBack,
            icon: const Icon(Icons.arrow_back, size: 28, color: Colors.cyanAccent),
            label: Text(
              widget.isEnglish ? "Back" : "Kembali",
              style: const TextStyle(fontSize: 18, color: Colors.cyanAccent),
            ),
          ),
        ),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                widget.isEnglish
                    ? "Select Medical Consultation Type"
                    : "Pilih Jenis Rundingan Perubatan",
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  shadows: [Shadow(color: Colors.cyanAccent.withOpacity(0.5), blurRadius: 10)]
                ),
              ),
              const SizedBox(height: 60),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 300,
                    height: 250,
                    child: _GlassBentoCard(
                      title: "WALK-IN",
                      icon: Icons.directions_walk_outlined,
                      onTap: widget.onWalkIn,
                    ),
                  ),
                  if (!widget.isGuest) ...[
                    const SizedBox(width: 50),
                    SizedBox(
                      width: 300,
                      height: 250,
                      child: _GlassBentoCard(
                        title: widget.isEnglish
                            ? "SCHEDULE APPOINTMENT"
                            : "JADUAL TEMU JANJI",
                        icon: Icons.calendar_month_outlined,
                        onTap: () => _preCheckAppointment(
                          widget.isEnglish ? "Dental Care" : "Penjagaan Gigi",
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Internal GlassBentoCard specific to ConsultationScreen
// ────────────────────────────────────────────────────────────────────────────
class _GlassBentoCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _GlassBentoCard({required this.icon, required this.title, required this.onTap});

  @override
  State<_GlassBentoCard> createState() => _GlassBentoCardState();
}

class _GlassBentoCardState extends State<_GlassBentoCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeInOut,
        transform: Matrix4.identity()..scale(_isPressed ? 0.98 : 1.0),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: _isPressed ? const Color(0xFF06B6D4) : Colors.white.withOpacity(0.1),
                  width: _isPressed ? 2 : 1,
                ),
                boxShadow: _isPressed ? [
                  BoxShadow(color: const Color(0xFF06B6D4).withOpacity(0.3), blurRadius: 30, spreadRadius: 5)
                ] : [],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(
                    widget.icon, 
                    size: 80, 
                    color: _isPressed ? const Color(0xFF06B6D4) : Colors.cyanAccent.withOpacity(0.8),
                    shadows: [
                      Shadow(
                        color: const Color(0xFF06B6D4).withOpacity(0.5), 
                        blurRadius: _isPressed ? 20 : 10
                      )
                    ]
                  ),
                  const SizedBox(height: 25),
                  Text(
                    widget.title.toUpperCase(), 
                    textAlign: TextAlign.center, 
                    maxLines: 2, 
                    style: TextStyle(
                      fontSize: 18, 
                      fontWeight: FontWeight.bold, 
                      color: Colors.white, 
                      letterSpacing: 1.2,
                      shadows: _isPressed ? [Shadow(color: const Color(0xFF06B6D4).withOpacity(0.8), blurRadius: 10)] : []
                    )
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
