import 'package:flutter/material.dart';
import 'dart:math' as math;

/// Enhanced loading animations for temple data fetching and operations
class LoadingAnimations {
  /// Creates a temple-themed loading animation with rotating lotus
  static Widget templeLoadingAnimation({
    double size = 60.0,
    Color color = const Color(0xFFFF6B35),
    Duration duration = const Duration(seconds: 2),
  }) {
    return _TempleLoadingWidget(size: size, color: color, duration: duration);
  }

  /// Creates a shimmer loading effect for temple cards
  static Widget shimmerLoading({
    required Widget child,
    Color baseColor = const Color(0xFFE0E0E0),
    Color highlightColor = const Color(0xFFF5F5F5),
    Duration duration = const Duration(milliseconds: 1500),
  }) {
    return _ShimmerWidget(
      baseColor: baseColor,
      highlightColor: highlightColor,
      duration: duration,
      child: child,
    );
  }

  /// Creates a pulsing dot loading indicator
  static Widget pulsingDots({
    int dotCount = 3,
    double dotSize = 8.0,
    Color color = const Color(0xFFFF6B35),
    Duration duration = const Duration(milliseconds: 600),
  }) {
    return _PulsingDotsWidget(
      dotCount: dotCount,
      dotSize: dotSize,
      color: color,
      duration: duration,
    );
  }

  /// Creates a wave loading animation
  static Widget waveLoading({
    double width = 100.0,
    double height = 40.0,
    Color color = const Color(0xFFFF6B35),
    Duration duration = const Duration(milliseconds: 1200),
  }) {
    return _WaveLoadingWidget(
      width: width,
      height: height,
      color: color,
      duration: duration,
    );
  }

  /// Creates a skeleton loading for temple list items
  static Widget templeCardSkeleton({
    double height = 200.0,
    double borderRadius = 12.0,
  }) {
    return Container(
      height: height,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: shimmerLoading(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image placeholder
            Container(
              height: height * 0.6,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(borderRadius),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title placeholder
                  Container(
                    height: 16,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Subtitle placeholder
                  Container(
                    height: 12,
                    width: 150,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Distance placeholder
                  Container(
                    height: 12,
                    width: 80,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Creates a search loading animation
  static Widget searchLoading({
    String text = 'Searching temples...',
    Color color = const Color(0xFFFF6B35),
  }) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        pulsingDots(color: color),
        const SizedBox(height: 16),
        Text(text, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
      ],
    );
  }
}

/// Temple-themed loading widget with rotating lotus
class _TempleLoadingWidget extends StatefulWidget {
  final double size;
  final Color color;
  final Duration duration;

  const _TempleLoadingWidget({
    required this.size,
    required this.color,
    required this.duration,
  });

  @override
  State<_TempleLoadingWidget> createState() => _TempleLoadingWidgetState();
}

class _TempleLoadingWidgetState extends State<_TempleLoadingWidget>
    with TickerProviderStateMixin {
  late AnimationController _rotationController;
  late AnimationController _pulseController;
  late Animation<double> _rotationAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    _rotationController = AnimationController(
      duration: widget.duration,
      vsync: this,
    );

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _rotationAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _rotationController, curve: Curves.linear),
    );

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _rotationController.repeat();
    _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: Listenable.merge([_rotationAnimation, _pulseAnimation]),
        builder: (context, child) {
          return Transform.scale(
            scale: _pulseAnimation.value,
            child: Transform.rotate(
              angle: _rotationAnimation.value * 2 * 3.14159,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      widget.color.withValues(alpha: 0.8),
                      widget.color.withValues(alpha: 0.3),
                    ],
                  ),
                ),
                child: Icon(
                  Icons.local_florist,
                  size: widget.size * 0.6,
                  color: Colors.white,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Shimmer loading effect widget
class _ShimmerWidget extends StatefulWidget {
  final Widget child;
  final Color baseColor;
  final Color highlightColor;
  final Duration duration;

  const _ShimmerWidget({
    required this.child,
    required this.baseColor,
    required this.highlightColor,
    required this.duration,
  });

  @override
  State<_ShimmerWidget> createState() => _ShimmerWidgetState();
}

class _ShimmerWidgetState extends State<_ShimmerWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: widget.duration, vsync: this);
    _animation = Tween<double>(
      begin: -1.0,
      end: 2.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                widget.baseColor,
                widget.highlightColor,
                widget.baseColor,
              ],
              stops: [
                _animation.value - 0.3,
                _animation.value,
                _animation.value + 0.3,
              ].map((stop) => stop.clamp(0.0, 1.0)).toList(),
            ).createShader(bounds);
          },
          child: widget.child,
        );
      },
    );
  }
}

/// Pulsing dots loading widget
class _PulsingDotsWidget extends StatefulWidget {
  final int dotCount;
  final double dotSize;
  final Color color;
  final Duration duration;

  const _PulsingDotsWidget({
    required this.dotCount,
    required this.dotSize,
    required this.color,
    required this.duration,
  });

  @override
  State<_PulsingDotsWidget> createState() => _PulsingDotsWidgetState();
}

class _PulsingDotsWidgetState extends State<_PulsingDotsWidget>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<double>> _animations;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(
      widget.dotCount,
      (index) => AnimationController(duration: widget.duration, vsync: this),
    );

    _animations = _controllers.map((controller) {
      return Tween<double>(
        begin: 0.0,
        end: 1.0,
      ).animate(CurvedAnimation(parent: controller, curve: Curves.easeInOut));
    }).toList();

    // Start animations with staggered delays
    for (int i = 0; i < _controllers.length; i++) {
      Future.delayed(Duration(milliseconds: i * 200), () {
        if (mounted) {
          _controllers[i].repeat(reverse: true);
        }
      });
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(widget.dotCount, (index) {
        return AnimatedBuilder(
          animation: _animations[index],
          builder: (context, child) {
            return Container(
              margin: EdgeInsets.symmetric(horizontal: widget.dotSize * 0.2),
              child: Transform.scale(
                scale: 0.5 + (_animations[index].value * 0.5),
                child: Container(
                  width: widget.dotSize,
                  height: widget.dotSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.color.withValues(
                      alpha: 0.3 + (_animations[index].value * 0.7),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      }),
    );
  }
}

/// Wave loading animation widget
class _WaveLoadingWidget extends StatefulWidget {
  final double width;
  final double height;
  final Color color;
  final Duration duration;

  const _WaveLoadingWidget({
    required this.width,
    required this.height,
    required this.color,
    required this.duration,
  });

  @override
  State<_WaveLoadingWidget> createState() => _WaveLoadingWidgetState();
}

class _WaveLoadingWidgetState extends State<_WaveLoadingWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: widget.duration, vsync: this);
    _animation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          return CustomPaint(
            painter: _WavePainter(
              animationValue: _animation.value,
              color: widget.color,
            ),
            size: Size(widget.width, widget.height),
          );
        },
      ),
    );
  }
}

/// Custom painter for wave loading animation
class _WavePainter extends CustomPainter {
  final double animationValue;
  final Color color;

  _WavePainter({required this.animationValue, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    final waveHeight = size.height * 0.3;
    final waveLength = size.width;
    final phase = animationValue * 2 * 3.14159;

    path.moveTo(0, size.height / 2);

    for (double x = 0; x <= size.width; x += 1) {
      final y =
          size.height / 2 +
          waveHeight *
              0.5 *
              (Math.sin((x / waveLength) * 2 * 3.14159 + phase) +
                  0.5 * Math.sin((x / waveLength) * 4 * 3.14159 + phase * 1.5));
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

/// Math utilities for wave calculations
class Math {
  static double sin(double value) => math.sin(value);
}
