import 'package:flutter/material.dart';
import '../widgets/emergency_button.dart';
import 'language_selection.dart';
import 'kiosk_login.dart';
import 'guest_qr.dart';

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
                          desc: widget.isEnglish ? "Tap your RFID student card\nfor full access" : "Sentuh kad RFID pelajar anda\nuntuk akses penuh",
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