import 'package:flutter/material.dart';

/// Centralized shadow constants for consistent elevation
class AppShadows {
  // Private constructor to prevent instantiation
  AppShadows._();

  // ============================================================================
  // SHADOW CONSTANTS
  // ============================================================================
  
  /// Small shadow for subtle elevation
  static List<BoxShadow> get small => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.05),
      blurRadius: 4,
      offset: const Offset(0, 2),
    ),
  ];
  
  /// Card shadow for standard cards
  static List<BoxShadow> get card => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.08),
      blurRadius: 10,
      offset: const Offset(0, 4),
    ),
  ];
  
  /// Medium shadow for elevated elements
  static List<BoxShadow> get medium => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.1),
      blurRadius: 15,
      offset: const Offset(0, 6),
    ),
  ];
  
  /// Large shadow for prominent elements
  static List<BoxShadow> get large => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.12),
      blurRadius: 20,
      offset: const Offset(0, 8),
    ),
  ];
  
  /// Extra large shadow for floating elements
  static List<BoxShadow> get extraLarge => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.15),
      blurRadius: 30,
      offset: const Offset(0, 12),
    ),
  ];
  
  /// High contrast shadow with visible border
  static List<BoxShadow> get highContrast => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.2),
      blurRadius: 8,
      offset: const Offset(0, 4),
    ),
  ];
  
  /// Subtle inner shadow effect
  static List<BoxShadow> get inner => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.03),
      blurRadius: 4,
      offset: const Offset(0, 2),
      spreadRadius: -2,
    ),
  ];
  
  /// No shadow
  static List<BoxShadow> get none => [];
}
