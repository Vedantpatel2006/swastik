import 'package:flutter/material.dart';
import '../../../shared/models/temple.dart';

/// Service for determining temple open/closed status
class TempleStatusService {
  /// Check if temple is currently open based on timings
  static bool isTempleOpen(Temple temple) {
    if (temple.timings.isEmpty) return true; // Assume open if no timings
    
    final now = DateTime.now();
    final currentDay = _getDayName(now.weekday);
    
    // Check if there's a timing for current day
    final todayTiming = temple.timings[currentDay] ?? 
                       temple.timings['Daily'] ?? 
                       temple.timings['All Days'];
    
    if (todayTiming == null) return true;
    
    return _isWithinTimings(now, todayTiming);
  }

  /// Get temple status with details
  static TempleStatus getTempleStatus(Temple temple) {
    if (temple.timings.isEmpty) {
      return TempleStatus(
        isOpen: true,
        statusText: 'Open',
        nextStatusChange: null,
      );
    }
    
    final now = DateTime.now();
    final currentDay = _getDayName(now.weekday);
    
    final todayTiming = temple.timings[currentDay] ?? 
                       temple.timings['Daily'] ?? 
                       temple.timings['All Days'];
    
    if (todayTiming == null) {
      return TempleStatus(
        isOpen: true,
        statusText: 'Open',
        nextStatusChange: null,
      );
    }
    
    final isOpen = _isWithinTimings(now, todayTiming);
    final nextChange = _getNextStatusChange(now, todayTiming);
    
    return TempleStatus(
      isOpen: isOpen,
      statusText: isOpen ? 'Open' : 'Closed',
      nextStatusChange: nextChange,
      timingText: todayTiming,
    );
  }

  /// Get day name from weekday number
  static String _getDayName(int weekday) {
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

  /// Check if current time is within temple timings
  static bool _isWithinTimings(DateTime now, String timingText) {
    try {
      // Parse timing text like "6:00 AM - 12:00 PM, 4:00 PM - 9:00 PM"
      final timingParts = timingText.split(',');
      
      for (final part in timingParts) {
        final times = part.trim().split('-');
        if (times.length != 2) continue;
        
        final startTime = _parseTime(times[0].trim());
        final endTime = _parseTime(times[1].trim());
        
        if (startTime == null || endTime == null) continue;
        
        final currentMinutes = now.hour * 60 + now.minute;
        
        if (currentMinutes >= startTime && currentMinutes <= endTime) {
          return true;
        }
      }
      
      return false;
    } catch (e) {
      debugPrint('Error parsing timing: $e');
      return true; // Default to open on error
    }
  }

  /// Get next status change time
  static DateTime? _getNextStatusChange(DateTime now, String timingText) {
    try {
      final timingParts = timingText.split(',');
      final currentMinutes = now.hour * 60 + now.minute;
      
      for (final part in timingParts) {
        final times = part.trim().split('-');
        if (times.length != 2) continue;
        
        final startTime = _parseTime(times[0].trim());
        final endTime = _parseTime(times[1].trim());
        
        if (startTime == null || endTime == null) continue;
        
        // If before opening time, return opening time
        if (currentMinutes < startTime) {
          return DateTime(
            now.year,
            now.month,
            now.day,
            startTime ~/ 60,
            startTime % 60,
          );
        }
        
        // If within timing, return closing time
        if (currentMinutes >= startTime && currentMinutes <= endTime) {
          return DateTime(
            now.year,
            now.month,
            now.day,
            endTime ~/ 60,
            endTime % 60,
          );
        }
      }
      
      return null;
    } catch (e) {
      debugPrint('Error getting next status change: $e');
      return null;
    }
  }

  /// Parse time string to minutes since midnight
  static int? _parseTime(String timeStr) {
    try {
      // Handle formats like "6:00 AM", "12:00 PM", "18:00"
      final parts = timeStr.trim().split(' ');
      final timeParts = parts[0].split(':');
      
      if (timeParts.length != 2) return null;
      
      int hour = int.parse(timeParts[0]);
      final minute = int.parse(timeParts[1]);
      
      // Handle AM/PM
      if (parts.length > 1) {
        final period = parts[1].toUpperCase();
        if (period == 'PM' && hour != 12) {
          hour += 12;
        } else if (period == 'AM' && hour == 12) {
          hour = 0;
        }
      }
      
      return hour * 60 + minute;
    } catch (e) {
      debugPrint('Error parsing time: $e');
      return null;
    }
  }
}

/// Temple status data class
class TempleStatus {
  final bool isOpen;
  final String statusText;
  final DateTime? nextStatusChange;
  final String? timingText;

  TempleStatus({
    required this.isOpen,
    required this.statusText,
    this.nextStatusChange,
    this.timingText,
  });

  /// Get status color
  Color get statusColor => isOpen ? Colors.green : Colors.red;

  /// Get status with time until change
  String getStatusWithTime() {
    if (nextStatusChange == null) return statusText;
    
    final now = DateTime.now();
    final difference = nextStatusChange!.difference(now);
    
    if (difference.inMinutes < 60) {
      return '$statusText • ${isOpen ? 'Closes' : 'Opens'} in ${difference.inMinutes}m';
    } else {
      return '$statusText • ${isOpen ? 'Closes' : 'Opens'} at ${_formatTime(nextStatusChange!)}';
    }
  }

  String _formatTime(DateTime time) {
    final hour = time.hour > 12 ? time.hour - 12 : time.hour;
    final period = time.hour >= 12 ? 'PM' : 'AM';
    return '${hour == 0 ? 12 : hour}:${time.minute.toString().padLeft(2, '0')} $period';
  }

  /// Convert to JSON for caching
  Map<String, dynamic> toJson() {
    return {
      'isOpen': isOpen,
      'statusText': statusText,
      if (nextStatusChange != null) 'nextStatusChange': nextStatusChange!.toIso8601String(),
      if (timingText != null) 'timingText': timingText,
    };
  }

  /// Create from JSON
  factory TempleStatus.fromJson(Map<String, dynamic> json) {
    return TempleStatus(
      isOpen: json['isOpen'] as bool,
      statusText: json['statusText'] as String,
      nextStatusChange: json['nextStatusChange'] != null 
          ? DateTime.parse(json['nextStatusChange'] as String)
          : null,
      timingText: json['timingText'] as String?,
    );
  }

  /// Get if currently open (alias for isOpen)
  bool get isCurrentlyOpen => isOpen;
}
