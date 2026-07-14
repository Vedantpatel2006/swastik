import 'package:cloud_firestore/cloud_firestore.dart';

/// User statistics model for tracking spiritual journey
class UserStats {
  final int totalFavorites;
  final int totalVisits;
  final int uniqueTemplesVisited;
  final int darshanViewingMinutes;
  final int totalDonations;
  final double totalDonationAmount;
  final int eventsAttended;
  final int reviewsWritten;
  final DateTime? lastVisitDate;
  final DateTime? firstVisitDate;

  const UserStats({
    this.totalFavorites = 0,
    this.totalVisits = 0,
    this.uniqueTemplesVisited = 0,
    this.darshanViewingMinutes = 0,
    this.totalDonations = 0,
    this.totalDonationAmount = 0.0,
    this.eventsAttended = 0,
    this.reviewsWritten = 0,
    this.lastVisitDate,
    this.firstVisitDate,
  });

  /// Check if user has any activity
  bool get hasActivity => totalVisits > 0 || totalFavorites > 0;

  /// Get formatted darshan viewing time
  String get formattedDarshanTime {
    if (darshanViewingMinutes < 60) {
      return '${darshanViewingMinutes}m';
    } else {
      final hours = darshanViewingMinutes ~/ 60;
      final minutes = darshanViewingMinutes % 60;
      return minutes > 0 ? '${hours}h ${minutes}m' : '${hours}h';
    }
  }

  /// Mock data for charts - visits by month
  Map<String, int> get visitsByMonth {
    // Mock data - in a real app this would come from actual visit data
    return {
      'Jan': totalVisits ~/ 12,
      'Feb': (totalVisits ~/ 12) + 1,
      'Mar': totalVisits ~/ 12,
      'Apr': (totalVisits ~/ 12) + 2,
      'May': totalVisits ~/ 12,
      'Jun': (totalVisits ~/ 12) + 1,
    };
  }

  /// Mock data for charts - visits by tradition
  Map<String, int> get visitsByTradition {
    // Mock data - in a real app this would come from actual visit data
    return {
      'Hindu': (totalVisits * 0.7).round(),
      'Jain': (totalVisits * 0.2).round(),
      'Buddhist': (totalVisits * 0.1).round(),
    };
  }

  /// First visit date (alias for firstVisitDate)
  DateTime? get firstVisit => firstVisitDate;

  /// Last visit date (alias for lastVisitDate)
  DateTime? get lastVisit => lastVisitDate;

  /// Calculate spiritual journey days
  int get spiritualJourneyDays {
    if (firstVisitDate == null || lastVisitDate == null) return 0;
    return lastVisitDate!.difference(firstVisitDate!).inDays;
  }

  /// Get most visited tradition (mock)
  String get mostVisitedTradition {
    // Mock data - in a real app this would be calculated from actual data
    return 'Hindu';
  }

  /// Create from JSON
  factory UserStats.fromJson(Map<String, dynamic> json) {
    return UserStats(
      totalFavorites: json['totalFavorites'] ?? 0,
      totalVisits: json['totalVisits'] ?? 0,
      uniqueTemplesVisited: json['uniqueTemplesVisited'] ?? 0,
      darshanViewingMinutes: json['darshanViewingMinutes'] ?? 0,
      totalDonations: json['totalDonations'] ?? 0,
      totalDonationAmount: (json['totalDonationAmount'] ?? 0.0).toDouble(),
      eventsAttended: json['eventsAttended'] ?? 0,
      reviewsWritten: json['reviewsWritten'] ?? 0,
      lastVisitDate: json['lastVisitDate'] != null
          ? DateTime.parse(json['lastVisitDate'])
          : null,
      firstVisitDate: json['firstVisitDate'] != null
          ? DateTime.parse(json['firstVisitDate'])
          : null,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'totalFavorites': totalFavorites,
      'totalVisits': totalVisits,
      'uniqueTemplesVisited': uniqueTemplesVisited,
      'darshanViewingMinutes': darshanViewingMinutes,
      'totalDonations': totalDonations,
      'totalDonationAmount': totalDonationAmount,
      'eventsAttended': eventsAttended,
      'reviewsWritten': reviewsWritten,
      'lastVisitDate': lastVisitDate?.toIso8601String(),
      'firstVisitDate': firstVisitDate?.toIso8601String(),
    };
  }

  /// Create a copy with updated values
  UserStats copyWith({
    int? totalFavorites,
    int? totalVisits,
    int? uniqueTemplesVisited,
    int? darshanViewingMinutes,
    int? totalDonations,
    double? totalDonationAmount,
    int? eventsAttended,
    int? reviewsWritten,
    DateTime? lastVisitDate,
    DateTime? firstVisitDate,
    DateTime? updatedAt, // Add updatedAt parameter (ignored for now)
  }) {
    return UserStats(
      totalFavorites: totalFavorites ?? this.totalFavorites,
      totalVisits: totalVisits ?? this.totalVisits,
      uniqueTemplesVisited: uniqueTemplesVisited ?? this.uniqueTemplesVisited,
      darshanViewingMinutes:
          darshanViewingMinutes ?? this.darshanViewingMinutes,
      totalDonations: totalDonations ?? this.totalDonations,
      totalDonationAmount: totalDonationAmount ?? this.totalDonationAmount,
      eventsAttended: eventsAttended ?? this.eventsAttended,
      reviewsWritten: reviewsWritten ?? this.reviewsWritten,
      lastVisitDate: lastVisitDate ?? this.lastVisitDate,
      firstVisitDate: firstVisitDate ?? this.firstVisitDate,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserStats &&
        other.totalFavorites == totalFavorites &&
        other.totalVisits == totalVisits &&
        other.uniqueTemplesVisited == uniqueTemplesVisited &&
        other.darshanViewingMinutes == darshanViewingMinutes &&
        other.totalDonations == totalDonations &&
        other.totalDonationAmount == totalDonationAmount &&
        other.eventsAttended == eventsAttended &&
        other.reviewsWritten == reviewsWritten &&
        other.lastVisitDate == lastVisitDate &&
        other.firstVisitDate == firstVisitDate;
  }

  @override
  int get hashCode {
    return Object.hash(
      totalFavorites,
      totalVisits,
      uniqueTemplesVisited,
      darshanViewingMinutes,
      totalDonations,
      totalDonationAmount,
      eventsAttended,
      reviewsWritten,
      lastVisitDate,
      firstVisitDate,
    );
  }

  /// Create from Firestore document
  factory UserStats.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return UserStats.fromJson(data);
  }

  /// Create default stats for a user
  factory UserStats.defaultForUser(String userId) {
    return const UserStats();
  }

  @override
  String toString() {
    return 'UserStats(totalFavorites: $totalFavorites, totalVisits: $totalVisits, uniqueTemplesVisited: $uniqueTemplesVisited, darshanViewingMinutes: $darshanViewingMinutes, totalDonations: $totalDonations, totalDonationAmount: $totalDonationAmount, eventsAttended: $eventsAttended, reviewsWritten: $reviewsWritten, lastVisitDate: $lastVisitDate, firstVisitDate: $firstVisitDate)';
  }
}

/// Visit history item model
class VisitHistoryItem {
  final String templeId;
  final String templeName;
  final DateTime visitDate;
  final String? notes;
  final List<String> images;

  const VisitHistoryItem({
    required this.templeId,
    required this.templeName,
    required this.visitDate,
    this.notes,
    this.images = const [],
  });

  factory VisitHistoryItem.fromJson(Map<String, dynamic> json) {
    return VisitHistoryItem(
      templeId: json['templeId'] ?? '',
      templeName: json['templeName'] ?? '',
      visitDate: DateTime.parse(json['visitDate']),
      notes: json['notes'],
      images: List<String>.from(json['images'] ?? []),
    );
  }

  /// Create from Firestore document
  factory VisitHistoryItem.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return VisitHistoryItem(
      templeId: data['templeId'] ?? '',
      templeName: data['templeName'] ?? '',
      visitDate: data['visitDate'] is Timestamp
          ? (data['visitDate'] as Timestamp).toDate()
          : DateTime.parse(
              data['visitDate'] ?? DateTime.now().toIso8601String(),
            ),
      notes: data['notes'],
      images: List<String>.from(data['images'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'templeId': templeId,
      'templeName': templeName,
      'visitDate': visitDate.toIso8601String(),
      'notes': notes,
      'images': images,
    };
  }
}
