import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Service for handling user support requests and contact methods
class ContactSupportService {
  static final ContactSupportService _instance = ContactSupportService._internal();
  factory ContactSupportService() => _instance;
  ContactSupportService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Support contact information
  static const String supportEmail = 'support@swastik.app';
  static const String supportPhone = '+91-9876543210';
  static const String supportWhatsApp = '+91-9876543210';
  static const String supportWebsite = 'https://swastik.app/support';

  /// Show support options dialog
  static Future<void> showSupportOptions(BuildContext context) async {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Contact Support'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('How would you like to contact us?'),
              const SizedBox(height: 16),
              _buildSupportOption(
                context,
                icon: Icons.email,
                title: 'Email Support',
                subtitle: supportEmail,
                onTap: () => _openEmail(context),
              ),
              _buildSupportOption(
                context,
                icon: Icons.phone,
                title: 'Call Support',
                subtitle: supportPhone,
                onTap: () => _makePhoneCall(context),
              ),
              _buildSupportOption(
                context,
                icon: Icons.chat,
                title: 'WhatsApp',
                subtitle: 'Chat with us',
                onTap: () => _openWhatsApp(context),
              ),
              _buildSupportOption(
                context,
                icon: Icons.web,
                title: 'Help Center',
                subtitle: 'Visit our website',
                onTap: () => _openWebsite(context),
              ),
              _buildSupportOption(
                context,
                icon: Icons.bug_report,
                title: 'Report Issue',
                subtitle: 'Submit a bug report',
                onTap: () => _showReportIssueDialog(context),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  /// Build support option widget
  static Widget _buildSupportOption(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).primaryColor),
      title: Text(title),
      subtitle: Text(subtitle),
      onTap: () {
        Navigator.of(context).pop();
        onTap();
      },
    );
  }

  /// Open email client
  static Future<void> _openEmail(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    final subject = Uri.encodeComponent('Swastik App Support Request');
    final body = Uri.encodeComponent(
      'Hi Swastik Support Team,\n\n'
      'I need help with:\n\n'
      '[Please describe your issue here]\n\n'
      'User ID: ${user?.uid ?? 'Not logged in'}\n'
      'Email: ${user?.email ?? 'Not provided'}\n'
      'App Version: 1.0.0\n'
      'Platform: ${defaultTargetPlatform.name}\n'
    );

    final emailUrl = 'mailto:$supportEmail?subject=$subject&body=$body';

    try {
      if (await canLaunchUrl(Uri.parse(emailUrl))) {
        await launchUrl(Uri.parse(emailUrl));
      } else {
        _showFallbackDialog(context, 'Email', supportEmail);
      }
    } catch (e) {
      _showFallbackDialog(context, 'Email', supportEmail);
    }
  }

  /// Make phone call
  static Future<void> _makePhoneCall(BuildContext context) async {
    final phoneUrl = 'tel:$supportPhone';

    try {
      if (await canLaunchUrl(Uri.parse(phoneUrl))) {
        await launchUrl(Uri.parse(phoneUrl));
      } else {
        _showFallbackDialog(context, 'Phone', supportPhone);
      }
    } catch (e) {
      _showFallbackDialog(context, 'Phone', supportPhone);
    }
  }

  /// Open WhatsApp
  static Future<void> _openWhatsApp(BuildContext context) async {
    final message = Uri.encodeComponent(
      'Hi! I need help with the Swastik app.'
    );
    final whatsappUrl = 'https://wa.me/$supportWhatsApp?text=$message';

    try {
      if (await canLaunchUrl(Uri.parse(whatsappUrl))) {
        await launchUrl(Uri.parse(whatsappUrl));
      } else {
        _showFallbackDialog(context, 'WhatsApp', supportWhatsApp);
      }
    } catch (e) {
      _showFallbackDialog(context, 'WhatsApp', supportWhatsApp);
    }
  }

  /// Open support website
  static Future<void> _openWebsite(BuildContext context) async {
    try {
      if (await canLaunchUrl(Uri.parse(supportWebsite))) {
        await launchUrl(Uri.parse(supportWebsite));
      } else {
        _showFallbackDialog(context, 'Website', supportWebsite);
      }
    } catch (e) {
      _showFallbackDialog(context, 'Website', supportWebsite);
    }
  }

  /// Show report issue dialog
  static Future<void> _showReportIssueDialog(BuildContext context) async {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Report Issue'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Issue Title',
                    hintText: 'Brief description of the problem',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a title';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    hintText: 'Detailed description of the issue',
                  ),
                  maxLines: 4,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a description';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  Navigator.of(context).pop();
                  await _submitIssueReport(
                    context,
                    titleController.text.trim(),
                    descriptionController.text.trim(),
                  );
                }
              },
              child: const Text('Submit'),
            ),
          ],
        );
      },
    );
  }

  /// Submit issue report to Firestore
  static Future<void> _submitIssueReport(
    BuildContext context,
    String title,
    String description,
  ) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final instance = ContactSupportService();

      await instance._firestore.collection('support_tickets').add({
        'title': title,
        'description': description,
        'userId': user?.uid,
        'userEmail': user?.email,
        'status': 'open',
        'priority': 'normal',
        'category': 'bug_report',
        'platform': defaultTargetPlatform.name,
        'appVersion': '1.0.0',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Issue reported successfully! We\'ll get back to you soon.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to submit issue report: $e');
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to submit report. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Show fallback dialog when URL launching fails
  static void _showFallbackDialog(
    BuildContext context,
    String method,
    String contact,
  ) {
    showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('$method Not Available'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Unable to open $method app. You can contact us at:'),
              const SizedBox(height: 8),
              SelectableText(
                contact,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: contact));
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Contact info copied to clipboard')),
                  );
                },
                child: const Text('Copy to Clipboard'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  /// Get support tickets for a user
  static Future<List<Map<String, dynamic>>> getUserSupportTickets(String userId) async {
    try {
      final instance = ContactSupportService();
      final snapshot = await instance._firestore
          .collection('support_tickets')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to get support tickets: $e');
      }
      return [];
    }
  }

  /// Quick contact methods
  static Future<void> quickEmail() async {
    final emailUrl = 'mailto:$supportEmail';
    if (await canLaunchUrl(Uri.parse(emailUrl))) {
      await launchUrl(Uri.parse(emailUrl));
    }
  }

  static Future<void> quickCall() async {
    final phoneUrl = 'tel:$supportPhone';
    if (await canLaunchUrl(Uri.parse(phoneUrl))) {
      await launchUrl(Uri.parse(phoneUrl));
    }
  }

  static Future<void> quickWhatsApp() async {
    final whatsappUrl = 'https://wa.me/$supportWhatsApp';
    if (await canLaunchUrl(Uri.parse(whatsappUrl))) {
      await launchUrl(Uri.parse(whatsappUrl));
    }
  }
}