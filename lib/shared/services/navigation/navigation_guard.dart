import 'package:flutter/material.dart';
import '../../models/user_role.dart';
import '../../widgets/error/index.dart';

/// Navigation guard that prevents unauthorized access to admin functionality
class NavigationGuard extends StatelessWidget {
  final UserRole userRole;
  final Widget child;
  final String? routeName;

  const NavigationGuard({
    super.key,
    required this.userRole,
    required this.child,
    this.routeName,
  });

  /// Check if a route requires admin access
  static bool requiresAdminAccess(String? routeName) {
    if (routeName == null) return false;
    const adminRoutes = {
      '/admin_home',
      '/add_temple',
      '/edit_temple',
      '/admin_settings',
      '/temple_management',
      '/user_management',
    };
    return adminRoutes.contains(routeName) || routeName.startsWith('/admin');
  }

  /// Check if a route requires user access (authenticated users only)
  static bool requiresUserAccess(String? routeName) {
    if (routeName == null) return false;
    const userOnlyRoutes = {
      '/home',
      '/temple_discovery',
      '/favorites',
      '/user_profile',
      '/preferences',
      '/live_darshan',
      '/booking',
      '/donation',
      '/events',
      '/community',
      '/notifications',
    };
    return userOnlyRoutes.contains(routeName);
  }

  /// Check if map access is allowed for the given role and context
  static bool canAccessMap(UserRole userRole, String context) {
    if (userRole != UserRole.admin) return false;
    const allowedMapContexts = {
      'add_temple',
      'edit_temple',
      'temple_submission',
    };
    return allowedMapContexts.contains(context);
  }

  /// Show permission denied dialog for map access
  static void showMapPermissionDenied(
    BuildContext context,
    String attemptedAction,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            Icon(Icons.block, color: Colors.red[600], size: 24),
            const SizedBox(width: 8),
            const Text('Permission Denied'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Map functionality is restricted to temple submission workflows only.',
              style: TextStyle(color: Colors.grey[700]),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'To access map features:',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.orange[800],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '• Go to "Add Temple" screen\n'
                    '• Use location picker during temple creation',
                    style: TextStyle(color: Colors.orange[700]),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Understood'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentRoute = routeName ?? ModalRoute.of(context)?.settings.name;

    // Block admin routes for non-admin users
    if (requiresAdminAccess(currentRoute) && userRole != UserRole.admin) {
      return _UnauthorizedScreen(
        attemptedRoute: currentRoute ?? '',
        userRole: userRole,
      );
    }

    return child;
  }
}

/// Screen shown when user tries to access unauthorized content
class _UnauthorizedScreen extends StatelessWidget {
  final String attemptedRoute;
  final UserRole userRole;

  const _UnauthorizedScreen({
    required this.attemptedRoute,
    required this.userRole,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F0),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF333333)),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: FallbackUI(
          title: 'Access Denied',
          message:
              'You don\'t have permission to access this feature. '
              'This area is restricted to ${NavigationGuard.requiresAdminAccess(attemptedRoute) ? 'admin' : 'authorized'} users only.',
          type: FallbackUIType.error,
          onRetry: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }
}



