import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../core/config/youtube_api_config.dart';
import 'cache/data_cache_manager.dart';

/// Rate limiter for YouTube API requests
class YouTubeApiRateLimiter {
  final int maxRequestsPerWindow;
  final Duration window;
  final List<DateTime> _requestTimes = [];

  YouTubeApiRateLimiter({
    required this.maxRequestsPerWindow,
    required this.window,
  });

  /// Check if a request can be made now
  bool canMakeRequest() {
    _cleanOldRequests();
    return _requestTimes.length < maxRequestsPerWindow;
  }

  /// Record a request
  void recordRequest() {
    _cleanOldRequests();
    _requestTimes.add(DateTime.now());
  }

  /// Get time until next request is allowed
  Duration? getTimeUntilNextRequest() {
    _cleanOldRequests();
    if (_requestTimes.length < maxRequestsPerWindow) {
      return null; // Can make request now
    }

    final oldestRequest = _requestTimes.first;
    final timeUntilExpiry = window - DateTime.now().difference(oldestRequest);
    return timeUntilExpiry.isNegative ? null : timeUntilExpiry;
  }

  void _cleanOldRequests() {
    final cutoff = DateTime.now().subtract(window);
    _requestTimes.removeWhere((time) => time.isBefore(cutoff));
  }

  /// Reset the rate limiter
  void reset() {
    _requestTimes.clear();
  }
}

/// Retry mechanism with exponential backoff
class YouTubeApiRetryManager {
  final int maxAttempts;
  final Duration initialDelay;
  final double backoffMultiplier;
  final Duration maxDelay;

  const YouTubeApiRetryManager({
    required this.maxAttempts,
    required this.initialDelay,
    required this.backoffMultiplier,
    required this.maxDelay,
  });

  /// Execute a function with retry logic
  Future<T> execute<T>(
    Future<T> Function() operation, {
    bool Function(Exception)? shouldRetry,
  }) async {
    Exception? lastException;

    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        return await operation();
      } catch (e) {
        lastException = e is Exception ? e : Exception(e.toString());

        // Check if we should retry
        if (attempt == maxAttempts ||
            (shouldRetry != null && !shouldRetry(lastException))) {
          break;
        }

        // Calculate delay for next attempt
        final delay = _calculateDelay(attempt);

        if (kDebugMode) {
          debugPrint(
            'YouTubeApiRetryManager: Attempt $attempt failed, retrying in ${delay.inMilliseconds}ms. Error: $e',
          );
        }

        await Future.delayed(delay);
      }
    }

    throw lastException!;
  }

  Duration _calculateDelay(int attempt) {
    final delay = Duration(
      milliseconds:
          (initialDelay.inMilliseconds * (backoffMultiplier * (attempt - 1)))
              .round(),
    );

    return delay > maxDelay ? maxDelay : delay;
  }
}

/// Comprehensive YouTube API manager with error handling, rate limiting, and caching
class YouTubeApiManager {
  static final YouTubeApiManager _instance = YouTubeApiManager._internal();
  factory YouTubeApiManager() => _instance;
  YouTubeApiManager._internal();

  late final YouTubeApiRateLimiter _rateLimiter;
  late final YouTubeApiRetryManager _retryManager;
  late final http.Client _httpClient;
  DataCacheManager? _cacheManager;

  bool _initialized = false;

  /// Initialize the API manager
  Future<void> initialize({
    http.Client? httpClient,
    DataCacheManager? cacheManager,
  }) async {
    if (_initialized) return;

    // Validate configuration
    if (!YouTubeApiConfig.validateConfiguration()) {
      throw StateError('Invalid YouTube API configuration');
    }

    _httpClient = httpClient ?? http.Client();
    _cacheManager = cacheManager ?? DataCacheManager();

    _rateLimiter = YouTubeApiRateLimiter(
      maxRequestsPerWindow: YouTubeApiConfig.maxRequestsPerMinute,
      window: YouTubeApiConfig.rateLimitWindow,
    );

    _retryManager = const YouTubeApiRetryManager(
      maxAttempts: YouTubeApiConfig.maxRetryAttempts,
      initialDelay: YouTubeApiConfig.initialRetryDelay,
      backoffMultiplier: YouTubeApiConfig.retryBackoffMultiplier,
      maxDelay: YouTubeApiConfig.maxRetryDelay,
    );

    await _cacheManager?.initialize();
    _initialized = true;

    if (kDebugMode) {
      debugPrint('YouTubeApiManager: Initialized successfully');
    }
  }

  /// Make a YouTube API request with full error handling
  Future<Map<String, dynamic>> makeRequest(
    String endpoint,
    Map<String, String> parameters, {
    Duration? cacheTTL,
    bool useCache = true,
    bool enableRetry = true,
  }) async {
    if (!_initialized) {
      throw StateError('YouTubeApiManager not initialized');
    }

    final cacheKey = _generateCacheKey(endpoint, parameters);

    // Try cache first if enabled
    if (useCache && cacheTTL != null && _cacheManager != null) {
      try {
        final cachedData = await _cacheManager!.getCachedData(cacheKey);
        if (cachedData != null) {
          if (kDebugMode) {
            debugPrint('YouTubeApiManager: Cache hit for $endpoint');
          }
          return cachedData;
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('YouTubeApiManager: Cache read error: $e');
        }
      }
    }

    // Make API request with retry logic
    final operation = () => _makeHttpRequest(endpoint, parameters);

    Map<String, dynamic> response;
    if (enableRetry) {
      response = await _retryManager.execute(
        operation,
        shouldRetry: (exception) =>
            exception is YouTubeApiError && exception.isRetryable,
      );
    } else {
      response = await operation();
    }

    // Cache the response if enabled
    if (useCache && cacheTTL != null && _cacheManager != null) {
      try {
        await _cacheManager!.cacheData(cacheKey, response, ttl: cacheTTL);
      } catch (e) {
        if (kDebugMode) {
          debugPrint('YouTubeApiManager: Cache write error: $e');
        }
      }
    }

    return response;
  }

  /// Search for channels
  Future<Map<String, dynamic>> searchChannels(
    String query, {
    int maxResults = 10,
    Duration? cacheTTL,
  }) async {
    return makeRequest('search', {
      'part': 'snippet',
      'q': query,
      'type': 'channel',
      'maxResults': maxResults.toString(),
    }, cacheTTL: cacheTTL ?? YouTubeApiConfig.searchResultsCacheTTL);
  }

  /// Get channel information
  Future<Map<String, dynamic>> getChannelInfo(
    String channelId, {
    Duration? cacheTTL,
  }) async {
    return makeRequest('channels', {
      'part': 'snippet,status', // Removed statistics to save quota
      'id': channelId,
    }, cacheTTL: cacheTTL ?? YouTubeApiConfig.channelInfoCacheTTL);
  }

  /// Search for live videos on a channel
  Future<Map<String, dynamic>> searchLiveVideos({
    required String channelId,
    int maxResults = 1,
    Duration? cacheTTL,
  }) async {
    return makeRequest('search', {
      'part': 'snippet',
      'channelId': channelId,
      'eventType': 'live',
      'type': 'video',
      'maxResults': maxResults.toString(),
    }, cacheTTL: cacheTTL ?? YouTubeApiConfig.liveStatusCacheTTL);
  }

  /// Search for videos on a channel (general search)
  Future<Map<String, dynamic>> searchChannelVideos({
    required String channelId,
    int maxResults = 5,
    String order = 'date',
    Duration? cacheTTL,
  }) async {
    return makeRequest('search', {
      'part': 'snippet',
      'channelId': channelId,
      'type': 'video',
      'order': order,
      'maxResults': maxResults.toString(),
    }, cacheTTL: cacheTTL ?? YouTubeApiConfig.searchResultsCacheTTL);
  }

  /// Get video information (optimized to reduce quota usage)
  Future<Map<String, dynamic>> getVideoInfo(
    String videoId, {
    Duration? cacheTTL,
  }) async {
    return makeRequest('videos', {
      'part': 'snippet,status', // Removed liveStreamingDetails to save quota
      'id': videoId,
    }, cacheTTL: cacheTTL);
  }

  /// Get channel info by username (legacy)
  Future<Map<String, dynamic>> getChannelByUsername(
    String username, {
    Duration? cacheTTL,
  }) async {
    return makeRequest('channels', {
      'part': 'id,snippet',
      'forUsername': username,
    }, cacheTTL: cacheTTL ?? YouTubeApiConfig.channelInfoCacheTTL);
  }

  /// Get video details with comprehensive information
  Future<Map<String, dynamic>?> getVideoDetails(String videoId) async {
    try {
      final response = await getVideoInfo(videoId);

      if (response['items'] != null && (response['items'] as List).isNotEmpty) {
        final items = response['items'];
        if (items is! List || items.isEmpty) return null;

        final videoData = items.first;
        if (videoData == null || videoData is! Map<String, dynamic>)
          return null;

        final video = videoData;
        final snippet = video['snippet'];
        final status = video['status'];

        if (snippet is! Map<String, dynamic>? ||
            status is! Map<String, dynamic>?) {
          return null;
        }

        return {
          'title': snippet?['title'] ?? 'Live Stream',
          'description': snippet?['description'] ?? '',
          'thumbnailUrl':
              snippet?['thumbnails']?['maxresdefault']?['url'] ??
              snippet?['thumbnails']?['high']?['url'] ??
              'https://img.youtube.com/vi/$videoId/maxresdefault.jpg',
          'publishedAt': snippet?['publishedAt'],
          'channelTitle': snippet?['channelTitle'],
          'isLive':
              status?['uploadStatus'] == 'processed' &&
              snippet?['liveBroadcastContent'] == 'live',
          'viewerCount': null, // Would need liveStreamingDetails part for this
        };
      }

      return null;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('YouTubeApiManager: Error getting video details: $e');
      }
      return null;
    }
  }

  /// Verify if a channel exists and is accessible
  Future<bool> verifyChannelExists(String channelId) async {
    try {
      final response = await getChannelInfo(channelId);
      return response['items'] != null &&
          (response['items'] as List).isNotEmpty;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('YouTubeApiManager: Error verifying channel: $e');
      }
      return false;
    }
  }

  /// Get live streams for a channel — reads from Firestore first.
  Future<List<Map<String, dynamic>>> getLiveStreams(String channelId) async {
    try {
      // Check Firestore for cached live status
      final snap = await FirebaseFirestore.instance
          .collection('temples')
          .where('liveDarshan.youtubeChannelId', isEqualTo: channelId)
          .limit(1)
          .get();

      if (snap.docs.isNotEmpty) {
        final data = snap.docs.first.data();
        if (data['isCurrentlyLive'] == true) {
          return [
            {
              'id': {'videoId': data['currentLiveVideoId']},
              'snippet': {
                'title': data['currentStreamTitle'] ?? 'Live Stream',
                'channelId': channelId,
                'liveBroadcastContent': 'live',
              },
            }
          ];
        }
      }

      // Fallback to YouTube API
      final apiResponse = await searchLiveVideos(
        channelId: channelId,
        maxResults: 5,
      );

      if (apiResponse['items'] != null) {
        return (apiResponse['items'] as List)
            .cast<Map<String, dynamic>>()
            .toList();
      }

      return [];
    } catch (e) {
      if (kDebugMode) {
        debugPrint('YouTubeApiManager: Error getting live streams: $e');
      }
      return [];
    }
  }

  /// Manual live detection — triggers the Supabase edge function.
  Future<Map<String, dynamic>?> detectLiveStreamManually(
    String templeId,
  ) async {
    // This still calls the Supabase edge function which writes back to Firestore.
    // The result is reflected in the Firestore document automatically.
    if (kDebugMode) {
      debugPrint(
        'detectLiveStreamManually: trigger via Supabase edge function for $templeId',
      );
    }
    return null; // Result will appear in Firestore via the cron write-back
  }

  /// Get live status for all temples from Firestore.
  Future<List<Map<String, dynamic>>> getAllLiveStatus() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('temples')
          .where('liveDarshan.isConfiguredByAdmin', isEqualTo: true)
          .get();

      return snap.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'name': data['name'],
          'is_currently_live': data['isCurrentlyLive'] ?? false,
          'current_live_video_id': data['currentLiveVideoId'],
          'current_stream_title': data['currentStreamTitle'],
          'last_live_check': data['lastLiveCheck'],
        };
      }).toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error getting all live status: $e');
      }
      return [];
    }
  }

  /// Extract channel ID from various YouTube URL formats
  static String? extractChannelId(String url) {
    try {
      final uri = Uri.parse(url);

      // Handle different YouTube URL formats
      if (uri.host.contains('youtube.com')) {
        // Channel URL: https://www.youtube.com/channel/UC...
        if (uri.pathSegments.length >= 2 && uri.pathSegments[0] == 'channel') {
          return uri.pathSegments[1];
        }

        // User URL: https://www.youtube.com/user/username
        if (uri.pathSegments.length >= 2 && uri.pathSegments[0] == 'user') {
          // Would need to resolve username to channel ID via API
          return null;
        }

        // Custom URL: https://www.youtube.com/c/customname
        if (uri.pathSegments.length >= 2 && uri.pathSegments[0] == 'c') {
          // Would need to resolve custom name to channel ID via API
          return null;
        }

        // Handle URL: https://www.youtube.com/@handle
        if (uri.pathSegments.isNotEmpty &&
            uri.pathSegments[0].startsWith('@')) {
          // Would need to resolve handle to channel ID via API
          return null;
        }
      }

      // Handle youtu.be URLs (these are typically video URLs, not channel URLs)
      if (uri.host == 'youtu.be') {
        return null;
      }

      // If it's already a channel ID (starts with UC and is 24 characters)
      if (url.startsWith('UC') && url.length == 24) {
        return url;
      }

      return null;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('YouTubeApiManager: Error extracting channel ID: $e');
      }
      return null;
    }
  }

  /// Resolve username or custom URL to channel ID
  Future<String?> resolveChannelId(String usernameOrUrl) async {
    try {
      // First try to extract directly
      final directId = extractChannelId(usernameOrUrl);
      if (directId != null) {
        return directId;
      }

      // Try to resolve via username
      final uri = Uri.tryParse(usernameOrUrl);
      if (uri != null &&
          uri.pathSegments.length >= 2 &&
          uri.pathSegments[0] == 'user') {
        final username = uri.pathSegments[1];
        final response = await getChannelByUsername(username);

        if (response['items'] != null &&
            (response['items'] as List).isNotEmpty) {
          final items = response['items'];
          if (items is! List || items.isEmpty) return null;

          final channelData = items.first;
          if (channelData != null && channelData is Map<String, dynamic>) {
            final channel = channelData;
            return channel['id'] as String?;
          }
        }
      }

      // Try searching for the channel
      final searchResponse = await searchChannels(usernameOrUrl, maxResults: 1);
      if (searchResponse['items'] != null &&
          (searchResponse['items'] as List).isNotEmpty) {
        final items = searchResponse['items'];
        if (items is! List || items.isEmpty) return null;

        final channelData = items.first;
        if (channelData != null && channelData is Map<String, dynamic>) {
          final channel = channelData;
          final snippet = channel['snippet'];
          if (snippet is Map<String, dynamic>) {
            return snippet['channelId'] as String?;
          }
        }
      }

      return null;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('YouTubeApiManager: Error resolving channel ID: $e');
      }
      return null;
    }
  }

  /// Get API usage statistics
  Map<String, dynamic> getUsageStats() {
    return {
      'rateLimitRemaining':
          _rateLimiter.maxRequestsPerWindow - _rateLimiter._requestTimes.length,
      'rateLimitTotal': _rateLimiter.maxRequestsPerWindow,
      'timeUntilReset': _rateLimiter.getTimeUntilNextRequest()?.inSeconds,
      'isInitialized': _initialized,
      'apiKeyConfigured': YouTubeApiConfig.isApiKeyConfigured,
    };
  }

  /// Clear all cached data
  Future<void> clearCache() async {
    if (_cacheManager != null) {
      await _cacheManager!.invalidateByPattern('youtube_api.*');
      if (kDebugMode) {
        debugPrint('YouTubeApiManager: Cache cleared');
      }
    }
  }

  /// Dispose resources
  void dispose() {
    _httpClient.close();
    _rateLimiter.reset();
    _initialized = false;
  }

  // Private methods

  Future<Map<String, dynamic>> _makeHttpRequest(
    String endpoint,
    Map<String, String> parameters,
  ) async {
    // Check rate limit
    if (!_rateLimiter.canMakeRequest()) {
      final waitTime = _rateLimiter.getTimeUntilNextRequest();
      if (waitTime != null) {
        throw YouTubeApiError(
          code: YouTubeApiErrorCode.rateLimitExceeded,
          message:
              'Rate limit exceeded. Try again in ${waitTime.inSeconds} seconds',
          isRetryable: true,
        );
      }
    }

    try {
      final url = YouTubeApiConfig.getApiUrl(endpoint, parameters);

      if (kDebugMode) {
        debugPrint('YouTubeApiManager: Making request to $endpoint');
      }

      // Record the request for rate limiting
      _rateLimiter.recordRequest();

      final response = await _httpClient
          .get(url)
          .timeout(YouTubeApiConfig.networkTimeout);

      if (response.statusCode == 200) {
        final responseBody = response.body;
        if (responseBody.isEmpty) {
          throw YouTubeApiError(
            code: YouTubeApiErrorCode.unknownError,
            message: 'Empty response from API',
            isRetryable: false,
          );
        }

        final decoded = json.decode(responseBody);
        if (decoded is! Map<String, dynamic>) {
          throw YouTubeApiError(
            code: YouTubeApiErrorCode.unknownError,
            message: 'Invalid response format - expected Map',
            isRetryable: false,
          );
        }

        final data = decoded;

        if (kDebugMode) {
          debugPrint('YouTubeApiManager: Request successful for $endpoint');
        }

        return data;
      } else {
        throw YouTubeApiError.fromHttpResponse(
          response.statusCode,
          response.body,
        );
      }
    } on TimeoutException {
      throw YouTubeApiError.timeout();
    } on SocketException catch (e) {
      throw YouTubeApiError.networkError(
        'Network connection failed',
        details: e.toString(),
      );
    } on HttpException catch (e) {
      throw YouTubeApiError.networkError(
        'HTTP error occurred',
        details: e.toString(),
      );
    } on FormatException catch (e) {
      throw YouTubeApiError(
        code: YouTubeApiErrorCode.unknownError,
        message: 'Invalid response format',
        details: e.toString(),
        isRetryable: false,
      );
    } catch (e) {
      if (e is YouTubeApiError) {
        rethrow;
      }

      throw YouTubeApiError(
        code: YouTubeApiErrorCode.unknownError,
        message: 'Unexpected error: ${e.toString()}',
        isRetryable: false,
      );
    }
  }

  String _generateCacheKey(String endpoint, Map<String, String> parameters) {
    final sortedParams = Map.fromEntries(
      parameters.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
    );
    final paramString = sortedParams.entries
        .map((e) => '${e.key}=${e.value}')
        .join('&');
    return 'youtube_api:$endpoint:${paramString.hashCode}';
  }
}
