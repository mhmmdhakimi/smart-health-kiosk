// lib/screens/consultation_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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

  const ConsultationScreen({super.key, required this.userId, required this.userName, required this.isGuest, required this.isEnglish, required this.onBack, required this.onWalkIn, required this.onLogOut});

  @override
  State<ConsultationScreen> createState() => _ConsultationScreenState();
}

class _ConsultationScreenState extends State<ConsultationScreen> {

  Future<void> _preCheckAppointment(String dept) async {
    showDialog(context: context, barrierDismissible: false, builder: (c) => const Center(child: CircularProgressIndicator()));
    DateTime now = DateTime.now();
    var q = await FirebaseDatabase.instance.ref('appointments').once();
    bool hasActive = false; int consecutiveExpired = 0; List<Map<dynamic, dynamic>> userAppts = [];

    if (q.snapshot.exists) {
      var map = q.snapshot.value as Map<dynamic, dynamic>;
      for (var deptKey in map.keys) {
        if (map[deptKey] is Map) {
          for (var key in map[deptKey].keys) {
            var v = map[deptKey][key];
            if (v is Map) {
              if (v['status'] == 'Booked') {
                try {
                  DateTime apptDT = DateFormat('yyyy-MM-dd hh:mm a').parse('${v['date']} ${v['time']}');
                  if (apptDT.isBefore(now)) FirebaseDatabase.instance.ref('appointments').child(deptKey.toString()).child(key.toString()).update({'status': 'Expired'});
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

    userAppts.sort((a, b) => (b['timestamp'] ?? 0).compareTo(a['timestamp'] ?? 0));
    for (var appt in userAppts) {
      if (appt['status'] == 'Expired' || appt['status'] == 'Cancelled') consecutiveExpired++;
      else if (appt['status'] == 'Booked') continue;
      else break; 
    }

    if (mounted) Navigator.of(context, rootNavigator: true).pop();

    if (consecutiveExpired >= 3) {
      showDialog(
        context: context,
        builder: (c) => AlertDialog(
          title: Row(children: [const Icon(Icons.block, color: Colors.red), const SizedBox(width: 10), Text(widget.isEnglish ? "Booking Blocked" : "Tempahan Disekat", style: const TextStyle(color: Colors.red))]),
          content: Text(widget.isEnglish ? "You missed 3 appointments. Please make your appointment at the clinic." : "Anda terlepas 3 temu janji. Sila buat temu janji di klinik."),
          actions: [ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white), onPressed: () => Navigator.pop(c), child: const Text("OK"))]
        )
      );
      return;
    }

    if (hasActive) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (c) => AlertDialog(
          title: Text(widget.isEnglish ? "Active Appointment Found" : "Temu Janji Aktif Ditemui"),
          content: Text(widget.isEnglish ? "You already have an active appointment. Proceed?" : "Anda sudah mempunyai temu janji aktif. Teruskan?"),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c), child: Text(widget.isEnglish ? "Go Back" : "Kembali")),
            ElevatedButton(onPressed: () { Navigator.pop(c); _handleDeptClick(dept); }, child: Text(widget.isEnglish ? "Proceed anyway" : "Teruskan juga")),
          ],
        ),
      );
    } else {
      _handleDeptClick(dept);
    }
  }

  void _handleDeptClick(String dept) async {
    String? result = await Navigator.push(context, MaterialPageRoute(builder: (c) => AppointmentPage(department: dept, userName: widget.userName.toUpperCase(), userId: widget.userId, isGuest: false, onLogOut: widget.onLogOut, isEnglish: widget.isEnglish)));
    if (result == "HOME" && mounted) widget.onBack();
  }

  Widget _osiCard(String t, IconData i, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: 250, height: 200,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200, width: 2), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)]),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(i, color: const Color(0xFF133F85), size: 50), const SizedBox(height: 20), Text(t, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF133F85)))]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(alignment: Alignment.centerLeft, child: TextButton.icon(onPressed: widget.onBack, icon: const Icon(Icons.arrow_back, size: 28,), label: Text(widget.isEnglish ? "Back" : "Kembali", style: const TextStyle(fontSize: 18)))),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(widget.isEnglish ? "Select Medical Consultation Type" : "Pilih Jenis Rundingan Perubatan", style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF133F85))),
              const SizedBox(height: 40),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _osiCard("WALK-IN", Icons.directions_walk, onTap: widget.onWalkIn),
                  if (!widget.isGuest) ...[
                    const SizedBox(width: 40),
                    _osiCard(widget.isEnglish ? "SCHEDULE APPOINTMENT" : "JADUAL TEMU JANJI", Icons.calendar_month, onTap: () => _preCheckAppointment(widget.isEnglish ? "Dental Care" : "Penjagaan Gigi")),
                  ]
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}