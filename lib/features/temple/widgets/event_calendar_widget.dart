import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../shared/models/event.dart';
import '../../../shared/services/event_service.dart';
import '../../../core/themes/app_colors.dart';
import '../../../core/themes/app_spacing.dart';

class EventCalendarWidget extends StatefulWidget {
  final String templeId;
  final Function(Event) onEventTap;

  const EventCalendarWidget({
    super.key,
    required this.templeId,
    required this.onEventTap,
  });

  @override
  State<EventCalendarWidget> createState() => _EventCalendarWidgetState();
}

class _EventCalendarWidgetState extends State<EventCalendarWidget> {
  final _eventService = EventService();
  DateTime _selectedMonth = DateTime.now();
  DateTime? _selectedDate;
  List<Event> _events = [];

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    try {
      final events = await _eventService.getEventsForTemple(widget.templeId);
      if (mounted) {
        setState(() {
          _events = events;
        });
      }
    } catch (e) {
      debugPrint('Error loading events: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildMonthSelector(),
        _buildCalendarGrid(),
        if (_selectedDate != null) ...[
          const Divider(),
          Expanded(child: _buildEventsList()),
        ],
      ],
    );
  }

  Widget _buildMonthSelector() {
    return Container(
      padding: AppSpacing.allMd,
      color: AppColors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () {
              setState(() {
                _selectedMonth = DateTime(
                  _selectedMonth.year,
                  _selectedMonth.month - 1,
                );
              });
            },
          ),
          Text(
            DateFormat('MMMM yyyy').format(_selectedMonth),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.primaryText,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () {
              setState(() {
                _selectedMonth = DateTime(
                  _selectedMonth.year,
                  _selectedMonth.month + 1,
                );
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarGrid() {
    final firstDayOfMonth = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
    final lastDayOfMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0);
    final daysInMonth = lastDayOfMonth.day;
    final firstWeekday = firstDayOfMonth.weekday;

    return Container(
      color: AppColors.white,
      padding: AppSpacing.allSm,
      child: Column(
        children: [
          _buildWeekdayHeaders(),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 1,
            ),
            itemCount: firstWeekday % 7 + daysInMonth,
            itemBuilder: (context, index) {
              if (index < firstWeekday % 7) {
                return const SizedBox.shrink();
              }

              final day = index - (firstWeekday % 7) + 1;
              final date = DateTime(_selectedMonth.year, _selectedMonth.month, day);
              final hasEvents = _getEventsForDate(date).isNotEmpty;
              final isSelected = _selectedDate != null &&
                  _selectedDate!.year == date.year &&
                  _selectedDate!.month == date.month &&
                  _selectedDate!.day == date.day;
              final isToday = DateTime.now().year == date.year &&
                  DateTime.now().month == date.month &&
                  DateTime.now().day == date.day;

              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedDate = date;
                  });
                },
                child: Container(
                  margin: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primaryOrange
                        : (isToday
                            ? AppColors.primaryOrange.withValues(alpha: 0.1)
                            : Colors.transparent),
                    borderRadius: BorderRadius.circular(8),
                    border: isToday && !isSelected
                        ? Border.all(color: AppColors.primaryOrange, width: 2)
                        : null,
                  ),
                  child: Stack(
                    children: [
                      Center(
                        child: Text(
                          day.toString(),
                          style: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : (isToday
                                    ? AppColors.primaryOrange
                                    : AppColors.primaryText),
                            fontWeight: isToday || isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                      if (hasEvents && !isSelected)
                        Positioned(
                          bottom: 4,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: Container(
                              width: 4,
                              height: 4,
                              decoration: const BoxDecoration(
                                color: AppColors.primaryOrange,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildWeekdayHeaders() {
    const weekdays = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    return Row(
      children: weekdays.map((day) {
        return Expanded(
          child: Center(
            child: Text(
              day,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.secondaryText,
                fontSize: 12,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildEventsList() {
    if (_selectedDate == null) return const SizedBox.shrink();

    final eventsForDate = _getEventsForDate(_selectedDate!);

    if (eventsForDate.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.event_busy, size: 48, color: AppColors.secondaryText),
            const SizedBox(height: 8),
            Text(
              'No events on ${DateFormat('MMM dd, yyyy').format(_selectedDate!)}',
              style: const TextStyle(color: AppColors.secondaryText),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: AppSpacing.allMd,
      itemCount: eventsForDate.length,
      itemBuilder: (context, index) {
        final event = eventsForDate[index];
        return Card(
          margin: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primaryOrange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.event,
                color: AppColors.primaryOrange,
              ),
            ),
            title: Text(
              event.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              '${DateFormat('h:mm a').format(event.startDate)} - ${DateFormat('h:mm a').format(event.endDate)}',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => widget.onEventTap(event),
          ),
        );
      },
    );
  }

  List<Event> _getEventsForDate(DateTime date) {
    return _events.where((event) {
      return event.startDate.year == date.year &&
          event.startDate.month == date.month &&
          event.startDate.day == date.day;
    }).toList();
  }
}
