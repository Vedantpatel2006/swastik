import 'package:flutter/material.dart';
import 'package:animate_icons/animate_icons.dart';
import 'package:iconly/iconly.dart';

/// A reusable animated icon button widget
/// Provides smooth transitions between two icon states
class AnimatedIconButton extends StatefulWidget {
  final IconData startIcon;
  final IconData endIcon;
  final VoidCallback? onStartIconPress;
  final VoidCallback? onEndIconPress;
  final Color? startIconColor;
  final Color? endIconColor;
  final double size;
  final Duration duration;
  final bool clockwise;
  final String? startTooltip;
  final String? endTooltip;

  const AnimatedIconButton({
    super.key,
    required this.startIcon,
    required this.endIcon,
    this.onStartIconPress,
    this.onEndIconPress,
    this.startIconColor,
    this.endIconColor,
    this.size = 24.0,
    this.duration = const Duration(milliseconds: 300),
    this.clockwise = false,
    this.startTooltip,
    this.endTooltip,
  });

  @override
  State<AnimatedIconButton> createState() => _AnimatedIconButtonState();
}

class _AnimatedIconButtonState extends State<AnimatedIconButton> {
  late AnimateIconController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimateIconController();
  }

  @override
  Widget build(BuildContext context) {
    return AnimateIcons(
      startIcon: widget.startIcon,
      endIcon: widget.endIcon,
      size: widget.size,
      controller: _controller,
      startTooltip: widget.startTooltip,
      endTooltip: widget.endTooltip,
      onStartIconPress: () {
        widget.onStartIconPress?.call();
        return true;
      },
      onEndIconPress: () {
        widget.onEndIconPress?.call();
        return true;
      },
      duration: widget.duration,
      startIconColor: widget.startIconColor ?? Theme.of(context).iconTheme.color,
      endIconColor: widget.endIconColor ?? Theme.of(context).iconTheme.color,
      clockwise: widget.clockwise,
    );
  }
}

/// Animated favorite button with heart icon
class AnimatedFavoriteButton extends StatelessWidget {
  final bool isFavorite;
  final VoidCallback onToggle;
  final double size;
  final Color? favoriteColor;
  final Color? unfavoriteColor;

  const AnimatedFavoriteButton({
    super.key,
    required this.isFavorite,
    required this.onToggle,
    this.size = 24.0,
    this.favoriteColor,
    this.unfavoriteColor,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedIconButton(
      startIcon: IconlyLight.heart,
      endIcon: IconlyBold.heart,
      size: size,
      startIconColor: unfavoriteColor ?? Colors.grey,
      endIconColor: favoriteColor ?? Colors.red,
      onStartIconPress: onToggle,
      onEndIconPress: onToggle,
      startTooltip: 'Add to favorites',
      endTooltip: 'Remove from favorites',
    );
  }
}

/// Animated bookmark button
class AnimatedBookmarkButton extends StatelessWidget {
  final bool isBookmarked;
  final VoidCallback onToggle;
  final double size;
  final Color? bookmarkedColor;
  final Color? unbookmarkedColor;

  const AnimatedBookmarkButton({
    super.key,
    required this.isBookmarked,
    required this.onToggle,
    this.size = 24.0,
    this.bookmarkedColor,
    this.unbookmarkedColor,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedIconButton(
      startIcon: IconlyLight.bookmark,
      endIcon: IconlyBold.bookmark,
      size: size,
      startIconColor: unbookmarkedColor ?? Colors.grey,
      endIconColor: bookmarkedColor ?? const Color(0xFFFF6B35),
      onStartIconPress: onToggle,
      onEndIconPress: onToggle,
      startTooltip: 'Bookmark',
      endTooltip: 'Remove bookmark',
    );
  }
}

/// Animated notification button
class AnimatedNotificationButton extends StatelessWidget {
  final bool hasNotifications;
  final VoidCallback onTap;
  final double size;
  final int? notificationCount;

  const AnimatedNotificationButton({
    super.key,
    required this.hasNotifications,
    required this.onTap,
    this.size = 24.0,
    this.notificationCount,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        AnimatedIconButton(
          startIcon: IconlyLight.notification,
          endIcon: IconlyBold.notification,
          size: size,
          startIconColor: Colors.white,
          endIconColor: Colors.white,
          onStartIconPress: onTap,
          onEndIconPress: onTap,
          startTooltip: 'Notifications',
          endTooltip: 'Notifications',
        ),
        if (hasNotifications && notificationCount != null && notificationCount! > 0)
          Positioned(
            right: -6,
            top: -6,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Colors.red,
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
      ],
    );
  }
}

/// Animated play/pause button
class AnimatedPlayPauseButton extends StatelessWidget {
  final bool isPlaying;
  final VoidCallback onToggle;
  final double size;
  final Color? color;

  const AnimatedPlayPauseButton({
    super.key,
    required this.isPlaying,
    required this.onToggle,
    this.size = 32.0,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedIconButton(
      startIcon: IconlyBold.play,
      endIcon: IconlyBold.video,
      size: size,
      startIconColor: color ?? Colors.white,
      endIconColor: color ?? Colors.white,
      onStartIconPress: onToggle,
      onEndIconPress: onToggle,
      startTooltip: 'Play',
      endTooltip: 'Pause',
    );
  }
}

/// Animated search button that expands
class AnimatedSearchButton extends StatelessWidget {
  final bool isExpanded;
  final VoidCallback onToggle;
  final double size;

  const AnimatedSearchButton({
    super.key,
    required this.isExpanded,
    required this.onToggle,
    this.size = 24.0,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedIconButton(
      startIcon: IconlyLight.search,
      endIcon: IconlyBold.search,
      size: size,
      startIconColor: Colors.grey[600],
      endIconColor: const Color(0xFFFF6B35),
      onStartIconPress: onToggle,
      onEndIconPress: onToggle,
      startTooltip: 'Search',
      endTooltip: 'Close search',
    );
  }
}
