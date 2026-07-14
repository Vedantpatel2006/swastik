import 'package:flutter/material.dart';

/// A widget that catches errors in its child widget tree and calls the onError callback
class ErrorCatcher extends StatefulWidget {
  final Widget child;
  final Function(dynamic error, StackTrace? stackTrace) onError;

  const ErrorCatcher({
    Key? key,
    required this.child,
    required this.onError,
  }) : super(key: key);

  @override
  State<ErrorCatcher> createState() => _ErrorCatcherState();
}

class _ErrorCatcherState extends State<ErrorCatcher> {
  @override
  void initState() {
    super.initState();
    // Register error handler
    FlutterError.onError = _handleFlutterError;
  }

  void _handleFlutterError(FlutterErrorDetails details) {
    widget.onError(details.exception, details.stack);
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }

  @override
  void dispose() {
    // Reset error handler to default
    FlutterError.onError = FlutterError.presentError;
    super.dispose();
  }
}