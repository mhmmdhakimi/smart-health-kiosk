import re

def process_file():
    with open('lib/screens/kiosk_dashboard.dart', 'r', encoding='utf-8') as f:
        content = f.read()

    # 1. Update _autoLogOut
    auto_logout_old = """  void _autoLogOut() {
    _idleTimer?.cancel();
    _warningTimer?.cancel();

    FirebaseDatabase.instance.ref('kiosk_control/session_active').set(false);

    if (_isWarningDialogVisible && mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }
    Navigator.pushAndRemoveUntil(
      context,
      NoAnimRoute(page: const LanguageSelectionPage()),
      (r) => false,
    );
  }"""
    
    auto_logout_new = """  void _autoLogOut() {
    _idleTimer?.cancel();
    _warningTimer?.cancel();

    FirebaseDatabase.instance.ref('kiosk_control/session_active').set(false);

    if (mounted) {
      // Reset all nested state layout variables explicitly
      setState(() {
        _currentView = "HOME";
        _isCheckupActive = false;
        _isWarningDialogVisible = false;
      });

      // Cleanly close active context overlays to clear potential background dialog leakages
      while (Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    }

    Navigator.pushAndRemoveUntil(
      context,
      NoAnimRoute(page: const LanguageSelectionPage()),
      (r) => false,
    );
  }"""
    
    content = content.replace(auto_logout_old, auto_logout_new)

    # 2. Update GlassBentoCard
    glass_bento_old = """              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: _isPressed
                      ? const Color(0xFF06B6D4)
                      : Colors.white.withOpacity(0.1),
                  width: _isPressed ? 2 : 1,
                ),"""
                
    glass_bento_new = """              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: _isPressed
                      ? const Color(0xFF06B6D4)
                      : const Color(0xFF1E293B),
                  width: _isPressed ? 2.0 : 1.0,
                ),"""
    
    content = content.replace(glass_bento_old, glass_bento_new)

    # 3. Update _buildHome completely
    # We will split content at 'Widget _buildHome() {' and find where the method ends
    build_home_start_idx = content.find('  Widget _buildHome() {')
    
    build_home_end_str = '        ),\n      ],\n    );\n  }'
    build_home_end_idx = content.find(build_home_end_str, build_home_start_idx) + len(build_home_end_str)
    
    build_home_new = """  Widget _buildBentoCard({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isRestricted = false,
  }) {
    Widget card = GlassBentoCard(
      icon: icon,
      title: title,
      onTap: isRestricted
          ? () {
              showDialog(
                context: context,
                builder: (c) => AlertDialog(
                  backgroundColor: const Color(0xFF111827),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                    side: const BorderSide(color: Colors.cyanAccent),
                  ),
                  title: Row(
                    children: [
                      const Icon(Icons.lock, color: Colors.cyanAccent, size: 30),
                      const SizedBox(width: 10),
                      Text(
                        widget.isEnglish ? "Access Restricted" : "Akses Terhad",
                        style: const TextStyle(
                          color: Colors.cyanAccent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  content: Text(
                    widget.isEnglish
                        ? "This feature requires an official UniMAP Student Account. Please scan your student ID badge at the login portal to continue."
                        : "Ciri ini memerlukan Akaun Pelajar UniMAP rasmi. Sila imbas kad ID pelajar anda di portal log masuk untuk meneruskan.",
                    style: const TextStyle(fontSize: 16, color: Colors.white),
                  ),
                  actions: [
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.cyanAccent.withOpacity(0.2),
                        foregroundColor: Colors.cyanAccent,
                        side: const BorderSide(color: Colors.cyanAccent),
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
          : onTap,
    );

    if (isRestricted) {
      return Opacity(
        opacity: 0.45,
        child: card,
      );
    }
    return card;
  }

  Widget _buildHome() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 30.0),
          child: Column(
            children: [
              Text(
                widget.isEnglish
                    ? 'WELCOME, ${widget.userName.toUpperCase()}!'
                    : 'SELAMAT DATANG, ${widget.userName.toUpperCase()}!',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  shadows: [
                    Shadow(
                      color: Colors.cyanAccent.withOpacity(0.5),
                      blurRadius: 10,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                widget.isEnglish
                    ? 'PLEASE CHOOSE AN OPTION BELOW TO BEGIN.'
                    : 'SILA PILIH PILIHAN DI BAWAH UNTUK BERMULA.',
                style: const TextStyle(
                  fontSize: 18,
                  color: Colors.white70,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Column(
            children: [
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _buildBentoCard(
                        icon: Icons.monitor_heart_outlined,
                        title: widget.isEnglish
                            ? 'SELF-CHECKUP'
                            : 'PEMERIKSAAN\\nKENDIRI',
                        onTap: () =>
                            setState(() => _currentView = "SELF_CHECKUP"),
                        isRestricted: false,
                      ),
                    ),
                    const SizedBox(width: 25),
                    Expanded(
                      child: _buildBentoCard(
                        icon: Icons.person_search_outlined,
                        title: widget.isEnglish
                            ? 'MEDICAL\\nCONSULTATION'
                            : 'RUNDINGAN\\nPERUBATAN',
                        onTap: () => setState(
                          () => _currentView = "SEE_DOCTOR_OPT",
                        ),
                        isRestricted: widget.isGuest,
                      ),
                    ),
                    const SizedBox(width: 25),
                    Expanded(
                      child: _buildBentoCard(
                        icon: Icons.wheelchair_pickup_outlined,
                        title: widget.isEnglish
                            ? 'MEDICAL EQUIPMENT\\nRESERVATION'
                            : 'TEMPAHAN PERALATAN\\nPERUBATAN',
                        onTap: () =>
                            setState(() => _currentView = "EQUIP_RES"),
                        isRestricted: widget.isGuest,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 25),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _buildBentoCard(
                        icon: widget.isGuest ? Icons.directions_walk_outlined : Icons.history_outlined,
                        title: widget.isGuest
                            ? (widget.isEnglish ? 'WALK-IN' : 'WALK-IN (TIDAK\\nBERJADUAL)')
                            : (widget.isEnglish ? 'HEALTH RECORD' : 'REKOD KESIHATAN'),
                        onTap: () =>
                            setState(() => _currentView = widget.isGuest ? "WALK_IN_TRIAGE" : "CHECKUP_HIST"),
                        isRestricted: false,
                      ),
                    ),
                    const SizedBox(width: 25),
                    Expanded(
                      child: _buildBentoCard(
                        icon: Icons.event_available_outlined,
                        title: widget.isEnglish
                            ? 'APPOINTMENT'
                            : 'TEMU JANJI',
                        onTap: () =>
                            setState(() => _currentView = "APPT_HIST"),
                        isRestricted: widget.isGuest,
                      ),
                    ),
                    const SizedBox(width: 25),
                    Expanded(
                      child: _buildBentoCard(
                        icon: Icons.biotech_outlined,
                        title: widget.isEnglish
                            ? 'RESERVATION\\nSTATUS'
                            : 'STATUS\\nTEMPAHAN',
                        onTap: () =>
                            setState(() => _currentView = "EQUIP_HIST"),
                        isRestricted: widget.isGuest,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }"""

    new_content = content[:build_home_start_idx] + build_home_new + content[build_home_end_idx:]

    with open('lib/screens/kiosk_dashboard.dart', 'w', encoding='utf-8') as f:
        f.write(new_content)

if __name__ == "__main__":
    process_file()
