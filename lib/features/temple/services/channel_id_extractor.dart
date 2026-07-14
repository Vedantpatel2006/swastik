import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../../shared/services/youtube_api_manager.dart';

/// Service to extract real YouTube channel IDs from various URL formats
class ChannelIdExtractor {
  static final ChannelIdExtractor _instance = ChannelIdExtractor._internal();
  factory ChannelIdExtractor() => _instance;
  ChannelIdExtractor._internal();

  final YouTubeApiManager _apiManager = YouTubeApiManager();
  final http.Client _httpClient = http.Client();

  /// Extract channel ID from various YouTube URL formats
  Future<String?> extractChannelId(String url) async {
    try {
      if (url.isEmpty) return null;

      final cleanUrl = _normalizeUrl(url);
      if (cleanUrl == null) return null;

      // Try different extraction methods
      String? channelId;

      // Method 1: Direct channel ID from URL
      channelId = _extractDirectChannelId(cleanUrl);
      if (channelId != null) {
        debugPrint('✅ Extracted direct channel ID: $channelId');
        return channelId;
      }

      // Method 2: Extract from @username format
      channelId = await _extractFromHandle(cleanUrl);
      if (channelId != null) {
        debugPrint('✅ Extracted channel ID from handle: $channelId');
        return channelId;
      }

      // Method 3: Extract from /c/ or /user/ format
      channelId = await _extractFromCustomUrl(cleanUrl);
      if (channelId != null) {
        debugPrint('✅ Extracted channel ID from custom URL: $channelId');
        return channelId;
      }

      // Method 4: Scrape from page HTML (fallback)
      channelId = await _extractFromPageScraping(cleanUrl);
      if (channelId != null) {
        debugPrint('✅ Extracted channel ID from page scraping: $channelId');
        return channelId;
      }

      debugPrint('❌ Could not extract channel ID from: $cleanUrl');
      return null;

    } catch (e) {
      debugPrint('❌ Error extracting channel ID: $e');
      return null;
    }
  }

  String? _normalizeUrl(String url) {
    try {
      url = url.trim();
      if (url.isEmpty) return null;

      if (!url.startsWith('http')) {
        url = 'https://$url';
      }

      url = url.replaceAll('youtu.be/', 'youtube.com/');
      url = url.replaceAll('www.youtube.com', 'youtube.com');
      url = url.replaceAll('m.youtube.com', 'youtube.com');

      final uri = Uri.parse(url);
      final cleanUri = Uri(
        scheme: uri.scheme,
        host: uri.host,
        path: uri.path,
      );

      return cleanUri.toString();
    } catch (e) {
      debugPrint('Error normalizing URL: $e');
      return null;
    }
  }

  String? _extractDirectChannelId(String url) {
    final channelMatch = RegExp(r'/channel/([a-zA-Z0-9_-]+)').firstMatch(url);
    if (channelMatch != null) {
      final channelId = channelMatch.group(1);
      if (channelId != null && channelId.startsWith('UC') && channelId.length == 24) {
        return channelId;
      }
    }
    return null;
  }

  Future<String?> _extractFromHandle(String url) async {
    try {
      final handleMatch = RegExp(r'/@([a-zA-Z0-9_.-]+)').firstMatch(url);
      if (handleMatch == null) return null;

      final handle = handleMatch.group(1);
      if (handle == null) return null;

      debugPrint('🔍 Looking up channel ID for handle: @$handle');

      // Use channels?forHandle= for an EXACT handle lookup (1 quota unit).
      // Never use search here — search returns fuzzy results and can return
      // a completely different (more popular) channel for the same query.
      final response = await _apiManager.makeRequest('channels', {
        'part': 'id',
        'forHandle': '@$handle',
      });

      final items = response['items'] as List<dynamic>?;
      if (items != null && items.isNotEmpty) {
        final channelId = items.first['id'] as String?;
        if (channelId != null && channelId.startsWith('UC')) {
          debugPrint('✅ Exact handle lookup → $channelId');
          return channelId;
        }
      }

      // forHandle returned nothing — fall back to forUsername (legacy channels)
      final usernameResponse = await _apiManager.makeRequest('channels', {
        'part': 'id',
        'forUsername': handle,
      });

      final usernameItems = usernameResponse['items'] as List<dynamic>?;
      if (usernameItems != null && usernameItems.isNotEmpty) {
        final channelId = usernameItems.first['id'] as String?;
        if (channelId != null && channelId.startsWith('UC')) {
          debugPrint('✅ forUsername lookup → $channelId');
          return channelId;
        }
      }

      return null;
    } catch (e) {
      debugPrint('Error extracting from handle: $e');
      return null;
    }
  }

  Future<String?> _extractFromCustomUrl(String url) async {
    try {
      String? customName;

      final cMatch = RegExp(r'/c/([a-zA-Z0-9_.-]+)').firstMatch(url);
      if (cMatch != null) {
        customName = cMatch.group(1);
      }

      if (customName == null) {
        final userMatch = RegExp(r'/user/([a-zA-Z0-9_.-]+)').firstMatch(url);
        if (userMatch != null) {
          customName = userMatch.group(1);
        }
      }

      if (customName == null) return null;

      debugPrint('🔍 Looking up channel ID for custom name: $customName');

      // Use forUsername for an exact lookup — never use search here.
      final response = await _apiManager.makeRequest('channels', {
        'part': 'id',
        'forUsername': customName,
      });

      final items = response['items'] as List<dynamic>?;
      if (items != null && items.isNotEmpty) {
        final channelId = items.first['id'] as String?;
        if (channelId != null && channelId.startsWith('UC')) {
          debugPrint('✅ forUsername lookup → $channelId');
          return channelId;
        }
      }

      // Also try forHandle in case it's a new-style handle
      final handleResponse = await _apiManager.makeRequest('channels', {
        'part': 'id',
        'forHandle': '@$customName',
      });

      final handleItems = handleResponse['items'] as List<dynamic>?;
      if (handleItems != null && handleItems.isNotEmpty) {
        final channelId = handleItems.first['id'] as String?;
        if (channelId != null && channelId.startsWith('UC')) {
          debugPrint('✅ forHandle lookup → $channelId');
          return channelId;
        }
      }

      return null;
    } catch (e) {
      debugPrint('Error extracting from custom URL: $e');
      return null;
    }
  }

  Future<String?> _extractFromPageScraping(String url) async {
    try {
      debugPrint('🔍 Attempting to scrape channel ID from page: $url');

      final response = await _httpClient.get(
        Uri.parse(url),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        debugPrint('❌ Failed to fetch page: ${response.statusCode}');
        return null;
      }

      final html = response.body;

      final patterns = [
        RegExp(r'"channelId":"([a-zA-Z0-9_-]{24})"'),
        RegExp(r'"externalId":"([a-zA-Z0-9_-]{24})"'),
        RegExp(r'channel/([a-zA-Z0-9_-]{24})'),
        RegExp(r'"ucid":"([a-zA-Z0-9_-]{24})"'),
      ];

      for (final pattern in patterns) {
        final match = pattern.firstMatch(html);
        if (match != null) {
          final channelId = match.group(1);
          if (channelId != null && channelId.startsWith('UC') && channelId.length == 24) {
            return channelId;
          }
        }
      }

      return null;
    } catch (e) {
      debugPrint('Error scraping page: $e');
      return null;
    }
  }

  bool isValidChannelId(String? channelId) {
    if (channelId == null || channelId.isEmpty) return false;
    return channelId.startsWith('UC') && channelId.length == 24;
  }

  Future<Map<String, dynamic>?> getChannelInfo(String channelId) async {
    try {
      if (!isValidChannelId(channelId)) return null;

      final channelInfo = await _apiManager.getChannelInfo(channelId);
      return channelInfo;
    } catch (e) {
      debugPrint('Error getting channel info: $e');
      return null;
    }
  }

  Future<String?> extractAndValidateChannelId(String url) async {
    final channelId = await extractChannelId(url);
    if (channelId == null) return null;

    final channelInfo = await getChannelInfo(channelId);
    if (channelInfo == null) {
      debugPrint('❌ Channel ID $channelId does not exist or is not accessible');
      return null;
    }

    final snippet = channelInfo['items']?[0]?['snippet'] as Map<String, dynamic>?;
    if (snippet != null) {
      final title = snippet['title'] as String?;
      debugPrint('✅ Verified channel: $title (ID: $channelId)');
    }

    return channelId;
  }

  void dispose() {
    _httpClient.close();
  }
}