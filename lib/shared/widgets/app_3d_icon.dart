import 'package:flutter/material.dart';

/// Displays a 3D icon (PNG/WebP) downloaded from IconScout Premium.
///
/// Falls back gracefully to a Material icon when the asset file has not
/// been placed yet, so the app continues to work throughout the rollout.
///
/// ## How to use
/// 1. Download your 3D icon as PNG/WebP from IconScout.
/// 2. Place it in the matching folder under `assets/icons/3d/`.
/// 3. Declare that folder in `pubspec.yaml` (see the commented section there).
/// 4. Run `flutter pub get` — the 3D icon will appear automatically.
///
/// ## Asset naming guide
/// | Location          | Folder                                                        |
/// |-------------------|---------------------------------------------------------------|
/// | Bottom nav        | assets/icons/3d/nav/icons8-*-windows-11-outline/             |
/// | Home actions      | assets/icons/3d/actions/     (add PNGs when ready)           |
/// | Auth intro        | assets/icons/3d/features/    (add PNGs when ready)           |
/// | Empty states      | assets/icons/3d/empty/       (add PNGs when ready)           |
class App3DIcon extends StatelessWidget {
  final String assetPath;
  final IconData fallbackIcon;
  final Color? fallbackColor;
  final double size;

  /// 0.0–1.0. Used to dim inactive nav icons without needing separate assets.
  final double opacity;

  const App3DIcon({
    super.key,
    required this.assetPath,
    required this.fallbackIcon,
    this.fallbackColor,
    this.size = 28,
    this.opacity = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    Widget image = Image.asset(
      assetPath,
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        return Icon(fallbackIcon, size: size * 0.875, color: fallbackColor);
      },
    );

    if (opacity < 1.0) {
      image = Opacity(opacity: opacity, child: image);
    }

    return image;
  }
}

/// Centralised paths for every 3D icon used in the app.
/// Update these if you rename or reorganise your asset files.
abstract class IconAssets {
  // ── Bottom navigation ────────────────────────────────────────────
  static const String navHome =
      'assets/icons/3d/nav/icons8-home-windows-11-outline/icons8-home-48.png';
  static const String navCommunity =
      'assets/icons/3d/nav/icons8-community-windows-11-outline/icons8-community-48.png';
  static const String navBooking =
      'assets/icons/icons8-diya-64.png';
  static const String navDonate =
      'assets/icons/3d/nav/icons8-donate-windows-11-outline/icons8-donate-48.png';
  static const String navNotification =
      'assets/icons/3d/nav/icons8-notification-windows-11-outline/icons8-notification-48.gif';
  static const String navProfile =
      'assets/icons/3d/nav/icons8-user-male-windows-11-outline/icons8-user-male-48.png';

  // ── Home quick actions ────────────────────────────────────────────
  // All action icons use the same temple icon.
  static const String actionBookDarshan =
      'assets/icons/icons8-diya-64.png';
  static const String actionFavourites =
      'assets/icons/3d/actions/book_darshan.png';
  static const String actionDonate =
      'assets/icons/3d/nav/icons8-donate-windows-11-outline/icons8-donate-48.png';
  static const String actionEvents =
      'assets/icons/3d/nav/icons8-events-windows-11-outline/icons8-events-48.png';

  // ── Auth intro features ───────────────────────────────────────────
  static const String featureTemples = 'assets/icons/3d/features/temples.png';
  static const String featureEvents = 'assets/icons/3d/features/events.png';
  static const String featureCommunity =
      'assets/icons/3d/features/community.png';

  // ── Empty states ──────────────────────────────────────────────────
  static const String emptyNoTemples = 'assets/icons/3d/empty/no_temples.png';
  static const String emptyNoSearch = 'assets/icons/3d/empty/no_search.png';
  static const String emptyNoFavorites =
      'assets/icons/3d/empty/no_favorites.png';
  static const String emptyNoBookings = 'assets/icons/3d/empty/no_bookings.png';
  static const String emptyNoDonations =
      'assets/icons/3d/empty/no_donations.png';
  static const String emptyNoNotifications =
      'assets/icons/3d/empty/no_notifications.png';
  static const String emptyOffline = 'assets/icons/3d/empty/offline.png';
}
