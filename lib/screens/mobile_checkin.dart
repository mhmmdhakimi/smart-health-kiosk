import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_database/firebase_database.dart';

class MobileCheckInPage extends StatefulWidget {
  final String kioskId;
  final String sessionId;
  const MobileCheckInPage({super.key, required this.kioskId, required this.sessionId});

  @override
  State<MobileCheckInPage> createState() => _MobileCheckInPageState();
}

class _MobileCheckInPageState extends State<MobileCheckInPage> {
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _phoneCtrl = TextEditingController();
  String? _selectedGender;
  bool _isProcessing = false;
  String _status = "";
  bool _isValidSession = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    try {
      var snapshot = await FirebaseDatabase.instance.ref('pending_registrations/${widget.kioskId}').once();
      if (snapshot.snapshot.exists) {
        var data = snapshot.snapshot.value as Map<dynamic, dynamic>;
        if (data['session'] == widget.sessionId && data['status'] == 'waiting') {
          if (mounted) setState(() { _isValidSession = true; _isLoading = false; });
          return;
        }
      }
    } catch (e) {}
    
    if (mounted) setState(() { _isValidSession = false; _isLoading = false; });
  }

  Future<void> _submit() async {
    String name = _nameCtrl.text.trim();
    String phone = _phoneCtrl.text.trim();

    if (name.isEmpty || phone.isEmpty || _selectedGender == null) {
      setState(() => _status = "Please fill in all fields.");
      return;
    }
    
    String digitsOnly = phone.replaceAll(RegExp(r'\D'), '');
    if (digitsOnly.length < 10 || digitsOnly.length > 11) {
      setState(() => _status = "Phone number must be 10 or 11 digits.");
      return;
    }

    String formattedPhone = phone.startsWith('0') ? '60${phone.substring(1)}' : '60$phone';

    setState(() {
      _isProcessing = true;
      _status = "Processing...";
    });

    try {
      var snapshot = await FirebaseDatabase.instance.ref('pending_registrations/${widget.kioskId}').once();
      if (snapshot.snapshot.exists) {
        var data = snapshot.snapshot.value as Map<dynamic, dynamic>;
        if (data['session'] != widget.sessionId || data['status'] != 'waiting') {
          setState(() {
            _isValidSession = false;
            _isProcessing = false;
          });
          return;
        }
      } else {
        setState(() {
          _isValidSession = false;
          _isProcessing = false;
        });
        return;
      }

      await FirebaseDatabase.instance.ref('pending_registrations/${widget.kioskId}').update({
        'name': name,
        'phone': formattedPhone,
        'gender': _selectedGender,
        'status': 'completed',
        'timestamp': ServerValue.timestamp,
      });

      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const MobileCheckInSuccessPage()),
          (route) => false,
        );
      }
    } catch (e) {
      setState(() {
        _status = "Error: $e";
        _isProcessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(backgroundColor: Color(0xFFF4F9FF), body: Center(child: CircularProgressIndicator()));
    }

    if (!_isValidSession) {
      return Scaffold(
        backgroundColor: const Color(0xFFF4F9FF),
        appBar: AppBar(
          title: const Text("Guest Check-in", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          backgroundColor: const Color(0xFF133F85),
          centerTitle: true,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 80, color: Colors.red),
                const SizedBox(height: 20),
                const Text("Session Expired", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF133F85))),
                const SizedBox(height: 10),
                const Text("This QR code is no longer valid or has already been used.\nPlease request a new one at the kiosk.", textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: Colors.blueGrey)),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF4F9FF),
      appBar: AppBar(
        title: const Text("Guest Check-in", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF133F85),
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 5))]),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.qr_code_scanner, size: 60, color: Color(0xFF133F85)),
                const SizedBox(height: 20),
                const Text("Welcome", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF133F85))),
                const SizedBox(height: 10),
                const Text("Please enter your details to check in at the kiosk.", textAlign: TextAlign.center, style: TextStyle(color: Colors.blueGrey)),
                const SizedBox(height: 30),
                TextField(
                  controller: _nameCtrl, 
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [
                    TextInputFormatter.withFunction((oldValue, newValue) => TextEditingValue(text: newValue.text.toUpperCase(), selection: newValue.selection))
                  ],
                  decoration: const InputDecoration(labelText: "Full Name", border: OutlineInputBorder(), prefixIcon: Icon(Icons.person))
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: _phoneCtrl, 
                  keyboardType: TextInputType.number, 
                  maxLength: 11,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(labelText: "Phone Number", border: OutlineInputBorder(), prefixIcon: Icon(Icons.phone), counterText: "")
                ),
                const SizedBox(height: 15),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedGender = 'Male'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          decoration: BoxDecoration(color: _selectedGender == 'Male' ? const Color(0xFF133F85) : Colors.grey.shade100, borderRadius: BorderRadius.circular(8), border: Border.all(color: _selectedGender == 'Male' ? const Color(0xFF133F85) : Colors.grey.shade300)),
                          child: Center(child: Text("Male", style: TextStyle(color: _selectedGender == 'Male' ? Colors.white : Colors.black87, fontWeight: FontWeight.bold))),
                        ),
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedGender = 'Female'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          decoration: BoxDecoration(color: _selectedGender == 'Female' ? const Color(0xFF133F85) : Colors.grey.shade100, borderRadius: BorderRadius.circular(8), border: Border.all(color: _selectedGender == 'Female' ? const Color(0xFF133F85) : Colors.grey.shade300)),
                          child: Center(child: Text("Female", style: TextStyle(color: _selectedGender == 'Female' ? Colors.white : Colors.black87, fontWeight: FontWeight.bold))),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF133F85), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                    onPressed: _isProcessing ? null : _submit,
                    child: _isProcessing ? const CircularProgressIndicator(color: Colors.white) : const Text("CHECK IN", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 20),
                Text(_status, textAlign: TextAlign.center, style: TextStyle(color: _status.contains("Success") ? Colors.green : Colors.red, fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MobileCheckInSuccessPage extends StatelessWidget {
  const MobileCheckInSuccessPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F9FF),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 5))]),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle, size: 80, color: Colors.green),
                const SizedBox(height: 20),
                const Text("Check-In Successful!", textAlign: TextAlign.center, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF133F85))),
                const SizedBox(height: 15),
                const Text("Your details have been sent to the kiosk.\nPlease look at the kiosk screen to continue.", textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: Colors.blueGrey, height: 1.5)),
                const SizedBox(height: 40),
                const Text("You can now close this page.", textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: Colors.grey)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}