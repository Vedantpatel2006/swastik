import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_animations.dart';

/// Enhanced animation utilities for user interactions and visual polish
class UserInteractionAnimations {
  /// Creates an animated favorite button with scale and color transitions
  static Widget animatedFavoriteButton({
    required bool isFavorite,
    required VoidCallback onTap,
    required AnimationController controller,
    Color favoriteColor = Colors.red,
    Color unfavoriteColor = Colors.grey,
    double size = 24.0,
    String? semanticLabel,
  }) {
    final scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(parent: controller, curve: Curves.elasticOut));

    final colorAnimation =
        ColorTween(begin: unfavoriteColor, end: favoriteColor).animate(
          CurvedAnimation(
            parent: controller,
            curve: AppAnimations.defaultCurve,
          ),
        );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        // Trigger haptic feedback
        HapticFeedback.selectionClick();

        // Animate the button
        controller.forward().then((_) {
          controller.reverse();
        });

        // Call the callback
        onTap();
      },
      child: Semantics(
        label:
            semanticLabel ??
            (isFavorite ? 'Remove from favorites' : 'Add to favorites'),
        button: true,
        child: AnimatedBuilder(
          animation: controller,
          builder: (context, child) {
            return Transform.scale(
              scale: scaleAnimation.value,
              child: Icon(
                isFavorite ? Icons.favorite : Icons.favorite_border,
                color: isFavorite ? favoriteColor : colorAnimation.value,
                size: size,
              ),
            );
          },
        ),
      ),
    );
  }

  /// Creates an animated loading indicator with pulse effect
  static Widget animatedLoadingIndicator({
    required AnimationController controller,
    String? message,
    Color color = Colors.orange,
    double size = 40.0,
  }) {
    final pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(parent: controller, curve: Curves.easeInOut));

    final fadeAnimation = Tween<double>(
      begin: 0.5,
      end: 1.0,
    ).animate(CurvedAnimation(parent: controller, curve: Curves.easeInOut));

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: controller,
          builder: (context, child) {
            return Transform.scale(
              scale: pulseAnimation.value,
              child: Opacity(
                opacity: fadeAnimation.value,
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                  strokeWidth: 3.0,
                ),
              ),
            );
          },
        ),
        if (message != null) ...[
          const SizedBox(height: 16),
          AnimatedBuilder(
            animation: controller,
            builder: (context, child) {
              return Opacity(
                opacity: fadeAnimation.value,
                child: Text(
                  message,
                  style: TextStyle(color: color, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              );
            },
          ),
        ],
      ],
    );
  }

  /// Creates an animated search result item with staggered entrance
  static Widget animatedSearchResultItem({
    required Widget child,
    required AnimationController controller,
    required int index,
  }) {
    final slideAnimation =
        Tween<Offset>(begin: const Offset(0.3, 0.0), end: Offset.zero).animate(
          CurvedAnimation(
            parent: controller,
            curve: Interval(
              (index * 0.1).clamp(0.0, 1.0),
              1.0,
              curve: AppAnimations.pageTransitionCurve,
            ),
          ),
        );

    final fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: controller,
        curve: Interval(
          (index * 0.1).clamp(0.0, 1.0),
          1.0,
          curve: AppAnimations.defaultCurve,
        ),
      ),
    );

    return SlideTransition(
      position: slideAnimation,
      child: FadeTransition(opacity: fadeAnimation, child: child),
    );
  }

  /// Creates an animated pull-to-refresh indicator
  static Widget animatedRefreshIndicator({
    required Widget child,
    required Future<void> Function() onRefresh,
    Color color = Colors.orange,
  }) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: color,
      backgroundColor: Colors.white,
      strokeWidth: 3.0,
      displacement: 60.0,
      child: child,
    );
  }

  /// Creates micro-interactions for button presses
  static Widget animatedButton({
    required Widget child,
    required VoidCallback? onPressed,
    Duration duration = const Duration(milliseconds: 150),
    Color? splashColor,
    Color? highlightColor,
    BorderRadius? borderRadius,
  }) {
    return AnimatedScale(
      scale: 1.0,
      duration: duration,
      curve: AppAnimations.interactionCurve,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed != null
              ? () {
                  HapticFeedback.lightImpact();
                  onPressed();
                }
              : null,
          splashColor: splashColor,
          highlightColor: highlightColor,
          borderRadius: borderRadius,
          child: child,
        ),
      ),
    );
  }

  /// Creates an animated card with hover and tap effects
  static Widget animatedCard({
    required Widget child,
    VoidCallback? onTap,
    Duration duration = const Duration(milliseconds: 200),
    double elevation = 2.0,
    double hoverElevation = 8.0,
    BorderRadius? borderRadius,
    Color? color,
  }) {
    return StatefulBuilder(
      builder: (context, setState) {
        return MouseRegion(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap != null
                ? () {
                    HapticFeedback.selectionClick();
                    onTap();
                  }
                : null,
            child: AnimatedContainer(
              duration: duration,
              curve: AppAnimations.interactionCurve,
              child: Card(
                elevation: elevation,
                shape: RoundedRectangleBorder(
                  borderRadius: borderRadius ?? BorderRadius.circular(12),
                ),
                color: color,
                child: AnimatedScale(
                  scale: 1.0,
                  duration: duration,
                  curve: AppAnimations.interactionCurve,
                  child: child,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Creates staggered list animations for temple cards
  static Widget staggeredListAnimation({
    required List<Widget> children,
    required AnimationController controller,
    Axis scrollDirection = Axis.vertical,
  }) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return ListView.builder(
          scrollDirection: scrollDirection,
          itemCount: children.length,
          itemBuilder: (context, index) {
            final itemAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
              CurvedAnimation(
                parent: controller,
                curve: Interval(
                  (index * 0.1).clamp(0.0, 0.8),
                  ((index * 0.1) + 0.2).clamp(0.2, 1.0),
                  curve: AppAnimations.pageTransitionCurve,
                ),
              ),
            );

            final slideAnimation =
                Tween<Offset>(
                  begin: scrollDirection == Axis.vertical
                      ? const Offset(0.0, 0.5)
                      : const Offset(0.5, 0.0),
                  end: Offset.zero,
                ).animate(
                  CurvedAnimation(
                    parent: controller,
                    curve: Interval(
                      (index * 0.1).clamp(0.0, 0.8),
                      ((index * 0.1) + 0.2).clamp(0.2, 1.0),
                      curve: AppAnimations.pageTransitionCurve,
                    ),
                  ),
                );

            return SlideTransition(
              position: slideAnimation,
              child: FadeTransition(
                opacity: itemAnimation,
                child: children[index],
              ),
            );
          },
        );
      },
    );
  }

  /// Creates a shimmer loading effect for content
  static Widget shimmerLoading({
    required Widget child,
    required AnimationController controller,
    Color baseColor = const Color(0xFFE0E0E0),
    Color highlightColor = const Color(0xFFF5F5F5),
  }) {
    final shimmerAnimation = Tween<double>(
      begin: -1.0,
      end: 2.0,
    ).animate(CurvedAnimation(parent: controller, curve: Curves.easeInOut));

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [baseColor, highlightColor, baseColor],
              stops: [
                shimmerAnimation.value - 0.3,
                shimmerAnimation.value,
                shimmerAnimation.value + 0.3,
              ].map((stop) => stop.clamp(0.0, 1.0)).toList(),
            ).createShader(bounds);
          },
          child: child,
        );
      },
    );
  }

  /// Creates a success animation with checkmark
  static Widget successAnimation({
    required AnimationController controller,
    String? message,
    Color color = Colors.green,
    double size = 60.0,
  }) {
    final scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: controller, curve: Curves.elasticOut));

    final checkAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: controller,
        curve: const Interval(0.5, 1.0, curve: Curves.easeInOut),
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: controller,
          builder: (context, child) {
            return Transform.scale(
              scale: scaleAnimation.value,
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                child: AnimatedBuilder(
                  animation: checkAnimation,
                  builder: (context, child) {
                    return Opacity(
                      opacity: checkAnimation.value,
                      child: const Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 30,
                      ),
                    );
                  },
                ),
              ),
            );
          },
        ),
        if (message != null) ...[
          const SizedBox(height: 16),
          AnimatedBuilder(
            animation: controller,
            builder: (context, child) {
              return Opacity(
                opacity: scaleAnimation.value,
                child: Text(
                  message,
                  style: TextStyle(
                    color: color,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              );
            },
          ),
        ],
      ],
    );
  }
}
