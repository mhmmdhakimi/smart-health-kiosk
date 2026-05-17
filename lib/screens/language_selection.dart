import '../utils/no_anim_route.dart';
import 'package:flutter/material.dart';
import 'dart:ui';
import '../widgets/emergency_button.dart';
import 'welcome_selection.dart';

class LanguageSelectionPage extends StatelessWidget {
  const LanguageSelectionPage({super.key});

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
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "Smart Health Kiosk",
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          color: Colors.cyan.withOpacity(0.5),
                          blurRadius: 20,
                        )
                      ]
                    )
                  ),
                  const SizedBox(height: 20),
                  const Text("Select Language / Pilih Bahasa", style: TextStyle(fontSize: 24, color: Colors.white70)),
                  const SizedBox(height: 60),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _LanguageCard(
                        title: "ENGLISH",
                        icon: Icons.language,
                        onTap: () => Navigator.pushReplacement(context, NoAnimRoute(page: const WelcomeSelectionScreen(isEnglish: true))),
                      ),
                      const SizedBox(width: 40),
                      _LanguageCard(
                        title: "BAHASA MELAYU",
                        icon: Icons.translate,
                        onTap: () => Navigator.pushReplacement(context, NoAnimRoute(page: const WelcomeSelectionScreen(isEnglish: false))),
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
      ),
    );
  }
}

class _LanguageCard extends StatefulWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  const _LanguageCard({required this.title, required this.icon, required this.onTap});

  @override
  State<_LanguageCard> createState() => _LanguageCardState();
}

class _LanguageCardState extends State<_LanguageCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    Color borderColor = _isPressed ? const Color(0xFF1B64F2) : Colors.white.withOpacity(0.1);

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
            width: 320,
            height: 350,
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: borderColor,
                width: _isPressed ? 2 : 1,
              ),
              boxShadow: _isPressed ? [
                BoxShadow(color: const Color(0xFF1B64F2).withOpacity(0.3), blurRadius: 30, spreadRadius: 5)
              ] : [],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(widget.icon, color: Colors.white, size: 80),
                const SizedBox(height: 40),
                Text(widget.title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1.5)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}