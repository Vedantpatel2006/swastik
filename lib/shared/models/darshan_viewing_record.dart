import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Record of a user's darshan viewing session
class DarshanViewingRecord {
  final String id;
  final String templeId;
  final String userId;
  final String videoId;
  final DateTime startTime;
  final DateTime? endTime;
  final Duration watchDuration;
  final String streamQuality;
  final bool completedSession;
  final Map<String, dynamic>? metadata;
  final DateTime createdAt;
  final DateTime updatedAt;

  const DarshanViewingRecord({
    required this.id,
    required this.templeId,
    required this.userId,
    required this.videoId,
    required this.startTime,
    this.endTime,
    required this.watchDuration,
    this.streamQuality = 'auto',
    this.completedSession = false,
    this.metadata,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Create DarshanViewingRecord from Firestore document
  factory DarshanViewingRecord.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return DarshanViewingRecord.fromJson({...data, 'id': doc.id});
  }

  /// Create DarshanViewingRecord from JSON
  factory DarshanViewingRecord.fromJson(Map<String, dynamic> json) {
    return DarshanViewingRecord(
      id: json['id'] as String,
      templeId: json['templeId'] as String,
      userId: json['userId'] as String,
      videoId: json['videoId'] as String,
      startTime: json['startTime'] != null
          ? (json['startTime'] as Timestamp).toDate()
          : DateTime.now(),
      endTime: json['endTime'] != null
          ? (json['endTime'] as Timestamp).toDate()
          : null,
      watchDuration: Duration(
        seconds: json['watchDurationSeconds'] as int? ?? 0,
      ),
      streamQuality: json['streamQuality'] as String? ?? 'auto',
      completedSession: json['completedSession'] as bool? ?? false,
      metadata: json['metadata'] != null
          ? Map<String, dynamic>.from(json['metadata'] as Map)
          : null,
      createdAt: json['createdAt'] != null
          ? (json['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? (json['updatedAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  /// Convert DarshanViewingRecord to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'templeId': templeId,
      'userId': userId,
      'videoId': videoId,
      'startTime': Timestamp.fromDate(startTime),
      if (endTime != null) 'endTime': Timestamp.fromDate(endTime!),
      'watchDurationSeconds': watchDuration.inSeconds,
      'streamQuality': streamQuality,
      'completedSession': completedSession,
      if (metadata != null) 'metadata': metadata,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  /// Validate darshan viewing record data
  bool isValid() {
    return id.isNotEmpty &&
        templeId.isNotEmpty &&
        userId.isNotEmpty &&
        videoId.isNotEmpty &&
        watchDuration.inSeconds >= 0 &&
        startTime.isBefore(DateTime.now().add(const Duration(minutes: 5)));
  }

  /// Create a copy of DarshanViewingRecord with updated fields
  DarshanViewingRecord copyWith({
    String? id,
    String? templeId,
    String? userId,
    String? videoId,
    DateTime? startTime,
    DateTime? endTime,
    Duration? watchDuration,
    String? streamQuality,
    bool? completedSession,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DarshanViewingRecord(
      id: id ?? this.id,
      templeId: templeId ?? this.templeId,
      userId: userId ?? this.userId,
      videoId: videoId ?? this.videoId,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      watchDuration: watchDuration ?? this.watchDuration,
      streamQuality: streamQuality ?? this.streamQuality,
      completedSession: completedSession ?? this.completedSession,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  /// Get formatted watch duration
  String get formattedWatchDuration {
    final hours = watchDuration.inHours;
    final minutes = watchDuration.inMinutes % 60;
    final seconds = watchDuration.inSeconds % 60;

    if (hours > 0) {
      return '${hours}h ${minutes}m ${seconds}s';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }

  /// Get time of day when viewing started
  TimeOfDay get startTimeOfDay {
    return TimeOfDay.fromDateTime(startTime);
  }

  /// Check if viewing session was long (more than 10 minutes)
  bool get isLongSession {
    return watchDuration.inMinutes >= 10;
  }

  /// Check if viewing session was completed (more than 80% of typical darshan duration)
  bool get isCompletedSession {
    return completedSession || watchDuration.inMinutes >= 20;
  }

  /// Get viewing session quality score (0-100)
  int get qualityScore {
    int score = 0;

    // Base score for watching
    score += 20;

    // Duration bonus
    if (watchDuration.inMinutes >= 5) score += 20;
    if (watchDuration.inMinutes >= 15) score += 20;
    if (watchDuration.inMinutes >= 30) score += 20;

    // Completion bonus
    if (completedSession) score += 20;

    return score.clamp(0, 100);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DarshanViewingRecord &&
        other.id == id &&
        other.templeId == templeId &&
        other.userId == userId &&
        other.videoId == videoId &&
        other.startTime == startTime &&
        other.endTime == endTime &&
        other.watchDuration == watchDuration &&
        other.streamQuality == streamQuality &&
        other.completedSession == completedSession &&
        _mapEquals(other.metadata, metadata) &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      templeId,
      userId,
      videoId,
      startTime,
      endTime,
      watchDuration,
      streamQuality,
      completedSession,
      metadata,
      createdAt,
      updatedAt,
    );
  }

  @override
  String toString() {
    return 'DarshanViewingRecord(id: $id, templeId: $templeId, '
        'duration: ${formattedWatchDuration}, quality: $streamQuality)';
  }

  bool _mapEquals(Map<String, dynamic>? a, Map<String, dynamic>? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (a[key] != b[key]) return false;
    }
    return true;
  }
}
