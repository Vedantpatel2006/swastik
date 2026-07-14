import 'package:flutter/material.dart';
import 'package:swastik/core/themes/app_colors.dart';
import 'app_3d_icon.dart';

/// Reusable empty state widget for consistent UI across the app
class EmptyStateWidget extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color? iconColor;
  final VoidCallback? onAction;
  final String? actionText;
  final Widget? customAction;
  final EdgeInsets? padding;

  /// Optional path to a 3D icon asset (PNG/WebP from IconScout).
  /// When provided the 3D image is shown; falls back to [icon] if not found.
  final String? imagePath;

  const EmptyStateWidget({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.iconColor,
    this.onAction,
    this.actionText,
    this.customAction,
    this.padding,
    this.imagePath,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ?? const EdgeInsets.all(32),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (imagePath != null)
              App3DIcon(
                assetPath: imagePath!,
                fallbackIcon: icon,
                fallbackColor: iconColor ?? Colors.grey[400],
                size: 96,
              )
            else
              Icon(icon, size: 80, color: iconColor ?? Colors.grey[400]),
            const SizedBox(height: 24),
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1F2937),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            if (customAction != null) ...[
              const SizedBox(height: 32),
              customAction!,
            ] else if (onAction != null && actionText != null) ...[
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: onAction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryOrange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  actionText!,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Predefined empty states for common scenarios
class EmptyStates {
  static Widget noTemples({VoidCallback? onRefresh}) {
    return EmptyStateWidget(
      title: 'No Temples Found',
      subtitle:
          'We couldn\'t find any temples matching your criteria. Try adjusting your search or filters.',
      icon: Icons.temple_hindu,
      iconColor: Colors.orange[300],
      imagePath: IconAssets.emptyNoTemples,
      onAction: onRefresh,
      actionText: onRefresh != null ? 'Refresh' : null,
    );
  }

  static Widget noSearchResults({VoidCallback? onClearSearch}) {
    return EmptyStateWidget(
      title: 'No Search Results',
      subtitle:
          'We couldn\'t find any temples matching your search. Try different keywords or clear your search.',
      icon: Icons.search_off,
      iconColor: Colors.grey[400],
      imagePath: IconAssets.emptyNoSearch,
      onAction: onClearSearch,
      actionText: onClearSearch != null ? 'Clear Search' : null,
    );
  }

  static Widget noFavorites({VoidCallback? onExplore}) {
    return EmptyStateWidget(
      title: 'No Favorite Temples',
      subtitle:
          'You haven\'t added any temples to your favorites yet. Explore temples and tap the heart icon to save them.',
      icon: Icons.favorite_border,
      iconColor: Colors.red[300],
      imagePath: IconAssets.emptyNoFavorites,
      onAction: onExplore,
      actionText: onExplore != null ? 'Explore Temples' : null,
    );
  }

  static Widget noBookings({VoidCallback? onBookNow}) {
    return EmptyStateWidget(
      title: 'No Bookings',
      subtitle:
          'You don\'t have any temple bookings yet. Book a visit or puja to get started.',
      icon: Icons.event_available,
      iconColor: Colors.orange[300],
      imagePath: IconAssets.emptyNoBookings,
      onAction: onBookNow,
      actionText: onBookNow != null ? 'Book Now' : null,
    );
  }

  static Widget noDonations({VoidCallback? onDonate}) {
    return EmptyStateWidget(
      title: 'No Donations',
      subtitle:
          'You haven\'t made any donations yet. Support your favorite temples with a contribution.',
      icon: Icons.volunteer_activism,
      iconColor: Colors.green[300],
      imagePath: IconAssets.emptyNoDonations,
      onAction: onDonate,
      actionText: onDonate != null ? 'Donate Now' : null,
    );
  }

  static Widget noNotifications() {
    return const EmptyStateWidget(
      title: 'No Notifications',
      subtitle:
          'You\'re all caught up! We\'ll notify you about temple updates, events, and more.',
      icon: Icons.notifications_none,
      imagePath: IconAssets.emptyNoNotifications,
    );
  }

  static Widget offline({VoidCallback? onRetry}) {
    return EmptyStateWidget(
      title: 'You\'re Offline',
      subtitle: 'Please check your internet connection and try again.',
      icon: Icons.wifi_off,
      iconColor: Colors.orange[400],
      imagePath: IconAssets.emptyOffline,
      onAction: onRetry,
      actionText: onRetry != null ? 'Try Again' : null,
    );
  }
}
