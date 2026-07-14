import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:iconly/iconly.dart';
import '../../../shared/models/temple.dart';
import '../../../core/services/accessibility_service.dart';
import '../../../shared/widgets/animations/favorite_animations.dart';
import '../../../shared/widgets/loading/skeleton_loader.dart';

/// Optimized temple image section widget
/// Separated from TempleCard to improve performance and reusability
class TempleImageSection extends StatelessWidget {
  final Temple temple;
  final bool showLiveIndicator;
  final bool showFavoriteButton;
  final bool isLive;
  final dynamic currentLiveDarshanInfo;
  final AnimationController? liveIndicatorController;
  final AnimationController? favoriteController;
  final VoidCallback? onLiveDarshanTap;
  final VoidCallback? onFavoriteToggle;

  const TempleImageSection({
    super.key,
    required this.temple,
    required this.showLiveIndicator,
    required this.showFavoriteButton,
    required this.isLive,
    this.currentLiveDarshanInfo,
    this.liveIndicatorController,
    this.favoriteController,
    this.onLiveDarshanTap,
    this.onFavoriteToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        TempleImageWidget(temple: temple),
        if (showLiveIndicator && isLive)
          LiveIndicatorWidget(
            currentLiveDarshanInfo: currentLiveDarshanInfo,
            liveIndicatorController: liveIndicatorController,
            onLiveDarshanTap: onLiveDarshanTap,
          ),
        if (showLiveIndicator &&
            !isLive &&
            currentLiveDarshanInfo?.isConfiguredByAdmin == true)
          DarshanIndicatorWidget(onLiveDarshanTap: onLiveDarshanTap),
        if (showFavoriteButton)
          TempleFavoriteButton(
            temple: temple,
            onFavoriteToggle: onFavoriteToggle,
          ),
      ],
    );
  }
}

/// Optimized temple image widget
class TempleImageWidget extends StatelessWidget {
  final Temple temple;

  const TempleImageWidget({super.key, required this.temple});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Temple image: ${temple.name}',
      image: true,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: AspectRatio(
          aspectRatio: 4 / 3,
          child: temple.images.isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: temple.images.first,
                  fit: BoxFit.cover,
                  memCacheWidth: 400,
                  memCacheHeight: 225,
                  maxWidthDiskCache: 800,
                  maxHeightDiskCache: 450,
                  placeholder: (context, url) => const TempleImagePlaceholder(),
                  errorWidget: (context, url, error) {
                    debugPrint('Image load error for ${temple.name}: $error');
                    debugPrint('Image URL: ${temple.images.first}');
                    return const TempleImageError();
                  },
                  httpHeaders: const {'Accept': 'image/*'},
                )
              : const TempleImageDefault(),
        ),
      ),
    );
  }
}

/// Optimized temple image placeholder widget
class TempleImagePlaceholder extends StatelessWidget {
  const TempleImagePlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading temple image',
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [const Color(0xFFE0E0E0), const Color(0xFFF5F5F5)],
            stops: const [0.0, 1.0],
          ),
        ),
        child: const SkeletonWidget(height: double.infinity, showShimmer: true,
        ),
      ),
    );
  }
}

/// Optimized temple image error widget
class TempleImageError extends StatelessWidget {
  const TempleImageError({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Temple image not available',
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [const Color(0xFFFFF8F0), const Color(0xFFFFE4CC)],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              IconlyBold.home,
              size: 64,
              color: const Color(0xFFFF6B35).withValues(alpha: 0.5),
            ),
            const SizedBox(height: 8),
            Text(
              'Image not available',
              style: TextStyle(color: const Color(0xFF6B7280), fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

/// Optimized temple image default widget
class TempleImageDefault extends StatelessWidget {
  const TempleImageDefault({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Default temple icon',
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [const Color(0xFFFFF8F0), const Color(0xFFFFE4CC)],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              IconlyBold.home,
              size: 64,
              color: const Color(0xFFFF6B35).withValues(alpha: 0.6),
            ),
            const SizedBox(height: 8),
            Text(
              'No image',
              style: TextStyle(color: const Color(0xFF6B7280), fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

/// Optimized live indicator widget
class LiveIndicatorWidget extends StatelessWidget {
  final dynamic currentLiveDarshanInfo;
  final AnimationController? liveIndicatorController;
  final VoidCallback? onLiveDarshanTap;

  const LiveIndicatorWidget({
    super.key,
    this.currentLiveDarshanInfo,
    this.liveIndicatorController,
    this.onLiveDarshanTap,
  });

  @override
  Widget build(BuildContext context) {
    final indicator = Positioned(
      top: 8,
      left: 8,
      child: Semantics(
        label: 'Live darshan available. Tap to watch live stream.',
        liveRegion: true,
        button: onLiveDarshanTap != null,
        onTap: onLiveDarshanTap != null
            ? () {
                AccessibilityService.instance.provideAccessibleHapticFeedback(
                  context,
                  type: 'lightImpact',
                );
                onLiveDarshanTap!();
              }
            : null,
        child: AnimatedBuilder(
          animation: liveIndicatorController ?? kAlwaysCompleteAnimation,
          builder: (context, child) {
            final controller =
                liveIndicatorController ?? kAlwaysCompleteAnimation;
            final pulseAnimation = Tween<double>(begin: 0.9, end: 1.1).animate(
              CurvedAnimation(parent: controller, curve: Curves.easeInOut),
            );

            final glowAnimation = Tween<double>(begin: 0.3, end: 0.7).animate(
              CurvedAnimation(parent: controller, curve: Curves.easeInOut),
            );

            return Transform.scale(
              scale: pulseAnimation.value,
              child: LiveIndicatorContainer(
                glowAnimation: glowAnimation,
                pulseAnimation: pulseAnimation,
                currentLiveDarshanInfo: currentLiveDarshanInfo,
              ),
            );
          },
        ),
      ),
    );

    if (onLiveDarshanTap == null) {
      return indicator;
    }

    return Positioned(
      top: 8,
      left: 8,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          AccessibilityService.instance.provideAccessibleHapticFeedback(
            context,
            type: 'lightImpact',
          );
          onLiveDarshanTap!();
        },
        child: Semantics(
          label: 'Live darshan available. Tap to watch live stream.',
          liveRegion: true,
          button: true,
          child: AnimatedBuilder(
            animation: liveIndicatorController ?? kAlwaysCompleteAnimation,
            builder: (context, child) {
              final controller =
                  liveIndicatorController ?? kAlwaysCompleteAnimation;
              final pulseAnimation = Tween<double>(begin: 0.9, end: 1.1)
                  .animate(
                    CurvedAnimation(
                      parent: controller,
                      curve: Curves.easeInOut,
                    ),
                  );

              final glowAnimation = Tween<double>(begin: 0.3, end: 0.7).animate(
                CurvedAnimation(parent: controller, curve: Curves.easeInOut),
              );

              return Transform.scale(
                scale: pulseAnimation.value,
                child: LiveIndicatorContainer(
                  glowAnimation: glowAnimation,
                  pulseAnimation: pulseAnimation,
                  currentLiveDarshanInfo: currentLiveDarshanInfo,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Optimized live indicator container widget
class LiveIndicatorContainer extends StatelessWidget {
  final Animation<double> glowAnimation;
  final Animation<double> pulseAnimation;
  final dynamic currentLiveDarshanInfo;

  const LiveIndicatorContainer({
    super.key,
    required this.glowAnimation,
    required this.pulseAnimation,
    this.currentLiveDarshanInfo,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF4444), Color(0xFFCC0000)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withValues(alpha: glowAnimation.value),
            blurRadius: 12 * pulseAnimation.value,
            spreadRadius: 3 * pulseAnimation.value,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const LiveIndicatorDot(),
          const SizedBox(width: 6),
          const LiveIndicatorText(),
          if (currentLiveDarshanInfo?.currentViewerCount != null) ...[
            const SizedBox(width: 6),
            LiveIndicatorViewerCount(
              viewerCount: currentLiveDarshanInfo!.currentViewerCount,
            ),
          ],
        ],
      ),
    );
  }
}

/// Optimized live indicator dot widget
class LiveIndicatorDot extends StatelessWidget {
  const LiveIndicatorDot({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
    );
  }
}

/// Optimized live indicator text widget
class LiveIndicatorText extends StatelessWidget {
  const LiveIndicatorText({super.key});

  @override
  Widget build(BuildContext context) {
    return const Text(
      'LIVE',
      style: TextStyle(
        color: Colors.white,
        fontSize: 11,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.5,
      ),
    );
  }
}

/// Optimized live indicator viewer count widget
class LiveIndicatorViewerCount extends StatelessWidget {
  final int viewerCount;

  const LiveIndicatorViewerCount({super.key, required this.viewerCount});

  @override
  Widget build(BuildContext context) {
    return Text(
      '$viewerCount',
      style: const TextStyle(
        color: Colors.white,
        fontSize: 9,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

/// Optimized darshan indicator widget
class DarshanIndicatorWidget extends StatelessWidget {
  final VoidCallback? onLiveDarshanTap;

  const DarshanIndicatorWidget({super.key, this.onLiveDarshanTap});

  @override
  Widget build(BuildContext context) {
    final indicator = Positioned(
      top: 8,
      left: 8,
      child: Semantics(
        label: 'Live darshan available. Tap to view schedule.',
        button: onLiveDarshanTap != null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.grey[700]?.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const DarshanIndicatorContent(),
        ),
      ),
    );

    if (onLiveDarshanTap == null) {
      return indicator;
    }

    return Positioned(
      top: 8,
      left: 8,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          AccessibilityService.instance.provideAccessibleHapticFeedback(
            context,
            type: 'lightImpact',
          );
          onLiveDarshanTap!();
        },
        child: Semantics(
          label: 'Live darshan available. Tap to view schedule.',
          button: true,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey[700]?.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const DarshanIndicatorContent(),
          ),
        ),
      ),
    );
  }
}

/// Optimized darshan indicator content widget
class DarshanIndicatorContent extends StatelessWidget {
  const DarshanIndicatorContent({super.key});

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(IconlyBold.video, color: Colors.white, size: 12),
        SizedBox(width: 4),
        Text(
          'DARSHAN',
          style: TextStyle(
            color: Colors.white,
            fontSize: 9,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

/// Optimized favorite button widget for temple images
class TempleFavoriteButton extends StatelessWidget {
  final Temple temple;
  final VoidCallback? onFavoriteToggle;

  const TempleFavoriteButton({
    super.key,
    required this.temple,
    this.onFavoriteToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 8,
      right: 8,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.9),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: FavoriteAnimations.floatingHeartAnimation(
          trigger: temple.isFavorite,
          child: FavoriteAnimations.animatedFavoriteButton(
            isFavorite: temple.isFavorite,
            onTap: () {
              AccessibilityService.instance.provideAccessibleHapticFeedback(
                context,
                type: 'selectionClick',
              );
              onFavoriteToggle?.call();
            },
            size: 20,
            favoriteColor: Colors.red,
            unfavoriteColor: Theme.of(context).iconTheme.color ?? Colors.grey,
          ),
        ),
      ),
    );
  }
}
