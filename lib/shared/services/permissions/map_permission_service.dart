import 'package:flutter/material.dart';
import '../security_logger.dart';
import '../../models/user_role.dart';

/// Service to handle map access permissions and security logging.
///
/// NOTE: The interactive map picker (SelectLocationMapScreen) is only
/// reachable from admin-only screens (AddTempleScreen / EditTempleScreen),
/// so role-based access is already enforced at the navigation level.
/// This service provides an additional explicit check and audit log for
/// any future use cases where the map might be exposed more broadly.
class MapPermissionService {
  static final MapPermissionService _instance =
      MapPermissionService._internal();
  factory MapPermissionService() => _instance;
  MapPermissionService._internal();

  /// Check if user can access map functionality in the given context.
  /// Admins can access the map in any allowed context.
  /// Regular users can access the map only in read-only view contexts.
  bool canAccessMap(UserRole userRole, String context) {
    const adminContexts = {
      'add_temple',
      'edit_temple',
      'temple_submission',
    };

    const readOnlyContexts = {'temple_detail', 'directions'};

    if (userRole == UserRole.admin) {
      return adminContexts.contains(context) ||
          readOnlyContexts.contains(context);
    }

    // Regular users can view maps in read-only contexts
    return readOnlyContexts.contains(context);
  }

  /// Attempt to access map functionality with permission checking
  Future<bool> attemptMapAccess({
    required BuildContext context,
    required UserRole userRole,
    required String accessContext,
    required String attemptedAction,
    VoidCallback? onSuccess,
    VoidCallback? onDenied,
  }) async {
    if (canAccessMap(userRole, accessContext)) {
      await _logMapAccess(userRole, accessContext, attemptedAction, true);
      onSuccess?.call();
      return true;
    } else {
      await _logMapAccess(userRole, accessContext, attemptedAction, false);
      _showMapPermissionDenied(context, attemptedAction);
      onDenied?.call();
      return false;
    }
  }

  /// Log map access attempts for security monitoring
  Future<void> _logMapAccess(
    UserRole userRole,
    String context,
    String action,
    bool granted,
  ) async {
    final timestamp = DateTime.now().toIso8601String();
    final logEntry = {
      'timestamp': timestamp,
      'userRole': userRole.toString(),
      'context': context,
      'action': action,
      'granted': granted,
      'type': 'map_access_attempt',
    };

    // In a production app, this would be sent to a logging service
    debugPrint('MAP_ACCESS_LOG: $logEntry');

    // Log to security monitoring system
    await SecurityLogger.logAccess(
      resource: 'map_permissions',
      action: action,
      granted: granted,
      reason: granted ? 'Permission granted' : 'Permission denied',
      metadata: logEntry,
    );
  }

  /// Get allowed contexts for map access
  List<String> getAllowedMapContexts() {
    return ['add_temple', 'edit_temple', 'temple_submission'];
  }

  /// Check if current screen context allows map access
  bool isMapAllowedInCurrentContext(String? routeName) {
    if (routeName == null) return false;

    final allowedRoutes = {'/add_temple', '/edit_temple'};

    return allowedRoutes.contains(routeName);
  }

  /// Show permission denied dialog for map access
  void _showMapPermissionDenied(BuildContext context, String attemptedAction) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
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
                    '• Go to "Add Temple" screen\n• Use location picker during temple creation',
                    style: TextStyle(color: Colors.orange[700]),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Understood'),
          ),
        ],
      ),
    );
  }
}
