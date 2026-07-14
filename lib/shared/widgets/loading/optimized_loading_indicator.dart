import 'package:flutter/material.dart';

/// A loading indicator that is optimized for performance
class OptimizedLoadingIndicator extends StatelessWidget {
  final double size;
  final Color? color;
  final String? message;
  final bool isFullScreen;

  const OptimizedLoadingIndicator({
    Key? key,
    this.size = 40.0,
    this.color,
    this.message,
    this.isFullScreen = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final loadingWidget = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: CircularProgressIndicator(
            strokeWidth: 3.0,
            color: color ?? Theme.of(context).primaryColor,
          ),
        ),
        if (message != null) ...[  
          const SizedBox(height: 16),
          Text(
            message!,
            style: const TextStyle(fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );

    if (isFullScreen) {
      return Container(
        color: Colors.black.withValues(alpha: 0.1),
        child: Center(
          child: Card(
            elevation: 4.0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8.0),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: loadingWidget,
            ),
          ),
        ),
      );
    }

    return Center(child: loadingWidget);
  }
}