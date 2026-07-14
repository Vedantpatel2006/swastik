import 'package:flutter/material.dart';
import '../../../core/config/youtube_api_config.dart';
import '../../../shared/models/temple.dart';

/// Fallback widget displayed when live darshan is unavailable
class LiveDarshanFallbackWidget extends StatelessWidget {
  final Temple temple;
  final YouTubeApiError? error;
  final VoidCallback? onRetry;
  final VoidCallback? onViewSchedule;
  final bool showRetryButton;
  final bool showScheduleButton;

  const LiveDarshanFallbackWidget({
    super.key,
    required this.temple,
    this.error,
    this.onRetry,
    this.onViewSchedule,
    this.showRetryButton = true,
    this.showScheduleButton = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildIcon(context),
          const SizedBox(height: 16),
          _buildTitle(context),
          const SizedBox(height: 8),
          _buildMessage(context),
          if (_shouldShowSchedule()) ...[
            const SizedBox(height: 16),
            _buildScheduleInfo(context),
          ],
          const SizedBox(height: 16),
          _buildActionButtons(context),
        ],
      ),
    );
  }

  Widget _buildIcon(BuildContext context) {
    IconData iconData;
    Color iconColor;

    if (error != null) {
      switch (error!.code) {
        case YouTubeApiErrorCode.networkTimeout:
        case YouTubeApiErrorCode.connectionFailed:
          iconData = Icons.wifi_off;
          iconColor = Theme.of(context).colorScheme.error;
          break;
        case YouTubeApiErrorCode.quotaExceeded:
        case YouTubeApiErrorCode.rateLimitExceeded:
          iconData = Icons.hourglass_empty;
          iconColor = Theme.of(context).colorScheme.primary;
          break;
        case YouTubeApiErrorCode.channelNotFound:
          iconData = Icons.search_off;
          iconColor = Theme.of(context).colorScheme.error;
          break;
        default:
          iconData = Icons.tv_off;
          iconColor = Theme.of(context).colorScheme.error;
      }
    } else {
      iconData = Icons.tv_off;
      iconColor = Theme.of(context).colorScheme.onSurfaceVariant;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: iconColor.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(iconData, size: 48, color: iconColor),
    );
  }

  Widget _buildTitle(BuildContext context) {
    String title;

    if (error != null) {
      switch (error!.code) {
        case YouTubeApiErrorCode.networkTimeout:
        case YouTubeApiErrorCode.connectionFailed:
          title = 'Connection Issue';
          break;
        case YouTubeApiErrorCode.quotaExceeded:
        case YouTubeApiErrorCode.rateLimitExceeded:
          title = 'Service Temporarily Unavailable';
          break;
        case YouTubeApiErrorCode.channelNotFound:
          title = 'Live Stream Not Found';
          break;
        default:
          title = 'Live Darshan Unavailable';
      }
    } else {
      title = 'Live Darshan Not Available';
    }

    return Text(
      title,
      style: Theme.of(
        context,
      ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildMessage(BuildContext context) {
    String message;

    if (error != null) {
      message = error!.userFriendlyMessage;
    } else {
      message =
          '${temple.name} is not currently streaming live darshan. '
          'Please check back later or view the darshan schedule.';
    }

    return Text(
      message,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildScheduleInfo(BuildContext context) {
    final schedule = temple.liveDarshan?.schedule ?? [];
    if (schedule.isEmpty) return const SizedBox.shrink();

    final nextDarshan = _getNextDarshanTime(schedule);
    if (nextDarshan == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.schedule,
                size: 16,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Next Darshan',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            nextDarshan,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    final buttons = <Widget>[];

    if (showRetryButton && onRetry != null && _shouldShowRetryButton()) {
      buttons.add(
        OutlinedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh, size: 18),
          label: const Text('Try Again'),
        ),
      );
    }

    if (showScheduleButton && onViewSchedule != null && _shouldShowSchedule()) {
      buttons.add(
        FilledButton.icon(
          onPressed: onViewSchedule,
          icon: const Icon(Icons.schedule, size: 18),
          label: const Text('View Schedule'),
        ),
      );
    }

    if (buttons.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 12,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: buttons,
    );
  }

  bool _shouldShowRetryButton() {
    if (error == null) return false;

    // Show retry button for retryable errors
    return error!.isRetryable;
  }

  bool _shouldShowSchedule() {
    final schedule = temple.liveDarshan?.schedule ?? [];
    return schedule.isNotEmpty;
  }

  String? _getNextDarshanTime(List<DarshanSchedule> schedule) {
    if (schedule.isEmpty) return null;

    final now = DateTime.now();
    final today = now.weekday;
    final currentTime = TimeOfDay.fromDateTime(now);

    // Map weekday numbers to schedule day strings
    const dayMap = {
      1: 'MON',
      2: 'TUE',
      3: 'WED',
      4: 'THU',
      5: 'FRI',
      6: 'SAT',
      7: 'SUN',
    };

    // Find next darshan today
    final todaySchedule = schedule
        .where((s) => s.isActive && s.daysOfWeek.contains(dayMap[today]))
        .toList();

    for (final darshan in todaySchedule) {
      final startTime = _parseTime(darshan.startTime);
      if (startTime != null && _isTimeAfter(startTime, currentTime)) {
        return '${darshan.name} today at ${darshan.startTime}';
      }
    }

    // Find next darshan in upcoming days
    for (int i = 1; i <= 7; i++) {
      final checkDay = ((today + i - 1) % 7) + 1;
      final daySchedule = schedule
          .where((s) => s.isActive && s.daysOfWeek.contains(dayMap[checkDay]))
          .toList();

      if (daySchedule.isNotEmpty) {
        final firstDarshan = daySchedule.first;
        final dayName = _getDayName(checkDay);
        return '${firstDarshan.name} on $dayName at ${firstDarshan.startTime}';
      }
    }

    return null;
  }

  TimeOfDay? _parseTime(String timeString) {
    try {
      final parts = timeString.split(':');
      if (parts.length == 2) {
        final hour = int.parse(parts[0]);
        final minute = int.parse(parts[1]);
        return TimeOfDay(hour: hour, minute: minute);
      }
    } catch (e) {
      // Invalid time format
    }
    return null;
  }

  bool _isTimeAfter(TimeOfDay time1, TimeOfDay time2) {
    if (time1.hour > time2.hour) return true;
    if (time1.hour == time2.hour && time1.minute > time2.minute) return true;
    return false;
  }

  String _getDayName(int weekday) {
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return days[weekday - 1];
  }
}

/// Compact fallback widget for temple cards
class LiveDarshanCompactFallback extends StatelessWidget {
  final Temple temple;
  final YouTubeApiError? error;
  final VoidCallback? onTap;

  const LiveDarshanCompactFallback({
    super.key,
    required this.temple,
    this.error,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.subscriptions_outlined,
              size: 16,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Text(
              'Watch Channel',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Loading state widget for live darshan
class LiveDarshanLoadingWidget extends StatelessWidget {
  final String? message;

  const LiveDarshanLoadingWidget({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            message ?? 'Checking live stream status...',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
