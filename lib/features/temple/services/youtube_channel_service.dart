import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class YouTubeChannelData {
  final String channelId;
  final String channelTitle;
  final String channelUrl;
  final String? description;
  final String? thumbnailUrl;
  final int? subscriberCount;

  YouTubeChannelData({
    required this.channelId,
    required this.channelTitle,
    required this.channelUrl,
    this.description,
    this.thumbnailUrl,
    this.subscriberCount,
  });
}

class YouTubeChannelService {
  static String get _apiKey => dotenv.env['YOUTUBE_API_KEY'] ?? '';

  /// Extract YouTube channel data from various URL formats.
  static Future<YouTubeChannelData?> getChannelDataFromUrl(String url) async {
    try {
      print('🎯 Starting extraction for URL: $url');

      final cleanUrl = url.trim().split('?')[0];
      print('🧹 Cleaned URL: $cleanUrl');
      if (cleanUrl.isEmpty) return null;

      String? channelId;
      String? handle;

      if (cleanUrl.contains('youtube.com/channel/')) {
        final match = RegExp(
          r'youtube\.com/channel/([a-zA-Z0-9_-]+)',
        ).firstMatch(cleanUrl);
        channelId = match?.group(1);
        print('📋 Extracted direct channel ID: $channelId');
      } else if (cleanUrl.contains('youtube.com/@')) {
        final match = RegExp(
          r'youtube\.com/@([a-zA-Z0-9_.-]+)',
        ).firstMatch(cleanUrl);
        handle = match?.group(1);
        print('🏷️ Extracted handle: $handle');
      } else if (cleanUrl.contains('youtube.com/c/') ||
          cleanUrl.contains('youtube.com/user/')) {
        final match = RegExp(
          r'youtube\.com/(?:c|user)/([a-zA-Z0-9_-]+)',
        ).firstMatch(cleanUrl);
        handle = match?.group(1);
        print('🏷️ Extracted legacy handle: $handle');
      } else if (cleanUrl.startsWith('@')) {
        handle = cleanUrl.substring(1);
        print('🏷️ Bare handle: $handle');
      } else {
        handle = cleanUrl;
        print('🏷️ Assuming handle: $handle');
      }

      if (channelId != null) {
        print('🎯 Using direct channel ID: $channelId');
        return await _getChannelDataById(channelId);
      }

      if (handle != null) {
        print('🎯 Resolving handle to channel ID: $handle');
        channelId = await _getChannelIdFromHandle(handle);
        if (channelId != null) {
          print('✅ Resolved to channel ID: $channelId');
          return await _getChannelDataById(channelId);
        } else {
          print('⚠️ API failed, returning null so admin can enter ID manually');
          return null;
        }
      }

      print('❌ No valid channel ID or handle found');
      return null;
    } catch (e) {
      print('❌ Error extracting YouTube channel data: $e');
      return null;
    }
  }

  /// Get channel ID from handle using YouTube API.
  /// Uses channels?forHandle= (1 unit) then channels?forUsername= (1 unit).
  /// Never falls back to search (100 units).
  static Future<String?> _getChannelIdFromHandle(String handle) async {
    try {
      print('🔍 Trying to get channel ID for handle: $handle');

      final url = Uri.parse(
        'https://www.googleapis.com/youtube/v3/channels'
        '?part=id'
        '&forHandle=${Uri.encodeComponent(handle)}'
        '&key=$_apiKey',
      );

      print('📡 API URL: $url');
      final response = await http.get(url);
      print('📊 Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final items = data['items'] as List?;
        if (items != null && items.isNotEmpty) {
          final channelId = items[0]['id'] as String;
          print('✅ Found channel ID via forHandle: $channelId');
          return channelId;
        }
        print('⚠️ forHandle returned no results, trying forUsername...');
      } else if (response.statusCode == 403) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final reason =
            (data['error']?['errors'] as List?)?.firstOrNull?['reason']
                as String?;
        if (reason == 'quotaExceeded') {
          print('⚠️ YouTube API quota exceeded');
          return null;
        }
        print('❌ forHandle API failed with 403: ${response.body}');
        return null;
      } else {
        print('❌ forHandle API failed with status: ${response.statusCode}');
      }

      // Fallback: forUsername (1 unit) — for legacy channels
      final usernameUrl = Uri.parse(
        'https://www.googleapis.com/youtube/v3/channels'
        '?part=id'
        '&forUsername=${Uri.encodeComponent(handle)}'
        '&key=$_apiKey',
      );
      final usernameResponse = await http.get(usernameUrl);
      if (usernameResponse.statusCode == 200) {
        final data = json.decode(usernameResponse.body) as Map<String, dynamic>;
        final items = data['items'] as List?;
        if (items != null && items.isNotEmpty) {
          final channelId = items[0]['id'] as String;
          print('✅ Found channel ID via forUsername: $channelId');
          return channelId;
        }
      }

      print(
        '❌ Could not resolve handle to channel ID (no search fallback to save quota)',
      );
      return null;
    } catch (e) {
      print('❌ Error getting channel ID from handle: $e');
      return null;
    }
  }

  /// Get detailed channel data by channel ID.
  /// Uses only `snippet` part (1 unit) — statistics part is not needed
  /// for display and would cost extra quota.
  static Future<YouTubeChannelData?> _getChannelDataById(
    String channelId,
  ) async {
    try {
      final url = Uri.parse(
        'https://www.googleapis.com/youtube/v3/channels'
        '?part=snippet'
        '&id=$channelId'
        '&key=$_apiKey',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final items = data['items'] as List?;
        if (items != null && items.isNotEmpty) {
          final channel = items[0] as Map<String, dynamic>;
          final snippet = channel['snippet'] as Map<String, dynamic>? ?? {};

          return YouTubeChannelData(
            channelId: channelId,
            channelTitle: snippet['title'] as String? ?? '',
            channelUrl: 'https://youtube.com/channel/$channelId',
            description: snippet['description'] as String?,
            thumbnailUrl:
                (snippet['thumbnails'] as Map?)?['default']?['url'] as String?,
            subscriberCount: null, // omitted — requires statistics part
          );
        }
      }
    } catch (e) {
      print('❌ Error getting channel data by ID: $e');
    }
    return null;
  }

  /// Extract channel handle from URL for display purposes
  static String? extractHandleFromUrl(String url) {
    try {
      if (url.contains('youtube.com/@')) {
        final match = RegExp(r'youtube\.com/@([a-zA-Z0-9_-]+)').firstMatch(url);
        return '@${match?.group(1)}';
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}