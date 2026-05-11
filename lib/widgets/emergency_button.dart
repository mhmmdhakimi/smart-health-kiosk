import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class EmergencyHelpButton extends StatelessWidget {
  final bool isEnglish;
  final String? customText;
  final String patientName;
  final String patientId;
  final String location;

  const EmergencyHelpButton({
    super.key, 
    required this.isEnglish, 
    this.customText,
    this.patientName = 'UNKNOWN / PRE-LOGIN',
    this.patientId = 'N/A',
    this.location = 'Kiosk Login Page',
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: SizedBox(
        width: customText != null ? 380 : 280, 
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red.shade600, 
            foregroundColor: Colors.white, 
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)), 
            elevation: 3
          ),
          icon: const Icon(Icons.emergency, size: 22), 
          label: Text(
            customText ?? (isEnglish ? "EMERGENCY HELP" : "BANTUAN KECEMASAN"), 
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.2)
          ),
          onPressed: () async {
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
                  backgroundColor: Colors.red.shade50,
                  title: Row(children: [const Icon(Icons.warning, color: Colors.red, size: 40), const SizedBox(width: 10), Text(isEnglish ? "EMERGENCY" : "KECEMASAN", style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold))]),
                  content: Text(isEnglish ? "Staff have been notified. Please remain at the kiosk. Help is on the way." : "Kakitangan telah dimaklumkan. Sila kekal di kiosk. Bantuan sedang dalam perjalanan.", style: const TextStyle(fontSize: 18)),
                  actions: [TextButton(onPressed: () => Navigator.pop(c), child: Text(isEnglish ? "DISMISS" : "TUTUP"))],
                ),
              );
            }
          },
        ),
      ),
    );
  }
}