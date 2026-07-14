import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../shared/models/temple.dart';

/// Widget to display darshan schedule with Gujarat timezone support
class DarshanScheduleWidget extends StatelessWidget {
  final List<DarshanSchedule> schedules;
  final bool showCurrentTime;
  final bool highlightCurrentSchedule;

  const DarshanScheduleWidget({
    super.key,
    required this.schedules,
    this.showCurrentTime = true,
    this.highlightCurrentSchedule = true,
  });

  // Gujarat timezone offset (IST = UTC+5:30)
  static const Duration gujaratTimezoneOffset = Duration(hours: 5, minutes: 30);

  @override
  Widget build(BuildContext context) {
    if (schedules.isEmpty) {
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

    final gujaratTime = DateTime.now().add(gujaratTimezoneOffset);
    final currentSchedule = _getCurrentSchedule(gujaratTime);
    final todaySchedules = _getTodaySchedules(gujaratTime);

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.schedule, color: Colors.amber),
                const SizedBox(width: 8),
                const Text(
                  'Darshan Schedule',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                if (showCurrentTime) _buildCurrentTime(gujaratTime),
              ],
            ),
            const SizedBox(height: 16),

            // Current live schedule
            if (currentSchedule != null) ...[
              _buildCurrentScheduleCard(currentSchedule, gujaratTime),
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
                  gujaratTime,
                  isCurrentSchedule: schedule == currentSchedule,
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
          ],
        ),
      ),
    );
  }

  /// Build current time display
  Widget _buildCurrentTime(DateTime gujaratTime) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        DateFormat('HH:mm').format(gujaratTime),
        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
      ),
    );
  }

  /// Build current schedule card
  Widget _buildCurrentScheduleCard(
    DarshanSchedule schedule,
    DateTime gujaratTime,
  ) {
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
          _buildTimeRemaining(schedule, gujaratTime),
        ],
      ),
    );
  }

  /// Build schedule item
  Widget _buildScheduleItem(
    DarshanSchedule schedule,
    DateTime gujaratTime, {
    bool isCurrentSchedule = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isCurrentSchedule
            ? Colors.green.withValues(alpha: 0.05)
            : Colors.grey.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isCurrentSchedule
              ? Colors.green.withValues(alpha: 0.3)
              : Colors.grey.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: isCurrentSchedule ? Colors.green : Colors.grey,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Icon(
              isCurrentSchedule ? Icons.play_arrow : Icons.schedule,
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
                    color: isCurrentSchedule ? Colors.green[700] : null,
                  ),
                ),
                Text(
                  '${schedule.startTime} - ${schedule.endTime}',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
          ),
          if (isCurrentSchedule) _buildTimeRemaining(schedule, gujaratTime),
        ],
      ),
    );
  }

  /// Build time remaining widget
  Widget _buildTimeRemaining(DarshanSchedule schedule, DateTime gujaratTime) {
    final endTime = _parseTime(schedule.endTime);
    if (endTime == null) return const SizedBox.shrink();

    final now = TimeOfDay.fromDateTime(gujaratTime);
    final remaining = _calculateTimeRemaining(now, endTime);

    if (remaining <= 0) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '${remaining}m left',
        style: const TextStyle(
          color: Colors.orange,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  /// Build weekly schedule
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

  /// Build day schedule
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

  /// Get current active schedule
  DarshanSchedule? _getCurrentSchedule(DateTime gujaratTime) {
    final currentDay = _getDayOfWeek(gujaratTime);
    final currentTime = TimeOfDay.fromDateTime(gujaratTime);

    for (final schedule in schedules) {
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

  /// Get today's schedules
  List<DarshanSchedule> _getTodaySchedules(DateTime gujaratTime) {
    final currentDay = _getDayOfWeek(gujaratTime);

    return schedules
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
          schedules
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
  int _calculateTimeRemaining(TimeOfDay current, TimeOfDay end) {
    final currentMinutes = current.hour * 60 + current.minute;
    final endMinutes = end.hour * 60 + end.minute;

    if (endMinutes >= currentMinutes) {
      return endMinutes - currentMinutes;
    } else {
      // Next day
      return (24 * 60) - currentMinutes + endMinutes;
    }
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
