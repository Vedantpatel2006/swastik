import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../../shared/services/offline/offline_manager.dart';
import '../../../shared/services/offline/sync_service.dart';
import '../../../shared/services/cache/data_cache_manager.dart';

/// Types of cached content for categorization
enum CacheType {
  temples,
  events,
  images,
  recommendations,
  searches,
  userPreferences,
}

/// Information about conflicts that need resolution
class ConflictInfo {
  final String id;
  final String collection;
  final Map<String, dynamic> serverData;
  final Map<String, dynamic> clientData;
  final DateTime conflictTime;
  final String description;

  ConflictInfo({
    required this.id,
    required this.collection,
    required this.serverData,
    required this.clientData,
    required this.conflictTime,
    required this.description,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'collection': collection,
    'serverData': serverData,
    'clientData': clientData,
    'conflictTime': conflictTime.toIso8601String(),
    'description': description,
  };

  factory ConflictInfo.fromJson(Map<String, dynamic> json) => ConflictInfo(
    id: json['id'] as String,
    collection: json['collection'] as String,
    serverData: Map<String, dynamic>.from(json['serverData'] as Map),
    clientData: Map<String, dynamic>.from(json['clientData'] as Map),
    conflictTime: DateTime.parse(json['conflictTime'] as String),
    description: json['description'] as String,
  );
}

/// Comprehensive offline state information
class OfflineState {
  final bool isOnline;
  final SyncStatus syncStatus;
  final int pendingOperations;
  final DateTime? lastSyncTime;
  final List<ConflictInfo> conflicts;
  final double syncProgress;
  final String? currentSyncOperation;
  final Map<CacheType, int> cacheStats;
  final int totalCacheSize;
  final bool isDataStale;

  OfflineState({
    required this.isOnline,
    required this.syncStatus,
    required this.pendingOperations,
    this.lastSyncTime,
    required this.conflicts,
    this.syncProgress = 0.0,
    this.currentSyncOperation,
    required this.cacheStats,
    required this.totalCacheSize,
    this.isDataStale = false,
  });

  /// Check if sync is in progress
  bool get isSyncing => syncStatus == SyncStatus.syncing;

  /// Check if there are conflicts to resolve
  bool get hasConflicts => conflicts.isNotEmpty;

  /// Check if data is fresh (synced within last hour)
  bool get isDataFresh {
    if (lastSyncTime == null) return false;
    return DateTime.now().difference(lastSyncTime!).inHours < 1;
  }

  /// Get human-readable sync status
  String get syncStatusText {
    switch (syncStatus) {
      case SyncStatus.idle:
        return 'Ready to sync';
      case SyncStatus.syncing:
        return currentSyncOperation ?? 'Syncing...';
      case SyncStatus.synced:
        return 'Up to date';
      case SyncStatus.success:
        return 'Sync completed';
      case SyncStatus.error:
        return 'Sync failed';
      case SyncStatus.failed:
        return 'Sync failed';
      case SyncStatus.offline:
        return 'Offline mode';
      case SyncStatus.pending:
        return 'Sync pending';
      case SyncStatus.conflict:
        return 'Conflicts need resolution';
    }
  }

  OfflineState copyWith({
    bool? isOnline,
    SyncStatus? syncStatus,
    int? pendingOperations,
    DateTime? lastSyncTime,
    List<ConflictInfo>? conflicts,
    double? syncProgress,
    String? currentSyncOperation,
    Map<CacheType, int>? cacheStats,
    int? totalCacheSize,
    bool? isDataStale,
  }) {
    return OfflineState(
      isOnline: isOnline ?? this.isOnline,
      syncStatus: syncStatus ?? this.syncStatus,
      pendingOperations: pendingOperations ?? this.pendingOperations,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      conflicts: conflicts ?? this.conflicts,
      syncProgress: syncProgress ?? this.syncProgress,
      currentSyncOperation: currentSyncOperation ?? this.currentSyncOperation,
      cacheStats: cacheStats ?? this.cacheStats,
      totalCacheSize: totalCacheSize ?? this.totalCacheSize,
      isDataStale: isDataStale ?? this.isDataStale,
    );
  }
}

/// Extended offline manager with comprehensive state management
class OfflineStateManager {
  static OfflineStateManager? _instance;
  factory OfflineStateManager() => _instance ??= OfflineStateManager._internal();
  OfflineStateManager._internal();

  final OfflineManager _offlineManager = OfflineManager();
  final SyncService _syncService = SyncService();
  final DataCacheManager _cacheManager = DataCacheManager();
  final Connectivity _connectivity = Connectivity();

  final StreamController<OfflineState> _stateController = 
      StreamController<OfflineState>.broadcast();

  OfflineState _currentState = OfflineState(
    isOnline: true,
    syncStatus: SyncStatus.idle,
    pendingOperations: 0,
    conflicts: [],
    cacheStats: {},
    totalCacheSize: 0,
  );

  Timer? _staleDataTimer;
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  StreamSubscription<SyncProgress>? _syncProgressSubscription;
  StreamSubscription<SyncResult>? _syncResultSubscription;

  /// Initialize the offline state manager
  Future<void> initialize() async {
    await _offlineManager.initialize();
    await _syncService.initialize();
    await _cacheManager.initialize();

    // Set up connectivity monitoring
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      _handleConnectivityChange,
    );

    // Set up sync progress monitoring
    _syncProgressSubscription = _syncService.progressStream.listen(
      _handleSyncProgress,
    );

    // Set up sync result monitoring
    _syncResultSubscription = _syncService.resultStream.listen(
      _handleSyncResult,
    );

    // Set up periodic state updates
    _setupPeriodicUpdates();

    // Initial state update
    await _updateState();

    if (kDebugMode) {
      debugPrint('OfflineStateManager: Initialized');
    }
  }

  /// Stream of offline state changes
  Stream<OfflineState> get offlineStateStream => _stateController.stream;

  /// Current offline state
  OfflineState get currentState => _currentState;

  /// Check if device is online
  bool get isOnline => _currentState.isOnline;

  /// Check if sync is in progress
  bool get isSyncing => _currentState.isSyncing;

  /// Get pending sync count
  int get pendingSyncCount => _currentState.pendingOperations;

  /// Force sync with progress tracking
  Future<SyncResult> forceSyncWithProgress() async {
    if (!_currentState.isOnline) {
      throw StateError('Cannot sync while offline');
    }

    if (_currentState.isSyncing) {
      throw StateError('Sync already in progress');
    }

    try {
      _updateSyncStatus(SyncStatus.syncing, 'Starting sync...');
      
      final result = await _syncService.syncAll();
      
      if (result.success) {
        _updateSyncStatus(SyncStatus.success, 'Sync completed');
      } else {
        _updateSyncStatus(SyncStatus.error, 'Sync failed');
      }

      await _updateState();
      return result;
    } catch (e) {
      _updateSyncStatus(SyncStatus.error, 'Sync error: $e');
      rethrow;
    }
  }

  /// Get comprehensive cache information
  Future<CacheInfo> getCacheInformation() async {
    final cacheStats = _cacheManager.getStatistics();
    final keys = await _cacheManager.getKeys();
    
    final cacheByType = <CacheType, int>{};
    final items = <CachedItem>[];

    // Categorize cache entries
    for (final key in keys) {
      final info = await _cacheManager.getCacheEntryInfo(key);
      if (info != null) {
        final type = _categorizeKey(key);
        cacheByType[type] = (cacheByType[type] ?? 0) + (info['dataSize'] as int? ?? 0);
        
        items.add(CachedItem(
          key: key,
          type: type,
          size: info['dataSize'] as int? ?? 0,
          createdAt: DateTime.parse(info['createdAt'] as String),
          lastAccessed: DateTime.parse(info['lastAccessed'] as String),
          accessCount: info['accessCount'] as int? ?? 0,
        ));
      }
    }

    return CacheInfo(
      totalSizeBytes: cacheStats.totalSize,
      sizeByType: cacheByType,
      lastCleanup: DateTime.now(), // Placeholder
      items: items,
    );
  }

  /// Clear cache selectively by types
  Future<void> clearCacheSelectively(List<CacheType> types) async {
    final keys = await _cacheManager.getKeys();
    int removedCount = 0;

    for (final key in keys) {
      final type = _categorizeKey(key);
      if (types.contains(type)) {
        await _cacheManager.remove(key);
        removedCount++;
      }
    }

    await _updateState();

    if (kDebugMode) {
      debugPrint('OfflineStateManager: Cleared $removedCount cache entries of types: $types');
    }
  }

  /// Handle connectivity changes
  void _handleConnectivityChange(ConnectivityResult result) {
    final wasOnline = _currentState.isOnline;
    final isOnline = result != ConnectivityResult.none;

    if (wasOnline != isOnline) {
      _currentState = _currentState.copyWith(isOnline: isOnline);
      
      if (isOnline) {
        // Coming back online - check for pending operations
        _updateSyncStatus(SyncStatus.pending, 'Connection restored');
        _scheduleAutoSync();
      } else {
        // Going offline
        _updateSyncStatus(SyncStatus.offline, 'Offline mode');
      }

      _stateController.add(_currentState);

      if (kDebugMode) {
        debugPrint('OfflineStateManager: Connectivity changed - Online: $isOnline');
      }
    }
  }

  /// Handle sync progress updates
  void _handleSyncProgress(SyncProgress progress) {
    _currentState = _currentState.copyWith(
      syncProgress: progress.progress,
      currentSyncOperation: progress.currentOperation,
    );
    _stateController.add(_currentState);
  }

  /// Handle sync results
  void _handleSyncResult(SyncResult result) {
    final conflicts = result.conflicts.map((conflict) => ConflictInfo(
      id: conflict.id,
      collection: conflict.collection,
      serverData: conflict.serverData,
      clientData: conflict.clientData,
      conflictTime: DateTime.now(),
      description: 'Data conflict in ${conflict.collection}',
    )).toList();

    _currentState = _currentState.copyWith(
      conflicts: conflicts,
      syncProgress: 1.0,
      lastSyncTime: DateTime.now(),
    );

    if (result.success) {
      _updateSyncStatus(SyncStatus.success, 'Sync completed successfully');
    } else if (result.hasConflicts) {
      _updateSyncStatus(SyncStatus.conflict, 'Conflicts need resolution');
    } else {
      _updateSyncStatus(SyncStatus.error, 'Sync failed');
    }

    _stateController.add(_currentState);
  }

  /// Update sync status
  void _updateSyncStatus(SyncStatus status, String? operation) {
    _currentState = _currentState.copyWith(
      syncStatus: status,
      currentSyncOperation: operation,
    );
    _stateController.add(_currentState);
  }

  /// Update complete state
  Future<void> _updateState() async {
    final pendingCount = _offlineManager.pendingSyncCount;
    final lastSync = await _offlineManager.getLastSyncTime();
    final cacheInfo = await getCacheInformation();
    final isStale = lastSync == null || 
        DateTime.now().difference(lastSync).inHours > 2;

    _currentState = _currentState.copyWith(
      pendingOperations: pendingCount,
      lastSyncTime: lastSync,
      cacheStats: cacheInfo.sizeByType,
      totalCacheSize: cacheInfo.totalSizeBytes,
      isDataStale: isStale,
    );

    _stateController.add(_currentState);
  }

  /// Set up periodic state updates
  void _setupPeriodicUpdates() {
    // Update state every 30 seconds
    Timer.periodic(const Duration(seconds: 30), (_) async {
      await _updateState();
    });

    // Check for stale data every 5 minutes
    _staleDataTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      final lastSync = _currentState.lastSyncTime;
      if (lastSync != null) {
        final isStale = DateTime.now().difference(lastSync).inHours > 2;
        if (isStale != _currentState.isDataStale) {
          _currentState = _currentState.copyWith(isDataStale: isStale);
          _stateController.add(_currentState);
        }
      }
    });
  }

  /// Schedule automatic sync when coming online
  void _scheduleAutoSync() {
    if (_currentState.pendingOperations > 0) {
      Timer(const Duration(seconds: 2), () async {
        try {
          await forceSyncWithProgress();
        } catch (e) {
          if (kDebugMode) {
            debugPrint('OfflineStateManager: Auto-sync failed - $e');
          }
        }
      });
    }
  }

  /// Categorize cache key by type
  CacheType _categorizeKey(String key) {
    if (key.startsWith('temple')) return CacheType.temples;
    if (key.startsWith('event')) return CacheType.events;
    if (key.startsWith('image')) return CacheType.images;
    if (key.startsWith('recommendation')) return CacheType.recommendations;
    if (key.startsWith('search')) return CacheType.searches;
    if (key.startsWith('user_pref')) return CacheType.userPreferences;
    return CacheType.temples; // Default
  }

  /// Dispose resources
  void dispose() {
    _stateController.close();
    _staleDataTimer?.cancel();
    _connectivitySubscription?.cancel();
    _syncProgressSubscription?.cancel();
    _syncResultSubscription?.cancel();
  }
}

/// Information about cached items
class CachedItem {
  final String key;
  final CacheType type;
  final int size;
  final DateTime createdAt;
  final DateTime lastAccessed;
  final int accessCount;

  CachedItem({
    required this.key,
    required this.type,
    required this.size,
    required this.createdAt,
    required this.lastAccessed,
    required this.accessCount,
  });

  /// Check if item is stale
  bool get isStale => DateTime.now().difference(lastAccessed).inHours > 24;

  /// Get human-readable size
  String get sizeText {
    if (size < 1024) return '${size}B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)}KB';
    return '${(size / (1024 * 1024)).toStringAsFixed(1)}MB';
  }
}

/// Cache information summary
class CacheInfo {
  final int totalSizeBytes;
  final Map<CacheType, int> sizeByType;
  final DateTime lastCleanup;
  final List<CachedItem> items;

  CacheInfo({
    required this.totalSizeBytes,
    required this.sizeByType,
    required this.lastCleanup,
    required this.items,
  });

  /// Get human-readable total size
  String get totalSizeText {
    if (totalSizeBytes < 1024) return '${totalSizeBytes}B';
    if (totalSizeBytes < 1024 * 1024) {
      return '${(totalSizeBytes / 1024).toStringAsFixed(1)}KB';
    }
    return '${(totalSizeBytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }

  /// Get size breakdown by type
  Map<CacheType, String> get sizeByTypeText {
    return sizeByType.map((type, size) {
      if (size < 1024) return MapEntry(type, '${size}B');
      if (size < 1024 * 1024) {
        return MapEntry(type, '${(size / 1024).toStringAsFixed(1)}KB');
      }
      return MapEntry(type, '${(size / (1024 * 1024)).toStringAsFixed(1)}MB');
    });
  }
}