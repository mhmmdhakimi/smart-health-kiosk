import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:intl/intl.dart';
import 'package:firebase_database/firebase_database.dart';
import '../services/email_service.dart';

class AppointmentPage extends StatefulWidget {
  final String department;
  final String userName;
  final String userId;
  final bool isGuest;
  final String? guestPhone;
  final String? guestEmail;
  final VoidCallback onLogOut;
  final bool isEnglish;

  const AppointmentPage({super.key, required this.department, required this.userName, required this.userId, required this.isGuest, this.guestPhone, this.guestEmail, required this.onLogOut, required this.isEnglish});
  @override
  State<AppointmentPage> createState() => _AppointmentPageState();
}

class _AppointmentPageState extends State<AppointmentPage> {
  late DateTime today, fDate;
  DateTime? selDate;
  String? selTime;
  List<String> booked = [];
  bool hasActive = false;

  Timer? _idleTimer;
  Timer? _warningTimer;
  bool _isWarningDialogVisible = false;

  @override
  void initState() {
    super.initState();
    today = DateTime.now();
    fDate = DateTime(today.year, today.month, 1);
    _checkExistingBookings();
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
    _warningTimer = Timer(const Duration(seconds: 15), () {
      if (_isWarningDialogVisible && mounted) {
        Navigator.of(context, rootNavigator: true).pop(); 
      }
      widget.onLogOut(); 
    });

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

  Future<void> _checkExistingBookings() async {
    DateTime now = DateTime.now();
    var q = await FirebaseDatabase.instance.ref('appointments').once();
    bool active = false;
    if (q.snapshot.exists) {
      var map = q.snapshot.value as Map<dynamic, dynamic>;
      for (var deptKey in map.keys) {
        var deptData = map[deptKey];
        if (deptData is Map) {
          for (var key in deptData.keys) {
            var v = deptData[key];
            if (v is Map && v['status'] == 'Booked') {
              try {
                DateTime parsedTime = DateFormat('hh:mm a').parse(v['time']);
                DateTime parsedDate = DateFormat('yyyy-MM-dd').parse(v['date']);
                DateTime apptDT = DateTime(parsedDate.year, parsedDate.month, parsedDate.day, parsedTime.hour, parsedTime.minute);
                
                if (apptDT.isBefore(now)) {
                  v['status'] = 'Expired';
                  FirebaseDatabase.instance.ref('appointments').child(deptKey.toString()).child(key.toString()).update({'status': 'Expired'});
                }
              } catch (e) {}

              if (v['patient_id'] == widget.userId && v['status'] == 'Booked') {
                active = true;
              }
            }
          }
        }
      }
    }
    if (mounted) setState(() => hasActive = active);
  }

  Future<void> _fetchBookedSlots(DateTime d) async {
    String s = DateFormat('yyyy-MM-dd').format(d);
    String deptNode = widget.department.contains("Dental") || widget.department.contains("Gigi") ? "dental_care" : "physiotherapy";
    var q = await FirebaseDatabase.instance.ref('appointments').child(deptNode).orderByChild('date').equalTo(s).once();
    List<String> b = [];
    if (q.snapshot.exists) {
      var map = q.snapshot.value as Map<dynamic, dynamic>;
      b = map.values
          .where((v) => v['department'] == widget.department && v['status'] == 'Booked')
          .map((v) => v['time'] as String)
          .toList();
    }
    setState(() => booked = b);
  }

  bool _isPastTime(String timeString) {
    if (selDate == null) return false;
    DateTime now = DateTime.now();
    if (selDate!.year == now.year && selDate!.month == now.month && selDate!.day == now.day) {
      try {
        String timeStr = timeString.replaceAll('\u202F', ' ');
        DateTime parsedTime = DateFormat('h:mm a').parse(timeStr);
        DateTime slotDT = DateTime(selDate!.year, selDate!.month, selDate!.day, parsedTime.hour, parsedTime.minute);
        return slotDT.isBefore(now);
      } catch (e) { return false; }
    }
    return false;
  }

  Widget _buildTopBar() {
    return Container(
      height: 70,
      padding: const EdgeInsets.symmetric(horizontal: 25),
      decoration: const BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)]),
      child: Row(
        children: [
          InkWell(
            onTap: () {
              Navigator.pop(context, "HOME");
            },
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
            onPressed: widget.onLogOut,
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _resetIdleTimer(),
      onPointerMove: (_) => _resetIdleTimer(),
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FB),
        body: Column(
          children: [
            _buildTopBar(),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(25),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextButton.icon(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back, size: 28), label: Text(widget.isEnglish ? "Back" : "Kembali", style: const TextStyle(fontSize: 18))),
                    Padding(
                      padding: const EdgeInsets.only(top: 10, bottom: 20),
                      child: Row(
                        children: [
                          Text(widget.isEnglish ? "Schedule Appointment" : "Jadual Temu Janji", style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF133F85))),
                          if (hasActive) ...[
                            const SizedBox(width: 20),
                            Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(10)), child: Text(widget.isEnglish ? "Active booking detected. Viewing mode only." : "Tempahan aktif dikesan. Mod tontonan sahaja.", style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),
                          ]
                        ],
                      ),
                    ),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 5))]),
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          children: [
                            Expanded(flex: 4, child: Column(children: [_buildCalendarHeader(), const SizedBox(height: 10), Expanded(child: _buildCalendarGrid())])),
                            Container(width: 1, color: Colors.grey.shade200, margin: const EdgeInsets.symmetric(horizontal: 20)),
                            Expanded(flex: 5, child: _buildTimeSlotSection()),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildConfirmButton(),
                  ],
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  bool _isClinicClosedDay(DateTime dt) {
    if (dt.weekday == 6 || dt.weekday == 7) return true;
    if (dt.weekday == 5) {
      int weekOfMonth = ((dt.day - 1) / 7).floor() + 1;
      if (weekOfMonth == 2 || weekOfMonth == 4) return true;
    }
    return false;
  }

  Widget _buildCalendarHeader() {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      IconButton(icon: const Icon(Icons.chevron_left, size: 30, color: Color(0xFF133F85)), onPressed: () => setState(() => fDate = DateTime(fDate.year, fDate.month - 1))),
      Text(DateFormat('MMMM yyyy').format(fDate), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF133F85))),
      IconButton(icon: const Icon(Icons.chevron_right, size: 30, color: Color(0xFF133F85)), onPressed: () => setState(() => fDate = DateTime(fDate.year, fDate.month + 1))),
    ]);
  }

  Widget _buildCalendarGrid() {
    int days = DateTime(fDate.year, fDate.month + 1, 0).day;
    DateTime first = DateTime(fDate.year, fDate.month, 1);
    
    List<Widget> dayHeaders = ["M", "T", "W", "T", "F", "S", "S"].map((d) => Expanded(child: Center(child: Text(d, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))))).toList();
    
    return Column(
      children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: dayHeaders),
        const SizedBox(height: 10),
        Expanded(
          child: GridView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: days + (first.weekday - 1), gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, childAspectRatio: 1.4), itemBuilder: (c, index) {
            int day = index - (first.weekday - 1) + 1;
            if (day <= 0) return const SizedBox.shrink();
            DateTime dt = DateTime(fDate.year, fDate.month, day);
            bool isDisabled = dt.isBefore(DateTime(today.year, today.month, today.day)) || _isClinicClosedDay(dt);
            bool isSelected = selDate != null && selDate!.day == day && selDate!.month == fDate.month;
            return GestureDetector(
              onTap: isDisabled ? null : () { setState(() { selDate = dt; selTime = null; }); _fetchBookedSlots(dt); },
              child: Container(margin: const EdgeInsets.all(4), decoration: BoxDecoration(color: isSelected ? const Color(0xFF133F85) : Colors.transparent, shape: BoxShape.circle), child: Center(child: Text("$day", style: TextStyle(fontSize: 14, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isDisabled ? Colors.grey.shade300 : (isSelected ? Colors.white : Colors.black87))))),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildTimeSlotSection() {
    if (selDate == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_note, size: 60, color: Colors.grey.shade300),
            const SizedBox(height: 15),
            Text(widget.isEnglish ? "Select a date to view slots" : "Pilih tarikh untuk melihat slot", style: TextStyle(color: Colors.grey.shade500, fontSize: 16)),
          ],
        ),
      );
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.isEnglish ? "Available Slots" : "Slot Tersedia", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF133F85))),
        const SizedBox(height: 5),
        Text(DateFormat('EEEE, dd MMM yyyy').format(selDate!), style: const TextStyle(color: Colors.blueGrey, fontSize: 14)),
        const SizedBox(height: 20),
        Expanded(
          child: GridView.count(
            crossAxisCount: 3, 
            childAspectRatio: 2.0, 
            mainAxisSpacing: 10, 
            crossAxisSpacing: 10, 
            children: _generateSlots(selDate).map((time) {
              bool isB = booked.contains(time), isP = _isPastTime(time);
              bool isS = selTime == time;
              Color bgColor = isB || isP ? Colors.grey.shade100 : (isS ? const Color(0xFF133F85) : Colors.blue.shade50);
              Color textColor = isB || isP ? Colors.grey.shade400 : (isS ? Colors.white : const Color(0xFF133F85));
              
              return InkWell(
                onTap: (isB || isP) ? null : () => setState(() => selTime = time),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(10), border: Border.all(color: isS ? const Color(0xFF133F85) : Colors.transparent)),
                  child: Center(child: Text(isB ? (widget.isEnglish ? "BOOKED" : "DITEMPAH") : time, style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 13))),
                ),
              );
            }).toList()
          ),
        ),
      ],
    );
  }

  Widget _buildConfirmButton() {
    bool can = selDate != null && selTime != null && !hasActive;
    return Center(
      child: SizedBox(
        height: 60, 
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 50),
            backgroundColor: can ? const Color(0xFF133F85) : Colors.grey.shade300, 
            foregroundColor: can ? Colors.white : Colors.grey.shade600,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: can ? 4 : 0,
          ), 
          onPressed: can ? _showConf : null, 
          child: Text(widget.isEnglish ? "CONFIRM APPOINTMENT" : "SAHKAN TEMU JANJI", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.0))
        )
      ),
    );
  }

  void _showConf() {
    showDialog(context: context, builder: (c) => AlertDialog(title: Text(widget.isEnglish ? "Confirm" : "Sahkan"), content: Text(widget.isEnglish ? "Book for ${DateFormat('dd MMM yyyy').format(selDate!)} at $selTime?" : "Tempah untuk ${DateFormat('dd MMM yyyy').format(selDate!)} pada $selTime?"), actions: [TextButton(onPressed: () => Navigator.pop(c), child: Text(widget.isEnglish ? "Back" : "Kembali")), ElevatedButton(onPressed: () { Navigator.pop(c); _sub(); }, child: Text(widget.isEnglish ? "Confirm" : "Sahkan"))]));
  }

  void _sub() async {
    String d = DateFormat('yyyy-MM-dd').format(selDate!);
    Map<String, dynamic> data = {
      'department': widget.department, 
      'date': d, 
      'time': selTime, 
      'status': 'Booked', 
      'patient_name': widget.userName, 
      'patient_id': widget.userId, 
      'doctor_name': 'not assigned yet',
      'timestamp': ServerValue.timestamp
    };
    
    String deptNode = widget.department.contains("Dental") || widget.department.contains("Gigi") ? "dental_care" : "physiotherapy";
    await FirebaseDatabase.instance.ref('appointments').child(deptNode).push().set(data);
    
    String recipientEmail = "s${widget.userId}@studentmail.unimap.edu.my";
    await sendEmailJSEmail(templateId: 'template_lt0jtlj', templateParams: {'to_email': recipientEmail, 'patient_name': widget.userName, 'department': widget.department, 'date': d, 'time': selTime});
    
    if (mounted) {
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
                widget.onLogOut(); 
              },
              child: Text(widget.isEnglish ? "LOG OUT" : "LOG KELUAR", style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF133F85), foregroundColor: Colors.white),
              onPressed: () {
                Navigator.pop(c); 
                Navigator.pop(context, "HOME"); 
              },
              child: Text(widget.isEnglish ? "CONTINUE" : "TERUSKAN", style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    }
  }

  List<String> _generateSlots(DateTime? d) {
    if (d == null) return [];
    List<String> s = []; 
    
    if (d.weekday == 5) {
      DateTime t = DateTime(d.year, d.month, d.day, 8, 0); 
      while (t.hour < 12 || (t.hour == 12 && t.minute == 0)) { 
        s.add(DateFormat('hh:mm a').format(t)); 
        t = t.add(const Duration(minutes: 30)); 
      }
      t = DateTime(d.year, d.month, d.day, 14, 45); 
      while (t.hour < 17) { 
        s.add(DateFormat('hh:mm a').format(t)); 
        t = t.add(const Duration(minutes: 30)); 
      }
    } else {
      DateTime t = DateTime(d.year, d.month, d.day, 8, 0); 
      while (t.hour < 17) { 
        if ((t.hour >= 8 && t.hour < 13) || (t.hour >= 14 && t.hour < 17)) {
          s.add(DateFormat('hh:mm a').format(t)); 
        }
        t = t.add(const Duration(minutes: 30)); 
      }
    }
    return s;
  }
}

class PhoneInputFormatter extends TextInputFormatter {
  @override TextEditingValue formatEditUpdate(TextEditingValue old, TextEditingValue newVal) {
    String t = newVal.text.replaceAll('-', ''); if (t.length > 11) return old;
    String f = ""; for (int i = 0; i < t.length; i++) { f += t[i]; if (i == 2 && t.length > 3) f += "-"; }
    return TextEditingValue(text: f, selection: TextSelection.collapsed(offset: f.length));
  }
}