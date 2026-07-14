import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../shared/widgets/error/index.dart';
import '../../../shared/models/user_role.dart';

/// Enhanced authentication error handler with user-specific error messages
class AuthErrorHandler {
  /// Handle authentication errors with user-specific context
  static String handleAuthError(
    dynamic error, {
    UserRole? userRole,
    String? context,
  }) {
    if (error is FirebaseAuthException) {
      return _handleFirebaseAuthError(
        error,
        userRole: userRole,
        context: context,
      );
    }

    if (error is String) {
      return error;
    }

    return 'An unexpected authentication error occurred. Please try again.';
  }

  /// Handle Firebase Auth specific errors with role context
  static String _handleFirebaseAuthError(
    FirebaseAuthException e, {
    UserRole? userRole,
    String? context,
  }) {
    final baseMessage = _getBaseErrorMessage(e);

    // Add role-specific context if available
    if (userRole != null && context != null) {
      return _addRoleContext(baseMessage, userRole, context);
    }

    return baseMessage;
  }

  /// Get base error message for Firebase Auth errors
  static String _getBaseErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'weak-password':
        return 'The password provided is too weak. Please use at least 6 characters with a mix of letters and numbers.';
      case 'email-already-in-use':
        return 'An account already exists for that email address. Please sign in instead or use a different email.';
      case 'invalid-email':
        return 'The email address is not valid. Please check the format and try again.';
      case 'operation-not-allowed':
        return 'Email/password accounts are not enabled. Please contact support.';
      case 'user-disabled':
        return 'This user account has been disabled. Please contact support for assistance.';
      case 'user-not-found':
        return 'No account found for that email address. Please check your email or sign up for a new account.';
      case 'wrong-password':
        return 'Incorrect password. Please check your password and try again.';
      case 'invalid-verification-code':
        return 'The verification code is invalid. Please check the code and try again.';
      case 'invalid-verification-id':
        return 'The verification ID is invalid. Please restart the verification process.';
      case 'account-exists-with-different-credential':
        return 'An account already exists with the same email but different sign-in method. Please use the original sign-in method.';
      case 'invalid-credential':
        return 'The sign-in credentials are invalid or have expired. Please try signing in again.';
      case 'credential-already-in-use':
        return 'This credential is already associated with a different user account.';
      case 'network-request-failed':
        return 'Network error. Please check your internet connection and try again.';
      case 'too-many-requests':
        return 'Too many failed attempts. Please wait a few minutes before trying again.';
      case 'requires-recent-login':
        return 'This operation requires recent authentication. Please sign out and sign in again.';
      case 'session-cookie-expired':
        return 'Your session has expired. Please sign in again.';
      case 'insufficient-permission':
        return 'You don\'t have permission to perform this action. Please contact an administrator.';
      default:
        return e.message ??
            'An authentication error occurred. Please try again.';
    }
  }

  /// Add role-specific context to error messages
  static String _addRoleContext(
    String baseMessage,
    UserRole userRole,
    String context,
  ) {
    switch (context) {
      case 'admin_access':
        if (userRole.isUser) {
          return '$baseMessage\n\nNote: You are signed in as a regular user. Admin features require administrator privileges.';
        }
        break;
      case 'user_access':
        if (userRole.isAdmin) {
          return '$baseMessage\n\nNote: You are signed in as an administrator. Please use the admin interface for management tasks.';
        }
        break;
      case 'role_verification':
        return '$baseMessage\n\nIf you believe your account role is incorrect, please contact support.';
    }

    return baseMessage;
  }

  /// Show authentication error dialog with appropriate styling and actions
  static Future<void> showAuthErrorDialog(
    BuildContext context, {
    required String error,
    UserRole? userRole,
    String? errorContext,
    VoidCallback? onRetry,
    VoidCallback? onContactSupport,
  }) async {
    final processedError = handleAuthError(
      error,
      userRole: userRole,
      context: errorContext,
    );

    await ErrorHandler.showErrorDialog(
      context: context,
      title: _getErrorTitle(errorContext),
      message: processedError,
      type: _getErrorType(error),
      onRetry: onRetry,
    );
  }

  /// Get appropriate error dialog title based on context
  static String _getErrorTitle(String? context) {
    switch (context) {
      case 'admin_access':
        return 'Admin Access Required';
      case 'user_access':
        return 'User Access Issue';
      case 'role_verification':
        return 'Account Role Issue';
      case 'session_expired':
        return 'Session Expired';
      case 'network_error':
        return 'Connection Error';
      default:
        return 'Authentication Error';
    }
  }

  /// Get error type for appropriate styling
  static ErrorDisplayType _getErrorType(dynamic error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'network-request-failed':
        case 'too-many-requests':
          return ErrorDisplayType.network;
        case 'weak-password':
        case 'invalid-email':
        case 'requires-recent-login':
          return ErrorDisplayType.warning;
        case 'insufficient-permission':
        case 'user-disabled':
          return ErrorDisplayType.error;
        default:
          return ErrorDisplayType.error;
      }
    }
    return ErrorDisplayType.error;
  }

  /// Check if error requires immediate sign out for security
  static bool requiresSignOut(dynamic error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'user-disabled':
        case 'session-cookie-expired':
        case 'insufficient-permission':
          return true;
        default:
          return false;
      }
    }
    return false;
  }

  /// Get user-friendly error message for role-based access issues
  static String getRoleAccessError(UserRole userRole, String attemptedAction) {
    if (userRole.isUser) {
      return 'This feature is only available to administrators. '
          'You are currently signed in as a regular user. '
          'If you need admin access, please contact your administrator.';
    } else {
      return 'This feature is designed for regular users. '
          'As an administrator, please use the admin interface '
          'for management tasks.';
    }
  }
}
