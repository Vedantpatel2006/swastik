import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/themes/app_colors.dart';
import '../../../shared/models/notification.dart';
import '../../../shared/services/supabase_notification_service.dart';
import '../../../providers/auth_provider.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../../../shared/widgets/common/error_widget.dart';

/// Widget for managing and displaying notifications with regional customization
class NotificationManagerWidget extends StatefulWidget {
  const NotificationManagerWidget({super.key});

  @override
  State<NotificationManagerWidget> createState() =>
      _NotificationManagerWidgetState();
}

class _NotificationManagerWidgetState extends State<NotificationManagerWidget> {
  final SupabaseNotificationService _notificationService =
      SupabaseNotificationService();
  String? _userId;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final uid = authProvider.currentUser?.uid;
      if (uid == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }
      await _notificationService.initialize(userId: uid);
      if (mounted) {
        setState(() {
          _userId = uid;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: AppColors.primaryOrange,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () =>
                Navigator.pushNamed(context, '/notification_preferences'),
          ),
          if (_userId != null)
            IconButton(
              icon: const Icon(Icons.done_all),
              tooltip: 'Mark all as read',
              onPressed: () async {
                await _notificationService.markAllAsRead(_userId!);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('All notifications marked as read'),
                      backgroundColor: AppColors.successGreen,
                    ),
                  );
                }
              },
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const LoadingWidget();

    if (_error != null) {
      return ErrorDisplayWidget(error: _error!, onRetry: _initialize);
    }

    if (_userId == null) {
      return const Center(child: Text('Please sign in to view notifications'));
    }

    return StreamBuilder<List<UserNotification>>(
      stream: _notificationService.getUserNotifications(_userId!),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingWidget();
        }
        if (snapshot.hasError) {
          return ErrorDisplayWidget(
            error: snapshot.error.toString(),
            onRetry: _initialize,
          );
        }

        final notifications = snapshot.data ?? [];
        if (notifications.isEmpty) return _buildEmptyState();

        return RefreshIndicator(
          onRefresh: _initialize,
          child: ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: notifications.length,
            itemBuilder: (context, index) =>
                _buildNotificationCard(notifications[index]),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_none,
            size: 64,
            color: AppColors.disabledText,
          ),
          const SizedBox(height: 16),
          Text(
            'No notifications yet',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: AppColors.secondaryText),
          ),
          const SizedBox(height: 8),
          Text(
            'You\'ll see temple updates and events here',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.secondaryText),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationCard(UserNotification notification) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12.0),
      color: notification.isRead
          ? null
          : AppColors.primaryOrange.withValues(alpha: 0.04),
      child: InkWell(
        onTap: () async {
          if (!notification.isRead) {
            await _notificationService.markAsRead(notification.id);
          }
        },
        borderRadius: BorderRadius.circular(8.0),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8.0),
                decoration: BoxDecoration(
                  color: notification.priorityColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8.0),
                ),
                child: Icon(
                  notification.icon,
                  color: notification.priorityColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notification.title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: notification.isRead
                            ? FontWeight.w500
                            : FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification.message,
                      style: Theme.of(context).textTheme.bodyMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification.timeAgo,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
              if (!notification.isRead)
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(top: 4, left: 8),
                  decoration: const BoxDecoration(
                    color: AppColors.primaryOrange,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
