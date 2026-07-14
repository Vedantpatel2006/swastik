import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'youtube_rss_detector.dart';

/// Hybrid live detection — RSS-based, writes to Firestore.
///
/// Reads channel config and writes live status directly to the
/// Firestore `temples` document. No Supabase dependency.
class HybridLiveDetector {
  static final HybridLiveDetector _instance = HybridLiveDetector._internal();
  factory HybridLiveDetector() => _instance;
  HybridLiveDetector._internal();

  final _firestore = FirebaseFirestore.instance;
  final YouTubeRSSDetector _rssDetector = YouTubeRSSDetector();

  final Map<String, Timer> _timers = {};
  final Map<String, bool> _lastKnownStatus = {};
  final Map<String, Duration> _checkIntervals = {};

  // ─── Public API ───────────────────────────────────────────────────────────

  /// Start smart monitoring for a temple.
  void startSmartMonitoring(String templeId, String channelId) {
    // Start at offline interval — adjusts down if live is detected
    _checkIntervals[templeId] = const Duration(minutes: 15);
    _timers[templeId]?.cancel();
    _timers[templeId] = Timer.periodic(_checkIntervals[templeId]!, (_) {
      _performSmartCheck(templeId, channelId);
    });
    // Immediate first check
    _performSmartCheck(templeId, channelId);
  }

  /// One-shot check (used by admin / manual refresh).
  Future<void> performSmartCheck(String templeId, String channelId) =>
      _performSmartCheck(templeId, channelId);

  /// Read current live status from Firestore (one-time).
  Future<bool> getFirestoreStatus(String templeId) async {
    try {
      final doc = await _firestore.collection('temples').doc(templeId).get();
      return doc.data()?['isCurrentlyLive'] as bool? ?? false;
    } catch (e) {
      debugPrint('HybridLiveDetector.getFirestoreStatus: $e');
      return false;
    }
  }

  /// Stream live status from Firestore snapshots.
  Stream<bool> watchLiveStatus(String templeId) {
    return _firestore
        .collection('temples')
        .doc(templeId)
        .snapshots()
        .map((snap) => snap.data()?['isCurrentlyLive'] as bool? ?? false);
  }

  void stopMonitoring(String templeId) {
    _timers[templeId]?.cancel();
    _timers.remove(templeId);
    _checkIntervals.remove(templeId);
    _lastKnownStatus.remove(templeId);
  }

  void stopAllMonitoring() {
    for (final t in _timers.values) {
      t.cancel();
    }
    _timers.clear();
    _checkIntervals.clear();
    _lastKnownStatus.clear();
  }

  Future<void> restartMonitoring(String templeId) async {
    stopMonitoring(templeId);
    await Future.delayed(const Duration(milliseconds: 300));
    final channelId = await _getChannelId(templeId);
    if (channelId != null) startSmartMonitoring(templeId, channelId);
  }

  Map<String, dynamic> getStats() => {
    'activeMonitors': _timers.length,
    'liveTemples': _lastKnownStatus.values.where((v) => v).length,
  };

  // ─── Internal ─────────────────────────────────────────────────────────────

  Future<void> _performSmartCheck(String templeId, String channelId) async {
    try {
      debugPrint('🔍 HybridLiveDetector: checking $templeId');

      final keywords = await _getKeywords(templeId);
      final isLive = await _rssDetector.isChannelLiveViaRSSWithKeywords(
        channelId,
        keywords,
      );

      if (_lastKnownStatus[templeId] != isLive) {
        await _updateFirestoreStatus(templeId, isLive);
        _lastKnownStatus[templeId] = isLive;
        _adjustInterval(templeId, isLive);
        debugPrint('🔄 HybridLiveDetector: $templeId → isLive=$isLive');
      }
    } catch (e) {
      debugPrint('❌ HybridLiveDetector._performSmartCheck: $e');
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
      debugPrint('❌ HybridLiveDetector._updateFirestoreStatus: $e');
    }
  }

  Future<List<String>> _getKeywords(String templeId) async {
    try {
      final doc = await _firestore.collection('temples').doc(templeId).get();
      if (doc.data() == null) return [];

      final data = doc.data()!;
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
    } catch (_) {
      return [];
    }
  }

  Future<String?> _getChannelId(String templeId) async {
    try {
      final doc = await _firestore.collection('temples').doc(templeId).get();
      final liveDarshan = doc.data()?['liveDarshan'] as Map<String, dynamic>?;
      return liveDarshan?['youtubeChannelId'] as String?;
    } catch (_) {
      return null;
    }
  }

  void _adjustInterval(String templeId, bool isLive) {
    // When live: check every 5 min (stream rarely ends mid-minute)
    // When offline: check every 20 min (saves RSS bandwidth + battery)
    final newInterval = isLive
        ? const Duration(minutes: 5)
        : const Duration(minutes: 20);
    if (_checkIntervals[templeId] == newInterval) return;
    _checkIntervals[templeId] = newInterval;
    _timers[templeId]?.cancel();
    _timers[templeId] = Timer.periodic(newInterval, (_) async {
      final channelId = await _getChannelId(templeId);
      if (channelId != null) _performSmartCheck(templeId, channelId);
    });
    debugPrint(
      '🔄 HybridLiveDetector: interval for $templeId → ${newInterval.inMinutes}min',
    );
  }
}
