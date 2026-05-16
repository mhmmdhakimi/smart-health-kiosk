import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:ui';
import 'package:firebase_database/firebase_database.dart';

class WalkInScreen extends StatefulWidget {
  final String userId;
  final String userName;
  final bool isGuest;
  final String? guestPhone;
  final bool isEnglish;
  final VoidCallback onBack;
  final VoidCallback onLogOut;

  const WalkInScreen({
    super.key,
    required this.userId,
    required this.userName,
    required this.isGuest,
    this.guestPhone,
    required this.isEnglish,
    required this.onBack,
    required this.onLogOut,
  });

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
      if (now.hour >= 8 &&
          (now.hour < 12 || (now.hour == 12 && now.minute <= 15)))
        return true;
      if ((now.hour == 14 && now.minute >= 45) ||
          (now.hour >= 15 && now.hour < 17))
        return true;
      return false;
    }
    if ((now.hour >= 8 && now.hour < 13) || (now.hour >= 14 && now.hour < 17))
      return true;
    return false;
  }

  Future<void> _handleWalkInSubmission(String reason) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => const Center(child: CircularProgressIndicator(color: Colors.cyanAccent)),
    );
    final activeTicketQuery = await FirebaseDatabase.instance
        .ref('walk_ins')
        .once();
    if (mounted) Navigator.of(context, rootNavigator: true).pop();

    if (activeTicketQuery.snapshot.exists) {
      var map = activeTicketQuery.snapshot.value as Map<dynamic, dynamic>;
      DateTime startOfToday = DateTime(
        DateTime.now().year,
        DateTime.now().month,
        DateTime.now().day,
      );
      int startOfTodayMs = startOfToday.millisecondsSinceEpoch;
      var activeTickets = [];

      map.forEach((catKey, catData) {
        if (catData is Map) {
          for (var v in catData.values) {
            if (v is Map) {
              bool isSameUser = v['patient_id'] == widget.userId;
              if (widget.isGuest &&
                  widget.guestPhone != null &&
                  v['phone'] == widget.guestPhone)
                isSameUser = true;
              if (isSameUser &&
                  (v['status'] == 'Waiting' || v['status'] == 'Serving') &&
                  (v['timestamp'] ?? 0) >= startOfTodayMs)
                activeTickets.add(v);
            }
          }
        }
      });

      if (activeTickets.isNotEmpty) {
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (c) => AlertDialog(
            backgroundColor: const Color(0xFF111827),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
              side: const BorderSide(color: Colors.amberAccent)
            ),
            title: Text(
              widget.isEnglish ? "Active Ticket Found" : "Tiket Aktif Ditemui",
              style: const TextStyle(
                color: Colors.amberAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Text(
              widget.isEnglish
                  ? "You already have an active ticket (#${activeTickets.first['queue_number']})."
                  : "Anda sudah mempunyai tiket aktif (#${activeTickets.first['queue_number']}).",
              style: const TextStyle(fontSize: 16, color: Colors.white),
            ),
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amberAccent.withOpacity(0.2),
                  foregroundColor: Colors.amberAccent,
                  side: const BorderSide(color: Colors.amberAccent)
                ),
                onPressed: () => Navigator.pop(c),
                child: const Text("OK"),
              ),
            ],
          ),
        );
        return;
      }
    }
    _generateWalkInTicket(
      name: widget.isGuest ? "GUEST" : widget.userName,
      id: widget.userId,
      reason: reason,
      phone: widget.guestPhone,
    );
  }

  Future<void> _generateWalkInTicket({
    required String name,
    required String id,
    required String reason,
    String? phone,
  }) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => const Center(child: CircularProgressIndicator(color: Colors.cyanAccent)),
    );
    int queueNumber = 1000;
    bool success = false;
    String errMsg = "";

    try {
      DateTime now = DateTime.now();
      String categoryNode = "other";
      int baseNumber = 4000;
      if (reason.contains("Fever") || reason.contains("Demam")) {
        categoryNode = "fever_flu_cough";
        baseNumber = 1000;
      } else if (reason.contains("Physical") || reason.contains("Fizikal")) {
        categoryNode = "physical_injury";
        baseNumber = 2000;
      } else if (reason.contains("Follow") || reason.contains("Susulan")) {
        categoryNode = "follow_up";
        baseNumber = 3000;
      }

      var snapshotEvent = await FirebaseDatabase.instance
          .ref('walk_ins')
          .child(categoryNode)
          .orderByChild('timestamp')
          .startAt(
            DateTime(now.year, now.month, now.day).millisecondsSinceEpoch,
          )
          .once();
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
        'queue_number': queueNumber,
        'patient_name': name.toUpperCase(),
        'patient_id': id,
        'reason': reason,
        'status': 'Waiting',
        'timestamp': ServerValue.timestamp,
        'date': DateFormat('yyyy-MM-dd').format(now),
        'time': DateFormat('hh:mm a').format(now),
        'doctor_name': 'not assigned yet',
      };
      if (phone != null) walkInData['phone'] = phone.toString();

      await FirebaseDatabase.instance
          .ref('walk_ins')
          .child(categoryNode)
          .push()
          .set(walkInData);
      success = true;
    } catch (e) {
      errMsg = e.toString();
    }

    if (mounted) Navigator.of(context, rootNavigator: true).pop();
    if (success && mounted) {
      _showQueueNumberDialog(queueNumber, name, reason);
    } else if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: Colors.redAccent,
        content: Text("Error: $errMsg", style: const TextStyle(color: Colors.white))
      ));
    }
  }

  void _showQueueNumberDialog(int queueNo, String name, String reason) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => AlertDialog(
        backgroundColor: const Color(0xFF111827),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.cyanAccent.withOpacity(0.5))
        ),
        contentPadding: const EdgeInsets.all(40),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.cyanAccent, size: 80),
            const SizedBox(height: 20),
            Text(
              widget.isEnglish
                  ? "WALK-IN TICKET GENERATED"
                  : "TIKET WALK-IN DIJANA",
              style: const TextStyle(
                fontSize: 20,
                color: Colors.white70,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              "$queueNo",
              style: TextStyle(
                fontSize: 90,
                fontWeight: FontWeight.bold,
                color: Colors.cyanAccent,
                shadows: [Shadow(color: Colors.cyanAccent.withOpacity(0.5), blurRadius: 20)]
              ),
            ),
            const SizedBox(height: 10),
            Text(
              widget.isEnglish ? "Reason: $reason" : "Sebab: $reason",
              style: const TextStyle(fontSize: 18, color: Colors.white),
            ),
            const SizedBox(height: 40),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.redAccent.withOpacity(0.5)),
                    backgroundColor: Colors.redAccent.withOpacity(0.1),
                    padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
                  ),
                  onPressed: () {
                    Navigator.pop(c);
                    widget.onLogOut();
                  },
                  child: Text(
                    widget.isEnglish ? "LOG OUT" : "LOG KELUAR",
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.cyanAccent.withOpacity(0.2),
                    foregroundColor: Colors.cyanAccent,
                    side: BorderSide(color: Colors.cyanAccent.withOpacity(0.5)),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 35,
                      vertical: 15,
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
                  ),
                  onPressed: () {
                    Navigator.pop(c);
                    widget.onBack();
                  },
                  child: Text(
                    widget.isEnglish ? "CONTINUE" : "TERUSKAN",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusItem(String label, String value, Color valColor) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.white54,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 42,
            fontWeight: FontWeight.bold,
            color: valColor,
            shadows: [Shadow(color: valColor.withOpacity(0.5), blurRadius: 15)]
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isClinicOpen = _checkIsClinicOpen();
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
        
        // ── LIVE CLINIC STATUS GLASS PANEL ───────────────────────────────────
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 25, horizontal: 15),
              margin: const EdgeInsets.only(bottom: 30, top: 10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.cyanAccent.withOpacity(0.3)),
              ),
              child: StreamBuilder<DatabaseEvent>(
                stream: FirebaseDatabase.instance.ref('walk_ins').onValue,
                builder: (context, snapshot) {
                  int peopleWaiting = 0;
                  int currentServing = 1000;
                  int estWaitTime = 0;
                  int? myQueueNo;
                  if (snapshot.hasData && snapshot.data!.snapshot.value != null) {
                    var dataMap =
                        snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
                    List<dynamic> docs = [];
                    DateTime startOfToday = DateTime(
                      DateTime.now().year,
                      DateTime.now().month,
                      DateTime.now().day,
                    );
                    dataMap.forEach((catKey, catData) {
                      if (catData is Map) {
                        for (var v in catData.values) {
                          if (v is Map &&
                              (v['timestamp'] ?? 0) >=
                                  startOfToday.millisecondsSinceEpoch)
                            docs.add(v);
                        }
                      }
                    });
                    peopleWaiting = docs
                        .where((d) => d['status'] == 'Waiting')
                        .length;
                    var servingDocs = docs
                        .where((d) => d['status'] == 'Serving')
                        .toList();
                    if (servingDocs.isNotEmpty) {
                      servingDocs.sort(
                        (a, b) =>
                            (b['timestamp'] ?? 0).compareTo(a['timestamp'] ?? 0),
                      );
                      currentServing =
                          int.tryParse(
                            servingDocs.first['queue_number'].toString(),
                          ) ??
                          1000;
                    } else {
                      var completedDocs = docs
                          .where((d) => d['status'] == 'Completed')
                          .toList();
                      if (completedDocs.isNotEmpty) {
                        completedDocs.sort(
                          (a, b) =>
                              (b['timestamp'] ?? 0).compareTo(a['timestamp'] ?? 0),
                        );
                        currentServing =
                            int.tryParse(
                              completedDocs.first['queue_number'].toString(),
                            ) ??
                            1000;
                      }
                    }
                    estWaitTime = peopleWaiting * 10;
                    var myActiveTickets = docs
                        .where(
                          (map) =>
                              map['patient_id'] == widget.userId &&
                              (map['status'] == 'Waiting' ||
                                  map['status'] == 'Serving'),
                        )
                        .toList();
                    if (myActiveTickets.isNotEmpty)
                      myQueueNo = int.tryParse(
                        myActiveTickets.first['queue_number'].toString(),
                      );
                  }

                  return Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 12, height: 12, 
                            decoration: BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.redAccent, blurRadius: 8)])
                          ),
                          const SizedBox(width: 10),
                          Text(
                            widget.isEnglish
                                ? "LIVE CLINIC STATUS"
                                : "STATUS KLINIK LANGSUNG",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 2.0,
                              shadows: [Shadow(color: Colors.white.withOpacity(0.5), blurRadius: 10)]
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 25),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildStatusItem(
                            widget.isEnglish ? "YOUR TICKET" : "TIKET ANDA",
                            myQueueNo != null ? "$myQueueNo" : "--",
                            myQueueNo != null ? Colors.greenAccent : Colors.white54,
                          ),
                          Container(width: 1, height: 70, color: Colors.white.withOpacity(0.2)),
                          _buildStatusItem(
                            widget.isEnglish
                                ? "CURRENT SERVING"
                                : "SEDANG DILAYANI",
                            currentServing > 1000 ? "$currentServing" : "--",
                            Colors.cyanAccent,
                          ),
                          Container(width: 1, height: 70, color: Colors.white.withOpacity(0.2)),
                          _buildStatusItem(
                            widget.isEnglish ? "PEOPLE WAITING" : "ORANG MENUNGGU",
                            "$peopleWaiting",
                            Colors.amberAccent,
                          ),
                          Container(width: 1, height: 70, color: Colors.white.withOpacity(0.2)),
                          _buildStatusItem(
                            widget.isEnglish ? "EST. WAIT TIME" : "ANGGARAN MASA",
                            widget.isEnglish
                                ? "$estWaitTime mins"
                                : "$estWaitTime minit",
                            Colors.pinkAccent,
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),

        Expanded(
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (isClinicOpen) ...[
                    Text(
                      widget.isEnglish
                          ? "Please select your primary reason for visiting:"
                          : "Sila pilih sebab utama lawatan anda:",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        shadows: [Shadow(color: Colors.cyanAccent.withOpacity(0.3), blurRadius: 10)]
                      ),
                    ),
                    const SizedBox(height: 40),
                    Wrap(
                      spacing: 25,
                      runSpacing: 25,
                      alignment: WrapAlignment.center,
                      children: [
                        _WalkInTriageCard(
                          title: widget.isEnglish
                              ? "Fever / Flu / Cough"
                              : "Demam / Selesema / Batuk",
                          icon: Icons.thermostat_outlined,
                          onTap: () => _handleWalkInSubmission(
                            widget.isEnglish
                                ? "Fever / Flu / Cough"
                                : "Demam / Selesema / Batuk",
                          ),
                        ),
                        _WalkInTriageCard(
                          title: widget.isEnglish
                              ? "Physical Injury / Pain"
                              : "Kecederaan / Kesakitan Fizikal",
                          icon: Icons.personal_injury_outlined,
                          onTap: () => _handleWalkInSubmission(
                            widget.isEnglish
                                ? "Physical Injury / Pain"
                                : "Kecederaan / Kesakitan Fizikal",
                          ),
                        ),
                        _WalkInTriageCard(
                          title: widget.isEnglish
                              ? "Follow-up / Review"
                              : "Susulan / Semakan",
                          icon: Icons.loop_outlined,
                          onTap: () => _handleWalkInSubmission(
                            widget.isEnglish
                                ? "Follow-up / Review"
                                : "Susulan / Semakan",
                          ),
                        ),
                        _WalkInTriageCard(
                          title: widget.isEnglish
                              ? "Other / General"
                              : "Lain-lain / Umum",
                          icon: Icons.help_outline_outlined,
                          onTap: () => _handleWalkInSubmission(
                            widget.isEnglish
                                ? "Other / General"
                                : "Lain-lain / Umum",
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    const Icon(
                      Icons.event_busy,
                      size: 90,
                      color: Colors.redAccent,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      widget.isEnglish
                          ? "Clinic is closed."
                          : "Klinik ditutup.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.redAccent,
                        shadows: [Shadow(color: Colors.redAccent.withOpacity(0.5), blurRadius: 10)]
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Interactive Glass Triage Card
// ────────────────────────────────────────────────────────────────────────────
class _WalkInTriageCard extends StatefulWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  const _WalkInTriageCard({required this.title, required this.icon, required this.onTap});

  @override
  State<_WalkInTriageCard> createState() => _WalkInTriageCardState();
}

class _WalkInTriageCardState extends State<_WalkInTriageCard> {
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
        duration: const Duration(milliseconds: 100),
        transform: Matrix4.identity()..scale(_isPressed ? 0.96 : 1.0),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              width: 250,
              height: 140,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _isPressed ? const Color(0xFF06B6D4) : Colors.white.withOpacity(0.1),
                  width: _isPressed ? 2 : 1
                ),
                boxShadow: _isPressed ? [BoxShadow(color: const Color(0xFF06B6D4).withOpacity(0.3), blurRadius: 20)] : [],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    widget.icon, 
                    color: _isPressed ? const Color(0xFF06B6D4) : Colors.cyanAccent.withOpacity(0.8), 
                    size: 45,
                    shadows: _isPressed ? [Shadow(color: const Color(0xFF06B6D4), blurRadius: 10)] : []
                  ),
                  const SizedBox(height: 15),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text(
                      widget.title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.white,
                        shadows: _isPressed ? [Shadow(color: const Color(0xFF06B6D4).withOpacity(0.8), blurRadius: 5)] : []
                      ),
                    ),
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
