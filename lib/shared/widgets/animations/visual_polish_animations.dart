import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_animations.dart';
import 'dart:math' as math;

/// Visual polish animations for enhanced user experience
class VisualPolishAnimations {
  /// Creates a ripple effect animation for buttons and cards
  static Widget rippleEffect({
    required Widget child,
    required VoidCallback? onTap,
    Color rippleColor = const Color(0xFFFF6B35),
    BorderRadius? borderRadius,
    Duration duration = AppAnimations.fastDuration,
  }) {
    return _RippleEffectWidget(
      onTap: onTap,
      rippleColor: rippleColor,
      borderRadius: borderRadius,
      duration: duration,
      child: child,
    );
  }

  /// Creates a glow effect animation for highlighting elements
  static Widget glowEffect({
    required Widget child,
    required bool isGlowing,
    Color glowColor = const Color(0xFFFF6B35),
    double glowRadius = 10.0,
    Duration duration = AppAnimations.normalDuration,
  }) {
    return _GlowEffectWidget(
      isGlowing: isGlowing,
      glowColor: glowColor,
      glowRadius: glowRadius,
      duration: duration,
      child: child,
    );
  }

  /// Creates a parallax scrolling effect
  static Widget parallaxEffect({
    required Widget child,
    required ScrollController scrollController,
    double parallaxFactor = 0.5,
  }) {
    return _ParallaxEffectWidget(
      scrollController: scrollController,
      parallaxFactor: parallaxFactor,
      child: child,
    );
  }

  /// Creates a morphing container animation
  static Widget morphingContainer({
    required Widget child,
    required bool isMorphed,
    Duration duration = AppAnimations.normalDuration,
    BorderRadius? fromBorderRadius,
    BorderRadius? toBorderRadius,
    Color? fromColor,
    Color? toColor,
    double? fromWidth,
    double? toWidth,
    double? fromHeight,
    double? toHeight,
  }) {
    return _MorphingContainerWidget(
      isMorphed: isMorphed,
      duration: duration,
      fromBorderRadius: fromBorderRadius,
      toBorderRadius: toBorderRadius,
      fromColor: fromColor,
      toColor: toColor,
      fromWidth: fromWidth,
      toWidth: toWidth,
      fromHeight: fromHeight,
      toHeight: toHeight,
      child: child,
    );
  }

  /// Creates a breathing animation for attention-grabbing elements
  static Widget breathingAnimation({
    required Widget child,
    Duration duration = const Duration(seconds: 2),
    double minScale = 0.95,
    double maxScale = 1.05,
    bool repeat = true,
  }) {
    return _BreathingAnimationWidget(
      duration: duration,
      minScale: minScale,
      maxScale: maxScale,
      repeat: repeat,
      child: child,
    );
  }

  /// Creates a typewriter text animation
  static Widget typewriterText({
    required String text,
    required bool startAnimation,
    Duration duration = const Duration(milliseconds: 100),
    TextStyle? textStyle,
    VoidCallback? onComplete,
  }) {
    return _TypewriterTextWidget(
      text: text,
      startAnimation: startAnimation,
      duration: duration,
      textStyle: textStyle,
      onComplete: onComplete,
    );
  }

  /// Creates a particle effect animation
  static Widget particleEffect({
    required Widget child,
    required bool showParticles,
    int particleCount = 20,
    Color particleColor = const Color(0xFFFF6B35),
    Duration duration = const Duration(seconds: 3),
  }) {
    return _ParticleEffectWidget(
      showParticles: showParticles,
      particleCount: particleCount,
      particleColor: particleColor,
      duration: duration,
      child: child,
    );
  }

  /// Creates a card flip animation
  static Widget cardFlip({
    required Widget frontChild,
    required Widget backChild,
    required bool isFlipped,
    Duration duration = AppAnimations.normalDuration,
    VoidCallback? onTap,
  }) {
    return _CardFlipWidget(
      frontChild: frontChild,
      backChild: backChild,
      isFlipped: isFlipped,
      duration: duration,
      onTap: onTap,
    );
  }
}

/// Ripple effect widget implementation
class _RippleEffectWidget extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final Color rippleColor;
  final BorderRadius? borderRadius;
  final Duration duration;

  const _RippleEffectWidget({
    required this.child,
    required this.onTap,
    required this.rippleColor,
    this.borderRadius,
    required this.duration,
  });

  @override
  State<_RippleEffectWidget> createState() => _RippleEffectWidgetState();
}

class _RippleEffectWidgetState extends State<_RippleEffectWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: widget.duration, vsync: this);
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (widget.onTap != null) {
      HapticFeedback.lightImpact();
      _controller.forward().then((_) => _controller.reset());
      widget.onTap!();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _handleTap,
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          return Container(
            decoration: BoxDecoration(
              borderRadius: widget.borderRadius,
              boxShadow: _animation.value > 0
                  ? [
                      BoxShadow(
                        color: widget.rippleColor.withValues(
                          alpha: 0.3 * (1 - _animation.value),
                        ),
                        blurRadius: 20 * _animation.value,
                        spreadRadius: 5 * _animation.value,
                      ),
                    ]
                  : null,
            ),
            child: widget.child,
          );
        },
      ),
    );
  }
}

/// Glow effect widget implementation
class _GlowEffectWidget extends StatefulWidget {
  final Widget child;
  final bool isGlowing;
  final Color glowColor;
  final double glowRadius;
  final Duration duration;

  const _GlowEffectWidget({
    required this.child,
    required this.isGlowing,
    required this.glowColor,
    required this.glowRadius,
    required this.duration,
  });

  @override
  State<_GlowEffectWidget> createState() => _GlowEffectWidgetState();
}

class _GlowEffectWidgetState extends State<_GlowEffectWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: widget.duration, vsync: this);
    _glowAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: AppAnimations.defaultCurve),
    );

    if (widget.isGlowing) {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(_GlowEffectWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isGlowing != oldWidget.isGlowing) {
      if (widget.isGlowing) {
        _controller.forward();
      } else {
        _controller.reverse();
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
    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: widget.glowColor.withValues(
                  alpha: 0.5 * _glowAnimation.value,
                ),
                blurRadius: widget.glowRadius * _glowAnimation.value,
                spreadRadius: 2 * _glowAnimation.value,
              ),
            ],
          ),
          child: widget.child,
        );
      },
    );
  }
}

/// Parallax effect widget implementation
class _ParallaxEffectWidget extends StatefulWidget {
  final Widget child;
  final ScrollController scrollController;
  final double parallaxFactor;

  const _ParallaxEffectWidget({
    required this.child,
    required this.scrollController,
    required this.parallaxFactor,
  });

  @override
  State<_ParallaxEffectWidget> createState() => _ParallaxEffectWidgetState();
}

class _ParallaxEffectWidgetState extends State<_ParallaxEffectWidget> {
  double _offset = 0.0;

  @override
  void initState() {
    super.initState();
    widget.scrollController.addListener(_updateOffset);
  }

  @override
  void dispose() {
    widget.scrollController.removeListener(_updateOffset);
    super.dispose();
  }

  void _updateOffset() {
    setState(() {
      _offset = widget.scrollController.offset * widget.parallaxFactor;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: Offset(0, _offset),
      child: widget.child,
    );
  }
}

/// Morphing container widget implementation
class _MorphingContainerWidget extends StatefulWidget {
  final Widget child;
  final bool isMorphed;
  final Duration duration;
  final BorderRadius? fromBorderRadius;
  final BorderRadius? toBorderRadius;
  final Color? fromColor;
  final Color? toColor;
  final double? fromWidth;
  final double? toWidth;
  final double? fromHeight;
  final double? toHeight;

  const _MorphingContainerWidget({
    required this.child,
    required this.isMorphed,
    required this.duration,
    this.fromBorderRadius,
    this.toBorderRadius,
    this.fromColor,
    this.toColor,
    this.fromWidth,
    this.toWidth,
    this.fromHeight,
    this.toHeight,
  });

  @override
  State<_MorphingContainerWidget> createState() =>
      _MorphingContainerWidgetState();
}

class _MorphingContainerWidgetState extends State<_MorphingContainerWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: widget.duration, vsync: this);

    if (widget.isMorphed) {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(_MorphingContainerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isMorphed != oldWidget.isMorphed) {
      if (widget.isMorphed) {
        _controller.forward();
      } else {
        _controller.reverse();
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
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return AnimatedContainer(
          duration: widget.duration,
          width: widget.fromWidth != null && widget.toWidth != null
              ? Tween<double>(
                  begin: widget.fromWidth!,
                  end: widget.toWidth!,
                ).animate(_controller).value
              : null,
          height: widget.fromHeight != null && widget.toHeight != null
              ? Tween<double>(
                  begin: widget.fromHeight!,
                  end: widget.toHeight!,
                ).animate(_controller).value
              : null,
          decoration: BoxDecoration(
            borderRadius: widget.fromBorderRadius != null &&
                    widget.toBorderRadius != null
                ? BorderRadiusTween(
                    begin: widget.fromBorderRadius!,
                    end: widget.toBorderRadius!,
                  ).animate(_controller).value
                : null,
            color: widget.fromColor != null && widget.toColor != null
                ? ColorTween(
                    begin: widget.fromColor!,
                    end: widget.toColor!,
                  ).animate(_controller).value
                : null,
          ),
          child: widget.child,
        );
      },
    );
  }
}

/// Breathing animation widget implementation
class _BreathingAnimationWidget extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final double minScale;
  final double maxScale;
  final bool repeat;

  const _BreathingAnimationWidget({
    required this.child,
    required this.duration,
    required this.minScale,
    required this.maxScale,
    required this.repeat,
  });

  @override
  State<_BreathingAnimationWidget> createState() =>
      _BreathingAnimationWidgetState();
}

class _BreathingAnimationWidgetState extends State<_BreathingAnimationWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: widget.duration, vsync: this);
    _scaleAnimation = Tween<double>(
      begin: widget.minScale,
      end: widget.maxScale,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

    if (widget.repeat) {
      _controller.repeat(reverse: true);
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: widget.child,
        );
      },
    );
  }
}

/// Typewriter text widget implementation
class _TypewriterTextWidget extends StatefulWidget {
  final String text;
  final bool startAnimation;
  final Duration duration;
  final TextStyle? textStyle;
  final VoidCallback? onComplete;

  const _TypewriterTextWidget({
    required this.text,
    required this.startAnimation,
    required this.duration,
    this.textStyle,
    this.onComplete,
  });

  @override
  State<_TypewriterTextWidget> createState() => _TypewriterTextWidgetState();
}

class _TypewriterTextWidgetState extends State<_TypewriterTextWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<int> _characterCount;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration * widget.text.length,
      vsync: this,
    );

    _characterCount = IntTween(
      begin: 0,
      end: widget.text.length,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

    if (widget.startAnimation) {
      _controller.forward().then((_) => widget.onComplete?.call());
    }
  }

  @override
  void didUpdateWidget(_TypewriterTextWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.startAnimation && !oldWidget.startAnimation) {
      _controller.forward().then((_) => widget.onComplete?.call());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _characterCount,
      builder: (context, child) {
        final displayText = widget.text.substring(0, _characterCount.value);
        return Text(
          displayText,
          style: widget.textStyle,
        );
      },
    );
  }
}

/// Particle effect widget implementation
class _ParticleEffectWidget extends StatefulWidget {
  final Widget child;
  final bool showParticles;
  final int particleCount;
  final Color particleColor;
  final Duration duration;

  const _ParticleEffectWidget({
    required this.child,
    required this.showParticles,
    required this.particleCount,
    required this.particleColor,
    required this.duration,
  });

  @override
  State<_ParticleEffectWidget> createState() => _ParticleEffectWidgetState();
}

class _ParticleEffectWidgetState extends State<_ParticleEffectWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<Particle> _particles;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: widget.duration, vsync: this);
    _particles = List.generate(widget.particleCount, (index) => Particle());

    if (widget.showParticles) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(_ParticleEffectWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.showParticles != oldWidget.showParticles) {
      if (widget.showParticles) {
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
    return Stack(
      children: [
        widget.child,
        if (widget.showParticles)
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return CustomPaint(
                painter: _ParticlePainter(
                  particles: _particles,
                  animationValue: _controller.value,
                  color: widget.particleColor,
                ),
                size: Size.infinite,
              );
            },
          ),
      ],
    );
  }
}

/// Card flip widget implementation
class _CardFlipWidget extends StatefulWidget {
  final Widget frontChild;
  final Widget backChild;
  final bool isFlipped;
  final Duration duration;
  final VoidCallback? onTap;

  const _CardFlipWidget({
    required this.frontChild,
    required this.backChild,
    required this.isFlipped,
    required this.duration,
    this.onTap,
  });

  @override
  State<_CardFlipWidget> createState() => _CardFlipWidgetState();
}

class _CardFlipWidgetState extends State<_CardFlipWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _flipAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: widget.duration, vsync: this);
    _flipAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    if (widget.isFlipped) {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(_CardFlipWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isFlipped != oldWidget.isFlipped) {
      if (widget.isFlipped) {
        _controller.forward();
      } else {
        _controller.reverse();
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
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _flipAnimation,
        builder: (context, child) {
          final isShowingFront = _flipAnimation.value < 0.5;
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateY(_flipAnimation.value * 3.14159),
            child: isShowingFront
                ? widget.frontChild
                : Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()..rotateY(3.14159),
                    child: widget.backChild,
                  ),
          );
        },
      ),
    );
  }
}

/// Particle class for particle effects
class Particle {
  late double x;
  late double y;
  late double vx;
  late double vy;
  late double life;

  Particle() {
    reset();
  }

  void reset() {
    x = 0.5;
    y = 0.5;
    vx = (math.Random().nextDouble() - 0.5) * 2;
    vy = (math.Random().nextDouble() - 0.5) * 2;
    life = 1.0;
  }

  void update(double dt) {
    x += vx * dt;
    y += vy * dt;
    life -= dt;
    
    if (life <= 0) {
      reset();
    }
  }
}

/// Custom painter for particle effects
class _ParticlePainter extends CustomPainter {
  final List<Particle> particles;
  final double animationValue;
  final Color color;

  _ParticlePainter({
    required this.particles,
    required this.animationValue,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    for (final particle in particles) {
      particle.update(0.016); // Assume 60fps
      
      final opacity = particle.life.clamp(0.0, 1.0);
      paint.color = color.withValues(alpha: opacity);
      
      canvas.drawCircle(
        Offset(particle.x * size.width, particle.y * size.height),
        2.0 * particle.life,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

