import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/user_stats.dart';

/// Service for managing user statistics and activity tracking
class UserStatsService {
  static final UserStatsService _instance = UserStatsService._internal();
  factory UserStatsService() => _instance;
  UserStatsService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _userStatsCollection = 'user_stats';
  static const String _visitHistoryCollection = 'visit_history';

  /// Get user statistics
  Future<UserStats> getUserStats(String userId) async {
    try {
      final doc = await _firestore
          .collection(_userStatsCollection)
          .doc(userId)
          .get();

      if (doc.exists) {
        return UserStats.fromFirestore(doc);
      } else {
        // Create default stats for new user
        final defaultStats = UserStats.defaultForUser(userId);
        await _createUserStats(userId, defaultStats);
        return defaultStats;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('UserStatsService: Error getting user stats - $e');
      }
      return UserStats.defaultForUser(userId);
    }
  }

  /// Get user statistics stream
  Stream<UserStats> watchUserStats(String userId) {
    return _firestore
        .collection(_userStatsCollection)
        .doc(userId)
        .snapshots()
        .map((doc) {
          if (doc.exists) {
            return UserStats.fromFirestore(doc);
          } else {
            return UserStats.defaultForUser(userId);
          }
        });
  }

  /// Create initial user stats
  Future<void> _createUserStats(String userId, UserStats stats) async {
    try {
      await _firestore
          .collection(_userStatsCollection)
          .doc(userId)
          .set(stats.toJson());

      if (kDebugMode) {
        debugPrint('UserStatsService: Created stats for user $userId');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('UserStatsService: Error creating user stats - $e');
      }
    }
  }

  /// Update user statistics
  Future<void> updateUserStats(String userId, UserStats stats) async {
    try {
      await _firestore
          .collection(_userStatsCollection)
          .doc(userId)
          .set(stats.toJson(), SetOptions(merge: true));

      if (kDebugMode) {
        debugPrint('UserStatsService: Updated stats for user $userId');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('UserStatsService: Error updating user stats - $e');
      }
      rethrow;
    }
  }

  /// Increment favorite count
  Future<void> incrementFavorites(String userId) async {
    try {
      await _firestore
          .collection(_userStatsCollection)
          .doc(userId)
          .update({
        'totalFavorites': FieldValue.increment(1),
      });

      if (kDebugMode) {
        debugPrint('UserStatsService: Incremented favorites for user $userId');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('UserStatsService: Error incrementing favorites - $e');
      }
    }
  }

  /// Decrement favorite count
  Future<void> decrementFavorites(String userId) async {
    try {
      await _firestore
          .collection(_userStatsCollection)
          .doc(userId)
          .update({
        'totalFavorites': FieldValue.increment(-1),
      });

      if (kDebugMode) {
        debugPrint('UserStatsService: Decremented favorites for user $userId');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('UserStatsService: Error decrementing favorites - $e');
      }
    }
  }

  /// Record temple visit
  Future<void> recordTempleVisit({
    required String userId,
    required String templeId,
    required String templeName,
    String? notes,
    List<String> images = const [],
  }) async {
    try {
      final visitTime = DateTime.now();
      
      // Add to visit history
      await _firestore
          .collection(_visitHistoryCollection)
          .add({
        'userId': userId,
        'templeId': templeId,
        'templeName': templeName,
        'visitDate': Timestamp.fromDate(visitTime),
        'notes': notes,
        'images': images,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Update user stats
      final currentStats = await getUserStats(userId);
      final updatedStats = currentStats.copyWith(
        totalVisits: currentStats.totalVisits + 1,
        lastVisitDate: visitTime,
        firstVisitDate: currentStats.firstVisitDate ?? visitTime,
      );

      await updateUserStats(userId, updatedStats);

      if (kDebugMode) {
        debugPrint('UserStatsService: Recorded visit to $templeName for user $userId');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('UserStatsService: Error recording temple visit - $e');
      }
      rethrow;
    }
  }

  /// Record darshan viewing time
  Future<void> recordDarshanViewing({
    required String userId,
    required String templeId,
    required int viewingMinutes,
  }) async {
    try {
      await _firestore
          .collection(_userStatsCollection)
          .doc(userId)
          .update({
        'darshanViewingMinutes': FieldValue.increment(viewingMinutes),
      });

      if (kDebugMode) {
        debugPrint('UserStatsService: Recorded $viewingMinutes minutes of darshan viewing for user $userId');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('UserStatsService: Error recording darshan viewing - $e');
      }
    }
  }

  /// Record donation
  Future<void> recordDonation({
    required String userId,
    required double amount,
  }) async {
    try {
      await _firestore
          .collection(_userStatsCollection)
          .doc(userId)
          .update({
        'totalDonations': FieldValue.increment(1),
        'totalDonationAmount': FieldValue.increment(amount),
      });

      if (kDebugMode) {
        debugPrint('UserStatsService: Recorded donation of ₹$amount for user $userId');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('UserStatsService: Error recording donation - $e');
      }
    }
  }

  /// Record event attendance
  Future<void> recordEventAttendance(String userId) async {
    try {
      await _firestore
          .collection(_userStatsCollection)
          .doc(userId)
          .update({
        'eventsAttended': FieldValue.increment(1),
      });

      if (kDebugMode) {
        debugPrint('UserStatsService: Recorded event attendance for user $userId');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('UserStatsService: Error recording event attendance - $e');
      }
    }
  }

  /// Record review written
  Future<void> recordReviewWritten(String userId) async {
    try {
      await _firestore
          .collection(_userStatsCollection)
          .doc(userId)
          .update({
        'reviewsWritten': FieldValue.increment(1),
      });

      if (kDebugMode) {
        debugPrint('UserStatsService: Recorded review written for user $userId');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('UserStatsService: Error recording review - $e');
      }
    }
  }

  /// Get visit history for user
  Future<List<VisitHistoryItem>> getVisitHistory(String userId, {int limit = 50}) async {
    try {
      final querySnapshot = await _firestore
          .collection(_visitHistoryCollection)
          .where('userId', isEqualTo: userId)
          .orderBy('visitDate', descending: true)
          .limit(limit)
          .get();

      return querySnapshot.docs
          .map((doc) => VisitHistoryItem.fromFirestore(doc))
          .toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('UserStatsService: Error getting visit history - $e');
      }
      return [];
    }
  }

  /// Get visit history stream
  Stream<List<VisitHistoryItem>> watchVisitHistory(String userId, {int limit = 50}) {
    return _firestore
        .collection(_visitHistoryCollection)
        .where('userId', isEqualTo: userId)
        .orderBy('visitDate', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => VisitHistoryItem.fromFirestore(doc))
            .toList());
  }

  /// Get user leaderboard position (mock implementation)
  Future<Map<String, dynamic>> getUserLeaderboardPosition(String userId) async {
    try {
      // Mock leaderboard data - in production, this would query actual rankings
      return {
        'totalVisitsRank': 42,
        'donationAmountRank': 28,
        'darshanTimeRank': 15,
        'totalUsers': 1000,
        'percentile': 85.0,
      };
    } catch (e) {
      if (kDebugMode) {
        debugPrint('UserStatsService: Error getting leaderboard position - $e');
      }
      return {
        'totalVisitsRank': 0,
        'donationAmountRank': 0,
        'darshanTimeRank': 0,
        'totalUsers': 0,
        'percentile': 0.0,
      };
    }
  }

  /// Reset user statistics (for testing or user request)
  Future<void> resetUserStats(String userId) async {
    try {
      final defaultStats = UserStats.defaultForUser(userId);
      await updateUserStats(userId, defaultStats);

      // Also clear visit history
      final visitHistory = await _firestore
          .collection(_visitHistoryCollection)
          .where('userId', isEqualTo: userId)
          .get();

      final batch = _firestore.batch();
      for (final doc in visitHistory.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      if (kDebugMode) {
        debugPrint('UserStatsService: Reset stats for user $userId');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('UserStatsService: Error resetting user stats - $e');
      }
      rethrow;
    }
  }
}