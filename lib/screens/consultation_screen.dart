import 'package:flutter/material.dart';
import 'dart:ui';
import 'appointment_page.dart';

class ConsultationScreen extends StatefulWidget {
  final String userId;
  final String userName;
  final bool isGuest;
  final bool isEnglish;
  final VoidCallback onBack;
  final VoidCallback onWalkIn;
  final VoidCallback onLogOut;

  const ConsultationScreen({
    super.key,
    required this.userId,
    required this.userName,
    required this.isGuest,
    required this.isEnglish,
    required this.onBack,
    required this.onWalkIn,
    required this.onLogOut,
  });

  @override
  State<ConsultationScreen> createState() => _ConsultationScreenState();
}

class _ConsultationScreenState extends State<ConsultationScreen> {
  void _navigateToAppointment() async {
    String? result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (c) => Scaffold(
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0B0F19), Color(0xFF111827)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(35),
              child: AppointmentPage(
                userName: widget.userName.toUpperCase(),
                userId: widget.userId,
                isGuest: false,
                onLogOut: widget.onLogOut,
                onBack: () => Navigator.pop(c, "HOME"),
                isEnglish: widget.isEnglish,
              ),
            ),
          ),
        ),
      ),
    );
    if (result == "HOME" && mounted) widget.onBack();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: widget.onBack,
            icon: const Icon(
              Icons.arrow_back,
              size: 28,
              color: Colors.cyanAccent,
            ),
            label: Text(
              widget.isEnglish ? "Back" : "Kembali",
              style: const TextStyle(fontSize: 18, color: Colors.cyanAccent),
            ),
          ),
        ),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                widget.isEnglish
                    ? "Select Medical Consultation Type"
                    : "Pilih Jenis Rundingan Perubatan",
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 1.5,
                  shadows: [
                    Shadow(
                      color: Colors.cyanAccent.withOpacity(0.5),
                      blurRadius: 15,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 80),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 320,
                    height: 300,
                    child: _GlassBentoCard(
                      title: widget.isEnglish
                          ? "WALK-IN\nCONSULTATION"
                          : "RUNDINGAN\nWALK-IN",
                      icon: Icons.directions_walk_rounded,
                      onTap: widget.onWalkIn,
                    ),
                  ),
                  if (!widget.isGuest) ...[
                    const SizedBox(width: 60),
                    SizedBox(
                      width: 320,
                      height: 300,
                      child: _GlassBentoCard(
                        title: widget.isEnglish
                            ? "SCHEDULE\nAPPOINTMENT"
                            : "JADUAL\nTEMU JANJI",
                        icon: Icons.calendar_month_rounded,
                        onTap: _navigateToAppointment,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Internal GlassBentoCard specific to ConsultationScreen
// ────────────────────────────────────────────────────────────────────────────
class _GlassBentoCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _GlassBentoCard({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  State<_GlassBentoCard> createState() => _GlassBentoCardState();
}

class _GlassBentoCardState extends State<_GlassBentoCard> {
  bool _isHovering = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    bool isActive = _isPressed || _isHovering;
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) {
          setState(() => _isPressed = false);
          widget.onTap();
        },
        onTapCancel: () => setState(() => _isPressed = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutQuart,
          transform: Matrix4.identity()..scale(_isPressed ? 0.96 : 1.0),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: Container(
                decoration: BoxDecoration(
                  color: isActive
                      ? Colors.cyan.withOpacity(0.08)
                      : Colors.white.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: isActive
                        ? const Color(0xFF06B6D4)
                        : Colors.white.withOpacity(0.1),
                    width: 1,
                  ),
                  boxShadow: isActive
                      ? [
                          BoxShadow(
                            color: const Color(0xFF06B6D4).withOpacity(0.4),
                            blurRadius: 40,
                            spreadRadius: 5,
                          ),
                        ]
                      : [],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: isActive
                            ? Colors.cyanAccent.withOpacity(0.15)
                            : Colors.transparent,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        widget.icon,
                        size: 90,
                        color: isActive
                            ? const Color(0xFF06B6D4)
                            : Colors.white70,
                        shadows: isActive
                            ? [
                                Shadow(
                                  color: const Color(
                                    0xFF06B6D4,
                                  ).withOpacity(0.8),
                                  blurRadius: 25,
                                ),
                              ]
                            : [],
                      ),
                    ),
                    const SizedBox(height: 35),
                    Text(
                      widget.title.toUpperCase(),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isActive ? Colors.white : Colors.white70,
                        letterSpacing: 1.5,
                        shadows: isActive
                            ? [
                                Shadow(
                                  color: const Color(
                                    0xFF06B6D4,
                                  ).withOpacity(0.8),
                                  blurRadius: 15,
                                ),
                              ]
                            : [],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
