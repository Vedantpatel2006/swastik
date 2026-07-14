import 'package:flutter/material.dart';
import '../../../core/themes/app_colors.dart';
import '../../../shared/services/supabase_notification_service.dart';
import '../../../shared/models/notification.dart';
import '../../../shared/widgets/loading/skeleton_loader.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Screen to display user notifications with real-time updates
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final SupabaseNotificationService _notificationService =
      SupabaseNotificationService();
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
  }

  Future<void> _initializeNotifications() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _currentUserId = user.uid;
      await _notificationService.initialize(userId: _currentUserId!);
      if (mounted) {
        setState(() {});
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('NotificationsScreen: Building notifications screen');
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: AppColors.primaryOrange,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.pushNamed(context, '/notification_preferences');
            },
            tooltip: 'Notification Settings',
          ),
          if (_currentUserId != null)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (value) async {
                switch (value) {
                  case 'mark_all_read':
                    await _notificationService.markAllAsRead(_currentUserId!);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('All notifications marked as read'),
                          backgroundColor: AppColors.successGreen,
                        ),
                      );
                    }
                    break;
                  case 'clear_all':
                    final shouldClear = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Clear All Notifications'),
                        content: const Text(
                          'Are you sure you want to delete all notifications? This action cannot be undone.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.red,
                            ),
                            child: const Text('Clear All'),
                          ),
                        ],
                      ),
                    );

                    if (shouldClear == true && mounted) {
                      await _notificationService.clearAllNotifications(
                        _currentUserId!,
                      );
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('All notifications cleared'),
                            backgroundColor: AppColors.primaryOrange,
                          ),
                        );
                      }
                    }
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'mark_all_read',
                  child: Row(
                    children: [
                      Icon(Icons.mark_email_read, size: 20),
                      SizedBox(width: 8),
                      Text('Mark All as Read'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'clear_all',
                  child: Row(
                    children: [
                      Icon(Icons.clear_all, size: 20, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Clear All', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: _currentUserId == null
          ? _buildLoadingState()
          : StreamBuilder<List<UserNotification>>(
              stream: _notificationService.getUserNotifications(
                _currentUserId!,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return _buildLoadingState();
                }

                if (snapshot.hasError) {
                  return _buildErrorState(snapshot.error.toString());
                }

                final notifications = snapshot.data ?? [];

                if (notifications.isEmpty) {
                  return _buildEmptyState();
                }

                return ListView.builder(
                  itemCount: notifications.length,
                  itemBuilder: (context, index) {
                    final notification = notifications[index];
                    return _buildNotificationTile(notification);
                  },
                );
              },
            ),
    );
  }

  Widget _buildLoadingState() {
    return const SearchSkeletonLoader(itemCount: 10);
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.errorRed.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline,
                size: 40,
                color: AppColors.errorRed,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Error loading notifications',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.primaryText,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.secondaryText,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                _initializeNotifications();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryOrange,
                foregroundColor: AppColors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primaryOrange.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.notifications_none,
                size: 40,
                color: AppColors.primaryOrange,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'No notifications yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.primaryText,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'You\'ll see temple updates and events here',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.secondaryText,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationTile(UserNotification notification) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      elevation: notification.isRead ? 0 : 1,
      color: notification.isRead
          ? AppColors.white
          : AppColors.primaryOrange.withValues(alpha: 0.04),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: notification.isRead
            ? const BorderSide(color: AppColors.borderGray, width: 0.5)
            : BorderSide(
                color: AppColors.primaryOrange.withValues(alpha: 0.2),
                width: 1,
              ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          if (!notification.isRead) {
            await _notificationService.markAsRead(notification.id);
          }
          _handleNotificationTap(notification);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: _getNotificationColor(notification.type),
                child: Icon(
                  _getNotificationIcon(notification.type),
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notification.title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: notification.isRead
                            ? FontWeight.w500
                            : FontWeight.bold,
                        color: AppColors.primaryText,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification.message,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.secondaryText,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatTime(notification.createdAt),
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.disabledText,
                      ),
                    ),
                  ],
                ),
              ),
              if (!notification.isRead)
                Padding(
                  padding: const EdgeInsets.only(left: 8, top: 4),
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.primaryOrange,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getNotificationColor(NotificationType type) {
    switch (type) {
      case NotificationType.eventReminder:
        return AppColors.primaryOrange;
      case NotificationType.templeUpdate:
        return AppColors.primaryOrange;
      case NotificationType.systemUpdate:
        return AppColors.errorRed;
      case NotificationType.bookingConfirmation:
      case NotificationType.bookingReminder:
      case NotificationType.bookingCancellation:
        return AppColors.infoPurple;
      case NotificationType.donationConfirmation:
        return AppColors.successGreen;
      case NotificationType.liveStreamStarted:
        return AppColors.liveRed;
      case NotificationType.communityUpdate:
        return AppColors.primaryBlue;
      case NotificationType.general:
        return AppColors.secondaryText;
    }
  }

  IconData _getNotificationIcon(NotificationType type) {
    switch (type) {
      case NotificationType.eventReminder:
        return Icons.celebration;
      case NotificationType.templeUpdate:
        return Icons.temple_hindu;
      case NotificationType.systemUpdate:
        return Icons.system_update;
      case NotificationType.bookingConfirmation:
      case NotificationType.bookingReminder:
      case NotificationType.bookingCancellation:
        return Icons.book_online;
      case NotificationType.donationConfirmation:
        return Icons.volunteer_activism;
      case NotificationType.liveStreamStarted:
        return Icons.live_tv;
      case NotificationType.communityUpdate:
        return Icons.people;
      case NotificationType.general:
        return Icons.notifications;
    }
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);
    // Guard against clock skew producing negative differences
    final d = difference.isNegative ? Duration.zero : difference;

    if (d.inMinutes < 1) {
      return 'just now';
    } else if (d.inMinutes < 60) {
      return '${d.inMinutes}m ago';
    } else if (d.inHours < 24) {
      return '${d.inHours}h ago';
    } else if (d.inDays < 7) {
      return '${d.inDays}d ago';
    } else {
      return '${time.day}/${time.month}/${time.year}';
    }
  }

  void _handleNotificationTap(UserNotification notification) {
    // Handle different notification types
    switch (notification.type) {
      case NotificationType.eventReminder:
        // Navigate to events or temple details
        if (notification.relatedId != null) {
          Navigator.pushNamed(context, '/home');
        } else {
          Navigator.pushNamed(context, '/home');
        }
        break;
      case NotificationType.templeUpdate:
        // Navigate to temple discovery
        Navigator.pushNamed(context, '/home');
        break;
      case NotificationType.liveStreamStarted:
        // Navigate to live darshan - go to home since we need a Temple object
        Navigator.pushNamed(context, '/home');
        break;
      case NotificationType.bookingConfirmation:
      case NotificationType.bookingReminder:
      case NotificationType.bookingCancellation:
        // Navigate to my bookings list
        Navigator.pushNamed(context, '/my_bookings');
        break;
      case NotificationType.donationConfirmation:
        // Navigate to donations
        Navigator.pushNamed(context, '/donations');
        break;
      case NotificationType.systemUpdate:
        // Show system update details
        _showSystemUpdateDetails(notification);
        break;
      case NotificationType.communityUpdate:
        // Navigate to community
        Navigator.pushNamed(context, '/community');
        break;
      case NotificationType.general:
        // Handle general navigation
        Navigator.pushNamed(context, '/home');
        break;
    }
  }

  void _showSystemUpdateDetails(UserNotification notification) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.system_update,
              color: _getNotificationColor(notification.type),
            ),
            const SizedBox(width: 8),
            const Text('System Update'),
          ],
        ),
        content: Text(notification.message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

// Remove the old static classes - they're replaced by the real notification models
