import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../shared/models/temple.dart';

/// Live Darshan Service — reads live status directly from Firestore.
///
/// The Supabase cron job writes live status fields directly into the
/// Firestore `temples` document. This service reads those fields.
class LiveDarshanService with ChangeNotifier {
  static const String _cacheKey = 'live_darshan_cache';
  static const Duration _cacheExpiry = Duration(minutes: 5);

  final _firestore = FirebaseFirestore.instance;
  final Map<String, StreamSubscription> _activeStreams = {};
  final Map<String, Timer> _backgroundLoaders = {};
  SharedPreferences? _prefs;
  bool _isInitialized = false;
  Completer<void>? _initCompleter;

  Future<void> initialize() async {
    if (_isInitialized) return _initCompleter?.future ?? Future.value();
    _initCompleter ??= Completer<void>();
    try {
      _prefs = await SharedPreferences.getInstance();
      _isInitialized = true;
      debugPrint('✅ LiveDarshanService initialized (Firestore)');
      _initCompleter!.complete();
    } catch (e) {
      debugPrint('❌ LiveDarshanService init failed: $e');
      _initCompleter!.completeError(e);
    }
  }

  Future<void> _ensureInitialized() async {
    if (!_isInitialized) await initialize();
  }

  // ─── Main read ────────────────────────────────────────────────────────────

  /// Get live darshan info for a temple from Firestore.
  Future<LiveDarshanInfo?> getLiveDarshanInfo(String templeId) async {
    await _ensureInitialized();

    final cached = _getCached(templeId);
    if (cached != null) {
      _refreshInBackground(templeId);
      return cached;
    }

    return _fetchFromFirestore(templeId);
  }

  Future<LiveDarshanInfo?> _fetchFromFirestore(String templeId) async {
    try {
      final doc = await _firestore.collection('temples').doc(templeId).get();
      if (!doc.exists) return null;

      final data = doc.data();
      if (data == null) return null;

      final info = _docToInfo(data);
      if (info != null) _cache(templeId, info);
      return info;
    } catch (e) {
      debugPrint('LiveDarshanService._fetchFromFirestore: $e');
      return null;
    }
  }

  // ─── Realtime stream ──────────────────────────────────────────────────────

  /// Stream live darshan status changes for a temple via Firestore snapshots.
  Stream<LiveDarshanInfo?> watchLiveDarshanStatus(String templeId) {
    _activeStreams[templeId]?.cancel();

    final controller = StreamController<LiveDarshanInfo?>.broadcast();

    // Seed immediately
    _fetchFromFirestore(templeId).then((info) {
      if (!controller.isClosed) controller.add(info);
    });

    // Subscribe to Firestore document changes
    final sub = _firestore
        .collection('temples')
        .doc(templeId)
        .snapshots()
        .listen((snapshot) {
          if (!snapshot.exists || snapshot.data() == null) {
            if (!controller.isClosed) controller.add(null);
            return;
          }
          final info = _docToInfo(snapshot.data()!);
          if (info != null) _cache(templeId, info);
          if (!controller.isClosed) controller.add(info);
        });

    _activeStreams[templeId] = sub;

    controller.onCancel = () {
      sub.cancel();
      _activeStreams.remove(templeId);
    };

    Timer(const Duration(minutes: 30), () => removeStreamListener(templeId));

    return controller.stream;
  }

  void removeStreamListener(String templeId) {
    _activeStreams[templeId]?.cancel();
    _activeStreams.remove(templeId);
    _backgroundLoaders[templeId]?.cancel();
    _backgroundLoaders.remove(templeId);
  }

  void handleReconnection(String templeId) => removeStreamListener(templeId);

  // ─── Helpers ──────────────────────────────────────────────────────────────

  /// Build a LiveDarshanInfo from a Firestore temple document map.
  LiveDarshanInfo? _docToInfo(Map<String, dynamic> data) {
    final liveDarshan = data['liveDarshan'] as Map<String, dynamic>?;

    // Channel config comes from the nested liveDarshan map
    final channelId = liveDarshan?['youtubeChannelId'] as String?;
    final channelUrl = liveDarshan?['youtubeChannelUrl'] as String?;
    final isConfigured = liveDarshan?['isConfiguredByAdmin'] as bool? ?? false;

    if (!isConfigured && channelId == null && channelUrl == null) return null;

    // Live status is written at the top level by the cron job
    final isLive = data['isCurrentlyLive'] as bool? ?? false;
    final videoId = data['currentLiveVideoId'] as String?;
    final lastCheck = data['lastLiveCheck'];
    DateTime? lastStreamDate;
    if (lastCheck is Timestamp) {
      lastStreamDate = lastCheck.toDate();
    } else if (lastCheck is String) {
      lastStreamDate = DateTime.tryParse(lastCheck);
    }

    return LiveDarshanInfo(
      youtubeChannelId: channelId,
      youtubeChannelUrl: channelUrl,
      currentLiveVideoId: videoId,
      isCurrentlyLive: isLive,
      isConfiguredByAdmin: isConfigured,
      lastStreamDate: lastStreamDate,
    );
  }

  void _refreshInBackground(String templeId) {
    _backgroundLoaders[templeId]?.cancel();
    _backgroundLoaders[templeId] = Timer(const Duration(seconds: 2), () async {
      final info = await _fetchFromFirestore(templeId);
      if (info != null) _cache(templeId, info);
      _backgroundLoaders.remove(templeId);
    });
  }

  void _cache(String templeId, LiveDarshanInfo info) {
    if (_prefs == null) return;
    final key = '${_cacheKey}_$templeId';
    _prefs!.setString(key, jsonEncode(info.toCacheJson()));
    _prefs!.setInt('${key}_time', DateTime.now().millisecondsSinceEpoch);
  }

  LiveDarshanInfo? _getCached(String templeId) {
    if (_prefs == null) return null;
    final key = '${_cacheKey}_$templeId';
    final raw = _prefs!.getString(key);
    final time = _prefs!.getInt('${key}_time') ?? 0;
    if (raw == null) return null;
    if (DateTime.now().millisecondsSinceEpoch - time >
        _cacheExpiry.inMilliseconds)
      return null;
    try {
      return LiveDarshanInfo.fromCacheJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      return null;
    }
  }

  Future<int> getViewerCount(String templeId) async =>
      50 + (templeId.hashCode % 200);

  /// Validate a YouTube channel URL by checking if the RSS feed is reachable.
  Future<bool> validateYouTubeChannel(String channelUrl) async {
    try {
      final channelId = _extractChannelId(channelUrl);
      if (channelId == null || channelId.isEmpty) return false;

      final uri = Uri.parse(
        'https://www.youtube.com/feeds/videos.xml?channel_id=$channelId',
      );
      final client = http.Client();
      try {
        final response = await client
            .get(uri)
            .timeout(const Duration(seconds: 8));
        return response.statusCode == 200;
      } finally {
        client.close();
      }
    } catch (e) {
      debugPrint('LiveDarshanService.validateYouTubeChannel: $e');
      return false;
    }
  }

  /// Check if a channel is currently live by reading from Firestore.
  Future<bool> isChannelLive(String channelId) async {
    try {
      // Query Firestore for a temple with this channel ID
      final snap = await _firestore
          .collection('temples')
          .where('liveDarshan.youtubeChannelId', isEqualTo: channelId)
          .limit(1)
          .get();

      if (snap.docs.isNotEmpty) {
        return snap.docs.first.data()['isCurrentlyLive'] as bool? ?? false;
      }

      // Fallback: RSS detection
      final rssUri = Uri.parse(
        'https://www.youtube.com/feeds/videos.xml?channel_id=$channelId',
      );
      final client = http.Client();
      try {
        final response = await client
            .get(rssUri)
            .timeout(const Duration(seconds: 8));
        if (response.statusCode != 200) return false;
        final body = response.body.toLowerCase();
        return body.contains('live') || body.contains('darshan');
      } finally {
        client.close();
      }
    } catch (e) {
      debugPrint('LiveDarshanService.isChannelLive: $e');
      return false;
    }
  }

  String? _extractChannelId(String url) {
    if (url.startsWith('UC') && url.length == 24) return url;
    try {
      final uri = Uri.parse(url);
      final segments = uri.pathSegments;
      if (segments.isEmpty) return null;
      if (segments.first == 'channel' && segments.length > 1) {
        return segments[1];
      }
      return segments.last;
    } catch (_) {
      return null;
    }
  }

  Future<void> clearCaches() async {
    if (_prefs == null) return;
    final keys = _prefs!
        .getKeys()
        .where((k) => k.startsWith(_cacheKey))
        .toList();
    for (final k in keys) {
      await _prefs!.remove(k);
    }
  }

  @override
  void dispose() {
    for (final s in _activeStreams.values) {
      s.cancel();
    }
    _activeStreams.clear();
    for (final t in _backgroundLoaders.values) {
      t.cancel();
    }
    _backgroundLoaders.clear();
    super.dispose();
  }
}
