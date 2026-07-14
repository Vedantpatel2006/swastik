import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Helper class for managing email verification
class EmailVerificationHelper {
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Check if current user's email is verified
  static bool get isCurrentUserEmailVerified {
    final user = _auth.currentUser;
    return user?.emailVerified ?? false;
  }

  /// Get current user's email
  static String? get currentUserEmail {
    return _auth.currentUser?.email;
  }

  /// Send verification email to current user
  static Future<bool> sendVerificationEmail() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        if (kDebugMode) {
          debugPrint('EmailVerificationHelper: No user signed in');
        }
        return false;
      }

      if (user.emailVerified) {
        if (kDebugMode) {
          debugPrint('EmailVerificationHelper: Email already verified');
        }
        return true;
      }

      await user.sendEmailVerification();
      if (kDebugMode) {
        debugPrint('EmailVerificationHelper: Verification email sent to ${user.email}');
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('EmailVerificationHelper: Error sending verification email - $e');
      }
      return false;
    }
  }

  /// Reload user to check latest email verification status
  static Future<bool> reloadAndCheckVerification() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      await user.reload();
      final updatedUser = _auth.currentUser;
      
      if (kDebugMode) {
        debugPrint('EmailVerificationHelper: Email verified status: ${updatedUser?.emailVerified}');
      }
      
      return updatedUser?.emailVerified ?? false;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('EmailVerificationHelper: Error reloading user - $e');
      }
      return false;
    }
  }

  /// Check if user needs to verify email before accessing features
  static bool shouldBlockUserAccess() {
    final user = _auth.currentUser;
    if (user == null) return true; // Block if not signed in
    return !user.emailVerified; // Block if email not verified
  }

  /// Get user-friendly message for email verification status
  static String getVerificationStatusMessage() {
    final user = _auth.currentUser;
    if (user == null) {
      return 'Please sign in to continue';
    }
    
    if (user.emailVerified) {
      return 'Email verified successfully';
    }
    
    return 'Please verify your email address (${user.email}) to continue';
  }
}