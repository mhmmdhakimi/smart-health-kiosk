import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class EmergencyHelpButton extends StatelessWidget {
  final bool isEnglish;
  final String? customText;
  final String patientName;
  final String patientId;
  final String location;
  final bool isCompact;

  const EmergencyHelpButton({
    super.key, 
    required this.isEnglish, 
    this.customText,
    this.patientName = 'UNKNOWN / PRE-LOGIN',
    this.patientId = 'N/A',
    this.location = 'Kiosk Login Page',
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    VoidCallback handleEmergency = () async {
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
            backgroundColor: const Color(0xFF111827),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: Colors.red.withOpacity(0.5), width: 1),
            ),
            title: Row(children: [const Icon(Icons.warning, color: Colors.redAccent, size: 40), const SizedBox(width: 10), Text(isEnglish ? "EMERGENCY" : "KECEMASAN", style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold))]),
            content: Text(isEnglish ? "Staff have been notified. Please remain at the kiosk. Help is on the way." : "Kakitangan telah dimaklumkan. Sila kekal di kiosk. Bantuan sedang dalam perjalanan.", style: const TextStyle(fontSize: 18, color: Colors.white70)),
            actions: [TextButton(onPressed: () => Navigator.pop(c), child: Text(isEnglish ? "DISMISS" : "TUTUP", style: const TextStyle(color: Colors.redAccent)))],
          ),
        );
      }
    };

    if (isCompact) {
      return OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          side: BorderSide(color: Colors.redAccent.withOpacity(0.5), width: 1),
          backgroundColor: Colors.redAccent.withOpacity(0.1),
          foregroundColor: Colors.redAccent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
        icon: const Icon(Icons.emergency),
        label: Text(
          customText ?? (isEnglish ? "EMERGENCY" : "KECEMASAN"), 
          style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)
        ),
        onPressed: handleEmergency,
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Container(
        width: customText != null ? 380 : 280, 
        height: 60,
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.15),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Colors.red.withOpacity(0.5), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.red.withOpacity(0.2),
              blurRadius: 10,
              spreadRadius: 2,
            )
          ]
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(30),
            onTap: handleEmergency,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.emergency, color: Colors.redAccent, size: 22), 
                const SizedBox(width: 8),
                Text(
                  customText ?? (isEnglish ? "EMERGENCY HELP" : "BANTUAN KECEMASAN"), 
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: Colors.redAccent)
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}