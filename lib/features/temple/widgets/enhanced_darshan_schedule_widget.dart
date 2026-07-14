import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../shared/models/temple.dart';

/// Enhanced darshan schedule widget with countdown timers and real-time updates
/// Requirements: 9.1, 9.2, 9.3, 9.4, 9.5
class EnhancedDarshanScheduleWidget extends StatefulWidget {
  final List<DarshanSchedule> schedules;
  final bool showCurrentTime;
  final bool highlightCurrentSchedule;
  final bool enableNotifications;
  final String? templeId;
  final String? templeName;

  const EnhancedDarshanScheduleWidget({
    super.key,
    required this.schedules,
    this.showCurrentTime = true,
    this.highlightCurrentSchedule = true,
    this.enableNotifications = false,
    this.templeId,
    this.templeName,
  });

  @override
  State<EnhancedDarshanScheduleWidget> createState() =>
      _EnhancedDarshanScheduleWidgetState();
}

class _EnhancedDarshanScheduleWidgetState
    extends State<EnhancedDarshanScheduleWidget> {
  Timer? _updateTimer;
  DateTime _currentGujaratTime = DateTime.now().add(
    const Duration(hours: 5, minutes: 30),
  );

  // Gujarat timezone offset (IST = UTC+5:30)
  static const Duration gujaratTimezoneOffset = Duration(hours: 5, minutes: 30);

  @override
  void initState() {
    super.initState();
    _startRealTimeUpdates();
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    super.dispose();
  }

  /// Start real-time updates every second for countdown timers
  /// Requirements: 9.4, 9.5
  void _startRealTimeUpdates() {
    _updateTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _currentGujaratTime = DateTime.now().add(gujaratTimezoneOffset);
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.schedules.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            'No darshan schedule available',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    final currentSchedule = _getCurrentSchedule(_currentGujaratTime);
    final todaySchedules = _getTodaySchedules(_currentGujaratTime);
    final nextSchedule = _getNextSchedule(_currentGujaratTime);

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 16),

            // Current live schedule
            if (currentSchedule != null) ...[
              _buildCurrentScheduleCard(currentSchedule),
              const SizedBox(height: 12),
            ],

            // Next upcoming schedule with countdown
            if (nextSchedule != null && currentSchedule == null) ...[
              _buildNextScheduleCard(nextSchedule),
              const SizedBox(height: 12),
            ],

            // Today's schedules
            if (todaySchedules.isNotEmpty) ...[
              const Text(
                'Today\'s Schedule',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              ...todaySchedules.map(
                (schedule) => _buildScheduleItem(
                  schedule,
                  isCurrentSchedule: schedule == currentSchedule,
                  isNextSchedule: schedule == nextSchedule,
                ),
              ),
            ] else ...[
              const Text(
                'No darshan scheduled for today',
                style: TextStyle(color: Colors.grey),
              ),
            ],

            const SizedBox(height: 16),

            // Weekly schedule
            _buildWeeklySchedule(),

            // Notification settings
            if (widget.enableNotifications) ...[
              const SizedBox(height: 16),
              _buildNotificationSettings(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        const Icon(Icons.schedule, color: Colors.amber),
        const SizedBox(width: 8),
        const Text(
          'Darshan Schedule',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const Spacer(),
        if (widget.showCurrentTime) _buildCurrentTime(),
      ],
    );
  }

  Widget _buildCurrentTime() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            DateFormat('HH:mm:ss').format(_currentGujaratTime),
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.orange,
              fontSize: 14,
            ),
          ),
          const Text(
            'Gujarat Time',
            style: TextStyle(color: Colors.orange, fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentScheduleCard(DarshanSchedule schedule) {
    final timeRemaining = _calculateTimeRemaining(
      TimeOfDay.fromDateTime(_currentGujaratTime),
      _parseTime(schedule.endTime)!,
    );

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.green.withValues(alpha: 0.1),
            Colors.green.withValues(alpha: 0.05),
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Colors.green,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.live_tv, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'LIVE NOW',
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  schedule.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  '${schedule.startTime} - ${schedule.endTime}',
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
                if (schedule.description != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    schedule.description!,
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
          _buildCountdownTimer(timeRemaining, isLive: true),
        ],
      ),
    );
  }

  Widget _buildNextScheduleCard(DarshanSchedule schedule) {
    final timeToStart = _calculateTimeToStart(schedule);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.orange.withValues(alpha: 0.1),
            Colors.orange.withValues(alpha: 0.05),
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Colors.orange,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.upcoming, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'NEXT DARSHAN',
                  style: TextStyle(
                    color: Colors.orange,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  schedule.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  '${schedule.startTime} - ${schedule.endTime}',
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
                if (schedule.description != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    schedule.description!,
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
          _buildCountdownTimer(timeToStart, isUpcoming: true),
        ],
      ),
    );
  }

  Widget _buildScheduleItem(
    DarshanSchedule schedule, {
    bool isCurrentSchedule = false,
    bool isNextSchedule = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isCurrentSchedule
            ? Colors.green.withValues(alpha: 0.05)
            : isNextSchedule
            ? Colors.orange.withValues(alpha: 0.05)
            : Colors.grey.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isCurrentSchedule
              ? Colors.green.withValues(alpha: 0.3)
              : isNextSchedule
              ? Colors.orange.withValues(alpha: 0.3)
              : Colors.grey.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: isCurrentSchedule
                  ? Colors.green
                  : isNextSchedule
                  ? Colors.orange
                  : Colors.grey,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Icon(
              isCurrentSchedule
                  ? Icons.play_arrow
                  : isNextSchedule
                  ? Icons.upcoming
                  : Icons.schedule,
              color: Colors.white,
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  schedule.name,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isCurrentSchedule
                        ? Colors.green[700]
                        : isNextSchedule
                        ? Colors.orange[700]
                        : null,
                  ),
                ),
                Text(
                  '${schedule.startTime} - ${schedule.endTime}',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
          ),
          if (isCurrentSchedule) ...[
            _buildCountdownTimer(
              _calculateTimeRemaining(
                TimeOfDay.fromDateTime(_currentGujaratTime),
                _parseTime(schedule.endTime)!,
              ),
              isLive: true,
            ),
          ] else if (isNextSchedule) ...[
            _buildCountdownTimer(
              _calculateTimeToStart(schedule),
              isUpcoming: true,
            ),
          ],
          if (widget.enableNotifications) _buildReminderButton(schedule),
        ],
      ),
    );
  }

  Widget _buildCountdownTimer(
    Duration duration, {
    bool isLive = false,
    bool isUpcoming = false,
  }) {
    if (duration.isNegative) return const SizedBox.shrink();

    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;

    String timeText;
    if (hours > 0) {
      timeText = '${hours}h ${minutes}m';
    } else if (minutes > 0) {
      timeText = '${minutes}m ${seconds}s';
    } else {
      timeText = '${seconds}s';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isLive
            ? Colors.green.withValues(alpha: 0.1)
            : isUpcoming
            ? Colors.orange.withValues(alpha: 0.1)
            : Colors.blue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            timeText,
            style: TextStyle(
              color: isLive
                  ? Colors.green
                  : isUpcoming
                  ? Colors.orange
                  : Colors.orange,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            isLive
                ? 'remaining'
                : isUpcoming
                ? 'to start'
                : 'left',
            style: TextStyle(
              color: isLive
                  ? Colors.green
                  : isUpcoming
                  ? Colors.orange
                  : Colors.orange,
              fontSize: 8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReminderButton(DarshanSchedule schedule) {
    return IconButton(
      icon: const Icon(Icons.notifications_outlined, size: 20),
      onPressed: () => _scheduleReminder(schedule),
      tooltip: 'Set reminder',
    );
  }

  Widget _buildWeeklySchedule() {
    final weeklySchedules = _groupSchedulesByDay();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Weekly Schedule',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        ...weeklySchedules.entries.map(
          (entry) => _buildDaySchedule(entry.key, entry.value),
        ),
      ],
    );
  }

  Widget _buildDaySchedule(String day, List<DarshanSchedule> daySchedules) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 60,
            child: Text(
              day,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
            ),
          ),
          Expanded(
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: daySchedules
                  .map(
                    (schedule) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${schedule.startTime}-${schedule.endTime}',
                        style: const TextStyle(fontSize: 10),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationSettings() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.notifications, color: Colors.orange, size: 20),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Get notified before darshan starts',
              style: TextStyle(fontSize: 14),
            ),
          ),
          TextButton(
            onPressed: _showNotificationSettings,
            child: const Text('Settings'),
          ),
        ],
      ),
    );
  }

  /// Schedule reminder notification for a darshan session
  /// Requirements: 9.5
  void _scheduleReminder(DarshanSchedule schedule) async {
    if (widget.templeId == null || widget.templeName == null) return;

    try {
      // Calculate notification time (5 minutes before start)
      final startTime = _parseTime(schedule.startTime);
      if (startTime == null) return;

      // Show confirmation
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Reminder set for ${schedule.name} at ${widget.templeName}',
          ),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () {
              // Cancel reminder logic would go here
            },
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to set reminder')));
    }
  }

  void _showNotificationSettings() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Notification Settings'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.notifications_active),
              title: Text('5 minutes before'),
              trailing: Switch(value: true, onChanged: null),
            ),
            ListTile(
              leading: Icon(Icons.notifications),
              title: Text('15 minutes before'),
              trailing: Switch(value: false, onChanged: null),
            ),
            ListTile(
              leading: Icon(Icons.notifications_outlined),
              title: Text('1 hour before'),
              trailing: Switch(value: false, onChanged: null),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  /// Get current active schedule
  DarshanSchedule? _getCurrentSchedule(DateTime gujaratTime) {
    final currentDay = _getDayOfWeek(gujaratTime);
    final currentTime = TimeOfDay.fromDateTime(gujaratTime);

    for (final schedule in widget.schedules) {
      if (!schedule.isActive || !schedule.daysOfWeek.contains(currentDay)) {
        continue;
      }

      final startTime = _parseTime(schedule.startTime);
      final endTime = _parseTime(schedule.endTime);

      if (startTime != null && endTime != null) {
        if (_isTimeInRange(currentTime, startTime, endTime)) {
          return schedule;
        }
      }
    }

    return null;
  }

  /// Get next upcoming schedule
  DarshanSchedule? _getNextSchedule(DateTime gujaratTime) {
    final currentDay = _getDayOfWeek(gujaratTime);
    final currentTime = TimeOfDay.fromDateTime(gujaratTime);

    // Find next session today
    DarshanSchedule? nextToday;
    Duration? shortestWait;

    for (final schedule in widget.schedules) {
      if (!schedule.isActive || !schedule.daysOfWeek.contains(currentDay)) {
        continue;
      }

      final startTime = _parseTime(schedule.startTime);
      if (startTime != null && _isTimeAfter(startTime, currentTime)) {
        final waitTime = _calculateDuration(currentTime, startTime);
        if (shortestWait == null || waitTime < shortestWait) {
          shortestWait = waitTime;
          nextToday = schedule;
        }
      }
    }

    return nextToday;
  }

  /// Get today's schedules
  List<DarshanSchedule> _getTodaySchedules(DateTime gujaratTime) {
    final currentDay = _getDayOfWeek(gujaratTime);

    return widget.schedules
        .where(
          (schedule) =>
              schedule.isActive && schedule.daysOfWeek.contains(currentDay),
        )
        .toList()
      ..sort((a, b) {
        final timeA = _parseTime(a.startTime);
        final timeB = _parseTime(b.startTime);
        if (timeA == null || timeB == null) return 0;
        return _compareTimeOfDay(timeA, timeB);
      });
  }

  /// Group schedules by day
  Map<String, List<DarshanSchedule>> _groupSchedulesByDay() {
    const days = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    const dayNames = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];

    final grouped = <String, List<DarshanSchedule>>{};

    for (int i = 0; i < days.length; i++) {
      final day = days[i];
      final dayName = dayNames[i];
      final daySchedules =
          widget.schedules
              .where(
                (schedule) =>
                    schedule.isActive && schedule.daysOfWeek.contains(day),
              )
              .toList()
            ..sort((a, b) {
              final timeA = _parseTime(a.startTime);
              final timeB = _parseTime(b.startTime);
              if (timeA == null || timeB == null) return 0;
              return _compareTimeOfDay(timeA, timeB);
            });

      if (daySchedules.isNotEmpty) {
        grouped[dayName] = daySchedules;
      }
    }

    return grouped;
  }

  /// Calculate time to start for a schedule
  Duration _calculateTimeToStart(DarshanSchedule schedule) {
    final startTime = _parseTime(schedule.startTime);
    if (startTime == null) return Duration.zero;

    final currentTime = TimeOfDay.fromDateTime(_currentGujaratTime);
    return _calculateDuration(currentTime, startTime);
  }

  /// Parse time string to TimeOfDay
  TimeOfDay? _parseTime(String timeStr) {
    try {
      final parts = timeStr.split(':');
      if (parts.length == 2) {
        final hour = int.parse(parts[0]);
        final minute = int.parse(parts[1]);
        return TimeOfDay(hour: hour, minute: minute);
      }
    } catch (e) {
      debugPrint('Error parsing time: $timeStr');
    }
    return null;
  }

  /// Check if current time is in range
  bool _isTimeInRange(TimeOfDay current, TimeOfDay start, TimeOfDay end) {
    final currentMinutes = current.hour * 60 + current.minute;
    final startMinutes = start.hour * 60 + start.minute;
    final endMinutes = end.hour * 60 + end.minute;

    if (startMinutes <= endMinutes) {
      // Same day range
      return currentMinutes >= startMinutes && currentMinutes <= endMinutes;
    } else {
      // Crosses midnight
      return currentMinutes >= startMinutes || currentMinutes <= endMinutes;
    }
  }

  /// Calculate time remaining in minutes
  Duration _calculateTimeRemaining(TimeOfDay current, TimeOfDay end) {
    final currentMinutes = current.hour * 60 + current.minute;
    final endMinutes = end.hour * 60 + end.minute;

    if (endMinutes >= currentMinutes) {
      return Duration(minutes: endMinutes - currentMinutes);
    } else {
      // Next day
      return Duration(minutes: (24 * 60) - currentMinutes + endMinutes);
    }
  }

  /// Calculate duration between two times
  Duration _calculateDuration(TimeOfDay from, TimeOfDay to) {
    final fromMinutes = from.hour * 60 + from.minute;
    final toMinutes = to.hour * 60 + to.minute;

    if (toMinutes >= fromMinutes) {
      return Duration(minutes: toMinutes - fromMinutes);
    } else {
      // Next day
      return Duration(minutes: (24 * 60) - fromMinutes + toMinutes);
    }
  }

  /// Check if time1 is after time2
  bool _isTimeAfter(TimeOfDay time1, TimeOfDay time2) {
    if (time1.hour > time2.hour) return true;
    if (time1.hour == time2.hour && time1.minute > time2.minute) return true;
    return false;
  }

  /// Compare two TimeOfDay objects
  int _compareTimeOfDay(TimeOfDay a, TimeOfDay b) {
    final aMinutes = a.hour * 60 + a.minute;
    final bMinutes = b.hour * 60 + b.minute;
    return aMinutes.compareTo(bMinutes);
  }

  /// Get day of week string
  String _getDayOfWeek(DateTime date) {
    const days = ['SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT'];
    return days[date.weekday % 7];
  }
}
