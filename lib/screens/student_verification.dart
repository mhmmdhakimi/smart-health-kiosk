import 'package:flutter/material.dart';
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
      backgroundColor: const Color(0xFFF4F9FF),
      body: Stack(
        children: [
          // ── Back button (top-left) ──────────────────────────────────────
          Positioned(
            top: 20,
            left: 20,
            child: TextButton.icon(
              onPressed: () => Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const LanguageSelectionPage()),
              ),
              icon: const Icon(Icons.arrow_back, size: 28, color: Color(0xFF133F85)),
              label: Text(
                isEnglish ? 'Back' : 'Kembali',
                style: const TextStyle(fontSize: 18, color: Color(0xFF133F85)),
              ),
            ),
          ),

          // ── Main content ───────────────────────────────────────────────
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon badge
                Container(
                  padding: const EdgeInsets.all(26),
                  decoration: BoxDecoration(
                    color: const Color(0xFF133F85),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF133F85).withOpacity(0.35),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.school_rounded, color: Colors.white, size: 64),
                ),

                const SizedBox(height: 36),

                // Question
                Text(
                  isEnglish
                      ? 'Are you a UniMAP student?'
                      : 'Adakah anda pelajar UniMAP?',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF133F85),
                  ),
                ),

                const SizedBox(height: 12),

                Text(
                  isEnglish
                      ? 'Please select the option that applies to you.'
                      : 'Sila pilih pilihan yang berkenaan.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 18, color: Colors.blueGrey),
                ),

                const SizedBox(height: 56),

                // YES / NO cards
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _VerificationCard(
                      label: isEnglish ? 'YES' : 'YA',
                      sublabel: isEnglish ? 'I am a UniMAP student' : 'Saya pelajar UniMAP',
                      icon: Icons.check_circle_rounded,
                      primaryColor: const Color(0xFF1B64F2),
                      onTap: () => Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => WelcomeSelectionPage(isEnglish: isEnglish),
                        ),
                      ),
                    ),
                    const SizedBox(width: 40),
                    _VerificationCard(
                      label: isEnglish ? 'NO' : 'TIDAK',
                      sublabel: isEnglish ? 'I am a guest / visitor' : 'Saya tetamu / pelawat',
                      icon: Icons.person_outline_rounded,
                      primaryColor: const Color(0xFF3B445B),
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

          // ── Emergency button ───────────────────────────────────────────
          const Align(
            alignment: Alignment.bottomCenter,
            child: EmergencyHelpButton(
              isEnglish: true,
              customText: 'EMERGENCY / KECEMASAN',
            ),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Private card widget
// ────────────────────────────────────────────────────────────────────────────
class _VerificationCard extends StatefulWidget {
  final String label;
  final String sublabel;
  final IconData icon;
  final Color primaryColor;
  final VoidCallback onTap;

  const _VerificationCard({
    required this.label,
    required this.sublabel,
    required this.icon,
    required this.primaryColor,
    required this.onTap,
  });

  @override
  State<_VerificationCard> createState() => _VerificationCardState();
}

class _VerificationCardState extends State<_VerificationCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      lowerBound: 0.0,
      upperBound: 0.04,
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(
        scale: _scaleAnim,
        child: Container(
          width: 300,
          height: 320,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: widget.primaryColor.withOpacity(0.15),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
              const BoxShadow(
                color: Colors.black12,
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
            border: Border.all(
              color: widget.primaryColor.withOpacity(0.12),
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon circle
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: widget.primaryColor,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(widget.icon, color: Colors.white, size: 56),
              ),
              const SizedBox(height: 28),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: widget.primaryColor,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                widget.sublabel,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.blueGrey,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
