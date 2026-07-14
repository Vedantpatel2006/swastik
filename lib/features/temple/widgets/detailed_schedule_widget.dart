import 'package:flutter/material.dart';
import '../../../shared/models/temple.dart';
import '../services/temple_status_service.dart';

/// Detailed schedule widget with weekly view and holiday exceptions
class DetailedScheduleWidget extends StatefulWidget {
  final Temple temple;
  final bool showHolidays;
  final bool showSpecialEvents;

  const DetailedScheduleWidget({
    super.key,
    required this.temple,
    this.showHolidays = true,
    this.showSpecialEvents = true,
  });

  @override
  State<DetailedScheduleWidget> createState() => _DetailedScheduleWidgetState();
}

class _DetailedScheduleWidgetState extends State<DetailedScheduleWidget>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Weekly Schedule'),
            Tab(text: 'Special Dates'),
          ],
        ),
        SizedBox(
          height: 400,
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildWeeklyScheduleTab(),
              _buildSpecialDatesTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWeeklyScheduleTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildCurrentWeekHeader(),
          const SizedBox(height: 16),
          _buildWeeklyScheduleGrid(),
        ],
      ),
    );
  }

  Widget _buildCurrentWeekHeader() {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final endOfWeek = startOfWeek.add(const Duration(days: 6));
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.calendar_today,
            color: Theme.of(context).primaryColor,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Current Week',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
                Text(
                  '${_formatDate(startOfWeek)} - ${_formatDate(endOfWeek)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyScheduleGrid() {
    final schedule = _parseWeeklySchedule();
    final today = DateTime.now().weekday;
    
    return Column(
      children: schedule.entries.map((entry) {
        final dayIndex = _getDayIndex(entry.key);
        final isToday = dayIndex == today;
        final status = _getDayStatus(entry.key, entry.value);
        
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: isToday 
                ? Theme.of(context).primaryColor.withValues(alpha: 0.1)
                : Colors.grey[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isToday 
                  ? Theme.of(context).primaryColor.withValues(alpha: 0.3)
                  : Colors.grey.withValues(alpha: 0.2),
            ),
          ),
          child: ListTile(
            leading: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  entry.key.substring(0, 3).toUpperCase(),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isToday ? Theme.of(context).primaryColor : null,
                  ),
                ),
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: status.color,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
            title: Text(
              entry.key,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: isToday ? FontWeight.w600 : FontWeight.normal,
                color: isToday ? Theme.of(context).primaryColor : null,
              ),
            ),
            subtitle: Text(
              entry.value,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: status.color,
                fontWeight: FontWeight.w500,
              ),
            ),
            trailing: isToday ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'TODAY',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ) : null,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSpecialDatesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          if (widget.showHolidays) ...[
            _buildHolidaysSection(),
            const SizedBox(height: 24),
          ],
          if (widget.showSpecialEvents) ...[
            _buildSpecialEventsSection(),
          ],
        ],
      ),
    );
  }

  Widget _buildHolidaysSection() {
    final holidays = _getUpcomingHolidays();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.event_busy,
              color: Colors.red[600],
            ),
            const SizedBox(width: 8),
            Text(
              'Upcoming Holidays',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (holidays.isEmpty)
          _buildNoHolidaysMessage()
        else
          ...holidays.map((holiday) => _buildHolidayItem(holiday)),
      ],
    );
  }

  Widget _buildSpecialEventsSection() {
    final events = _getUpcomingSpecialEvents();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.celebration,
              color: Colors.orange[600],
            ),
            const SizedBox(width: 8),
            Text(
              'Special Events',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (events.isEmpty)
          _buildNoEventsMessage()
        else
          ...events.map((event) => _buildEventItem(event)),
      ],
    );
  }

  Widget _buildHolidayItem(HolidayInfo holiday) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.red[100],
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              holiday.date.day.toString(),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.red[700],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  holiday.name,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  _formatFullDate(holiday.date),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
                if (holiday.description != null)
                  Text(
                    holiday.description!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.red[700],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventItem(SpecialEventInfo event) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.orange[100],
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              event.date.day.toString(),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.orange[700],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.name,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  _formatFullDate(event.date),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
                if (event.specialTiming != null)
                  Text(
                    'Special Hours: ${event.specialTiming}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.orange[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoHolidaysMessage() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            color: Colors.grey[600],
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'No upcoming holidays scheduled',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoEventsMessage() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            color: Colors.grey[600],
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'No special events scheduled',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Map<String, String> _parseWeeklySchedule() {
    final schedule = <String, String>{};
    final timings = widget.temple.timings;
    
    final days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    
    if (timings.containsKey('Daily') || timings.containsKey('All Days')) {
      final dailyTiming = timings['Daily'] ?? timings['All Days']!;
      for (final day in days) {
        schedule[day] = dailyTiming;
      }
    } else {
      for (final day in days) {
        schedule[day] = timings[day] ?? 'Closed';
      }
    }
    
    return schedule;
  }

  int _getDayIndex(String dayName) {
    switch (dayName) {
      case 'Monday': return 1;
      case 'Tuesday': return 2;
      case 'Wednesday': return 3;
      case 'Thursday': return 4;
      case 'Friday': return 5;
      case 'Saturday': return 6;
      case 'Sunday': return 7;
      default: return 1;
    }
  }

  DayStatus _getDayStatus(String dayName, String timing) {
    if (timing.toLowerCase() == 'closed') {
      return DayStatus(color: Colors.red, status: 'Closed');
    }
    
    final now = DateTime.now();
    final dayIndex = _getDayIndex(dayName);
    
    if (dayIndex == now.weekday) {
      final status = TempleStatusService.getTempleStatus(widget.temple);
      return DayStatus(
        color: status.statusColor,
        status: status.isOpen ? 'Open Now' : 'Closed Now',
      );
    }
    
    return DayStatus(color: Colors.green, status: 'Open');
  }

  List<HolidayInfo> _getUpcomingHolidays() {
    // This would typically come from a service or API
    // For now, return mock data
    final now = DateTime.now();
    return [
      HolidayInfo(
        name: 'Diwali',
        date: DateTime(now.year, 11, 12),
        description: 'Temple closed for festival celebration',
      ),
      HolidayInfo(
        name: 'Holi',
        date: DateTime(now.year + 1, 3, 8),
        description: 'Special celebration timings apply',
      ),
    ].where((holiday) => holiday.date.isAfter(now)).toList();
  }

  List<SpecialEventInfo> _getUpcomingSpecialEvents() {
    // This would typically come from a service or API
    final now = DateTime.now();
    return [
      SpecialEventInfo(
        name: 'Janmashtami Celebration',
        date: DateTime(now.year, 8, 26),
        specialTiming: '4:00 AM - 11:00 PM',
      ),
      SpecialEventInfo(
        name: 'Navratri Festival',
        date: DateTime(now.year, 10, 15),
        specialTiming: '6:00 AM - 10:00 PM',
      ),
    ].where((event) => event.date.isAfter(now)).toList();
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}';
  }

  String _formatFullDate(DateTime date) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}

class DayStatus {
  final Color color;
  final String status;

  DayStatus({required this.color, required this.status});
}

class HolidayInfo {
  final String name;
  final DateTime date;
  final String? description;

  HolidayInfo({
    required this.name,
    required this.date,
    this.description,
  });
}

class SpecialEventInfo {
  final String name;
  final DateTime date;
  final String? specialTiming;

  SpecialEventInfo({
    required this.name,
    required this.date,
    this.specialTiming,
  });
}