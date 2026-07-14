import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_animations.dart';

/// Animations for favorite/unfavorite actions with visual feedback
class FavoriteAnimations {
  /// Creates an animated favorite button with heart animation
  static Widget animatedFavoriteButton({
    required bool isFavorite,
    required VoidCallback onTap,
    double size = 24.0,
    Color favoriteColor = const Color(0xFFE91E63),
    Color unfavoriteColor = Colors.grey,
    Duration duration = AppAnimations.normalDuration,
  }) {
    return _AnimatedFavoriteButtonWidget(
      isFavorite: isFavorite,
      onTap: onTap,
      size: size,
      favoriteColor: favoriteColor,
      unfavoriteColor: unfavoriteColor,
      duration: duration,
    );
  }

  /// Creates a floating heart animation for favorite actions
  static Widget floatingHeartAnimation({
    required bool trigger,
    required Widget child,
    Duration duration = const Duration(milliseconds: 1500),
    Color heartColor = const Color(0xFFE91E63),
  }) {
    return _FloatingHeartWidget(
      trigger: trigger,
      duration: duration,
      heartColor: heartColor,
      child: child,
    );
  }

  /// Creates a favorite count animation with bounce effect
  static Widget animatedFavoriteCount({
    required int count,
    Duration duration = AppAnimations.normalDuration,
    TextStyle? textStyle,
  }) {
    return _AnimatedFavoriteCountWidget(
      count: count,
      duration: duration,
      textStyle: textStyle,
    );
  }

  /// Creates a favorite list item with slide and fade animation
  static Widget animatedFavoriteListItem({
    required Widget child,
    required bool isRemoving,
    Duration duration = AppAnimations.normalDuration,
    VoidCallback? onRemoved,
  }) {
    return _AnimatedFavoriteListItemWidget(
      isRemoving: isRemoving,
      duration: duration,
      onRemoved: onRemoved,
      child: child,
    );
  }

  /// Creates a success animation for adding to favorites
  static Widget favoriteSuccessAnimation({
    required bool show,
    String message = 'Added to favorites!',
    Duration duration = const Duration(milliseconds: 2000),
  }) {
    return _FavoriteSuccessAnimationWidget(
      show: show,
      message: message,
      duration: duration,
    );
  }
}

/// Animated favorite button widget implementation
class _AnimatedFavoriteButtonWidget extends StatefulWidget {
  final bool isFavorite;
  final VoidCallback onTap;
  final double size;
  final Color favoriteColor;
  final Color unfavoriteColor;
  final Duration duration;

  const _AnimatedFavoriteButtonWidget({
    required this.isFavorite,
    required this.onTap,
    required this.size,
    required this.favoriteColor,
    required this.unfavoriteColor,
    required this.duration,
  });

  @override
  State<_AnimatedFavoriteButtonWidget> createState() =>
      _AnimatedFavoriteButtonWidgetState();
}

class _AnimatedFavoriteButtonWidgetState
    extends State<_AnimatedFavoriteButtonWidget>
    with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late AnimationController _colorController;
  late Animation<double> _scaleAnimation;
  late Animation<Color?> _colorAnimation;

  @override
  void initState() {
    super.initState();

    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _colorController = AnimationController(
      duration: widget.duration,
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );

    _colorAnimation =
        ColorTween(
          begin: widget.unfavoriteColor,
          end: widget.favoriteColor,
        ).animate(
          CurvedAnimation(
            parent: _colorController,
            curve: AppAnimations.defaultCurve,
          ),
        );

    if (widget.isFavorite) {
      _colorController.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(_AnimatedFavoriteButtonWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isFavorite != oldWidget.isFavorite) {
      if (widget.isFavorite) {
        _colorController.forward();
        _scaleController.forward().then((_) => _scaleController.reverse());
      } else {
        _colorController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _colorController.dispose();
    super.dispose();
  }

  void _handleTap() {
    HapticFeedback.selectionClick();
    _scaleController.forward().then((_) => _scaleController.reverse());
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _handleTap,
      child: AnimatedBuilder(
        animation: Listenable.merge([_scaleAnimation, _colorAnimation]),
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Icon(
              widget.isFavorite ? Icons.favorite : Icons.favorite_border,
              size: widget.size,
              color: widget.isFavorite
                  ? widget.favoriteColor
                  : _colorAnimation.value,
            ),
          );
        },
      ),
    );
  }
}

/// Floating heart animation widget
class _FloatingHeartWidget extends StatefulWidget {
  final bool trigger;
  final Duration duration;
  final Color heartColor;
  final Widget child;

  const _FloatingHeartWidget({
    required this.trigger,
    required this.duration,
    required this.heartColor,
    required this.child,
  });

  @override
  State<_FloatingHeartWidget> createState() => _FloatingHeartWidgetState();
}

class _FloatingHeartWidgetState extends State<_FloatingHeartWidget>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  bool _showHeart = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: widget.duration, vsync: this);

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.5).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.3, curve: Curves.elasticOut),
      ),
    );

    _fadeAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.7, 1.0, curve: Curves.easeOut),
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0.0, -2.0),
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
  }

  @override
  void didUpdateWidget(_FloatingHeartWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.trigger && !oldWidget.trigger) {
      _showFloatingHeart();
    }
  }

  void _showFloatingHeart() {
    setState(() => _showHeart = true);
    _controller.forward().then((_) {
      _controller.reset();
      setState(() => _showHeart = false);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        widget.child,
        if (_showHeart)
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return SlideTransition(
                  position: _slideAnimation,
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: Transform.scale(
                      scale: _scaleAnimation.value,
                      child: Center(
                        child: Icon(
                          Icons.favorite,
                          color: widget.heartColor,
                          size: 30,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

/// Animated favorite count widget
class _AnimatedFavoriteCountWidget extends StatefulWidget {
  final int count;
  final Duration duration;
  final TextStyle? textStyle;

  const _AnimatedFavoriteCountWidget({
    required this.count,
    required this.duration,
    this.textStyle,
  });

  @override
  State<_AnimatedFavoriteCountWidget> createState() =>
      _AnimatedFavoriteCountWidgetState();
}

class _AnimatedFavoriteCountWidgetState
    extends State<_AnimatedFavoriteCountWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  int _previousCount = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: widget.duration, vsync: this);
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.elasticOut));
    _previousCount = widget.count;
  }

  @override
  void didUpdateWidget(_AnimatedFavoriteCountWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.count != oldWidget.count) {
      _controller.forward().then((_) => _controller.reverse());
      _previousCount = oldWidget.count;
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
          child: TweenAnimationBuilder<int>(
            tween: IntTween(begin: _previousCount, end: widget.count),
            duration: widget.duration,
            builder: (context, value, child) {
              return Text(
                value.toString(),
                style:
                    widget.textStyle ?? Theme.of(context).textTheme.bodyMedium,
              );
            },
          ),
        );
      },
    );
  }
}

/// Animated favorite list item widget
class _AnimatedFavoriteListItemWidget extends StatefulWidget {
  final Widget child;
  final bool isRemoving;
  final Duration duration;
  final VoidCallback? onRemoved;

  const _AnimatedFavoriteListItemWidget({
    required this.child,
    required this.isRemoving,
    required this.duration,
    this.onRemoved,
  });

  @override
  State<_AnimatedFavoriteListItemWidget> createState() =>
      _AnimatedFavoriteListItemWidgetState();
}

class _AnimatedFavoriteListItemWidgetState
    extends State<_AnimatedFavoriteListItemWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: widget.duration, vsync: this);

    _fadeAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: AppAnimations.defaultCurve),
    );

    _slideAnimation =
        Tween<Offset>(begin: Offset.zero, end: const Offset(-1.0, 0.0)).animate(
          CurvedAnimation(
            parent: _controller,
            curve: AppAnimations.pageTransitionCurve,
          ),
        );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.8).animate(
      CurvedAnimation(parent: _controller, curve: AppAnimations.defaultCurve),
    );
  }

  @override
  void didUpdateWidget(_AnimatedFavoriteListItemWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isRemoving && !oldWidget.isRemoving) {
      _controller.forward().then((_) {
        widget.onRemoved?.call();
      });
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
        return SlideTransition(
          position: _slideAnimation,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Transform.scale(
              scale: _scaleAnimation.value,
              child: widget.child,
            ),
          ),
        );
      },
    );
  }
}

/// Favorite success animation widget
class _FavoriteSuccessAnimationWidget extends StatefulWidget {
  final bool show;
  final String message;
  final Duration duration;

  const _FavoriteSuccessAnimationWidget({
    required this.show,
    required this.message,
    required this.duration,
  });

  @override
  State<_FavoriteSuccessAnimationWidget> createState() =>
      _FavoriteSuccessAnimationWidgetState();
}

class _FavoriteSuccessAnimationWidgetState
    extends State<_FavoriteSuccessAnimationWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: widget.duration, vsync: this);

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.3, curve: Curves.easeOut),
      ),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0.0, 1.0), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _controller,
            curve: const Interval(0.0, 0.5, curve: Curves.elasticOut),
          ),
        );
  }

  @override
  void didUpdateWidget(_FavoriteSuccessAnimationWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.show && !oldWidget.show) {
      _controller.forward().then((_) {
        Future.delayed(const Duration(milliseconds: 1000), () {
          if (mounted) {
            _controller.reverse();
          }
        });
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.show) return const SizedBox.shrink();

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return SlideTransition(
          position: _slideAnimation,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFE91E63),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.favorite, color: Colors.white, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    widget.message,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
