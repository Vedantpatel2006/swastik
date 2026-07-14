import 'package:flutter/material.dart';
import 'package:swastik/core/themes/app_colors.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/auth_provider_selectors.dart';
import '../../../shared/models/user_role.dart';
import '../../../shared/widgets/auth/optimized_auth_widgets.dart';
import '../screens/auth_intro.dart';
import '../../../shared/screens/user_home_screen.dart';
import '../../admin/screens/admin_home_screen.dart';
import '../../../shared/widgets/error/index.dart';
import '../../../shared/services/navigation/navigation_guard.dart';
import '../../temple/services/hybrid_live_detector.dart';

/// Enhanced AuthWrapper with proper role-based routing and session management
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  UserRole? _cachedUserRole;
  String? _cachedUserId;
  bool _isInitializing = true;

  @override
  void initState() {
    super.initState();
    _initializeAuth();
  }

  Future<void> _initializeAuth() async {
    try {
      final authProvider = context.read<AuthProvider>();

      // Wait for auth state to be determined
      await Future.delayed(const Duration(milliseconds: 100));

      // Guard: widget may have been disposed during the delay
      if (!mounted) return;

      if (authProvider.isAuthenticated) {
        await _loadUserRole(authProvider);

        // Guard again after the Firestore role fetch
        if (!mounted) return;

        // Initialize live detection after authentication
        _initializeLiveDetectionAfterAuth();
      }
    } catch (e) {
      debugPrint('Auth initialization error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
      }
    }
  }

  /// Initialize live detection system after user authentication
  void _initializeLiveDetectionAfterAuth() {
    Future.delayed(const Duration(seconds: 2), () async {
      // Widget may have been disposed during the 2-second delay
      if (!mounted) return;
      try {
        final hybridDetector = HybridLiveDetector();
        await _startHybridMonitoring(hybridDetector);
        debugPrint('🧠 Hybrid smart live detection started (post-auth)');
      } catch (e) {
        debugPrint('❌ Failed to initialize hybrid live detection: $e');
      }
    });
  }

  /// Start hybrid monitoring for authenticated users.
  /// Reads channel config directly from Firestore.
  Future<void> _startHybridMonitoring(HybridLiveDetector detector) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('temples')
          .where('liveDarshan.isConfiguredByAdmin', isEqualTo: true)
          .get();

      if (!mounted) return;

      debugPrint(
        '🔍 Found ${snapshot.docs.length} temples with live darshan configured (Firestore)',
      );

      for (final doc in snapshot.docs) {
        if (!mounted) return;
        final data = doc.data();
        final liveDarshan = data['liveDarshan'] as Map<String, dynamic>?;
        final channelId =
            liveDarshan?['youtubeChannelId'] as String? ?? '';
        if (channelId.isEmpty) {
          debugPrint('! No channelId for temple ${doc.id} — skipping');
          continue;
        }
        detector.startSmartMonitoring(doc.id, channelId);
        debugPrint('🎯 Started smart monitoring for temple: ${doc.id}');
      }
    } catch (e) {
      debugPrint('❌ Error starting hybrid monitoring: $e');
    }
  }

  Future<void> _loadUserRole(AuthProvider authProvider) async {
    try {
      final currentUserId = authProvider.currentUser?.uid;

      // Only reload role if user changed or role not cached
      if (_cachedUserId != currentUserId || _cachedUserRole == null) {
        // Use getUserRole() directly — preserves the full cached role object
        // and avoids a redundant Firestore read compared to calling isAdmin.
        // getUserRole() also populates authProvider.cachedUserRole via its
        // internal batch, but that fires after a 100ms window. We store the
        // result locally here so _buildAuthenticatedApp never receives null.
        final role = await authProvider.getUserRole();
        _cachedUserRole = role;
        _cachedUserId = currentUserId;
      } else {
        // Already cached locally — keep in sync with provider
        _cachedUserRole = authProvider.cachedUserRole ?? _cachedUserRole;
      }
    } catch (e) {
      debugPrint('Error loading user role: $e');
      // Default to user role on error — never leave _cachedUserRole null
      _cachedUserRole ??= UserRole.user;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show loading during initialization
    if (_isInitializing) {
      return const _LoadingScreen();
    }

    // Use optimized auth state wrapper for efficient rebuilds
    return OptimizedAuthStateWrapper(
      loadingWidget: const _LoadingScreen(),
      builder: (context, isAuthenticated) {
        // Handle authentication errors using optimized error display
        final errorState = AuthSelectors.errorState(context);
        if (errorState.hasError) {
          return _AuthErrorScreen(
            error: errorState.errorMessage ?? 'Authentication error',
            onRetry: () async {
              context.read<AuthProvider>().clearError();
              await _initializeAuth();
            },
          );
        }

        // Not authenticated - show auth intro
        if (!isAuthenticated) {
          _clearCache();
          return const AuthIntroScreen();
        }

        // Use optimized role-based widget for authenticated users
        return OptimizedRoleBasedWidget(
          loadingWidget: const _LoadingScreen(),
          builder: (context, role) {
            _cachedUserRole = role;
            return _buildAuthenticatedApp();
          },
        );
      },
    );
  }

  Widget _buildAuthenticatedApp() {
    // _cachedUserRole is always set before this is called (defaulting to
    // UserRole.user on error), but guard defensively to avoid a null crash.
    final role = _cachedUserRole ?? UserRole.user;
    return NavigationGuard(
      userRole: role,
      child: role.isAdmin
          ? const AdminHomeScreen()
          : const MainNavigationScreen(),
    );
  }

  void _clearCache() {
    _cachedUserRole = null;
    _cachedUserId = null;
  }
}

/// Loading screen shown during authentication initialization
class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F0),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primaryOrange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(40),
              ),
              child: const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryOrange),
                  strokeWidth: 3,
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Initializing...',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Color(0xFF6B7280),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Error screen shown when authentication fails
class _AuthErrorScreen extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const _AuthErrorScreen({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F0),
      body: SafeArea(
        child: FallbackUI(
          title: 'Authentication Error',
          message: error,
          type: FallbackUIType.error,
          onRetry: onRetry,
        ),
      ),
    );
  }
}
