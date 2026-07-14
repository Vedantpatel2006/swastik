import 'package:flutter/material.dart';
import 'app_animations.dart';
import 'dart:math' as math;

/// Enhanced pull-to-refresh animations for temple data fetching
class PullToRefreshAnimations {
  /// Creates an animated pull-to-refresh indicator with temple theme
  static Widget templePullToRefresh({
    required Widget child,
    required Future<void> Function() onRefresh,
    Color color = const Color(0xFFFF6B35),
    String refreshText = 'Pull to refresh temples',
    String releaseText = 'Release to refresh',
    String refreshingText = 'Refreshing temples...',
  }) {
    return _TemplePullToRefreshWidget(
      onRefresh: onRefresh,
      color: color,
      refreshText: refreshText,
      releaseText: releaseText,
      refreshingText: refreshingText,
      child: child,
    );
  }

  /// Creates a custom refresh indicator with lotus animation
  static Widget lotusRefreshIndicator({
    required Widget child,
    required Future<void> Function() onRefresh,
    Color color = const Color(0xFFFF6B35),
    double displacement = 40.0,
  }) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: color,
      backgroundColor: Colors.white,
      displacement: displacement,
      child: child,
    );
  }

  /// Creates a wave refresh animation
  static Widget waveRefreshAnimation({
    required bool isRefreshing,
    Color color = const Color(0xFFFF6B35),
    double height = 60.0,
  }) {
    return _WaveRefreshAnimationWidget(
      isRefreshing: isRefreshing,
      color: color,
      height: height,
    );
  }
}

/// Temple-themed pull-to-refresh widget
class _TemplePullToRefreshWidget extends StatefulWidget {
  final Widget child;
  final Future<void> Function() onRefresh;
  final Color color;
  final String refreshText;
  final String releaseText;
  final String refreshingText;

  const _TemplePullToRefreshWidget({
    required this.child,
    required this.onRefresh,
    required this.color,
    required this.refreshText,
    required this.releaseText,
    required this.refreshingText,
  });

  @override
  State<_TemplePullToRefreshWidget> createState() =>
      _TemplePullToRefreshWidgetState();
}

class _TemplePullToRefreshWidgetState extends State<_TemplePullToRefreshWidget>
    with TickerProviderStateMixin {
  late AnimationController _rotationController;
  late AnimationController _scaleController;

  @override
  void initState() {
    super.initState();

    _rotationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _scaleController = AnimationController(
      duration: AppAnimations.normalDuration,
      vsync: this,
    );
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        _rotationController.repeat();
        _scaleController.repeat(reverse: true);

        try {
          await widget.onRefresh();
        } finally {
          _rotationController.stop();
          _scaleController.stop();
          _rotationController.reset();
          _scaleController.reset();
        }
      },
      color: widget.color,
      backgroundColor: Colors.white,
      child: widget.child,
    );
  }
}

/// Wave refresh animation widget
class _WaveRefreshAnimationWidget extends StatefulWidget {
  final bool isRefreshing;
  final Color color;
  final double height;

  const _WaveRefreshAnimationWidget({
    required this.isRefreshing,
    required this.color,
    required this.height,
  });

  @override
  State<_WaveRefreshAnimationWidget> createState() =>
      _WaveRefreshAnimationWidgetState();
}

class _WaveRefreshAnimationWidgetState
    extends State<_WaveRefreshAnimationWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _waveAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _waveAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    if (widget.isRefreshing) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(_WaveRefreshAnimationWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isRefreshing != oldWidget.isRefreshing) {
      if (widget.isRefreshing) {
        _controller.repeat();
      } else {
        _controller.stop();
        _controller.reset();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isRefreshing) return const SizedBox.shrink();

    return SizedBox(
      height: widget.height,
      child: AnimatedBuilder(
        animation: _waveAnimation,
        builder: (context, child) {
          return CustomPaint(
            painter: _WaveRefreshPainter(
              animationValue: _waveAnimation.value,
              color: widget.color,
            ),
            size: Size(double.infinity, widget.height),
          );
        },
      ),
    );
  }
}

/// Custom painter for wave refresh animation
class _WaveRefreshPainter extends CustomPainter {
  final double animationValue;
  final Color color;

  _WaveRefreshPainter({required this.animationValue, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;

    final path = Path();
    final waveHeight = size.height * 0.3;
    final phase = animationValue * 2 * 3.14159;

    path.moveTo(0, size.height / 2);

    for (double x = 0; x <= size.width; x += 2) {
      final y =
          size.height / 2 +
          waveHeight *
              (0.5 * math.sin((x / size.width) * 4 * 3.14159 + phase) +
                  0.3 * math.sin((x / size.width) * 6 * 3.14159 + phase * 1.5));
      path.lineTo(x, y);
    }

    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
