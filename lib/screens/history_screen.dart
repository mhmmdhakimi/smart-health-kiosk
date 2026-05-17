import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:ui';
import 'package:firebase_database/firebase_database.dart';
import '../widgets/emergency_button.dart';

class HistoryScreen extends StatelessWidget {
  final String userId;
  final bool isEnglish;
  final String historyType;
  final VoidCallback onBack;

  const HistoryScreen({
    super.key,
    required this.userId,
    required this.isEnglish,
    required this.historyType,
    required this.onBack,
  });

  Widget _buildHistoryRow(
    IconData icon,
    Color color,
    String label,
    String val,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 15),
          Text(
            label,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.white70,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          Text(
            val,
            style: TextStyle(
              fontSize: 18,
              color: color,
              fontWeight: FontWeight.bold,
              shadows: [Shadow(color: color.withOpacity(0.5), blurRadius: 10)],
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    if (status == "Booked" ||
        status == "WAITING" ||
        status == "Waiting" ||
        status == "Pending") {
      return Colors.amberAccent;
    }
    if (status == "Approved" ||
        status == "COMPLETED" ||
        status == "Completed") {
      return Colors.cyanAccent;
    }
    if (status == "Cancelled" || status == "Overdue" || status == "Expired") {
      return Colors.redAccent;
    }
    if (status == "Returned") return const Color(0xFF1B64F2);
    return Colors.white70;
  }

  Widget _buildGlassCard({required Widget child}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      constraints: const BoxConstraints(minHeight: 44),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: child,
        ),
      ),
    );
  }

  // --- APPOINTMENT SPECIFIC UI ---

  Widget _buildBadge(String count, String label, IconData icon, Color color) {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.08), width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 20),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 50,
                  color: color,
                  shadows: [
                    Shadow(color: color.withOpacity(0.5), blurRadius: 15),
                  ],
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        count,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          height: 1.0,
                          shadows: [
                            Shadow(
                              color: color.withOpacity(0.5),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        label,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                          letterSpacing: 1.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyPlaceholder() {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Center(
        child: Text(
          isEnglish ? "No records found." : "Tiada rekod ditemui.",
          style: const TextStyle(color: Colors.white38, fontSize: 18),
        ),
      ),
    );
  }

  Widget _buildActiveCard(Map<String, dynamic> appointment) {
    String dept = appointment['department'] ?? 'Clinic';
    String doctor = appointment['doctor'] ?? 'Unassigned';
    String room = appointment['room'] ?? 'TBD';
    String reason = appointment['reason'] ?? 'General Checkup';
    DateTime dt = appointment['parsedDateTime'] as DateTime;
    String dateStr = DateFormat('dd MMM yyyy').format(dt);
    String timeStr = DateFormat('hh:mm a').format(dt);

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      constraints: const BoxConstraints(minHeight: 44),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.cyanAccent.withOpacity(0.3), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.cyanAccent.withOpacity(0.05),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Padding(
            padding: const EdgeInsets.all(25),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.cyanAccent.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.medical_services_rounded,
                    size: 50,
                    color: Colors.cyanAccent,
                    shadows: [Shadow(color: Colors.cyanAccent, blurRadius: 15)],
                  ),
                ),
                const SizedBox(width: 30),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        dept.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Icon(
                            Icons.person_outline,
                            color: Colors.white54,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            doctor,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(
                            Icons.info_outline,
                            color: Colors.white54,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            reason,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.cyanAccent.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.cyanAccent, width: 1),
                      ),
                      child: const Text(
                        "ACTIVE",
                        style: TextStyle(
                          color: Colors.cyanAccent,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 15),
                    Text(
                      dateStr,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      timeStr,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPastCard(Map<String, dynamic> appointment) {
    String dept = appointment['department'] ?? 'Clinic';
    String doctor = appointment['doctor'] ?? 'Unassigned';
    String room = appointment['room'] ?? 'TBD';
    String notes = appointment['notes'] ?? '';
    String status = (appointment['status'] ?? '').toString().toLowerCase();

    DateTime dt = appointment['parsedDateTime'] as DateTime;
    String dateStr = DateFormat('dd MMM yyyy').format(dt);
    String timeStr = DateFormat('hh:mm a').format(dt);

    bool isCancelled = status == 'cancelled';
    Color statusColor = isCancelled ? Colors.redAccent : Colors.grey;
    String statusText = isCancelled ? "CANCELLED" : "COMPLETED";

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      constraints: const BoxConstraints(minHeight: 44),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05), width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.all(25),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            dept.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.only(left: 10),
                            decoration: const BoxDecoration(
                              border: Border(
                                left: BorderSide(
                                  color: Colors.white24,
                                  width: 2,
                                ),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Dr. $doctor",
                                  style: const TextStyle(
                                    color: Colors.white54,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          statusText,
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 15),
                        Text(
                          dateStr,
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          timeStr,
                          style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (notes.isNotEmpty && !isCancelled)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 25,
                    vertical: 20,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.25),
                    border: const Border(
                      top: BorderSide(color: Colors.white12, width: 1),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Clinical Notes:",
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        notes,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppointmentHistory(List<Map<String, dynamic>> docs) {
    int upcomingCount = 0;
    int completedCount = 0;
    int cancelledCount = 0;

    List<Map<String, dynamic>> activeBookingsList = [];
    List<Map<String, dynamic>> pastHistoryList = [];

    DateTime now = DateTime.now();

    for (var appointment in docs) {
      String status = (appointment['status'] ?? '').toString().toLowerCase();
      String dateStr = appointment['date'] ?? '1970-01-01';
      String timeStr = appointment['time'] ?? '12:00 AM';

      DateTime parsedDateTime;
      try {
        parsedDateTime = DateFormat(
          'yyyy-MM-dd hh:mm a',
        ).parse('$dateStr $timeStr');
      } catch (e) {
        try {
          parsedDateTime = DateFormat(
            'dd MMM yyyy hh:mm a',
          ).parse('$dateStr $timeStr');
        } catch (e) {
          parsedDateTime = DateTime(1970);
        }
      }

      appointment['parsedDateTime'] = parsedDateTime;

      if (status == 'cancelled') {
        cancelledCount++;
        pastHistoryList.add(appointment);
      } else if (status == 'completed') {
        completedCount++;
        pastHistoryList.add(appointment);
      } else {
        if (parsedDateTime.isAfter(now)) {
          upcomingCount++;
          activeBookingsList.add(appointment);
        } else {
          pastHistoryList.add(appointment);
        }
      }
    }

    activeBookingsList.sort(
      (a, b) => (a['parsedDateTime'] as DateTime).compareTo(
        b['parsedDateTime'] as DateTime,
      ),
    );
    pastHistoryList.sort(
      (a, b) => (b['parsedDateTime'] as DateTime).compareTo(
        a['parsedDateTime'] as DateTime,
      ),
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Panel (Summary Badges)
        Expanded(
          flex: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildBadge(
                upcomingCount.toString(),
                isEnglish ? "Upcoming" : "Akan Datang",
                Icons.calendar_today_rounded,
                const Color(0xFF06B6D4),
              ),
              const SizedBox(height: 15),
              _buildBadge(
                completedCount.toString(),
                isEnglish ? "Completed" : "Selesai",
                Icons.check_circle_outline_rounded,
                Colors.greenAccent,
              ),
              const SizedBox(height: 15),
              _buildBadge(
                cancelledCount.toString(),
                isEnglish ? "Cancelled" : "Batal",
                Icons.cancel_outlined,
                Colors.redAccent,
              ),
            ],
          ),
        ),
        const SizedBox(width: 30),
        // Right Panel (Appointments Cards)
        Expanded(
          flex: 5,
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.only(
                bottom: 100,
              ), // Give room for emergency button
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    isEnglish
                        ? "Upcoming Appointments"
                        : "Temu Janji Akan Datang",
                    style: const TextStyle(
                      color: Colors.cyanAccent,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 15),
                  if (activeBookingsList.isEmpty)
                    _buildEmptyPlaceholder()
                  else
                    ...activeBookingsList.map((appt) => _buildActiveCard(appt)),

                  const SizedBox(height: 40),

                  Text(
                    isEnglish
                        ? "Past Appointments"
                        : "Sejarah Temu Janji Lepas",
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 15),
                  if (pastHistoryList.isEmpty)
                    _buildEmptyPlaceholder()
                  else
                    ...pastHistoryList.map((appt) => _buildPastCard(appt)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // --- MAIN BUILD ---
  @override
  Widget build(BuildContext context) {
    String title = "";
    String dbNode = "";

    if (historyType == "CHECKUP") {
      title = isEnglish ? "HEALTH RECORD" : "REKOD KESIHATAN";
      dbNode = "checkups";
    } else if (historyType == "APPOINTMENT") {
      title = isEnglish ? "APPOINTMENTS" : "TEMU JANJI";
      dbNode = "appointments";
    } else {
      title = isEnglish ? "RESERVATION STATUS" : "STATUS TEMPAHAN";
      dbNode = "reservations";
    }

    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44),
                child: TextButton.icon(
                  onPressed: onBack,
                  icon: const Icon(Icons.arrow_back, color: Colors.cyanAccent),
                  label: Text(
                    isEnglish ? "Back" : "Kembali",
                    style: const TextStyle(
                      color: Colors.cyanAccent,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 20, bottom: 10),
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  shadows: [
                    Shadow(
                      color: Colors.cyanAccent.withOpacity(0.5),
                      blurRadius: 10,
                    ),
                  ],
                ),
              ),
            ),

            Expanded(
              child: StreamBuilder<DatabaseEvent>(
                stream: historyType == "APPOINTMENT"
                    ? FirebaseDatabase.instance.ref('appointments').onValue
                    : FirebaseDatabase.instance
                          .ref(dbNode)
                          .orderByChild('patient_id')
                          .equalTo(userId)
                          .onValue,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: Colors.cyanAccent,
                      ),
                    );
                  }
                  if (!snapshot.hasData ||
                      snapshot.data!.snapshot.value == null) {
                    if (historyType == "APPOINTMENT") {
                      return _buildAppointmentHistory([]);
                    } else {
                      return _buildEmptyPlaceholder();
                    }
                  }

                  var dataMap =
                      snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
                  List<Map<String, dynamic>> docs = [];

                  if (historyType == "APPOINTMENT") {
                    dataMap.forEach((deptKey, deptData) {
                      if (deptData is Map) {
                        deptData.forEach((key, value) {
                          if (value is Map && value['patient_id'] == userId) {
                            var map = Map<String, dynamic>.from(value);
                            map['id'] = key;
                            map['deptNode'] = deptKey;
                            docs.add(map);
                          }
                        });
                      }
                    });
                  } else {
                    for (var v in dataMap.values) {
                      if (v is Map) docs.add(Map<String, dynamic>.from(v));
                    }
                  }

                  if (historyType == "APPOINTMENT") {
                    return _buildAppointmentHistory(docs);
                  }

                  // Legacy handling for CHECKUP and RESERVATION
                  docs.sort((a, b) {
                    try {
                      String dateA = a['date'] ?? '1970-01-01';
                      String timeA = a['time'] ?? '12:00 AM';
                      String dateB = b['date'] ?? '1970-01-01';
                      String timeB = b['time'] ?? '12:00 AM';
                      DateTime dtA = DateFormat(
                        'yyyy-MM-dd hh:mm a',
                      ).parse('$dateA $timeA');
                      DateTime dtB = DateFormat(
                        'yyyy-MM-dd hh:mm a',
                      ).parse('$dateB $timeB');
                      return dtB.compareTo(dtA);
                    } catch (e) {
                      int timeA = int.tryParse(a['timestamp'].toString()) ?? 0;
                      int timeB = int.tryParse(b['timestamp'].toString()) ?? 0;
                      return timeB.compareTo(timeA);
                    }
                  });

                  return ListView.builder(
                    padding: const EdgeInsets.only(bottom: 100),
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      var data = docs[index];

                      if (historyType == "CHECKUP") {
                        double w = (data['weight'] ?? 0).toDouble();
                        double h = (data['height'] ?? 0).toDouble();
                        double t = (data['temp'] ?? 0).toDouble();
                        double bmi = (data['bmi'] ?? 0).toDouble();
                        return _buildGlassCard(
                          child: Theme(
                            data: Theme.of(
                              context,
                            ).copyWith(dividerColor: Colors.transparent),
                            child: ExpansionTile(
                              iconColor: Colors.cyanAccent,
                              collapsedIconColor: Colors.white54,
                              leading: const Icon(
                                Icons.monitor_heart_outlined,
                                color: Colors.cyanAccent,
                                size: 30,
                              ),
                              title: Text(
                                isEnglish ? "Health Scan" : "Imbasan Kesihatan",
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: Colors.white,
                                ),
                              ),
                              subtitle: Text(
                                "${data['date'] ?? 'N/A'}  |  ${data['time'] ?? 'N/A'}",
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              childrenPadding: const EdgeInsets.all(20),
                              expandedCrossAxisAlignment:
                                  CrossAxisAlignment.stretch,
                              children: [
                                _buildHistoryRow(
                                  Icons.scale,
                                  Colors.cyanAccent,
                                  isEnglish ? "Weight" : "Berat",
                                  "${w.toStringAsFixed(2)} kg",
                                ),
                                Container(
                                  height: 1,
                                  color: Colors.white.withOpacity(0.1),
                                ),
                                _buildHistoryRow(
                                  Icons.height,
                                  Colors.purpleAccent,
                                  isEnglish ? "Height" : "Tinggi",
                                  "${h.toStringAsFixed(2)} cm",
                                ),
                                Container(
                                  height: 1,
                                  color: Colors.white.withOpacity(0.1),
                                ),
                                _buildHistoryRow(
                                  Icons.monitor_weight,
                                  Colors.amberAccent,
                                  "BMI",
                                  bmi.toStringAsFixed(2),
                                ),
                                Container(
                                  height: 1,
                                  color: Colors.white.withOpacity(0.1),
                                ),
                                _buildHistoryRow(
                                  Icons.thermostat,
                                  Colors.redAccent,
                                  isEnglish ? "Body Temp" : "Suhu Badan",
                                  "${t.toStringAsFixed(1)} °C",
                                ),
                                Container(
                                  height: 1,
                                  color: Colors.white.withOpacity(0.1),
                                ),
                                _buildHistoryRow(
                                  Icons.favorite,
                                  Colors.pinkAccent,
                                  isEnglish ? "Heart Rate" : "Kadar Jantung",
                                  "${data['heart_rate']} bpm",
                                ),
                                Container(
                                  height: 1,
                                  color: Colors.white.withOpacity(0.1),
                                ),
                                _buildHistoryRow(
                                  Icons.bloodtype,
                                  Colors.redAccent,
                                  "SpO2",
                                  "${data['spo2']} %",
                                ),
                              ],
                            ),
                          ),
                        );
                      } else {
                        String status = data['status'] ?? "Pending";
                        Color sc = _getStatusColor(status);
                        String subtitleText =
                            (data.containsKey('start_date') &&
                                data.containsKey('end_date'))
                            ? "From: ${data['start_date']}  To: ${data['end_date']}"
                            : "Awaiting dates";
                        return _buildGlassCard(
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 25,
                              vertical: 15,
                            ),
                            leading: Icon(
                              Icons.medical_information_outlined,
                              color: sc,
                              size: 35,
                            ),
                            title: Text(
                              data.containsKey('quantity')
                                  ? "${data['quantity']}x ${data['item']}"
                                  : (data['item'] ?? "Equipment"),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: Colors.white,
                              ),
                            ),
                            subtitle: Text(
                              subtitleText,
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 15,
                              ),
                            ),
                            trailing: Text(
                              status.toUpperCase(),
                              style: TextStyle(
                                color: sc,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                shadows: [
                                  Shadow(
                                    color: sc.withOpacity(0.8),
                                    blurRadius: 10,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}
