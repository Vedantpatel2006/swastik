import 'dart:async';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../../shared/models/temple.dart';
import '../../../shared/models/temple_filters.dart';
import '../../../shared/models/user_preferences.dart';
import '../../../shared/services/cache/data_cache_manager.dart';
import '../../../shared/services/cache/search_cache_manager.dart';
import '../../../shared/services/offline/offline_manager.dart';
import '../../../shared/services/performance/query_optimizer.dart';

/// Service for user-side temple operations with search, filtering, and caching
class UserTempleService {
  static final UserTempleService _instance = UserTempleService._internal();
  factory UserTempleService() => _instance;
  UserTempleService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Use singleton instances to prevent multiple initializations
  DataCacheManager? _cacheManager;
  SearchCacheManager? _searchCache;
  OfflineManager? _offlineManager;
  QueryOptimizer? _queryOptimizer;

  // Lazy getters for services
  DataCacheManager get cacheManager => _cacheManager ??= DataCacheManager();
  SearchCacheManager get searchCache => _searchCache ??= SearchCacheManager();
  OfflineManager get offlineManager => _offlineManager ??= OfflineManager();
  QueryOptimizer get queryOptimizer => _queryOptimizer ??= QueryOptimizer();

  static const String _templesCollection = 'temples';
  static const String _cacheKeyPrefix = 'user_temples';
  static const Duration _defaultCacheTTL = Duration(hours: 2);

  /// Initialize the service
  Future<void> initialize() async {
    // Only initialize if not already done
    if (_cacheManager == null) {
      await cacheManager.initialize();
    }
    if (_searchCache == null) {
      await searchCache.initialize();
    }
    if (_offlineManager == null) {
      await offlineManager.initialize();
    }
    if (_queryOptimizer == null) {
      await queryOptimizer.initialize();
    }

    // Set up offline data sync listeners
    offlineManager.syncStatusStream.listen((status) {
      if (status == SyncStatus.synced) {
        // Clear cache to force refresh with latest data
        _clearTempleCache();
        searchCache.clear();
      }
    });
  }

  /// Search temples with query filtering and performance optimizations
  /// Includes memory usage tracking and automatic optimization triggers
  Future<List<Temple>> searchTemples(
    String query, {
    TempleFilters? filters,
    bool useCache = true,
    int? limit,
    int? offset,
  }) async {
    final operationId =
        'search_${query.hashCode}_${DateTime.now().millisecondsSinceEpoch}';

    if (kDebugMode) {
      debugPrint(
        'UserTempleService.searchTemples: Starting search operation $operationId',
      );
    }

    try {
      // Implement query result pagination for memory efficiency
      final effectiveLimit = limit;

      // Try search cache first if enabled
      if (useCache) {
        final cachedResults = await searchCache.getCachedSearchResults(
          query,
          filters: filters,
        );
        if (cachedResults != null) {
          // Apply distance filtering to cached results if location is provided
          var results = cachedResults;
          if (filters?.userLocation != null) {
            results = _applyDistanceFiltering(results, filters!);
          }

          // Apply pagination to cached results
          final paginatedResults = _applyPagination(results, limit, offset);

          if (kDebugMode) {
            debugPrint(
              'UserTempleService: Returning ${paginatedResults.length} cached search results',
            );
          }
          return paginatedResults;
        }
      }

      // Use optimized query execution with performance monitoring
      final queryStartTime = DateTime.now();
      final querySnapshot = await queryOptimizer.optimizeTempleSearchQuery(
        query,
        filters,
      );
      final queryDuration = DateTime.now().difference(queryStartTime);

      // Convert to Temple objects with batch processing for large datasets
      List<Temple> temples;
      if (querySnapshot.docs.length > 500) {
        temples = await _batchProcessTemples(querySnapshot.docs);
      } else {
        temples = [];
        int successfulParses = 0;
        int fallbackCreations = 0;
        int totalFailures = 0;

        for (final doc in querySnapshot.docs) {
          try {
            final temple = Temple.fromFirestore(doc);
            temples.add(temple);
            successfulParses++;
          } catch (e) {
            if (kDebugMode) {
              debugPrint(
                'UserTempleService.searchTemples: Error parsing temple ${doc.id}: $e',
              );
              debugPrint('Temple data: ${doc.data()}');
            }

            // Try to create fallback temple
            final fallbackTemple = _createFallbackTemple(doc);
            if (fallbackTemple != null) {
              temples.add(fallbackTemple);
              fallbackCreations++;
            } else {
              totalFailures++;
            }
          }
        }

        if (kDebugMode && (fallbackCreations > 0 || totalFailures > 0)) {
          debugPrint(
            'UserTempleService.searchTemples: Parsing summary - '
            'Successful: $successfulParses, Fallbacks: $fallbackCreations, Failures: $totalFailures',
          );
        }
      }

      // Apply client-side text search filtering with optimization
      if (query.isNotEmpty) {
        temples = _filterTemplesByTextOptimized(temples, query);
      }

      // Apply distance filtering and calculate distances
      if (filters?.userLocation != null) {
        temples = _applyDistanceFiltering(temples, filters!);
      }

      // Apply sorting with performance optimization
      temples = _sortTemples(
        temples,
        filters?.sortBy ?? SortOption.name,
        filters?.ascending ?? true,
      );

      // Apply pagination with effective limit
      temples = _applyPagination(temples, effectiveLimit, offset);

      // Cache results in search cache with performance metadata
      if (useCache && temples.isNotEmpty) {
        try {
          await searchCache.cacheSearchResults(
            query,
            temples,
            filters: filters,
            metadata: {
              'resultCount': temples.length,
              'executionTime': DateTime.now().toIso8601String(),
              'queryDurationMs': queryDuration.inMilliseconds,
              'fromCache': false,
              'optimized': temples.length > 100,
            },
          );
        } catch (e) {
          if (kDebugMode) {
            debugPrint('UserTempleService: Error caching search results - $e');
          }
          // Continue without caching if there's a serialization error
        }
      }

      if (kDebugMode) {
        debugPrint(
          'UserTempleService: Found ${temples.length} temples for query: "$query" '
          '(${queryDuration.inMilliseconds}ms)',
        );
      }

      if (kDebugMode) {
        debugPrint(
          'UserTempleService.searchTemples: Completed search operation $operationId',
        );
      }

      return temples;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('UserTempleService: Error searching temples - $e');
      }

      // Try to return cached search results as fallback
      final cachedResults = await searchCache.getCachedSearchResults(
        query,
        filters: filters,
      );
      if (cachedResults != null) {
        return _applyPagination(cachedResults, limit, offset);
      }

      rethrow;
    }
  }

  /// Apply pagination to temple results
  List<Temple> _applyPagination(List<Temple> temples, int? limit, int? offset) {
    if (offset != null && offset > 0) {
      temples = temples.skip(offset).toList();
    }
    if (limit != null && limit > 0) {
      temples = temples.take(limit).toList();
    }
    return temples;
  }

  /// Batch process temples for large datasets to avoid memory issues
  /// Uses enhanced fallback temple creation for parsing failures

  Future<List<Temple>> _batchProcessTemples(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) async {
    // Use standard batch size
    const batchSize = 50;

    final temples = <Temple>[];
    int successfulParses = 0;
    int fallbackCreations = 0;
    int totalFailures = 0;

    if (kDebugMode) {
      debugPrint(
        'UserTempleService._batchProcessTemples: Processing ${docs.length} temples in batches of $batchSize',
      );
    }

    for (int i = 0; i < docs.length; i += batchSize) {
      final batch = docs.skip(i).take(batchSize);
      final batchTemples = <Temple>[];

      for (final doc in batch) {
        try {
          final temple = Temple.fromFirestore(doc);
          batchTemples.add(temple);
          successfulParses++;
        } catch (e) {
          if (kDebugMode) {
            debugPrint(
              'UserTempleService._batchProcessTemples: Error parsing temple ${doc.id}: $e',
            );
          }

          // Try to create fallback temple
          final fallbackTemple = _createFallbackTemple(doc);
          if (fallbackTemple != null) {
            batchTemples.add(fallbackTemple);
            fallbackCreations++;
          } else {
            totalFailures++;
            if (kDebugMode) {
              debugPrint(
                'UserTempleService._batchProcessTemples: Failed to create fallback temple for ${doc.id}',
              );
            }
          }
        }
      }

      temples.addAll(batchTemples);

      // Small delay to prevent blocking the UI thread
      if (i + batchSize < docs.length) {
        await Future.delayed(const Duration(milliseconds: 1));
      }
    }

    if (kDebugMode) {
      debugPrint(
        'UserTempleService._batchProcessTemples: Completed processing. '
        'Successful: $successfulParses, Fallbacks: $fallbackCreations, Failures: $totalFailures',
      );
    }

    return temples;
  }

  /// Create a fallback temple object when parsing fails gracefully
  /// Handles parsing failures by creating a minimal temple with available data
  /// and comprehensive error logging for debugging
  Temple? _createFallbackTemple(DocumentSnapshot doc) {
    final templeId = doc.id;

    try {
      final data = doc.data();

      // Log detailed error information about the document structure
      if (data == null) {
        if (kDebugMode) {
          debugPrint(
            'UserTempleService._createFallbackTemple: Document data is null for temple $templeId',
          );
        }
        return _createMinimalFallbackTemple(templeId, null);
      }

      Map<String, dynamic> docData;
      if (data is Map<String, dynamic>) {
        docData = data;
      } else if (data is Map) {
        docData = Map<String, dynamic>.from(data);
        if (kDebugMode) {
          debugPrint(
            'UserTempleService._createFallbackTemple: Converted Map to Map<String, dynamic> for temple $templeId',
          );
        }
      } else {
        if (kDebugMode) {
          debugPrint(
            'UserTempleService._createFallbackTemple: Document data is not a Map for temple $templeId. '
            'Type: ${data.runtimeType}, Value: $data',
          );
        }
        return _createMinimalFallbackTemple(templeId, null);
      }

      // Log the fields that are available vs missing
      _logAvailableFields(templeId, docData);

      // Create fallback temple with safe field extraction
      return Temple(
        id: templeId,
        name: _safeExtractString(docData, 'name', templeId) ?? 'Unknown Temple',
        description:
            _safeExtractString(docData, 'description', templeId) ??
            'Temple data could not be loaded properly. Please try refreshing.',
        location: _safeExtractLocation(docData, 'location', templeId),
        images: _safeExtractStringList(docData, 'images', templeId),
        traditions: _safeExtractStringList(docData, 'traditions', templeId),
        timings: _safeExtractStringMap(docData, 'timings', templeId),
        contact: _safeExtractContactInfo(docData, 'contact', templeId),
        features: _safeExtractStringList(docData, 'features', templeId),
        isActive: _safeExtractBool(docData, 'isActive', templeId) ?? true,
        createdAt:
            _safeExtractDateTime(docData, 'createdAt', templeId) ??
            DateTime.now(),
        updatedAt:
            _safeExtractDateTime(docData, 'updatedAt', templeId) ??
            DateTime.now(),
        // Set safe defaults for other fields
        acceptsBookings:
            _safeExtractBool(docData, 'acceptsBookings', templeId) ?? false,
        acceptsDonations:
            _safeExtractBool(docData, 'acceptsDonations', templeId) ?? false,
        allowsReviews:
            _safeExtractBool(docData, 'allowsReviews', templeId) ?? true,
        averageRating:
            _safeExtractDouble(docData, 'averageRating', templeId) ?? 0.0,
        totalReviews: _safeExtractInt(docData, 'totalReviews', templeId) ?? 0,
        visitCount: 0, // Reset for fallback temples
      );
    } catch (e, stackTrace) {
      // Comprehensive error logging with stack trace
      if (kDebugMode) {
        debugPrint(
          'UserTempleService._createFallbackTemple: Critical error creating fallback temple for $templeId: $e',
        );
        debugPrint('Stack trace: $stackTrace');
      }

      // Last resort - create absolute minimal temple
      return _createMinimalFallbackTemple(templeId, e.toString());
    }
  }

  /// Create a minimal fallback temple when all else fails
  Temple _createMinimalFallbackTemple(String templeId, String? errorDetails) {
    if (kDebugMode) {
      debugPrint(
        'UserTempleService._createMinimalFallbackTemple: Creating minimal temple for $templeId. '
        'Error: $errorDetails',
      );
    }

    return Temple(
      id: templeId,
      name: 'Temple (ID: $templeId)',
      description: errorDetails != null
          ? 'Temple data is corrupted and could not be loaded. Error: $errorDetails'
          : 'Temple data is not available. Please try refreshing the app.',
      location: const Location(
        latitude: 0.0,
        longitude: 0.0,
        address: 'Location not available',
      ),
      contact: const ContactInfo(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      isActive: true, // Assume active so it shows up in lists
    );
  }

  /// Log available vs missing fields for debugging
  void _logAvailableFields(String templeId, Map<String, dynamic> data) {
    if (!kDebugMode) return;

    final requiredFields = ['name', 'description', 'location', 'contact'];
    final optionalFields = [
      'images',
      'traditions',
      'timings',
      'features',
      'isActive',
    ];

    final availableRequired = <String>[];
    final missingRequired = <String>[];
    final availableOptional = <String>[];
    final missingOptional = <String>[];

    for (final field in requiredFields) {
      if (data.containsKey(field) && data[field] != null) {
        availableRequired.add(field);
      } else {
        missingRequired.add(field);
      }
    }

    for (final field in optionalFields) {
      if (data.containsKey(field) && data[field] != null) {
        availableOptional.add(field);
      } else {
        missingOptional.add(field);
      }
    }

    debugPrint(
      'UserTempleService: Temple $templeId field check:\n'
      '  Available required: ${availableRequired.join(', ')}\n'
      '  Missing required: ${missingRequired.join(', ')}\n'
      '  Available optional: ${availableOptional.join(', ')}\n'
      '  Missing optional: ${missingOptional.join(', ')}',
    );
  }

  /// Safe field extraction methods with detailed error logging
  String? _safeExtractString(
    Map<String, dynamic> data,
    String field,
    String templeId,
  ) {
    try {
      final value = data[field];
      if (value == null) return null;
      if (value is String) return value.isNotEmpty ? value : null;
      return value.toString();
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          'UserTempleService._safeExtractString: Error extracting $field for temple $templeId: $e. '
          'Value type: ${data[field]?.runtimeType}, Value: ${data[field]}',
        );
      }
      return null;
    }
  }

  List<String> _safeExtractStringList(
    Map<String, dynamic> data,
    String field,
    String templeId,
  ) {
    try {
      final value = data[field];
      if (value == null) return [];
      if (value is List<String>) return value;
      if (value is List) return value.map((item) => item.toString()).toList();
      if (value is String) return [value]; // Single string as list
      return [];
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          'UserTempleService._safeExtractStringList: Error extracting $field for temple $templeId: $e. '
          'Value type: ${data[field]?.runtimeType}, Value: ${data[field]}',
        );
      }
      return [];
    }
  }

  Map<String, String> _safeExtractStringMap(
    Map<String, dynamic> data,
    String field,
    String templeId,
  ) {
    try {
      final value = data[field];
      if (value == null) return {};
      if (value is Map<String, String>) return value;
      if (value is Map) {
        return value.map(
          (key, val) => MapEntry(key.toString(), val.toString()),
        );
      }
      return {};
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          'UserTempleService._safeExtractStringMap: Error extracting $field for temple $templeId: $e. '
          'Value type: ${data[field]?.runtimeType}, Value: ${data[field]}',
        );
      }
      return {};
    }
  }

  Location _safeExtractLocation(
    Map<String, dynamic> data,
    String field,
    String templeId,
  ) {
    try {
      final value = data[field];
      if (value == null) {
        if (kDebugMode) {
          debugPrint(
            'UserTempleService._safeExtractLocation: No location data for temple $templeId',
          );
        }
        return const Location(latitude: 0.0, longitude: 0.0);
      }

      // Use the enhanced Location.fromDynamic method
      return Location.fromDynamic(value, templeId: templeId);
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          'UserTempleService._safeExtractLocation: Error extracting location for temple $templeId: $e. '
          'Value type: ${data[field]?.runtimeType}, Value: ${data[field]}',
        );
      }
      return const Location(latitude: 0.0, longitude: 0.0);
    }
  }

  ContactInfo _safeExtractContactInfo(
    Map<String, dynamic> data,
    String field,
    String templeId,
  ) {
    try {
      final value = data[field];
      if (value == null) return const ContactInfo();
      if (value is Map) {
        final map = Map<String, dynamic>.from(value);
        return ContactInfo(
          phone: _safeExtractString(map, 'phone', templeId),
          email: _safeExtractString(map, 'email', templeId),
          website: _safeExtractString(map, 'website', templeId),
          socialMedia: map['socialMedia'] != null
              ? Map<String, String>.from(map['socialMedia'] as Map)
              : null,
        );
      }
      return const ContactInfo();
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          'UserTempleService._safeExtractContactInfo: Error extracting contact for temple $templeId: $e. '
          'Value type: ${data[field]?.runtimeType}, Value: ${data[field]}',
        );
      }
      return const ContactInfo();
    }
  }

  bool? _safeExtractBool(
    Map<String, dynamic> data,
    String field,
    String templeId,
  ) {
    try {
      final value = data[field];
      if (value == null) return null;
      if (value is bool) return value;
      if (value is String) {
        final lower = value.toLowerCase();
        return lower == 'true' || lower == '1' || lower == 'yes';
      }
      if (value is int) return value != 0;
      return null;
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          'UserTempleService._safeExtractBool: Error extracting $field for temple $templeId: $e. '
          'Value type: ${data[field]?.runtimeType}, Value: ${data[field]}',
        );
      }
      return null;
    }
  }

  double? _safeExtractDouble(
    Map<String, dynamic> data,
    String field,
    String templeId,
  ) {
    try {
      final value = data[field];
      if (value == null) return null;
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value);
      return null;
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          'UserTempleService._safeExtractDouble: Error extracting $field for temple $templeId: $e. '
          'Value type: ${data[field]?.runtimeType}, Value: ${data[field]}',
        );
      }
      return null;
    }
  }

  int? _safeExtractInt(
    Map<String, dynamic> data,
    String field,
    String templeId,
  ) {
    try {
      final value = data[field];
      if (value == null) return null;
      if (value is int) return value;
      if (value is double) return value.toInt();
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value);
      return null;
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          'UserTempleService._safeExtractInt: Error extracting $field for temple $templeId: $e. '
          'Value type: ${data[field]?.runtimeType}, Value: ${data[field]}',
        );
      }
      return null;
    }
  }

  DateTime? _safeExtractDateTime(
    Map<String, dynamic> data,
    String field,
    String templeId,
  ) {
    try {
      final value = data[field];
      if (value == null) return null;
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      if (value is String) return DateTime.tryParse(value);
      if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
      return null;
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          'UserTempleService._safeExtractDateTime: Error extracting $field for temple $templeId: $e. '
          'Value type: ${data[field]?.runtimeType}, Value: ${data[field]}',
        );
      }
      return null;
    }
  }

  /// Optimized text filtering for large datasets with memory efficiency
  List<Temple> _filterTemplesByTextOptimized(
    List<Temple> temples,
    String query,
  ) {
    if (query.isEmpty) return temples;

    final searchTerms = query.toLowerCase().split(' ');
    // Choose filtering strategy based on dataset size
    if (temples.length > 500) {
      return _filterTemplesByTextMemoryEfficient(temples, searchTerms);
    } else if (temples.length > 200) {
      return _filterTemplesByTextParallel(temples, searchTerms);
    } else {
      // Standard filtering for smaller datasets
      return _filterTemplesByText(temples, query);
    }
  }

  /// Memory-efficient text filtering for very large datasets
  List<Temple> _filterTemplesByTextMemoryEfficient(
    List<Temple> temples,
    List<String> searchTerms,
  ) {
    final filteredTemples = <Temple>[];
    const batchSize = 50; // Small batches to minimize memory usage

    for (int i = 0; i < temples.length; i += batchSize) {
      final batch = temples.skip(i).take(batchSize);

      for (final temple in batch) {
        // Build searchable text on-demand to save memory
        final searchableText = _buildSearchableTextMinimal(temple);
        if (searchTerms.every((term) => searchableText.contains(term))) {
          filteredTemples.add(temple);
        }
      }

      // Yield control periodically to prevent blocking
      if (i % (batchSize * 10) == 0) {
        // Small delay every 10 batches
        Future.delayed(Duration.zero);
      }
    }

    return filteredTemples;
  }

  /// Parallel text filtering for medium-large datasets
  List<Temple> _filterTemplesByTextParallel(
    List<Temple> temples,
    List<String> searchTerms,
  ) {
    return temples.where((temple) {
      final searchableText = _buildSearchableText(temple);
      return searchTerms.every((term) => searchableText.contains(term));
    }).toList();
  }

  /// Build minimal searchable text to reduce memory usage
  String _buildSearchableTextMinimal(Temple temple) {
    // Only include essential fields for searching to minimize memory
    return [
      temple.name,
      temple.location.city ?? '',
      temple.location.state ?? '',
      temple.traditions.isNotEmpty ? temple.traditions.first : '',
    ].join(' ').toLowerCase();
  }

  /// Build searchable text for a temple (cached for performance)
  String _buildSearchableText(Temple temple) {
    return [
      temple.name,
      temple.description,
      temple.location.address ?? '',
      temple.location.city ?? '',
      temple.location.state ?? '',
      ...temple.traditions,
      ...temple.features,
    ].join(' ').toLowerCase();
  }

  /// Optimized sorting for large datasets with memory awareness

  // Removed unused heap sort implementation

  // Removed unused merge sort implementation

  // Removed unused quick sort implementation

  // Removed _compareTemples - unused method

  /// Get nearby temples based on location and radius with performance optimizations
  /// Includes memory usage tracking and optimization for large datasets
  Future<List<Temple>> getNearbyTemples(
    Location userLocation,
    double radiusKm, {
    TempleFilters? additionalFilters,
    bool useCache = true,
    int? limit,
  }) async {
    final operationId =
        'nearby_${userLocation.latitude}_${userLocation.longitude}_${DateTime.now().millisecondsSinceEpoch}';

    if (kDebugMode) {
      debugPrint(
        'UserTempleService.getNearbyTemples: Starting operation $operationId',
      );
    }

    try {
      final effectiveLimit = limit;
      final cacheKey = _generateCacheKey('nearby', {
        'location': userLocation.toJson(),
        'radius': radiusKm,
        'filters': additionalFilters?.toJson() ?? {},
      });

      // Try cache first
      if (useCache) {
        final cachedResults = await _getCachedTemples(cacheKey);
        if (cachedResults != null) {
          if (kDebugMode) {
            debugPrint(
              'UserTempleService: Returning ${cachedResults.length} cached nearby temples',
            );
          }
          return cachedResults;
        }
      }

      // Create filters with location and radius
      final filters = (additionalFilters ?? const TempleFilters()).copyWith(
        userLocation: userLocation,
        maxDistance: radiusKm,
      );

      // Get all temples and filter by distance
      // For better performance, you might want to use GeoFirestore or similar
      final allTemples = await _getAllActiveTemples();

      // Filter by distance
      final nearbyTemples = _applyDistanceFiltering(allTemples, filters);

      // Apply additional filters
      List<Temple> filteredTemples = nearbyTemples;

      if (filters.traditions?.isNotEmpty == true) {
        filteredTemples = filteredTemples
            .where(
              (temple) => temple.traditions.any(
                (tradition) => filters.traditions!.contains(tradition),
              ),
            )
            .toList();
      }

      if (filters.features?.isNotEmpty == true) {
        filteredTemples = filteredTemples
            .where(
              (temple) => temple.features.any(
                (feature) => filters.features!.contains(feature),
              ),
            )
            .toList();
      }

      if (filters.hasLiveDarshan == true) {
        filteredTemples = filteredTemples
            .where((temple) => temple.liveDarshan?.isConfiguredByAdmin == true)
            .toList();
      }

      // Sort by distance by default with optimization
      filteredTemples = _sortTemples(
        filteredTemples,
        filters.sortBy == SortOption.name
            ? SortOption.distance
            : filters.sortBy,
        filters.ascending,
      );

      // Apply effective limit if specified
      if (effectiveLimit != null && effectiveLimit > 0) {
        filteredTemples = filteredTemples.take(effectiveLimit).toList();
      }

      // Cache results
      if (useCache) {
        await _cacheTemples(cacheKey, filteredTemples);
      }

      if (kDebugMode) {
        debugPrint(
          'UserTempleService.getNearbyTemples: Completed operation $operationId. '
          'Found ${filteredTemples.length} temples within ${radiusKm}km',
        );
      }

      return filteredTemples;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('UserTempleService: Error getting nearby temples - $e');
      }

      // Try offline fallback
      final offlineTemples = await offlineManager.getDataList(
        _templesCollection,
      );
      if (offlineTemples.isNotEmpty) {
        final temples = offlineTemples
            .map((data) => Temple.fromJson(data))
            .toList();
        return _applyDistanceFiltering(
          temples,
          TempleFilters(userLocation: userLocation, maxDistance: radiusKm),
        );
      }

      rethrow;
    }
  }

  /// Get recommended temples based on user preferences
  /// Includes memory usage tracking and optimization
  Future<List<Temple>> getRecommendedTemples(
    UserPreferences preferences, {
    Location? userLocation,
    int limit = 20,
    bool useCache = true,
  }) async {
    final operationId =
        'recommended_${preferences.userId}_${DateTime.now().millisecondsSinceEpoch}';

    if (kDebugMode) {
      debugPrint(
        'UserTempleService.getRecommendedTemples: Starting operation $operationId',
      );
    }

    try {
      final effectiveLimit = limit;
      final cacheKey = _generateCacheKey('recommended', {
        'userId': preferences.userId,
        'preferences': preferences.toJson(),
        'location': userLocation?.toJson(),
        'limit': limit,
      });

      // Try cache first
      if (useCache) {
        final cachedResults = await _getCachedTemples(cacheKey);
        if (cachedResults != null) {
          if (kDebugMode) {
            debugPrint(
              'UserTempleService: Returning ${cachedResults.length} cached recommended temples',
            );
          }
          return cachedResults.take(limit).toList();
        }
      }

      // Build filters based on preferences
      final filters = TempleFilters(
        traditions: preferences.hasPreferredTraditions
            ? preferences.preferredTraditions
            : null,
        userLocation: userLocation,
        maxDistance: preferences.isLocationEnabled
            ? preferences.locationRadius
            : null,
        isActive: true,
        sortBy: userLocation != null ? SortOption.distance : SortOption.name,
      );

      // Get temples based on preferences
      List<Temple> recommendedTemples;

      if (preferences.hasPreferredTraditions) {
        // Get temples matching preferred traditions
        recommendedTemples = await searchTemples(
          '',
          filters: filters,
          useCache: false,
        );
      } else if (userLocation != null && preferences.isLocationEnabled) {
        // Get nearby temples if no tradition preferences
        recommendedTemples = await getNearbyTemples(
          userLocation,
          preferences.locationRadius,
          useCache: false,
        );
      } else {
        // Get general popular temples (you might want to add popularity scoring)
        recommendedTemples = await _getAllActiveTemples();
        recommendedTemples = _sortTemples(
          recommendedTemples,
          SortOption.visitCount,
          false,
        );
      }

      // Apply recommendation scoring and limit results
      recommendedTemples = _applyRecommendationScoring(
        recommendedTemples,
        preferences,
        userLocation,
      );
      recommendedTemples = recommendedTemples.take(effectiveLimit).toList();

      // Cache results
      if (useCache) {
        await _cacheTemples(cacheKey, recommendedTemples);
      }

      if (kDebugMode) {
        debugPrint(
          'UserTempleService.getRecommendedTemples: Completed operation $operationId. '
          'Generated ${recommendedTemples.length} recommended temples',
        );
      }

      return recommendedTemples;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('UserTempleService: Error getting recommended temples - $e');
      }

      // Fallback to nearby temples or cached data
      if (userLocation != null) {
        try {
          return await getNearbyTemples(
            userLocation,
            preferences.locationRadius,
          );
        } catch (_) {
          // Continue to offline fallback
        }
      }

      // Try offline fallback
      final offlineTemples = await offlineManager.getDataList(
        _templesCollection,
      );
      if (offlineTemples.isNotEmpty) {
        final temples = offlineTemples
            .map((data) => Temple.fromJson(data))
            .toList();
        return temples.take(limit).toList();
      }

      rethrow;
    }
  }

  /// Get temple details by ID
  Future<Temple?> getTempleDetails(
    String templeId, {
    bool useCache = true,
  }) async {
    try {
      final cacheKey = '$_cacheKeyPrefix:temple:$templeId';

      // Try cache first
      if (useCache) {
        final cachedData = await cacheManager.getCachedData(cacheKey);
        if (cachedData != null) {
          return Temple.fromJson(cachedData);
        }
      }

      // Try offline data
      final offlineData = await offlineManager.getData(
        '${_templesCollection}_$templeId',
      );
      if (offlineData != null) {
        return Temple.fromJson(offlineData);
      }

      // Fetch from Firestore
      final doc = await _firestore
          .collection(_templesCollection)
          .doc(templeId)
          .get();

      if (!doc.exists) {
        return null;
      }

      final temple = Temple.fromFirestore(doc);

      // Cache the result
      if (useCache) {
        await cacheManager.cacheData(
          cacheKey,
          temple.toCacheJson(),
          ttl: _defaultCacheTTL,
        );
      }

      return temple;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('UserTempleService: Error getting temple details - $e');
      }

      // Try offline fallback
      final offlineData = await offlineManager.getData(
        '${_templesCollection}_$templeId',
      );
      if (offlineData != null) {
        return Temple.fromJson(offlineData);
      }

      rethrow;
    }
  }

  /// Watch temples with real-time updates
  Stream<List<Temple>> watchTemples({TempleFilters? filters}) {
    Query<Map<String, dynamic>> query = _firestore
        .collection(_templesCollection)
        .where('isActive', isEqualTo: filters?.isActive ?? true);

    // Apply filters to query
    if (filters?.traditions?.isNotEmpty == true) {
      query = query.where('traditions', arrayContainsAny: filters!.traditions);
    }

    if (filters?.features?.isNotEmpty == true) {
      query = query.where('features', arrayContainsAny: filters!.features);
    }

    if (filters?.hasLiveDarshan == true) {
      query = query.where('liveDarshan.isConfiguredByAdmin', isEqualTo: true);
    }

    return query.snapshots().map((snapshot) {
      List<Temple> temples = snapshot.docs
          .map((doc) => Temple.fromFirestore(doc))
          .toList();

      // Apply client-side filtering
      if (filters?.searchQuery?.isNotEmpty == true) {
        temples = _filterTemplesByText(temples, filters!.searchQuery!);
      }

      if (filters?.userLocation != null) {
        temples = _applyDistanceFiltering(temples, filters!);
      }

      // Apply sorting
      temples = _sortTemples(
        temples,
        filters?.sortBy ?? SortOption.name,
        filters?.ascending ?? true,
      );

      return temples;
    });
  }

  /// Watch temples with pagination for memory optimization (requirement 3.3)
  /// Load 10-20 temples per page to reduce memory usage
  Stream<List<Temple>> watchTemplesPaginated({
    TempleFilters? filters,
    int limit = 15,
    DocumentSnapshot? startAfter,
  }) {
    Query<Map<String, dynamic>> query = _firestore
        .collection(_templesCollection)
        .where('isActive', isEqualTo: filters?.isActive ?? true);

    // Apply filters to query
    if (filters?.traditions?.isNotEmpty == true) {
      query = query.where('traditions', arrayContainsAny: filters!.traditions);
    }

    if (filters?.features?.isNotEmpty == true) {
      query = query.where('features', arrayContainsAny: filters!.features);
    }

    if (filters?.hasLiveDarshan == true) {
      query = query.where('liveDarshan.isConfiguredByAdmin', isEqualTo: true);
    }

    // Apply pagination
    query = query.limit(limit);
    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    // Order by name for consistent pagination
    query = query.orderBy('name');

    return query.snapshots().map((snapshot) {
      List<Temple> temples = snapshot.docs
          .map((doc) => Temple.fromFirestore(doc))
          .toList();

      // Apply client-side filtering
      if (filters?.searchQuery?.isNotEmpty == true) {
        temples = _filterTemplesByText(temples, filters!.searchQuery!);
      }

      if (filters?.userLocation != null) {
        temples = _applyDistanceFiltering(temples, filters!);
      }

      // Apply sorting (limited since we're already ordered by name for pagination)
      if (filters != null && filters.sortBy != SortOption.name) {
        temples = _sortTemples(temples, filters.sortBy, filters.ascending);
      }

      return temples;
    });
  }

  /// Get temples with live darshan
  Future<List<Temple>> getTemplesWithLiveDarshan({bool useCache = true}) async {
    final filters = const TempleFilters(hasLiveDarshan: true);
    return await searchTemples('', filters: filters, useCache: useCache);
  }

  /// Check if a temple is currently live
  Future<bool> isTempleLive(String templeId) async {
    try {
      final temple = await getTempleDetails(templeId);
      return temple?.liveDarshan?.isCurrentlyLive ?? false;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('UserTempleService: Error checking temple live status - $e');
      }
      return false;
    }
  }

  /// Clear temple cache
  Future<void> clearCache() async {
    await cacheManager.invalidateByPattern('$_cacheKeyPrefix.*');
    if (kDebugMode) {
      debugPrint('UserTempleService: Cleared temple cache');
    }
  }

  /// Clear temple cache (internal method)
  Future<void> _clearTempleCache() async {
    await cacheManager.invalidateByPattern('$_cacheKeyPrefix.*');
  }

  /// Get offline status
  bool get isOffline => !offlineManager.isOnline;

  /// Get sync status
  bool get isSyncing => offlineManager.isSyncing;

  /// Get pending sync count
  int get pendingSyncCount => offlineManager.pendingSyncCount;

  /// Get sync status stream
  Stream<SyncStatus> get syncStatusStream => offlineManager.syncStatusStream;

  /// Force sync all offline data
  Future<void> forceSyncAll() async {
    if (!offlineManager.isOnline) {
      throw Exception('Cannot sync while offline');
    }
    await offlineManager.forceSyncAll();
  }

  /// Get data freshness information
  Future<Map<String, dynamic>> getDataFreshness() async {
    final lastSyncTime = await offlineManager.getLastSyncTime();
    final cacheUsage = await cacheManager.getCacheUsageRatio();

    return {
      'lastSyncTime': lastSyncTime?.toIso8601String(),
      'isOnline': offlineManager.isOnline,
      'isSyncing': offlineManager.isSyncing,
      'pendingSyncCount': offlineManager.pendingSyncCount,
      'cacheUsage': cacheUsage,
      'isStale': lastSyncTime != null
          ? DateTime.now().difference(lastSyncTime).inHours > 24
          : true,
    };
  }

  /// Refresh temple data
  Future<void> refreshTempleData(String templeId) async {
    final cacheKey = '$_cacheKeyPrefix:temple:$templeId';
    await cacheManager.refreshEntry(cacheKey);
  }

  // Private helper methods

  /// Get all active temples
  Future<List<Temple>> _getAllActiveTemples() async {
    final cacheKey = '$_cacheKeyPrefix:all_active';

    // Try cache first
    final cachedResults = await _getCachedTemples(cacheKey);
    if (cachedResults != null) {
      return cachedResults;
    }

    // Fetch from Firestore
    final querySnapshot = await _firestore
        .collection(_templesCollection)
        .where('isActive', isEqualTo: true)
        .get();

    final temples = querySnapshot.docs
        .map((doc) => Temple.fromFirestore(doc))
        .toList();

    // Cache results
    await _cacheTemples(cacheKey, temples);

    return temples;
  }

  /// Filter temples by text search
  List<Temple> _filterTemplesByText(List<Temple> temples, String query) {
    if (query.isEmpty) return temples;

    final searchTerms = query.toLowerCase().split(' ');

    return temples.where((temple) {
      final searchableText = [
        temple.name,
        temple.description,
        temple.mainDeity ?? '',
        temple.location.address ?? '',
        temple.location.city ?? '',
        temple.location.state ?? '',
        ...temple.traditions,
        ...temple.features,
      ].join(' ').toLowerCase();

      return searchTerms.every((term) => searchableText.contains(term));
    }).toList();
  }

  /// Apply distance filtering and calculate distances
  List<Temple> _applyDistanceFiltering(
    List<Temple> temples,
    TempleFilters filters,
  ) {
    if (filters.userLocation == null) return temples;

    final userLocation = filters.userLocation!;
    final maxDistance = filters.maxDistance;

    if (kDebugMode) {
      debugPrint(
        'UserTempleService: Calculating distances from '
        'Lat: ${userLocation.latitude}, Lng: ${userLocation.longitude}',
      );
    }

    final templesWithDistance = temples
        .map((temple) {
          final distance = _calculateDistance(
            userLocation.latitude,
            userLocation.longitude,
            temple.location.latitude,
            temple.location.longitude,
          );

          if (kDebugMode && temples.indexOf(temple) < 3) {
            // Log first 3 temples for debugging
            debugPrint(
              'Temple: ${temple.name}, '
              'Location: ${temple.location.latitude}, ${temple.location.longitude}, '
              'Distance: ${distance.toStringAsFixed(2)} km',
            );
          }

          return temple.copyWith(distanceFromUser: distance);
        })
        .where((temple) {
          return maxDistance == null || temple.distanceFromUser! <= maxDistance;
        })
        .toList();

    if (kDebugMode) {
      debugPrint(
        'UserTempleService: Calculated distances for ${templesWithDistance.length} temples',
      );
    }

    return templesWithDistance;
  }

  /// Calculate distance between two points using Haversine formula
  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadius = 6371; // Earth's radius in kilometers

    final double dLat = _degreesToRadians(lat2 - lat1);
    final double dLon = _degreesToRadians(lon2 - lon1);

    final double a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degreesToRadians(lat1)) *
            math.cos(_degreesToRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  /// Convert degrees to radians
  double _degreesToRadians(double degrees) {
    return degrees * (math.pi / 180);
  }

  /// Sort temples based on criteria
  List<Temple> _sortTemples(
    List<Temple> temples,
    SortOption sortBy,
    bool ascending,
  ) {
    temples.sort((a, b) {
      int comparison;

      switch (sortBy) {
        case SortOption.name:
          comparison = a.name.compareTo(b.name);
          break;
        case SortOption.distance:
          final aDistance = a.distanceFromUser ?? double.infinity;
          final bDistance = b.distanceFromUser ?? double.infinity;
          comparison = aDistance.compareTo(bDistance);
          break;
        case SortOption.createdAt:
          comparison = a.createdAt.compareTo(b.createdAt);
          break;
        case SortOption.updatedAt:
          comparison = a.updatedAt.compareTo(b.updatedAt);
          break;
        case SortOption.visitCount:
          comparison = a.visitCount.compareTo(b.visitCount);
          break;
        case SortOption.tradition:
          final aTradition = a.traditions.isNotEmpty ? a.traditions.first : '';
          final bTradition = b.traditions.isNotEmpty ? b.traditions.first : '';
          comparison = aTradition.compareTo(bTradition);
          break;
        case SortOption.rating:
          comparison = a.averageRating.compareTo(b.averageRating);
          break;
        case SortOption.popularity:
          // Popularity based on combination of visit count and rating
          final aPopularity = (a.visitCount * 0.7) + (a.averageRating * 0.3);
          final bPopularity = (b.visitCount * 0.7) + (b.averageRating * 0.3);
          comparison = aPopularity.compareTo(bPopularity);
          break;
      }

      return ascending ? comparison : -comparison;
    });

    return temples;
  }

  /// Apply recommendation scoring based on user preferences
  List<Temple> _applyRecommendationScoring(
    List<Temple> temples,
    UserPreferences preferences,
    Location? userLocation,
  ) {
    // Simple scoring algorithm - can be enhanced with ML in the future
    final scoredTemples = temples.map((temple) {
      double score = 0.0;

      // Tradition match scoring
      if (preferences.hasPreferredTraditions) {
        final matchingTraditions = temple.traditions
            .where(
              (tradition) =>
                  preferences.preferredTraditions.contains(tradition),
            )
            .length;
        score += matchingTraditions * 10.0; // High weight for tradition match
      }

      // Distance scoring (closer is better)
      if (temple.distanceFromUser != null) {
        final distance = temple.distanceFromUser!;
        if (distance <= 5) {
          score += 5.0; // Very close
        } else if (distance <= 20) {
          score += 3.0; // Close
        } else if (distance <= 50) {
          score += 1.0; // Moderate distance
        }
      }

      // Live darshan bonus
      if (temple.liveDarshan?.isConfiguredByAdmin == true) {
        score += 2.0;
      }

      // Visit count bonus (popularity)
      score += temple.visitCount * 0.1;

      // Recent updates bonus
      final daysSinceUpdate = DateTime.now()
          .difference(temple.updatedAt)
          .inDays;
      if (daysSinceUpdate <= 30) {
        score += 1.0;
      }

      return MapEntry(temple, score);
    }).toList();

    // Sort by score (highest first)
    scoredTemples.sort((a, b) => b.value.compareTo(a.value));

    return scoredTemples.map((entry) => entry.key).toList();
  }

  /// Generate cache key for temple data
  String _generateCacheKey(String operation, Map<String, dynamic> params) {
    final paramString = params.entries
        .map((e) => '${e.key}:${e.value.toString()}')
        .join('|');
    return '$_cacheKeyPrefix:$operation:${paramString.hashCode}';
  }

  /// Cache temple list
  Future<void> _cacheTemples(String cacheKey, List<Temple> temples) async {
    final templeDataList = temples
        .map((temple) => temple.toCacheJson())
        .toList();
    await cacheManager.cacheDataList(
      cacheKey,
      templeDataList,
      ttl: _defaultCacheTTL,
    );
  }

  /// Get cached temple list
  Future<List<Temple>?> _getCachedTemples(String cacheKey) async {
    final cachedDataList = await cacheManager.getCachedDataList(cacheKey);
    if (cachedDataList != null) {
      return cachedDataList.map((data) => Temple.fromCacheJson(data)).toList();
    }
    return null;
  }
}
