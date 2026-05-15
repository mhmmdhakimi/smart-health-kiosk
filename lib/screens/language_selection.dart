import 'package:flutter/material.dart';
import '../widgets/emergency_button.dart';
import 'welcome_selection.dart';

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