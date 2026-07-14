import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'auth_provider.dart';
import '../shared/models/user_role.dart';

/// Optimized selectors for AuthProvider to minimize widget rebuilds
/// These selectors allow widgets to listen only to specific parts of the auth state
class AuthSelectors {
  /// Selector for authentication status only
  static bool isAuthenticated(BuildContext context) {
    return context.select<AuthProvider, bool>((auth) => auth.isAuthenticated);
  }

  /// Selector for loading state only
  static bool isLoading(BuildContext context) {
    return context.select<AuthProvider, bool>((auth) => auth.isLoading);
  }

  /// Selector for error state only
  static bool hasError(BuildContext context) {
    return context.select<AuthProvider, bool>((auth) => auth.hasError);
  }

  /// Selector for error message only
  static String? errorMessage(BuildContext context) {
    return context.select<AuthProvider, String?>((auth) => auth.errorMessage);
  }

  /// Selector for current user only
  static String? currentUserId(BuildContext context) {
    return context.select<AuthProvider, String?>(
      (auth) => auth.currentUser?.uid,
    );
  }

  /// Selector for user email only
  static String? currentUserEmail(BuildContext context) {
    return context.select<AuthProvider, String?>(
      (auth) => auth.currentUser?.email,
    );
  }

  /// Selector for cached user role only
  static UserRole? cachedUserRole(BuildContext context) {
    return context.select<AuthProvider, UserRole?>(
      (auth) => auth.cachedUserRole,
    );
  }

  /// Selector for role cache validity
  static bool hasValidRoleCache(BuildContext context) {
    return context.select<AuthProvider, bool>((auth) => auth.hasValidRoleCache);
  }

  /// Combined selector for auth state (authentication + loading)
  static AuthState authState(BuildContext context) {
    return context.select<AuthProvider, AuthState>(
      (auth) => AuthState(
        isAuthenticated: auth.isAuthenticated,
        isLoading: auth.isLoading,
      ),
    );
  }

  /// Combined selector for error state (hasError + errorMessage)
  static ErrorState errorState(BuildContext context) {
    return context.select<AuthProvider, ErrorState>(
      (auth) => ErrorState(
        hasError: auth.hasError,
        errorMessage: auth.errorMessage,
        errorType: auth.errorType,
      ),
    );
  }

  /// Combined selector for user info (id + email + role)
  static UserInfo? userInfo(BuildContext context) {
    return context.select<AuthProvider, UserInfo?>((auth) {
      final user = auth.currentUser;
      if (user == null) return null;

      return UserInfo(
        uid: user.uid,
        email: user.email,
        displayName: user.displayName,
        photoURL: user.photoURL,
        role: auth.cachedUserRole,
      );
    });
  }
}

/// Data classes for combined selectors
class AuthState {
  final bool isAuthenticated;
  final bool isLoading;

  const AuthState({required this.isAuthenticated, required this.isLoading});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthState &&
          runtimeType == other.runtimeType &&
          isAuthenticated == other.isAuthenticated &&
          isLoading == other.isLoading;

  @override
  int get hashCode => isAuthenticated.hashCode ^ isLoading.hashCode;
}

class ErrorState {
  final bool hasError;
  final String? errorMessage;
  final dynamic errorType;

  const ErrorState({required this.hasError, this.errorMessage, this.errorType});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ErrorState &&
          runtimeType == other.runtimeType &&
          hasError == other.hasError &&
          errorMessage == other.errorMessage &&
          errorType == other.errorType;

  @override
  int get hashCode =>
      hasError.hashCode ^ errorMessage.hashCode ^ errorType.hashCode;
}

class UserInfo {
  final String uid;
  final String? email;
  final String? displayName;
  final String? photoURL;
  final UserRole? role;

  const UserInfo({
    required this.uid,
    this.email,
    this.displayName,
    this.photoURL,
    this.role,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserInfo &&
          runtimeType == other.runtimeType &&
          uid == other.uid &&
          email == other.email &&
          displayName == other.displayName &&
          photoURL == other.photoURL &&
          role == other.role;

  @override
  int get hashCode =>
      uid.hashCode ^
      email.hashCode ^
      displayName.hashCode ^
      photoURL.hashCode ^
      role.hashCode;
}

/// Extension methods for easier access to selectors
extension AuthSelectorExtensions on BuildContext {
  /// Quick access to authentication status
  bool get isAuthenticated => AuthSelectors.isAuthenticated(this);

  /// Quick access to loading state
  bool get isAuthLoading => AuthSelectors.isLoading(this);

  /// Quick access to error state
  bool get hasAuthError => AuthSelectors.hasError(this);

  /// Quick access to error message
  String? get authErrorMessage => AuthSelectors.errorMessage(this);

  /// Quick access to current user ID
  String? get currentUserId => AuthSelectors.currentUserId(this);

  /// Quick access to current user email
  String? get currentUserEmail => AuthSelectors.currentUserEmail(this);

  /// Quick access to cached user role
  UserRole? get cachedUserRole => AuthSelectors.cachedUserRole(this);

  /// Quick access to auth state
  AuthState get authState => AuthSelectors.authState(this);

  /// Quick access to error state
  ErrorState get errorState => AuthSelectors.errorState(this);

  /// Quick access to user info
  UserInfo? get userInfo => AuthSelectors.userInfo(this);
}
