import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';

/// Enhanced error recovery utilities with production monitoring
class ErrorRecoveryUtils {
  static const String _logTag = 'ErrorRecoveryUtils';
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Handle YouTube API errors gracefully
  static String getYouTubeErrorMessage(dynamic error) {
    if (error.toString().contains('API key expired')) {
      return 'Live streaming temporarily unavailable. Please check back later.';
    } else if (error.toString().contains('quota')) {
      return 'Live streaming service is busy. Please try again in a few minutes.';
    } else if (error.toString().contains('network')) {
      return 'Please check your internet connection and try again.';
    }
    return 'Live streaming temporarily unavailable.';
  }

  /// Handle Firestore permission errors
  static String getFirestoreErrorMessage(dynamic error) {
    if (error.toString().contains('permission-denied')) {
      return 'Access denied. Please make sure you are logged in.';
    } else if (error.toString().contains('failed-precondition')) {
      return 'Service is being updated. Please try again in a moment.';
    } else if (error.toString().contains('unavailable')) {
      return 'Service temporarily unavailable. Please try again later.';
    }
    return 'Unable to load data. Please try again.';
  }

  /// Handle Stripe payment errors
  static String getStripeErrorMessage(dynamic error) {
    if (error.toString().contains('FlutterFragmentActivity')) {
      return 'Payment system is being updated. Please try alternative payment methods.';
    }
    return 'Payment service temporarily unavailable.';
  }

  /// Log errors for debugging while showing user-friendly messages
  static void logAndShowError(
    String context,
    dynamic error, [
    String? userMessage,
  ]) {
    if (kDebugMode) {
      debugPrint('[$context] Error: $error');
    }

    // In production, you might want to send this to a crash reporting service
    // like Firebase Crashlytics or Sentry
  }

  /// Check if error is recoverable (user can retry)
  static bool isRecoverableError(dynamic error) {
    final errorString = error.toString().toLowerCase();

    // Network errors are usually recoverable
    if (errorString.contains('network') ||
        errorString.contains('timeout') ||
        errorString.contains('connection')) {
      return true;
    }

    // Temporary service issues are recoverable
    if (errorString.contains('unavailable') ||
        errorString.contains('busy') ||
        errorString.contains('quota')) {
      return true;
    }

    // Permission and configuration errors are not recoverable by user
    if (errorString.contains('permission') ||
        errorString.contains('expired') ||
        errorString.contains('invalid')) {
      return false;
    }

    return true; // Default to recoverable
  }

  /// PRODUCTION ENHANCEMENT: Recover from authentication errors
  static Future<bool> recoverFromAuthError(dynamic error) async {
    try {
      final errorStr = error.toString().toLowerCase();

      if (errorStr.contains('network') || errorStr.contains('connection')) {
        // Wait for network recovery
        return await _waitForNetworkRecovery();
      }

      if (errorStr.contains('token') || errorStr.contains('expired')) {
        // Refresh authentication token
        return await _refreshAuthToken();
      }

      if (errorStr.contains('permission') ||
          errorStr.contains('unauthorized')) {
        // Re-verify user permissions
        return await _reverifyUserPermissions();
      }

      return false;
    } catch (e) {
      _logError('Auth recovery failed', e);
      return false;
    }
  }

  /// PRODUCTION ENHANCEMENT: Recover from payment errors
  static Future<bool> recoverFromPaymentError(
    dynamic error, {
    String? paymentIntentId,
    String? userId,
  }) async {
    try {
      final errorStr = error.toString().toLowerCase();

      // Log payment error for security monitoring
      await _logSecurityEvent('payment_error', {
        'error': errorStr,
        'paymentIntentId': paymentIntentId,
        'userId': userId,
        'timestamp': DateTime.now().toIso8601String(),
      });

      if (errorStr.contains('network') || errorStr.contains('timeout')) {
        // Verify payment status server-side
        return await _verifyPaymentStatus(paymentIntentId);
      }

      if (errorStr.contains('card') || errorStr.contains('declined')) {
        // Payment method issue - no recovery possible
        return false;
      }

      if (errorStr.contains('insufficient')) {
        // Insufficient funds - no recovery possible
        return false;
      }

      return false;
    } catch (e) {
      _logError('Payment recovery failed', e);
      return false;
    }
  }

  /// PRODUCTION ENHANCEMENT: Wait for network recovery with timeout
  static Future<bool> _waitForNetworkRecovery({
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final connectivity = Connectivity();
    final completer = Completer<bool>();

    // Set timeout
    Timer(timeout, () {
      if (!completer.isCompleted) {
        completer.complete(false);
      }
    });

    // Listen for connectivity changes
    final subscription = connectivity.onConnectivityChanged.listen((result) {
      if (result != ConnectivityResult.none && !completer.isCompleted) {
        completer.complete(true);
      }
    });

    // Check current connectivity
    final currentConnectivity = await connectivity.checkConnectivity();
    if (currentConnectivity != ConnectivityResult.none &&
        !completer.isCompleted) {
      completer.complete(true);
    }

    final recovered = await completer.future;
    await subscription.cancel();

    return recovered;
  }

  /// PRODUCTION ENHANCEMENT: Refresh authentication token
  static Future<bool> _refreshAuthToken() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      await user.reload();
      final token = await user.getIdToken(true); // Force refresh

      return token?.isNotEmpty ?? false;
    } catch (e) {
      _logError('Token refresh failed', e);
      return false;
    }
  }

  /// PRODUCTION ENHANCEMENT: Re-verify user permissions
  static Future<bool> _reverifyUserPermissions() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      // Check if user document still exists and has valid role
      final userDoc = await _firestore.collection('users').doc(user.uid).get();

      if (!userDoc.exists) {
        // User document missing - sign out for security
        await _auth.signOut();
        return false;
      }

      final userData = userDoc.data() ?? {};
      final role = userData['role'] as String?;

      // Verify role is valid
      return role != null && ['user', 'admin'].contains(role);
    } catch (e) {
      _logError('Permission verification failed', e);
      return false;
    }
  }

  /// PRODUCTION ENHANCEMENT: Verify payment status server-side
  static Future<bool> _verifyPaymentStatus(String? paymentIntentId) async {
    if (paymentIntentId == null) return false;

    try {
      // Check if payment was completed in Firestore
      final donations = await _firestore
          .collection('donations')
          .where('paymentIntentId', isEqualTo: paymentIntentId)
          .where('status', isEqualTo: 'completed')
          .get();

      return donations.docs.isNotEmpty;
    } catch (e) {
      _logError('Payment status verification failed', e);
      return false;
    }
  }

  /// PRODUCTION ENHANCEMENT: Log security events for monitoring
  static Future<void> _logSecurityEvent(
    String eventType,
    Map<String, dynamic> details,
  ) async {
    try {
      await _firestore.collection('security_logs').add({
        'type': eventType,
        'details': details,
        'timestamp': FieldValue.serverTimestamp(),
        'userId': _auth.currentUser?.uid,
        'source': 'client_error_recovery',
      });
    } catch (e) {
      _logError('Security event logging failed', e);
    }
  }

  /// PRODUCTION ENHANCEMENT: Log errors for debugging
  static void _logError(String context, dynamic error) {
    if (kDebugMode) {
      debugPrint('$_logTag: [$context] $error');
    }
  }

  /// PRODUCTION ENHANCEMENT: Comprehensive error recovery strategy
  static Future<bool> recoverFromError(
    dynamic error, {
    String? context,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final errorStr = error.toString().toLowerCase();

      // Log error for monitoring
      await _logSecurityEvent('error_recovery_attempt', {
        'context': context,
        'error': errorStr,
        'metadata': metadata,
      });

      // Try different recovery strategies based on error type
      if (errorStr.contains('auth') || errorStr.contains('permission')) {
        return await recoverFromAuthError(error);
      }

      if (errorStr.contains('payment') || errorStr.contains('stripe')) {
        return await recoverFromPaymentError(
          error,
          paymentIntentId: metadata?['paymentIntentId'],
          userId: metadata?['userId'],
        );
      }

      if (errorStr.contains('network') || errorStr.contains('connection')) {
        return await _waitForNetworkRecovery();
      }

      return false;
    } catch (e) {
      _logError('General error recovery failed', e);
      return false;
    }
  }
}
