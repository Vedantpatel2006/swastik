import 'dart:async';
import 'package:flutter/material.dart';

/// Manages multiple stream subscriptions for widgets
/// Automatically disposes all subscriptions to prevent memory leaks
/// 
/// Usage in State class:
/// ```dart
/// class _MyScreenState extends State<MyScreen> with SubscriptionManagerMixin {
///   @override
///   void initState() {
///     super.initState();
///     addSubscription(
///       service.stream.listen((_) => setState(() {}))
///     );
///   }
/// }
/// ```
class SubscriptionManager {
  final List<StreamSubscription> _subscriptions = [];
  bool _disposed = false;

  /// Add a subscription to be managed
  /// Throws exception if manager is already disposed
  void add(StreamSubscription subscription) {
    if (_disposed) {
      throw Exception(
        'Cannot add subscription to disposed SubscriptionManager. '
        'Make sure to add subscriptions in initState() before dispose()',
      );
    }
    _subscriptions.add(subscription);
    debugPrint(
      '📊 Added subscription (total: ${_subscriptions.length})',
    );
  }

  /// Add multiple subscriptions at once
  void addAll(List<StreamSubscription> subscriptions) {
    for (final sub in subscriptions) {
      add(sub);
    }
  }

  /// Remove a specific subscription (without canceling it)
  void remove(StreamSubscription subscription) {
    _subscriptions.remove(subscription);
  }

  /// Get count of managed subscriptions
  int get count => _subscriptions.length;

  /// Get all subscription count for debugging
  void debugPrintStats() {
    debugPrint('📊 SubscriptionManager has ${_subscriptions.length} active subscriptions');
  }

  /// Cancel all subscriptions and clean up
  /// Call this in State.dispose()
  Future<void> dispose() async {
    if (_disposed) {
      debugPrint('⚠️ SubscriptionManager already disposed');
      return;
    }

    try {
      debugPrint('🔄 Disposing ${_subscriptions.length} subscriptions...');

      final futures = <Future>[];
      for (final subscription in _subscriptions) {
        futures.add(subscription.cancel());
      }

      await Future.wait(futures);
      _subscriptions.clear();
      _disposed = true;

      debugPrint('✅ All subscriptions disposed');
    } catch (e) {
      debugPrint('❌ Error disposing subscriptions: $e');
    }
  }
}

/// Mixin for StatefulWidget to automatically manage subscriptions
/// Automatically cancels all subscriptions in dispose()
///
/// Example:
/// ```dart
/// class _MyScreenState extends State<MyScreen> with SubscriptionManagerMixin {
///   @override
///   void initState() {
///     super.initState();
///     // Subscriptions will be automatically cleaned up
///     addSubscription(streamController.stream.listen((_) {
///       setState(() {});
///     }));
///   }
/// }
/// ```
mixin SubscriptionManagerMixin on State {
  late final SubscriptionManager _subscriptionManager = SubscriptionManager();

  /// Add a subscription to be automatically cleaned up in dispose()
  void addSubscription(StreamSubscription subscription) {
    _subscriptionManager.add(subscription);
  }

  /// Add multiple subscriptions
  void addSubscriptions(List<StreamSubscription> subscriptions) {
    _subscriptionManager.addAll(subscriptions);
  }

  /// Get subscription count
  int get subscriptionCount => _subscriptionManager.count;

  /// Debug: Print subscription stats
  void debugPrintSubscriptions() {
    _subscriptionManager.debugPrintStats();
  }

  @override
  void dispose() {
    _subscriptionManager.dispose();
    super.dispose();
  }
}

/// Base mixin that implements both SubscriptionManagerMixin and TickerProviderStateMixin
/// Use this when you need both streaming and animations
mixin StreamAnimationMixin on State implements TickerProviderStateMixin {
  late final SubscriptionManager _subscriptionManager = SubscriptionManager();

  void addSubscription(StreamSubscription subscription) {
    _subscriptionManager.add(subscription);
  }

  @override
  void dispose() {
    _subscriptionManager.dispose();
    super.dispose();
  }
}
