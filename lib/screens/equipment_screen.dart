import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:ui';
import 'package:firebase_database/firebase_database.dart';
import '../services/email_service.dart';
import 'package:table_calendar/table_calendar.dart';

class EquipmentScreen extends StatefulWidget {
  final String userId;
  final String userName;
  final bool isEnglish;
  final VoidCallback onBack;
  final VoidCallback onLogOut;

  const EquipmentScreen({
    super.key,
    required this.userId,
    required this.userName,
    required this.isEnglish,
    required this.onBack,
    required this.onLogOut,
  });

  @override
  State<EquipmentScreen> createState() => _EquipmentScreenState();
}

class _EquipmentScreenState extends State<EquipmentScreen> {
  String? _selectedEquip;
  String? _selectedQuantity;
  String? _selectedLoanReason;
  final GlobalKey<FormState> _equipFKey = GlobalKey<FormState>();
  String? _sDay;
  String? _sMonth;
  String? _sYear;
  String? _eDay;
  String? _eMonth;
  String? _eYear;


  List<String> get _monthsList => widget.isEnglish
      ? [
          'January',
          'February',
          'March',
          'April',
          'May',
          'June',
          'July',
          'August',
          'September',
          'October',
          'November',
          'December',
        ]
      : [
          'Januari',
          'Februari',
          'Mac',
          'April',
          'Mei',
          'Jun',
          'Julai',
          'Ogos',
          'September',
          'Oktober',
          'November',
          'Disember',
        ];
  List<String> get _loanReasons => widget.isEnglish
      ? [
          'Post-Surgery Recovery',
          'Chronic Condition',
          'Temporary Injury',
          'Follow-up Treatment',
          'Other',
        ]
      : [
          'Pemulihan Selepas Pembedahan',
          'Keadaan Kronik',
          'Kecederaan Sementara',
          'Rawatan Susulan',
          'Lain-lain',
        ];
  List<String> get _equipList => widget.isEnglish
      ? [
          "Wheelchair",
          "Crutches",
          "Nebulizer",
          "First Aid Kit",
          "Anatomical Model",
          "Digital Thermometer",
          "Blood Pressure Cuff",
        ]
      : [
          "Kerusi Roda",
          "Tongkat",
          "Nebulizer",
          "Peti Pertolongan Cemas",
          "Model Anatomi",
          "Termometer Digital",
          "Alat Tekanan Darah",
        ];

  Widget _buildFieldSelector(String label, String? value, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: Colors.lightBlueAccent.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              value ?? label,
              style: TextStyle(
                color: value == null ? Colors.white54 : Colors.white,
                fontSize: 16,
              ),
            ),
            const Icon(Icons.arrow_drop_down, color: Colors.lightBlueAccent),
          ],
        ),
      ),
    );
  }

  void _showBottomSheetSelector({
    required String title,
    required List<String> options,
    required ValueChanged<String> onSelected,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(25),
            topRight: Radius.circular(25),
          ),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.5,
              ),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0A2249), Color(0xFF133F85)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                border: Border(
                  top: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.white38,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(height: 15),
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.lightBlueAccent,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: ListView.builder(
                      itemCount: options.length,
                      itemBuilder: (context, index) {
                        final option = options[index];
                        return ListTile(
                          title: Text(
                            option,
                            style: const TextStyle(color: Colors.white),
                          ),
                          tileColor: Colors.white.withValues(alpha: 0.02),
                          onTap: () {
                            onSelected(option);
                            Navigator.pop(context);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<DateTime?> _showTouchFriendlyDatePicker(
    BuildContext context, {
    required DateTime initialDate,
    required DateTime firstDate,
  }) async {
    return showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        DateTime focusedDay = initialDate;
        DateTime? selectedDay = initialDate;

        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.90,
              decoration: const BoxDecoration(
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(25),
                  topRight: Radius.circular(25),
                ),
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(25),
                  topRight: Radius.circular(25),
                ),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                  child: Container(
                    padding: EdgeInsets.only(
                      bottom: MediaQuery.of(context).padding.bottom + 16,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0A2249), Color(0xFF133F85)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      border: Border(
                        top: BorderSide(
                          color: const Color(0xFF0EA5E9).withValues(alpha: 0.8),
                          width: 1,
                        ),
                      ),
                    ),
                    child: Column(
                      children: [
                        const SizedBox(height: 15),
                        Container(
                          width: 50,
                          height: 5,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          widget.isEnglish ? "Select Date" : "Pilih Tarikh",
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: TableCalendar(
                              firstDay: firstDate,
                              lastDay: DateTime.now().add(
                                const Duration(days: 365),
                              ),
                              focusedDay: focusedDay,
                              selectedDayPredicate: (day) =>
                                  isSameDay(selectedDay, day),
                              shouldFillViewport: true,
                              daysOfWeekHeight: 60.0,
                              availableGestures:
                                  AvailableGestures.horizontalSwipe,
                              headerStyle: const HeaderStyle(
                                formatButtonVisible: false,
                                titleCentered: true,
                                titleTextStyle: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                                leftChevronIcon: Icon(
                                  Icons.chevron_left,
                                  color: Colors.lightBlueAccent,
                                  size: 36,
                                ),
                                rightChevronIcon: Icon(
                                  Icons.chevron_right,
                                  color: Colors.lightBlueAccent,
                                  size: 36,
                                ),
                              ),
                              calendarStyle: CalendarStyle(
                                defaultTextStyle: const TextStyle(
                                  fontSize: 22,
                                  color: Colors.white,
                                ),
                                weekendTextStyle: const TextStyle(
                                  fontSize: 22,
                                  color: Colors.white70,
                                ),
                                outsideTextStyle: const TextStyle(
                                  fontSize: 18,
                                  color: Colors.white38,
                                ),
                                disabledTextStyle: const TextStyle(
                                  fontSize: 18,
                                  color: Colors.white38,
                                ),
                                todayDecoration: BoxDecoration(
                                  border: Border.all(
                                    color: Colors.lightBlueAccent,
                                    width: 2,
                                  ),
                                  shape: BoxShape.circle,
                                ),
                                todayTextStyle: const TextStyle(
                                  fontSize: 22,
                                  color: Colors.lightBlueAccent,
                                  fontWeight: FontWeight.bold,
                                ),
                                selectedDecoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF0EA5E9),
                                      Color(0xFF1B64F2),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  shape: BoxShape.rectangle,
                                ),
                                selectedTextStyle: const TextStyle(
                                  fontSize: 24,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              daysOfWeekStyle: const DaysOfWeekStyle(
                                weekdayStyle: TextStyle(
                                  fontSize: 18,
                                  color: Colors.white70,
                                ),
                                weekendStyle: TextStyle(
                                  fontSize: 18,
                                  color: Colors.white54,
                                ),
                              ),
                              onDaySelected: (selected, focused) {
                                setSheetState(() {
                                  selectedDay = selected;
                                  focusedDay = focused;
                                });
                                Future.delayed(
                                  const Duration(milliseconds: 250),
                                  () {
                                    if (mounted && context.mounted) {
                                      Navigator.pop(context, selectedDay);
                                    }
                                  },
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _selectDate(BuildContext context, bool isStart) async {
    final DateTime now = DateTime.now();
    DateTime firstDate = DateTime(now.year, now.month, now.day);
    DateTime initialDate = firstDate;

    if (!isStart && _sDay != null && _sMonth != null && _sYear != null) {
      int startMonthIndex = _monthsList.indexOf(_sMonth!) + 1;
      firstDate = DateTime(
        int.parse(_sYear!),
        startMonthIndex,
        int.parse(_sDay!),
      );
      initialDate = firstDate;
    }

    final DateTime? picked = await _showTouchFriendlyDatePicker(
      context,
      initialDate: initialDate,
      firstDate: firstDate,
    );

    if (picked != null) {
      setState(() {
        if (isStart) {
          _sDay = picked.day.toString();
          _sMonth = _monthsList[picked.month - 1];
          _sYear = picked.year.toString();

          if (_eDay != null && _eMonth != null && _eYear != null) {
            int endMonthIndex = _monthsList.indexOf(_eMonth!) + 1;
            DateTime endDate = DateTime(
              int.parse(_eYear!),
              endMonthIndex,
              int.parse(_eDay!),
            );
            if (endDate.isBefore(picked)) {
              _eDay = null;
              _eMonth = null;
              _eYear = null;
            }
          }
        } else {
          _eDay = picked.day.toString();
          _eMonth = _monthsList[picked.month - 1];
          _eYear = picked.year.toString();
        }
      });
    }
  }

  Widget _buildDateFieldRow(String title, bool isStart) {
    String? day = isStart ? _sDay : _eDay;
    String? month = isStart ? _sMonth : _eMonth;
    String? year = isStart ? _sYear : _eYear;
    String displayDate = (day != null && month != null && year != null)
        ? "$day $month $year"
        : (widget.isEnglish ? "Select Date" : "Pilih Tarikh");

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: Colors.lightBlueAccent,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 10),
        InkWell(
          onTap: () => _selectDate(context, isStart),
          borderRadius: BorderRadius.circular(15),
          child: Container(
            constraints: const BoxConstraints(minHeight: 64),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: Colors.lightBlueAccent.withValues(alpha: 0.5),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  displayDate,
                  style: TextStyle(
                    color: (day != null && month != null && year != null)
                        ? Colors.white
                        : Colors.white54,
                    fontSize: 18,
                  ),
                ),
                const Icon(
                  Icons.calendar_month_outlined,
                  color: Colors.lightBlueAccent,
                  size: 28,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: widget.onBack,
            icon: const Icon(
              Icons.arrow_back,
              size: 28,
              color: Colors.lightBlueAccent,
            ),
            label: Text(
              widget.isEnglish ? "Back" : "Kembali",
              style: const TextStyle(fontSize: 18, color: Colors.lightBlueAccent),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 15),
          child: Text(
            widget.isEnglish
                ? "Medical Equipment Reservation"
                : "Permohonan Tempahan Peralatan Perubatan",
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              shadows: [
                Shadow(
                  color: Colors.lightBlueAccent.withValues(alpha: 0.5),
                  blurRadius: 10,
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                child: Container(
                  padding: const EdgeInsets.all(35),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Form(
                    key: _equipFKey,
                    child: Column(
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 2,
                              child: _buildFieldSelector(
                                widget.isEnglish
                                    ? "Equipment Type"
                                    : "Jenis Peralatan",
                                _selectedEquip,
                                () => _showBottomSheetSelector(
                                  title: widget.isEnglish
                                      ? "Select Equipment Type"
                                      : "Pilih Jenis Peralatan",
                                  options: _equipList,
                                  onSelected: (v) =>
                                      setState(() => _selectedEquip = v),
                                ),
                              ),
                            ),
                            const SizedBox(width: 25),
                            Expanded(
                              flex: 1,
                              child: _buildFieldSelector(
                                widget.isEnglish ? "Quantity" : "Kuantiti",
                                _selectedQuantity,
                                () => _showBottomSheetSelector(
                                  title: widget.isEnglish
                                      ? "Select Quantity"
                                      : "Pilih Kuantiti",
                                  options: ["1", "2", "3", "4", "5"],
                                  onSelected: (v) =>
                                      setState(() => _selectedQuantity = v),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 35),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _buildDateFieldRow(
                                widget.isEnglish ? "START DATE" : "TARIKH MULA",
                                true,
                              ),
                            ),
                            const SizedBox(width: 35),
                            Expanded(
                              child: _buildDateFieldRow(
                                widget.isEnglish ? "END DATE" : "TARIKH TAMAT",
                                false,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 35),
                        _buildFieldSelector(
                          widget.isEnglish
                              ? "Reason for Loan"
                              : "Sebab Pinjaman",
                          _selectedLoanReason,
                          () => _showBottomSheetSelector(
                            title: widget.isEnglish
                                ? "Select Reason"
                                : "Pilih Sebab",
                            options: _loanReasons,
                            onSelected: (v) =>
                                setState(() => _selectedLoanReason = v),
                          ),
                        ),
                        const SizedBox(height: 50),
                        Center(
                          child: SizedBox(
                            height: 65,
                            width: 350,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.lightBlueAccent.withValues(
                                  alpha: 0.1,
                                ),
                                foregroundColor: Colors.lightBlueAccent,
                                side: BorderSide(
                                  color: Colors.lightBlueAccent.withValues(
                                    alpha: 0.5,
                                  ),
                                  width: 1.5,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 50,
                                ),
                              ),
                              onPressed: () {
                                if (_selectedEquip != null &&
                                    _selectedQuantity != null &&
                                    _sDay != null &&
                                    _eDay != null &&
                                    _selectedLoanReason != null) {
                                  int startMonthIndex =
                                      _monthsList.indexOf(_sMonth!) + 1;
                                  int endMonthIndex =
                                      _monthsList.indexOf(_eMonth!) + 1;
                                  DateTime startDate = DateTime(
                                    int.parse(_sYear!),
                                    startMonthIndex,
                                    int.parse(_sDay!),
                                  );
                                  DateTime endDate = DateTime(
                                    int.parse(_eYear!),
                                    endMonthIndex,
                                    int.parse(_eDay!),
                                  );

                                  if (endDate.isBefore(startDate)) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        backgroundColor: Colors.redAccent,
                                        content: Text(
                                          "Error: End Date cannot be before Start Date.",
                                          style: TextStyle(color: Colors.white),
                                        ),
                                      ),
                                    );
                                    return;
                                  }

                                  String displayDateRange =
                                      "${DateFormat('dd MMM yyyy').format(startDate)}  -  ${DateFormat('dd MMM yyyy').format(endDate)}";
                                  showDialog(
                                    context: context,
                                    builder: (c) => AlertDialog(
                                      backgroundColor: const Color(0xFF133F85),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(15),
                                        side: BorderSide(
                                          color: Colors.lightBlueAccent.withValues(
                                            alpha: 0.5,
                                          ),
                                        ),
                                      ),
                                      title: Text(
                                        widget.isEnglish
                                            ? "Confirm Reservation"
                                            : "Sahkan Tempahan",
                                        style: const TextStyle(
                                          color: Colors.lightBlueAccent,
                                        ),
                                      ),
                                      content: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            "Reserve ${_selectedQuantity}x $_selectedEquip from\n$displayDateRange?",
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ],
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(c),
                                          child: Text(
                                            widget.isEnglish
                                                ? "Back"
                                                : "Kembali",
                                            style: const TextStyle(
                                              color: Colors.white70,
                                            ),
                                          ),
                                        ),
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.lightBlueAccent
                                                .withValues(alpha: 0.2),
                                            foregroundColor: Colors.lightBlueAccent,
                                            side: const BorderSide(
                                              color: Colors.lightBlueAccent,
                                            ),
                                          ),
                                          onPressed: () async {
                                            Navigator.pop(c);
                                            final ctx = context;
                                            await FirebaseDatabase.instance
                                                .ref('reservations')
                                                .push()
                                                .set({
                                                  'item': _selectedEquip,
                                                  'quantity': _selectedQuantity,
                                                  'start_date': DateFormat(
                                                    'yyyy-MM-dd',
                                                  ).format(startDate),
                                                  'end_date': DateFormat(
                                                    'yyyy-MM-dd',
                                                  ).format(endDate),
                                                  'reason': _selectedLoanReason,
                                                  'patient_name': widget
                                                      .userName
                                                      .toUpperCase(),
                                                  'patient_id': widget.userId,
                                                  'status': 'Pending',
                                                  'timestamp':
                                                      ServerValue.timestamp,
                                                });
                                            await sendEmailJSEmail(
                                              templateId: 'template_aaoznaf',
                                              templateParams: {
                                                'to_email':
                                                    "s${widget.userId}@studentmail.unimap.edu.my",
                                                'patient_name': widget.userName
                                                    .toUpperCase(),
                                                'item':
                                                    '$_selectedQuantity x $_selectedEquip',
                                                'duration': displayDateRange,
                                              },
                                            );
                                            if (mounted && ctx.mounted) {
                                              showDialog(
                                                context: ctx,
                                                barrierDismissible: false,
                                                builder: (c2) => AlertDialog(
                                                  backgroundColor: const Color(
                                                    0xFF133F85,
                                                  ),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          15,
                                                        ),
                                                    side: const BorderSide(
                                                      color: Colors.green,
                                                    ),
                                                  ),
                                                  title: const Text(
                                                    "Success!",
                                                    style: TextStyle(
                                                      color: Colors.green,
                                                    ),
                                                  ),
                                                  content: const Text(
                                                    "Your request has been successfully processed.\nContinue or Log Out?",
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 16,
                                                    ),
                                                  ),
                                                  actions: [
                                                    TextButton(
                                                      onPressed: () {
                                                        Navigator.pop(c2);
                                                        widget.onLogOut();
                                                      },
                                                      child: const Text(
                                                        "LOG OUT",
                                                        style: TextStyle(
                                                          color:
                                                              Colors.redAccent,
                                                        ),
                                                      ),
                                                    ),
                                                    ElevatedButton(
                                                      style: ElevatedButton.styleFrom(
                                                        backgroundColor: Colors
                                                            .greenAccent
                                                            .withValues(
                                                              alpha: 0.2,
                                                            ),
                                                        foregroundColor:
                                                            Colors.green,
                                                        side: const BorderSide(
                                                          color: Colors
                                                              .greenAccent,
                                                        ),
                                                      ),
                                                      onPressed: () {
                                                        Navigator.pop(c2);
                                                        widget.onBack();
                                                      },
                                                      child: const Text(
                                                        "CONTINUE",
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            }
                                          },
                                          child: Text(
                                            widget.isEnglish
                                                ? "Confirm"
                                                : "Sahkan",
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }
                              },
                              child: Text(
                                widget.isEnglish
                                    ? "SUBMIT REQUEST"
                                    : "HANTAR PERMOHONAN",
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
