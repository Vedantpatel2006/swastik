import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Utility class for providing success feedback to users
class SuccessFeedbackUtils {
  /// Shows a success snackbar with haptic feedback
  static void showSuccessSnackbar(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
    bool includeHapticFeedback = true,
  }) {
    if (includeHapticFeedback) {
      HapticFeedback.lightImpact();
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(message, style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
        backgroundColor: Colors.green,
        duration: duration,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  /// Shows a success dialog with haptic feedback
  static Future<void> showSuccessDialog(
    BuildContext context,
    String title,
    String message, {
    bool includeHapticFeedback = true,
  }) async {
    if (includeHapticFeedback) {
      HapticFeedback.lightImpact();
    }

    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 24),
              const SizedBox(width: 8),
              Text(title),
            ],
          ),
          content: Text(message),
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
}
