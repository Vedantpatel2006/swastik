import 'package:flutter/material.dart';
import 'app_animations.dart';
import 'transition_manager.dart';

/// Enhanced screen transition animations for smooth navigation
class ScreenTransitionAnimations {
  /// Creates a temple-themed page transition with shared elements
  static PageRouteBuilder<T> templePageTransition<T>({
    required Widget page,
    TransitionType transitionType = TransitionType.fadeSlide,
    Duration duration = AppAnimations.normalDuration,
    String? heroTag,
    RouteSettings? settings,
  }) {
    return PageRouteBuilder<T>(
      settings: settings,
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: duration,
      reverseTransitionDuration: duration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return _buildTransition(
          child,
          animation,
          secondaryAnimation,
          transitionType,
          heroTag,
        );
      },
    );
  }

  /// Creates a modal bottom sheet transition with custom animation
  static Widget modalBottomSheetTransition({
    required Widget child,
    required Animation<double> animation,
    bool enableDrag = true,
  }) {
    return _ModalBottomSheetTransitionWidget(
      animation: animation,
      enableDrag: enableDrag,
      child: child,
    );
  }

  /// Creates a dialog transition with scale and fade
  static Widget dialogTransition({
    required Widget child,
    required Animation<double> animation,
  }) {
    return _DialogTransitionWidget(animation: animation, child: child);
  }

  /// Creates a tab transition animation
  static Widget tabTransition({
    required Widget child,
    required Animation<double> animation,
    required int index,
    required int previousIndex,
  }) {
    return _TabTransitionWidget(
      animation: animation,
      index: index,
      previousIndex: previousIndex,
      child: child,
    );
  }

  /// Creates a list item transition for staggered animations
  static Widget listItemTransition({
    required Widget child,
    required Animation<double> animation,
    required int index,
    Duration delay = const Duration(milliseconds: 50),
  }) {
    return _ListItemTransitionWidget(
      animation: animation,
      index: index,
      delay: delay,
      child: child,
    );
  }

  /// Creates a hero transition for temple images
  static Widget heroImageTransition({
    required String heroTag,
    required Widget child,
    BorderRadius? borderRadius,
  }) {
    return Hero(
      tag: heroTag,
      child: ClipRRect(
        borderRadius: borderRadius ?? BorderRadius.circular(12),
        child: child,
      ),
    );
  }

  /// Helper method to build transitions
  static Widget _buildTransition(
    Widget child,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    TransitionType transitionType,
    String? heroTag,
  ) {
    // Add secondary animation for the previous page
    final secondaryChild = SlideTransition(
      position: Tween<Offset>(begin: Offset.zero, end: const Offset(-0.3, 0.0))
          .animate(
            CurvedAnimation(
              parent: secondaryAnimation,
              curve: AppAnimations.pageTransitionCurve,
            ),
          ),
      child: child,
    );

    switch (transitionType) {
      case TransitionType.slideFromRight:
        return TransitionManager.slideTransition(
          secondaryChild,
          animation,
          begin: const Offset(1.0, 0.0),
        );
      case TransitionType.slideFromLeft:
        return TransitionManager.slideTransition(
          secondaryChild,
          animation,
          begin: const Offset(-1.0, 0.0),
        );
      case TransitionType.slideFromBottom:
        return TransitionManager.slideTransition(
          secondaryChild,
          animation,
          begin: const Offset(0.0, 1.0),
        );
      case TransitionType.fade:
        return TransitionManager.fadeTransition(secondaryChild, animation);
      case TransitionType.scale:
        return TransitionManager.scaleTransition(secondaryChild, animation);
      case TransitionType.fadeSlide:
        return TransitionManager.fadeSlideTransition(secondaryChild, animation);
      case TransitionType.scaleFade:
        return TransitionManager.scaleFadeTransition(secondaryChild, animation);
      case TransitionType.sharedElement:
        return TransitionManager.sharedElementTransition(
          secondaryChild,
          animation,
        );
      default:
        return TransitionManager.fadeSlideTransition(secondaryChild, animation);
    }
  }
}

/// Modal bottom sheet transition widget
class _ModalBottomSheetTransitionWidget extends StatelessWidget {
  final Widget child;
  final Animation<double> animation;
  final bool enableDrag;

  const _ModalBottomSheetTransitionWidget({
    required this.child,
    required this.animation,
    required this.enableDrag,
  });

  @override
  Widget build(BuildContext context) {
    final slideAnimation =
        Tween<Offset>(begin: const Offset(0.0, 1.0), end: Offset.zero).animate(
          CurvedAnimation(
            parent: animation,
            curve: AppAnimations.pageTransitionCurve,
          ),
        );

    final fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: animation, curve: AppAnimations.defaultCurve),
    );

    return SlideTransition(
      position: slideAnimation,
      child: FadeTransition(
        opacity: fadeAnimation,
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 10,
                offset: Offset(0, -2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (enableDrag)
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              Flexible(child: child),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dialog transition widget
class _DialogTransitionWidget extends StatelessWidget {
  final Widget child;
  final Animation<double> animation;

  const _DialogTransitionWidget({required this.child, required this.animation});

  @override
  Widget build(BuildContext context) {
    final scaleAnimation = Tween<double>(
      begin: 0.7,
      end: 1.0,
    ).animate(CurvedAnimation(parent: animation, curve: Curves.elasticOut));

    final fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: animation, curve: AppAnimations.defaultCurve),
    );

    return ScaleTransition(
      scale: scaleAnimation,
      child: FadeTransition(opacity: fadeAnimation, child: child),
    );
  }
}

/// Tab transition widget
class _TabTransitionWidget extends StatelessWidget {
  final Widget child;
  final Animation<double> animation;
  final int index;
  final int previousIndex;

  const _TabTransitionWidget({
    required this.child,
    required this.animation,
    required this.index,
    required this.previousIndex,
  });

  @override
  Widget build(BuildContext context) {
    final isMovingRight = index > previousIndex;

    final slideAnimation =
        Tween<Offset>(
          begin: Offset(isMovingRight ? 1.0 : -1.0, 0.0),
          end: Offset.zero,
        ).animate(
          CurvedAnimation(
            parent: animation,
            curve: AppAnimations.pageTransitionCurve,
          ),
        );

    final fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: animation, curve: AppAnimations.defaultCurve),
    );

    return SlideTransition(
      position: slideAnimation,
      child: FadeTransition(opacity: fadeAnimation, child: child),
    );
  }
}

/// List item transition widget
class _ListItemTransitionWidget extends StatefulWidget {
  final Widget child;
  final Animation<double> animation;
  final int index;
  final Duration delay;

  const _ListItemTransitionWidget({
    required this.child,
    required this.animation,
    required this.index,
    required this.delay,
  });

  @override
  State<_ListItemTransitionWidget> createState() =>
      _ListItemTransitionWidgetState();
}

class _ListItemTransitionWidgetState extends State<_ListItemTransitionWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _delayController;
  late Animation<double> _delayedAnimation;

  @override
  void initState() {
    super.initState();
    _delayController = AnimationController(duration: widget.delay, vsync: this);

    _delayedAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _delayController,
        curve: AppAnimations.defaultCurve,
      ),
    );

    // Start the delay animation
    Future.delayed(widget.delay * widget.index, () {
      if (mounted) {
        _delayController.forward();
      }
    });
  }

  @override
  void dispose() {
    _delayController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final slideAnimation =
        Tween<Offset>(begin: const Offset(0.0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(
            parent: widget.animation,
            curve: AppAnimations.pageTransitionCurve,
          ),
        );

    return AnimatedBuilder(
      animation: Listenable.merge([widget.animation, _delayedAnimation]),
      builder: (context, child) {
        return SlideTransition(
          position: slideAnimation,
          child: FadeTransition(
            opacity: Tween<double>(begin: 0.0, end: widget.animation.value)
                .animate(
                  CurvedAnimation(
                    parent: _delayedAnimation,
                    curve: AppAnimations.defaultCurve,
                  ),
                ),
            child: widget.child,
          ),
        );
      },
    );
  }
}
