import 'package:flutter/material.dart';

/// Advanced scroll physics for nested lists and complex scroll scenarios
class AdvancedScrollPhysics extends ScrollPhysics {
  final bool enableBouncing;
  final bool enableOverscroll;
  final double friction;
  final double springTension;
  final double springDamping;

  const AdvancedScrollPhysics({
    super.parent,
    this.enableBouncing = true,
    this.enableOverscroll = true,
    this.friction = 0.015,
    this.springTension = 100.0,
    this.springDamping = 0.8,
  });

  @override
  AdvancedScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return AdvancedScrollPhysics(
      parent: buildParent(ancestor),
      enableBouncing: enableBouncing,
      enableOverscroll: enableOverscroll,
      friction: friction,
      springTension: springTension,
      springDamping: springDamping,
    );
  }

  @override
  SpringDescription get spring => SpringDescription(
    mass: 80,
    stiffness: springTension,
    damping: springDamping,
  );

  @override
  double get dragStartDistanceMotionThreshold => 3.5;

  @override
  double get minFlingDistance => 25.0;

  @override
  double get minFlingVelocity => 50.0;

  @override
  double get maxFlingVelocity => 8000.0;

  // Custom friction factor for overscroll control
  double frictionFactor(double overscrollFraction) {
    if (!enableOverscroll) return 0.0;
    return friction * overscrollFraction;
  }

  @override
  bool get allowImplicitScrolling => true;

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    final tolerance = toleranceFor(position);

    if (velocity.abs() < tolerance.velocity ||
        (velocity > 0.0 && position.pixels >= position.maxScrollExtent) ||
        (velocity < 0.0 && position.pixels <= position.minScrollExtent)) {
      return null;
    }

    return ClampingScrollSimulation(
      position: position.pixels,
      velocity: velocity,
      friction: friction,
      tolerance: tolerance,
    );
  }
}

/// Smooth scroll physics optimized for image-heavy lists
class ImageListScrollPhysics extends ScrollPhysics {
  const ImageListScrollPhysics({super.parent});

  @override
  ImageListScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return ImageListScrollPhysics(parent: buildParent(ancestor));
  }

  @override
  SpringDescription get spring => const SpringDescription(
    mass: 120, // Heavier for smoother scrolling with images
    stiffness: 80,
    damping: 1.0,
  );

  @override
  double get minFlingVelocity => 100.0; // Higher threshold for image lists

  @override
  double get maxFlingVelocity => 5000.0; // Lower max to prevent jarring

  // Custom friction factor for image list stability
  double frictionFactor(double overscrollFraction) {
    return 0.02 * overscrollFraction; // More friction for stability
  }
}

/// Nested scroll physics for complex scroll scenarios
class NestedScrollPhysics extends ScrollPhysics {
  final bool allowParentScrolling;
  final double parentScrollThreshold;

  const NestedScrollPhysics({
    super.parent,
    this.allowParentScrolling = true,
    this.parentScrollThreshold = 50.0,
  });

  @override
  NestedScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return NestedScrollPhysics(
      parent: buildParent(ancestor),
      allowParentScrolling: allowParentScrolling,
      parentScrollThreshold: parentScrollThreshold,
    );
  }

  @override
  bool shouldAcceptUserOffset(ScrollMetrics position) {
    if (!allowParentScrolling) return super.shouldAcceptUserOffset(position);

    // Allow parent scrolling when at boundaries
    if (position.pixels <= position.minScrollExtent + parentScrollThreshold ||
        position.pixels >= position.maxScrollExtent - parentScrollThreshold) {
      return false;
    }

    return super.shouldAcceptUserOffset(position);
  }

  @override
  double applyPhysicsToUserOffset(ScrollMetrics position, double offset) {
    if (!allowParentScrolling)
      return super.applyPhysicsToUserOffset(position, offset);

    // Reduce scroll sensitivity near boundaries
    if (position.pixels <= position.minScrollExtent + parentScrollThreshold ||
        position.pixels >= position.maxScrollExtent - parentScrollThreshold) {
      return offset * 0.5;
    }

    return super.applyPhysicsToUserOffset(position, offset);
  }
}

/// Optimized scroll physics for large datasets
class LargeDatasetScrollPhysics extends ScrollPhysics {
  final int itemCount;
  final double averageItemHeight;

  const LargeDatasetScrollPhysics({
    super.parent,
    required this.itemCount,
    this.averageItemHeight = 100.0,
  });

  @override
  LargeDatasetScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return LargeDatasetScrollPhysics(
      parent: buildParent(ancestor),
      itemCount: itemCount,
      averageItemHeight: averageItemHeight,
    );
  }

  @override
  SpringDescription get spring {
    // Adjust spring based on dataset size
    final mass = (itemCount / 1000).clamp(50.0, 200.0);
    return SpringDescription(mass: mass, stiffness: 100.0, damping: 0.9);
  }

  @override
  double get minFlingVelocity {
    // Higher threshold for large datasets to prevent excessive scrolling
    return (itemCount / 100).clamp(50.0, 200.0);
  }

  @override
  double get maxFlingVelocity {
    // Lower max velocity for large datasets
    return (10000 - (itemCount / 10)).clamp(3000.0, 8000.0);
  }

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    final tolerance = toleranceFor(position);

    if (velocity.abs() < tolerance.velocity) return null;

    // Use custom simulation for large datasets
    return _LargeDatasetScrollSimulation(
      position: position.pixels,
      velocity: velocity,
      itemCount: itemCount,
      averageItemHeight: averageItemHeight,
      tolerance: tolerance,
    );
  }
}

/// Custom scroll simulation for large datasets
class _LargeDatasetScrollSimulation extends Simulation {
  final double _position;
  final double _velocity;
  final int _itemCount;
  final Tolerance _tolerance;

  _LargeDatasetScrollSimulation({
    required double position,
    required double velocity,
    required int itemCount,
    required double averageItemHeight,
    required Tolerance tolerance,
  }) : _position = position,
       _velocity = velocity,
       _itemCount = itemCount,
       _tolerance = tolerance;

  @override
  double x(double time) {
    // Implement smooth deceleration
    final friction = 0.015 * (_itemCount / 1000).clamp(1.0, 3.0);
    return _position + _velocity * time * (1 - friction * time);
  }

  @override
  double dx(double time) {
    final friction = 0.015 * (_itemCount / 1000).clamp(1.0, 3.0);
    return _velocity * (1 - 2 * friction * time);
  }

  @override
  bool isDone(double time) {
    return dx(time).abs() < _tolerance.velocity;
  }
}

/// Scroll physics factory for different use cases
class ScrollPhysicsFactory {
  /// Get optimized physics for image-heavy lists
  static ScrollPhysics imageHeavyList({ScrollPhysics? parent}) {
    return ImageListScrollPhysics(parent: parent);
  }

  /// Get optimized physics for nested scrolling
  static ScrollPhysics nestedScrolling({
    ScrollPhysics? parent,
    bool allowParentScrolling = true,
    double parentScrollThreshold = 50.0,
  }) {
    return NestedScrollPhysics(
      parent: parent,
      allowParentScrolling: allowParentScrolling,
      parentScrollThreshold: parentScrollThreshold,
    );
  }

  /// Get optimized physics for large datasets
  static ScrollPhysics largeDataset({
    ScrollPhysics? parent,
    required int itemCount,
    double averageItemHeight = 100.0,
  }) {
    return LargeDatasetScrollPhysics(
      parent: parent,
      itemCount: itemCount,
      averageItemHeight: averageItemHeight,
    );
  }

  /// Get optimized physics for complex widgets
  static ScrollPhysics complexWidgets({ScrollPhysics? parent}) {
    return AdvancedScrollPhysics(
      parent: parent,
      enableBouncing: true,
      enableOverscroll: true,
      friction: 0.02, // More friction for stability
      springTension: 80.0, // Lower tension for smoother animation
      springDamping: 1.0, // Higher damping to reduce oscillation
    );
  }

  /// Get physics based on list characteristics
  static ScrollPhysics adaptive({
    ScrollPhysics? parent,
    required int itemCount,
    bool hasImages = false,
    bool hasComplexWidgets = false,
    bool isNested = false,
  }) {
    if (itemCount > 1000) {
      return largeDataset(parent: parent, itemCount: itemCount);
    }

    if (hasImages) {
      return imageHeavyList(parent: parent);
    }

    if (hasComplexWidgets) {
      return complexWidgets(parent: parent);
    }

    if (isNested) {
      return nestedScrolling(parent: parent);
    }

    return const AlwaysScrollableScrollPhysics();
  }
}
