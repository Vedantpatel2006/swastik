import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../shared/models/user_preferences.dart';
import '../../../shared/services/interfaces/user_preferences_service_interface.dart';
import '../../../shared/services/offline/offline_manager.dart';

/// Service for managing user preferences with local storage and Firebase sync
class UserPreferencesService implements UserPreferencesServiceInterface {
  static final UserPreferencesService _instance =
      UserPreferencesService._internal();
  factory UserPreferencesService() => _instance;
  UserPreferencesService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final OfflineManager _offlineManager = OfflineManager();

  SharedPreferences? _prefs;
  UserPreferences? _cachedPreferences;
  StreamController<UserPreferences>? _preferencesController;

  // For testing purposes
  String? _testUserId;

  static const String _prefsKeyPrefix = 'user_preferences';
  static const String _firestoreCollection = 'user_preferences';

  // Available options
  static const List<String> _availableThemes = ['light', 'dark', 'auto'];
  static const List<String> _availableLanguages = ['en', 'hi'];

  bool _initialized = false;

  /// Initialize the service
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      _prefs = await SharedPreferences.getInstance();
      await _offlineManager.initialize();
      _preferencesController = StreamController<UserPreferences>.broadcast();
      _initialized = true;

      // Set up offline sync listeners
      _offlineManager.syncStatusStream.listen((status) {
        if (status == SyncStatus.synced) {
          // Refresh cached preferences after sync
          _cachedPreferences = null;
        }
      });

      if (kDebugMode) {
        debugPrint('UserPreferencesService: Initialized successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('UserPreferencesService: Error initializing - $e');
      }
      rethrow;
    }
  }

  /// Get current user ID
  String? get _currentUserId => _testUserId ?? _auth.currentUser?.uid;

  /// Set test user ID (for testing only)
  void setTestUserId(String? userId) {
    _testUserId = userId;
  }

  /// Ensure service is initialized
  void _ensureInitialized() {
    if (!_initialized || _prefs == null) {
      throw StateError(
        'UserPreferencesService not initialized. Call initialize() first.',
      );
    }
  }

  /// Generate preferences key for current user
  String _getPreferencesKey([String? userId]) {
    final uid = userId ?? _currentUserId;
    if (uid == null) {
      throw StateError('No authenticated user found');
    }
    return '${_prefsKeyPrefix}_$uid';
  }

  @override
  Future<UserPreferences> getUserPreferences() async {
    _ensureInitialized();

    final userId = _currentUserId;
    if (userId == null) {
      throw StateError('No authenticated user found');
    }

    return await getUserPreferencesById(userId);
  }

  @override
  Future<UserPreferences> getUserPreferencesById(String userId) async {
    _ensureInitialized();

    try {
      // Check cache first
      if (_cachedPreferences != null && _cachedPreferences!.userId == userId) {
        return _cachedPreferences!;
      }

      // Try to load from local storage
      final prefsKey = _getPreferencesKey(userId);
      final prefsJson = _prefs!.getString(prefsKey);

      UserPreferences preferences;

      if (prefsJson != null) {
        // Load from local storage
        final prefsData = jsonDecode(prefsJson) as Map<String, dynamic>;
        preferences = UserPreferences.fromJson(prefsData);

        if (kDebugMode) {
          debugPrint(
            'UserPreferencesService: Loaded preferences from local storage for user $userId',
          );
        }
      } else {
        // Create default preferences
        preferences = UserPreferences.defaultForUser(userId);

        // Save default preferences to local storage
        await _saveToLocalStorage(preferences);

        if (kDebugMode) {
          debugPrint(
            'UserPreferencesService: Created default preferences for user $userId',
          );
        }
      }

      // Cache the preferences
      _cachedPreferences = preferences;

      // Try to sync with Firebase in the background (don't await)
      _syncWithFirebase(preferences);

      return preferences;
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          'UserPreferencesService: Error getting user preferences - $e',
        );
      }

      // Return default preferences as fallback
      final defaultPrefs = UserPreferences.defaultForUser(userId);
      _cachedPreferences = defaultPrefs;
      return defaultPrefs;
    }
  }

  @override
  Future<void> updatePreferences(UserPreferences preferences) async {
    _ensureInitialized();

    try {
      // Validate preferences
      if (!preferences.isValid()) {
        throw ArgumentError('Invalid preferences provided');
      }

      // Update timestamp
      final updatedPreferences = preferences.copyWith(
        updatedAt: DateTime.now(),
      );

      // Save to local storage
      await _saveToLocalStorage(updatedPreferences);

      // Store offline for sync
      await _offlineManager.storeOfflineData(
        id: updatedPreferences.userId,
        collection: _firestoreCollection,
        data: updatedPreferences.toJson(),
        operation: OfflineOperationType.update,
      );

      // Update cache
      _cachedPreferences = updatedPreferences;

      // Notify listeners
      _preferencesController?.add(updatedPreferences);

      if (kDebugMode) {
        debugPrint(
          'UserPreferencesService: Updated preferences for user ${preferences.userId}',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('UserPreferencesService: Error updating preferences - $e');
      }
      rethrow;
    }
  }

  @override
  Future<void> setLocationRadius(double radius) async {
    final currentPrefs = await getUserPreferences();
    final updatedPrefs = currentPrefs.updateLocationRadius(radius);
    await updatePreferences(updatedPrefs);
  }

  @override
  Future<void> setSpiritualTraditions(List<String> traditions) async {
    final currentPrefs = await getUserPreferences();
    final updatedPrefs = currentPrefs.copyWith(
      preferredTraditions: traditions,
      updatedAt: DateTime.now(),
    );
    await updatePreferences(updatedPrefs);
  }

  @override
  Future<void> addSpiritualTradition(String tradition) async {
    final currentPrefs = await getUserPreferences();
    final updatedPrefs = currentPrefs.addPreferredTradition(tradition);
    await updatePreferences(updatedPrefs);
  }

  @override
  Future<void> removeSpiritualTradition(String tradition) async {
    final currentPrefs = await getUserPreferences();
    final updatedPrefs = currentPrefs.removePreferredTradition(tradition);
    await updatePreferences(updatedPrefs);
  }

  @override
  Future<void> setLocationServicesEnabled(bool enabled) async {
    final currentPrefs = await getUserPreferences();
    final updatedPrefs = currentPrefs.copyWith(
      enableLocationServices: enabled,
      updatedAt: DateTime.now(),
    );
    await updatePreferences(updatedPrefs);
  }

  @override
  Future<void> setNotificationsEnabled(bool enabled) async {
    final currentPrefs = await getUserPreferences();
    final updatedPrefs = currentPrefs.copyWith(
      enableNotifications: enabled,
      updatedAt: DateTime.now(),
    );
    await updatePreferences(updatedPrefs);
  }

  @override
  Future<void> setTheme(String theme) async {
    final currentPrefs = await getUserPreferences();
    final updatedPrefs = currentPrefs.updateTheme(theme);
    await updatePreferences(updatedPrefs);
  }

  @override
  Future<void> setLanguage(String language) async {
    final currentPrefs = await getUserPreferences();
    final updatedPrefs = currentPrefs.updateLanguage(language);
    await updatePreferences(updatedPrefs);
  }

  @override
  Future<String> getUserLocation() async {
    final currentPrefs = await getUserPreferences();
    return currentPrefs.savedLocation ?? 'Select Location';
  }

  @override
  Future<void> setUserLocation(String location) async {
    final currentPrefs = await getUserPreferences();
    final updatedPrefs = currentPrefs.copyWith(
      savedLocation: location,
      updatedAt: DateTime.now(),
    );
    await updatePreferences(updatedPrefs);
  }

  @override
  Future<void> setCustomSetting(String key, dynamic value) async {
    final currentPrefs = await getUserPreferences();
    final updatedPrefs = currentPrefs.updateCustomSetting(key, value);
    await updatePreferences(updatedPrefs);
  }

  @override
  Future<void> removeCustomSetting(String key) async {
    final currentPrefs = await getUserPreferences();
    final updatedPrefs = currentPrefs.removeCustomSetting(key);
    await updatePreferences(updatedPrefs);
  }

  @override
  Future<T?> getCustomSetting<T>(String key) async {
    final currentPrefs = await getUserPreferences();
    return currentPrefs.getCustomSetting<T>(key);
  }

  @override
  Stream<UserPreferences> watchPreferences() {
    _ensureInitialized();

    final userId = _currentUserId;
    if (userId == null) {
      throw StateError('No authenticated user found');
    }

    return watchPreferencesById(userId);
  }

  @override
  Stream<UserPreferences> watchPreferencesById(String userId) {
    _ensureInitialized();

    // Create a stream controller for this specific user
    late StreamController<UserPreferences> controller;
    controller = StreamController<UserPreferences>(
      onListen: () async {
        // Emit initial preferences
        try {
          final initialPrefs = await getUserPreferencesById(userId);
          if (!controller.isClosed) {
            controller.add(initialPrefs);
          }
        } catch (e) {
          if (!controller.isClosed) {
            controller.addError(e);
          }
        }

        // Listen to updates
        final subscription = _preferencesController!.stream
            .where((prefs) => prefs.userId == userId)
            .listen(
              (prefs) {
                if (!controller.isClosed) {
                  controller.add(prefs);
                }
              },
              onError: (error) {
                if (!controller.isClosed) {
                  controller.addError(error);
                }
              },
            );

        // Clean up when stream is cancelled
        controller.onCancel = () {
          subscription.cancel();
        };
      },
    );

    return controller.stream;
  }

  @override
  Future<void> resetToDefaults() async {
    final userId = _currentUserId;
    if (userId == null) {
      throw StateError('No authenticated user found');
    }

    final defaultPrefs = UserPreferences.defaultForUser(userId);
    await updatePreferences(defaultPrefs);

    if (kDebugMode) {
      debugPrint(
        'UserPreferencesService: Reset preferences to defaults for user $userId',
      );
    }
  }

  @override
  Future<Map<String, dynamic>> exportPreferences() async {
    final preferences = await getUserPreferences();
    return preferences.toJson();
  }

  @override
  Future<void> importPreferences(Map<String, dynamic> preferencesJson) async {
    try {
      final preferences = UserPreferences.fromJson(preferencesJson);

      // Ensure the user ID matches current user
      final userId = _currentUserId;
      if (userId == null) {
        throw StateError('No authenticated user found');
      }

      final updatedPreferences = preferences.copyWith(
        userId: userId,
        updatedAt: DateTime.now(),
      );

      await updatePreferences(updatedPreferences);

      if (kDebugMode) {
        debugPrint(
          'UserPreferencesService: Imported preferences for user $userId',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('UserPreferencesService: Error importing preferences - $e');
      }
      rethrow;
    }
  }

  @override
  Future<bool> validatePreferences(UserPreferences preferences) async {
    return preferences.isValid();
  }

  @override
  List<String> getAvailableThemes() {
    return List.from(_availableThemes);
  }

  @override
  List<String> getAvailableLanguages() {
    return List.from(_availableLanguages);
  }

  @override
  Future<void> clearCache() async {
    _cachedPreferences = null;

    if (kDebugMode) {
      debugPrint('UserPreferencesService: Cleared preferences cache');
    }
  }

  /// Get offline status
  bool get isOffline => !_offlineManager.isOnline;

  /// Get sync status
  bool get isSyncing => _offlineManager.isSyncing;

  /// Get pending sync count
  int get pendingSyncCount => _offlineManager.pendingSyncCount;

  /// Get sync status stream
  Stream<SyncStatus> get syncStatusStream => _offlineManager.syncStatusStream;

  /// Force sync all offline data
  Future<void> forceSyncAll() async {
    if (!_offlineManager.isOnline) {
      throw Exception('Cannot sync while offline');
    }
    await _offlineManager.forceSyncAll();
  }

  /// Get data freshness information
  Future<Map<String, dynamic>> getDataFreshness() async {
    final lastSyncTime = await _offlineManager.getLastSyncTime();

    return {
      'lastSyncTime': lastSyncTime?.toIso8601String(),
      'isOnline': _offlineManager.isOnline,
      'isSyncing': _offlineManager.isSyncing,
      'pendingSyncCount': _offlineManager.pendingSyncCount,
      'isStale': lastSyncTime != null
          ? DateTime.now().difference(lastSyncTime).inHours > 24
          : true,
    };
  }

  /// Save preferences to local storage
  Future<void> _saveToLocalStorage(UserPreferences preferences) async {
    try {
      final prefsKey = _getPreferencesKey(preferences.userId);
      final prefsJson = jsonEncode(preferences.toJson());
      await _prefs!.setString(prefsKey, prefsJson);

      if (kDebugMode) {
        debugPrint(
          'UserPreferencesService: Saved preferences to local storage',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          'UserPreferencesService: Error saving to local storage - $e',
        );
      }
      rethrow;
    }
  }

  /// Sync preferences with Firebase (background operation)
  Future<void> _syncWithFirebase(UserPreferences preferences) async {
    try {
      await _firestore
          .collection(_firestoreCollection)
          .doc(preferences.userId)
          .set(preferences.toFirestoreJson(), SetOptions(merge: true));

      if (kDebugMode) {
        debugPrint('UserPreferencesService: Synced preferences with Firebase');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('UserPreferencesService: Error syncing with Firebase - $e');
      }
      // Don't rethrow - this is a background operation
    }
  }

  /// Dispose the service
  void dispose() {
    _preferencesController?.close();
    _preferencesController = null;
    _cachedPreferences = null;
    _initialized = false;
  }
}
