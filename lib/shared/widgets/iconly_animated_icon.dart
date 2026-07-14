import 'package:flutter/material.dart';
import 'package:iconly/iconly.dart';

/// Animated icon widget that smoothly transitions between Iconly icons
/// Uses AnimatedSwitcher for smooth fade and scale transitions
class IconlyAnimatedIcon extends StatelessWidget {
  final IconData icon;
  final double size;
  final Color? color;
  final Duration duration;
  final Curve curve;

  const IconlyAnimatedIcon({
    super.key,
    required this.icon,
    this.size = 24.0,
    this.color,
    this.duration = const Duration(milliseconds: 300),
    this.curve = Curves.easeInOut,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: duration,
      switchInCurve: curve,
      switchOutCurve: curve,
      transitionBuilder: (Widget child, Animation<double> animation) {
        return ScaleTransition(
          scale: animation,
          child: FadeTransition(
            opacity: animation,
            child: child,
          ),
        );
      },
      child: Icon(
        icon,
        key: ValueKey<IconData>(icon),
        size: size,
        color: color,
      ),
    );
  }
}

/// Animated toggle icon that switches between two Iconly icons
/// Perfect for favorite, bookmark, and other toggle actions
class IconlyToggleIcon extends StatelessWidget {
  final bool isActive;
  final IconData activeIcon;
  final IconData inactiveIcon;
  final double size;
  final Color? activeColor;
  final Color? inactiveColor;
  final Duration duration;
  final VoidCallback? onTap;
  final String? tooltip;

  const IconlyToggleIcon({
    super.key,
    required this.isActive,
    required this.activeIcon,
    required this.inactiveIcon,
    this.size = 24.0,
    this.activeColor,
    this.inactiveColor,
    this.duration = const Duration(milliseconds: 300),
    this.onTap,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final icon = isActive ? activeIcon : inactiveIcon;
    final color = isActive 
        ? (activeColor ?? Theme.of(context).primaryColor)
        : (inactiveColor ?? Colors.grey);

    Widget iconWidget = AnimatedSwitcher(
      duration: duration,
      transitionBuilder: (Widget child, Animation<double> animation) {
        return ScaleTransition(
          scale: Tween<double>(begin: 0.8, end: 1.0).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
          ),
          child: FadeTransition(
            opacity: animation,
            child: child,
          ),
        );
      },
      child: Icon(
        icon,
        key: ValueKey<IconData>(icon),
        size: size,
        color: color,
      ),
    );

    if (onTap != null) {
      iconWidget = GestureDetector(
        onTap: onTap,
        child: iconWidget,
      );
    }

    if (tooltip != null) {
      iconWidget = Tooltip(
        message: tooltip!,
        child: iconWidget,
      );
    }

    return iconWidget;
  }
}

/// Animated favorite icon using Iconly heart icons
class IconlyFavoriteIcon extends StatelessWidget {
  final bool isFavorite;
  final VoidCallback onToggle;
  final double size;
  final Color? favoriteColor;
  final Color? unfavoriteColor;

  const IconlyFavoriteIcon({
    super.key,
    required this.isFavorite,
    required this.onToggle,
    this.size = 24.0,
    this.favoriteColor,
    this.unfavoriteColor,
  });

  @override
  Widget build(BuildContext context) {
    return IconlyToggleIcon(
      isActive: isFavorite,
      activeIcon: IconlyBold.heart,
      inactiveIcon: IconlyLight.heart,
      size: size,
      activeColor: favoriteColor ?? Colors.red,
      inactiveColor: unfavoriteColor ?? Colors.grey,
      onTap: onToggle,
      tooltip: isFavorite ? 'Remove from favorites' : 'Add to favorites',
    );
  }
}

/// Animated bookmark icon using Iconly bookmark icons
class IconlyBookmarkIcon extends StatelessWidget {
  final bool isBookmarked;
  final VoidCallback onToggle;
  final double size;
  final Color? bookmarkedColor;
  final Color? unbookmarkedColor;

  const IconlyBookmarkIcon({
    super.key,
    required this.isBookmarked,
    required this.onToggle,
    this.size = 24.0,
    this.bookmarkedColor,
    this.unbookmarkedColor,
  });

  @override
  Widget build(BuildContext context) {
    return IconlyToggleIcon(
      isActive: isBookmarked,
      activeIcon: IconlyBold.bookmark,
      inactiveIcon: IconlyLight.bookmark,
      size: size,
      activeColor: bookmarkedColor ?? const Color(0xFFFF6B35),
      inactiveColor: unbookmarkedColor ?? Colors.grey,
      onTap: onToggle,
      tooltip: isBookmarked ? 'Remove bookmark' : 'Bookmark',
    );
  }
}

/// Animated star icon for ratings
class IconlyStarIcon extends StatelessWidget {
  final bool isActive;
  final VoidCallback? onToggle;
  final double size;
  final Color? activeColor;
  final Color? inactiveColor;

  const IconlyStarIcon({
    super.key,
    required this.isActive,
    this.onToggle,
    this.size = 24.0,
    this.activeColor,
    this.inactiveColor,
  });

  @override
  Widget build(BuildContext context) {
    return IconlyToggleIcon(
      isActive: isActive,
      activeIcon: IconlyBold.star,
      inactiveIcon: IconlyLight.star,
      size: size,
      activeColor: activeColor ?? const Color(0xFFFFA500),
      inactiveColor: inactiveColor ?? Colors.grey[300],
      onTap: onToggle,
    );
  }
}

/// Animated notification icon with badge
class IconlyNotificationIcon extends StatelessWidget {
  final bool hasNotifications;
  final VoidCallback onTap;
  final double size;
  final int? notificationCount;
  final Color? iconColor;
  final Color? badgeColor;

  const IconlyNotificationIcon({
    super.key,
    required this.hasNotifications,
    required this.onTap,
    this.size = 24.0,
    this.notificationCount,
    this.iconColor,
    this.badgeColor,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconlyToggleIcon(
          isActive: hasNotifications,
          activeIcon: IconlyBold.notification,
          inactiveIcon: IconlyLight.notification,
          size: size,
          activeColor: iconColor ?? Colors.white,
          inactiveColor: iconColor ?? Colors.white,
          onTap: onTap,
          tooltip: 'Notifications',
        ),
        if (hasNotifications && notificationCount != null && notificationCount! > 0)
          Positioned(
            right: -6,
            top: -6,
            child: AnimatedScale(
              scale: hasNotifications ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              curve: Curves.elasticOut,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: badgeColor ?? Colors.red,
                  shape: BoxShape.circle,
                ),
                constraints: const BoxConstraints(
                  minWidth: 18,
                  minHeight: 18,
                ),
                child: Text(
                  notificationCount! > 99 ? '99+' : notificationCount.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Animated search icon that pulses
class IconlySearchIcon extends StatefulWidget {
  final bool isActive;
  final VoidCallback? onTap;
  final double size;
  final Color? color;

  const IconlySearchIcon({
    super.key,
    required this.isActive,
    this.onTap,
    this.size = 24.0,
    this.color,
  });

  @override
  State<IconlySearchIcon> createState() => _IconlySearchIconState();
}

class _IconlySearchIconState extends State<IconlySearchIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    if (widget.isActive) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(IconlySearchIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        _controller.repeat(reverse: true);
      } else {
        _controller.stop();
        _controller.value = 0;
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
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: widget.isActive ? _scaleAnimation.value : 1.0,
            child: IconlyToggleIcon(
              isActive: widget.isActive,
              activeIcon: IconlyBold.search,
              inactiveIcon: IconlyLight.search,
              size: widget.size,
              activeColor: widget.color ?? const Color(0xFFFF6B35),
              inactiveColor: widget.color ?? Colors.grey,
            ),
          );
        },
      ),
    );
  }
}

/// Animated location icon with pulse effect
class IconlyLocationIcon extends StatefulWidget {
  final bool isActive;
  final VoidCallback? onTap;
  final double size;
  final Color? color;

  const IconlyLocationIcon({
    super.key,
    required this.isActive,
    this.onTap,
    this.size = 24.0,
    this.color,
  });

  @override
  State<IconlyLocationIcon> createState() => _IconlyLocationIconState();
}

class _IconlyLocationIconState extends State<IconlyLocationIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    if (widget.isActive) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(IconlyLocationIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        _controller.repeat(reverse: true);
      } else {
        _controller.stop();
        _controller.value = 0;
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
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: widget.isActive ? _pulseAnimation.value : 1.0,
            child: IconlyToggleIcon(
              isActive: widget.isActive,
              activeIcon: IconlyBold.location,
              inactiveIcon: IconlyLight.location,
              size: widget.size,
              activeColor: widget.color ?? const Color(0xFFFF6B35),
              inactiveColor: widget.color ?? Colors.grey,
            ),
          );
        },
      ),
    );
  }
}

/// Animated filter icon with rotation
class IconlyFilterIcon extends StatefulWidget {
  final bool isActive;
  final VoidCallback onTap;
  final double size;
  final Color? activeColor;
  final Color? inactiveColor;

  const IconlyFilterIcon({
    super.key,
    required this.isActive,
    required this.onTap,
    this.size = 24.0,
    this.activeColor,
    this.inactiveColor,
  });

  @override
  State<IconlyFilterIcon> createState() => _IconlyFilterIconState();
}

class _IconlyFilterIconState extends State<IconlyFilterIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _rotationAnimation = Tween<double>(begin: 0.0, end: 0.5).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    if (widget.isActive) {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(IconlyFilterIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
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
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _rotationAnimation,
        builder: (context, child) {
          return Transform.rotate(
            angle: _rotationAnimation.value * 3.14159,
            child: IconlyToggleIcon(
              isActive: widget.isActive,
              activeIcon: IconlyBold.filter,
              inactiveIcon: IconlyLight.filter,
              size: widget.size,
              activeColor: widget.activeColor ?? const Color(0xFFFF6B35),
              inactiveColor: widget.inactiveColor ?? Colors.grey,
            ),
          );
        },
      ),
    );
  }
}
