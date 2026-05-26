import '../utils/no_anim_route.dart';
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
      NoAnimRoute(
        page: Scaffold(
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0A2249), Color(0xFF133F85)],
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
                onBack: () => Navigator.pop(context, "HOME"),
                isEnglish: widget.isEnglish,
              ),
            ),
          ),
        ),
      ),
    );
    if (result == "HOME" && mounted) widget.onBack();
  }

  void _showDisabledDialog({required String title, required String message, required IconData icon, required Color color}) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: const Color(0xFF0D1B3E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: color.withValues(alpha: 0.6), width: 1.5),
        ),
        title: Row(
          children: [
            Icon(icon, color: color, size: 30),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(fontSize: 15, color: Colors.white70, height: 1.5),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: color.withValues(alpha: 0.15),
              foregroundColor: color,
              side: BorderSide(color: color.withValues(alpha: 0.5)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(c),
            child: Text(
              widget.isEnglish ? "OK, UNDERSTOOD" : "OK, FAHAM",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
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
              color: Colors.lightBlueAccent,
            ),
            label: Text(
              widget.isEnglish ? "Back" : "Kembali",
              style: const TextStyle(fontSize: 18, color: Colors.lightBlueAccent),
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
                      color: Colors.lightBlueAccent.withValues(alpha: 0.5),
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
                  const SizedBox(width: 60),
                  SizedBox(
                    width: 320,
                    height: 300,
                    child: widget.isGuest
                        ? Opacity(
                            opacity: 0.45,
                            child: _GlassBentoCard(
                              title: widget.isEnglish
                                  ? "SCHEDULE\nAPPOINTMENT"
                                  : "JADUAL\nTEMU JANJI",
                              icon: Icons.calendar_month_rounded,
                              onTap: () => _showDisabledDialog(
                                title: widget.isEnglish ? 'Access Restricted' : 'Akses Terhad',
                                message: widget.isEnglish
                                    ? 'This feature requires an official UniMAP Student Account.\n\nPlease scan your Student ID card at the login portal to continue.'
                                    : 'Ciri ini memerlukan Akaun Pelajar UniMAP rasmi.\n\nSila imbas kad ID pelajar anda di portal log masuk untuk meneruskan.',
                                icon: Icons.lock_outline_rounded,
                                color: Colors.lightBlueAccent,
                              ),
                            ),
                          )
                        : _GlassBentoCard(
                            title: widget.isEnglish
                                ? "SCHEDULE\nAPPOINTMENT"
                                : "JADUAL\nTEMU JANJI",
                            icon: Icons.calendar_month_rounded,
                            onTap: _navigateToAppointment,
                          ),
                  ),
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
          transform: Matrix4.diagonal3Values(_isPressed ? 0.96 : 1.0, _isPressed ? 0.96 : 1.0, 1.0),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: Container(
                decoration: BoxDecoration(
                  color: isActive
                      ? Colors.lightBlue.withValues(alpha: 0.08)
                      : Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: isActive
                        ? const Color(0xFF0EA5E9)
                        : Colors.white.withValues(alpha: 0.1),
                    width: 1,
                  ),
                  boxShadow: isActive
                      ? [
                          BoxShadow(
                            color: const Color(
                              0xFF0EA5E9,
                            ).withValues(alpha: 0.4),
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
                            ? Colors.lightBlueAccent.withValues(alpha: 0.15)
                            : Colors.transparent,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        widget.icon,
                        size: 90,
                        color: isActive
                            ? const Color(0xFF0EA5E9)
                            : Colors.white70,
                        shadows: isActive
                            ? [
                                Shadow(
                                  color: const Color(
                                    0xFF0EA5E9,
                                  ).withValues(alpha: 0.8),
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
                                    0xFF0EA5E9,
                                  ).withValues(alpha: 0.8),
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
