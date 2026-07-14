import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../shared/widgets/error/index.dart';
import '../shared/models/user_role.dart';
import '../features/auth/services/auth_error_handler.dart';
import '../shared/mixins/advanced_state_optimization_mixin.dart';
import '../shared/services/state_management/state_optimization_service.dart';
import '../shared/services/contact_support_service.dart';
import '../core/services/error_logger.dart';
import '../shared/services/fcm_service.dart';
import '../main.dart' show initializeNotificationServicesForUser;

/// Optimized AuthProvider with efficient state management and selective rebuilds
class AuthProvider extends AdvancedOptimizedChangeNotifier {
  static const String _widgetId = 'AuthProvider';

  // Enhanced state optimization service integration
  final StateOptimizationService _stateOptimization =
      StateOptimizationService();

  @override
  void dispose() {
    // Cancel all pending state optimization operations
    _stateOptimization.cancel(_widgetId);

    super.dispose();
  }

  // Lazy initialization of Firebase services
  FirebaseAuth? _auth;
  FirebaseFirestore? _firestore;

  FirebaseAuth get _authInstance {
    _auth ??= FirebaseAuth.instance;
    return _auth!;
  }

  FirebaseFirestore get _firestoreInstance {
    _firestore ??= FirebaseFirestore.instance;
    return _firestore!;
  }

  final GoogleSignIn _googleSignIn = GoogleSignIn();

  User? get currentUser => _authInstance.currentUser;
  bool get isAuthenticated => currentUser != null;

  Stream<User?> get authStateChanges => _authInstance.authStateChanges();

  // Session management
  UserRole? _cachedUserRole;
  String? _cachedUserId;
  DateTime? _roleLastFetched;
  static const Duration _roleCacheDuration = Duration(minutes: 5);

  UserRole? get cachedUserRole => _cachedUserRole;
  bool get hasValidRoleCache =>
      _cachedUserRole != null &&
      _cachedUserId == currentUser?.uid &&
      _roleLastFetched != null &&
      DateTime.now().difference(_roleLastFetched!) < _roleCacheDuration;

  // Animation states for error handling
  bool _isLoading = false;
  String? _errorMessage;
  bool _hasError = false;
  final bool _isRetrying = false;
  ErrorDisplayType _errorType = ErrorDisplayType.error;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasError => _hasError;
  bool get isRetrying => _isRetrying;
  ErrorDisplayType get errorType => _errorType;

  void _setLoading(bool loading) {
    if (_isLoading == loading) return; // Prevent unnecessary updates

    // Use StateOptimizationService for debounced loading state updates
    _stateOptimization.debounce('${_widgetId}_loading', () {
      _isLoading = loading;
      markPropertyChanged('isLoading');
      notifyListenersThrottled(); // Use throttled notifications for loading state
    }, delay: const Duration(milliseconds: 100));
  }

  void _setError(
    String? error, [
    ErrorDisplayType type = ErrorDisplayType.error,
  ]) {
    if (_errorMessage == error && _errorType == type) {
      return; // Prevent unnecessary updates
    }

    // Use StateOptimizationService for batched error state changes
    _stateOptimization.batch('${_widgetId}_error', () {
      startBatch();
      _errorMessage = error;
      _hasError = error != null;
      _errorType = type;
      markPropertyChanged('errorMessage');
      markPropertyChanged('hasError');
      markPropertyChanged('errorType');
      executeBatch();
    }, batchWindow: const Duration(milliseconds: 50));
  }

  void clearError() {
    if (!_hasError) {
      return; // Already cleared
    }

    // Use StateOptimizationService for debounced error clearing
    _stateOptimization.debounce('${_widgetId}_clear_error', () {
      startBatch();
      _errorMessage = null;
      _hasError = false;
      _errorType = ErrorDisplayType.error;
      markPropertyChanged('errorMessage');
      markPropertyChanged('hasError');
      markPropertyChanged('errorType');
      executeBatch();
    }, delay: const Duration(milliseconds: 200));
  }

  /// Show animated error dialog with retry functionality and role context
  Future<void> showErrorDialog(
    BuildContext context, {
    VoidCallback? onRetry,
    String? errorContext,
  }) async {
    if (!_hasError || _errorMessage == null) return;

    await AuthErrorHandler.showAuthErrorDialog(
      context,
      error: _errorMessage!,
      userRole: _cachedUserRole,
      errorContext: errorContext,
      onRetry: onRetry,
      onContactSupport: () async {
        // Open support contact options
        await ContactSupportService.showSupportOptions(context);
      },
    );

    clearError();
  }

  Future<bool> get isAdmin async {
    final role = await getUserRole();
    return role.isAdmin;
  }

  /// Get user role with caching for better performance
  Future<UserRole> getUserRole() async {
    if (!isAuthenticated) return UserRole.user;

    // Return cached role if valid
    if (hasValidRoleCache) {
      return _cachedUserRole!;
    }

    try {
      final doc = await _firestoreInstance
          .collection('users')
          .doc(currentUser!.uid)
          .get();

      final roleString = doc.data()?['role'] as String? ?? 'user';
      final role = UserRole.fromString(roleString);

      // Cache the role with optimized batched notification
      _stateOptimization.batch('${_widgetId}_role_cache', () {
        startBatch();
        _cachedUserRole = role;
        _cachedUserId = currentUser!.uid;
        _roleLastFetched = DateTime.now();
        markPropertyChanged('cachedUserRole');
        markPropertyChanged('hasValidRoleCache');
        executeBatch();
      }, batchWindow: const Duration(milliseconds: 100));

      return role;
    } catch (e) {
      debugPrint('Error fetching user role: $e');
      // Return user role as fallback, but don't cache the error
      return UserRole.user;
    }
  }

  /// Clear role cache (useful when user signs out or role changes)
  void clearRoleCache() {
    if (_cachedUserRole == null && _cachedUserId == null) {
      return; // Already cleared
    }

    // Use StateOptimizationService for throttled role cache clearing
    _stateOptimization.throttle('${_widgetId}_clear_cache', () {
      startBatch();
      _cachedUserRole = null;
      _cachedUserId = null;
      _roleLastFetched = null;
      markPropertyChanged('cachedUserRole');
      markPropertyChanged('hasValidRoleCache');
      executeBatch();
    }, interval: const Duration(milliseconds: 300));
  }

  /// Check if current user can access admin features
  Future<bool> canAccessAdminFeatures() async {
    final role = await getUserRole();
    return role.isAdmin;
  }

  /// Check if current user can access user features
  Future<bool> canAccessUserFeatures() async {
    final role = await getUserRole();
    return role.isUser;
  }

  // 🔐 Email/password sign-up with email verification
  Future<void> signUpWithEmailAndPassword(
    String email,
    String password, {
    String? displayName,
    bool sendVerificationEmail = true,
  }) async {
    // Use immediate loading state for faster UI feedback
    _isLoading = true;
    _errorMessage = null;
    _hasError = false;
    markPropertyChanged('isLoading');
    markPropertyChanged('errorMessage');
    markPropertyChanged('hasError');
    notifyListeners();

    try {
      final credential = await _authInstance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Update display name if provided
      if (displayName != null && displayName.isNotEmpty) {
        await credential.user!.updateDisplayName(displayName);
      }

      // Send email verification
      if (sendVerificationEmail && !credential.user!.emailVerified) {
        await credential.user!.sendEmailVerification();
      }

      await _firestoreInstance
          .collection('users')
          .doc(credential.user!.uid)
          .set({
            'uid': credential.user!.uid,
            'email': credential.user!.email,
            'displayName': displayName ?? '',
            'createdAt': FieldValue.serverTimestamp(),
            'emailVerified': credential.user!.emailVerified,
            'provider': 'email',
            'role': UserRole.user.value,
          });

      // Cache the role for new user
      _cachedUserRole = UserRole.user;
      _cachedUserId = credential.user!.uid;
      _roleLastFetched = DateTime.now();

      // Initialize notification services for the newly registered user
      unawaited(initializeNotificationServicesForUser(credential.user!.uid));

      // Sign out immediately — user must verify email before accessing the app.
      // AuthWrapper would otherwise route an unverified user straight to HomeScreen.
      await _authInstance.signOut();
      _cachedUserRole = null;
      _cachedUserId = null;
      _roleLastFetched = null;

      // Immediate loading state update
      _isLoading = false;
      markPropertyChanged('isLoading');
      notifyListeners();
    } on FirebaseAuthException catch (e, stackTrace) {
      ErrorLogger.log(
        'AuthProvider.signUpWithEmailAndPassword',
        e,
        stackTrace: stackTrace,
        metadata: {'email': email},
      );

      _isLoading = false;
      final errorMessage = AuthErrorHandler.handleAuthError(e);
      final errorType = _getErrorTypeFromException(e);

      // Immediate error state update
      _errorMessage = errorMessage;
      _hasError = true;
      _errorType = errorType;
      markPropertyChanged('isLoading');
      markPropertyChanged('errorMessage');
      markPropertyChanged('hasError');
      markPropertyChanged('errorType');
      notifyListeners();

      throw errorMessage;
    } catch (e, stackTrace) {
      ErrorLogger.log(
        'AuthProvider.signUpWithEmailAndPassword',
        e,
        stackTrace: stackTrace,
        metadata: {'email': email},
      );

      _isLoading = false;
      final errorMessage = 'An unexpected error occurred: ${e.toString()}';

      // Immediate error state update
      _errorMessage = errorMessage;
      _hasError = true;
      _errorType = ErrorDisplayType.error;
      markPropertyChanged('isLoading');
      markPropertyChanged('errorMessage');
      markPropertyChanged('hasError');
      markPropertyChanged('errorType');
      notifyListeners();

      throw errorMessage;
    }
  }

  // 📧 Send email verification
  Future<void> sendEmailVerification() async {
    if (currentUser == null) {
      throw 'No user is currently signed in';
    }

    if (currentUser!.emailVerified) {
      throw 'Email is already verified';
    }

    _setLoading(true);
    _setError(null);

    try {
      await currentUser!.sendEmailVerification();
      _setLoading(false);
    } on FirebaseAuthException catch (e) {
      _setLoading(false);
      final errorMessage = AuthErrorHandler.handleAuthError(e);
      final errorType = _getErrorTypeFromException(e);
      _setError(errorMessage, errorType);
      throw errorMessage;
    } catch (e) {
      _setLoading(false);
      final errorMessage = 'Failed to send verification email: ${e.toString()}';
      _setError(errorMessage, ErrorDisplayType.error);
      throw errorMessage;
    }
  }

  // 🔄 Reload user to check email verification status
  Future<void> reloadUser() async {
    if (currentUser == null) return;

    try {
      await currentUser!.reload();
      // Update Firestore if email verification status changed
      if (currentUser!.emailVerified) {
        await _firestoreInstance
            .collection('users')
            .doc(currentUser!.uid)
            .update({
              'emailVerified': true,
              'emailVerifiedAt': FieldValue.serverTimestamp(),
            });
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error reloading user: $e');
    }
  }

  // ✅ Check if email is verified
  bool get isEmailVerified => currentUser?.emailVerified ?? false;

  // 📧 Resend verification email for a specific email/password
  Future<void> resendVerificationForEmail(String email, String password) async {
    _setLoading(true);
    _setError(null);

    try {
      // Sign in temporarily to send verification
      final credential = await _authInstance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user!.emailVerified) {
        // Sign out before throwing so we don't leave a verified user signed in
        await _authInstance.signOut();
        _setLoading(false);
        throw 'Email is already verified. Please try logging in again.';
      }

      try {
        await credential.user!.sendEmailVerification();
      } finally {
        // Always sign out after the temporary sign-in, success or failure
        await _authInstance.signOut();
      }

      _setLoading(false);
    } on FirebaseAuthException catch (e) {
      _setLoading(false);
      final errorMessage = AuthErrorHandler.handleAuthError(e);
      final errorType = _getErrorTypeFromException(e);
      _setError(errorMessage, errorType);
      throw errorMessage;
    } catch (e) {
      _setLoading(false);
      if (e.toString().contains('already verified')) {
        throw e.toString();
      }
      final errorMessage =
          'Failed to resend verification email: ${e.toString()}';
      _setError(errorMessage, ErrorDisplayType.error);
      throw errorMessage;
    }
  }

  // 🔐 Email/password sign-in with email verification enforcement
  Future<void> signInWithEmailAndPassword(String email, String password) async {
    // Use immediate loading state for faster UI feedback
    _isLoading = true;
    _errorMessage = null;
    _hasError = false;
    markPropertyChanged('isLoading');
    markPropertyChanged('errorMessage');
    markPropertyChanged('hasError');
    notifyListeners();

    try {
      final credential = await _authInstance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // SECURITY FIX: Enforce email verification for ALL users
      if (!credential.user!.emailVerified) {
        _isLoading = false;
        markPropertyChanged('isLoading');
        notifyListeners();

        // Sign out the user
        await _authInstance.signOut();

        throw 'Please verify your email address before signing in. Check your inbox for the verification link.';
      }

      // SECURITY FIX: Get user role from Firestore (server-side managed)
      UserRole role = UserRole.user;
      try {
        final userDoc = await _firestoreInstance
            .collection('users')
            .doc(credential.user!.uid)
            .get();

        if (userDoc.exists) {
          final userData = userDoc.data() ?? {};
          final roleString = userData['role'] as String? ?? 'user';
          role = UserRole.fromString(roleString);
        }
      } catch (e) {
        // Default to user role if role fetch fails
        debugPrint(
          'Warning: Could not fetch user role, defaulting to user: $e',
        );
        role = UserRole.user;
      }

      final userDoc = _firestoreInstance
          .collection('users')
          .doc(credential.user!.uid);

      // Optimize: Use set with merge instead of get + update/set
      await userDoc.set({
        'uid': credential.user!.uid,
        'email': credential.user!.email,
        'role': role.value,
        'lastSignIn': FieldValue.serverTimestamp(),
        'emailVerified': credential.user!.emailVerified,
        'provider': 'email',
      }, SetOptions(merge: true));

      // Cache the role immediately after successful login
      _cachedUserRole = role;
      _cachedUserId = credential.user!.uid;
      _roleLastFetched = DateTime.now();

      // Initialize notification services now that we have a signed-in user
      unawaited(initializeNotificationServicesForUser(credential.user!.uid));

      // Immediate loading state update
      _isLoading = false;
      markPropertyChanged('isLoading');
      notifyListeners();
    } on FirebaseAuthException catch (e, stackTrace) {
      ErrorLogger.log(
        'AuthProvider.signInWithEmailAndPassword',
        e,
        stackTrace: stackTrace,
        metadata: {'email': email},
      );

      _isLoading = false;
      final errorMessage = AuthErrorHandler.handleAuthError(e);
      final errorType = _getErrorTypeFromException(e);

      // Immediate error state update
      _errorMessage = errorMessage;
      _hasError = true;
      _errorType = errorType;
      markPropertyChanged('isLoading');
      markPropertyChanged('errorMessage');
      markPropertyChanged('hasError');
      markPropertyChanged('errorType');
      notifyListeners();

      // Check if error requires sign out for security
      if (AuthErrorHandler.requiresSignOut(e)) {
        await signOut();
      }

      throw errorMessage;
    } catch (e, stackTrace) {
      ErrorLogger.log(
        'AuthProvider.signInWithEmailAndPassword',
        e,
        stackTrace: stackTrace,
        metadata: {'email': email},
      );

      _isLoading = false;
      final errorMessage = 'An unexpected error occurred: ${e.toString()}';

      // Immediate error state update
      _errorMessage = errorMessage;
      _hasError = true;
      _errorType = ErrorDisplayType.error;
      markPropertyChanged('isLoading');
      markPropertyChanged('errorMessage');
      markPropertyChanged('hasError');
      markPropertyChanged('errorType');
      notifyListeners();

      throw errorMessage;
    }
  }

  // 🔁 Reset password
  Future<void> resetPassword(String email) async {
    _setLoading(true);
    _setError(null);

    try {
      await _authInstance.sendPasswordResetEmail(email: email);
      _setLoading(false);
    } on FirebaseAuthException catch (e) {
      _setLoading(false);
      final errorMessage = AuthErrorHandler.handleAuthError(e);
      final errorType = _getErrorTypeFromException(e);
      _setError(errorMessage, errorType);
      throw errorMessage;
    } catch (e) {
      _setLoading(false);
      final errorMessage = 'Failed to send reset email: ${e.toString()}';
      _setError(errorMessage, ErrorDisplayType.error);
      throw errorMessage;
    }
  }

  // 🔐 Google Sign-In
  Future<void> signInWithGoogle() async {
    // Use immediate loading state for faster UI feedback
    _isLoading = true;
    _errorMessage = null;
    _hasError = false;
    markPropertyChanged('isLoading');
    markPropertyChanged('errorMessage');
    markPropertyChanged('hasError');
    notifyListeners();

    try {
      // Trigger the authentication flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        // User cancelled the sign-in
        _isLoading = false;
        markPropertyChanged('isLoading');
        notifyListeners();
        return;
      }

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the Google credential
      final userCredential = await _authInstance.signInWithCredential(
        credential,
      );
      final user = userCredential.user!;

      // Optimize: Use set with merge to reduce Firestore operations
      final userDoc = _firestoreInstance.collection('users').doc(user.uid);

      // Get existing role if any (single read operation)
      final doc = await userDoc.get();
      final existingRole = doc.exists
          ? UserRole.fromString(doc.data()?['role'] as String? ?? 'user')
          : UserRole.user;

      // SECURITY FIX: Only create user document if it doesn't exist
      // Don't overwrite existing role assignments
      if (!doc.exists) {
        await userDoc.set({
          'uid': user.uid,
          'email': user.email,
          'displayName': user.displayName,
          'photoURL': user.photoURL,
          'createdAt': FieldValue.serverTimestamp(),
          'emailVerified': user.emailVerified,
          'provider': 'google',
          'role': UserRole.user.value, // Default to user role
        });
      } else {
        // Update last sign-in without changing role
        await userDoc.update({
          'lastSignIn': FieldValue.serverTimestamp(),
          'emailVerified': user.emailVerified,
        });
      }

      // Cache the role
      _cachedUserRole = existingRole;
      _cachedUserId = user.uid;
      _roleLastFetched = DateTime.now();

      // Initialize notification services now that we have a signed-in user
      unawaited(initializeNotificationServicesForUser(user.uid));

      // Immediate loading state update
      _isLoading = false;
      markPropertyChanged('isLoading');
      notifyListeners();
    } on FirebaseAuthException catch (e, stackTrace) {
      ErrorLogger.log(
        'AuthProvider.signInWithGoogle',
        e,
        stackTrace: stackTrace,
      );

      _isLoading = false;
      final errorMessage = AuthErrorHandler.handleAuthError(e);
      final errorType = _getErrorTypeFromException(e);

      // Immediate error state update
      _errorMessage = errorMessage;
      _hasError = true;
      _errorType = errorType;
      markPropertyChanged('isLoading');
      markPropertyChanged('errorMessage');
      markPropertyChanged('hasError');
      markPropertyChanged('errorType');
      notifyListeners();

      throw errorMessage;
    } catch (e, stackTrace) {
      ErrorLogger.log(
        'AuthProvider.signInWithGoogle',
        e,
        stackTrace: stackTrace,
      );

      _isLoading = false;
      final errorMessage = 'Google sign-in failed: ${e.toString()}';

      // Immediate error state update
      _errorMessage = errorMessage;
      _hasError = true;
      _errorType = ErrorDisplayType.error;
      markPropertyChanged('isLoading');
      markPropertyChanged('errorMessage');
      markPropertyChanged('hasError');
      markPropertyChanged('errorType');
      notifyListeners();

      throw errorMessage;
    }
  }

  // 🔒 Logout
  Future<void> signOut() async {
    // Use immediate state updates for sign out (no debouncing)
    _isLoading = true;
    _errorMessage = null;
    _hasError = false;
    markPropertyChanged('isLoading');
    markPropertyChanged('errorMessage');
    markPropertyChanged('hasError');
    notifyListeners();

    try {
      // Sign out from Google if signed in with Google
      if (await _googleSignIn.isSignedIn()) {
        await _googleSignIn.signOut();
      }

      await _authInstance.signOut();

      // Clear FCM user ID so token refreshes are no longer persisted.
      FCMService().setCurrentUserId(null);

      // Clear cached role data immediately (no throttling)
      _cachedUserRole = null;
      _cachedUserId = null;
      _roleLastFetched = null;
      markPropertyChanged('cachedUserRole');
      markPropertyChanged('hasValidRoleCache');

      _isLoading = false;
      markPropertyChanged('isLoading');
      notifyListeners();
    } catch (e, stackTrace) {
      ErrorLogger.log('AuthProvider.signOut', e, stackTrace: stackTrace);

      _isLoading = false;
      final errorMessage = 'Sign out failed: ${e.toString()}';
      _errorMessage = errorMessage;
      _hasError = true;
      _errorType = ErrorDisplayType.error;
      markPropertyChanged('isLoading');
      markPropertyChanged('errorMessage');
      markPropertyChanged('hasError');
      markPropertyChanged('errorType');
      notifyListeners();

      // Clear cache even if sign out fails for security (immediate)
      _cachedUserRole = null;
      _cachedUserId = null;
      _roleLastFetched = null;
      markPropertyChanged('cachedUserRole');
      markPropertyChanged('hasValidRoleCache');
      notifyListeners();

      throw errorMessage;
    }
  }

  /// Get error type based on Firebase Auth exception
  ErrorDisplayType _getErrorTypeFromException(FirebaseAuthException e) {
    switch (e.code) {
      case 'network-request-failed':
      case 'too-many-requests':
        return ErrorDisplayType.network;
      case 'weak-password':
      case 'invalid-email':
        return ErrorDisplayType.warning;
      default:
        return ErrorDisplayType.error;
    }
  }
}
