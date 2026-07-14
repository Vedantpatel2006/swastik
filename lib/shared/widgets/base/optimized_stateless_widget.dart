import 'package:flutter/material.dart';

/// Base class for all stateless widgets
abstract class OptimizedStatelessWidget extends StatelessWidget {
  const OptimizedStatelessWidget({super.key});

  @override
  Widget build(BuildContext context) {
    try {
      return buildWidget(context);
    } catch (e, stackTrace) {
      debugPrint('Error in ${runtimeType.toString()}: $e\n$stackTrace');
      return ErrorWidget(e);
    }
  }

  /// The actual build method that subclasses should implement
  @protected
  Widget buildWidget(BuildContext context);
}
