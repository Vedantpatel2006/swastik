import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'youtube_api_key_manager.dart';

/// Configuration class for YouTube Data API integration
class YouTubeApiConfig {
  // YouTube Data API v3 configuration - now managed by key manager
  // Configure your YouTube Data API v3 key in the .env file as YOUTUBE_API_KEY
  // Get it from: https://console.cloud.google.com/apis/credentials
  static const String _youtubeApiKey = '';

  static const String youtubeApiBaseUrl =
      'https://www.googleapis.com/youtube/v3';

  // Rate limiting — kept low since API is only called for user-triggered actions
  static const int maxRequestsPerMinute = 5;
  static const int maxRequestsPerDay =
      500; // Hard ceiling; RSS handles detection
  static const Duration rateLimitWindow = Duration(minutes: 1);
  static const Duration quotaResetWindow = Duration(days: 1);

  // Retry — only 1 retry to avoid doubling quota spend on failures
  static const int maxRetryAttempts = 1;
  static const Duration initialRetryDelay = Duration(seconds: 3);
  static const double retryBackoffMultiplier = 2.0;
  static const Duration maxRetryDelay = Duration(seconds: 30);

  // Cache — long TTLs so repeated UI interactions don't re-hit the API
  static const Duration liveStatusCacheTTL = Duration(hours: 6);
  static const Duration channelInfoCacheTTL = Duration(hours: 24);
  static const Duration searchResultsCacheTTL = Duration(hours: 12);

  // Error handling configuration
  static const Duration networkTimeout = Duration(seconds: 30);
  static const int maxConcurrentRequests = 5;

  // Fallback configuration
  static const Duration fallbackCacheTTL = Duration(hours: 24);
  static const bool enableOfflineFallback = true;

  /// Get the YouTube API key (with rotation support)
  static String get apiKey {
    try {
      return YouTubeApiKeyManager().getCurrentApiKey();
    } catch (e) {
      // Fallback to primary key if manager fails
      return _youtubeApiKey;
    }
  }

  /// Check if API key is properly configured
  static bool get isApiKeyConfigured {
    try {
      final key = YouTubeApiKeyManager().getCurrentApiKey();
      return key.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Get API endpoint URL with parameters and record usage
  static Uri getApiUrl(String endpoint, Map<String, String> parameters) {
    final params = Map<String, String>.from(parameters);
    params['key'] = apiKey;

    // Record API usage for quota tracking
    try {
      YouTubeApiKeyManager().recordUsage(
        cost: _getApiCost(endpoint, parameters),
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to record API usage: $e');
      }
    }

    return Uri.parse(
      '$youtubeApiBaseUrl/$endpoint',
    ).replace(queryParameters: params);
  }

  /// Calculate API cost based on endpoint and parameters
  static int _getApiCost(String endpoint, Map<String, String> parameters) {
    // YouTube API v3 quota costs
    switch (endpoint) {
      case 'search':
        return 100; // Search operations cost 100 units
      case 'videos':
        return 1; // Video details cost 1 unit
      case 'channels':
        return 1; // Channel details cost 1 unit
      case 'playlists':
        return 1; // Playlist details cost 1 unit
      default:
        return 1; // Default cost
    }
  }

  /// Validate configuration
  static bool validateConfiguration() {
    try {
      // Check API key
      if (!isApiKeyConfigured) {
        if (kDebugMode) {
          debugPrint('YouTube API configuration: API key not configured');
        }
        return false;
      }

      // Check rate limits are reasonable
      if (maxRequestsPerMinute <= 0 || maxRequestsPerDay <= 0) {
        if (kDebugMode) {
          debugPrint('YouTube API configuration: Invalid rate limits');
        }
        return false;
      }

      // Check retry configuration
      if (maxRetryAttempts < 0 || retryBackoffMultiplier <= 1.0) {
        if (kDebugMode) {
          debugPrint('YouTube API configuration: Invalid retry configuration');
        }
        return false;
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('YouTube API configuration validation error: $e');
      }
      return false;
    }
  }
}

/// YouTube API error codes and their meanings
enum YouTubeApiErrorCode {
  // Authentication errors
  invalidApiKey,
  authenticationRequired,

  // Quota errors
  quotaExceeded,
  rateLimitExceeded,

  // Resource errors
  channelNotFound,
  videoNotFound,
  playlistNotFound,

  // Network errors
  networkTimeout,
  connectionFailed,
  serverError,

  // Validation errors
  invalidRequest,
  invalidParameter,

  // General errors
  unknownError,
  serviceUnavailable,
}

/// YouTube API error details
class YouTubeApiError implements Exception {
  final YouTubeApiErrorCode code;
  final String message;
  final String? details;
  final int? httpStatusCode;
  final DateTime timestamp;
  final bool isRetryable;

  YouTubeApiError({
    required this.code,
    required this.message,
    this.details,
    this.httpStatusCode,
    DateTime? timestamp,
    this.isRetryable = false,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Create error from HTTP response
  factory YouTubeApiError.fromHttpResponse(
    int statusCode,
    String responseBody,
  ) {
    try {
      // Try to parse YouTube API error response
      final Map<String, dynamic>? errorData = _parseErrorResponse(responseBody);

      if (errorData != null) {
        final error = errorData['error'] as Map<String, dynamic>?;
        if (error != null) {
          final code = _mapErrorCode(
            error['code'] as int?,
            error['message'] as String?,
          );
          return YouTubeApiError(
            code: code,
            message: error['message'] as String? ?? 'Unknown API error',
            details: error['errors']?.toString(),
            httpStatusCode: statusCode,
            isRetryable: _isRetryableError(code, statusCode),
          );
        }
      }

      // Fallback to HTTP status code mapping
      final code = _mapHttpStatusToErrorCode(statusCode);
      return YouTubeApiError(
        code: code,
        message: 'HTTP $statusCode: ${_getDefaultMessage(code)}',
        httpStatusCode: statusCode,
        isRetryable: _isRetryableError(code, statusCode),
      );
    } catch (e) {
      return YouTubeApiError(
        code: YouTubeApiErrorCode.unknownError,
        message: 'Failed to parse error response: $e',
        details: responseBody,
        httpStatusCode: statusCode,
        isRetryable: statusCode >= 500,
      );
    }
  }

  /// Create network error
  factory YouTubeApiError.networkError(String message, {String? details}) {
    return YouTubeApiError(
      code: YouTubeApiErrorCode.connectionFailed,
      message: message,
      details: details,
      isRetryable: true,
    );
  }

  /// Create timeout error
  factory YouTubeApiError.timeout() {
    return YouTubeApiError(
      code: YouTubeApiErrorCode.networkTimeout,
      message: 'Request timed out',
      isRetryable: true,
    );
  }

  /// Create quota exceeded error
  factory YouTubeApiError.quotaExceeded() {
    return YouTubeApiError(
      code: YouTubeApiErrorCode.quotaExceeded,
      message: 'YouTube API quota exceeded',
      isRetryable: false,
    );
  }

  /// Get user-friendly error message
  String get userFriendlyMessage {
    switch (code) {
      case YouTubeApiErrorCode.invalidApiKey:
        return 'Live streaming service is temporarily unavailable';
      case YouTubeApiErrorCode.quotaExceeded:
        return 'Live streaming service is temporarily unavailable due to high usage';
      case YouTubeApiErrorCode.rateLimitExceeded:
        return 'Too many requests. Please try again in a moment';
      case YouTubeApiErrorCode.channelNotFound:
        return 'Live streaming channel not found';
      case YouTubeApiErrorCode.networkTimeout:
      case YouTubeApiErrorCode.connectionFailed:
        return 'Unable to connect to streaming service. Please check your internet connection';
      case YouTubeApiErrorCode.serverError:
      case YouTubeApiErrorCode.serviceUnavailable:
        return 'Streaming service is temporarily unavailable. Please try again later';
      default:
        return 'Unable to load live streaming. Please try again later';
    }
  }

  @override
  String toString() {
    return 'YouTubeApiError(code: $code, message: $message, httpStatus: $httpStatusCode, retryable: $isRetryable)';
  }

  // Private helper methods

  static Map<String, dynamic>? _parseErrorResponse(String responseBody) {
    try {
      final dynamic parsed = responseBody.isNotEmpty
          ? json.decode(responseBody)
          : null;
      return parsed as Map<String, dynamic>?;
    } catch (e) {
      return null;
    }
  }

  static YouTubeApiErrorCode _mapErrorCode(int? apiCode, String? message) {
    if (apiCode != null) {
      switch (apiCode) {
        case 400:
          if (message?.contains('quota') == true) {
            return YouTubeApiErrorCode.quotaExceeded;
          }
          return YouTubeApiErrorCode.invalidRequest;
        case 401:
          return YouTubeApiErrorCode.invalidApiKey;
        case 403:
          if (message?.contains('quota') == true) {
            return YouTubeApiErrorCode.quotaExceeded;
          }
          return YouTubeApiErrorCode.authenticationRequired;
        case 404:
          return YouTubeApiErrorCode.channelNotFound;
        case 429:
          return YouTubeApiErrorCode.rateLimitExceeded;
        case 500:
        case 502:
        case 503:
          return YouTubeApiErrorCode.serverError;
        default:
          return YouTubeApiErrorCode.unknownError;
      }
    }
    return YouTubeApiErrorCode.unknownError;
  }

  static YouTubeApiErrorCode _mapHttpStatusToErrorCode(int statusCode) {
    switch (statusCode) {
      case 400:
        return YouTubeApiErrorCode.invalidRequest;
      case 401:
        return YouTubeApiErrorCode.invalidApiKey;
      case 403:
        return YouTubeApiErrorCode.authenticationRequired;
      case 404:
        return YouTubeApiErrorCode.channelNotFound;
      case 429:
        return YouTubeApiErrorCode.rateLimitExceeded;
      case 500:
      case 502:
      case 503:
      case 504:
        return YouTubeApiErrorCode.serverError;
      default:
        return YouTubeApiErrorCode.unknownError;
    }
  }

  static bool _isRetryableError(YouTubeApiErrorCode code, int? httpStatusCode) {
    switch (code) {
      case YouTubeApiErrorCode.networkTimeout:
      case YouTubeApiErrorCode.connectionFailed:
      case YouTubeApiErrorCode.serverError:
      case YouTubeApiErrorCode.serviceUnavailable:
        return true;
      case YouTubeApiErrorCode.rateLimitExceeded:
        return true; // Can retry after delay
      default:
        return httpStatusCode != null && httpStatusCode >= 500;
    }
  }

  static String _getDefaultMessage(YouTubeApiErrorCode code) {
    switch (code) {
      case YouTubeApiErrorCode.invalidApiKey:
        return 'Invalid API key';
      case YouTubeApiErrorCode.quotaExceeded:
        return 'API quota exceeded';
      case YouTubeApiErrorCode.rateLimitExceeded:
        return 'Rate limit exceeded';
      case YouTubeApiErrorCode.channelNotFound:
        return 'Channel not found';
      case YouTubeApiErrorCode.networkTimeout:
        return 'Network timeout';
      case YouTubeApiErrorCode.connectionFailed:
        return 'Connection failed';
      case YouTubeApiErrorCode.serverError:
        return 'Server error';
      default:
        return 'Unknown error';
    }
  }
}
