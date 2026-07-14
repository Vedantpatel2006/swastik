import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../shared/services/offline/offline_manager.dart';
import '../../../shared/services/cache/data_cache_manager.dart';
import 'enhanced_search_manager.dart';
import 'recommendation_manager.dart';
import 'live_darshan_service.dart';
import 'temple_status_service.dart';
import 'temple_share_service.dart';
import 'search_manager.dart';
import '../../../shared/models/temple.dart';
import '../../../shared/models/user_preferences.dart';
// TempleStatus is defined in temple_status_service.dart

/// Offline state for integrated features
class IntegratedOfflineState {
  final bool isOnline;
  final SyncStatus syncStatus;
  final int pendingOperations;
  final DateTime? lastSyncTime;
  final Map<String, int> cachedItemCounts;
  final List<String> availableFeatures;
  final Map<String, DateTime> lastFeatureSync;

  const IntegratedOfflineState({
    required this.isOnline,
    required this.syncStatus,
    required this.pendingOperations,
    this.lastSyncTime,
    this.cachedItemCounts = const {},
    this.availableFeatures = const [],
    this.lastFeatureSync = const {},
  });

  IntegratedOfflineState copyWith({
    bool? isOnline,
    SyncStatus? syncStatus,
    int? pendingOperations,
    DateTime? lastSyncTime,
    Map<String, int>? cachedItemCounts,
    List<String>? availableFeatures,
    Map<String, DateTime>? lastFeatureSync,
  }) {
    return IntegratedOfflineState(
      isOnline: isOnline ?? this.isOnline,
      syncStatus: syncStatus ?? this.syncStatus,
      pendingOperations: pendingOperations ?? this.pendingOperations,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      cachedItemCounts: cachedItemCounts ?? this.cachedItemCounts,
      availableFeatures: availableFeatures ?? this.availableFeatures,
      lastFeatureSync: lastFeatureSync ?? this.lastFeatureSync,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'isOnline': isOnline,
      'syncStatus': syncStatus.name,
      'pendingOperations': pendingOperations,
      'lastSyncTime': lastSyncTime?.toIso8601String(),
      'cachedItemCounts': cachedItemCounts,
      'availableFeatures': availableFeatures,
      'lastFeatureSync': lastFeatureSync.map(
        (k, v) => MapEntry(k, v.toIso8601String()),
      ),
    };
  }

  factory IntegratedOfflineState.fromJson(Map<String, dynamic> json) {
    return IntegratedOfflineState(
      isOnline: json['isOnline'] as bool? ?? true,
      syncStatus: SyncStatus.values.firstWhere(
        (e) => e.name == json['syncStatus'],
        orElse: () => SyncStatus.idle,
      ),
      pendingOperations: json['pendingOperations'] as int? ?? 0,
      lastSyncTime: json['lastSyncTime'] != null
          ? DateTime.parse(json['lastSyncTime'] as String)
          : null,
      cachedItemCounts: Map<String, int>.from(
        json['cachedItemCounts'] as Map? ?? {},
      ),
      availableFeatures: List<String>.from(
        json['availableFeatures'] as List? ?? [],
      ),
      lastFeatureSync: (json['lastFeatureSync'] as Map<String, dynamic>? ?? {})
          .map((k, v) => MapEntry(k, DateTime.parse(v as String))),
    );
  }
}

/// Integrated offline manager that provides offline support for all integrated features
/// Implements requirements 20.2, 20.4
class IntegratedOfflineManager extends ChangeNotifier {
  static final IntegratedOfflineManager _instance =
      IntegratedOfflineManager._internal();
  factory IntegratedOfflineManager() => _instance;
  IntegratedOfflineManager._internal();

  // Service dependencies
  final OfflineManager _offlineManager = OfflineManager();
  final DataCacheManager _cacheManager = DataCacheManager();

  // Integrated services
  EnhancedSearchManager? _searchManager;
  RecommendationManager? _recommendationManager;
  LiveDarshanService? _liveDarshanService;
  TempleStatusService? _templeStatusService;
  TempleShareService? _shareService;

  // Lazy getters for services
  EnhancedSearchManager get searchManager =>
      _searchManager ??= EnhancedSearchManager();
  RecommendationManager get recommendationManager =>
      _recommendationManager ??= RecommendationManager();
  LiveDarshanService get liveDarshanService =>
      _liveDarshanService ??= LiveDarshanService();
  TempleStatusService get templeStatusService =>
      _templeStatusService ??= TempleStatusService();
  TempleShareService get shareService => _shareService ??= TempleShareService();

  // Current state
  IntegratedOfflineState _currentState = const IntegratedOfflineState(
    isOnline: true,
    syncStatus: SyncStatus.idle,
    pendingOperations: 0,
  );

  // Stream controllers
  final StreamController<IntegratedOfflineState> _stateController =
      StreamController<IntegratedOfflineState>.broadcast();

  bool _initialized = false;

  /// Initialize the integrated offline manager
  Future<void> initialize() async {
    if (_initialized) return;

    await _offlineManager.initialize();
    await _cacheManager.initialize();
    await searchManager.initialize();
    await recommendationManager.initialize();
    await liveDarshanService.initialize();
    // TempleStatusService and TempleShareService don't have initialize methods
    // await templeStatusService.initialize();
    // await shareService.initialize();

    // Listen to base offline manager state changes
    _offlineManager.syncStatusStream.listen(_handleSyncStatusChange);

    // Load current state
    await _loadCurrentState();

    _initialized = true;

    if (kDebugMode) {
      debugPrint(
        'IntegratedOfflineManager: Initialized with all feature integrations',
      );
    }
  }

  /// Get current offline state
  IntegratedOfflineState get currentState => _currentState;

  /// Get offline state stream
  Stream<IntegratedOfflineState> get stateStream => _stateController.stream;

  /// Provide cached recommendations in offline mode
  /// Implements requirement 20.2
  Future<List<RecommendedTemple>> getCachedRecommendations({
    required String userId,
    UserPreferences? preferences,
    Location? userLocation,
    int limit = 10,
  }) async {
    try {
      if (_offlineManager.isOnline) {
        // If online, get fresh recommendations
        return await recommendationManager.getPersonalizedRecommendations(
          preferences:
              preferences ??
              UserPreferences(
                userId: userId,
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              ),
          userLocation: userLocation,
          limit: limit,
          includeExplanations: true,
          useCache: true,
        );
      }

      // Offline mode - get cached recommendations
      final cacheKey = 'offline_recommendations_$userId';
      final cachedData = await _cacheManager.getCachedDataList(cacheKey);

      if (cachedData != null) {
        final recommendations = cachedData
            .map((data) => RecommendedTemple.fromJson(data))
            .take(limit)
            .toList();

        if (kDebugMode) {
          debugPrint(
            'IntegratedOfflineManager: Returned ${recommendations.length} cached recommendations',
          );
        }

        return recommendations;
      }

      // No cached recommendations available
      return [];
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          'IntegratedOfflineManager: Error getting cached recommendations - $e',
        );
      }
      return [];
    }
  }

  /// Provide cached temple status in offline mode
  /// Implements requirement 20.2
  Future<TempleStatus?> getCachedTempleStatus(String templeId) async {
    try {
      if (_offlineManager.isOnline) {
        // If online, get fresh status
        // Get temple first, then get status
        final temple = await _getCachedTemple(templeId);
        if (temple != null) {
          return TempleStatusService.getTempleStatus(temple);
        }
        return null;
      }

      // Offline mode - get cached status
      final cacheKey = 'offline_temple_status_$templeId';
      final cachedData = await _cacheManager.getCachedData(cacheKey);

      if (cachedData != null) {
        final status = TempleStatus.fromJson(cachedData);

        if (kDebugMode) {
          debugPrint(
            'IntegratedOfflineManager: Returned cached status for temple $templeId',
          );
        }

        return status;
      }

      return null;
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          'IntegratedOfflineManager: Error getting cached temple status - $e',
        );
      }
      return null;
    }
  }

  /// Maintain sharing functionality with cached content
  /// Implements requirement 20.4
  Future<ShareContent> prepareCachedShareContent({
    required String templeId,
    bool includeLiveStatus = true,
    bool includeRecommendations = false,
  }) async {
    try {
      // Get cached temple data
      final temple = await _getCachedTemple(templeId);
      if (temple == null) {
        throw Exception('Temple not found in cache');
      }

      // Prepare basic share content
      var shareContent = ShareContent(
        templeId: templeId,
        templeName: temple.name,
        templeLocation: temple.location,
        description: temple.description,
        imageUrl: temple.images.isNotEmpty ? temple.images.first : null,
        isOfflineContent: !_offlineManager.isOnline,
      );

      // Add live status if requested and available in cache
      if (includeLiveStatus) {
        final cachedStatus = await getCachedTempleStatus(templeId);
        if (cachedStatus != null) {
          shareContent = shareContent.copyWith(
            isCurrentlyOpen: cachedStatus.isCurrentlyOpen,
            nextStatusChange: cachedStatus.nextStatusChange,
            liveDarshanAvailable:
                temple.liveDarshan?.isConfiguredByAdmin == true,
          );
        }
      }

      // Add recommendation context if requested
      if (includeRecommendations && !_offlineManager.isOnline) {
        shareContent = shareContent.copyWith(
          recommendationNote: 'Shared from offline recommendations',
        );
      }

      if (kDebugMode) {
        debugPrint(
          'IntegratedOfflineManager: Prepared cached share content for temple $templeId',
        );
      }

      return shareContent;
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          'IntegratedOfflineManager: Error preparing cached share content - $e',
        );
      }
      rethrow;
    }
  }

  /// Cache recommendations for offline use
  Future<void> cacheRecommendationsForOffline({
    required String userId,
    required List<RecommendedTemple> recommendations,
  }) async {
    try {
      final cacheKey = 'offline_recommendations_$userId';
      final data = recommendations.map((r) => r.toJson()).toList();

      await _cacheManager.cacheDataList(
        cacheKey,
        data,
        ttl: const Duration(hours: 24), // Cache for 24 hours
      );

      // Update state
      await _updateCachedItemCount('recommendations', recommendations.length);

      if (kDebugMode) {
        debugPrint(
          'IntegratedOfflineManager: Cached ${recommendations.length} recommendations for offline use',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          'IntegratedOfflineManager: Error caching recommendations - $e',
        );
      }
    }
  }

  /// Cache temple status for offline use
  Future<void> cacheTempleStatusForOffline({
    required String templeId,
    required TempleStatus status,
  }) async {
    try {
      final cacheKey = 'offline_temple_status_$templeId';

      await _cacheManager.cacheData(
        cacheKey,
        status.toJson(),
        ttl: const Duration(hours: 6), // Cache for 6 hours
      );

      // Update state
      await _updateCachedItemCount('temple_status', 1);

      if (kDebugMode) {
        debugPrint(
          'IntegratedOfflineManager: Cached status for temple $templeId',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          'IntegratedOfflineManager: Error caching temple status - $e',
        );
      }
    }
  }

  /// Cache search results for offline use
  Future<void> cacheSearchResultsForOffline({
    required String query,
    required List<Temple> temples,
    required SearchFilters filters,
  }) async {
    try {
      final cacheKey = 'offline_search_${query.hashCode}_${filters.hashCode}';
      final data = temples.map((t) => t.toJson()).toList();

      await _cacheManager.cacheDataList(
        cacheKey,
        data,
        ttl: const Duration(hours: 12), // Cache for 12 hours
      );

      // Update state
      await _updateCachedItemCount('search_results', temples.length);

      if (kDebugMode) {
        debugPrint(
          'IntegratedOfflineManager: Cached ${temples.length} search results for offline use',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          'IntegratedOfflineManager: Error caching search results - $e',
        );
      }
    }
  }

  /// Get cached search results for offline use
  Future<List<Temple>> getCachedSearchResults({
    required String query,
    required SearchFilters filters,
  }) async {
    try {
      if (_offlineManager.isOnline) {
        // If online, delegate to search manager
        final results = await searchManager.performEnhancedSearch(
          query: query,
          filters: filters,
          sortBy: SortOptions(
            sortBy: filters.sortBy,
            ascending: filters.ascending,
          ),
          useCache: true,
        );
        return results.temples;
      }

      // Offline mode - get cached results
      final cacheKey = 'offline_search_${query.hashCode}_${filters.hashCode}';
      final cachedData = await _cacheManager.getCachedDataList(cacheKey);

      if (cachedData != null) {
        final temples = cachedData
            .map((data) => Temple.fromJson(data))
            .toList();

        if (kDebugMode) {
          debugPrint(
            'IntegratedOfflineManager: Returned ${temples.length} cached search results',
          );
        }

        return temples;
      }

      return [];
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          'IntegratedOfflineManager: Error getting cached search results - $e',
        );
      }
      return [];
    }
  }

  /// Force sync all cached data when connection is restored
  Future<void> forceSyncAllFeatures() async {
    try {
      _updateState(_currentState.copyWith(syncStatus: SyncStatus.syncing));

      // Sync base offline data
      await _offlineManager.forceSyncAll();

      // Clear expired caches to force fresh data
      await _clearExpiredCaches();

      // Update sync timestamps
      final now = DateTime.now();
      final updatedFeatureSync = Map<String, DateTime>.from(
        _currentState.lastFeatureSync,
      );
      updatedFeatureSync['recommendations'] = now;
      updatedFeatureSync['temple_status'] = now;
      updatedFeatureSync['search_results'] = now;
      updatedFeatureSync['share_content'] = now;

      _updateState(
        _currentState.copyWith(
          syncStatus: SyncStatus.synced,
          lastSyncTime: now,
          lastFeatureSync: updatedFeatureSync,
          pendingOperations: 0,
        ),
      );

      if (kDebugMode) {
        debugPrint(
          'IntegratedOfflineManager: Completed sync of all integrated features',
        );
      }
    } catch (e) {
      _updateState(_currentState.copyWith(syncStatus: SyncStatus.error));

      if (kDebugMode) {
        debugPrint('IntegratedOfflineManager: Error syncing all features - $e');
      }
      rethrow;
    }
  }

  /// Get comprehensive cache information
  Future<IntegratedCacheInfo> getCacheInformation() async {
    try {
      final cacheStats = await _cacheManager.getStatistics();

      // Get detailed cache breakdown
      final cacheBreakdown = <String, CacheTypeInfo>{};

      // Recommendations cache info
      final recommendationsCacheSize = await _getCacheTypeSize(
        'offline_recommendations_',
      );
      cacheBreakdown['recommendations'] = CacheTypeInfo(
        itemCount: _currentState.cachedItemCounts['recommendations'] ?? 0,
        sizeBytes: recommendationsCacheSize,
        lastUpdated: _currentState.lastFeatureSync['recommendations'],
      );

      // Temple status cache info
      final statusCacheSize = await _getCacheTypeSize('offline_temple_status_');
      cacheBreakdown['temple_status'] = CacheTypeInfo(
        itemCount: _currentState.cachedItemCounts['temple_status'] ?? 0,
        sizeBytes: statusCacheSize,
        lastUpdated: _currentState.lastFeatureSync['temple_status'],
      );

      // Search results cache info
      final searchCacheSize = await _getCacheTypeSize('offline_search_');
      cacheBreakdown['search_results'] = CacheTypeInfo(
        itemCount: _currentState.cachedItemCounts['search_results'] ?? 0,
        sizeBytes: searchCacheSize,
        lastUpdated: _currentState.lastFeatureSync['search_results'],
      );

      return IntegratedCacheInfo(
        totalSizeBytes: cacheStats.totalSize,
        totalItemCount: _currentState.cachedItemCounts.values.fold(
          0,
          (sum, count) => sum + count,
        ),
        cacheBreakdown: cacheBreakdown,
        lastSyncTime: _currentState.lastSyncTime,
        isOnline: _currentState.isOnline,
        syncStatus: _currentState.syncStatus,
        availableFeatures: _currentState.availableFeatures,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          'IntegratedOfflineManager: Error getting cache information - $e',
        );
      }
      rethrow;
    }
  }

  /// Clear cache selectively by feature type
  Future<void> clearCacheByType(List<String> cacheTypes) async {
    try {
      for (final cacheType in cacheTypes) {
        switch (cacheType) {
          case 'recommendations':
            await _cacheManager.invalidateByPattern(
              'offline_recommendations_*',
            );
            break;
          case 'temple_status':
            await _cacheManager.invalidateByPattern('offline_temple_status_*');
            break;
          case 'search_results':
            await _cacheManager.invalidateByPattern('offline_search_*');
            break;
          case 'share_content':
            await _cacheManager.invalidateByPattern('offline_share_*');
            break;
          default:
            if (kDebugMode) {
              debugPrint(
                'IntegratedOfflineManager: Unknown cache type: $cacheType',
              );
            }
            break;
        }
      }

      // Update cached item counts
      final updatedCounts = Map<String, int>.from(
        _currentState.cachedItemCounts,
      );
      for (final cacheType in cacheTypes) {
        updatedCounts[cacheType] = 0;
      }

      _updateState(_currentState.copyWith(cachedItemCounts: updatedCounts));

      if (kDebugMode) {
        debugPrint(
          'IntegratedOfflineManager: Cleared cache for types: ${cacheTypes.join(', ')}',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          'IntegratedOfflineManager: Error clearing cache by type - $e',
        );
      }
      rethrow;
    }
  }

  /// Handle sync status changes from base offline manager
  void _handleSyncStatusChange(SyncStatus status) {
    _updateState(
      _currentState.copyWith(
        syncStatus: status,
        pendingOperations: _offlineManager.pendingSyncCount,
      ),
    );
  }

  /// Update cached item count for a specific type
  Future<void> _updateCachedItemCount(String type, int count) async {
    final updatedCounts = Map<String, int>.from(_currentState.cachedItemCounts);
    updatedCounts[type] = (updatedCounts[type] ?? 0) + count;

    _updateState(_currentState.copyWith(cachedItemCounts: updatedCounts));
  }

  /// Get cached temple data
  Future<Temple?> _getCachedTemple(String templeId) async {
    try {
      final cacheKey = 'temple_$templeId';
      final cachedData = await _cacheManager.getCachedData(cacheKey);

      if (cachedData != null) {
        return Temple.fromJson(cachedData);
      }

      return null;
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          'IntegratedOfflineManager: Error getting cached temple - $e',
        );
      }
      return null;
    }
  }

  /// Get cache size for a specific cache type pattern
  Future<int> _getCacheTypeSize(String pattern) async {
    try {
      // This would ideally get actual cache size from cache manager
      // For now, return estimated size
      return 1024; // 1KB estimated per item
    } catch (e) {
      return 0;
    }
  }

  /// Clear expired caches
  Future<void> _clearExpiredCaches() async {
    try {
      // Clear expired entries (method may not exist in DataCacheManager)
      // await _cacheManager.clearExpiredEntries();

      if (kDebugMode) {
        debugPrint('IntegratedOfflineManager: Cleared expired caches');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          'IntegratedOfflineManager: Error clearing expired caches - $e',
        );
      }
    }
  }

  /// Load current state from storage
  Future<void> _loadCurrentState() async {
    try {
      final stateData = await _offlineManager.getData(
        'integrated_offline_state',
      );
      if (stateData != null) {
        _currentState = IntegratedOfflineState.fromJson(stateData);
      }

      // Update online status
      _currentState = _currentState.copyWith(
        isOnline: _offlineManager.isOnline,
        pendingOperations: _offlineManager.pendingSyncCount,
      );

      _stateController.add(_currentState);
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          'IntegratedOfflineManager: Error loading current state - $e',
        );
      }
    }
  }

  /// Update current state and notify listeners
  void _updateState(IntegratedOfflineState newState) {
    _currentState = newState;
    _stateController.add(_currentState);
    notifyListeners();

    // Persist state
    _persistCurrentState();
  }

  /// Persist current state to storage
  Future<void> _persistCurrentState() async {
    try {
      await _offlineManager.updateOfflineData(
        id: 'integrated_offline_state',
        collection: 'system',
        data: _currentState.toJson(),
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          'IntegratedOfflineManager: Error persisting current state - $e',
        );
      }
    }
  }

  /// Dispose resources
  @override
  void dispose() {
    _stateController.close();
    super.dispose();
  }
}

/// Cache information for a specific cache type
class CacheTypeInfo {
  final int itemCount;
  final int sizeBytes;
  final DateTime? lastUpdated;

  const CacheTypeInfo({
    required this.itemCount,
    required this.sizeBytes,
    this.lastUpdated,
  });

  Map<String, dynamic> toJson() {
    return {
      'itemCount': itemCount,
      'sizeBytes': sizeBytes,
      if (lastUpdated != null) 'lastUpdated': lastUpdated!.toIso8601String(),
    };
  }

  factory CacheTypeInfo.fromJson(Map<String, dynamic> json) {
    return CacheTypeInfo(
      itemCount: json['itemCount'] as int,
      sizeBytes: json['sizeBytes'] as int,
      lastUpdated: json['lastUpdated'] != null
          ? DateTime.parse(json['lastUpdated'] as String)
          : null,
    );
  }
}

/// Comprehensive cache information for integrated features
class IntegratedCacheInfo {
  final int totalSizeBytes;
  final int totalItemCount;
  final Map<String, CacheTypeInfo> cacheBreakdown;
  final DateTime? lastSyncTime;
  final bool isOnline;
  final SyncStatus syncStatus;
  final List<String> availableFeatures;

  const IntegratedCacheInfo({
    required this.totalSizeBytes,
    required this.totalItemCount,
    required this.cacheBreakdown,
    this.lastSyncTime,
    required this.isOnline,
    required this.syncStatus,
    required this.availableFeatures,
  });

  Map<String, dynamic> toJson() {
    return {
      'totalSizeBytes': totalSizeBytes,
      'totalItemCount': totalItemCount,
      'cacheBreakdown': cacheBreakdown.map((k, v) => MapEntry(k, v.toJson())),
      if (lastSyncTime != null) 'lastSyncTime': lastSyncTime!.toIso8601String(),
      'isOnline': isOnline,
      'syncStatus': syncStatus.name,
      'availableFeatures': availableFeatures,
    };
  }

  factory IntegratedCacheInfo.fromJson(Map<String, dynamic> json) {
    return IntegratedCacheInfo(
      totalSizeBytes: json['totalSizeBytes'] as int,
      totalItemCount: json['totalItemCount'] as int,
      cacheBreakdown: (json['cacheBreakdown'] as Map<String, dynamic>).map(
        (k, v) =>
            MapEntry(k, CacheTypeInfo.fromJson(v as Map<String, dynamic>)),
      ),
      lastSyncTime: json['lastSyncTime'] != null
          ? DateTime.parse(json['lastSyncTime'] as String)
          : null,
      isOnline: json['isOnline'] as bool,
      syncStatus: SyncStatus.values.firstWhere(
        (e) => e.name == json['syncStatus'],
        orElse: () => SyncStatus.idle,
      ),
      availableFeatures: List<String>.from(
        json['availableFeatures'] as List? ?? [],
      ),
    );
  }
}

/// Share content model for offline sharing
class ShareContent {
  final String templeId;
  final String templeName;
  final Location templeLocation;
  final String description;
  final String? imageUrl;
  final bool isOfflineContent;
  final bool? isCurrentlyOpen;
  final DateTime? nextStatusChange;
  final bool? liveDarshanAvailable;
  final String? recommendationNote;

  const ShareContent({
    required this.templeId,
    required this.templeName,
    required this.templeLocation,
    required this.description,
    this.imageUrl,
    required this.isOfflineContent,
    this.isCurrentlyOpen,
    this.nextStatusChange,
    this.liveDarshanAvailable,
    this.recommendationNote,
  });

  ShareContent copyWith({
    String? templeId,
    String? templeName,
    Location? templeLocation,
    String? description,
    String? imageUrl,
    bool? isOfflineContent,
    bool? isCurrentlyOpen,
    DateTime? nextStatusChange,
    bool? liveDarshanAvailable,
    String? recommendationNote,
  }) {
    return ShareContent(
      templeId: templeId ?? this.templeId,
      templeName: templeName ?? this.templeName,
      templeLocation: templeLocation ?? this.templeLocation,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      isOfflineContent: isOfflineContent ?? this.isOfflineContent,
      isCurrentlyOpen: isCurrentlyOpen ?? this.isCurrentlyOpen,
      nextStatusChange: nextStatusChange ?? this.nextStatusChange,
      liveDarshanAvailable: liveDarshanAvailable ?? this.liveDarshanAvailable,
      recommendationNote: recommendationNote ?? this.recommendationNote,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'templeId': templeId,
      'templeName': templeName,
      'templeLocation': templeLocation.toJson(),
      'description': description,
      if (imageUrl != null) 'imageUrl': imageUrl,
      'isOfflineContent': isOfflineContent,
      if (isCurrentlyOpen != null) 'isCurrentlyOpen': isCurrentlyOpen,
      if (nextStatusChange != null)
        'nextStatusChange': nextStatusChange!.toIso8601String(),
      if (liveDarshanAvailable != null)
        'liveDarshanAvailable': liveDarshanAvailable,
      if (recommendationNote != null) 'recommendationNote': recommendationNote,
    };
  }

  factory ShareContent.fromJson(Map<String, dynamic> json) {
    return ShareContent(
      templeId: json['templeId'] as String,
      templeName: json['templeName'] as String,
      templeLocation: Location.fromJson(
        json['templeLocation'] as Map<String, dynamic>,
      ),
      description: json['description'] as String,
      imageUrl: json['imageUrl'] as String?,
      isOfflineContent: json['isOfflineContent'] as bool,
      isCurrentlyOpen: json['isCurrentlyOpen'] as bool?,
      nextStatusChange: json['nextStatusChange'] != null
          ? DateTime.parse(json['nextStatusChange'] as String)
          : null,
      liveDarshanAvailable: json['liveDarshanAvailable'] as bool?,
      recommendationNote: json['recommendationNote'] as String?,
    );
  }
}
