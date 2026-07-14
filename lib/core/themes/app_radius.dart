import 'package:flutter/material.dart';

/// Centralized border radius constants for consistent UI
class AppRadius {
  // Private constructor to prevent instantiation
  AppRadius._();

  // ============================================================================
  // RADIUS CONSTANTS
  // ============================================================================
  
  /// Extra small radius - 4.0
  static const double xs = 4.0;
  
  /// Small radius - 8.0
  static const double sm = 8.0;
  
  /// Medium radius - 12.0
  static const double md = 12.0;
  
  /// Large radius - 16.0
  static const double lg = 16.0;
  
  /// Extra large radius - 20.0
  static const double xl = 20.0;
  
  /// Pill radius - 24.0
  static const double pill = 24.0;
  
  /// Circle radius - 999.0
  static const double circle = 999.0;

  // ============================================================================
  // BORDER RADIUS HELPERS
  // ============================================================================
  
  /// Small border radius
  static BorderRadius get smallRadius => BorderRadius.circular(sm);
  
  /// Medium border radius
  static BorderRadius get mediumRadius => BorderRadius.circular(md);
  
  /// Large border radius
  static BorderRadius get largeRadius => BorderRadius.circular(lg);
  
  /// Extra large border radius
  static BorderRadius get extraLargeRadius => BorderRadius.circular(xl);
  
  /// Pill border radius
  static BorderRadius get pillRadius => BorderRadius.circular(pill);
  
  /// Circle border radius
  static BorderRadius get circleRadius => BorderRadius.circular(circle);
  
  /// Top only small radius
  static BorderRadius get topSmallRadius => const BorderRadius.vertical(
    top: Radius.circular(sm),
  );
  
  /// Top only medium radius
  static BorderRadius get topMediumRadius => const BorderRadius.vertical(
    top: Radius.circular(md),
  );
  
  /// Top only large radius
  static BorderRadius get topLargeRadius => const BorderRadius.vertical(
    top: Radius.circular(lg),
  );
  
  /// Bottom only small radius
  static BorderRadius get bottomSmallRadius => const BorderRadius.vertical(
    bottom: Radius.circular(sm),
  );
  
  /// Bottom only medium radius
  static BorderRadius get bottomMediumRadius => const BorderRadius.vertical(
    bottom: Radius.circular(md),
  );
  
  /// Bottom only large radius
  static BorderRadius get bottomLargeRadius => const BorderRadius.vertical(
    bottom: Radius.circular(lg),
  );
}
