import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../shared/services/youtube_api_manager.dart';

/// Live Stream Service
///
/// Handles live stream detection and video ID/URL resolution.
/// Does NOT provide embed URLs or WebView player support —
/// all playback is handled externally via YouTube app/browser.
class LiveStreamService {
  static final LiveStreamService _instance = LiveStreamService._internal();
  factory LiveStreamService() => _instance;
  LiveStreamService._internal();

  final YouTubeApiManager _apiManager = YouTubeApiManager();
  final Map<String, String> _videoIdCache = {};
  final Map<String, DateTime> _cacheTimestamps = {};

  // Cache video IDs for 2 hours — a live stream rarely changes video ID
  // mid-stream, and this prevents repeated 100-unit search calls.
  static const Duration _cacheExpiry = Duration(hours: 2);

  /// Get current live video ID for a channel.
  /// Returns a [LiveStreamResult] with the video ID on success.
  Future<LiveStreamResult> getCurrentLiveVideoId(String channelId) async {
    try {
      final cachedVideoId = _getCachedVideoId(channelId);
      if (cachedVideoId != null) {
        debugPrint('🎯 Using cached video ID: $cachedVideoId');
        return LiveStreamResult.success(cachedVideoId);
      }

      debugPrint('🔍 Fetching live video ID for channel: $channelId');

      final response = await _apiManager.searchLiveVideos(
        channelId: channelId,
        maxResults: 1,
        // Cache for 2 h — matches _cacheExpiry above, avoids redundant API calls
        cacheTTL: const Duration(hours: 2),
      );

      final items = response['items'] as List<dynamic>? ?? [];

      if (items.isEmpty) {
        debugPrint('❌ No live videos found for channel: $channelId');
        return LiveStreamResult.error('No live stream available');
      }

      final videoId = items[0]['id']['videoId'] as String;
      _cacheVideoId(channelId, videoId);

      debugPrint('✅ Found live video ID: $videoId');
      return LiveStreamResult.success(videoId);
    } catch (e) {
      debugPrint('❌ Error fetching live video ID: $e');
      return LiveStreamResult.error('Failed to fetch live stream: $e');
    }
  }

  /// Get live stream info including video ID and thumbnail.
  /// Viewer count is intentionally omitted — it requires the
  /// quota-heavy liveStreamingDetails API part.
  Future<LiveStreamInfo> getLiveStreamInfo(String channelId) async {
    try {
      final videoResult = await getCurrentLiveVideoId(channelId);

      if (!videoResult.isSuccess) {
        return LiveStreamInfo(isLive: false, error: videoResult.error);
      }

      final videoId = videoResult.videoId!;
      final videoDetails = await _getVideoDetails(videoId);

      return LiveStreamInfo(
        isLive: true,
        videoId: videoId,
        title: videoDetails['title'] as String?,
        description: videoDetails['description'] as String?,
        thumbnailUrl: videoDetails['thumbnailUrl'] as String?,
        startTime: videoDetails['startTime'] as DateTime?,
      );
    } catch (e) {
      debugPrint('❌ Error getting live stream info: $e');
      return LiveStreamInfo(
        isLive: false,
        error: 'Failed to get stream info: $e',
      );
    }
  }

  /// Build the YouTube watch URL for a video ID.
  /// Use this to open in YouTube app/browser via launchUrl().
  String getYouTubeWatchUrl(String videoId) {
    return 'https://www.youtube.com/watch?v=$videoId';
  }

  /// Build the YouTube channel URL for a channel ID.
  /// Used as fallback when no live video ID is available.
  String getYouTubeChannelUrl(String channelId) {
    return 'https://www.youtube.com/channel/$channelId';
  }

  /// Check if a video ID is still live.
  Future<bool> isVideoStillLive(String videoId) async {
    try {
      final videoDetails = await _getVideoDetails(videoId);
      return videoDetails['isLive'] as bool? ?? false;
    } catch (e) {
      debugPrint('❌ Error checking if video is still live: $e');
      return false;
    }
  }

  /// Clear cache for a specific channel.
  void clearCache(String channelId) {
    _videoIdCache.remove(channelId);
    _cacheTimestamps.remove(channelId);
  }

  /// Clear all cached video IDs.
  void clearAllCache() {
    _videoIdCache.clear();
    _cacheTimestamps.clear();
  }

  // ─── Private helpers ────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> _getVideoDetails(String videoId) async {
    try {
      final youtubeApi = YouTubeApiManager();
      await youtubeApi.initialize();

      final videoDetails = await youtubeApi.getVideoDetails(videoId);

      if (videoDetails != null) {
        return {
          'title': videoDetails['title'] ?? 'Live Stream',
          'description': videoDetails['description'] ?? 'Live darshan stream',
          'thumbnailUrl':
              videoDetails['thumbnailUrl'] ??
              'https://img.youtube.com/vi/$videoId/maxresdefault.jpg',
          'startTime': videoDetails['publishedAt'] != null
              ? DateTime.tryParse(videoDetails['publishedAt'] as String) ??
                    DateTime.now()
              : DateTime.now(),
          'isLive': videoDetails['isLive'] ?? false,
        };
      }

      return {
        'title': 'Live Stream',
        'description': 'Live darshan stream',
        'thumbnailUrl': 'https://img.youtube.com/vi/$videoId/maxresdefault.jpg',
        'startTime': DateTime.now(),
        'isLive': false,
      };
    } catch (e) {
      debugPrint('❌ Error getting video details: $e');
      return {
        'title': 'Live Stream',
        'description': 'Live darshan stream',
        'thumbnailUrl': 'https://img.youtube.com/vi/$videoId/maxresdefault.jpg',
        'startTime': DateTime.now(),
        'isLive': false,
      };
    }
  }

  void _cacheVideoId(String channelId, String videoId) {
    _videoIdCache[channelId] = videoId;
    _cacheTimestamps[channelId] = DateTime.now();
  }

  String? _getCachedVideoId(String channelId) {
    final videoId = _videoIdCache[channelId];
    final timestamp = _cacheTimestamps[channelId];

    if (videoId == null || timestamp == null) return null;

    if (DateTime.now().difference(timestamp) > _cacheExpiry) {
      _videoIdCache.remove(channelId);
      _cacheTimestamps.remove(channelId);
      return null;
    }

    return videoId;
  }
}

// ─── Result / Info models ──────────────────────────────────────────────────────

/// Result of a live video ID lookup.
class LiveStreamResult {
  final bool isSuccess;
  final String? videoId;
  final String? error;

  const LiveStreamResult._({
    required this.isSuccess,
    this.videoId,
    this.error,
  });

  factory LiveStreamResult.success(String videoId) =>
      LiveStreamResult._(isSuccess: true, videoId: videoId);

  factory LiveStreamResult.error(String error) =>
      LiveStreamResult._(isSuccess: false, error: error);
}

/// Metadata about a live stream.
/// viewerCount is intentionally absent — requires quota-heavy API part.
class LiveStreamInfo {
  final bool isLive;
  final String? videoId;
  final String? title;
  final String? description;
  final String? thumbnailUrl;
  final DateTime? startTime;
  final String? error;

  const LiveStreamInfo({
    required this.isLive,
    this.videoId,
    this.title,
    this.description,
    this.thumbnailUrl,
    this.startTime,
    this.error,
  });

  @override
  String toString() =>
      'LiveStreamInfo(isLive: $isLive, videoId: $videoId, title: $title, error: $error)';
}
