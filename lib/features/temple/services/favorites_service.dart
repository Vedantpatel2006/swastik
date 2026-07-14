import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../shared/services/interfaces/favorites_service_interface.dart';
import '../../../shared/services/offline/offline_manager.dart';
import '../../../shared/models/user_stats.dart';

/// Service for managing per-user favorites.
///
/// Storage strategy:
///   • Primary: Firestore  `users/{uid}/data/favorites`  (field: `templeIds`)
///   • Local cache: SharedPreferences key `user_favorites_{uid}`
///
/// The singleton resets its in-memory state whenever the Firebase Auth user
/// changes so that User B never sees User A's favorites.
class FavoritesService implements FavoritesServiceInterface {
  static final FavoritesService _instance = FavoritesService._internal();
  factory FavoritesService() => _instance;
  FavoritesService._internal() {
    // Listen for auth changes and reset state when the user switches.
    FirebaseAuth.instance.authStateChanges().listen(_onAuthStateChanged);
  }

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final OfflineManager _offlineManager = OfflineManager();

  SharedPreferences? _prefs;
  bool _initialized = false;

  // Tracks which userId the current cache belongs to.
  String? _cachedForUserId;

  // In-memory cache — only valid when _cachedForUserId == _currentUserId.
  List<String>? _cachedFavorites;

  // Stream controllers
  StreamController<List<String>> _favoritesController =
      StreamController<List<String>>.broadcast();

  // Constants
  static const String _favoritesKey = 'user_favorites';

  String? get _currentUserId => _auth.currentUser?.uid;

  // ---------------------------------------------------------------------------
  // Auth-change handler — clears stale cache when user switches
  // ---------------------------------------------------------------------------

  void _onAuthStateChanged(User? user) {
    final newUid = user?.uid;
    if (newUid != _cachedForUserId) {
      _cachedFavorites = null;
      _cachedForUserId = null;
      _initialized = false; // Force re-init for the new user
      if (!_favoritesController.isClosed) {
        _favoritesController.add([]);
      }
      if (kDebugMode) {
        debugPrint(
          'FavoritesService: Auth changed → cache cleared '
          '(new uid: $newUid)',
        );
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Initialization
  // ---------------------------------------------------------------------------

  /// Initialize the service for the currently signed-in user.
  Future<void> initialize() async {
    final userId = _currentUserId;

    // Already initialised for this exact user — nothing to do.
    if (_initialized && _cachedForUserId == userId) return;

    // Different user (or first run) — reset everything first.
    _cachedFavorites = null;
    _cachedForUserId = null;
    _initialized = false;

    try {
      _prefs = await SharedPreferences.getInstance();
      await _offlineManager.initialize();

      _initialized = true;
      _cachedForUserId = userId;
      await _loadCachedData();

      if (kDebugMode) {
        debugPrint('FavoritesService: Initialized for user $userId');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('FavoritesService: Error initializing - $e');
      }
      rethrow;
    }
  }

  void _ensureInitialized() {
    if (!_initialized || _prefs == null) {
      throw StateError(
        'FavoritesService not initialized. Call initialize() first.',
      );
    }
  }

  @override
  Future<void> addToFavorites(String templeId) async {
    _ensureInitialized();

    final userId = _currentUserId;
    if (userId == null) {
      throw StateError('No authenticated user found');
    }

    try {
      final favorites = await getFavoriteTempleIds();
      if (!favorites.contains(templeId)) {
        final updatedFavorites = [...favorites, templeId];

        // Update cache
        _cachedFavorites = updatedFavorites;

        // Persist locally
        await _saveFavoritesToLocal(updatedFavorites);

        // Persist to Firestore (per-user document)
        await _saveFavoritesToFirestore(userId, updatedFavorites);

        // Track activity
        await _trackUserActivity(
          userId: userId,
          type: 'favorite',
          data: {'templeId': templeId, 'action': 'added'},
        );

        // Update user stats
        await _updateUserStatsForFavorite(userId, templeId, true);

        // Notify listeners
        _favoritesController.add(updatedFavorites);

        if (kDebugMode) {
          debugPrint('FavoritesService: Added temple $templeId to favorites');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('FavoritesService: Error adding to favorites - $e');
      }
      rethrow;
    }
  }

  @override
  Future<void> removeFromFavorites(String templeId) async {
    _ensureInitialized();

    final userId = _currentUserId;
    if (userId == null) {
      throw StateError('No authenticated user found');
    }

    try {
      final favorites = await getFavoriteTempleIds();
      if (favorites.contains(templeId)) {
        final updatedFavorites = favorites
            .where((id) => id != templeId)
            .toList();

        // Update cache
        _cachedFavorites = updatedFavorites;

        // Persist locally
        await _saveFavoritesToLocal(updatedFavorites);

        // Persist to Firestore
        await _saveFavoritesToFirestore(userId, updatedFavorites);

        // Track activity
        await _trackUserActivity(
          userId: userId,
          type: 'favorite',
          data: {'templeId': templeId, 'action': 'removed'},
        );

        // Update user stats
        await _updateUserStatsForFavorite(userId, templeId, false);

        // Notify listeners
        _favoritesController.add(updatedFavorites);

        if (kDebugMode) {
          debugPrint(
            'FavoritesService: Removed temple $templeId from favorites',
          );
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('FavoritesService: Error removing from favorites - $e');
      }
      rethrow;
    }
  }

  @override
  Future<List<String>> getFavoriteTempleIds() async {
    _ensureInitialized();

    final userId = _currentUserId;

    // Return in-memory cache if it belongs to the current user.
    if (_cachedFavorites != null && _cachedForUserId == userId) {
      return _cachedFavorites!;
    }

    if (userId == null) return [];

    try {
      // 1. Try Firestore first (source of truth across devices).
      final firestoreIds = await _loadFavoritesFromFirestore(userId);
      if (firestoreIds != null) {
        _cachedFavorites = firestoreIds;
        _cachedForUserId = userId;
        // Keep local cache in sync.
        await _saveFavoritesToLocal(firestoreIds);
        return firestoreIds;
      }

      // 2. Fall back to local SharedPreferences (offline / first load).
      final localIds = await _loadFavoritesFromLocal();
      _cachedFavorites = localIds;
      _cachedForUserId = userId;
      return localIds;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('FavoritesService: Error getting favorites - $e');
      }
      return [];
    }
  }

  @override
  Future<bool> isFavorite(String templeId) async {
    final favorites = await getFavoriteTempleIds();
    return favorites.contains(templeId);
  }

  @override
  Future<void> clearAllFavorites() async {
    _ensureInitialized();

    final userId = _currentUserId;
    if (userId == null) {
      throw StateError('No authenticated user found');
    }

    try {
      _cachedFavorites = [];

      await _saveFavoritesToLocal([]);
      await _saveFavoritesToFirestore(userId, []);

      _favoritesController.add([]);

      if (kDebugMode) {
        debugPrint('FavoritesService: Cleared all favorites');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('FavoritesService: Error clearing favorites - $e');
      }
      rethrow;
    }
  }

  @override
  Stream<List<String>> watchFavorites() {
    _ensureInitialized();

    // Recreate controller if it was previously closed
    if (_favoritesController.isClosed) {
      _favoritesController = StreamController<List<String>>.broadcast();
    }

    // Emit current data immediately so the listener gets an initial value
    getFavoriteTempleIds().then((favorites) {
      if (!_favoritesController.isClosed) {
        _favoritesController.add(favorites);
      }
    });

    return _favoritesController.stream;
  }

  @override
  Future<Map<String, dynamic>> exportUserData() async {
    final favorites = await getFavoriteTempleIds();

    return {
      'favorites': favorites,
      'exportedAt': DateTime.now().toIso8601String(),
    };
  }

  @override
  Future<void> importUserData(Map<String, dynamic> userData) async {
    _ensureInitialized();

    try {
      if (userData.containsKey('favorites')) {
        final favorites = List<String>.from(userData['favorites'] as List);

        // Update cache
        _cachedFavorites = favorites;

        // Save to local storage
        await _saveFavoritesToLocal(favorites);

        // Notify listeners
        _favoritesController.add(favorites);
      }

      if (kDebugMode) {
        debugPrint('FavoritesService: Imported user data successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('FavoritesService: Error importing user data - $e');
      }
      rethrow;
    }
  }

  @override
  Future<void> forceSyncAll() async {
    _ensureInitialized();

    try {
      await _offlineManager.forceSyncAll();

      // Reload from Firestore
      _cachedFavorites = null;
      await getFavoriteTempleIds();

      if (kDebugMode) {
        debugPrint('FavoritesService: Force sync completed');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('FavoritesService: Error during force sync - $e');
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Local + Firestore helpers
  // ---------------------------------------------------------------------------

  /// Load cached data on init.
  Future<void> _loadCachedData() async {
    try {
      await getFavoriteTempleIds();
      if (kDebugMode) {
        debugPrint('FavoritesService: Loaded cached data');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('FavoritesService: Error loading cached data - $e');
      }
    }
  }

  /// Read favorites list from Firestore for [userId].
  /// Returns `null` if the document doesn't exist yet.
  Future<List<String>?> _loadFavoritesFromFirestore(String userId) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('data')
          .doc('favorites')
          .get();

      if (!doc.exists) return null;

      final raw = doc.data()?['templeIds'];
      if (raw == null) return [];
      return List<String>.from(raw as List);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('FavoritesService: Firestore read failed - $e');
      }
      return null; // Fall back to local
    }
  }

  /// Write [favorites] to Firestore for [userId].
  Future<void> _saveFavoritesToFirestore(
    String userId,
    List<String> favorites,
  ) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('data')
          .doc('favorites')
          .set({
            'templeIds': favorites,
            'updatedAt': FieldValue.serverTimestamp(),
          });
    } catch (e) {
      if (kDebugMode) {
        debugPrint('FavoritesService: Firestore write failed - $e');
      }
      // Non-fatal — local cache is still updated.
    }
  }

  /// Read favorites from SharedPreferences for the current user.
  Future<List<String>> _loadFavoritesFromLocal() async {
    try {
      final key = _getCacheKey(_favoritesKey);
      final json = _prefs!.getString(key);
      if (json == null) return [];
      return List<String>.from(jsonDecode(json) as List);
    } catch (_) {
      return [];
    }
  }

  /// Write [favorites] to SharedPreferences for the current user.
  Future<void> _saveFavoritesToLocal(List<String> favorites) async {
    final key = _getCacheKey(_favoritesKey);
    await _prefs!.setString(key, jsonEncode(favorites));
  }

  /// User-scoped SharedPreferences key.
  String _getCacheKey(String baseKey) {
    final userId = _currentUserId ?? 'anonymous';
    return '${baseKey}_$userId';
  }

  /// Get user statistics - Real Firebase data
  Future<UserStats> getUserStats() async {
    _ensureInitialized();

    final userId = _currentUserId;
    if (userId == null) {
      throw StateError('No authenticated user found');
    }

    try {
      // Get real user stats from Firebase
      final userStatsDoc = await _firestore
          .collection('user_stats')
          .doc(userId)
          .get();

      if (userStatsDoc.exists) {
        return UserStats.fromFirestore(userStatsDoc);
      } else {
        // Create default stats if none exist
        final favorites = await getFavoriteTempleIds();
        final defaultStats = UserStats(
          totalFavorites: favorites.length,
          totalVisits: 0,
          uniqueTemplesVisited: 0,
          darshanViewingMinutes: 0,
          totalDonations: 0,
          totalDonationAmount: 0.0,
          eventsAttended: 0,
          reviewsWritten: 0,
          lastVisitDate: null,
          firstVisitDate: null,
        );

        // Save default stats to Firebase
        await _firestore
            .collection('user_stats')
            .doc(userId)
            .set(defaultStats.toJson());

        return defaultStats;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('FavoritesService: Error getting user stats - $e');
      }
      rethrow;
    }
  }

  /// Watch user statistics - Real Firebase stream
  Stream<UserStats> watchUserStats() {
    _ensureInitialized();

    final userId = _currentUserId;
    if (userId == null) {
      throw StateError('No authenticated user found');
    }

    return _firestore.collection('user_stats').doc(userId).snapshots().asyncMap(
      (doc) async {
        if (doc.exists) {
          return UserStats.fromFirestore(doc);
        } else {
          // Create and return default stats
          final stats = await getUserStats();
          return stats;
        }
      },
    );
  }

  /// Get visit history - Real Firebase data
  Future<List<VisitHistoryItem>> getVisitHistory() async {
    _ensureInitialized();

    final userId = _currentUserId;
    if (userId == null) {
      throw StateError('No authenticated user found');
    }

    try {
      final querySnapshot = await _firestore
          .collection('temple_visits')
          .where('userId', isEqualTo: userId)
          .orderBy('visitDate', descending: true)
          .limit(10)
          .get();

      return querySnapshot.docs
          .map((doc) => VisitHistoryItem.fromFirestore(doc))
          .toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('FavoritesService: Error getting visit history - $e');
      }
      return [];
    }
  }

  /// Watch user activity stream - Real Firebase data
  Stream<List<Map<String, dynamic>>> watchUserActivity(String userId) {
    return _firestore
        .collection('user_activities')
        .where('userId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .limit(10)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => {
                  'id': doc.id,
                  'type': doc.data()['type'] as String,
                  'timestamp': (doc.data()['timestamp'] as Timestamp)
                      .toDate()
                      .toIso8601String(),
                  'data': doc.data()['data'] as Map<String, dynamic>,
                },
              )
              .toList(),
        );
  }

  /// Watch unread notifications count - Real Firebase data
  Stream<int> watchUnreadNotifications(String userId) {
    return _firestore
        .collection('user_notifications')
        .where('userId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  /// Watch visit history stream - Real Firebase data
  Stream<List<VisitHistoryItem>> watchVisitHistory() {
    _ensureInitialized();

    final userId = _currentUserId;
    if (userId == null) {
      throw StateError('No authenticated user found');
    }

    return _firestore
        .collection('temple_visits')
        .where('userId', isEqualTo: userId)
        .orderBy('visitDate', descending: true)
        .limit(10)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => VisitHistoryItem.fromFirestore(doc))
              .toList(),
        );
  }

  /// Dispose resources
  void dispose() {
    // Do NOT close _favoritesController — this is a singleton service shared
    // across the app. Closing it permanently kills the broadcast stream for
    // all current and future listeners. Individual screens should just cancel
    // their own StreamSubscription in their own dispose().
  }

  /// Track user activity in Firebase
  Future<void> _trackUserActivity({
    required String userId,
    required String type,
    required Map<String, dynamic> data,
  }) async {
    try {
      await _firestore.collection('user_activities').add({
        'userId': userId,
        'type': type,
        'data': data,
        'timestamp': Timestamp.fromDate(DateTime.now()),
        'createdAt': Timestamp.fromDate(DateTime.now()),
      });
    } catch (e) {
      if (kDebugMode) {
        debugPrint('FavoritesService: Error tracking activity - $e');
      }
      // Don't throw error for activity tracking failures
    }
  }

  /// Update user stats for favorite changes
  Future<void> _updateUserStatsForFavorite(
    String userId,
    String templeId,
    bool isAdding,
  ) async {
    try {
      final userStatsRef = _firestore.collection('user_stats').doc(userId);

      await _firestore.runTransaction((transaction) async {
        final userStatsDoc = await transaction.get(userStatsRef);

        UserStats userStats;
        if (userStatsDoc.exists) {
          userStats = UserStats.fromFirestore(userStatsDoc);
        } else {
          userStats = UserStats(
            totalFavorites: 0,
            totalVisits: 0,
            uniqueTemplesVisited: 0,
            darshanViewingMinutes: 0,
            totalDonations: 0,
            totalDonationAmount: 0.0,
            eventsAttended: 0,
            reviewsWritten: 0,
            lastVisitDate: null,
            firstVisitDate: null,
          );
        }

        final updatedStats = userStats.copyWith(
          totalFavorites: isAdding
              ? userStats.totalFavorites + 1
              : (userStats.totalFavorites - 1)
                    .clamp(0, double.infinity)
                    .toInt(),
          updatedAt: DateTime.now(),
        );

        transaction.set(userStatsRef, updatedStats.toJson());
      });
    } catch (e) {
      if (kDebugMode) {
        debugPrint('FavoritesService: Error updating user stats - $e');
      }
      // Don't throw error for stats update failures
    }
  }

  /// Track temple visit
  Future<void> trackTempleVisit({
    required String templeId,
    required String templeName,
    String? notes,
    int? darshanMinutes,
  }) async {
    _ensureInitialized();

    final userId = _currentUserId;
    if (userId == null) {
      throw StateError('No authenticated user found');
    }

    try {
      final visitData = {
        'userId': userId,
        'templeId': templeId,
        'templeName': templeName,
        'visitDate': Timestamp.fromDate(DateTime.now()),
        'notes': notes ?? '',
        'darshanMinutes': darshanMinutes ?? 0,
        'createdAt': Timestamp.fromDate(DateTime.now()),
      };

      // Add to temple visits collection
      await _firestore.collection('temple_visits').add(visitData);

      // Track activity
      await _trackUserActivity(
        userId: userId,
        type: 'temple_visit',
        data: {
          'templeId': templeId,
          'templeName': templeName,
          'darshanMinutes': darshanMinutes ?? 0,
        },
      );

      // Update user stats
      await _updateUserStatsForVisit(userId, templeId, darshanMinutes ?? 0);

      if (kDebugMode) {
        debugPrint('FavoritesService: Tracked temple visit for $templeName');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('FavoritesService: Error tracking temple visit - $e');
      }
      rethrow;
    }
  }

  /// Update user stats for temple visit
  Future<void> _updateUserStatsForVisit(
    String userId,
    String templeId,
    int darshanMinutes,
  ) async {
    try {
      final userStatsRef = _firestore.collection('user_stats').doc(userId);

      await _firestore.runTransaction((transaction) async {
        final userStatsDoc = await transaction.get(userStatsRef);

        UserStats userStats;
        if (userStatsDoc.exists) {
          userStats = UserStats.fromFirestore(userStatsDoc);
        } else {
          userStats = UserStats(
            totalFavorites: 0,
            totalVisits: 0,
            uniqueTemplesVisited: 0,
            darshanViewingMinutes: 0,
            totalDonations: 0,
            totalDonationAmount: 0.0,
            eventsAttended: 0,
            reviewsWritten: 0,
            lastVisitDate: null,
            firstVisitDate: null,
          );
        }

        // Check if this is a new temple for the user
        final visitedTemplesQuery = await _firestore
            .collection('temple_visits')
            .where('userId', isEqualTo: userId)
            .where('templeId', isEqualTo: templeId)
            .limit(1)
            .get();

        final isNewTemple =
            visitedTemplesQuery.docs.length == 1; // First visit to this temple

        final updatedStats = userStats.copyWith(
          totalVisits: userStats.totalVisits + 1,
          uniqueTemplesVisited: isNewTemple
              ? userStats.uniqueTemplesVisited + 1
              : userStats.uniqueTemplesVisited,
          darshanViewingMinutes:
              userStats.darshanViewingMinutes + darshanMinutes,
          lastVisitDate: DateTime.now(),
          firstVisitDate: userStats.firstVisitDate ?? DateTime.now(),
          updatedAt: DateTime.now(),
        );

        transaction.set(userStatsRef, updatedStats.toJson());
      });
    } catch (e) {
      if (kDebugMode) {
        debugPrint('FavoritesService: Error updating visit stats - $e');
      }
    }
  }

  /// Track event attendance
  Future<void> trackEventAttendance({
    required String eventId,
    required String eventName,
    required String templeId,
  }) async {
    _ensureInitialized();

    final userId = _currentUserId;
    if (userId == null) {
      throw StateError('No authenticated user found');
    }

    try {
      // Track activity
      await _trackUserActivity(
        userId: userId,
        type: 'event_attendance',
        data: {
          'eventId': eventId,
          'eventName': eventName,
          'templeId': templeId,
        },
      );

      // Update user stats
      await _updateUserStatsForEvent(userId);

      if (kDebugMode) {
        debugPrint('FavoritesService: Tracked event attendance for $eventName');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('FavoritesService: Error tracking event attendance - $e');
      }
      rethrow;
    }
  }

  /// Update user stats for event attendance
  Future<void> _updateUserStatsForEvent(String userId) async {
    try {
      final userStatsRef = _firestore.collection('user_stats').doc(userId);

      await _firestore.runTransaction((transaction) async {
        final userStatsDoc = await transaction.get(userStatsRef);

        UserStats userStats;
        if (userStatsDoc.exists) {
          userStats = UserStats.fromFirestore(userStatsDoc);
        } else {
          userStats = UserStats(
            totalFavorites: 0,
            totalVisits: 0,
            uniqueTemplesVisited: 0,
            darshanViewingMinutes: 0,
            totalDonations: 0,
            totalDonationAmount: 0.0,
            eventsAttended: 0,
            reviewsWritten: 0,
            lastVisitDate: null,
            firstVisitDate: null,
          );
        }

        final updatedStats = userStats.copyWith(
          eventsAttended: userStats.eventsAttended + 1,
          updatedAt: DateTime.now(),
        );

        transaction.set(userStatsRef, updatedStats.toJson());
      });
    } catch (e) {
      if (kDebugMode) {
        debugPrint('FavoritesService: Error updating event stats - $e');
      }
    }
  }

  /// Track review submission
  Future<void> trackReviewSubmission({
    required String reviewId,
    required String templeId,
    required double rating,
  }) async {
    _ensureInitialized();

    final userId = _currentUserId;
    if (userId == null) {
      throw StateError('No authenticated user found');
    }

    try {
      // Track activity
      await _trackUserActivity(
        userId: userId,
        type: 'review_submission',
        data: {'reviewId': reviewId, 'templeId': templeId, 'rating': rating},
      );

      // Update user stats
      await _updateUserStatsForReview(userId);

      if (kDebugMode) {
        debugPrint('FavoritesService: Tracked review submission');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('FavoritesService: Error tracking review submission - $e');
      }
      rethrow;
    }
  }

  /// Update user stats for review submission
  Future<void> _updateUserStatsForReview(String userId) async {
    try {
      final userStatsRef = _firestore.collection('user_stats').doc(userId);

      await _firestore.runTransaction((transaction) async {
        final userStatsDoc = await transaction.get(userStatsRef);

        UserStats userStats;
        if (userStatsDoc.exists) {
          userStats = UserStats.fromFirestore(userStatsDoc);
        } else {
          userStats = UserStats(
            totalFavorites: 0,
            totalVisits: 0,
            uniqueTemplesVisited: 0,
            darshanViewingMinutes: 0,
            totalDonations: 0,
            totalDonationAmount: 0.0,
            eventsAttended: 0,
            reviewsWritten: 0,
            lastVisitDate: null,
            firstVisitDate: null,
          );
        }

        final updatedStats = userStats.copyWith(
          reviewsWritten: userStats.reviewsWritten + 1,
          updatedAt: DateTime.now(),
        );

        transaction.set(userStatsRef, updatedStats.toJson());
      });
    } catch (e) {
      if (kDebugMode) {
        debugPrint('FavoritesService: Error updating review stats - $e');
      }
    }
  }

  /// Create notification
  Future<void> createNotification({
    required String userId,
    required String title,
    required String message,
    required String type,
    Map<String, dynamic>? data,
  }) async {
    try {
      await _firestore.collection('user_notifications').add({
        'userId': userId,
        'title': title,
        'message': message,
        'type': type,
        'data': data ?? {},
        'isRead': false,
        'createdAt': Timestamp.fromDate(DateTime.now()),
      });
    } catch (e) {
      if (kDebugMode) {
        debugPrint('FavoritesService: Error creating notification - $e');
      }
    }
  }

  /// Mark notification as read
  Future<void> markNotificationAsRead(String notificationId) async {
    try {
      await _firestore
          .collection('user_notifications')
          .doc(notificationId)
          .update({
            'isRead': true,
            'readAt': Timestamp.fromDate(DateTime.now()),
          });
    } catch (e) {
      if (kDebugMode) {
        debugPrint('FavoritesService: Error marking notification as read - $e');
      }
    }
  }
}
