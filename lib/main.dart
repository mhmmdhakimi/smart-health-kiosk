import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:async';
import 'package:nfc_manager/nfc_manager.dart';
import 'web_listener_logic.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // KIOSK MODE: Force Landscape & Immersive Fullscreen
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeRight,
    DeviceOrientation.landscapeLeft,
  ]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const SmartHealthKioskApp());
}

// --- EMAILJS HELPER FUNCTION ---
Future<void> sendEmailJSEmail({
  required String templateId,
  required Map<String, dynamic> templateParams,
}) async {
  const serviceId = 'service_f3mmtjj'; 
  const publicKey = '73WBQxNlkGUqMf2r9'; 

  final url = Uri.parse('https://api.emailjs.com/api/v1.0/email/send');
  
  try {
    final response = await http.post(
      url,
      headers: {
        'origin': 'http://localhost',
        'Content-Type': 'application/json',
      },
      body: json.encode({
        'service_id': serviceId,
        'template_id': templateId,
        'user_id': publicKey,
        'template_params': templateParams,
      }),
    );
    
    if (response.statusCode == 200) {
      debugPrint("Email successfully sent via EmailJS (Template: $templateId)");
    } else {
      debugPrint("EmailJS Error: ${response.body}");
    }
  } catch (e) {
    debugPrint("Failed to send email: $e");
  }
}

class SmartHealthKioskApp extends StatelessWidget {
  const SmartHealthKioskApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'UniMAP Smart Health Kiosk',
      theme: ThemeData(
        primaryColor: const Color(0xFF133F85),
        scaffoldBackgroundColor: Colors.white,
        useMaterial3: true,
      ),
      initialRoute: '/',
      onGenerateRoute: (settings) {
        // Handle the deep link from the mobile QR scan
        Uri uri = Uri.parse(settings.name ?? '/');
        if (uri.path == '/checkin') {
          String kioskId = uri.queryParameters['kioskId'] ?? 'KIOSK_01';
          String sessionId = uri.queryParameters['session'] ?? '';
          return MaterialPageRoute(builder: (context) => MobileCheckInPage(kioskId: kioskId, sessionId: sessionId));
        }
        // Default to the kiosk welcome screen
        return MaterialPageRoute(builder: (context) => const LanguageSelectionPage());
      },
    );
  }
}

// --- MOBILE CHECK-IN PAGE (Loaded on Guest's Phone) ---
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

    String formattedPhone = phone.startsWith('0') ? '60' + phone.substring(1) : '60' + phone;

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
        // Removes the form from the navigation stack and shows the success page
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

// --- MOBILE CHECK-IN SUCCESS PAGE ---
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

// --- EMERGENCY HELP BUTTON ---
class EmergencyHelpButton extends StatelessWidget {
  final bool isEnglish;
  final String? customText;
  final String patientName;
  final String patientId;
  final String location;

  const EmergencyHelpButton({
    super.key, 
    required this.isEnglish, 
    this.customText,
    this.patientName = 'UNKNOWN / PRE-LOGIN',
    this.patientId = 'N/A',
    this.location = 'Kiosk Login Page',
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: SizedBox(
        width: customText != null ? 380 : 280, 
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red.shade600, 
            foregroundColor: Colors.white, 
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)), 
            elevation: 3
          ),
          icon: const Icon(Icons.emergency, size: 22), 
          label: Text(
            customText ?? (isEnglish ? "EMERGENCY HELP" : "BANTUAN KECEMASAN"), 
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.2)
          ),
          onPressed: () async {
            try {
              await FirebaseDatabase.instance.ref('emergencies').push().set({
                'patient_name': patientName,
                'patient_id': patientId,
                'status': 'Unresolved',
                'timestamp': ServerValue.timestamp,
                'location': location,
              });
            } catch (e) {
              debugPrint("Failed to send Emergency Alert to Firebase: $e");
            }

            if (context.mounted) {
              showDialog(
                context: context,
                builder: (c) => AlertDialog(
                  backgroundColor: Colors.red.shade50,
                  title: Row(children: [const Icon(Icons.warning, color: Colors.red, size: 40), const SizedBox(width: 10), Text(isEnglish ? "EMERGENCY" : "KECEMASAN", style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold))]),
                  content: Text(isEnglish ? "Staff have been notified. Please remain at the kiosk. Help is on the way." : "Kakitangan telah dimaklumkan. Sila kekal di kiosk. Bantuan sedang dalam perjalanan.", style: const TextStyle(fontSize: 18)),
                  actions: [TextButton(onPressed: () => Navigator.pop(c), child: Text(isEnglish ? "DISMISS" : "TUTUP"))],
                ),
              );
            }
          },
        ),
      ),
    );
  }
}

// --- LANGUAGE SELECTION PAGE ---
class LanguageSelectionPage extends StatelessWidget {
  const LanguageSelectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F9FF),
      body: Stack(
        children: [
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("Select Language / Pilih Bahasa", style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Color(0xFF133F85))),
                const SizedBox(height: 50),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildLanguageCard(
                      context,
                      title: "English",
                      icon: Icons.language,
                      iconBgColor: const Color(0xFF1B64F2),
                    actionText: "Select",
                      onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (c) => const WelcomeSelectionPage(isEnglish: true))),
                    ),
                    const SizedBox(width: 40),
                    _buildLanguageCard(
                      context,
                      title: "Bahasa Melayu",
                      icon: Icons.translate,
                      iconBgColor: const Color(0xFF3B445B),
                    actionText: "Pilih",
                      onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (c) => const WelcomeSelectionPage(isEnglish: false))),
                    ),
                  ],
                )
              ],
            ),
          ),
          const Align(
            alignment: Alignment.bottomCenter,
            child: EmergencyHelpButton(isEnglish: true, customText: "EMERGENCY / KECEMASAN"),
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageCard(BuildContext context, {required String title, required IconData icon, required Color iconBgColor, required String actionText, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        width: 320,
        height: 350,
        padding: const EdgeInsets.all(30),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 5))]
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(25),
              decoration: BoxDecoration(color: iconBgColor, borderRadius: BorderRadius.circular(20)),
              child: Icon(icon, color: Colors.white, size: 60),
            ),
            const SizedBox(height: 30),
            Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87)),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(actionText, style: TextStyle(color: iconBgColor, fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(width: 5),
                Icon(Icons.arrow_forward, color: iconBgColor, size: 20),
              ],
            )
          ],
        ),
      ),
    );
  }
}

// --- WELCOME SELECTION PAGE ---
class WelcomeSelectionPage extends StatefulWidget {
  final bool isEnglish;
  const WelcomeSelectionPage({super.key, required this.isEnglish});

  @override
  State<WelcomeSelectionPage> createState() => _WelcomeSelectionPageState();
}

class _WelcomeSelectionPageState extends State<WelcomeSelectionPage> {

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F9FF),
      body: Padding(
        padding: const EdgeInsets.all(25.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (c) => const LanguageSelectionPage())), 
                    icon: const Icon(Icons.arrow_back, size: 28), 
                    label: Text(widget.isEnglish ? "Back" : "Kembali", style: const TextStyle(fontSize: 18))
                  ),
                ],
              ),
            ),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(widget.isEnglish ? "Welcome" : "Selamat Datang", style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Color(0xFF133F85))),
                  const SizedBox(height: 10),
                  Text(widget.isEnglish ? "How would you like to continue?" : "Bagaimana anda ingin meneruskan?", style: const TextStyle(fontSize: 20, color: Colors.blueGrey)),
                  const SizedBox(height: 50),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 40,
                    runSpacing: 20,
                    children: [
                      _buildSelectionCard(
                          context,
                          title: widget.isEnglish ? "Student Login" : "Log Masuk Pelajar",
                          desc: widget.isEnglish ? "Tap your NFC student card\nfor full access" : "Sentuh kad NFC pelajar anda\nuntuk akses penuh",
                          icon: Icons.school,
                          iconBgColor: const Color(0xFF1B64F2),
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => KioskLoginPage(isEnglish: widget.isEnglish)))),
                      _buildSelectionCard(
                          context,
                          title: widget.isEnglish ? "Guest Login" : "Log Masuk Tetamu",
                          desc: widget.isEnglish ? "Scan QR code to check-in\nwith your mobile phone" : "Imbas kod QR untuk daftar masuk\ndengan telefon bimbit anda",
                          icon: Icons.qr_code_scanner,
                          iconBgColor: const Color(0xFF3B445B),
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => GuestQrPage(isEnglish: widget.isEnglish)))),
                    ],
                  )
                ],
              ),
            ),
            Center(child: EmergencyHelpButton(isEnglish: widget.isEnglish)),
          ],
        ),
      ),
    );
  }

  void _showAdminLoginDialog() {
    TextEditingController idController = TextEditingController();
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(widget.isEnglish ? "Admin Sign In (Test Mode)" : "Log Masuk Admin (Mod Ujian)"),
        content: TextField(
          controller: idController,
          decoration: InputDecoration(
            hintText: widget.isEnglish ? "Enter Student/Admin ID" : "Masukkan ID Pelajar/Admin",
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: Text(widget.isEnglish ? "Cancel" : "Batal"),
          ),
          ElevatedButton(
            onPressed: () async {
              String id = idController.text.trim();
              if (id.isNotEmpty) {
                Navigator.pop(c);
                _performManualLogin(id);
              }
            },
            child: Text(widget.isEnglish ? "Login" : "Log Masuk"),
          ),
        ],
      ),
    );
  }

  Future<void> _performManualLogin(String studentId) async {
    showDialog(context: context, barrierDismissible: false, builder: (c) => const Center(child: CircularProgressIndicator()));
    try {
      var studentEvent = await FirebaseDatabase.instance.ref('students').child(studentId).once();
      if (!mounted) return;
      Navigator.pop(context); // pop loading

      String userName = "TEST ADMIN";
      if (studentEvent.snapshot.exists) {
        var data = studentEvent.snapshot.value as Map<dynamic, dynamic>;
        userName = data['name'] ?? userName;
      }
        
      try {
        await FirebaseDatabase.instance.ref('login_record').push().set({
          'patient_id': studentId,
          'patient_name': userName,
          'is_guest': false,
          'timestamp': ServerValue.timestamp,
          'date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
          'time': DateFormat('hh:mm:ss a').format(DateTime.now()),
        });
      } catch (e) {
        debugPrint("Failed to record manual login: $e");
      }

      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context, 
        MaterialPageRoute(builder: (context) => KioskDashboard(
          userName: userName,
          userId: studentId,
          isGuest: false,
          isEnglish: widget.isEnglish,
        )),
        (r) => false
      );
    } catch (e) {
      if (mounted) Navigator.pop(context); // pop loading
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  Widget _buildSelectionCard(BuildContext context, {required String title, required String desc, required IconData icon, required Color iconBgColor, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        width: 320,
        height: 350,
        padding: const EdgeInsets.all(30),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 5))]
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(25),
              decoration: BoxDecoration(color: iconBgColor, borderRadius: BorderRadius.circular(20)),
              child: Icon(icon, color: Colors.white, size: 60),
            ),
            const SizedBox(height: 30),
            Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87)),
            const SizedBox(height: 15),
            Text(desc, textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, color: Colors.grey, height: 1.4)),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(widget.isEnglish ? "Continue" : "Teruskan", style: TextStyle(color: iconBgColor, fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(width: 5),
                Icon(Icons.arrow_forward, color: iconBgColor, size: 20),
              ],
            )
          ],
        ),
      ),
    );
  }
}

// --- GUEST QR PAGE ---
class GuestQrPage extends StatefulWidget {
  final bool isEnglish;
  const GuestQrPage({super.key, required this.isEnglish});

  @override
  State<GuestQrPage> createState() => _GuestQrPageState();
}

class _GuestQrPageState extends State<GuestQrPage> {
  StreamSubscription<DatabaseEvent>? _subscription;
  static const String kioskId = 'KIOSK_01';
  bool _isProcessing = false;
  late String _sessionId;
  Timer? _timeoutTimer;
  int _timeLeft = 120; // 2 minutes timeout

  @override
  void initState() {
    super.initState();
    _sessionId = "SESS_${DateTime.now().millisecondsSinceEpoch}";
    _initializeSession();
    _startListening();
    _startTimer();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _timeoutTimer?.cancel();
    if (!_isProcessing) {
      FirebaseDatabase.instance.ref('pending_registrations/$kioskId').remove();
    }
    super.dispose();
  }

  Future<void> _initializeSession() async {
    await FirebaseDatabase.instance.ref('pending_registrations/$kioskId').set({
      'session': _sessionId,
      'status': 'waiting',
      'timestamp': ServerValue.timestamp,
    });
  }

  void _startTimer() {
    _timeoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        if (_timeLeft > 0) {
          setState(() => _timeLeft--);
        } else {
          timer.cancel();
          if (!_isProcessing) {
            _handleTimeout();
          }
        }
      }
    });
  }

  void _handleTimeout() async {
    await FirebaseDatabase.instance.ref('pending_registrations/$kioskId').remove();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (c) => const LanguageSelectionPage()),
        (route) => false,
      );
    }
  }


  void _startListening() {
    _subscription = FirebaseDatabase.instance.ref('pending_registrations/$kioskId').onValue.listen((event) async {
      if (_isProcessing) return;

      if (event.snapshot.exists && event.snapshot.value != null) {
        var data = Map<String, dynamic>.from(event.snapshot.value as Map);
        
        if (data['session'] == _sessionId && data['status'] == 'completed') {
          setState(() => _isProcessing = true);
          _timeoutTimer?.cancel();
          
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (c) => AlertDialog(
              content: Row(
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(width: 20),
                  Text(widget.isEnglish ? "Processing login..." : "Memproses log masuk..."),
                ],
              ),
            ),
          );

          try {
            String name = data['name']?.toString() ?? 'Guest';
            String phone = data['phone']?.toString() ?? 'N/A';
            String gender = data['gender']?.toString() ?? 'Unknown';
            String uniqueGuestId = "GUEST_${DateTime.now().millisecondsSinceEpoch}";

            await FirebaseDatabase.instance.ref('pending_registrations/$kioskId').remove();

            await FirebaseDatabase.instance.ref('login_record').push().set({
              'patient_id': uniqueGuestId,
              'patient_name': name.toUpperCase(),
              'phone': phone,
              'gender': gender,
              'is_guest': true,
              'timestamp': ServerValue.timestamp,
              'date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
              'time': DateFormat('hh:mm:ss a').format(DateTime.now()),
            });

            if (mounted) {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (c) => KioskDashboard(
                  userName: name.toUpperCase(),
                  userId: uniqueGuestId,
                  isGuest: true,
                  isEnglish: widget.isEnglish,
                  guestPhone: phone,
                )),
                (r) => false
              );
            }
          } catch (e) {
            if (mounted) Navigator.pop(context);
            setState(() => _isProcessing = false);
            debugPrint("Error processing guest login: $e");
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(widget.isEnglish ? "An error occurred." : "Berlaku ralat.")));
            }
          }
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    const String webAppUrl = 'https://smart-health-kiosk-193a5.web.app';
    // Added /#/ to safely trigger Flutter's deep linking router
    final String qrData = '$webAppUrl/#/checkin?kioskId=$kioskId&session=$_sessionId';

    return Scaffold(
      backgroundColor: const Color(0xFFF4F9FF),
      body: Stack(
        children: [
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  widget.isEnglish ? "Guest Check-in" : "Daftar Masuk Tetamu",
                  style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF133F85)),
                ),
                const SizedBox(height: 20),
                Text(
                  widget.isEnglish
                      ? "Scan the QR code with your phone to register."
                      : "Imbas kod QR dengan telefon anda untuk mendaftar.",
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 18, color: Colors.blueGrey),
                ),
                const SizedBox(height: 15),
                Text(
                  widget.isEnglish
                      ? "QR Code expires in: $_timeLeft seconds"
                      : "Kod QR tamat tempoh dalam: $_timeLeft saat",
                  style: const TextStyle(fontSize: 16, color: Colors.red, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 25),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 5))]),
                  child: QrImageView(data: qrData, version: QrVersions.auto, size: 280.0),
                ),
                const SizedBox(height: 40),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15)),
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.cancel_outlined),
                  label: Text(widget.isEnglish ? "CANCEL" : "BATAL", style: const TextStyle(fontSize: 16)),
                ),
              ],
            ),
          ),
          Align(alignment: Alignment.bottomCenter, child: EmergencyHelpButton(isEnglish: widget.isEnglish)),
        ],
      ),
    );
  }
}

// --- STUDENT LOGIN PAGE ---
class KioskLoginPage extends StatefulWidget {
  final bool isEnglish;
  const KioskLoginPage({super.key, required this.isEnglish});
  @override
  State<KioskLoginPage> createState() => _KioskLoginPageState();
}

class _KioskLoginPageState extends State<KioskLoginPage> {
  bool _isLoading = false;
  String _statusMessage = "";
  final NfcWebListener _webListener = NfcWebListener();
  
  // RFID Scanner Variables
  final FocusNode _rfidFocusNode = FocusNode();
  String _rfidBuffer = "";
  DateTime _lastKeyPress = DateTime.now();

  @override
  void initState() {
    super.initState();
    // Changed to professional agnostic text
    _statusMessage = widget.isEnglish ? "Please tap your card" : "Sila sentuh kad anda";
    _startNFC();
    
    // Start listening to the Firebase Relay for web/desktop kiosks
    _webListener.startListening((String uid) {
      if (mounted && !_isLoading) {
        setState(() => _isLoading = true);
        _handleLogin(uid);
      }
    });

    // Ensure the hidden RFID listener is active
    Future.delayed(Duration.zero, () => _rfidFocusNode.requestFocus());
  }

  @override
  void dispose() {
    if (!kIsWeb) {
      try { NfcManager.instance.stopSession(); } catch (_) {}
    }
    _webListener.stopListening();
    _rfidFocusNode.dispose();
    super.dispose();
  }

  // Intercepts rapid HID Keyboard keystrokes from USB RFID Modules
  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent) {
      final now = DateTime.now();
      // Clear buffer if typing is humanly slow (RFID modules type <50ms per char)
      if (now.difference(_lastKeyPress).inMilliseconds > 150) _rfidBuffer = "";
      _lastKeyPress = now;

      if (event.logicalKey == LogicalKeyboardKey.enter) {
        if (_rfidBuffer.isNotEmpty && !_isLoading) {
          String scannedUid = _rfidBuffer.toUpperCase();
          _rfidBuffer = "";
          setState(() => _isLoading = true);
          _handleLogin(scannedUid);
        }
        return KeyEventResult.handled;
      } else {
        String char = event.character ?? "";
        if (char.isEmpty && event.logicalKey.keyLabel.length == 1) char = event.logicalKey.keyLabel;
        if (char.isNotEmpty) _rfidBuffer += char;
      }
    }
    return KeyEventResult.ignored;
  }

  void _startNFC() async {
    // Prevent Web App from crashing by completely bypassing native hardware checks!
    if (kIsWeb) return; 
    try {
      bool isAvailable = await NfcManager.instance.isAvailable();
      if (!isAvailable) {
        // Fail silently so laptops/web don't show ugly NFC errors
        return;
      }

      NfcManager.instance.startSession(onDiscovered: (NfcTag tag) async {
        if (_isLoading) return;
        setState(() => _isLoading = true);
        
        String nfcId = _extractTagId(tag);
        await _handleLogin(nfcId);
      });
    } catch (e) {
      // Fail silently
    }
  }

  String _extractTagId(NfcTag tag) {
    try {
      List<int>? idBytes;
      if (tag.data.containsKey('nfca')) {
        idBytes = tag.data['nfca']['identifier'];
      } else if (tag.data.containsKey('mifareclassic')) {
        idBytes = tag.data['mifareclassic']['identifier'];
      } else if (tag.data.containsKey('isodep')) {
        idBytes = tag.data['isodep']['identifier'];
      } else if (tag.data.containsKey('mifareultralight')) {
        idBytes = tag.data['mifareultralight']['identifier'];
      } else if (tag.data.containsKey('ndefformatable')) {
        idBytes = tag.data['ndefformatable']['identifier'];
      }
      
      if (idBytes != null) {
        return idBytes.map((e) => e.toRadixString(16).padLeft(2, '0')).join('').toUpperCase();
      }
      return tag.data.toString().hashCode.toString();
    } catch (e) {
      return "UNKNOWN_TAG";
    }
  }

  Future<void> _handleLogin(String nfcId) async {
    try {
      // Fast lookup of the Student ID using the NFC root branch
      var nfcEvent = await FirebaseDatabase.instance.ref('NFC').child(nfcId).once();
          
      if (nfcEvent.snapshot.exists) {
        var studentId = nfcEvent.snapshot.value.toString();
        
        // Fetch the actual student data using the retrieved studentId
        var studentEvent = await FirebaseDatabase.instance.ref('students').child(studentId).once();
        
        if (studentEvent.snapshot.exists) {
          var data = studentEvent.snapshot.value as Map<dynamic, dynamic>;
        
        try {
          await FirebaseDatabase.instance.ref('login_record').push().set({
            'patient_id': studentId,
            'patient_name': data['name'] ?? (widget.isEnglish ? "STUDENT" : "PELAJAR"),
            'is_guest': false,
            'timestamp': ServerValue.timestamp,
            'date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
            'time': DateFormat('hh:mm:ss a').format(DateTime.now()),
          });
        } catch (e) {
          debugPrint("Failed to record student login: $e");
        }

        if (!mounted) return;
        if (!kIsWeb) {
          try { NfcManager.instance.stopSession(); } catch (_) {}
        }
        Navigator.pushAndRemoveUntil(
          context, 
          MaterialPageRoute(builder: (context) => KioskDashboard(
            userName: data['name'] ?? (widget.isEnglish ? "STUDENT" : "PELAJAR"),
            userId: studentId,
            isGuest: false,
            isEnglish: widget.isEnglish,
          )),
          (r) => false
        );
        } else {
          setState(() {
            _statusMessage = widget.isEnglish ? "Student data not found for:\n$studentId" : "Data pelajar tidak ditemui untuk:\n$studentId";
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(widget.isEnglish ? "Student data missing." : "Data pelajar hilang.")));
        }
      } else {
        setState(() {
          _statusMessage = widget.isEnglish ? "Unregistered Card ID:\n$nfcId" : "ID Kad Tidak Berdaftar:\n$nfcId";
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(widget.isEnglish ? "Card not recognized." : "Kad tidak dikenali.")));
      }
    } catch (e) {
      setState(() {
        _statusMessage = widget.isEnglish ? "Login Error" : "Ralat Log Masuk";
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(widget.isEnglish ? "Login Error: $e" : "Ralat Log Masuk: $e")));
    }
    
    // Re-request focus in case of error so the RFID scanner remains ready
    if (mounted) _rfidFocusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    bool isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    return Focus(
      focusNode: _rfidFocusNode,
      onKeyEvent: _handleKeyEvent,
      autofocus: true,
      child: Scaffold(
        backgroundColor: const Color(0xFF133F85),
        body: Stack(
          children: [
            Center(
              child: Container(
                width: 450,
                padding: const EdgeInsets.all(40),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                  Row(
                    children: [
                      IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
                          Expanded(child: Text(widget.isEnglish ? "STUDENT NFC LOGIN" : "LOG MASUK NFC PELAJAR", textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF133F85), fontWeight: FontWeight.bold, fontSize: 20))),
                      const SizedBox(width: 48), 
                    ],
                  ),
                  const Divider(height: 40),
                      
                      Icon(Icons.contactless, size: 100, color: _isLoading ? Colors.grey : const Color(0xFF1B64F2)),
                      const SizedBox(height: 20),
                      
                  _isLoading
                      ? const CircularProgressIndicator()
                          : Text(
                              _statusMessage,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey)
                            ),
                      
                      const SizedBox(height: 30),
                      Text(
                        widget.isEnglish 
                          ? "Please tap your Student Card to the reader" 
                          : "Sila sentuh Kad Pelajar anda pada pembaca",
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 14, color: Colors.grey)
                      ),
                ],
              ),
            ),
          ),
          if (!isKeyboardOpen)
            Align(
              alignment: Alignment.bottomCenter,
              child: EmergencyHelpButton(isEnglish: widget.isEnglish),
            ),
          ],
        ),
      ),
    );
  }
}

// --- MAIN DASHBOARD ---
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
    // Route back to the initial Selection Screen
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

          // Sort descending by timestamp to find the latest
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

    // Operating hours check
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
                
                // Get general stats
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

                // Check if current user has an active ticket to show
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
    
    await _expireOldAndSkippedTickets(); // Run expiration check right before validation

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

// --- APPOINTMENT PAGE ---
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

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android: return android;
      default: throw UnsupportedError('Platform not supported');
    }
  }
  static const FirebaseOptions web = FirebaseOptions(apiKey: "AIzaSyB0t88bvV3eTZoGLqt3_DOp4AXjwEYTlW4", authDomain: "smart-health-kiosk-193a5.firebaseapp.com", databaseURL: "https://smart-health-kiosk-193a5-default-rtdb.asia-southeast1.firebasedatabase.app", projectId: "smart-health-kiosk-193a5", storageBucket: "smart-health-kiosk-193a5.firebasestorage.app", messagingSenderId: "74365494988", appId: "1:74365494988:web:977ee83752dbb8b7ca4469");
  static const FirebaseOptions android = FirebaseOptions(apiKey: "AIzaSyB0t88bvV3eTZoGLqt3_DOp4AXjwEYTlW4", appId: "1:74365494988:android:977ee83752dbb8b7ca4469", messagingSenderId: "74365494988", projectId: "smart-health-kiosk-193a5", databaseURL: "https://smart-health-kiosk-193a5-default-rtdb.asia-southeast1.firebasedatabase.app", storageBucket: "smart-health-kiosk-193a5.firebasestorage.app");
}