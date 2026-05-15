// lib/screens/history_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_database/firebase_database.dart';

class HistoryScreen extends StatelessWidget {
  final String userId;
  final bool isEnglish;
  final String historyType;
  final VoidCallback onBack;

  const HistoryScreen({super.key, required this.userId, required this.isEnglish, required this.historyType, required this.onBack});

  Widget _buildHistoryRow(IconData icon, Color color, String label, String val) {
     return Padding(
       padding: const EdgeInsets.symmetric(vertical: 8.0),
       child: Row(
         children: [
           Icon(icon, color: color, size: 28), const SizedBox(width: 15),
           Text(label, style: const TextStyle(fontSize: 16, color: Colors.black54, fontWeight: FontWeight.bold)), const Spacer(),
           Text(val, style: TextStyle(fontSize: 18, color: color, fontWeight: FontWeight.bold)),
         ]
       )
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
        Align(alignment: Alignment.centerLeft, child: TextButton.icon(onPressed: onBack, icon: const Icon(Icons.arrow_back), label: Text(isEnglish ? "Back" : "Kembali"))),
        Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF133F85)))),
        Expanded(
          child: StreamBuilder<DatabaseEvent>(
            stream: historyType == "APPOINTMENT" ? FirebaseDatabase.instance.ref('appointments').onValue : FirebaseDatabase.instance.ref(dbNode).orderByChild('patient_id').equalTo(userId).onValue,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              if (!snapshot.hasData || snapshot.data!.snapshot.value == null) return Center(child: Text(isEnglish ? "No records found." : "Tiada rekod ditemui."));
              
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
                    return Card(
                      elevation: 2, margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      child: ExpansionTile(
                        leading: const Icon(Icons.monitor_heart, color: Colors.red, size: 30), 
                        title: Text(isEnglish ? "Health Scan" : "Imbasan Kesihatan", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                        subtitle: Text("${data['date'] ?? 'N/A'}  |  ${data['time'] ?? 'N/A'}", style: const TextStyle(color: Colors.blueGrey, fontWeight: FontWeight.w500)),
                        childrenPadding: const EdgeInsets.all(20), expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                           _buildHistoryRow(Icons.scale, Colors.blue, isEnglish ? "Weight" : "Berat", "${w.toStringAsFixed(2)} kg"), const Divider(),
                           _buildHistoryRow(Icons.height, Colors.purple, isEnglish ? "Height" : "Tinggi", "${h.toStringAsFixed(2)} cm"), const Divider(),
                           _buildHistoryRow(Icons.monitor_weight, Colors.orange, "BMI", bmi.toStringAsFixed(2)), const Divider(),
                           _buildHistoryRow(Icons.thermostat, Colors.red, isEnglish ? "Body Temp" : "Suhu Badan", "${t.toStringAsFixed(1)} °C"), const Divider(),
                           _buildHistoryRow(Icons.favorite, Colors.pink, isEnglish ? "Heart Rate" : "Kadar Jantung", "${data['heart_rate']} bpm"), const Divider(),
                           _buildHistoryRow(Icons.bloodtype, Colors.redAccent, "SpO2", "${data['spo2']} %"),
                        ],
                      )
                    );
                  } else if (historyType == "APPOINTMENT") {
                    String status = data['status'] ?? "Booked";
                    return Card(
                      elevation: 2,
                      child: ListTile(
                        leading: const Icon(Icons.calendar_today, size: 30),
                        title: Text(data['department'] ?? "Clinic", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                        subtitle: Text("${data['date']} | ${data['time']}"),
                        trailing: status == "Booked"
                            ? ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white), onPressed: () async { await FirebaseDatabase.instance.ref('appointments').child(data['deptNode']).child(data['id']).update({'status': 'Cancelled'}); }, child: Text(isEnglish ? "Cancel" : "Batal"))
                            : Text(status, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                    );
                  } else {
                    String status = data['status'] ?? "Pending";
                    Color sc = status == "Approved" ? Colors.green : (status == "Returned" ? Colors.blue : (status == "Overdue" ? Colors.red : Colors.orange));
                    String subtitleText = (data.containsKey('start_date') && data.containsKey('end_date')) ? "From: ${data['start_date']}  To: ${data['end_date']}" : "Awaiting dates";
                    return Card(
                      elevation: 2,
                      child: ListTile(
                        leading: Icon(Icons.medical_information, color: sc, size: 30),
                        title: Text(data.containsKey('quantity') ? "${data['quantity']}x ${data['item']}" : (data['item'] ?? "Equipment"), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                        subtitle: Text(subtitleText), trailing: Text(status, style: TextStyle(color: sc, fontWeight: FontWeight.bold, fontSize: 16)),
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