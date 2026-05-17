import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'package:intl/intl.dart';
import 'package:firebase_database/firebase_database.dart';
import '../services/email_service.dart';

class AppointmentPage extends StatefulWidget {
  final String userName;
  final String userId;
  final bool isGuest;
  final String? guestPhone;
  final String? guestEmail;
  final VoidCallback onLogOut;
  final VoidCallback onBack;
  final bool isEnglish;

  const AppointmentPage({
    super.key,
    required this.userName,
    required this.userId,
    required this.isGuest,
    this.guestPhone,
    this.guestEmail,
    required this.onLogOut,
    required this.onBack,
    required this.isEnglish,
  });

  @override
  State<AppointmentPage> createState() => _AppointmentPageState();
}

class _AppointmentPageState extends State<AppointmentPage> {
  String? selectedService;
  DateTime? selectedDate;
  String? selectedTime;

  late DateTime today, fDate;
  List<String> booked = [];
  bool hasActive = false;

  @override
  void initState() {
    super.initState();
    today = DateTime.now();
    fDate = DateTime(today.year, today.month, 1);
    _checkExistingBookings();
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
              if (v['patient_id'] == widget.userId) {
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
    if (selectedService == null) return;
    String s = DateFormat('yyyy-MM-dd').format(d);
    String deptNode = selectedService == "Dental"
        ? "dental_care"
        : "physiotherapy";
    var q = await FirebaseDatabase.instance
        .ref('appointments')
        .child(deptNode)
        .orderByChild('date')
        .equalTo(s)
        .once();
    List<String> b = [];
    if (q.snapshot.exists) {
      var map = q.snapshot.value as Map<dynamic, dynamic>;
      b = map.values
          .where((v) => v['status'] == 'Booked')
          .map((v) => v['time'] as String)
          .toList();
    }
    setState(() => booked = b);
  }

  bool _isPastTime(String timeString) {
    if (selectedDate == null) return false;
    DateTime now = DateTime.now();
    if (selectedDate!.year == now.year &&
        selectedDate!.month == now.month &&
        selectedDate!.day == now.day) {
      try {
        String timeStr = timeString.replaceAll('\u202F', ' ');
        DateTime parsedTime = DateFormat('h:mm a').parse(timeStr);
        DateTime slotDT = DateTime(
          selectedDate!.year,
          selectedDate!.month,
          selectedDate!.day,
          parsedTime.hour,
          parsedTime.minute,
        );
        return slotDT.isBefore(now);
      } catch (e) {
        return false;
      }
    }
    return false;
  }

  bool _isClinicClosedDay(DateTime dt) {
    if (dt.weekday == 6 || dt.weekday == 7) return true;
    if (dt.weekday == 5) {
      int weekOfMonth = ((dt.day - 1) / 7).floor() + 1;
      if (weekOfMonth == 2 || weekOfMonth == 4) return true;
    }
    return false;
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

  void _showConf() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Dismiss",
      pageBuilder: (context, animation, secondaryAnimation) {
        return Scaffold(
          backgroundColor: Colors.black.withOpacity(0.5),
          body: Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  width: 500,
                  padding: const EdgeInsets.all(40),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Colors.cyanAccent.withOpacity(0.5),
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.event_available,
                        size: 80,
                        color: Colors.cyanAccent,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        widget.isEnglish
                            ? "Confirm Booking"
                            : "Sahkan Tempahan",
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.cyanAccent,
                        ),
                      ),
                      const SizedBox(height: 30),
                      Text(
                        "Service: $selectedService",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        "Date: ${DateFormat('dd MMM yyyy').format(selectedDate!)}",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        "Time: $selectedTime",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                        ),
                      ),
                      const SizedBox(height: 40),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 20,
                                ),
                                side: BorderSide(
                                  color: Colors.white.withOpacity(0.3),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                              ),
                              onPressed: () => Navigator.pop(context),
                              child: Text(
                                widget.isEnglish ? "CANCEL" : "BATAL",
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 20,
                                ),
                                backgroundColor: Colors.cyanAccent.withOpacity(
                                  0.2,
                                ),
                                side: const BorderSide(
                                  color: Colors.cyanAccent,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                              ),
                              onPressed: () {
                                Navigator.pop(context);
                                _sub();
                              },
                              child: Text(
                                widget.isEnglish ? "CONFIRM" : "SAHKAN",
                                style: const TextStyle(
                                  color: Colors.cyanAccent,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _sub() async {
    String d = DateFormat('yyyy-MM-dd').format(selectedDate!);
    Map<String, dynamic> data = {
      'department': selectedService == "Dental"
          ? (widget.isEnglish ? "Dental Care" : "Penjagaan Gigi")
          : "Physiotherapy",
      'date': d,
      'time': selectedTime,
      'status': 'Booked',
      'patient_name': widget.userName,
      'patient_id': widget.userId,
      'doctor_name': 'not assigned yet',
      'timestamp': ServerValue.timestamp,
    };

    String deptNode = selectedService == "Dental"
        ? "dental_care"
        : "physiotherapy";
    await FirebaseDatabase.instance
        .ref('appointments')
        .child(deptNode)
        .push()
        .set(data);

    String recipientEmail = "s${widget.userId}@studentmail.unimap.edu.my";
    await sendEmailJSEmail(
      templateId: 'template_lt0jtlj',
      templateParams: {
        'to_email': recipientEmail,
        'patient_name': widget.userName,
        'department': data['department'],
        'date': d,
        'time': selectedTime,
      },
    );

    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (c) => AlertDialog(
          backgroundColor: const Color(0xFF111827),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
            side: const BorderSide(color: Colors.greenAccent),
          ),
          title: Text(
            widget.isEnglish ? "Success!" : "Berjaya!",
            style: const TextStyle(
              color: Colors.greenAccent,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            widget.isEnglish
                ? "Your request has been successfully processed.\n\nDo you want to continue using the kiosk or log out?"
                : "Permintaan anda telah berjaya diproses.\n\nAdakah anda ingin terus menggunakan kiosk atau log keluar?",
            style: const TextStyle(fontSize: 16, color: Colors.white),
          ),
          actions: [
            TextButton(
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
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.cyanAccent.withOpacity(0.2),
                foregroundColor: Colors.cyanAccent,
                side: const BorderSide(color: Colors.cyanAccent),
              ),
              onPressed: () {
                Navigator.pop(c);
                widget.onBack();
              },
              child: Text(
                widget.isEnglish ? "CONTINUE" : "TERUSKAN",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );
    }
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
            icon: const Icon(
              Icons.arrow_back,
              size: 28,
              color: Colors.cyanAccent,
            ),
            label: Text(
              widget.isEnglish ? "Back" : "Kembali",
              style: const TextStyle(fontSize: 18, color: Colors.cyanAccent),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Text(
                widget.isEnglish ? "Schedule Appointment" : "Jadual Temu Janji",
                style: TextStyle(
                  fontSize: 32,
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
              if (hasActive) ...[
                const SizedBox(width: 25),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                      color: Colors.redAccent.withOpacity(0.5),
                    ),
                  ),
                  child: Text(
                    widget.isEnglish
                        ? "Active booking detected. Viewing mode only."
                        : "Tempahan aktif dikesan. Mod tontonan sahaja.",
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left Panel (Flex: 3): Service Selector
              Expanded(
                flex: 3,
                child: Container(
                  margin: const EdgeInsets.only(right: 15),
                  padding: const EdgeInsets.all(25),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.isEnglish
                            ? "Select Service"
                            : "Pilih Perkhidmatan",
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 30),
                      _buildServiceToggle(
                        "Dental",
                        Icons.medical_services_outlined,
                      ),
                      const SizedBox(height: 20),
                      _buildServiceToggle(
                        "Physiotherapy",
                        Icons.accessibility_new_outlined,
                      ),
                    ],
                  ),
                ),
              ),

              // Center Panel (Flex: 5): Calendar Widget
              Expanded(
                flex: 5,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 15),
                  padding: const EdgeInsets.all(25),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: Column(
                    children: [
                      _buildCalendarHeader(),
                      const SizedBox(height: 20),
                      Expanded(child: _buildCalendarGrid()),
                    ],
                  ),
                ),
              ),

              // Right Panel (Flex: 4): Time Slots & Booking Action
              Expanded(
                flex: 4,
                child: Container(
                  margin: const EdgeInsets.only(left: 15),
                  padding: const EdgeInsets.all(25),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: _buildTimeSlotSection(),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildServiceToggle(String title, IconData icon) {
    bool isSelected = selectedService == title;
    return GestureDetector(
      onTap: () {
        setState(() {
          selectedService = title;
          selectedTime = null;
          if (selectedDate != null) _fetchBookedSlots(selectedDate!);
        });
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(20),
            constraints: const BoxConstraints(minHeight: 100),
            decoration: BoxDecoration(
              color: isSelected
                  ? Colors.cyan.withOpacity(0.1)
                  : Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFF06B6D4)
                    : Colors.white.withOpacity(0.1),
                width: isSelected ? 2 : 1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: const Color(0xFF06B6D4).withOpacity(0.3),
                        blurRadius: 15,
                      ),
                    ]
                  : [],
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 40,
                  color: isSelected ? Colors.cyanAccent : Colors.white54,
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Text(
                    title == "Dental"
                        ? (widget.isEnglish ? "Dental Care" : "Penjagaan Gigi")
                        : (widget.isEnglish ? "Physiotherapy" : "Fisioterapi"),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.cyanAccent : Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCalendarHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          icon: const Icon(
            Icons.chevron_left,
            size: 44,
            color: Colors.cyanAccent,
          ),
          onPressed: () =>
              setState(() => fDate = DateTime(fDate.year, fDate.month - 1)),
        ),
        Text(
          DateFormat('MMMM yyyy').format(fDate).toUpperCase(),
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 1.5,
            shadows: [
              Shadow(color: Colors.cyanAccent.withOpacity(0.5), blurRadius: 10),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(
            Icons.chevron_right,
            size: 44,
            color: Colors.cyanAccent,
          ),
          onPressed: () =>
              setState(() => fDate = DateTime(fDate.year, fDate.month + 1)),
        ),
      ],
    );
  }

  Widget _buildCalendarGrid() {
    int days = DateTime(fDate.year, fDate.month + 1, 0).day;
    DateTime first = DateTime(fDate.year, fDate.month, 1);

    List<Widget> dayHeaders = ["M", "T", "W", "T", "F", "S", "S"]
        .map(
          (d) => Expanded(
            child: Center(
              child: Text(
                d,
                style: const TextStyle(
                  color: Colors.cyanAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        )
        .toList();

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: dayHeaders,
        ),
        const SizedBox(height: 15),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              double cellWidth = constraints.maxWidth / 7;
              double cellHeight = constraints.maxHeight / 6;
              double aspect = cellWidth / cellHeight;
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: days + (first.weekday - 1),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  childAspectRatio: aspect,
                ),
                itemBuilder: (c, index) {
                  int day = index - (first.weekday - 1) + 1;
                  if (day <= 0) return const SizedBox.shrink();
                  DateTime dt = DateTime(fDate.year, fDate.month, day);
                  bool isDisabled =
                      dt.isBefore(
                        DateTime(today.year, today.month, today.day),
                      ) ||
                      _isClinicClosedDay(dt);
                  bool isSelected =
                      selectedDate != null &&
                      selectedDate!.day == day &&
                      selectedDate!.month == fDate.month &&
                      selectedDate!.year == fDate.year;
                  bool isToday =
                      dt.year == today.year &&
                      dt.month == today.month &&
                      dt.day == today.day;

                  return GestureDetector(
                    onTap: isDisabled
                        ? null
                        : () {
                            setState(() {
                              selectedDate = dt;
                              selectedTime = null;
                            });
                            _fetchBookedSlots(dt);
                          },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.all(4),
                      constraints: const BoxConstraints(
                        minWidth: 44,
                        minHeight: 44,
                      ),
                      decoration: BoxDecoration(
                        gradient: isSelected
                            ? const LinearGradient(
                                colors: [Color(0xFF06B6D4), Color(0xFF1B64F2)],
                              )
                            : null,
                        color: isSelected
                            ? null
                            : (isDisabled
                                  ? Colors.transparent
                                  : Colors.white.withOpacity(0.05)),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                          color: isSelected
                              ? Colors.transparent
                              : (isToday
                                    ? Colors.tealAccent
                                    : Colors.transparent),
                          width: isToday && !isSelected ? 2 : 0,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: Colors.cyanAccent.withOpacity(0.4),
                                  blurRadius: 10,
                                ),
                              ]
                            : [],
                      ),
                      child: Center(
                        child: Text(
                          "$day",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: isDisabled ? Colors.white38 : Colors.white,
                          ),
                        ),
                      ),
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

  Widget _buildTimeSlotSection() {
    if (selectedDate == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.event_note,
              size: 80,
              color: Colors.white.withOpacity(0.2),
            ),
            const SizedBox(height: 20),
            Text(
              widget.isEnglish
                  ? "Please select a date to view available slots."
                  : "Sila pilih tarikh untuk melihat slot.",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 18,
              ),
            ),
          ],
        ),
      );
    }

    bool canBook =
        selectedService != null &&
        selectedDate != null &&
        selectedTime != null &&
        !hasActive;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.isEnglish ? "AVAILABLE SLOTS" : "SLOT TERSEDIA",
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.cyanAccent,
            letterSpacing: 1.5,
            shadows: [
              Shadow(color: Colors.cyanAccent.withOpacity(0.5), blurRadius: 10),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          DateFormat('EEEE, dd MMM yyyy').format(selectedDate!),
          style: const TextStyle(color: Colors.white70, fontSize: 16),
        ),
        const SizedBox(height: 20),
        Expanded(
          child: GridView.count(
            crossAxisCount: 2,
            childAspectRatio: 2.5,
            mainAxisSpacing: 15,
            crossAxisSpacing: 15,
            children: _generateSlots(selectedDate).map((time) {
              bool isB = booked.contains(time), isP = _isPastTime(time);
              bool isS = selectedTime == time;
              Color borderColor = (isB || isP)
                  ? Colors.transparent
                  : (isS ? Colors.cyanAccent : Colors.white.withOpacity(0.1));
              Color bgColor = (isB || isP)
                  ? Colors.white12
                  : (isS
                        ? Colors.cyan.withOpacity(0.15)
                        : Colors.white.withOpacity(0.05));
              Color textColor = (isB || isP)
                  ? Colors.white38
                  : (isS ? Colors.cyanAccent : Colors.white);

              return InkWell(
                onTap: (isB || isP)
                    ? null
                    : () => setState(() => selectedTime = time),
                borderRadius: BorderRadius.circular(15),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  constraints: const BoxConstraints(
                    minWidth: 44,
                    minHeight: 44,
                  ),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: borderColor, width: isS ? 2 : 1),
                    boxShadow: isS
                        ? [
                            BoxShadow(
                              color: Colors.cyanAccent.withOpacity(0.3),
                              blurRadius: 10,
                            ),
                          ]
                        : [],
                  ),
                  child: Center(
                    child: Text(
                      isB ? (widget.isEnglish ? "BOOKED" : "DITEMPAH") : time,
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        decoration: (isB || isP)
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 65,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: canBook
                  ? Colors.cyanAccent.withOpacity(0.2)
                  : Colors.white.withOpacity(0.05),
              foregroundColor: canBook
                  ? Colors.cyanAccent
                  : Colors.white.withOpacity(0.3),
              side: BorderSide(
                color: canBook ? Colors.cyanAccent : Colors.transparent,
                width: 2,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            onPressed: canBook ? _showConf : null,
            child: Text(
              widget.isEnglish ? "BOOK APPOINTMENT" : "TEMPAH TEMU JANJI",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
                shadows: canBook
                    ? [
                        Shadow(
                          color: Colors.cyanAccent.withOpacity(0.8),
                          blurRadius: 10,
                        ),
                      ]
                    : [],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
