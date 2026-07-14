import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Service to manage realtime data streams across the app
class RealtimeService {
  static final RealtimeService _instance = RealtimeService._internal();
  factory RealtimeService() => _instance;
  RealtimeService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Map<String, StreamSubscription> _activeStreams = {};

  /// Get realtime stream for temples collection
  Stream<List<Map<String, dynamic>>> getTemplesStream({
    String? orderBy = 'updatedAt',
    bool descending = true,
    int? limit,
    Map<String, dynamic>? where,
  }) {
    Query query = _firestore.collection('temples');

    // Apply where conditions
    if (where != null) {
      where.forEach((field, value) {
        query = query.where(field, isEqualTo: value);
      });
    }

    // Apply ordering
    if (orderBy != null) {
      query = query.orderBy(orderBy, descending: descending);
    }

    // Apply limit
    if (limit != null) {
      query = query.limit(limit);
    }

    return query.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final result = doc.data() as Map<String, dynamic>;
        result['id'] = doc.id;
        return result;
      }).toList();
    });
  }

  /// Get realtime stream for a specific temple
  Stream<Map<String, dynamic>?> getTempleStream(String templeId) {
    return _firestore.collection('temples').doc(templeId).snapshots().map((
      snapshot,
    ) {
      if (snapshot.exists) {
        final data = snapshot.data();
        if (data == null) return null;
        data['id'] = snapshot.id;
        return data;
      }
      return null;
    });
  }

  /// Subscribe to a named stream (for managing multiple streams)
  void subscribeToStream(
    String streamName,
    Stream stream,
    Function(dynamic) onData, {
    Function(dynamic)? onError,
  }) {
    // Cancel existing stream if any
    _activeStreams[streamName]?.cancel();

    // Subscribe to new stream
    _activeStreams[streamName] = stream.listen(
      onData,
      onError:
          onError ??
          (error) {
            debugPrint('❌ Realtime stream error ($streamName): $error');
          },
    );

    debugPrint('📡 Subscribed to realtime stream: $streamName');
  }

  /// Unsubscribe from a named stream
  void unsubscribeFromStream(String streamName) {
    _activeStreams[streamName]?.cancel();
    _activeStreams.remove(streamName);
    debugPrint('📡 Unsubscribed from realtime stream: $streamName');
  }

  /// Cancel all active streams
  void cancelAllStreams() {
    for (final subscription in _activeStreams.values) {
      subscription.cancel();
    }
    _activeStreams.clear();
    debugPrint('📡 Cancelled all realtime streams');
  }

  /// Dispose the service
  void dispose() {
    cancelAllStreams();
  }
}

/// Mixin to easily add realtime capabilities to widgets
mixin RealtimeMixin<T extends StatefulWidget> on State<T> {
  final RealtimeService _realtimeService = RealtimeService();
  final List<String> _streamNames = [];

  /// Subscribe to a realtime stream with automatic cleanup
  void subscribeToRealtimeStream(
    String streamName,
    Stream stream,
    Function(dynamic) onData, {
    Function(dynamic)? onError,
  }) {
    _streamNames.add(streamName);
    _realtimeService.subscribeToStream(
      streamName,
      stream,
      onData,
      onError: onError,
    );
  }

  /// Unsubscribe from a specific stream
  void unsubscribeFromRealtimeStream(String streamName) {
    _realtimeService.unsubscribeFromStream(streamName);
    _streamNames.remove(streamName);
  }

  @override
  void dispose() {
    // Automatically cleanup all streams when widget is disposed
    for (final streamName in _streamNames) {
      _realtimeService.unsubscribeFromStream(streamName);
    }
    super.dispose();
  }
}
