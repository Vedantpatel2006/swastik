import 'package:flutter/material.dart';

/// Centralized spacing constants for consistent layout
class AppSpacing {
  // Private constructor to prevent instantiation
  AppSpacing._();

  // ============================================================================
  // SPACING CONSTANTS
  // ============================================================================
  
  /// Extra small spacing - 4.0
  static const double xs = 4.0;
  
  /// Small spacing - 8.0
  static const double sm = 8.0;
  
  /// Medium spacing - 12.0
  static const double md = 12.0;
  
  /// Large spacing - 16.0
  static const double lg = 16.0;
  
  /// Extra large spacing - 20.0
  static const double xl = 20.0;
  
  /// Extra extra large spacing - 24.0
  static const double xxl = 24.0;
  
  /// Extra extra extra large spacing - 32.0
  static const double xxxl = 32.0;
  
  /// Huge spacing - 48.0
  static const double huge = 48.0;

  // ============================================================================
  // EDGE INSETS HELPERS
  // ============================================================================
  
  /// All sides extra small padding
  static const EdgeInsets allXs = EdgeInsets.all(xs);
  
  /// All sides small padding
  static const EdgeInsets allSm = EdgeInsets.all(sm);
  
  /// All sides medium padding
  static const EdgeInsets allMd = EdgeInsets.all(md);
  
  /// All sides large padding
  static const EdgeInsets allLg = EdgeInsets.all(lg);
  
  /// All sides extra large padding
  static const EdgeInsets allXl = EdgeInsets.all(xl);
  
  /// All sides extra extra large padding
  static const EdgeInsets allXxl = EdgeInsets.all(xxl);
  
  /// Horizontal small padding
  static const EdgeInsets horizontalSm = EdgeInsets.symmetric(horizontal: sm);
  
  /// Horizontal medium padding
  static const EdgeInsets horizontalMd = EdgeInsets.symmetric(horizontal: md);
  
  /// Horizontal large padding
  static const EdgeInsets horizontalLg = EdgeInsets.symmetric(horizontal: lg);
  
  /// Horizontal extra large padding
  static const EdgeInsets horizontalXl = EdgeInsets.symmetric(horizontal: xl);
  
  /// Vertical small padding
  static const EdgeInsets verticalSm = EdgeInsets.symmetric(vertical: sm);
  
  /// Vertical medium padding
  static const EdgeInsets verticalMd = EdgeInsets.symmetric(vertical: md);
  
  /// Vertical large padding
  static const EdgeInsets verticalLg = EdgeInsets.symmetric(vertical: lg);
  
  /// Vertical extra large padding
  static const EdgeInsets verticalXl = EdgeInsets.symmetric(vertical: xl);

  // ============================================================================
  // SIZED BOX HELPERS
  // ============================================================================
  
  /// Vertical gap extra small
  static const SizedBox gapXs = SizedBox(height: xs);
  
  /// Vertical gap small
  static const SizedBox gapSm = SizedBox(height: sm);
  
  /// Vertical gap medium
  static const SizedBox gapMd = SizedBox(height: md);
  
  /// Vertical gap large
  static const SizedBox gapLg = SizedBox(height: lg);
  
  /// Vertical gap extra large
  static const SizedBox gapXl = SizedBox(height: xl);
  
  /// Vertical gap extra extra large
  static const SizedBox gapXxl = SizedBox(height: xxl);
  
  // Aliases for consistency with existing code
  /// Alias for gapMd
  static const SizedBox verticalSpaceMedium = gapMd;

  /// Alias for gapSm
  static const SizedBox verticalSpaceSmall = gapSm;
  
  /// Horizontal gap extra small
  static const SizedBox gapHorizontalXs = SizedBox(width: xs);
  
  /// Horizontal gap small
  static const SizedBox gapHorizontalSm = SizedBox(width: sm);
  
  /// Horizontal gap medium
  static const SizedBox gapHorizontalMd = SizedBox(width: md);
  
  /// Horizontal gap large
  static const SizedBox gapHorizontalLg = SizedBox(width: lg);
  
  /// Horizontal gap extra large
  static const SizedBox gapHorizontalXl = SizedBox(width: xl);
}
