import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'youtube_rss_detector.dart';

/// Real-Time Live Darshan Controller
///
/// Strategy: RSS-only for all routine checks (zero quota cost).
/// YouTube Data API is NEVER called from this controller — live detection
/// is 100% RSS-based. The API is only used in LiveStreamService when a
/// user explicitly taps "Watch Live" and we need the actual video ID.
///
/// Quota budget per temple per day (RSS only): 0 units.
class RealtimeLiveController {
  static final RealtimeLiveController _instance =
      RealtimeLiveController._internal();
  factory RealtimeLiveController() => _instance;
  RealtimeLiveController._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final YouTubeRSSDetector _rssDetector = YouTubeRSSDetector();

  final Map<String, Timer> _monitoringTimers = {};
  final Map<String, bool> _lastKnownStatus = {};
  final Map<String, int> _consecutiveFailures = {};
  final Map<String, String> _lastKnownChannelIds = {};
  final Map<String, List<String>> _lastKnownKeywords = {};

  // Offline temples: check every 30 min (RSS is free but no need to hammer it)
  // Live temples: check every 5 min (confirm stream is still running)
  // Error backoff: 60 min (something is wrong, back off hard)
  static const Duration _offlineCheckInterval = Duration(minutes: 30);
  static const Duration _liveCheckInterval = Duration(minutes: 5);
  static const Duration _errorBackoffInterval = Duration(minutes: 60);
  static const int _maxConsecutiveFailures = 3;

  bool _isInitialized = false;
  bool _isRunning = false;
  Timer? _heartbeatTimer;
  StreamSubscription<QuerySnapshot>? _configChangeSubscription;

  Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;
    debugPrint('✅ RealtimeLiveController initialized (RSS-only, zero quota)');
  }

  Future<void> startRealtimeMonitoring() async {
    if (!_isInitialized) throw StateError('Controller not initialized');
    if (_isRunning) {
      debugPrint('⚠️ Real-time monitoring already running');
      return;
    }

    _isRunning = true;
    debugPrint('🚀 Starting real-time live monitoring (RSS-only)...');

    final temples = await _getConfiguredTemples();
    debugPrint('📊 Found ${temples.length} temples to monitor');

    for (final temple in temples) {
      await _startTempleMonitoring(
        temple['id'],
        temple['channelId'],
        temple['keywords'],
      );
    }

    _startConfigurationChangeListener();
    _startHeartbeat();

    debugPrint('✅ Real-time monitoring started for ${temples.length} temples');
  }

  Future<void> stopRealtimeMonitoring() async {
    if (!_isRunning) return;
    debugPrint('🛑 Stopping real-time monitoring...');

    _configChangeSubscription?.cancel();
    _configChangeSubscription = null;

    for (final timer in _monitoringTimers.values) {
      timer.cancel();
    }
    _monitoringTimers.clear();

    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;

    _lastKnownStatus.clear();
    _consecutiveFailures.clear();
    _lastKnownChannelIds.clear();
    _lastKnownKeywords.clear();

    _isRunning = false;
    debugPrint('✅ Real-time monitoring stopped');
  }

  Future<List<Map<String, dynamic>>> _getConfiguredTemples() async {
    try {
      final snapshot = await _firestore
          .collection('temples')
          .where('liveDarshan.isConfiguredByAdmin', isEqualTo: true)
          .get();

      final temples = <Map<String, dynamic>>[];
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final channelId = _extractChannelId(data);
        if (channelId == null || channelId.isEmpty) continue;
        final keywords = _extractKeywords(data);
        temples.add({
          'id': doc.id,
          'channelId': channelId,
          'keywords': keywords,
        });
      }
      return temples;
    } catch (e) {
      debugPrint('❌ Error getting configured temples from Firestore: $e');
      return [];
    }
  }

  String? _extractChannelId(Map<String, dynamic> data) {
    final liveDarshan = data['liveDarshan'] as Map<String, dynamic>?;
    return liveDarshan?['youtubeChannelId'] as String?;
  }

  List<String> _extractKeywords(Map<String, dynamic> data) {
    final keywords = <String>[];
    final liveKeyword = data['liveKeyword'] as String?;
    if (liveKeyword != null && liveKeyword.isNotEmpty) {
      keywords.add(liveKeyword);
    }
    final liveDarshan = data['liveDarshan'] as Map<String, dynamic>?;
    final channels = liveDarshan?['channels'] as List<dynamic>?;
    if (channels != null) {
      for (final ch in channels) {
        if (ch is Map<String, dynamic>) {
          final kw = ch['keyword'] as String?;
          if (kw != null && kw.isNotEmpty) keywords.add(kw);
        }
      }
    }
    return keywords;
  }

  Future<void> _startTempleMonitoring(
    String templeId,
    String channelId,
    List<String> keywords,
  ) async {
    if (!_validateTempleConfig(templeId, channelId)) {
      debugPrint('❌ Invalid configuration for temple: $templeId');
      return;
    }

    _monitoringTimers[templeId]?.cancel();
    _lastKnownChannelIds[templeId] = channelId;
    _lastKnownKeywords[templeId] = List.from(keywords);
    _lastKnownStatus[templeId] = false;
    _consecutiveFailures[templeId] = 0;

    // Stagger first check by a few seconds to avoid burst on startup
    await Future.delayed(const Duration(seconds: 2));
    await _performLiveCheck(templeId, channelId, keywords);

    _monitoringTimers[templeId] = Timer.periodic(_offlineCheckInterval, (_) {
      _performLiveCheck(templeId, channelId, keywords);
    });

    debugPrint(
      '🎯 Monitoring $templeId every ${_offlineCheckInterval.inMinutes} min (RSS)',
    );
  }

  /// Pure RSS check — zero API quota cost.
  Future<void> _performLiveCheck(
    String templeId,
    String channelId,
    List<String> keywords,
  ) async {
    try {
      final isLive = keywords.isNotEmpty
          ? await _rssDetector.isChannelLiveViaRSSWithKeywords(
              channelId,
              keywords,
            )
          : await _rssDetector.isChannelLiveViaRSS(channelId);

      _consecutiveFailures[templeId] = 0;

      final lastKnown = _lastKnownStatus[templeId] ?? false;
      if (isLive != lastKnown) {
        await _updateFirestoreStatus(templeId, isLive);
        _lastKnownStatus[templeId] = isLive;
        _adjustMonitoringFrequency(templeId, isLive);
        debugPrint('🔄 $templeId: $lastKnown → $isLive');
      }
    } catch (e) {
      debugPrint('❌ Live check failed for $templeId: $e');
      final failures = (_consecutiveFailures[templeId] ?? 0) + 1;
      _consecutiveFailures[templeId] = failures;
      if (failures >= _maxConsecutiveFailures) {
        _adjustMonitoringFrequency(templeId, false, isError: true);
      }
    }
  }

  Future<void> _updateFirestoreStatus(String templeId, bool isLive) async {
    try {
      await _firestore.collection('temples').doc(templeId).update({
        'isCurrentlyLive': isLive,
        'lastLiveCheck': FieldValue.serverTimestamp(),
        'liveStatusSource': 'rss_client',
        if (!isLive) 'currentLiveVideoId': null,
      });
    } catch (e) {
      debugPrint('❌ Failed to update Firestore for $templeId: $e');
    }
  }

  void _adjustMonitoringFrequency(
    String templeId,
    bool isLive, {
    bool isError = false,
  }) {
    final newInterval = isError
        ? _errorBackoffInterval
        : isLive
        ? _liveCheckInterval
        : _offlineCheckInterval;

    _monitoringTimers[templeId]?.cancel();
    _monitoringTimers[templeId] = Timer.periodic(newInterval, (_) {
      final channelId = _lastKnownChannelIds[templeId];
      final keywords = _lastKnownKeywords[templeId] ?? [];
      if (channelId != null) {
        _performLiveCheck(templeId, channelId, keywords);
      }
    });

    debugPrint('⏱️ $templeId interval → ${newInterval.inMinutes} min');
  }

  void _startHeartbeat() {
    _heartbeatTimer = Timer.periodic(const Duration(minutes: 30), (_) {
      if (kDebugMode) {
        debugPrint(
          '💓 RealtimeLiveController: monitoring ${_monitoringTimers.length} temples',
        );
      }
    });
  }

  Future<void> addTempleToMonitoring(String templeId) async {
    if (!_isRunning) return;
    try {
      final doc = await _firestore.collection('temples').doc(templeId).get();
      if (!doc.exists) return;
      final data = doc.data()!;
      final channelId = _extractChannelId(data);
      if (channelId != null && channelId.isNotEmpty) {
        final keywords = _extractKeywords(data);
        await _startTempleMonitoring(templeId, channelId, keywords);
        debugPrint('✅ Added temple to monitoring: $templeId');
      }
    } catch (e) {
      debugPrint('❌ Error adding temple to monitoring: $e');
    }
  }

  void removeTempleFromMonitoring(String templeId) {
    _removeTempleFromMonitoring(templeId);
  }

  Map<String, dynamic> getMonitoringStats() {
    final liveTemples = _lastKnownStatus.values.where((s) => s).length;
    return {
      'isRunning': _isRunning,
      'monitoringCount': _monitoringTimers.length,
      'liveTemples': liveTemples,
      'quotaUsed': 0, // RSS-only: always zero
    };
  }

  Future<void> forceRefreshAll() async {
    if (!_isRunning) return;
    debugPrint('🔄 Force refreshing all temples (RSS)...');
    final futures = <Future>[];
    for (final entry in _lastKnownChannelIds.entries) {
      final templeId = entry.key;
      final channelId = entry.value;
      final keywords = _lastKnownKeywords[templeId] ?? [];
      futures.add(_performLiveCheck(templeId, channelId, keywords));
    }
    await Future.wait(futures);
    debugPrint('✅ Force refresh completed');
  }

  void _startConfigurationChangeListener() {
    _configChangeSubscription = _firestore
        .collection('temples')
        .where('liveDarshan.isConfiguredByAdmin', isEqualTo: true)
        .snapshots()
        .listen(
          (snapshot) async {
            for (final change in snapshot.docChanges) {
              final templeId = change.doc.id;
              switch (change.type) {
                case DocumentChangeType.added:
                  if (!_monitoringTimers.containsKey(templeId)) {
                    await addTempleToMonitoring(templeId);
                  }
                  break;
                case DocumentChangeType.modified:
                  await _handleTempleConfigurationChange(
                    templeId,
                    change.doc.data(),
                  );
                  break;
                case DocumentChangeType.removed:
                  _removeTempleFromMonitoring(templeId);
                  break;
              }
            }
          },
          onError: (error) {
            debugPrint('❌ Configuration change listener error: $error');
          },
        );
  }

  Future<void> _handleTempleConfigurationChange(
    String templeId,
    Map<String, dynamic>? data,
  ) async {
    if (data == null) return;
    final newChannelId = _extractChannelId(data);
    final newKeywords = _extractKeywords(data);
    final oldChannelId = _lastKnownChannelIds[templeId];
    final oldKeywords = _lastKnownKeywords[templeId];

    if (newChannelId == null) return;

    if (oldChannelId != newChannelId ||
        !_listsEqual(oldKeywords ?? [], newKeywords)) {
      _removeTempleFromMonitoring(templeId);
      await Future.delayed(const Duration(milliseconds: 300));
      await _startTempleMonitoring(templeId, newChannelId, newKeywords);
    }
  }

  bool _validateTempleConfig(String templeId, String channelId) {
    if (channelId.isEmpty) return false;
    if (!channelId.startsWith('UC') || channelId.length != 24) {
      debugPrint('❌ Invalid channel ID for $templeId: $channelId');
      return false;
    }
    return true;
  }

  void _removeTempleFromMonitoring(String templeId) {
    _monitoringTimers[templeId]?.cancel();
    _monitoringTimers.remove(templeId);
    _lastKnownStatus.remove(templeId);
    _consecutiveFailures.remove(templeId);
    _lastKnownChannelIds.remove(templeId);
    _lastKnownKeywords.remove(templeId);
    debugPrint('🗑️ Removed $templeId from monitoring');
  }

  bool _listsEqual<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  Future<void> restartTempleMonitoring(String templeId) async {
    if (!_isRunning) return;
    final channelId = _lastKnownChannelIds[templeId];
    final keywords = _lastKnownKeywords[templeId] ?? [];
    if (channelId == null) return;
    _removeTempleFromMonitoring(templeId);
    await Future.delayed(const Duration(milliseconds: 300));
    await _startTempleMonitoring(templeId, channelId, keywords);
  }
}
