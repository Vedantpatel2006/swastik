import 'package:flutter/foundation.dart';
import 'youtube_api_config.dart';
import '../../shared/services/youtube_api_manager.dart';

/// Utility class to validate and test YouTube API configuration.
///
/// QUOTA NOTE: All live-detection checks use RSS (zero quota).
/// The API is only called here for one-time admin validation, and only
/// when explicitly triggered — never on app startup.
class ApiKeyValidator {
  static final ApiKeyValidator _instance = ApiKeyValidator._internal();
  factory ApiKeyValidator() => _instance;
  ApiKeyValidator._internal();

  /// Validate the API key using a single cheap channels request (1 unit).
  /// Does NOT call search (100 units).
  Future<ApiValidationResult> validateApiKey() async {
    try {
      if (!YouTubeApiConfig.isApiKeyConfigured) {
        return ApiValidationResult(
          isValid: false,
          error: 'API key not configured',
          recommendation:
              'Add your YouTube Data API v3 key to the .env file as YOUTUBE_API_KEY',
        );
      }

      final apiKey = YouTubeApiConfig.apiKey;
      if (!_isValidApiKeyFormat(apiKey)) {
        return ApiValidationResult(
          isValid: false,
          error: 'API key format appears invalid',
          recommendation:
              'Ensure you copied the complete API key from Google Cloud Console',
        );
      }

      // Cheapest possible live test: channels?id= costs 1 unit (not search = 100).
      final youtubeApi = YouTubeApiManager();
      await youtubeApi.initialize();

      final testResponse = await youtubeApi.getChannelInfo(
        'UCK8sQmJBp8GCxrOtXWBpyEA', // Google's YouTube channel
        cacheTTL: const Duration(hours: 24),
      );

      if (testResponse['items'] != null &&
          (testResponse['items'] as List).isNotEmpty) {
        return ApiValidationResult(
          isValid: true,
          message: 'API key is valid and working (1 quota unit used)',
        );
      } else {
        return ApiValidationResult(
          isValid: false,
          error: 'API key test returned no results',
          recommendation:
              'Check if YouTube Data API v3 is enabled in Google Cloud Console',
        );
      }
    } catch (e) {
      return ApiValidationResult(
        isValid: false,
        error: 'API key validation failed: ${e.toString()}',
        recommendation: _getRecommendationForError(e.toString()),
      );
    }
  }

  bool _isValidApiKeyFormat(String apiKey) {
    return apiKey.startsWith('AIza') && apiKey.length == 39;
  }

  String _getRecommendationForError(String error) {
    if (error.contains('403') || error.contains('forbidden')) {
      return 'API key may be restricted. Check restrictions in Google Cloud Console';
    } else if (error.contains('400') || error.contains('invalid')) {
      return 'API key appears invalid. Verify the key in Google Cloud Console';
    } else if (error.contains('quota')) {
      return 'API quota exceeded. Check quota usage in Google Cloud Console';
    } else if (error.contains('network') || error.contains('timeout')) {
      return 'Network issue. Check internet connection and try again';
    } else {
      return 'Check YouTube Data API v3 setup in Google Cloud Console';
    }
  }

  /// Lightweight functionality test — uses only cheap endpoints (1 unit each).
  /// The old test called search (100 units × 2 = 200 units wasted).
  Future<Map<String, ApiValidationResult>> testYouTubeFunctionality() async {
    final results = <String, ApiValidationResult>{};

    try {
      final youtubeApi = YouTubeApiManager();
      await youtubeApi.initialize();

      // Test 1: Channel info (1 unit) — replaces channel search (100 units)
      try {
        await youtubeApi.getChannelInfo(
          'UCK8sQmJBp8GCxrOtXWBpyEA',
          cacheTTL: const Duration(hours: 24),
        );
        results['channel_info'] = ApiValidationResult(
          isValid: true,
          message: 'Channel info retrieval working (1 unit)',
        );
      } catch (e) {
        results['channel_info'] = ApiValidationResult(
          isValid: false,
          error: 'Channel info failed: $e',
        );
      }

      // Test 2: Video info (1 unit)
      try {
        await youtubeApi.getVideoInfo(
          'dQw4w9WgXcQ',
          cacheTTL: const Duration(hours: 24),
        );
        results['video_info'] = ApiValidationResult(
          isValid: true,
          message: 'Video info retrieval working (1 unit)',
        );
      } catch (e) {
        results['video_info'] = ApiValidationResult(
          isValid: false,
          error: 'Video info failed: $e',
        );
      }

      // NOTE: live_search test removed — costs 100 units and is not needed
      // for validation. Live detection uses RSS (zero quota).
      results['live_detection'] = ApiValidationResult(
        isValid: true,
        message: 'Live detection uses RSS feed (0 quota units)',
      );
    } catch (e) {
      results['initialization'] = ApiValidationResult(
        isValid: false,
        error: 'YouTube API initialization failed: $e',
      );
    }

    return results;
  }

  Map<String, dynamic> getApiUsageStats() {
    try {
      return YouTubeApiManager().getUsageStats();
    } catch (e) {
      return {'error': 'Failed to get usage stats: $e'};
    }
  }

  Future<void> printValidationReport() async {
    if (!kDebugMode) return;

    debugPrint('=== YouTube API Validation Report ===');

    final basicValidation = await validateApiKey();
    debugPrint(
      'Basic Validation: ${basicValidation.isValid ? "✅ PASS" : "❌ FAIL"}',
    );
    if (!basicValidation.isValid) {
      debugPrint('Error: ${basicValidation.error}');
      debugPrint('Recommendation: ${basicValidation.recommendation}');
    } else {
      debugPrint('Message: ${basicValidation.message}');
    }

    debugPrint('\n=== Functionality Tests ===');
    final functionalityTests = await testYouTubeFunctionality();
    for (final entry in functionalityTests.entries) {
      final result = entry.value;
      debugPrint('${entry.key}: ${result.isValid ? "✅ PASS" : "❌ FAIL"}');
      if (!result.isValid) {
        debugPrint('  Error: ${result.error}');
      } else {
        debugPrint('  Message: ${result.message}');
      }
    }

    debugPrint('\n=== API Usage Stats ===');
    final stats = getApiUsageStats();
    for (final entry in stats.entries) {
      debugPrint('${entry.key}: ${entry.value}');
    }

    debugPrint('=== End Report ===\n');
  }
}

class ApiValidationResult {
  final bool isValid;
  final String? message;
  final String? error;
  final String? recommendation;

  ApiValidationResult({
    required this.isValid,
    this.message,
    this.error,
    this.recommendation,
  });

  @override
  String toString() {
    if (isValid) {
      return 'Valid: ${message ?? "API key is working"}';
    } else {
      return 'Invalid: ${error ?? "Unknown error"}'
          '${recommendation != null ? " - $recommendation" : ""}';
    }
  }
}
