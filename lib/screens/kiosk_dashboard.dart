import 'package:flutter/material.dart';
import 'dart:async';
import 'package:intl/intl.dart';
import 'package:firebase_database/firebase_database.dart';
import '../widgets/emergency_button.dart';
import '../services/email_service.dart';
import 'language_selection.dart';
import 'appointment_page.dart';

class KioskDashboard extends StatefulWidget {
  final String userName;
  final String userId;
  final bool isGuest;
  final String? guestPhone; 
  final bool isEnglish;
  const KioskDashboard({super.key, required this.userName, required this.userId, required this.isGuest, this.guestPhone, required this.isEnglish});

  @override
  State<KioskDashboard> createState() => _KioskDashboardState();
}

class _KioskDashboardState extends State<KioskDashboard> {
  String _currentView = "HOME";

  // Equipment Form Controllers
  String? _selectedEquip;
  String? _selectedQuantity;
  String? _selectedLoanReason;
  final GlobalKey<FormState> _equipFKey = GlobalKey<FormState>();

  // Dropdown States for Equipment Date Selection
  String? _sDay; String? _sMonth; String? _sYear; 
  String? _eDay; String? _eMonth; String? _eYear; 

  final List<String> _daysList = List.generate(31, (i) => (i + 1).toString());
  final List<String> _yearsList = [DateTime.now().year.toString(), (DateTime.now().year + 1).toString()];
  
  List<String> get _monthsList => widget.isEnglish 
    ? ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December']
    : ['Januari', 'Februari', 'Mac', 'April', 'Mei', 'Jun', 'Julai', 'Ogos', 'September', 'Oktober', 'November', 'Disember'];
  List<String> get _loanReasons => widget.isEnglish
    ? ['Post-Surgery Recovery', 'Chronic Condition', 'Temporary Injury', 'Follow-up Treatment', 'Other']
    : ['Pemulihan Selepas Pembedahan', 'Keadaan Kronik', 'Kecederaan Sementara', 'Rawatan Susulan', 'Lain-lain'];
  List<String> get _equipList => widget.isEnglish
    ? ["Wheelchair", "Crutches", "Nebulizer", "First Aid Kit", "Anatomical Model", "Digital Thermometer", "Blood Pressure Cuff"]
    : ["Kerusi Roda", "Tongkat", "Nebulizer", "Peti Pertolongan Cemas", "Model Anatomi", "Termometer Digital", "Alat Tekanan Darah"];

  // --- IDLE TIMEOUT LOGIC ---
  Timer? _idleTimer;
  Timer? _warningTimer;
  bool _isWarningDialogVisible = false;

  @override
  void initState() {
    super.initState();
    _resetIdleTimer();
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    _warningTimer?.cancel();
    super.dispose();
  }

  void _resetIdleTimer() {
    _idleTimer?.cancel();
    _warningTimer?.cancel();
    
    if (_isWarningDialogVisible) {
      Navigator.of(context, rootNavigator: true).pop();
      _isWarningDialogVisible = false;
    }

    _idleTimer = Timer(const Duration(seconds: 45), _showIdleWarningDialog);
  }

  void _showIdleWarningDialog() {
    setState(() => _isWarningDialogVisible = true);
    _warningTimer = Timer(const Duration(seconds: 15), _autoLogOut);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Row(
          children: [
            const Icon(Icons.timer, color: Colors.orange, size: 30),
            const SizedBox(width: 10),
            Text(widget.isEnglish ? "Are you still there?" : "Adakah anda masih di sana?", style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(widget.isEnglish ? "You have been idle for a while.\n\nFor your security, you will be automatically logged out in 15 seconds if there is no activity." : "Anda telah melahu sebentar.\n\nUntuk keselamatan anda, anda akan dilog keluar secara automatik dalam 15 saat jika tiada aktiviti.", style: const TextStyle(fontSize: 16)),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF133F85), foregroundColor: Colors.white),
            onPressed: () => _resetIdleTimer(),
            child: Text(widget.isEnglish ? "I'M STILL HERE" : "SAYA MASIH DI SINI", style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _autoLogOut() {
    _idleTimer?.cancel();
    _warningTimer?.cancel();
    if (_isWarningDialogVisible && mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }
    Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (c) => const LanguageSelectionPage()), (r) => false);
  }

  bool _checkIsClinicOpen() {
    DateTime now = DateTime.now();
    if (now.weekday >= 6) return false;

    if (now.weekday == 5) {
      int weekOfMonth = ((now.day - 1) / 7).floor() + 1;
      if (weekOfMonth == 2 || weekOfMonth == 4) return false;

      if (now.hour >= 8 && (now.hour < 12 || (now.hour == 12 && now.minute <= 15))) {
        return true;
      } else if ((now.hour == 14 && now.minute >= 45) || (now.hour >= 15 && now.hour < 17)) {
        return true;
      }
      return false;
    }

    if ((now.hour >= 8 && now.hour < 13) || (now.hour >= 14 && now.hour < 17)) {
      return true;
    }

    return false;
  }

  void _goToWalkIn() {
    _expireOldAndSkippedTickets();
    setState(() => _currentView = "WALK_IN_TRIAGE");
  }

  Future<void> _expireOldAndSkippedTickets() async {
    DateTime now = DateTime.now();
    DateTime startOfToday = DateTime(now.year, now.month, now.day);
    int startOfTodayMs = startOfToday.millisecondsSinceEpoch;
    bool isClinicOpen = _checkIsClinicOpen();

    try {
      var q = await FirebaseDatabase.instance.ref('walk_ins').once();
      if (!q.snapshot.exists) return;
      var map = q.snapshot.value as Map<dynamic, dynamic>;

      map.forEach((catKey, catData) {
        if (catData is Map) {
          int currentServingQn = 0;
          List todayServingOrCompleted = [];

          catData.forEach((key, v) {
            if (v is Map && (v['timestamp'] ?? 0) >= startOfTodayMs) {
              if (v['status'] == 'Serving' || v['status'] == 'Completed') {
                todayServingOrCompleted.add(v);
              }
            }
          });

          todayServingOrCompleted.sort((a, b) => (b['timestamp'] ?? 0).compareTo(a['timestamp'] ?? 0));
          if (todayServingOrCompleted.isNotEmpty) {
            currentServingQn = int.tryParse(todayServingOrCompleted.first['queue_number'].toString()) ?? 0;
          }

          catData.forEach((key, v) {
            if (v is Map && v['status'] == 'Waiting') {
              bool isOld = (v['timestamp'] ?? 0) < startOfTodayMs;
              int qn = int.tryParse(v['queue_number'].toString()) ?? 0;
              bool isSkipped = currentServingQn > 0 && qn > 0 && qn < currentServingQn;

              if (isOld || isSkipped || !isClinicOpen) {
                FirebaseDatabase.instance.ref('walk_ins').child(catKey.toString()).child(key.toString()).update({'status': 'Expired'});
              }
            }
          });
        }
      });
    } catch (e) {
      debugPrint("Error expiring old/skipped tickets: $e");
    }
  }

  Widget _getContent() {
    switch (_currentView) {
      case "SEE_DOCTOR_OPT": return _buildSeeDoctorOptions();
      case "WALK_IN_TRIAGE": return _buildWalkInTriage();
      case "APPT_DEPT": return _buildDepartmentSelection();
      case "EQUIP_RES": return _buildEquipmentForm();
      case "EQUIP_HIST": return _buildReservationHistory();
      case "APPT_HIST": return _buildAppointmentHistory();
      case "CHECKUP_HIST": return _buildCheckupHistory();
      default: return _buildHome();
    }
  }

  void _showPostActionDialog(BuildContext context, VoidCallback onContinue) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Text(widget.isEnglish ? "Success!" : "Berjaya!", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
        content: Text(widget.isEnglish ? "Your request has been successfully processed.\n\nDo you want to continue using the kiosk or log out?" : "Permintaan anda telah berjaya diproses.\n\nAdakah anda ingin terus menggunakan kiosk atau log keluar?", style: const TextStyle(fontSize: 16)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(c);
              _autoLogOut(); 
            },
            child: Text(widget.isEnglish ? "LOG OUT" : "LOG KELUAR", style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF133F85), foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(c);
              onContinue();
            },
            child: Text(widget.isEnglish ? "CONTINUE" : "TERUSKAN", style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildHome() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 20.0),
          child: Column(
            children: [
              Text(widget.isEnglish ? 'WELCOME! SELECT A SERVICE' : 'SELAMAT DATANG! PILIH PERKHIDMATAN', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF133F85))),
              const SizedBox(height: 8),
              Text(widget.isEnglish ? 'PLEASE CHOOSE AN OPTION BELOW TO BEGIN.' : 'SILA PILIH PILIHAN DI BAWAH UNTUK BERMULA.', style: const TextStyle(fontSize: 16, color: Colors.black54)),
            ],
          ),
        ),
        Expanded(
          child: widget.isGuest 
            ? Column(
                children: [
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Spacer(flex: 1), 
                        Expanded(
                          flex: 2, 
                          child: _buildMenuCard(Icons.medical_services_outlined, widget.isEnglish ? 'SELF-CHECKUP' : 'PEMERIKSAAN\nKENDIRI', () {})
                        ),
                        const SizedBox(width: 30),
                        Expanded(
                          flex: 2, 
                          child: _buildMenuCard(Icons.directions_walk, widget.isEnglish ? 'WALK-IN' : 'WALK-IN (TIDAK\nBERJADUAL)', _goToWalkIn)
                        ),
                        const Spacer(flex: 1), 
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Expanded(child: SizedBox()), 
                ],
              )
            : Column(
                children: [
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: _buildMenuCard(Icons.medical_services_outlined, widget.isEnglish ? 'SELF-CHECKUP' : 'PEMERIKSAAN\nKENDIRI', () {})),
                        const SizedBox(width: 16),
                        Expanded(child: _buildMenuCard(Icons.person_search_outlined, widget.isEnglish ? 'MEDICAL\nCONSULTATION' : 'RUNDINGAN\nPERUBATAN', () => setState(() => _currentView = "SEE_DOCTOR_OPT"))),
                        const SizedBox(width: 16),
                        Expanded(child: _buildMenuCard(Icons.wheelchair_pickup_outlined, widget.isEnglish ? 'MEDICAL EQUIPMENT\nRESERVATION' : 'TEMPAHAN PERALATAN\nPERUBATAN', () => setState(() => _currentView = "EQUIP_RES"))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: _buildMenuCard(Icons.history_outlined, widget.isEnglish ? 'CHECK UP HISTORY' : 'SEJARAH PEMERIKSAAN', () => setState(() => _currentView = "CHECKUP_HIST"))),
                        const SizedBox(width: 16),
                        Expanded(child: _buildMenuCard(Icons.event_available_outlined, widget.isEnglish ? 'APPOINTMENT HISTORY' : 'SEJARAH TEMU JANJI', () => setState(() => _currentView = "APPT_HIST"))),
                        const SizedBox(width: 16),
                        Expanded(child: _buildMenuCard(Icons.handyman_outlined, widget.isEnglish ? 'EQUIPMENT RESERVATION\nSTATUS' : 'STATUS TEMPAHAN\nPERALATAN', () => setState(() => _currentView = "EQUIP_HIST"))),
                      ],
                    ),
                  ),
                ],
              ),
        ),
      ],
    );
  }

  Widget _buildMenuCard(IconData icon, String title, VoidCallback onTap) {
    return Card(
      color: const Color(0xFF133F85),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(icon, size: 50, color: const Color(0xFF00C7C7)),
              const SizedBox(height: 12),
              Text(title.toUpperCase(), textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white, height: 1.2)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSeeDoctorOptions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(onPressed: () => setState(() => _currentView = "HOME"), icon: const Icon(Icons.arrow_back, size: 28,), label: Text(widget.isEnglish ? "Back" : "Kembali", style: const TextStyle(fontSize: 18))),
        ),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(widget.isEnglish ? "Select Medical Consultation Type" : "Pilih Jenis Rundingan Perubatan", style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF133F85))),
              const SizedBox(height: 40),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _osiCard("WALK-IN", Icons.directions_walk, onTap: _goToWalkIn),
                  if (!widget.isGuest) ...[
                    const SizedBox(width: 40),
                    _osiCard(widget.isEnglish ? "SCHEDULE APPOINTMENT" : "JADUAL TEMU JANJI", Icons.calendar_month, onTap: () => setState(() => _currentView = "APPT_DEPT")),
                  ]
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWalkInTriage() {
    DateTime now = DateTime.now();
    DateTime startOfToday = DateTime(now.year, now.month, now.day);
    bool isClinicOpen = _checkIsClinicOpen();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () {
              if (widget.isGuest) {
                setState(() => _currentView = "HOME");
              } else {
                setState(() => _currentView = "SEE_DOCTOR_OPT");
              }
            }, 
            icon: const Icon(Icons.arrow_back, size: 28,), 
            label: Text(widget.isEnglish ? "Back" : "Kembali", style: const TextStyle(fontSize: 18))
          ),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.blue.shade200)),
          child: StreamBuilder<DatabaseEvent>(
            stream: FirebaseDatabase.instance.ref('walk_ins').onValue,
            builder: (context, snapshot) {
              int peopleWaiting = 0;
              int currentServing = 1000;
              int estWaitTime = 0;
              int? myQueueNo;

              if (snapshot.hasData && snapshot.data!.snapshot.value != null) {
                var dataMap = snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
                List<dynamic> docs = [];
                dataMap.forEach((catKey, catData) {
                  if (catData is Map) {
                    for (var v in catData.values) {
                      if (v is Map && (v['timestamp'] ?? 0) >= startOfToday.millisecondsSinceEpoch) {
                        docs.add(v);
                      }
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

                var myActiveTickets = docs.where((map) {
                  return map['patient_id'] == widget.userId && (map['status'] == 'Waiting' || map['status'] == 'Serving');
                }).toList();

                if (myActiveTickets.isNotEmpty) {
                  myQueueNo = int.tryParse(myActiveTickets.first['queue_number'].toString());
                }
              }

              String servingText = currentServing > 1000 ? "$currentServing" : "--";
              String myQueueText = myQueueNo != null ? "$myQueueNo" : "--";
              Color myQueueColor = myQueueNo != null ? Colors.green.shade700 : Colors.grey;

              return Column(
                children: [
                  Text(widget.isEnglish ? "LIVE CLINIC STATUS" : "STATUS KLINIK LANGSUNG", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF133F85))),
                  const SizedBox(height: 15),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildStatusItem(widget.isEnglish ? "YOUR TICKET" : "TIKET ANDA", myQueueText, myQueueColor),
                      Container(width: 2, height: 60, color: Colors.blue.shade200),
                      _buildStatusItem(widget.isEnglish ? "CURRENT SERVING" : "SEDANG DILAYANI", servingText, const Color(0xFF133F85)),
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
                      spacing: 20,
                      runSpacing: 20,
                      alignment: WrapAlignment.center,
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
                    Text(
                      widget.isEnglish 
                          ? "Pusat Kesihatan UniMAP is currently closed.\nPlease come again during operating hours." 
                          : "Pusat Kesihatan UniMAP ditutup pada masa ini.\nSila datang lagi pada waktu operasi.",
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.redAccent, height: 1.4),
                    ),
                    const SizedBox(height: 15),
                    Text(
                      widget.isEnglish
                          ? "Operating Hours:\nMon - Thu (8:00 AM - 1:00 PM, 2:00 PM - 5:00 PM)\nFri (8:00 AM - 12:15 PM, 2:45 PM - 5:00 PM)\nClosed on Weekends & 2nd/4th Friday"
                          : "Waktu Operasi:\nIsnin - Kha (8:00 Pagi - 1:00 Ptg, 2:00 Ptg - 5:00 Ptg)\nJum (8:00 Pagi - 12:15 Tgh, 2:45 Ptg - 5:00 Ptg)\nDitutup pada Hujung Minggu & Jumaat ke-2/ke-4",
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16, color: Colors.blueGrey, fontWeight: FontWeight.bold, height: 1.4),
                    ),
                  ]
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusItem(String label, String value, Color valColor) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
        const SizedBox(height: 5),
        Text(value, style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: valColor)),
      ],
    );
  }

  Widget _triageCard(String title, IconData icon, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: 250, height: 120,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade300, width: 2), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)]),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: const Color(0xFF133F85), size: 35), 
            const SizedBox(height: 10), 
            Text(title, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF133F85)))
          ],
        ),
      ),
    );
  }

  Future<void> _handleWalkInSubmission(String reason) async {
    showDialog(context: context, barrierDismissible: false, builder: (c) => const Center(child: CircularProgressIndicator()));
    
    await _expireOldAndSkippedTickets();

    final activeTicketQuery = await FirebaseDatabase.instance.ref('walk_ins').once();

    if (mounted) Navigator.of(context, rootNavigator: true).pop();

    if (activeTicketQuery.snapshot.exists) {
      var map = activeTicketQuery.snapshot.value as Map<dynamic, dynamic>;
      DateTime now = DateTime.now();
      DateTime startOfToday = DateTime(now.year, now.month, now.day);
      int startOfTodayMs = startOfToday.millisecondsSinceEpoch;

      var activeTickets = [];
      map.forEach((catKey, catData) {
        if (catData is Map) {
          for (var v in catData.values) {
            if (v is Map) {
              bool isSameUser = v['patient_id'] == widget.userId;
              if (widget.isGuest && widget.guestPhone != null && widget.guestPhone!.isNotEmpty) {
                if (v['phone'] == widget.guestPhone) {
                  isSameUser = true;
                }
              }
              if (isSameUser) {
                bool isActive = v['status'] == 'Waiting' || v['status'] == 'Serving';
                bool isToday = (v['timestamp'] ?? 0) >= startOfTodayMs;
                if (isActive && isToday) activeTickets.add(v);
              }
            }
          }
        }
      });
      if (activeTickets.isNotEmpty) {
        final existingNo = activeTickets.first['queue_number'];
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (c) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            title: Text(widget.isEnglish ? "Active Ticket Found" : "Tiket Aktif Ditemui", style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            content: Text(widget.isEnglish ? "You already have an active ticket (#$existingNo) waiting to be called.\n\nPlease wait for your turn before requesting a new ticket." : "Anda sudah mempunyai tiket aktif (#$existingNo) yang menunggu untuk dipanggil.\n\nSila tunggu giliran anda sebelum meminta tiket baharu.", style: const TextStyle(fontSize: 16)),
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF133F85), foregroundColor: Colors.white),
                onPressed: () => Navigator.pop(c),
                child: Text(widget.isEnglish ? "OK" : "OK"),
              )
            ],
          )
        );
        return;
      }
    }

    if (widget.isGuest) {
      _generateWalkInTicket(name: "GUEST", id: widget.userId, reason: reason, phone: widget.guestPhone);
    } else {
      _generateWalkInTicket(name: widget.userName, id: widget.userId, reason: reason);
    }
  }

  Future<void> _generateWalkInTicket({required String name, required String id, required String reason, String? phone, String? email}) async {
    showDialog(context: context, barrierDismissible: false, builder: (c) => const Center(child: CircularProgressIndicator()));

    int queueNumber = 1000;
    bool success = false;
    String errMsg = "";

    try {
      DateTime now = DateTime.now();
      DateTime startOfToday = DateTime(now.year, now.month, now.day);
      
      String categoryNode = "other";
      int baseNumber = 4000;
      if (reason.contains("Fever") || reason.contains("Demam")) {
        categoryNode = "fever_flu_cough";
        baseNumber = 1000;
      } else if (reason.contains("Physical") || reason.contains("Fizikal") || reason.contains("Injury") || reason.contains("Kesakitan")) {
        categoryNode = "physical_injury";
        baseNumber = 2000;
      } else if (reason.contains("Follow") || reason.contains("Susulan") || reason.contains("Review") || reason.contains("Semakan")) {
        categoryNode = "follow_up";
        baseNumber = 3000;
      }

      var snapshotEvent = await FirebaseDatabase.instance.ref('walk_ins').child(categoryNode)
          .orderByChild('timestamp')
          .startAt(startOfToday.millisecondsSinceEpoch)
          .once();

      int maxQueueNo = baseNumber;
      if (snapshotEvent.snapshot.exists) {
        var map = snapshotEvent.snapshot.value as Map<dynamic, dynamic>;
        for (var v in map.values) {
          if (v is Map && v['queue_number'] != null) {
            int qn = int.tryParse(v['queue_number'].toString()) ?? baseNumber;
            if (qn > maxQueueNo) {
              maxQueueNo = qn;
            }
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
      if (email != null) walkInData['email'] = email.toString();

      await FirebaseDatabase.instance.ref('walk_ins').child(categoryNode).push().set(walkInData);
      success = true;
    } catch (e) { errMsg = e.toString(); }

    if (mounted) Navigator.of(context, rootNavigator: true).pop();

    if (success && mounted) {
      _showQueueNumberDialog(queueNumber, name, reason);
    } else if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(widget.isEnglish ? "Error generating ticket: $errMsg" : "Ralat menjana tiket: $errMsg")));
    }
  }

  void _showQueueNumberDialog(int queueNo, String name, String reason) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.all(30),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 60),
            const SizedBox(height: 15),
            Text(widget.isEnglish ? "WALK-IN TICKET GENERATED" : "TIKET WALK-IN DIJANA", style: const TextStyle(fontSize: 18, color: Colors.black54, fontWeight: FontWeight.bold)),
            Text("$queueNo", style: const TextStyle(fontSize: 80, fontWeight: FontWeight.bold, color: Color(0xFF133F85))),
            Text(widget.isEnglish ? "Reason: $reason" : "Sebab: $reason", style: const TextStyle(fontSize: 16, color: Colors.black87)),
            const SizedBox(height: 30),
            Text(widget.isEnglish ? "Do you want to continue using the kiosk or log out?" : "Adakah anda ingin terus menggunakan kiosk atau log keluar?", textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 25),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  onPressed: () { Navigator.pop(c); _autoLogOut(); },
                  child: Text(widget.isEnglish ? "LOG OUT" : "LOG KELUAR", style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16)),
                ),
                const SizedBox(width: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF133F85), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12)),
                  onPressed: () { Navigator.pop(c); setState(() => _currentView = "HOME"); },
                  child: Text(widget.isEnglish ? "CONTINUE" : "TERUSKAN", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildDepartmentSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(onPressed: () => setState(() => _currentView = "SEE_DOCTOR_OPT"), icon: const Icon(Icons.arrow_back, size: 28,), label: Text(widget.isEnglish ? "Back" : "Kembali", style: const TextStyle(fontSize: 18))),
        ),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(widget.isEnglish ? "Select Department for Appointment" : "Pilih Jabatan untuk Temu Janji", style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF133F85))),
              const SizedBox(height: 40),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _osiCard(widget.isEnglish ? "DENTAL CARE" : "PENJAGAAN GIGI", Icons.medical_services, onTap: () => _preCheckAppointment(widget.isEnglish ? "Dental Care" : "Penjagaan Gigi")),
                  const SizedBox(width: 40),
                  _osiCard(widget.isEnglish ? "PHYSIOTHERAPY" : "FISIOTERAPI", Icons.accessibility_new, onTap: () => _preCheckAppointment(widget.isEnglish ? "Physiotherapy" : "Fisioterapi")),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _preCheckAppointment(String dept) async {
    showDialog(context: context, barrierDismissible: false, builder: (c) => const Center(child: CircularProgressIndicator()));

    DateTime now = DateTime.now();
    var q = await FirebaseDatabase.instance.ref('appointments').once();
    
    bool hasActive = false;
    int consecutiveExpired = 0;
    List<Map<dynamic, dynamic>> userAppts = [];

    if (q.snapshot.exists) {
      var map = q.snapshot.value as Map<dynamic, dynamic>;
      for (var deptKey in map.keys) {
        var deptData = map[deptKey];
        if (deptData is Map) {
          for (var key in deptData.keys) {
            var v = deptData[key];
            if (v is Map) {
              if (v['status'] == 'Booked') {
                try {
                  DateTime parsedTime = DateFormat('hh:mm a').parse(v['time']);
                  DateTime parsedDate = DateFormat('yyyy-MM-dd').parse(v['date']);
                  DateTime apptDT = DateTime(parsedDate.year, parsedDate.month, parsedDate.day, parsedTime.hour, parsedTime.minute);
                  
                  if (apptDT.isBefore(now)) {
                    v['status'] = 'Expired';
                    FirebaseDatabase.instance.ref('appointments').child(deptKey.toString()).child(key.toString()).update({'status': 'Expired'});
                  }
                } catch (e) {}
              }

              if (v['patient_id'] == widget.userId) {
                userAppts.add(v);
                if (v['status'] == 'Booked') {
                  hasActive = true;
                }
              }
            }
          }
        }
      }
    }

    userAppts.sort((a, b) => (b['timestamp'] ?? 0).compareTo(a['timestamp'] ?? 0));

    for (var appt in userAppts) {
      if (appt['status'] == 'Expired' || appt['status'] == 'Cancelled') {
        consecutiveExpired++;
      } else if (appt['status'] == 'Booked') {
        continue;
      } else {
        break; 
      }
    }

    if (mounted) Navigator.of(context, rootNavigator: true).pop();

    if (consecutiveExpired >= 3) {
      showDialog(
        context: context,
        builder: (c) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.block, color: Colors.red),
              const SizedBox(width: 10),
              Text(widget.isEnglish ? "Booking Blocked" : "Tempahan Disekat", style: const TextStyle(color: Colors.red)),
            ],
          ),
          content: Text(widget.isEnglish 
            ? "You have missed or cancelled 3 consecutive appointments.\nYou are forbidden from making another appointment through the kiosk. Please make your appointment directly at the clinic." 
            : "Anda telah tidak hadir atau membatalkan 3 temu janji berturut-turut.\nAnda dilarang membuat temu janji lain melalui kiosk. Sila buat temu janji anda secara terus di klinik.",
            style: const TextStyle(fontSize: 16)
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(c), 
              child: const Text("OK")
            )
          ]
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
          content: Text(widget.isEnglish ? "You already have an active appointment. Do you still want to proceed?" : "Anda sudah mempunyai temu janji aktif. Adakah anda masih mahu meneruskan?"),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c), child: Text(widget.isEnglish ? "Go Back" : "Kembali")),
            ElevatedButton(onPressed: () { 
              Navigator.pop(c); 
              if (consecutiveExpired > 0) {
                _showExpiredWarningAndProceed(dept, consecutiveExpired);
              } else {
                _handleDeptClick(dept); 
              }
            }, child: Text(widget.isEnglish ? "Proceed anyway" : "Teruskan juga")),
          ],
        ),
      );
    } else {
      if (consecutiveExpired > 0) {
        _showExpiredWarningAndProceed(dept, consecutiveExpired);
      } else {
        _handleDeptClick(dept);
      }
    }
  }

  void _showExpiredWarningAndProceed(String dept, int missedCount) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.orange),
            const SizedBox(width: 10),
            Text(widget.isEnglish ? "Warning: Missed/Cancelled Appointments" : "Amaran: Temu Janji Terlepas/Dibatalkan", style: const TextStyle(color: Colors.orange)),
          ],
        ),
        content: Text(widget.isEnglish 
          ? "You have $missedCount consecutive missed/cancelled appointment(s).\nMissing 3 appointments consecutively will forbid you from making future appointments through the kiosk."
          : "Anda mempunyai $missedCount temu janji terlepas/dibatalkan berturut-turut.\nTidak hadir 3 temu janji berturut-turut akan melarang anda daripada membuat temu janji masa depan melalui kiosk.",
          style: const TextStyle(fontSize: 16)
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: Text(widget.isEnglish ? "Cancel" : "Batal")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF133F85), foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(c);
              _handleDeptClick(dept);
            }, 
            child: Text(widget.isEnglish ? "I Understand, Proceed" : "Saya Faham, Teruskan")
          ),
        ]
      )
    );
  }

  void _handleDeptClick(String dept) async {
    String? result = await Navigator.push(context, MaterialPageRoute(builder: (c) => AppointmentPage(
      department: dept, userName: widget.userName.toUpperCase(), userId: widget.userId, isGuest: false,
      onLogOut: _autoLogOut, isEnglish: widget.isEnglish,
    )));
    if (result == "HOME" && mounted) {
      setState(() => _currentView = "HOME");
    }
  }

  InputDecoration _dropdownDecor() {
    return InputDecoration(
      filled: true,
      fillColor: Colors.grey.shade100,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(5), borderSide: BorderSide(color: Colors.grey.shade300)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(5), borderSide: BorderSide(color: Colors.grey.shade300)),
    );
  }

  Widget _buildDateDropdownRow(
    String title, 
    String? day, String? month, String? year,
    ValueChanged<String?> onDayChanged,
    ValueChanged<String?> onMonthChanged,
    ValueChanged<String?> onYearChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blueGrey)),
        const SizedBox(height: 5),
        Row(
          children: [
            Expanded(flex: 2, child: DropdownButtonFormField<String>(decoration: _dropdownDecor(), hint: Text(widget.isEnglish ? "Day" : "Hari", style: const TextStyle(fontSize: 12)), initialValue: day, items: _daysList.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 12)))).toList(), onChanged: onDayChanged, validator: (v) => v == null ? (widget.isEnglish ? "Req" : "Perlu") : null)),
            const SizedBox(width: 5),
            Expanded(flex: 4, child: DropdownButtonFormField<String>(decoration: _dropdownDecor(), hint: Text(widget.isEnglish ? "Month" : "Bulan", style: const TextStyle(fontSize: 12)), initialValue: month, items: _monthsList.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 12)))).toList(), onChanged: onMonthChanged, validator: (v) => v == null ? (widget.isEnglish ? "Req" : "Perlu") : null)),
            const SizedBox(width: 5),
            Expanded(flex: 3, child: DropdownButtonFormField<String>(decoration: _dropdownDecor(), hint: Text(widget.isEnglish ? "Year" : "Tahun", style: const TextStyle(fontSize: 12)), initialValue: year, items: _yearsList.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 12)))).toList(), onChanged: onYearChanged, validator: (v) => v == null ? (widget.isEnglish ? "Req" : "Perlu") : null)),
          ],
        ),
      ],
    );
  }

  Widget _buildEquipmentForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () {
              _selectedEquip = null; _selectedQuantity = null; _selectedLoanReason = null;
              _sDay = null; _sMonth = null; _sYear = null;
              _eDay = null; _eMonth = null; _eYear = null;
              setState(() => _currentView = "HOME");
            }, 
            icon: const Icon(Icons.arrow_back, size: 28), 
            label: Text(widget.isEnglish ? "Back" : "Kembali", style: const TextStyle(fontSize: 18))
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(vertical: 10), 
          child: Text(widget.isEnglish ? "Medical Equipment Reservation Request" : "Permohonan Tempahan Peralatan Perubatan", style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF133F85)))
        ),
        Expanded(
          child: SingleChildScrollView(
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(border: Border.all(color: Colors.black12), borderRadius: BorderRadius.circular(10)),
              child: Form(
                key: _equipFKey,
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 2,
                          child: DropdownButtonFormField<String>(
                              decoration: InputDecoration(labelText: widget.isEnglish ? "Equipment Type" : "Jenis Peralatan", border: const OutlineInputBorder()),
                              items: _equipList.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                              initialValue: _selectedEquip,
                              onChanged: (v) => _selectedEquip = v,
                              validator: (v) => v == null ? (widget.isEnglish ? "Please select equipment" : "Sila pilih peralatan") : null,
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          flex: 1,
                          child: DropdownButtonFormField<String>(
                              decoration: InputDecoration(labelText: widget.isEnglish ? "Quantity" : "Kuantiti", border: const OutlineInputBorder()),
                              items: ["1", "2", "3", "4", "5", "6", "7", "8", "9", "10"].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                              initialValue: _selectedQuantity,
                              onChanged: (v) => _selectedQuantity = v,
                              validator: (v) => v == null ? (widget.isEnglish ? "Required" : "Perlu") : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 25),
                    
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _buildDateDropdownRow(widget.isEnglish ? "START DATE" : "TARIKH MULA", _sDay, _sMonth, _sYear, (v) => setState(() => _sDay = v), (v) => setState(() => _sMonth = v), (v) => setState(() => _sYear = v)),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: _buildDateDropdownRow(widget.isEnglish ? "END DATE" : "TARIKH TAMAT", _eDay, _eMonth, _eYear, (v) => setState(() => _eDay = v), (v) => setState(() => _eMonth = v), (v) => setState(() => _eYear = v)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 25),
                    
                    DropdownButtonFormField<String>(
                      decoration: InputDecoration(labelText: widget.isEnglish ? "Reason for Loan" : "Sebab Pinjaman", border: const OutlineInputBorder()),
                      items: _loanReasons.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                      initialValue: _selectedLoanReason,
                      onChanged: (v) => _selectedLoanReason = v,
                      validator: (v) => v == null ? (widget.isEnglish ? "Please select a reason" : "Sila pilih sebab") : null,
                    ),
                    const SizedBox(height: 30),
                    
                    Center(
                      child: SizedBox(
                        height: 60,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF133F85), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 50)),
                          onPressed: () {
                            if (_equipFKey.currentState!.validate()) {
                            
                            int startMonthIndex = _monthsList.indexOf(_sMonth!) + 1;
                            int endMonthIndex = _monthsList.indexOf(_eMonth!) + 1;
                            DateTime startDate; DateTime endDate;

                            try {
                              startDate = DateTime(int.parse(_sYear!), startMonthIndex, int.parse(_sDay!));
                              endDate = DateTime(int.parse(_eYear!), endMonthIndex, int.parse(_eDay!));
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(widget.isEnglish ? "Invalid date selected." : "Tarikh tidak sah dipilih.")));
                              return;
                            }

                            if (endDate.isBefore(startDate)) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(widget.isEnglish ? "Error: End Date cannot be before Start Date." : "Ralat: Tarikh Tamat tidak boleh sebelum Tarikh Mula.")));
                              return;
                            }

                            String displayDateRange = "${DateFormat('dd MMM yyyy').format(startDate)}  -  ${DateFormat('dd MMM yyyy').format(endDate)}";

                            showDialog(
                              context: context,
                              builder: (c) => AlertDialog(
                                title: Text(widget.isEnglish ? "Confirm Reservation" : "Sahkan Tempahan"),
                                content: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(widget.isEnglish 
                                      ? "Reserve ${_selectedQuantity}x $_selectedEquip from\n$displayDateRange?" 
                                      : "Tempah ${_selectedQuantity}x $_selectedEquip dari\n$displayDateRange?"
                                    ),
                                    const SizedBox(height: 20),
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.orange.shade50,
                                        border: Border.all(color: Colors.orange.shade200),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 24),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              widget.isEnglish 
                                                ? "Important: Any damages to the equipment or late returns will incur penalty fees charged directly to your student account." 
                                                : "Penting: Sebarang kerosakan pada peralatan atau pemulangan lewat akan mengakibatkan bayaran denda dikenakan ke atas akaun pelajar anda.",
                                              style: TextStyle(fontSize: 14, color: Colors.orange.shade900, fontWeight: FontWeight.w500),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(c), child: Text(widget.isEnglish ? "Back" : "Kembali")),
                                  ElevatedButton(
                                    onPressed: () async {
                                      Navigator.pop(c); 
                                      
                                      Map<String, dynamic> reservationData = {
                                        'item': _selectedEquip,
                                        'quantity': _selectedQuantity,
                                        'start_date': DateFormat('yyyy-MM-dd').format(startDate),
                                        'end_date': DateFormat('yyyy-MM-dd').format(endDate),
                                        'reason': _selectedLoanReason,
                                        'patient_name': widget.userName.toUpperCase(),
                                        'patient_id': widget.userId,
                                        'status': 'Pending',
                                        'timestamp': ServerValue.timestamp
                                      };
        
                                      await FirebaseDatabase.instance.ref('reservations').push().set(reservationData);
        
                                      String recipientEmail = "s${widget.userId}@studentmail.unimap.edu.my";
                                      await sendEmailJSEmail(
                                        templateId: 'template_aaoznaf',
                                        templateParams: {
                                          'to_email': recipientEmail,
                                          'patient_name': widget.userName.toUpperCase(),
                                          'item': '$_selectedQuantity x $_selectedEquip',
                                          'duration': displayDateRange,
                                        },
                                      );
        
                                      _selectedEquip = null; _selectedQuantity = null; _selectedLoanReason = null;
                                      _sDay = null; _sMonth = null; _sYear = null;
                                      _eDay = null; _eMonth = null; _eYear = null;
                                      
                                      _showPostActionDialog(context, () {
                                        setState(() => _currentView = "HOME");
                                      });
                                    },
                                    child: Text(widget.isEnglish ? "Confirm" : "Sahkan"),
                                  ),
                                ],
                              ),
                            );
                          }
                          },
                          child: Text(widget.isEnglish ? "SUBMIT REQUEST" : "HANTAR PERMOHONAN", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ]);
    }

  Widget _buildReservationHistory() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(onPressed: () => setState(() => _currentView = "HOME"), icon: const Icon(Icons.arrow_back), label: Text(widget.isEnglish ? "Back" : "Kembali")),
        ),
        Padding(
          padding: EdgeInsets.symmetric(vertical: 10),
          child: Text(widget.isEnglish ? "EQUIPMENT RESERVATION STATUS" : "STATUS TEMPAHAN PERALATAN", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF133F85))),
        ),
        Expanded(
          child: StreamBuilder<DatabaseEvent>(
            stream: FirebaseDatabase.instance
                .ref('reservations')
                .orderByChild('patient_id')
                .equalTo(widget.userId)
                .onValue,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              if (!snapshot.hasData || snapshot.data!.snapshot.value == null) return Center(child: Text(widget.isEnglish ? "No reservation history found." : "Tiada sejarah tempahan ditemui."));
              var dataMap = snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
              var docs = dataMap.values.toList();
              docs.sort((a, b) => (b['timestamp'] ?? 0).compareTo(a['timestamp'] ?? 0));
              return ListView.builder(
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  var data = docs[index] as Map<dynamic, dynamic>;
                  String status = data['status'] ?? "Pending";
                  Color sc = status == "Approved" ? Colors.green : (status == "Returned" ? Colors.blue : (status == "Overdue" ? Colors.red : Colors.orange));
                  
                  String displayStatus = status;
                  if (status == 'Pending' && !widget.isEnglish) {
                    displayStatus = 'Menunggu';
                  } else if (status == 'Approved' && !widget.isEnglish) displayStatus = 'Diluluskan';
                  else if (status == 'Returned' && !widget.isEnglish) displayStatus = 'Dipulangkan';
                  else if (status == 'Overdue' && !widget.isEnglish) displayStatus = 'Lewat';

                  String subtitleText = widget.isEnglish ? "Awaiting dates" : "Menunggu tarikh";
                  if (data.containsKey('start_date') && data.containsKey('end_date')) {
                     subtitleText = widget.isEnglish ? "From: ${data['start_date']}  To: ${data['end_date']}" : "Dari: ${data['start_date']}  Hingga: ${data['end_date']}";
                  }

                  return Card(
                    elevation: 2,
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      leading: Icon(Icons.medical_information, color: sc, size: 30),
                      title: Text(data.containsKey('quantity') ? "${data['quantity']}x ${data['item']}" : (data['item'] ?? "Equipment"), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      subtitle: Text(subtitleText),
                      trailing: Text(displayStatus, style: TextStyle(color: sc, fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAppointmentHistory() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(onPressed: () => setState(() => _currentView = "HOME"), icon: const Icon(Icons.arrow_back), label: Text(widget.isEnglish ? "Back" : "Kembali")),
        ),
        Padding(
          padding: EdgeInsets.symmetric(vertical: 10),
          child: Text(widget.isEnglish ? "APPOINTMENTS" : "TEMU JANJI", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF133F85))),
        ),
        Expanded(
          child: StreamBuilder<DatabaseEvent>(
            stream: FirebaseDatabase.instance.ref('appointments').onValue,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              if (!snapshot.hasData || snapshot.data!.snapshot.value == null) return Center(child: Text(widget.isEnglish ? "No records found." : "Tiada rekod ditemui."));
              var dataMap = snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
              List<Map<String, dynamic>> docs = [];
              dataMap.forEach((deptKey, deptData) {
                if (deptData is Map) {
                  deptData.forEach((key, value) {
                    if (value is Map && value['patient_id'] == widget.userId) {
                      var map = Map<String, dynamic>.from(value);
                      map['id'] = key;
                      map['deptNode'] = deptKey;
                      docs.add(map);
                    }
                  });
                }
              });
              docs.sort((a, b) => (b['timestamp'] ?? 0).compareTo(a['timestamp'] ?? 0));

              int consecutiveMissed = 0;
              for (var appt in docs) {
                if (appt['status'] == 'Expired' || appt['status'] == 'Cancelled') {
                  consecutiveMissed++;
                } else if (appt['status'] == 'Booked') {
                  continue;
                } else {
                  break;
                }
              }

              return ListView.builder(
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  var data = docs[index];
                  String status = data['status'] ?? "Booked";
                  
                  String displayStatus = status;
                  if (status == 'Booked' && !widget.isEnglish) {
                    displayStatus = 'Ditempah';
                  } else if (status == 'Cancelled' && !widget.isEnglish) {
                    displayStatus = 'Dibatalkan';
                  } else if (status == 'Expired' && !widget.isEnglish) {
                    displayStatus = 'Tamat Tempoh';
                  }
                  
                  return Card(
                    elevation: 2,
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      leading: const Icon(Icons.calendar_today, size: 30),
                      title: Text(data['department'] ?? "Clinic", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      subtitle: Text("${data['date']} | ${data['time']}"),
                      trailing: status == "Booked"
                          ? ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                              onPressed: () => _showCancelConfirmation(data['id'], data['deptNode'], consecutiveMissed),
                              child: Text(widget.isEnglish ? "Cancel" : "Batal")
                            )
                          : Text(displayStatus, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  void _showCancelConfirmation(String id, String deptNode, int consecutiveMissed) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(widget.isEnglish ? "Cancel Appointment" : "Batalkan Temu Janji"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.isEnglish ? "Are you sure you want to cancel this appointment?" : "Adakah anda pasti mahu membatalkan temu janji ini?"),
            if (consecutiveMissed > 0) ...[
              const SizedBox(height: 15),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.orange.shade200)),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 24),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(widget.isEnglish
                        ? "Warning: You have $consecutiveMissed consecutive missed/cancelled appointment(s). Cancelling this will increase your streak. Reaching 3 will block you from future bookings."
                        : "Amaran: Anda mempunyai $consecutiveMissed temu janji terlepas/dibatalkan berturut-turut. Membatalkan ini akan meningkatkan rekod anda. Mencapai 3 akan menyekat anda dari tempahan masa depan.",
                        style: TextStyle(color: Colors.orange.shade900, fontSize: 14, fontWeight: FontWeight.w500)
                      ),
                    )
                  ]
                )
              )
            ]
          ]
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: Text(widget.isEnglish ? "No" : "Tidak")),
          ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white), onPressed: () { Navigator.pop(c); _cancelAppt(id, deptNode); }, child: Text(widget.isEnglish ? "Yes, Cancel" : "Ya, Batal")),
        ],
      ),
    );
  }

  Future<void> _cancelAppt(String id, String deptNode) async {
    await FirebaseDatabase.instance.ref('appointments').child(deptNode).child(id).update({'status': 'Cancelled'});
  }

  Widget _buildCheckupHistory() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(onPressed: () => setState(() => _currentView = "HOME"), icon: const Icon(Icons.arrow_back), label: Text(widget.isEnglish ? "Back" : "Kembali")),
        ),
        Padding(
          padding: EdgeInsets.symmetric(vertical: 10),
          child: Text(widget.isEnglish ? "CHECKUP HISTORY" : "SEJARAH PEMERIKSAAN", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF133F85))),
        ),
        Expanded(
          child: StreamBuilder<DatabaseEvent>(
            stream: FirebaseDatabase.instance
                .ref('checkups')
                .orderByChild('patient_id')
                .equalTo(widget.userId)
                .onValue,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              if (!snapshot.hasData || snapshot.data!.snapshot.value == null) return Center(child: Text(widget.isEnglish ? "No records found." : "Tiada rekod ditemui."));
              var dataMap = snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
              var docs = dataMap.values.toList();
              docs.sort((a, b) => (b['timestamp'] ?? 0).compareTo(a['timestamp'] ?? 0));
              return ListView.builder(
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  var data = docs[index] as Map<dynamic, dynamic>;
                  return Card(
                    elevation: 2,
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      leading: const Icon(Icons.monitor_heart, color: Colors.red, size: 30), 
                      title: Text("Temp: ${data['temp']}°C | BPM: ${data['heart_rate']}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))
                    )
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTopBar() {
    return Container(
      height: 70,
      padding: const EdgeInsets.symmetric(horizontal: 25),
      decoration: const BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)]),
      child: Row(
        children: [
          InkWell(
            onTap: () => setState(() => _currentView = "HOME"),
            child: Row(
              children: [
                const Icon(Icons.health_and_safety, color: Color(0xFF133F85), size: 35),
                const SizedBox(width: 15),
                const Text("SMART HEALTH KIOSK", style: TextStyle(color: Color(0xFF133F85), fontWeight: FontWeight.bold, fontSize: 20, letterSpacing: 1.2)),
              ],
            ),
          ),
          const Spacer(),
          Text(widget.userName.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(width: 15),
          const CircleAvatar(radius: 20, backgroundColor: Colors.orange, child: Icon(Icons.person, color: Colors.white, size: 24)),
          const SizedBox(width: 25),
          Container(height: 40, width: 1.5, color: Colors.grey.shade300),
          const SizedBox(width: 25),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade50, foregroundColor: Colors.red.shade800, elevation: 0),
            icon: const Icon(Icons.power_settings_new),
            label: Text(widget.isEnglish ? "LOG OUT" : "LOG KELUAR", style: const TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () => _autoLogOut(), 
          )
        ],
      ),
    );
  }

  Widget _buildEmergencyButton() {
    return EmergencyHelpButton(
      isEnglish: widget.isEnglish,
      patientName: widget.userName.toUpperCase(),
      patientId: widget.userId,
      location: 'Kiosk Main',
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    return Listener(
      onPointerDown: (_) => _resetIdleTimer(),
      onPointerMove: (_) => _resetIdleTimer(),
      child: Scaffold(
        body: Column(
          children: [
            _buildTopBar(),
            Expanded(child: Padding(padding: const EdgeInsets.all(25), child: _getContent())),
            if (!isKeyboardOpen) _buildEmergencyButton(),
          ],
        ),
      ),
    );
  }

  Widget _osiCard(String t, IconData i, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: 250, height: 200,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200, width: 2), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)]),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [Icon(i, color: const Color(0xFF133F85), size: 50), const SizedBox(height: 20), Text(t, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF133F85)))],
        ),
      ),
    );
  }
}