// lib/screens/equipment_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_database/firebase_database.dart';
import '../services/email_service.dart';

class EquipmentScreen extends StatefulWidget {
  final String userId;
  final String userName;
  final bool isEnglish;
  final VoidCallback onBack;
  final VoidCallback onLogOut;

  const EquipmentScreen({super.key, required this.userId, required this.userName, required this.isEnglish, required this.onBack, required this.onLogOut});

  @override
  State<EquipmentScreen> createState() => _EquipmentScreenState();
}

class _EquipmentScreenState extends State<EquipmentScreen> {
  String? _selectedEquip; String? _selectedQuantity; String? _selectedLoanReason;
  final GlobalKey<FormState> _equipFKey = GlobalKey<FormState>();
  String? _sDay; String? _sMonth; String? _sYear; 
  String? _eDay; String? _eMonth; String? _eYear; 

  final List<String> _daysList = List.generate(31, (i) => (i + 1).toString());
  final List<String> _yearsList = [DateTime.now().year.toString(), (DateTime.now().year + 1).toString()];
  List<String> get _monthsList => widget.isEnglish ? ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'] : ['Januari', 'Februari', 'Mac', 'April', 'Mei', 'Jun', 'Julai', 'Ogos', 'September', 'Oktober', 'November', 'Disember'];
  List<String> get _loanReasons => widget.isEnglish ? ['Post-Surgery Recovery', 'Chronic Condition', 'Temporary Injury', 'Follow-up Treatment', 'Other'] : ['Pemulihan Selepas Pembedahan', 'Keadaan Kronik', 'Kecederaan Sementara', 'Rawatan Susulan', 'Lain-lain'];
  List<String> get _equipList => widget.isEnglish ? ["Wheelchair", "Crutches", "Nebulizer", "First Aid Kit", "Anatomical Model", "Digital Thermometer", "Blood Pressure Cuff"] : ["Kerusi Roda", "Tongkat", "Nebulizer", "Peti Pertolongan Cemas", "Model Anatomi", "Termometer Digital", "Alat Tekanan Darah"];

  InputDecoration _dropdownDecor() {
    return InputDecoration(filled: true, fillColor: Colors.grey.shade100, contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), border: OutlineInputBorder(borderRadius: BorderRadius.circular(5), borderSide: BorderSide(color: Colors.grey.shade300)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(5), borderSide: BorderSide(color: Colors.grey.shade300)));
  }

  Widget _buildDateDropdownRow(String title, String? day, String? month, String? year, ValueChanged<String?> onDayChanged, ValueChanged<String?> onMonthChanged, ValueChanged<String?> onYearChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blueGrey)), const SizedBox(height: 5),
        Row(children: [
            Expanded(flex: 2, child: DropdownButtonFormField<String>(decoration: _dropdownDecor(), hint: Text(widget.isEnglish ? "Day" : "Hari", style: const TextStyle(fontSize: 12)), initialValue: day, items: _daysList.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 12)))).toList(), onChanged: onDayChanged, validator: (v) => v == null ? "*" : null)), const SizedBox(width: 5),
            Expanded(flex: 4, child: DropdownButtonFormField<String>(decoration: _dropdownDecor(), hint: Text(widget.isEnglish ? "Month" : "Bulan", style: const TextStyle(fontSize: 12)), initialValue: month, items: _monthsList.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 12)))).toList(), onChanged: onMonthChanged, validator: (v) => v == null ? "*" : null)), const SizedBox(width: 5),
            Expanded(flex: 3, child: DropdownButtonFormField<String>(decoration: _dropdownDecor(), hint: Text(widget.isEnglish ? "Year" : "Tahun", style: const TextStyle(fontSize: 12)), initialValue: year, items: _yearsList.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 12)))).toList(), onChanged: onYearChanged, validator: (v) => v == null ? "*" : null)),
          ]),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(alignment: Alignment.centerLeft, child: TextButton.icon(onPressed: widget.onBack, icon: const Icon(Icons.arrow_back, size: 28), label: Text(widget.isEnglish ? "Back" : "Kembali", style: const TextStyle(fontSize: 18)))),
        Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Text(widget.isEnglish ? "Medical Equipment Reservation Request" : "Permohonan Tempahan Peralatan Perubatan", style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF133F85)))),
        Expanded(
          child: SingleChildScrollView(
            child: Container(
              padding: const EdgeInsets.all(20), decoration: BoxDecoration(border: Border.all(color: Colors.black12), borderRadius: BorderRadius.circular(10)),
              child: Form(
                key: _equipFKey,
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 2, child: DropdownButtonFormField<String>(decoration: InputDecoration(labelText: widget.isEnglish ? "Equipment Type" : "Jenis Peralatan", border: const OutlineInputBorder()), items: _equipList.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), initialValue: _selectedEquip, onChanged: (v) => _selectedEquip = v, validator: (v) => v == null ? "*" : null)),
                        const SizedBox(width: 20),
                        Expanded(flex: 1, child: DropdownButtonFormField<String>(decoration: InputDecoration(labelText: widget.isEnglish ? "Quantity" : "Kuantiti", border: const OutlineInputBorder()), items: ["1", "2", "3", "4", "5"].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), initialValue: _selectedQuantity, onChanged: (v) => _selectedQuantity = v, validator: (v) => v == null ? "*" : null)),
                      ],
                    ),
                    const SizedBox(height: 25),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _buildDateDropdownRow(widget.isEnglish ? "START DATE" : "TARIKH MULA", _sDay, _sMonth, _sYear, (v) => setState(() => _sDay = v), (v) => setState(() => _sMonth = v), (v) => setState(() => _sYear = v))),
                        const SizedBox(width: 20),
                        Expanded(child: _buildDateDropdownRow(widget.isEnglish ? "END DATE" : "TARIKH TAMAT", _eDay, _eMonth, _eYear, (v) => setState(() => _eDay = v), (v) => setState(() => _eMonth = v), (v) => setState(() => _eYear = v))),
                      ],
                    ),
                    const SizedBox(height: 25),
                    DropdownButtonFormField<String>(decoration: InputDecoration(labelText: widget.isEnglish ? "Reason for Loan" : "Sebab Pinjaman", border: const OutlineInputBorder()), items: _loanReasons.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), initialValue: _selectedLoanReason, onChanged: (v) => _selectedLoanReason = v, validator: (v) => v == null ? "*" : null),
                    const SizedBox(height: 30),
                    Center(
                      child: SizedBox(
                        height: 60,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF133F85), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 50)),
                          onPressed: () {
                            if (_equipFKey.currentState!.validate()) {
                            int startMonthIndex = _monthsList.indexOf(_sMonth!) + 1; int endMonthIndex = _monthsList.indexOf(_eMonth!) + 1;
                            DateTime startDate = DateTime(int.parse(_sYear!), startMonthIndex, int.parse(_sDay!));
                            DateTime endDate = DateTime(int.parse(_eYear!), endMonthIndex, int.parse(_eDay!));

                            if (endDate.isBefore(startDate)) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error: End Date cannot be before Start Date."))); return; }

                            String displayDateRange = "${DateFormat('dd MMM yyyy').format(startDate)}  -  ${DateFormat('dd MMM yyyy').format(endDate)}";
                            showDialog(
                              context: context,
                              builder: (c) => AlertDialog(
                                title: Text(widget.isEnglish ? "Confirm Reservation" : "Sahkan Tempahan"),
                                content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [Text("Reserve ${_selectedQuantity}x $_selectedEquip from\n$displayDateRange?")]),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(c), child: Text(widget.isEnglish ? "Back" : "Kembali")),
                                  ElevatedButton(
                                    onPressed: () async {
                                      Navigator.pop(c); 
                                      await FirebaseDatabase.instance.ref('reservations').push().set({
                                        'item': _selectedEquip, 'quantity': _selectedQuantity, 'start_date': DateFormat('yyyy-MM-dd').format(startDate), 'end_date': DateFormat('yyyy-MM-dd').format(endDate),
                                        'reason': _selectedLoanReason, 'patient_name': widget.userName.toUpperCase(), 'patient_id': widget.userId, 'status': 'Pending', 'timestamp': ServerValue.timestamp
                                      });
                                      await sendEmailJSEmail(templateId: 'template_aaoznaf', templateParams: {'to_email': "s${widget.userId}@studentmail.unimap.edu.my", 'patient_name': widget.userName.toUpperCase(), 'item': '$_selectedQuantity x $_selectedEquip', 'duration': displayDateRange});
                                      showDialog(
                                        context: context, barrierDismissible: false,
                                        builder: (c2) => AlertDialog(
                                          title: const Text("Success!"), content: const Text("Your request has been successfully processed.\nContinue or Log Out?"),
                                          actions: [TextButton(onPressed: () { Navigator.pop(c2); widget.onLogOut(); }, child: const Text("LOG OUT", style: TextStyle(color: Colors.red))), ElevatedButton(onPressed: () { Navigator.pop(c2); widget.onBack(); }, child: const Text("CONTINUE"))]
                                        ),
                                      );
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
}