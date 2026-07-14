import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../features/temple/services/user_temple_service.dart';
import '../../models/temple.dart';
import '../../models/temple_filters.dart';
import '../../models/user_preferences.dart';

/// Lazy loading configuration
class LazyLoadingConfig {
  final int pageSize;
  final int preloadThreshold;
  final int maxCachedPages;
  final Duration loadTimeout;

  const LazyLoadingConfig({
    this.pageSize = 20,
    this.preloadThreshold = 5,
    this.maxCachedPages = 10,
    this.loadTimeout = const Duration(seconds: 10),
  });
}

/// Lazy loading state
enum LazyLoadingState { idle, loading, loadingMore, error, endReached }

/// Lazy loading result
class LazyLoadingResult<T> {
  final List<T> items;
  final bool hasMore;
  final int totalCount;
  final String? error;

  const LazyLoadingResult({
    required this.items,
    required this.hasMore,
    this.totalCount = -1,
    this.error,
  });

  LazyLoadingResult<T> copyWith({
    List<T>? items,
    bool? hasMore,
    int? totalCount,
    String? error,
  }) {
    return LazyLoadingResult<T>(
      items: items ?? this.items,
      hasMore: hasMore ?? this.hasMore,
      totalCount: totalCount ?? this.totalCount,
      error: error ?? this.error,
    );
  }
}

/// Lazy loading manager for temple lists with intelligent prefetching
class LazyLoadingManager {
  static final LazyLoadingManager _instance = LazyLoadingManager._internal();
  factory LazyLoadingManager() => _instance;
  LazyLoadingManager._internal();

  final UserTempleService _templeService = UserTempleService();
  final LazyLoadingConfig _config = const LazyLoadingConfig();

  // Active loading sessions
  final Map<String, _LazyLoadingSession> _sessions = {};

  /// Initialize the lazy loading manager
  Future<void> initialize() async {
    await _templeService.initialize();

    if (kDebugMode) {
      debugPrint('LazyLoadingManager: Initialized');
    }
  }

  /// Create a new lazy loading session for temple search
  String createSearchSession(
    String query, {
    TempleFilters? filters,
    LazyLoadingConfig? config,
  }) {
    final sessionId = _generateSessionId('search', query, filters);
    final sessionConfig = config ?? _config;

    _sessions[sessionId] = _LazyLoadingSession(
      sessionId: sessionId,
      config: sessionConfig,
      loadFunction: (page, pageSize) =>
          _loadSearchResults(query, filters, page, pageSize),
    );

    if (kDebugMode) {
      debugPrint('LazyLoadingManager: Created search session $sessionId');
    }

    return sessionId;
  }

  /// Create a new lazy loading session for nearby temples
  String createNearbySession(
    Location userLocation,
    double radiusKm, {
    TempleFilters? additionalFilters,
    LazyLoadingConfig? config,
  }) {
    final sessionId = _generateSessionId(
      'nearby',
      userLocation.toString(),
      additionalFilters,
    );
    final sessionConfig = config ?? _config;

    _sessions[sessionId] = _LazyLoadingSession(
      sessionId: sessionId,
      config: sessionConfig,
      loadFunction: (page, pageSize) => _loadNearbyResults(
        userLocation,
        radiusKm,
        additionalFilters,
        page,
        pageSize,
      ),
    );

    if (kDebugMode) {
      debugPrint('LazyLoadingManager: Created nearby session $sessionId');
    }

    return sessionId;
  }

  /// Create a new lazy loading session for recommended temples
  String createRecommendedSession(
    UserPreferences preferences, {
    Location? userLocation,
    LazyLoadingConfig? config,
  }) {
    final sessionId = _generateSessionId(
      'recommended',
      preferences.userId,
      null,
    );
    final sessionConfig = config ?? _config;

    _sessions[sessionId] = _LazyLoadingSession(
      sessionId: sessionId,
      config: sessionConfig,
      loadFunction: (page, pageSize) =>
          _loadRecommendedResults(preferences, userLocation, page, pageSize),
    );

    if (kDebugMode) {
      debugPrint('LazyLoadingManager: Created recommended session $sessionId');
    }

    return sessionId;
  }

  /// Load initial data for a session
  Future<LazyLoadingResult<Temple>> loadInitial(String sessionId) async {
    final session = _sessions[sessionId];
    if (session == null) {
      return const LazyLoadingResult(
        items: [],
        hasMore: false,
        error: 'Session not found',
      );
    }

    return await session.loadInitial();
  }

  /// Load more data for a session
  Future<LazyLoadingResult<Temple>> loadMore(String sessionId) async {
    final session = _sessions[sessionId];
    if (session == null) {
      return const LazyLoadingResult(
        items: [],
        hasMore: false,
        error: 'Session not found',
      );
    }

    return await session.loadMore();
  }

  /// Check if more data should be loaded based on current position
  bool shouldLoadMore(String sessionId, int currentIndex) {
    final session = _sessions[sessionId];
    if (session == null) return false;

    return session.shouldLoadMore(currentIndex);
  }

  /// Get current loading state for a session
  LazyLoadingState getLoadingState(String sessionId) {
    final session = _sessions[sessionId];
    return session?.state ?? LazyLoadingState.idle;
  }

  /// Get current items for a session
  List<Temple> getCurrentItems(String sessionId) {
    final session = _sessions[sessionId];
    return session?.allItems ?? [];
  }

  /// Refresh a session (reload from beginning)
  Future<LazyLoadingResult<Temple>> refresh(String sessionId) async {
    final session = _sessions[sessionId];
    if (session == null) {
      return const LazyLoadingResult(
        items: [],
        hasMore: false,
        error: 'Session not found',
      );
    }

    return await session.refresh();
  }

  /// Dispose a session and free resources
  void disposeSession(String sessionId) {
    final session = _sessions.remove(sessionId);
    if (session != null) {
      session.dispose();

      if (kDebugMode) {
        debugPrint('LazyLoadingManager: Disposed session $sessionId');
      }
    }
  }

  /// Get session statistics
  Map<String, dynamic> getSessionStatistics(String sessionId) {
    final session = _sessions[sessionId];
    return session?.getStatistics() ?? {};
  }

  /// Get all session statistics
  Map<String, dynamic> getAllStatistics() {
    return {
      'activeSessions': _sessions.length,
      'sessions': _sessions.map(
        (key, session) => MapEntry(key, session.getStatistics()),
      ),
    };
  }

  /// Clear all sessions
  void clearAllSessions() {
    for (final session in _sessions.values) {
      session.dispose();
    }
    _sessions.clear();

    if (kDebugMode) {
      debugPrint('LazyLoadingManager: Cleared all sessions');
    }
  }

  // Private helper methods

  /// Generate session ID
  String _generateSessionId(
    String type,
    String identifier,
    TempleFilters? filters,
  ) {
    final filterHash = filters?.hashCode ?? 0;
    return '${type}_${identifier.hashCode}_${filterHash}_${DateTime.now().millisecondsSinceEpoch}';
  }

  /// Load search results for a specific page
  Future<List<Temple>> _loadSearchResults(
    String query,
    TempleFilters? filters,
    int page,
    int pageSize,
  ) async {
    // For now, we'll load all results and paginate client-side
    // In a production app, you'd want server-side pagination
    final allResults = await _templeService.searchTemples(
      query,
      filters: filters,
    );

    final startIndex = page * pageSize;
    final endIndex = (startIndex + pageSize).clamp(0, allResults.length);

    if (startIndex >= allResults.length) {
      return [];
    }

    return allResults.sublist(startIndex, endIndex);
  }

  /// Load nearby results for a specific page
  Future<List<Temple>> _loadNearbyResults(
    Location userLocation,
    double radiusKm,
    TempleFilters? additionalFilters,
    int page,
    int pageSize,
  ) async {
    final allResults = await _templeService.getNearbyTemples(
      userLocation,
      radiusKm,
      additionalFilters: additionalFilters,
    );

    final startIndex = page * pageSize;
    final endIndex = (startIndex + pageSize).clamp(0, allResults.length);

    if (startIndex >= allResults.length) {
      return [];
    }

    return allResults.sublist(startIndex, endIndex);
  }

  /// Load recommended results for a specific page
  Future<List<Temple>> _loadRecommendedResults(
    UserPreferences preferences,
    Location? userLocation,
    int page,
    int pageSize,
  ) async {
    final limit = (page + 1) * pageSize;
    final allResults = await _templeService.getRecommendedTemples(
      preferences,
      userLocation: userLocation,
      limit: limit,
    );

    final startIndex = page * pageSize;
    final endIndex = (startIndex + pageSize).clamp(0, allResults.length);

    if (startIndex >= allResults.length) {
      return [];
    }

    return allResults.sublist(startIndex, endIndex);
  }
}

/// Internal lazy loading session
class _LazyLoadingSession {
  final String sessionId;
  final LazyLoadingConfig config;
  final Future<List<Temple>> Function(int page, int pageSize) loadFunction;

  LazyLoadingState _state = LazyLoadingState.idle;
  final List<Temple> _allItems = [];
  final Map<int, List<Temple>> _pageCache = {};
  int _currentPage = -1;
  bool _hasMore = true;
  String? _lastError;
  DateTime? _lastLoadTime;
  int _totalLoadedItems = 0;

  _LazyLoadingSession({
    required this.sessionId,
    required this.config,
    required this.loadFunction,
  });

  LazyLoadingState get state => _state;
  List<Temple> get allItems => List.unmodifiable(_allItems);
  bool get hasMore => _hasMore;
  String? get lastError => _lastError;

  /// Load initial data
  Future<LazyLoadingResult<Temple>> loadInitial() async {
    if (_state == LazyLoadingState.loading) {
      return LazyLoadingResult(
        items: _allItems,
        hasMore: _hasMore,
        error: 'Already loading',
      );
    }

    _state = LazyLoadingState.loading;
    _lastError = null;

    try {
      final items = await loadFunction(
        0,
        config.pageSize,
      ).timeout(config.loadTimeout);

      _pageCache[0] = items;
      _allItems.clear();
      _allItems.addAll(items);
      _currentPage = 0;
      _hasMore = items.length >= config.pageSize;
      _lastLoadTime = DateTime.now();
      _totalLoadedItems = items.length;

      _state = LazyLoadingState.idle;

      if (kDebugMode) {
        debugPrint(
          'LazyLoadingSession: Loaded initial ${items.length} items for $sessionId',
        );
      }

      return LazyLoadingResult(
        items: _allItems,
        hasMore: _hasMore,
        totalCount: _totalLoadedItems,
      );
    } catch (e) {
      _state = LazyLoadingState.error;
      _lastError = e.toString();

      if (kDebugMode) {
        debugPrint('LazyLoadingSession: Error loading initial data - $e');
      }

      return LazyLoadingResult(
        items: _allItems,
        hasMore: false,
        error: e.toString(),
      );
    }
  }

  /// Load more data
  Future<LazyLoadingResult<Temple>> loadMore() async {
    if (_state == LazyLoadingState.loading ||
        _state == LazyLoadingState.loadingMore ||
        !_hasMore) {
      return LazyLoadingResult(items: _allItems, hasMore: _hasMore);
    }

    _state = LazyLoadingState.loadingMore;
    _lastError = null;

    try {
      final nextPage = _currentPage + 1;

      // Check cache first
      List<Temple> items;
      if (_pageCache.containsKey(nextPage)) {
        items = _pageCache[nextPage]!;
        if (kDebugMode) {
          debugPrint(
            'LazyLoadingSession: Using cached page $nextPage for $sessionId',
          );
        }
      } else {
        items = await loadFunction(
          nextPage,
          config.pageSize,
        ).timeout(config.loadTimeout);

        // Cache the page
        _pageCache[nextPage] = items;

        // Limit cache size
        if (_pageCache.length > config.maxCachedPages) {
          final oldestPage = _pageCache.keys.reduce((a, b) => a < b ? a : b);
          _pageCache.remove(oldestPage);
        }
      }

      _allItems.addAll(items);
      _currentPage = nextPage;
      _hasMore = items.length >= config.pageSize;
      _lastLoadTime = DateTime.now();
      _totalLoadedItems += items.length;

      _state = LazyLoadingState.idle;

      if (kDebugMode) {
        debugPrint(
          'LazyLoadingSession: Loaded ${items.length} more items (page $nextPage) for $sessionId',
        );
      }

      return LazyLoadingResult(
        items: _allItems,
        hasMore: _hasMore,
        totalCount: _totalLoadedItems,
      );
    } catch (e) {
      _state = LazyLoadingState.error;
      _lastError = e.toString();

      if (kDebugMode) {
        debugPrint('LazyLoadingSession: Error loading more data - $e');
      }

      return LazyLoadingResult(
        items: _allItems,
        hasMore: _hasMore,
        error: e.toString(),
      );
    }
  }

  /// Check if more data should be loaded
  bool shouldLoadMore(int currentIndex) {
    if (!_hasMore || _state != LazyLoadingState.idle) {
      return false;
    }

    final threshold = _allItems.length - config.preloadThreshold;
    return currentIndex >= threshold;
  }

  /// Refresh data
  Future<LazyLoadingResult<Temple>> refresh() async {
    _allItems.clear();
    _pageCache.clear();
    _currentPage = -1;
    _hasMore = true;
    _lastError = null;
    _totalLoadedItems = 0;

    return await loadInitial();
  }

  /// Get session statistics
  Map<String, dynamic> getStatistics() {
    return {
      'sessionId': sessionId,
      'state': _state.toString(),
      'currentPage': _currentPage,
      'totalItems': _allItems.length,
      'cachedPages': _pageCache.length,
      'hasMore': _hasMore,
      'lastError': _lastError,
      'lastLoadTime': _lastLoadTime?.toIso8601String(),
      'totalLoadedItems': _totalLoadedItems,
    };
  }

  /// Dispose session resources
  void dispose() {
    _allItems.clear();
    _pageCache.clear();
    _state = LazyLoadingState.idle;
  }
}
