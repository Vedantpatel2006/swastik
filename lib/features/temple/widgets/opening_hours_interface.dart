import 'package:flutter/material.dart';
import '../../../shared/models/temple.dart';
import '../services/temple_status_service.dart';
import '../../../shared/services/location_service.dart';

/// Comprehensive opening hours interface with schedule display
class OpeningHoursInterface extends StatefulWidget {
  final Temple temple;
  final bool showTravelTime;
  final bool showVisitSuggestions;

  const OpeningHoursInterface({
    super.key,
    required this.temple,
    this.showTravelTime = true,
    this.showVisitSuggestions = true,
  });

  @override
  State<OpeningHoursInterface> createState() => _OpeningHoursInterfaceState();
}

class _OpeningHoursInterfaceState extends State<OpeningHoursInterface> {
  final LocationService _locationService = LocationService();
  Duration? _travelTime;
  bool _loadingTravelTime = false;

  @override
  void initState() {
    super.initState();
    if (widget.showTravelTime) {
      _calculateTravelTime();
    }
  }

  Future<void> _calculateTravelTime() async {
    if (!widget.showTravelTime) return;
    
    setState(() {
      _loadingTravelTime = true;
    });

    try {
      final userLocation = await _locationService.getCurrentLocation();
      if (userLocation != null) {
        // Estimate travel time (simplified calculation)
        final distance = await _locationService.calculateDistance(
          userLocation,
          widget.temple.location,
        );
        
        // Rough estimate: 30 km/h average speed in city
        final travelTimeHours = distance / 30;
        _travelTime = Duration(
          minutes: (travelTimeHours * 60).round(),
        );
      }
    } catch (e) {
      debugPrint('Error calculating travel time: $e');
    } finally {
      setState(() {
        _loadingTravelTime = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 16),
            _buildCurrentStatus(),
            const SizedBox(height: 16),
            _buildWeeklySchedule(),
            if (widget.showTravelTime && _travelTime != null) ...[
              const SizedBox(height: 16),
              _buildTravelTimeInfo(),
            ],
            if (widget.showVisitSuggestions) ...[
              const SizedBox(height: 16),
              _buildVisitSuggestions(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Icon(
          Icons.access_time,
          color: Theme.of(context).primaryColor,
        ),
        const SizedBox(width: 8),
        Text(
          'Opening Hours',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildCurrentStatus() {
    final status = TempleStatusService.getTempleStatus(widget.temple);
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: status.statusColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: status.statusColor.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            status.isOpen ? Icons.lock_open : Icons.lock,
            color: status.statusColor,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  status.getStatusWithTime(),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: status.statusColor,
                  ),
                ),
                if (status.timingText != null)
                  Text(
                    'Today: ${status.timingText}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklySchedule() {
    if (widget.temple.timings.isEmpty) {
      return _buildNoScheduleMessage();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Weekly Schedule',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        ..._buildScheduleItems(),
      ],
    );
  }

  List<Widget> _buildScheduleItems() {
    final schedule = _parseWeeklySchedule();
    final today = _getCurrentDayName();
    
    return schedule.entries.map((entry) {
      final isToday = entry.key == today;
      
      return Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isToday ? Theme.of(context).primaryColor.withValues(alpha: 0.1) : null,
          borderRadius: BorderRadius.circular(6),
          border: isToday ? Border.all(
            color: Theme.of(context).primaryColor.withValues(alpha: 0.3),
          ) : null,
        ),
        child: Row(
          children: [
            SizedBox(
              width: 80,
              child: Text(
                entry.key,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: isToday ? FontWeight.w600 : FontWeight.normal,
                  color: isToday ? Theme.of(context).primaryColor : null,
                ),
              ),
            ),
            Expanded(
              child: Text(
                entry.value,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: isToday ? FontWeight.w500 : FontWeight.normal,
                ),
              ),
            ),
            if (isToday)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Today',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white,
                    fontSize: 10,
                  ),
                ),
              ),
          ],
        ),
      );
    }).toList();
  }

  Widget _buildNoScheduleMessage() {
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
              'Opening hours not specified. Temple is likely open during daylight hours.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTravelTimeInfo() {
    if (_loadingTravelTime) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.orange[50],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.orange[600]!),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Calculating travel time...',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.orange[700],
              ),
            ),
          ],
        ),
      );
    }

    if (_travelTime == null) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.directions_car,
            color: Colors.orange[600],
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Estimated Travel Time',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.orange[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  _formatTravelTime(_travelTime!),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.orange[800],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVisitSuggestions() {
    final suggestions = _generateVisitSuggestions();
    
    if (suggestions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Best Times to Visit',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        ...suggestions.map((suggestion) => _buildSuggestionItem(suggestion)),
      ],
    );
  }

  Widget _buildSuggestionItem(VisitSuggestion suggestion) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: suggestion.priority == SuggestionPriority.high
            ? Colors.green[50]
            : Colors.orange[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: suggestion.priority == SuggestionPriority.high
              ? Colors.green.withValues(alpha: 0.3)
              : Colors.orange.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            suggestion.priority == SuggestionPriority.high
                ? Icons.thumb_up
                : Icons.info,
            color: suggestion.priority == SuggestionPriority.high
                ? Colors.green[600]
                : Colors.orange[600],
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  suggestion.title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (suggestion.description != null)
                  Text(
                    suggestion.description!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Map<String, String> _parseWeeklySchedule() {
    final schedule = <String, String>{};
    final timings = widget.temple.timings;
    
    // Handle different timing formats
    if (timings.containsKey('Daily') || timings.containsKey('All Days')) {
      final dailyTiming = timings['Daily'] ?? timings['All Days']!;
      for (final day in _getAllDays()) {
        schedule[day] = dailyTiming;
      }
    } else {
      // Individual day timings
      for (final day in _getAllDays()) {
        schedule[day] = timings[day] ?? 'Closed';
      }
    }
    
    return schedule;
  }

  List<String> _getAllDays() {
    return ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
  }

  String _getCurrentDayName() {
    final weekday = DateTime.now().weekday;
    switch (weekday) {
      case 1: return 'Monday';
      case 2: return 'Tuesday';
      case 3: return 'Wednesday';
      case 4: return 'Thursday';
      case 5: return 'Friday';
      case 6: return 'Saturday';
      case 7: return 'Sunday';
      default: return 'Monday';
    }
  }

  String _formatTravelTime(Duration duration) {
    if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes % 60}m';
    } else {
      return '${duration.inMinutes}m';
    }
  }

  List<VisitSuggestion> _generateVisitSuggestions() {
    final suggestions = <VisitSuggestion>[];
    final status = TempleStatusService.getTempleStatus(widget.temple);
    final now = DateTime.now();
    
    // Current status suggestion
    if (status.isOpen) {
      if (status.nextStatusChange != null) {
        final timeUntilClose = status.nextStatusChange!.difference(now);
        if (timeUntilClose.inHours >= 2) {
          suggestions.add(VisitSuggestion(
            title: 'Visit Now',
            description: 'Temple is open for ${_formatTravelTime(timeUntilClose)} more',
            priority: SuggestionPriority.high,
          ));
        } else if (timeUntilClose.inMinutes > 30) {
          suggestions.add(VisitSuggestion(
            title: 'Visit Soon',
            description: 'Temple closes in ${_formatTravelTime(timeUntilClose)}',
            priority: SuggestionPriority.medium,
          ));
        }
      }
    } else {
      if (status.nextStatusChange != null) {
        final timeUntilOpen = status.nextStatusChange!.difference(now);
        if (timeUntilOpen.inHours < 12) {
          suggestions.add(VisitSuggestion(
            title: 'Visit Later Today',
            description: 'Temple opens in ${_formatTravelTime(timeUntilOpen)}',
            priority: SuggestionPriority.medium,
          ));
        }
      }
    }
    
    // Travel time consideration
    if (_travelTime != null && status.isOpen && status.nextStatusChange != null) {
      final timeUntilClose = status.nextStatusChange!.difference(now);
      if (timeUntilClose < _travelTime!) {
        suggestions.add(VisitSuggestion(
          title: 'Consider Next Opening',
          description: 'Travel time (${_formatTravelTime(_travelTime!)}) exceeds remaining open time',
          priority: SuggestionPriority.medium,
        ));
      }
    }
    
    return suggestions;
  }
}

/// Visit suggestion data model
class VisitSuggestion {
  final String title;
  final String? description;
  final SuggestionPriority priority;

  VisitSuggestion({
    required this.title,
    this.description,
    required this.priority,
  });
}

enum SuggestionPriority { high, medium, low }

/// Compact opening hours display for temple cards
class CompactOpeningHours extends StatelessWidget {
  final Temple temple;

  const CompactOpeningHours({
    super.key,
    required this.temple,
  });

  @override
  Widget build(BuildContext context) {
    final status = TempleStatusService.getTempleStatus(temple);
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.access_time,
          size: 14,
          color: Colors.grey[600],
        ),
        const SizedBox(width: 4),
        Text(
          status.timingText ?? 'Hours not specified',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }
}