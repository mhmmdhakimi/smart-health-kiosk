import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:ui';
import 'package:firebase_database/firebase_database.dart';

class HistoryScreen extends StatelessWidget {
  final String userId;
  final bool isEnglish;
  final String historyType;
  final VoidCallback onBack;

  const HistoryScreen({super.key, required this.userId, required this.isEnglish, required this.historyType, required this.onBack});

  Widget _buildHistoryRow(IconData icon, Color color, String label, String val) {
     return Padding(
       padding: const EdgeInsets.symmetric(vertical: 12.0),
       child: Row(
         children: [
           Icon(icon, color: color, size: 28), const SizedBox(width: 15),
           Text(label, style: const TextStyle(fontSize: 16, color: Colors.white70, fontWeight: FontWeight.bold)), const Spacer(),
           Text(val, style: TextStyle(fontSize: 18, color: color, fontWeight: FontWeight.bold, shadows: [Shadow(color: color.withOpacity(0.5), blurRadius: 10)])),
         ]
       )
     );
  }

  Color _getStatusColor(String status) {
    if (status == "Booked" || status == "WAITING" || status == "Waiting" || status == "Pending") return Colors.amberAccent;
    if (status == "Approved" || status == "COMPLETED" || status == "Completed") return Colors.cyanAccent;
    if (status == "Cancelled" || status == "Overdue" || status == "Expired") return Colors.redAccent;
    if (status == "Returned") return const Color(0xFF1B64F2); // Royal Blue
    return Colors.white70;
  }

  Widget _buildGlassCard({required Widget child}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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

  @override
  Widget build(BuildContext context) {
    String title = "";
    String dbNode = "";
    
    if (historyType == "CHECKUP") { title = isEnglish ? "CHECKUP RECORD" : "REKOD PEMERIKSAAN"; dbNode = "checkups"; }
    else if (historyType == "APPOINTMENT") { title = isEnglish ? "APPOINTMENTS" : "TEMU JANJI"; dbNode = "appointments"; }
    else { title = isEnglish ? "RESERVATION STATUS" : "STATUS TEMPAHAN"; dbNode = "reservations"; }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(alignment: Alignment.centerLeft, child: TextButton.icon(onPressed: onBack, icon: const Icon(Icons.arrow_back, color: Colors.cyanAccent), label: Text(isEnglish ? "Back" : "Kembali", style: const TextStyle(color: Colors.cyanAccent)))),
        Padding(padding: const EdgeInsets.symmetric(vertical: 20), child: Text(title, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white, shadows: [Shadow(color: Colors.cyanAccent.withOpacity(0.5), blurRadius: 10)]))),
        Expanded(
          child: StreamBuilder<DatabaseEvent>(
            stream: historyType == "APPOINTMENT" ? FirebaseDatabase.instance.ref('appointments').onValue : FirebaseDatabase.instance.ref(dbNode).orderByChild('patient_id').equalTo(userId).onValue,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Colors.cyanAccent));
              if (!snapshot.hasData || snapshot.data!.snapshot.value == null) return Center(child: Text(isEnglish ? "No records found." : "Tiada rekod ditemui.", style: const TextStyle(color: Colors.white70, fontSize: 18)));
              
              var dataMap = snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
              List<Map<String, dynamic>> docs = [];

              if (historyType == "APPOINTMENT") {
                dataMap.forEach((deptKey, deptData) {
                  if (deptData is Map) {
                    deptData.forEach((key, value) {
                      if (value is Map && value['patient_id'] == userId) {
                        var map = Map<String, dynamic>.from(value);
                        map['id'] = key; map['deptNode'] = deptKey; docs.add(map);
                      }
                    });
                  }
                });
              } else {
                for (var v in dataMap.values) {
                  if (v is Map) docs.add(Map<String, dynamic>.from(v));
                }
              }

              docs.sort((a, b) {
                try {
                  String dateA = a['date'] ?? '1970-01-01'; String timeA = a['time'] ?? '12:00 AM';
                  String dateB = b['date'] ?? '1970-01-01'; String timeB = b['time'] ?? '12:00 AM';
                  DateTime dtA = DateFormat('yyyy-MM-dd hh:mm a').parse('$dateA $timeA');
                  DateTime dtB = DateFormat('yyyy-MM-dd hh:mm a').parse('$dateB $timeB');
                  return dtB.compareTo(dtA); 
                } catch (e) {
                  int timeA = int.tryParse(a['timestamp'].toString()) ?? 0;
                  int timeB = int.tryParse(b['timestamp'].toString()) ?? 0;
                  return timeB.compareTo(timeA); 
                }
              });

              return ListView.builder(
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  var data = docs[index];

                  if (historyType == "CHECKUP") {
                    double w = (data['weight'] ?? 0).toDouble(); double h = (data['height'] ?? 0).toDouble();
                    double t = (data['temp'] ?? 0).toDouble(); double bmi = (data['bmi'] ?? 0).toDouble();
                    return _buildGlassCard(
                      child: Theme(
                        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          iconColor: Colors.cyanAccent,
                          collapsedIconColor: Colors.white54,
                          leading: const Icon(Icons.monitor_heart_outlined, color: Colors.cyanAccent, size: 30), 
                          title: Text(isEnglish ? "Health Scan" : "Imbasan Kesihatan", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
                          subtitle: Text("${data['date'] ?? 'N/A'}  |  ${data['time'] ?? 'N/A'}", style: const TextStyle(color: Colors.white54, fontWeight: FontWeight.w500)),
                          childrenPadding: const EdgeInsets.all(20), expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                             _buildHistoryRow(Icons.scale, Colors.cyanAccent, isEnglish ? "Weight" : "Berat", "${w.toStringAsFixed(2)} kg"),
                             Container(height: 1, color: Colors.white.withOpacity(0.1)),
                             _buildHistoryRow(Icons.height, Colors.purpleAccent, isEnglish ? "Height" : "Tinggi", "${h.toStringAsFixed(2)} cm"),
                             Container(height: 1, color: Colors.white.withOpacity(0.1)),
                             _buildHistoryRow(Icons.monitor_weight, Colors.amberAccent, "BMI", bmi.toStringAsFixed(2)),
                             Container(height: 1, color: Colors.white.withOpacity(0.1)),
                             _buildHistoryRow(Icons.thermostat, Colors.redAccent, isEnglish ? "Body Temp" : "Suhu Badan", "${t.toStringAsFixed(1)} °C"),
                             Container(height: 1, color: Colors.white.withOpacity(0.1)),
                             _buildHistoryRow(Icons.favorite, Colors.pinkAccent, isEnglish ? "Heart Rate" : "Kadar Jantung", "${data['heart_rate']} bpm"),
                             Container(height: 1, color: Colors.white.withOpacity(0.1)),
                             _buildHistoryRow(Icons.bloodtype, Colors.redAccent, "SpO2", "${data['spo2']} %"),
                          ],
                        ),
                      )
                    );
                  } else if (historyType == "APPOINTMENT") {
                    String status = data['status'] ?? "Booked";
                    Color sc = _getStatusColor(status);
                    bool isActive = status == "Booked";

                    if (isActive) {
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 15),
                        decoration: BoxDecoration(
                          color: Colors.cyanAccent.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(30), // Squircle
                          border: Border.all(color: Colors.cyanAccent.withOpacity(0.5), width: 2),
                          boxShadow: [BoxShadow(color: Colors.cyanAccent.withOpacity(0.1), blurRadius: 20)],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(30),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                            child: Padding(
                              padding: const EdgeInsets.all(25),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.calendar_month, color: Colors.cyanAccent, size: 40),
                                      const SizedBox(width: 15),
                                      Text(data['department'] ?? "Clinic", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24, color: Colors.white, shadows: [Shadow(color: Colors.cyanAccent.withOpacity(0.5), blurRadius: 10)])),
                                      const Spacer(),
                                      OutlinedButton(
                                        style: OutlinedButton.styleFrom(
                                          side: BorderSide(color: Colors.redAccent.withOpacity(0.5)),
                                          backgroundColor: Colors.redAccent.withOpacity(0.1),
                                          foregroundColor: Colors.redAccent,
                                        ),
                                        onPressed: () async { await FirebaseDatabase.instance.ref('appointments').child(data['deptNode']).child(data['id']).update({'status': 'Cancelled'}); }, 
                                        child: Text(isEnglish ? "Cancel" : "Batal")
                                      )
                                    ]
                                  ),
                                  const SizedBox(height: 20),
                                  Row(
                                    children: [
                                      const Icon(Icons.event, color: Colors.white70), const SizedBox(width: 10),
                                      Text(data['date'] ?? "", style: const TextStyle(color: Colors.white, fontSize: 18)),
                                      const SizedBox(width: 30),
                                      const Icon(Icons.schedule, color: Colors.white70), const SizedBox(width: 10),
                                      Text(data['time'] ?? "", style: const TextStyle(color: Colors.white, fontSize: 18)),
                                    ]
                                  )
                                ]
                              )
                            )
                          )
                        )
                      );
                    } else {
                      return _buildGlassCard(
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 25, vertical: 15),
                          leading: const Icon(Icons.history, size: 35, color: Colors.white54),
                          title: Text(data['department'] ?? "Clinic", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
                          subtitle: Text("${data['date']} | ${data['time']}", style: const TextStyle(color: Colors.white54, fontSize: 15)),
                          trailing: Text(status.toUpperCase(), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: sc, shadows: [Shadow(color: sc.withOpacity(0.8), blurRadius: 10)])),
                        ),
                      );
                    }
                  } else {
                    String status = data['status'] ?? "Pending";
                    Color sc = _getStatusColor(status);
                    String subtitleText = (data.containsKey('start_date') && data.containsKey('end_date')) ? "From: ${data['start_date']}  To: ${data['end_date']}" : "Awaiting dates";
                    return _buildGlassCard(
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 25, vertical: 15),
                        leading: Icon(Icons.medical_information_outlined, color: sc, size: 35),
                        title: Text(data.containsKey('quantity') ? "${data['quantity']}x ${data['item']}" : (data['item'] ?? "Equipment"), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
                        subtitle: Text(subtitleText, style: const TextStyle(color: Colors.white54, fontSize: 15)), 
                        trailing: Text(status.toUpperCase(), style: TextStyle(color: sc, fontWeight: FontWeight.bold, fontSize: 16, shadows: [Shadow(color: sc.withOpacity(0.8), blurRadius: 10)])),
                      ),
                    );
                  }
                },
              );
            },
          ),
        ),
      ],
    );
  }
}