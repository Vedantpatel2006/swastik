import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../shared/models/temple.dart';
import '../../../shared/models/user_preferences.dart';

import '../../../shared/services/cache/data_cache_manager.dart';
import 'user_temple_service.dart';

/// Enhanced recommendation manager with ML-based scoring and user behavior tracking
class RecommendationManager {
  static final RecommendationManager _instance = RecommendationManager._internal();
  factory RecommendationManager() => _instance;
  RecommendationManager._internal();

  final UserTempleService _userTempleService = UserTempleService();
  DataCacheManager? _cacheManager;
  SharedPreferences? _prefs;

  static const String _cacheKeyPrefix = 'recommendations';
  static const String _behaviorKeyPrefix = 'user_behavior';
  static const Duration _defaultCacheTTL = Duration(hours: 1);

  // ML-based scoring weights
  static const double _traditionMatchWeight = 10.0;
  static const double _distanceWeight = 5.0;
  static const double _liveDarshanWeight = 3.0;
  static const double _popularityWeight = 2.0;
  static const double _recentActivityWeight = 1.5;
  static const double _userBehaviorWeight = 8.0;

  /// Initialize the recommendation manager
  Future<void> initialize() async {
    _cacheManager ??= DataCacheManager();
    await _cacheManager!.initialize();
    _prefs ??= await SharedPreferences.getInstance();
    await _userTempleService.initialize();
  }

  /// Get personalized temple recommendations with ML-based scoring
  Future<List<RecommendedTemple>> getPersonalizedRecommendations({
    required UserPreferences preferences,
    Location? userLocation,
    int limit = 10,
    bool includeExplanations = true,
    bool useCache = true,
  }) async {
    if (kDebugMode) {
      debugPrint('RecommendationManager: Getting personalized recommendations for user ${preferences.userId}');
    }

    try {
      final cacheKey = _generateCacheKey('personalized', {
        'userId': preferences.userId,
        'location': userLocation?.toJson(),
        'limit': limit,
        'preferences_hash': preferences.hashCode,
      });

      // Try cache first
      if (useCache) {
        final cachedResults = await _getCachedRecommendations(cacheKey);
        if (cachedResults != null) {
          if (kDebugMode) {
            debugPrint('RecommendationManager: Returning ${cachedResults.length} cached recommendations');
          }
          return cachedResults.take(limit).toList();
        }
      }

      // Get base temple data using existing UserTempleService
      final baseTemples = await _userTempleService.getRecommendedTemples(
        preferences,
        userLocation: userLocation,
        limit: limit * 3, // Get more temples for better scoring
        useCache: false,
      );

      if (baseTemples.isEmpty) {
        if (kDebugMode) {
          debugPrint('RecommendationManager: No base temples found');
        }
        return [];
      }

      // Get user behavior data
      final userBehavior = await _getUserBehaviorData(preferences.userId);

      // Apply ML-based scoring
      final scoredTemples = await _applyMLBasedScoring(
        baseTemples,
        preferences,
        userLocation,
        userBehavior,
      );

      // Convert to RecommendedTemple objects with explanations
      final recommendations = scoredTemples.map((entry) {
        final temple = entry.key;
        final scoreData = entry.value;
        
        return RecommendedTemple(
          temple: temple,
          relevanceScore: scoreData['score'],
          recommendationReason: includeExplanations 
              ? _generateRecommendationReason(temple, scoreData, preferences)
              : 'Recommended for you',
          matchingFactors: scoreData['factors'] ?? [],
        );
      }).toList();

      // Cache results
      if (useCache && recommendations.isNotEmpty) {
        await _cacheRecommendations(cacheKey, recommendations);
      }

      if (kDebugMode) {
        debugPrint('RecommendationManager: Generated ${recommendations.length} personalized recommendations');
      }

      return recommendations.take(limit).toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('RecommendationManager: Error getting personalized recommendations - $e');
      }
      rethrow;
    }
  }

  /// Track user interaction for ML learning
  Future<void> trackUserInteraction(
    String userId,
    String templeId,
    InteractionType type, {
    Duration? duration,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final currentBehavior = await _getUserBehaviorData(userId);
      
      // Update interaction data
      final interaction = UserInteraction(
        templeId: templeId,
        type: type,
        timestamp: DateTime.now(),
        duration: duration,
        metadata: metadata,
      );

      currentBehavior.interactions.add(interaction);

      // Keep only recent interactions (last 1000)
      if (currentBehavior.interactions.length > 1000) {
        currentBehavior.interactions = currentBehavior.interactions
            .skip(currentBehavior.interactions.length - 1000)
            .toList();
      }

      // Update behavior patterns
      _updateBehaviorPatterns(currentBehavior, interaction);

      // Save updated behavior data
      await _saveBehaviorData(userId, currentBehavior);

      // Clear recommendation cache for this user
      await _clearUserRecommendationCache(userId);

      if (kDebugMode) {
        debugPrint('RecommendationManager: Tracked $type interaction for temple $templeId');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('RecommendationManager: Error tracking user interaction - $e');
      }
    }
  }

  /// Update user preferences based on behavior
  Future<void> updateUserPreferences(
    String userId,
    UserPreferences preferences,
  ) async {
    try {
      final behavior = await _getUserBehaviorData(userId);
      
      // Update preference patterns based on recent behavior
      behavior.preferencePatterns = _analyzePreferencePatterns(
        behavior.interactions,
        preferences,
      );

      await _saveBehaviorData(userId, behavior);
      await _clearUserRecommendationCache(userId);

      if (kDebugMode) {
        debugPrint('RecommendationManager: Updated user preferences for $userId');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('RecommendationManager: Error updating user preferences - $e');
      }
    }
  }

  /// Apply ML-based scoring to temples
  Future<List<MapEntry<Temple, Map<String, dynamic>>>> _applyMLBasedScoring(
    List<Temple> temples,
    UserPreferences preferences,
    Location? userLocation,
    UserBehaviorData userBehavior,
  ) async {
    final scoredTemples = <MapEntry<Temple, Map<String, dynamic>>>[];

    for (final temple in temples) {
      final scoreData = await _calculateTempleScore(
        temple,
        preferences,
        userLocation,
        userBehavior,
      );
      
      scoredTemples.add(MapEntry(temple, scoreData));
    }

    // Sort by score (highest first)
    scoredTemples.sort((a, b) => b.value['score'].compareTo(a.value['score']));

    return scoredTemples;
  }

  /// Calculate comprehensive temple score using ML-based approach
  Future<Map<String, dynamic>> _calculateTempleScore(
    Temple temple,
    UserPreferences preferences,
    Location? userLocation,
    UserBehaviorData userBehavior,
  ) async {
    double score = 0.0;
    final factors = <String>[];

    // 1. Tradition matching score
    final traditionScore = _calculateTraditionScore(temple, preferences);
    if (traditionScore > 0) {
      score += traditionScore * _traditionMatchWeight;
      factors.add('tradition_match');
    }

    // 2. Distance score (closer is better)
    final distanceScore = _calculateDistanceScore(temple, userLocation);
    if (distanceScore > 0) {
      score += distanceScore * _distanceWeight;
      factors.add('nearby');
    }

    // 3. Live darshan bonus
    final liveDarshanScore = _calculateLiveDarshanScore(temple);
    if (liveDarshanScore > 0) {
      score += liveDarshanScore * _liveDarshanWeight;
      factors.add('live_darshan');
    }

    // 4. Popularity score
    final popularityScore = _calculatePopularityScore(temple);
    score += popularityScore * _popularityWeight;
    if (popularityScore > 0.7) {
      factors.add('popular');
    }

    // 5. Recent activity score
    final recentActivityScore = _calculateRecentActivityScore(temple);
    if (recentActivityScore > 0) {
      score += recentActivityScore * _recentActivityWeight;
      factors.add('recently_updated');
    }

    // 6. User behavior score (ML component)
    final behaviorScore = _calculateUserBehaviorScore(temple, userBehavior);
    if (behaviorScore > 0) {
      score += behaviorScore * _userBehaviorWeight;
      factors.add('personalized');
    }

    // 7. Collaborative filtering score
    final collaborativeScore = await _calculateCollaborativeScore(temple, userBehavior);
    if (collaborativeScore > 0) {
      score += collaborativeScore * 2.0;
      factors.add('similar_users');
    }

    // Normalize score to 0-100 range
    final normalizedScore = math.min(100.0, score);

    return {
      'score': normalizedScore,
      'factors': factors,
      'breakdown': {
        'tradition': traditionScore * _traditionMatchWeight,
        'distance': distanceScore * _distanceWeight,
        'live_darshan': liveDarshanScore * _liveDarshanWeight,
        'popularity': popularityScore * _popularityWeight,
        'recent_activity': recentActivityScore * _recentActivityWeight,
        'user_behavior': behaviorScore * _userBehaviorWeight,
        'collaborative': collaborativeScore * 2.0,
      },
    };
  }

  /// Calculate tradition matching score
  double _calculateTraditionScore(Temple temple, UserPreferences preferences) {
    if (!preferences.hasPreferredTraditions) return 0.0;

    final matchingTraditions = temple.traditions
        .where((tradition) => preferences.preferredTraditions.contains(tradition))
        .length;

    if (matchingTraditions == 0) return 0.0;

    // Score based on percentage of matching traditions
    return matchingTraditions / preferences.preferredTraditions.length;
  }

  /// Calculate distance-based score
  double _calculateDistanceScore(Temple temple, Location? userLocation) {
    if (userLocation == null || temple.distanceFromUser == null) return 0.0;

    final distance = temple.distanceFromUser!;
    
    // Exponential decay for distance scoring
    if (distance <= 5) return 1.0;
    if (distance <= 20) return 0.8;
    if (distance <= 50) return 0.5;
    if (distance <= 100) return 0.2;
    return 0.0;
  }

  /// Calculate live darshan score
  double _calculateLiveDarshanScore(Temple temple) {
    if (temple.liveDarshan?.isConfiguredByAdmin != true) return 0.0;
    
    double score = 0.5; // Base score for having live darshan
    
    if (temple.liveDarshan?.isCurrentlyLive == true) {
      score += 0.5; // Bonus for currently live
    }
    
    return score;
  }

  /// Calculate popularity score
  double _calculatePopularityScore(Temple temple) {
    // Combine visit count and rating for popularity
    final visitScore = math.min(1.0, temple.visitCount / 1000.0);
    final ratingScore = temple.averageRating / 5.0;
    
    return (visitScore * 0.6) + (ratingScore * 0.4);
  }

  /// Calculate recent activity score
  double _calculateRecentActivityScore(Temple temple) {
    final daysSinceUpdate = DateTime.now().difference(temple.updatedAt).inDays;
    
    if (daysSinceUpdate <= 7) return 1.0;
    if (daysSinceUpdate <= 30) return 0.7;
    if (daysSinceUpdate <= 90) return 0.3;
    return 0.0;
  }

  /// Calculate user behavior-based score (ML component)
  double _calculateUserBehaviorScore(Temple temple, UserBehaviorData userBehavior) {
    double score = 0.0;

    // Check if user has interacted with similar temples
    final similarInteractions = userBehavior.interactions.where((interaction) {
      // This would ideally use temple similarity metrics
      return temple.traditions.any((tradition) => 
          userBehavior.preferencePatterns['preferred_traditions']?.contains(tradition) ?? false);
    }).length;

    if (similarInteractions > 0) {
      score += math.min(1.0, similarInteractions / 10.0);
    }

    // Check time-based patterns
    final currentHour = DateTime.now().hour;
    final userActiveHours = userBehavior.preferencePatterns['active_hours'] as List<int>? ?? [];
    if (userActiveHours.contains(currentHour)) {
      score += 0.2;
    }

    return score;
  }

  /// Calculate collaborative filtering score
  Future<double> _calculateCollaborativeScore(Temple temple, UserBehaviorData userBehavior) async {
    // Simplified collaborative filtering
    // In a real implementation, this would compare with other users' behavior
    
    // For now, return a score based on temple popularity among similar preference users
    if (temple.totalReviews > 50 && temple.averageRating > 4.0) {
      return 0.5;
    }
    
    return 0.0;
  }

  /// Generate recommendation reason text
  String _generateRecommendationReason(
    Temple temple,
    Map<String, dynamic> scoreData,
    UserPreferences preferences,
  ) {
    final factors = scoreData['factors'] as List<String>;
    
    if (factors.contains('tradition_match')) {
      final matchingTraditions = temple.traditions
          .where((t) => preferences.preferredTraditions.contains(t))
          .toList();
      return 'Matches your preferred ${matchingTraditions.join(', ')} tradition';
    }
    
    if (factors.contains('live_darshan') && temple.liveDarshan?.isCurrentlyLive == true) {
      return 'Currently streaming live darshan';
    }
    
    if (factors.contains('nearby')) {
      return 'Located nearby (${temple.distanceFromUser?.toStringAsFixed(1)}km away)';
    }
    
    if (factors.contains('popular')) {
      return 'Highly rated by the community (${temple.averageRating.toStringAsFixed(1)}/5)';
    }
    
    if (factors.contains('personalized')) {
      return 'Based on your temple visit patterns';
    }
    
    return 'Recommended for you';
  }

  /// Get user behavior data
  Future<UserBehaviorData> _getUserBehaviorData(String userId) async {
    try {
      final behaviorKey = '$_behaviorKeyPrefix:$userId';
      final cachedData = await _cacheManager!.getCachedData(behaviorKey);
      
      if (cachedData != null) {
        return UserBehaviorData.fromJson(cachedData);
      }
      
      return UserBehaviorData(userId: userId);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('RecommendationManager: Error getting user behavior data - $e');
      }
      return UserBehaviorData(userId: userId);
    }
  }

  /// Save user behavior data
  Future<void> _saveBehaviorData(String userId, UserBehaviorData behaviorData) async {
    try {
      final behaviorKey = '$_behaviorKeyPrefix:$userId';
      await _cacheManager!.cacheData(
        behaviorKey,
        behaviorData.toJson(),
        ttl: const Duration(days: 30),
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('RecommendationManager: Error saving behavior data - $e');
      }
    }
  }

  /// Update behavior patterns based on interaction
  void _updateBehaviorPatterns(UserBehaviorData behavior, UserInteraction interaction) {
    // Update preferred traditions - simplified for now (would require temple data)
    
    // Update active hours
    final activeHours = behavior.preferencePatterns['active_hours'] as List<int>? ?? [];
    final currentHour = interaction.timestamp.hour;
    if (!activeHours.contains(currentHour)) {
      activeHours.add(currentHour);
      if (activeHours.length > 24) {
        activeHours.removeAt(0); // Keep only recent hours
      }
    }
    
    behavior.preferencePatterns['active_hours'] = activeHours;
  }

  /// Analyze preference patterns from interactions
  Map<String, dynamic> _analyzePreferencePatterns(
    List<UserInteraction> interactions,
    UserPreferences preferences,
  ) {
    final patterns = <String, dynamic>{};
    
    // Analyze interaction types
    final interactionCounts = <InteractionType, int>{};
    for (final interaction in interactions) {
      interactionCounts[interaction.type] = (interactionCounts[interaction.type] ?? 0) + 1;
    }
    
    patterns['interaction_preferences'] = interactionCounts.map(
      (key, value) => MapEntry(key.toString(), value),
    );
    
    // Analyze time patterns
    final hourCounts = <int, int>{};
    for (final interaction in interactions) {
      final hour = interaction.timestamp.hour;
      hourCounts[hour] = (hourCounts[hour] ?? 0) + 1;
    }
    
    patterns['active_hours'] = hourCounts.entries
        .where((entry) => entry.value > 2) // Only hours with multiple interactions
        .map((entry) => entry.key)
        .toList();
    
    return patterns;
  }

  /// Generate cache key
  String _generateCacheKey(String operation, Map<String, dynamic> params) {
    final paramString = params.entries
        .map((e) => '${e.key}:${e.value.toString()}')
        .join('|');
    return '$_cacheKeyPrefix:$operation:${paramString.hashCode}';
  }

  /// Cache recommendations
  Future<void> _cacheRecommendations(String cacheKey, List<RecommendedTemple> recommendations) async {
    try {
      final data = recommendations.map((r) => r.toJson()).toList();
      await _cacheManager!.cacheDataList(cacheKey, data, ttl: _defaultCacheTTL);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('RecommendationManager: Error caching recommendations - $e');
      }
    }
  }

  /// Get cached recommendations
  Future<List<RecommendedTemple>?> _getCachedRecommendations(String cacheKey) async {
    try {
      final cachedDataList = await _cacheManager!.getCachedDataList(cacheKey);
      if (cachedDataList != null) {
        return cachedDataList.map((data) => RecommendedTemple.fromJson(data)).toList();
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('RecommendationManager: Error getting cached recommendations - $e');
      }
      return null;
    }
  }

  /// Clear user recommendation cache
  Future<void> _clearUserRecommendationCache(String userId) async {
    try {
      await _cacheManager!.invalidateByPattern('$_cacheKeyPrefix.*$userId.*');
    } catch (e) {
      if (kDebugMode) {
        debugPrint('RecommendationManager: Error clearing user cache - $e');
      }
    }
  }

  /// Clear all caches
  Future<void> clearCache() async {
    try {
      await _cacheManager!.invalidateByPattern('$_cacheKeyPrefix.*');
      if (kDebugMode) {
        debugPrint('RecommendationManager: Cleared all recommendation caches');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('RecommendationManager: Error clearing cache - $e');
      }
    }
  }
}

/// Recommended temple with scoring information
class RecommendedTemple {
  final Temple temple;
  final double relevanceScore;
  final String recommendationReason;
  final List<String> matchingFactors;

  const RecommendedTemple({
    required this.temple,
    required this.relevanceScore,
    required this.recommendationReason,
    required this.matchingFactors,
  });

  /// Create RecommendedTemple from JSON
  factory RecommendedTemple.fromJson(Map<String, dynamic> json) {
    return RecommendedTemple(
      temple: Temple.fromJson(json['temple'] as Map<String, dynamic>),
      relevanceScore: (json['relevanceScore'] as num).toDouble(),
      recommendationReason: json['recommendationReason'] as String,
      matchingFactors: List<String>.from(json['matchingFactors'] as List),
    );
  }

  /// Convert RecommendedTemple to JSON
  Map<String, dynamic> toJson() {
    return {
      'temple': temple.toJson(),
      'relevanceScore': relevanceScore,
      'recommendationReason': recommendationReason,
      'matchingFactors': matchingFactors,
    };
  }

  @override
  String toString() {
    return 'RecommendedTemple(${temple.name}, score: ${relevanceScore.toStringAsFixed(1)}, reason: $recommendationReason)';
  }
}

/// User interaction types for ML learning
enum InteractionType {
  view,
  favorite,
  unfavorite,
  share,
  visit,
  liveDarshanWatch,
  search,
  filter,
  booking,
  donation,
  review,
}

/// User interaction data
class UserInteraction {
  final String templeId;
  final InteractionType type;
  final DateTime timestamp;
  final Duration? duration;
  final Map<String, dynamic>? metadata;

  const UserInteraction({
    required this.templeId,
    required this.type,
    required this.timestamp,
    this.duration,
    this.metadata,
  });

  /// Create UserInteraction from JSON
  factory UserInteraction.fromJson(Map<String, dynamic> json) {
    return UserInteraction(
      templeId: json['templeId'] as String,
      type: InteractionType.values[json['type'] as int],
      timestamp: DateTime.parse(json['timestamp'] as String),
      duration: json['duration'] != null 
          ? Duration(milliseconds: json['duration'] as int)
          : null,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  /// Convert UserInteraction to JSON
  Map<String, dynamic> toJson() {
    return {
      'templeId': templeId,
      'type': type.index,
      'timestamp': timestamp.toIso8601String(),
      if (duration != null) 'duration': duration!.inMilliseconds,
      if (metadata != null) 'metadata': metadata,
    };
  }
}

/// User behavior data for ML learning
class UserBehaviorData {
  final String userId;
  List<UserInteraction> interactions;
  Map<String, dynamic> preferencePatterns;
  DateTime lastUpdated;

  UserBehaviorData({
    required this.userId,
    List<UserInteraction>? interactions,
    Map<String, dynamic>? preferencePatterns,
    DateTime? lastUpdated,
  }) : interactions = interactions ?? [],
       preferencePatterns = preferencePatterns ?? {},
       lastUpdated = lastUpdated ?? DateTime.now();

  /// Create UserBehaviorData from JSON
  factory UserBehaviorData.fromJson(Map<String, dynamic> json) {
    return UserBehaviorData(
      userId: json['userId'] as String,
      interactions: json['interactions'] != null
          ? (json['interactions'] as List)
              .map((i) => UserInteraction.fromJson(i as Map<String, dynamic>))
              .toList()
          : [],
      preferencePatterns: json['preferencePatterns'] as Map<String, dynamic>? ?? {},
      lastUpdated: DateTime.parse(json['lastUpdated'] as String),
    );
  }

  /// Convert UserBehaviorData to JSON
  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'interactions': interactions.map((i) => i.toJson()).toList(),
      'preferencePatterns': preferencePatterns,
      'lastUpdated': lastUpdated.toIso8601String(),
    };
  }
}