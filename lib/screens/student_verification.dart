import 'package:flutter/material.dart';
import 'dart:ui';
import '../widgets/emergency_button.dart';
import 'language_selection.dart';
import 'welcome_selection.dart';
import 'guest_qr.dart';

class StudentVerificationPage extends StatelessWidget {
  final bool isEnglish;
  const StudentVerificationPage({super.key, required this.isEnglish});

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
                  MaterialPageRoute(builder: (_) => const LanguageSelectionPage()),
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
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 40),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.04),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
                        ),
                        child: Text(
                          isEnglish
                              ? 'Are you a UniMAP student?'
                              : 'Adakah anda pelajar UniMAP?',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 60),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _VerificationButton(
                        label: isEnglish ? 'YES' : 'YA',
                        icon: Icons.school_rounded,
                        glowColor: const Color(0xFF06B6D4),
                        onTap: () => Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => WelcomeSelectionPage(isEnglish: isEnglish),
                          ),
                        ),
                      ),
                      const SizedBox(width: 40),
                      _VerificationButton(
                        label: isEnglish ? 'NO (GUEST)' : 'TIDAK (TETAMU)',
                        icon: Icons.person_outline_rounded,
                        glowColor: const Color(0xFF6366F1), 
                        onTap: () => Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => GuestQrPage(isEnglish: isEnglish),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Align(
              alignment: Alignment.bottomCenter,
              child: EmergencyHelpButton(
                isEnglish: true,
                customText: 'EMERGENCY / KECEMASAN',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VerificationButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final Color glowColor;
  final VoidCallback onTap;

  const _VerificationButton({
    required this.label,
    required this.icon,
    required this.glowColor,
    required this.onTap,
  });

  @override
  State<_VerificationButton> createState() => _VerificationButtonState();
}

class _VerificationButtonState extends State<_VerificationButton> {
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
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 300,
            height: 250,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _isPressed ? widget.glowColor : Colors.white.withOpacity(0.1),
                width: _isPressed ? 2 : 1,
              ),
              boxShadow: _isPressed ? [
                BoxShadow(
                  color: widget.glowColor.withOpacity(0.3),
                  blurRadius: 30,
                  spreadRadius: 5,
                )
              ] : [],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(widget.icon, color: _isPressed ? widget.glowColor : Colors.white, size: 64),
                const SizedBox(height: 28),
                Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: _isPressed ? widget.glowColor : Colors.white,
                    letterSpacing: 1.2,
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
