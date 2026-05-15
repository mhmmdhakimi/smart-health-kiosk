// lib/screens/walk_in_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_database/firebase_database.dart';

class WalkInScreen extends StatefulWidget {
  final String userId;
  final String userName;
  final bool isGuest;
  final String? guestPhone;
  final bool isEnglish;
  final VoidCallback onBack;
  final VoidCallback onLogOut;

  const WalkInScreen({super.key, required this.userId, required this.userName, required this.isGuest, this.guestPhone, required this.isEnglish, required this.onBack, required this.onLogOut});

  @override
  State<WalkInScreen> createState() => _WalkInScreenState();
}

class _WalkInScreenState extends State<WalkInScreen> {
  bool _checkIsClinicOpen() {
    DateTime now = DateTime.now();
    if (now.weekday >= 6) return false;
    if (now.weekday == 5) {
      int weekOfMonth = ((now.day - 1) / 7).floor() + 1;
      if (weekOfMonth == 2 || weekOfMonth == 4) return false;
      if (now.hour >= 8 && (now.hour < 12 || (now.hour == 12 && now.minute <= 15))) return true;
      if ((now.hour == 14 && now.minute >= 45) || (now.hour >= 15 && now.hour < 17)) return true;
      return false;
    }
    if ((now.hour >= 8 && now.hour < 13) || (now.hour >= 14 && now.hour < 17)) return true;
    return false;
  }

  Future<void> _handleWalkInSubmission(String reason) async {
    showDialog(context: context, barrierDismissible: false, builder: (c) => const Center(child: CircularProgressIndicator()));
    final activeTicketQuery = await FirebaseDatabase.instance.ref('walk_ins').once();
    if (mounted) Navigator.of(context, rootNavigator: true).pop();

    if (activeTicketQuery.snapshot.exists) {
      var map = activeTicketQuery.snapshot.value as Map<dynamic, dynamic>;
      DateTime startOfToday = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
      int startOfTodayMs = startOfToday.millisecondsSinceEpoch;
      var activeTickets = [];

      map.forEach((catKey, catData) {
        if (catData is Map) {
          for (var v in catData.values) {
            if (v is Map) {
              bool isSameUser = v['patient_id'] == widget.userId;
              if (widget.isGuest && widget.guestPhone != null && v['phone'] == widget.guestPhone) isSameUser = true;
              if (isSameUser && (v['status'] == 'Waiting' || v['status'] == 'Serving') && (v['timestamp'] ?? 0) >= startOfTodayMs) activeTickets.add(v);
            }
          }
        }
      });

      if (activeTickets.isNotEmpty) {
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (c) => AlertDialog(
            title: Text(widget.isEnglish ? "Active Ticket Found" : "Tiket Aktif Ditemui", style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            content: Text(widget.isEnglish ? "You already have an active ticket (#${activeTickets.first['queue_number']})." : "Anda sudah mempunyai tiket aktif (#${activeTickets.first['queue_number']}).", style: const TextStyle(fontSize: 16)),
            actions: [ElevatedButton(onPressed: () => Navigator.pop(c), child: const Text("OK"))],
          )
        );
        return;
      }
    }
    _generateWalkInTicket(name: widget.isGuest ? "GUEST" : widget.userName, id: widget.userId, reason: reason, phone: widget.guestPhone);
  }

  Future<void> _generateWalkInTicket({required String name, required String id, required String reason, String? phone}) async {
    showDialog(context: context, barrierDismissible: false, builder: (c) => const Center(child: CircularProgressIndicator()));
    int queueNumber = 1000; bool success = false; String errMsg = "";

    try {
      DateTime now = DateTime.now();
      String categoryNode = "other"; int baseNumber = 4000;
      if (reason.contains("Fever") || reason.contains("Demam")) { categoryNode = "fever_flu_cough"; baseNumber = 1000; }
      else if (reason.contains("Physical") || reason.contains("Fizikal")) { categoryNode = "physical_injury"; baseNumber = 2000; }
      else if (reason.contains("Follow") || reason.contains("Susulan")) { categoryNode = "follow_up"; baseNumber = 3000; }

      var snapshotEvent = await FirebaseDatabase.instance.ref('walk_ins').child(categoryNode).orderByChild('timestamp').startAt(DateTime(now.year, now.month, now.day).millisecondsSinceEpoch).once();
      int maxQueueNo = baseNumber;
      if (snapshotEvent.snapshot.exists) {
        var map = snapshotEvent.snapshot.value as Map<dynamic, dynamic>;
        for (var v in map.values) {
          if (v is Map && v['queue_number'] != null) {
            int qn = int.tryParse(v['queue_number'].toString()) ?? baseNumber;
            if (qn > maxQueueNo) maxQueueNo = qn;
          }
        }
      }
      queueNumber = maxQueueNo + 1; 

      Map<String, dynamic> walkInData = {
        'queue_number': queueNumber, 'patient_name': name.toUpperCase(), 'patient_id': id, 'reason': reason, 'status': 'Waiting',
        'timestamp': ServerValue.timestamp, 'date': DateFormat('yyyy-MM-dd').format(now), 'time': DateFormat('hh:mm a').format(now), 'doctor_name': 'not assigned yet',
      };
      if (phone != null) walkInData['phone'] = phone.toString();

      await FirebaseDatabase.instance.ref('walk_ins').child(categoryNode).push().set(walkInData);
      success = true;
    } catch (e) { errMsg = e.toString(); }

    if (mounted) Navigator.of(context, rootNavigator: true).pop();
    if (success && mounted) _showQueueNumberDialog(queueNumber, name, reason);
    else if (!success && mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $errMsg")));
  }

  void _showQueueNumberDialog(int queueNo, String name, String reason) {
    showDialog(
      context: context, barrierDismissible: false,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), contentPadding: const EdgeInsets.all(30),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 60), const SizedBox(height: 15),
            Text(widget.isEnglish ? "WALK-IN TICKET GENERATED" : "TIKET WALK-IN DIJANA", style: const TextStyle(fontSize: 18, color: Colors.black54, fontWeight: FontWeight.bold)),
            Text("$queueNo", style: const TextStyle(fontSize: 80, fontWeight: FontWeight.bold, color: Color(0xFF133F85))),
            Text(widget.isEnglish ? "Reason: $reason" : "Sebab: $reason", style: const TextStyle(fontSize: 16, color: Colors.black87)),
            const SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(onPressed: () { Navigator.pop(c); widget.onLogOut(); }, child: Text(widget.isEnglish ? "LOG OUT" : "LOG KELUAR", style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16))), const SizedBox(width: 20),
                ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF133F85), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12)), onPressed: () { Navigator.pop(c); widget.onBack(); }, child: Text(widget.isEnglish ? "CONTINUE" : "TERUSKAN", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _triageCard(String title, IconData icon, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: 250, height: 120,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade300, width: 2), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)]),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, color: const Color(0xFF133F85), size: 35), const SizedBox(height: 10), Text(title, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF133F85)))]),
      ),
    );
  }

  Widget _buildStatusItem(String label, String value, Color valColor) {
    return Column(children: [Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blueGrey)), const SizedBox(height: 5), Text(value, style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: valColor))]);
  }

  @override
  Widget build(BuildContext context) {
    bool isClinicOpen = _checkIsClinicOpen();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(alignment: Alignment.centerLeft, child: TextButton.icon(onPressed: widget.onBack, icon: const Icon(Icons.arrow_back, size: 28), label: Text(widget.isEnglish ? "Back" : "Kembali", style: const TextStyle(fontSize: 18)))),
        Container(
          width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10), margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.blue.shade200)),
          child: StreamBuilder<DatabaseEvent>(
            stream: FirebaseDatabase.instance.ref('walk_ins').onValue,
            builder: (context, snapshot) {
              int peopleWaiting = 0; int currentServing = 1000; int estWaitTime = 0; int? myQueueNo;
              if (snapshot.hasData && snapshot.data!.snapshot.value != null) {
                var dataMap = snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
                List<dynamic> docs = [];
                DateTime startOfToday = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
                dataMap.forEach((catKey, catData) {
                  if (catData is Map) {
                    for (var v in catData.values) {
                      if (v is Map && (v['timestamp'] ?? 0) >= startOfToday.millisecondsSinceEpoch) docs.add(v);
                    }
                  }
                });
                peopleWaiting = docs.where((d) => d['status'] == 'Waiting').length;
                var servingDocs = docs.where((d) => d['status'] == 'Serving').toList();
                if (servingDocs.isNotEmpty) {
                  servingDocs.sort((a, b) => (b['timestamp'] ?? 0).compareTo(a['timestamp'] ?? 0));
                  currentServing = int.tryParse(servingDocs.first['queue_number'].toString()) ?? 1000;
                } else {
                  var completedDocs = docs.where((d) => d['status'] == 'Completed').toList();
                  if (completedDocs.isNotEmpty) {
                    completedDocs.sort((a, b) => (b['timestamp'] ?? 0).compareTo(a['timestamp'] ?? 0));
                    currentServing = int.tryParse(completedDocs.first['queue_number'].toString()) ?? 1000;
                  }
                }
                estWaitTime = peopleWaiting * 10;
                var myActiveTickets = docs.where((map) => map['patient_id'] == widget.userId && (map['status'] == 'Waiting' || map['status'] == 'Serving')).toList();
                if (myActiveTickets.isNotEmpty) myQueueNo = int.tryParse(myActiveTickets.first['queue_number'].toString());
              }

              return Column(
                children: [
                  Text(widget.isEnglish ? "LIVE CLINIC STATUS" : "STATUS KLINIK LANGSUNG", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF133F85))),
                  const SizedBox(height: 15),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildStatusItem(widget.isEnglish ? "YOUR TICKET" : "TIKET ANDA", myQueueNo != null ? "$myQueueNo" : "--", myQueueNo != null ? Colors.green.shade700 : Colors.grey),
                      Container(width: 2, height: 60, color: Colors.blue.shade200),
                      _buildStatusItem(widget.isEnglish ? "CURRENT SERVING" : "SEDANG DILAYANI", currentServing > 1000 ? "$currentServing" : "--", const Color(0xFF133F85)),
                      Container(width: 2, height: 60, color: Colors.blue.shade200),
                      _buildStatusItem(widget.isEnglish ? "PEOPLE WAITING" : "ORANG MENUNGGU", "$peopleWaiting", Colors.red),
                      Container(width: 2, height: 60, color: Colors.blue.shade200),
                      _buildStatusItem(widget.isEnglish ? "EST. WAIT TIME" : "ANGGARAN MASA", widget.isEnglish ? "$estWaitTime mins" : "$estWaitTime minit", Colors.orange.shade800),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (isClinicOpen) ...[
                    Text(widget.isEnglish ? "Please select your primary reason for visiting:" : "Sila pilih sebab utama lawatan anda:", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF133F85))),
                    const SizedBox(height: 30),
                    Wrap(
                      spacing: 20, runSpacing: 20, alignment: WrapAlignment.center,
                      children: [
                        _triageCard(widget.isEnglish ? "Fever / Flu / Cough" : "Demam / Selesema / Batuk", Icons.thermostat, onTap: () => _handleWalkInSubmission(widget.isEnglish ? "Fever / Flu / Cough" : "Demam / Selesema / Batuk")),
                        _triageCard(widget.isEnglish ? "Physical Injury / Pain" : "Kecederaan / Kesakitan Fizikal", Icons.personal_injury, onTap: () => _handleWalkInSubmission(widget.isEnglish ? "Physical Injury / Pain" : "Kecederaan / Kesakitan Fizikal")),
                        _triageCard(widget.isEnglish ? "Follow-up / Review" : "Susulan / Semakan", Icons.loop, onTap: () => _handleWalkInSubmission(widget.isEnglish ? "Follow-up / Review" : "Susulan / Semakan")),
                        _triageCard(widget.isEnglish ? "Other / General" : "Lain-lain / Umum", Icons.help_outline, onTap: () => _handleWalkInSubmission(widget.isEnglish ? "Other / General" : "Lain-lain / Umum")),
                      ],
                    ),
                  ] else ...[
                    const Icon(Icons.event_busy, size: 70, color: Colors.redAccent),
                    const SizedBox(height: 20),
                    Text(widget.isEnglish ? "Clinic is closed." : "Klinik ditutup.", textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.redAccent)),
                  ]
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}