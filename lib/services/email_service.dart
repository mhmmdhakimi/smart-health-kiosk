import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../core/config.dart';

Future<void> sendEmailJSEmail({
  required String templateId,
  required Map<String, dynamic> templateParams,
}) async {
  final url = Uri.parse('https://api.emailjs.com/api/v1.0/email/send');
  
  try {
    final response = await http.post(
      url,
      headers: {
        'origin': 'http://localhost',
        'Content-Type': 'application/json',
      },
      body: json.encode({
        'service_id': AppConfig.emailJsServiceId,
        'template_id': templateId,
        'user_id': AppConfig.emailJsPublicKey,
        'template_params': templateParams,
      }),
    );
    
    if (response.statusCode == 200) {
      debugPrint("Email successfully sent via EmailJS (Template: $templateId)");
    } else {
      debugPrint("EmailJS Error: ${response.body}");
    }
  } catch (e) {
    debugPrint("Failed to send email: $e");
  }
}