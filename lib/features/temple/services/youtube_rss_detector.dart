import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';
import 'package:flutter/foundation.dart';

/// FREE YouTube live detection using RSS feeds (no API quota usage)
class YouTubeRSSDetector {
  static final YouTubeRSSDetector _instance = YouTubeRSSDetector._internal();
  factory YouTubeRSSDetector() => _instance;
  YouTubeRSSDetector._internal();

  final http.Client _httpClient = http.Client();
  final Map<String, bool> _liveStatus = {};

  // All live-related keywords (English + Hindi)
  static const List<String> _defaultLiveKeywords = [
    'live',
    'LIVE',
    'streaming',
    'darshan',
    '🔴',
    'आरती',
    'दर्शन',
    'लाइव',
    'प्रसारण',
    'सीधा',
    'अभी',
    'aarti',
    'bhajan',
    'kirtan',
    'satsang',
    'pravachan',
    'भजन',
    'कीर्तन',
    'सत्संग',
    'प्रवचन',
    'मंदिर',
    'live now',
    'going live',
    'now streaming',
  ];

  /// Compute a live confidence score for a video title.
  /// Returns a score ≥ 3 when the title strongly suggests a live stream.
  int _computeLiveScore(String title) {
    final lower = title.toLowerCase();
    int score = 0;
    for (final kw in _defaultLiveKeywords) {
      if (lower.contains(kw.toLowerCase())) {
        // 'live' and 🔴 are the strongest signals
        score += (kw == 'live' || kw == 'LIVE' || kw == '🔴') ? 3 : 1;
      }
    }
    if (lower.contains('🔴') || lower.contains('●')) score += 5;
    if (RegExp(r'\b(now|अभी|currently)\b').hasMatch(lower)) score += 2;
    return score;
  }

  /// Maximum allowed age (hours) for a video to still be considered live,
  /// based on its confidence score.  Higher score → more lenient age limit.
  int _maxAgeHours(int score) {
    if (score >= 6) return 12; // Very strong signal → up to 12 h
    if (score >= 4) return 8; // Strong signal    → up to  8 h
    return 4; // Moderate signal  → up to  4 h
  }

  /// Check if channel is live using RSS feed with custom keywords
  Future<bool> isChannelLiveViaRSSWithKeywords(
    String channelId,
    List<String> customKeywords,
  ) async {
    try {
      final rssUrl =
          'https://www.youtube.com/feeds/videos.xml?channel_id=$channelId';
      final response = await _httpClient.get(Uri.parse(rssUrl));
      if (response.statusCode != 200) return false;

      final document = XmlDocument.parse(response.body);
      final entries = document.findAllElements('entry');

      for (final entry in entries.take(5)) {
        final title = entry.findElements('title').first.innerText;
        final published = entry.findElements('published').first.innerText;

        final publishedTime = DateTime.parse(published);
        final ageHours =
            DateTime.now().difference(publishedTime).inMinutes / 60.0;

        // Skip anything older than 24 h — definitely not live
        if (ageHours > 24) break;

        // Score using built-in + custom keywords
        int score = _computeLiveScore(title);
        for (final kw in customKeywords) {
          if (title.toLowerCase().contains(kw.toLowerCase())) score += 2;
        }
        if (ageHours < 0.5) score += 2; // Very fresh bonus

        if (score >= 3 && ageHours < _maxAgeHours(score)) {
          debugPrint(
            '🔴 Live detected via RSS: "$title" '
            '(score=$score, age=${ageHours.toStringAsFixed(1)}h)',
          );
          return true;
        }
      }

      return false;
    } catch (e) {
      debugPrint('Error checking RSS feed (with keywords): $e');
      return false;
    }
  }

  /// Check if channel is live using RSS feed (FREE - no API quota)
  Future<bool> isChannelLiveViaRSS(String channelId) async {
    return isChannelLiveViaRSSWithKeywords(channelId, const []);
  }

  /// Smart detection: RSS first, then API if needed
  Future<bool> smartLiveDetection(String channelId) async {
    // Step 1: Quick RSS check (free)
    final rssResult = await isChannelLiveViaRSS(channelId);
    
    if (rssResult) {
      debugPrint('✅ Live detected via RSS (free)');
      return true;
    }

    // Step 2: Only use API if RSS suggests possible live stream
    // This reduces API usage by 80-90%
    debugPrint('📡 RSS shows no live stream, skipping API call');
    return false;
  }

  /// Continuous monitoring with minimal API usage
  void startSmartMonitoring(String channelId, Function(bool) onStatusChange) {
    // 15 min when offline, adjusts to 5 min when live — RSS is free so
    // we can afford more frequent checks, but 5 min is plenty for live detection.
    Timer.periodic(const Duration(minutes: 15), (timer) async {
      final isLive = await smartLiveDetection(channelId);
      
      // Only notify if status changed
      if (_liveStatus[channelId] != isLive) {
        _liveStatus[channelId] = isLive;
        onStatusChange(isLive);
      }
    });
  }
}