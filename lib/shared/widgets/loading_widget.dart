import 'package:flutter/material.dart';
import 'package:swastik/core/themes/app_colors.dart';

/// Reusable loading widget for consistent UI across the app
class LoadingWidget extends StatelessWidget {
  final String? message;
  final Color? color;
  final double? size;
  final EdgeInsets? padding;

  const LoadingWidget({
    super.key,
    this.message,
    this.color,
    this.size,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ?? const EdgeInsets.all(32),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: size ?? 40,
              height: size ?? 40,
              child: CircularProgressIndicator(
                color: color ?? AppColors.primaryOrange,
                strokeWidth: 3,
              ),
            ),
            if (message != null) ...[
              const SizedBox(height: 16),
              Text(
                message!,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Predefined loading states for common scenarios
class LoadingStates {
  static Widget temples() {
    return const LoadingWidget(
      message: 'Loading temples...',
    );
  }

  static Widget search() {
    return const LoadingWidget(
      message: 'Searching temples...',
    );
  }

  static Widget booking() {
    return const LoadingWidget(
      message: 'Processing booking...',
    );
  }

  static Widget donation() {
    return const LoadingWidget(
      message: 'Processing donation...',
    );
  }

  static Widget location() {
    return const LoadingWidget(
      message: 'Getting your location...',
    );
  }

  static Widget liveDarshan() {
    return const LoadingWidget(
      message: 'Loading live darshan...',
    );
  }

  static Widget generic() {
    return const LoadingWidget(
      message: 'Loading...',
    );
  }

  /// Small loading indicator for buttons
  static Widget button({Color? color}) {
    return SizedBox(
      width: 20,
      height: 20,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        color: color ?? Colors.white,
      ),
    );
  }

  /// Inline loading indicator
  static Widget inline({String? message, Color? color}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: color ?? AppColors.primaryOrange,
          ),
        ),
        if (message != null) ...[
          const SizedBox(width: 8),
          Text(
            message,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        ],
      ],
    );
  }
}