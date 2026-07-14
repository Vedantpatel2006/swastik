import 'package:flutter/material.dart';
import 'package:iconly/iconly.dart';

/// Centralized icon constants for the app using Iconly icons
/// This provides a consistent icon system across the entire application
class AppIcons {
  AppIcons._();

  // Navigation Icons
  static const IconData home = IconlyBold.home;
  static const IconData search = IconlyBold.search;
  static const IconData location = IconlyBold.location;
  static const IconData notification = IconlyBold.notification;
  static const IconData profile = IconlyBold.profile;
  static const IconData setting = IconlyBold.setting;

  // Temple Related Icons
  static const IconData star = IconlyBold.star;
  static const IconData heart = IconlyBold.heart;
  static const IconData bookmark = IconlyBold.bookmark;
  static const IconData calendar = IconlyBold.calendar;
  static const IconData camera = IconlyBold.camera;
  static const IconData video = IconlyBold.video;
  static const IconData image = IconlyBold.image;

  // Action Icons
  static const IconData filter = IconlyBold.filter;
  static const IconData delete = IconlyBold.delete;
  static const IconData edit = IconlyBold.edit;
  static const IconData send = IconlyBold.send;
  static const IconData download = IconlyBold.download;
  static const IconData upload = IconlyBold.upload;

  // UI Icons
  static const IconData category = IconlyBold.category;
  static const IconData document = IconlyBold.document;
  static const IconData folder = IconlyBold.folder;
  static const IconData chart = IconlyBold.chart;
  static const IconData graph = IconlyBold.graph;
  static const IconData buy = IconlyBold.buy;
  static const IconData wallet = IconlyBold.wallet;

  // Communication Icons
  static const IconData call = IconlyBold.call;
  static const IconData message = IconlyBold.message;
  static const IconData chat = IconlyBold.chat;

  // Media Icons
  static const IconData play = IconlyBold.play;
  static const IconData videoIcon = IconlyBold.video;

  // Status Icons
  static const IconData tick = IconlyBold.show;
  static const IconData close = IconlyBold.delete;
  static const IconData danger = IconlyBold.danger;

  // Light variants (for outlined icons)
  static const IconData homeLight = IconlyLight.home;
  static const IconData searchLight = IconlyLight.search;
  static const IconData locationLight = IconlyLight.location;
  static const IconData notificationLight = IconlyLight.notification;
  static const IconData profileLight = IconlyLight.profile;
  static const IconData settingLight = IconlyLight.setting;
  static const IconData starLight = IconlyLight.star;
  static const IconData heartLight = IconlyLight.heart;
  static const IconData bookmarkLight = IconlyLight.bookmark;

  // Broken variants (for partially outlined icons)
  static const IconData homeBroken = IconlyBroken.home;
  static const IconData searchBroken = IconlyBroken.search;
  static const IconData locationBroken = IconlyBroken.location;
  static const IconData notificationBroken = IconlyBroken.notification;
  static const IconData profileBroken = IconlyBroken.profile;
  static const IconData settingBroken = IconlyBroken.setting;
}

/// Icon size constants
class AppIconSizes {
  AppIconSizes._();

  static const double small = 16.0;
  static const double medium = 24.0;
  static const double large = 32.0;
  static const double extraLarge = 48.0;
  static const double huge = 64.0;
}

/// Helper class for animated icon pairs
class AnimatedIconPairs {
  AnimatedIconPairs._();

  // Filter animation
  static const IconData filterStart = IconlyBold.filter;
  static const IconData filterEnd = IconlyBold.setting;

  // Favorite animation
  static const IconData favoriteStart = IconlyLight.heart;
  static const IconData favoriteEnd = IconlyBold.heart;

  // Bookmark animation
  static const IconData bookmarkStart = IconlyLight.bookmark;
  static const IconData bookmarkEnd = IconlyBold.bookmark;

  // Notification animation
  static const IconData notificationStart = IconlyLight.notification;
  static const IconData notificationEnd = IconlyBold.notification;

  // Search animation
  static const IconData searchStart = IconlyLight.search;
  static const IconData searchEnd = IconlyBold.search;

  // Play/Pause animation
  static const IconData playStart = IconlyBold.play;
  static const IconData playEnd = IconlyBold.video;
}
