import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Live status data model
class LiveStatus {
  final String templeId;
  final bool isLive;
  final String? currentVideoId;
  final String? streamTitle;
  final DateTime? lastUpdated;
  final String? source;
  final bool isStale;

  const LiveStatus({
    required this.templeId,
    required this.isLive,
    this.currentVideoId,
    this.streamTitle,
    this.lastUpdated,
    this.source,
    this.isStale = false,
  });

  LiveStatus copyWith({
    String? templeId,
    bool? isLive,
    String? currentVideoId,
    String? streamTitle,
    DateTime? lastUpdated,
    String? source,
    bool? isStale,
  }) {
    return LiveStatus(
      templeId: templeId ?? this.templeId,
      isLive: isLive ?? this.isLive,
      currentVideoId: currentVideoId ?? this.currentVideoId,
      streamTitle: streamTitle ?? this.streamTitle,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      source: source ?? this.source,
      isStale: isStale ?? this.isStale,
    );
  }

  @override
  String toString() =>
      'LiveStatus(templeId: $templeId, isLive: $isLive, '
      'lastUpdated: $lastUpdated, source: $source, isStale: $isStale)';
}

/// Real-Time Live Status Provider — backed by Firestore snapshots.
///
/// The Supabase cron job writes live status fields directly into the
/// Firestore `temples` document. This provider reads those fields in
/// real time via Firestore snapshots — no Supabase client needed here.
class RealtimeLiveProvider {
  static final RealtimeLiveProvider _instance =
      RealtimeLiveProvider._internal();
  factory RealtimeLiveProvider() => _instance;
  RealtimeLiveProvider._internal();

  final _firestore = FirebaseFirestore.instance;

  final Map<String, StreamController<LiveStatus>> _streamControllers = {};
  final Map<String, StreamSubscription> _subscriptions = {};

  // ─── Single temple stream ─────────────────────────────────────────────────

  /// Watch live status for one temple via Firestore snapshots.
  Stream<LiveStatus> watchLiveStatus(String templeId) {
    if (_streamControllers.containsKey(templeId)) {
      return _streamControllers[templeId]!.stream;
    }

    final controller = StreamController<LiveStatus>.broadcast(
      onCancel: () => _cleanupStream(templeId),
    );
    _streamControllers[templeId] = controller;

    final sub = _firestore
        .collection('temples')
        .doc(templeId)
        .snapshots()
        .listen(
          (snapshot) {
            if (!controller.isClosed) {
              controller.add(
                snapshot.exists && snapshot.data() != null
                    ? _parseDoc(templeId, snapshot.data()!)
                    : LiveStatus(
                        templeId: templeId,
                        isLive: false,
                        lastUpdated: DateTime.now(),
                        source: 'not_found',
                      ),
              );
            }
          },
          onError: (e) {
            debugPrint('RealtimeLiveProvider.watchLiveStatus error: $e');
          },
        );

    _subscriptions[templeId] = sub;
    return controller.stream;
  }

  // ─── All live temples stream ──────────────────────────────────────────────

  /// Stream of all currently-live temples (updates in real time).
  Stream<List<LiveStatus>> watchAllLiveTemples() {
    final controller = StreamController<List<LiveStatus>>.broadcast();

    final sub = _firestore
        .collection('temples')
        .where('isCurrentlyLive', isEqualTo: true)
        .snapshots()
        .listen(
          (snapshot) {
            if (!controller.isClosed) {
              controller.add(
                snapshot.docs
                    .map((doc) => _parseDoc(doc.id, doc.data()))
                    .toList(),
              );
            }
          },
          onError: (e) {
            debugPrint('RealtimeLiveProvider.watchAllLiveTemples error: $e');
          },
        );

    controller.onCancel = () => sub.cancel();
    return controller.stream;
  }

  Stream<int> watchLiveCount() =>
      watchAllLiveTemples().map((list) => list.length);

  Stream<bool> watchAnyTempleLive() =>
      watchLiveCount().map((count) => count > 0);

  // ─── One-time reads ───────────────────────────────────────────────────────

  Future<LiveStatus> getCurrentLiveStatus(String templeId) async {
    try {
      final doc = await _firestore.collection('temples').doc(templeId).get();
      if (doc.exists && doc.data() != null) {
        return _parseDoc(templeId, doc.data()!);
      }
    } catch (e) {
      debugPrint('❌ RealtimeLiveProvider.getCurrentLiveStatus: $e');
    }
    return LiveStatus(
      templeId: templeId,
      isLive: false,
      lastUpdated: DateTime.now(),
      source: 'error',
      isStale: true,
    );
  }

  Future<List<LiveStatus>> getCurrentLiveTemples() async {
    try {
      final snap = await _firestore
          .collection('temples')
          .where('isCurrentlyLive', isEqualTo: true)
          .get();
      return snap.docs.map((doc) => _parseDoc(doc.id, doc.data())).toList();
    } catch (e) {
      debugPrint('❌ RealtimeLiveProvider.getCurrentLiveTemples: $e');
      return [];
    }
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  LiveStatus _parseDoc(String templeId, Map<String, dynamic> data) {
    final isLive = data['isCurrentlyLive'] as bool? ?? false;
    final videoId = data['currentLiveVideoId'] as String?;
    final title = data['currentStreamTitle'] as String?;
    final source = data['liveStatusSource'] as String? ?? 'unknown';

    DateTime? lastUpdated;
    final lastCheck = data['lastLiveCheck'];
    if (lastCheck is Timestamp) {
      lastUpdated = lastCheck.toDate();
    } else if (lastCheck is String) {
      lastUpdated = DateTime.tryParse(lastCheck);
    }

    final isStale =
        lastUpdated == null ||
        DateTime.now().difference(lastUpdated).inMinutes > 10;

    return LiveStatus(
      templeId: templeId,
      isLive: isLive,
      currentVideoId: videoId,
      streamTitle: title,
      lastUpdated: lastUpdated,
      source: source,
      isStale: isStale,
    );
  }

  void _cleanupStream(String templeId) {
    _subscriptions[templeId]?.cancel();
    _subscriptions.remove(templeId);
    _streamControllers[templeId]?.close();
    _streamControllers.remove(templeId);
    debugPrint('🧹 RealtimeLiveProvider: cleaned up stream for $templeId');
  }

  void dispose() {
    for (final sub in _subscriptions.values) {
      sub.cancel();
    }
    _subscriptions.clear();
    for (final c in _streamControllers.values) {
      c.close();
    }
    _streamControllers.clear();
  }

  Map<String, dynamic> getStats() => {
    'activeStreams': _streamControllers.length,
    'activeSubscriptions': _subscriptions.length,
  };
}
