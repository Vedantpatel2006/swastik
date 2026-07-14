import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Types of offline operations
enum OfflineOperationType { create, update, delete }

/// Sync status enumeration
enum SyncStatus {
  idle,
  syncing,
  synced,
  success,
  error,
  failed,
  offline,
  pending,
  conflict,
}

/// Conflict resolution strategies
enum ConflictResolutionStrategy { serverWins, clientWins, merge, manual }

/// Offline data entry for sync queue
class OfflineDataEntry {
  final String id;
  final String collection;
  final Map<String, dynamic> data;
  final OfflineOperationType operation;
  final DateTime timestamp;
  final bool needsSync;
  final String? conflictResolution;

  OfflineDataEntry({
    required this.id,
    required this.collection,
    required this.data,
    required this.operation,
    required this.timestamp,
    this.needsSync = true,
    this.conflictResolution,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'collection': collection,
    'data': data,
    'operation': operation.name,
    'timestamp': timestamp.toIso8601String(),
    'needsSync': needsSync,
    'conflictResolution': conflictResolution,
  };

  factory OfflineDataEntry.fromJson(Map<String, dynamic> json) =>
      OfflineDataEntry(
        id: json['id'] as String,
        collection: json['collection'] as String,
        data: Map<String, dynamic>.from(json['data'] as Map),
        operation: OfflineOperationType.values.firstWhere(
          (e) => e.name == json['operation'],
        ),
        timestamp: DateTime.parse(json['timestamp'] as String),
        needsSync: json['needsSync'] as bool? ?? true,
        conflictResolution: json['conflictResolution'] as String?,
      );
}

class OfflineManager {
  static OfflineManager? _instance;
  factory OfflineManager() => _instance ??= OfflineManager._internal();
  OfflineManager._internal();

  SharedPreferences? _prefs;
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  bool _isOnline = true;
  bool _initialized = false;

  static const String _offlineDataKey = 'offline_data';
  static const String _lastSyncTimeKey = 'last_sync_time';

  /// Initialize the offline manager
  Future<void> initialize() async {
    if (_initialized) return;

    _prefs = await SharedPreferences.getInstance();

    // Check initial connectivity
    final connectivityResult = await _connectivity.checkConnectivity();
    _isOnline = connectivityResult != ConnectivityResult.none;

    // Listen to connectivity changes
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((
      ConnectivityResult result,
    ) {
      _isOnline = result != ConnectivityResult.none;
    });

    _initialized = true;
  }

  /// Check if device is online
  bool get isOnline => _isOnline;

  /// Get count of pending sync operations
  int get pendingSyncCount {
    if (_prefs == null) return 0;
    final offlineDataJson = _prefs!.getString(_offlineDataKey);
    if (offlineDataJson == null) return 0;

    try {
      final offlineData = jsonDecode(offlineDataJson) as Map<String, dynamic>;
      return offlineData.values
          .where(
            (entry) => (entry as Map<String, dynamic>)['needsSync'] == true,
          )
          .length;
    } catch (e) {
      return 0;
    }
  }

  /// Store data for offline sync
  Future<void> storeOfflineData({
    required String id,
    required String collection,
    required Map<String, dynamic> data,
    required OfflineOperationType operation,
  }) async {
    if (_prefs == null) {
      throw StateError('OfflineManager not initialized');
    }

    final entry = OfflineDataEntry(
      id: id,
      collection: collection,
      data: data,
      operation: operation,
      timestamp: DateTime.now(),
    );

    // Get existing offline data
    final offlineDataJson = _prefs!.getString(_offlineDataKey) ?? '{}';
    final offlineData = jsonDecode(offlineDataJson) as Map<String, dynamic>;

    // Store entry with composite key
    final key = '${collection}_$id';
    offlineData[key] = entry.toJson();

    // Save back to preferences
    await _prefs!.setString(_offlineDataKey, jsonEncode(offlineData));
  }

  /// Delete offline data entry
  Future<void> deleteOfflineData({
    required String id,
    required String collection,
  }) async {
    if (_prefs == null) {
      throw StateError('OfflineManager not initialized');
    }

    final offlineDataJson = _prefs!.getString(_offlineDataKey) ?? '{}';
    final offlineData = jsonDecode(offlineDataJson) as Map<String, dynamic>;

    final key = '${collection}_$id';
    offlineData.remove(key);

    await _prefs!.setString(_offlineDataKey, jsonEncode(offlineData));
  }

  /// Get offline data by collection
  Future<List<OfflineDataEntry>> getOfflineDataByCollection(
    String collection,
  ) async {
    if (_prefs == null) return [];

    final offlineDataJson = _prefs!.getString(_offlineDataKey) ?? '{}';
    final offlineData = jsonDecode(offlineDataJson) as Map<String, dynamic>;

    final entries = <OfflineDataEntry>[];
    for (final entry in offlineData.values) {
      try {
        final dataEntry = OfflineDataEntry.fromJson(
          entry as Map<String, dynamic>,
        );
        if (dataEntry.collection == collection) {
          entries.add(dataEntry);
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('OfflineManager: Error parsing entry - $e');
        }
      }
    }

    return entries;
  }

  /// Force sync all offline data
  Future<void> forceSyncAll() async {
    // This would typically trigger the sync service
    // For now, just mark all entries as synced
    if (_prefs == null) return;

    final offlineDataJson = _prefs!.getString(_offlineDataKey) ?? '{}';
    final offlineData = jsonDecode(offlineDataJson) as Map<String, dynamic>;

    for (final key in offlineData.keys) {
      final entry = offlineData[key] as Map<String, dynamic>;
      entry['needsSync'] = false;
    }

    await _prefs!.setString(_offlineDataKey, jsonEncode(offlineData));
    await _prefs!.setString(_lastSyncTimeKey, DateTime.now().toIso8601String());
  }

  /// Get last sync time
  Future<DateTime?> getLastSyncTime() async {
    if (_prefs == null) return null;

    final lastSyncStr = _prefs!.getString(_lastSyncTimeKey);
    if (lastSyncStr == null) return null;

    try {
      return DateTime.parse(lastSyncStr);
    } catch (e) {
      return null;
    }
  }

  /// Get pending conflicts (placeholder)
  Future<List<Map<String, dynamic>>> getPendingConflicts() async {
    // Placeholder implementation
    return [];
  }

  /// Stream controller for sync status
  final StreamController<SyncStatus> _syncStatusController =
      StreamController<SyncStatus>.broadcast();

  /// Current sync status
  SyncStatus _currentSyncStatus = SyncStatus.idle;

  /// Get sync status stream
  Stream<SyncStatus> get syncStatusStream => _syncStatusController.stream;

  /// Check if currently syncing
  bool get isSyncing => _currentSyncStatus == SyncStatus.syncing;

  /// Update sync status
  void updateSyncStatus(SyncStatus status) {
    _currentSyncStatus = status;
    _syncStatusController.add(status);
  }

  /// Get data by key
  Future<Map<String, dynamic>?> getData(String key) async {
    if (_prefs == null) return null;

    final dataJson = _prefs!.getString(key);
    if (dataJson == null) return null;

    try {
      return jsonDecode(dataJson) as Map<String, dynamic>;
    } catch (e) {
      return null;
    }
  }

  /// Get data list by key
  Future<List<Map<String, dynamic>>> getDataList(String key) async {
    if (_prefs == null) return [];

    final dataJson = _prefs!.getString(key);
    if (dataJson == null) return [];

    try {
      final data = jsonDecode(dataJson);
      if (data is List) {
        return data.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  /// Update offline data
  Future<void> updateOfflineData({
    required String id,
    required String collection,
    required Map<String, dynamic> data,
  }) async {
    await storeOfflineData(
      id: id,
      collection: collection,
      data: data,
      operation: OfflineOperationType.update,
    );
  }

  /// Resolve conflict with improved logic
  Map<String, dynamic> resolveConflict({
    required Map<String, dynamic> conflict,
    required ConflictResolutionStrategy strategy,
  }) {
    final serverData = Map<String, dynamic>.from(
      conflict['serverData'] as Map<String, dynamic>? ?? {},
    );
    final clientData = Map<String, dynamic>.from(
      conflict['clientData'] as Map<String, dynamic>? ?? {},
    );
    
    switch (strategy) {
      case ConflictResolutionStrategy.serverWins:
        return serverData;
        
      case ConflictResolutionStrategy.clientWins:
        return clientData;
        
      case ConflictResolutionStrategy.merge:
        // Intelligent merge with timestamp-based resolution
        final merged = Map<String, dynamic>.from(serverData);

        clientData.forEach((key, value) {
          if (value != null) {
            // For timestamp fields, use the latest
            if (key.contains('At') || key.contains('Time')) {
              try {
                final serverTime = DateTime.tryParse(
                  serverData[key]?.toString() ?? '',
                );
                final clientTime = DateTime.tryParse(value.toString());

                if (serverTime != null && clientTime != null) {
                  merged[key] = clientTime.isAfter(serverTime)
                      ? value
                      : serverData[key];
                } else {
                  merged[key] = value;
                }
              } catch (e) {
                merged[key] = value;
              }
            } else {
              // For other fields, client wins
              merged[key] = value;
            }
          }
        });

        // Ensure updatedAt is set to current time
        merged['updatedAt'] = DateTime.now().toIso8601String();
        return merged;
        
      case ConflictResolutionStrategy.manual:
        // Return both datasets for manual resolution
        return {
          'conflictType': 'manual_resolution_required',
          'serverData': serverData,
          'clientData': clientData,
          'conflictFields': _identifyConflictFields(serverData, clientData),
        };
    }
  }

  /// Identify fields that have conflicts between server and client data
  List<String> _identifyConflictFields(
    Map<String, dynamic> serverData,
    Map<String, dynamic> clientData,
  ) {
    final conflicts = <String>[];

    for (final key in clientData.keys) {
      if (serverData.containsKey(key) &&
          serverData[key] != clientData[key] &&
          key != 'updatedAt') {
        // Ignore timestamp differences
        conflicts.add(key);
      }
    }
    
    return conflicts;
  }

  /// Dispose resources
  void dispose() {
    _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
    _syncStatusController.close();
  }
}
