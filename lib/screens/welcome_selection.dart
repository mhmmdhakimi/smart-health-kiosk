import 'package:flutter/material.dart';
import 'dart:ui';
import '../widgets/emergency_button.dart';
import 'kiosk_login.dart';
import 'app_login_qr.dart';
import 'student_verification.dart';

class WelcomeSelectionPage extends StatelessWidget {
  final bool isEnglish;
  const WelcomeSelectionPage({super.key, required this.isEnglish});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0B0F19), Color(0xFF111827)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          )
        ),
        child: Stack(
          children: [
            Positioned(
              top: 20,
              left: 20,
              child: TextButton.icon(
                onPressed: () => Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => StudentVerificationPage(isEnglish: isEnglish)),
                ),
                icon: const Icon(Icons.arrow_back, size: 28, color: Colors.white),
                label: Text(
                  isEnglish ? 'Back' : 'Kembali',
                  style: const TextStyle(fontSize: 18, color: Colors.white),
                ),
              ),
            ),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isEnglish ? "Select Login Method" : "Pilih Kaedah Log Masuk", 
                    style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.white)
                  ),
                  const SizedBox(height: 10),
                  Text(
                    isEnglish ? "How would you like to log in?" : "Bagaimana anda ingin log masuk?", 
                    style: const TextStyle(fontSize: 20, color: Colors.white70)
                  ),
                  const SizedBox(height: 60),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _BentoLoginCard(
                        title: isEnglish ? "Student Card" : "Kad Pelajar",
                        subtext: isEnglish ? "TAP PHYSICAL CARD ON SCANNER" : "SENTUH KAD FIZIKAL PADA PENGIMBAS",
                        icon: Icons.vignette_rounded,
                        auraColor: const Color(0xFF1B64F2),
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => KioskLoginPage(isEnglish: isEnglish))),
                      ),
                      const SizedBox(width: 40),
                      _BentoLoginCard(
                        title: isEnglish ? "UniMAP Health App" : "Aplikasi UniMAP Health",
                        subtext: isEnglish ? "SCAN QR LINK WITH PHONE" : "IMBAS KOD QR DENGAN TELEFON",
                        icon: Icons.phonelink_setup_rounded,
                        auraColor: const Color(0xFF8B5CF6),
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => AppLoginQrPage(isEnglish: isEnglish))),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: EmergencyHelpButton(isEnglish: isEnglish),
            ),
          ],
        ),
      ),
    );
  }
}

class _BentoLoginCard extends StatefulWidget {
  final String title;
  final String subtext;
  final IconData icon;
  final Color auraColor;
  final VoidCallback onTap;

  const _BentoLoginCard({
    required this.title,
    required this.subtext,
    required this.icon,
    required this.auraColor,
    required this.onTap,
  });

  @override
  State<_BentoLoginCard> createState() => _BentoLoginCardState();
}

class _BentoLoginCardState extends State<_BentoLoginCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 340,
            height: 380,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: _isPressed ? widget.auraColor : Colors.white.withOpacity(0.1),
                width: _isPressed ? 2 : 1,
              ),
              boxShadow: _isPressed ? [
                BoxShadow(
                  color: widget.auraColor.withOpacity(0.4),
                  blurRadius: 40,
                  spreadRadius: 5,
                )
              ] : [],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: widget.auraColor.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(widget.icon, color: widget.auraColor, size: 70),
                ),
                const SizedBox(height: 40),
                Text(
                  widget.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  widget.subtext,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.6),
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}