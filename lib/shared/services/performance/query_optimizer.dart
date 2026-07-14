import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../models/temple_filters.dart';
import '../../models/temple.dart';

/// Query optimization strategy
enum QueryStrategy { simple, indexed, composite, paginated, cached }

/// Query optimization configuration
class QueryOptimizationConfig {
  final int maxResultsPerQuery;
  final Duration queryTimeout;
  final bool enableQueryCaching;
  final int maxCachedQueries;

  const QueryOptimizationConfig({
    this.maxResultsPerQuery = 500,
    this.queryTimeout = const Duration(seconds: 15),
    this.enableQueryCaching = true,
    this.maxCachedQueries = 20,
  });
}

/// Database query optimizer for better performance
class QueryOptimizer {
  static final QueryOptimizer _instance = QueryOptimizer._internal();
  factory QueryOptimizer() => _instance;
  QueryOptimizer._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final QueryOptimizationConfig _config = const QueryOptimizationConfig();

  // Query optimization patterns
  final Map<String, QueryStrategy> _queryStrategies = {};
  final Set<String> _slowQueries = {};

  /// Initialize the query optimizer
  Future<void> initialize() async {
    // Set up Firestore settings for better performance
    _firestore.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );

    if (kDebugMode) {
      debugPrint('QueryOptimizer: Initialized');
    }
  }

  /// Optimize temple search query
  Future<QuerySnapshot<Map<String, dynamic>>> optimizeTempleSearchQuery(
    String query,
    TempleFilters? filters, {
    DocumentSnapshot? startAfterDoc,
  }) async {
    final queryId = _generateQueryId('temple_search', {
      'query': query,
      'filters': filters?.toJson() ?? {},
    });

    final stopwatch = Stopwatch()..start();

    try {
      // Build optimized Firestore query
      Query<Map<String, dynamic>> firestoreQuery = _buildOptimizedQuery(
        'temples',
        query,
        filters,
      );

      // Apply cursor for real pagination when provided
      if (startAfterDoc != null) {
        firestoreQuery = firestoreQuery.startAfterDocument(startAfterDoc);
      }

      // Execute query with timeout
      final result = await firestoreQuery
          .get(const GetOptions(source: Source.serverAndCache))
          .timeout(_config.queryTimeout);

      stopwatch.stop();

      // Update query strategy based on performance
      _updateQueryStrategy(queryId, stopwatch.elapsed, result.docs.length);

      if (kDebugMode) {
        debugPrint(
          'QueryOptimizer: Temple search completed in ${stopwatch.elapsedMilliseconds}ms '
          '(${result.docs.length} results, fromCache: ${result.metadata.isFromCache})',
        );
      }

      return result;
    } catch (e) {
      stopwatch.stop();

      if (kDebugMode) {
        debugPrint(
          'QueryOptimizer: Query failed after ${stopwatch.elapsedMilliseconds}ms - $e',
        );
      }

      rethrow;
    }
  }

  /// Optimize nearby temples query
  Future<QuerySnapshot<Map<String, dynamic>>> optimizeNearbyTemplesQuery(
    Location userLocation,
    double radiusKm,
    TempleFilters? additionalFilters,
  ) async {
    final stopwatch = Stopwatch()..start();

    try {
      // For nearby queries, we need to use a different approach since Firestore
      // doesn't support geospatial queries directly
      Query<Map<String, dynamic>> firestoreQuery = _firestore
          .collection('temples')
          .where('isActive', isEqualTo: true);

      // Apply additional filters
      if (additionalFilters != null) {
        firestoreQuery = _applyFiltersToQuery(
          firestoreQuery,
          additionalFilters,
        );
      }

      // Limit results for performance
      firestoreQuery = firestoreQuery.limit(_config.maxResultsPerQuery);

      final result = await firestoreQuery
          .get(const GetOptions(source: Source.serverAndCache))
          .timeout(_config.queryTimeout);

      stopwatch.stop();

      if (kDebugMode) {
        debugPrint(
          'QueryOptimizer: Nearby temples query completed in ${stopwatch.elapsedMilliseconds}ms '
          '(${result.docs.length} results, fromCache: ${result.metadata.isFromCache})',
        );
      }

      return result;
    } catch (e) {
      stopwatch.stop();

      if (kDebugMode) {
        debugPrint(
          'QueryOptimizer: Nearby query failed after ${stopwatch.elapsedMilliseconds}ms - $e',
        );
      }

      rethrow;
    }
  }

  /// Optimize single temple query
  Future<DocumentSnapshot<Map<String, dynamic>>> optimizeTempleDetailQuery(
    String templeId,
  ) async {
    final stopwatch = Stopwatch()..start();

    try {
      final result = await _firestore
          .collection('temples')
          .doc(templeId)
          .get(const GetOptions(source: Source.serverAndCache))
          .timeout(_config.queryTimeout);

      stopwatch.stop();

      if (kDebugMode) {
        debugPrint(
          'QueryOptimizer: Temple detail query completed in ${stopwatch.elapsedMilliseconds}ms '
          '(exists: ${result.exists}, fromCache: ${result.metadata.isFromCache})',
        );
      }

      return result;
    } catch (e) {
      stopwatch.stop();

      if (kDebugMode) {
        debugPrint(
          'QueryOptimizer: Temple detail query failed after ${stopwatch.elapsedMilliseconds}ms - $e',
        );
      }

      rethrow;
    }
  }

  /// Build optimized Firestore query
  Query<Map<String, dynamic>> _buildOptimizedQuery(
    String collection,
    String searchQuery,
    TempleFilters? filters,
  ) {
    Query<Map<String, dynamic>> query = _firestore.collection(collection);

    // Always filter by active status first (most selective)
    query = query.where('isActive', isEqualTo: filters?.isActive ?? true);

    // Apply filters in order of selectivity
    if (filters != null) {
      query = _applyFiltersToQuery(query, filters);
    }

    // Limit results for performance
    query = query.limit(_config.maxResultsPerQuery);

    return query;
  }

  /// Apply filters to query in optimized order
  Query<Map<String, dynamic>> _applyFiltersToQuery(
    Query<Map<String, dynamic>> query,
    TempleFilters filters,
  ) {
    // Apply most selective filters first

    // 1. Live darshan filter (if specified)
    if (filters.hasLiveDarshan == true) {
      query = query.where('liveDarshan.isConfiguredByAdmin', isEqualTo: true);
    }

    // 2. State filter (more selective than city usually)
    if (filters.states?.isNotEmpty == true) {
      query = query.where(
        'location.state',
        whereIn: filters.states!.take(10).toList(),
      );
    }

    // 3. City filter
    if (filters.cities?.isNotEmpty == true) {
      query = query.where(
        'location.city',
        whereIn: filters.cities!.take(10).toList(),
      );
    }

    // 4. Tradition filter
    if (filters.traditions?.isNotEmpty == true) {
      query = query.where(
        'traditions',
        arrayContainsAny: filters.traditions!.take(10).toList(),
      );
    }

    // 5. Features filter (least selective usually)
    if (filters.features?.isNotEmpty == true) {
      query = query.where(
        'features',
        arrayContainsAny: filters.features!.take(10).toList(),
      );
    }

    return query;
  }

  /// Generate query ID for caching and metrics
  String _generateQueryId(String type, Map<String, dynamic> params) {
    final paramString = params.entries
        .map((e) => '${e.key}:${e.value}')
        .join('|');
    return '${type}_${paramString.hashCode}';
  }

  /// Update query strategy based on performance
  void _updateQueryStrategy(
    String queryId,
    Duration executionTime,
    int resultCount,
  ) {
    QueryStrategy strategy = QueryStrategy.simple;

    if (executionTime.inMilliseconds > 3000) {
      strategy = QueryStrategy.cached;
    } else if (executionTime.inMilliseconds > 1000) {
      strategy = QueryStrategy.indexed;
    } else if (resultCount > 50) {
      strategy = QueryStrategy.paginated;
    }

    _queryStrategies[queryId] = strategy;
  }

  /// Get slow queries
  List<String> getSlowQueries() {
    return _slowQueries.toList();
  }

  /// Clear query metrics
  void clearMetrics() {
    _queryStrategies.clear();
    _slowQueries.clear();

    if (kDebugMode) {
      debugPrint('QueryOptimizer: Cleared all metrics');
    }
  }

  /// Get optimizer statistics
  Map<String, dynamic> getStatistics() {
    return {
      'queryStrategiesCount': _queryStrategies.length,
      'slowQueriesCount': _slowQueries.length,
      'config': {
        'maxResultsPerQuery': _config.maxResultsPerQuery,
        'queryTimeoutMs': _config.queryTimeout.inMilliseconds,
        'enableQueryCaching': _config.enableQueryCaching,
      },
    };
  }
}
