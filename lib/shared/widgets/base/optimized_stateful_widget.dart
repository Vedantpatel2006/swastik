import 'dart:async';
import 'package:flutter/material.dart';

/// Base class for all stateful widgets
abstract class OptimizedStatefulWidget extends StatefulWidget {
  const OptimizedStatefulWidget({super.key});
}

/// Base state class with common functionality
abstract class OptimizedState<T extends OptimizedStatefulWidget>
    extends State<T> {
  /// List of active subscriptions that will be disposed automatically
  final List<StreamSubscription<dynamic>> _subscriptions = [];

  @override
  @mustCallSuper
  void dispose() {
    // Cancel all subscriptions
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();
    super.dispose();
  }

  /// Safely manage a stream subscription
  @protected
  void manageSubscription(StreamSubscription<dynamic> subscription) {
    _subscriptions.add(subscription);
  }

  @override
  @mustCallSuper
  Widget build(BuildContext context) {
    try {
      return buildWidget(context);
    } catch (e, stackTrace) {
      return ErrorWidget.builder(
        FlutterErrorDetails(
          exception: e,
          stack: stackTrace,
          library: 'widgets',
          context: ErrorDescription('building ${widget.runtimeType}'),
        ),
      );
    }
  }

  /// The actual build method that subclasses should implement
  @protected
  Widget buildWidget(BuildContext context);

  /// Helper method to create a FutureBuilder with common settings
  @protected
  Widget buildFuture<U>({
    required Future<U> future,
    required Widget Function(U data) builder,
    Widget? loading,
    Widget? error,
    U? initialData,
  }) {
    return FutureBuilder<U>(
      future: future,
      initialData: initialData,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return loading ?? const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          debugPrint(
            'FutureBuilder error: ${snapshot.error}\n${snapshot.stackTrace}',
          );
          return error ?? Center(child: Text('Error: ${snapshot.error}'));
        }

        return builder(snapshot.data as U);
      },
    );
  }

  /// Helper method to create a StreamBuilder with common settings
  @protected
  Widget buildStream<U>({
    required Stream<U> stream,
    required Widget Function(U? data) builder,
    Widget? loading,
    Widget? error,
    U? initialData,
  }) {
    return StreamBuilder<U>(
      stream: stream,
      initialData: initialData,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return loading ?? const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          debugPrint(
            'StreamBuilder error: ${snapshot.error}\n${snapshot.stackTrace}',
          );
          return error ?? Center(child: Text('Error: ${snapshot.error}'));
        }

        return builder(snapshot.data);
      },
    );
  }
}
