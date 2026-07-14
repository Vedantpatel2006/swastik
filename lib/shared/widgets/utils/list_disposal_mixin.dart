import 'dart:async';
import 'package:flutter/material.dart';

/// Mixin to help with proper disposal of list-related resources
mixin ListDisposalMixin<T extends StatefulWidget> on State<T> {
  final List<ScrollController> _scrollControllers = [];
  final List<AnimationController> _animationControllers = [];
  final List<VoidCallback> _listeners = [];
  final Map<String, dynamic> _resources = {};

  /// Register a scroll controller for automatic disposal
  void registerScrollController(ScrollController controller) {
    _scrollControllers.add(controller);
  }

  /// Register an animation controller for automatic disposal
  void registerAnimationController(AnimationController controller) {
    _animationControllers.add(controller);
  }

  /// Register a listener for automatic removal
  void registerListener(VoidCallback listener) {
    _listeners.add(listener);
  }

  /// Register any resource with a dispose method
  void registerResource(String key, dynamic resource) {
    _resources[key] = resource;
  }

  /// Unregister a resource
  void unregisterResource(String key) {
    _resources.remove(key);
  }

  /// Clear all cached data
  void clearCache() {
    // Override in subclasses to clear specific caches
  }

  @override
  void dispose() {
    // Dispose scroll controllers
    for (final controller in _scrollControllers) {
      try {
        controller.dispose();
      } catch (e) {
        debugPrint('Error disposing scroll controller: $e');
      }
    }
    _scrollControllers.clear();

    // Dispose animation controllers
    for (final controller in _animationControllers) {
      try {
        controller.dispose();
      } catch (e) {
        debugPrint('Error disposing animation controller: $e');
      }
    }
    _animationControllers.clear();

    // Remove listeners
    _listeners.clear();

    // Dispose registered resources
    for (final entry in _resources.entries) {
      try {
        final resource = entry.value;
        if (resource is ChangeNotifier) {
          resource.dispose();
        } else if (resource is StreamController) {
          resource.close();
        } else if (resource is Stream) {
          // Streams don't need explicit disposal
        } else if (resource?.dispose != null) {
          resource.dispose();
        }
      } catch (e) {
        debugPrint('Error disposing resource ${entry.key}: $e');
      }
    }
    _resources.clear();

    // Clear any caches
    clearCache();

    super.dispose();
  }
}

/// Utility class for managing list item lifecycle
class ListItemLifecycleManager {
  static final Map<String, Set<String>> _activeItems = {};
  static final Map<String, DateTime> _lastAccessed = {};

  /// Mark an item as active
  static void markItemActive(String listId, String itemId) {
    _activeItems.putIfAbsent(listId, () => <String>{}).add(itemId);
    _lastAccessed['${listId}_$itemId'] = DateTime.now();
  }

  /// Mark an item as inactive
  static void markItemInactive(String listId, String itemId) {
    _activeItems[listId]?.remove(itemId);
    _lastAccessed.remove('${listId}_$itemId');
  }

  /// Get active items for a list
  static Set<String> getActiveItems(String listId) {
    return _activeItems[listId] ?? <String>{};
  }

  /// Clean up old items (call periodically)
  static void cleanupOldItems({Duration maxAge = const Duration(minutes: 5)}) {
    final now = DateTime.now();
    final keysToRemove = <String>[];

    for (final entry in _lastAccessed.entries) {
      if (now.difference(entry.value) > maxAge) {
        keysToRemove.add(entry.key);
      }
    }

    for (final key in keysToRemove) {
      _lastAccessed.remove(key);
      final parts = key.split('_');
      if (parts.length >= 2) {
        final listId = parts[0];
        final itemId = parts.sublist(1).join('_');
        _activeItems[listId]?.remove(itemId);
      }
    }

    // Remove empty list entries
    _activeItems.removeWhere((key, value) => value.isEmpty);
  }

  /// Clear all tracking data
  static void clearAll() {
    _activeItems.clear();
    _lastAccessed.clear();
  }
}

/// Widget that automatically manages its lifecycle in lists
abstract class ManagedListItem extends StatefulWidget {
  final String listId;
  final String itemId;

  const ManagedListItem({
    super.key,
    required this.listId,
    required this.itemId,
  });
}

abstract class ManagedListItemState<T extends ManagedListItem> extends State<T>
    with ListDisposalMixin {
  @override
  void initState() {
    super.initState();
    ListItemLifecycleManager.markItemActive(widget.listId, widget.itemId);
  }

  @override
  void dispose() {
    ListItemLifecycleManager.markItemInactive(widget.listId, widget.itemId);
    super.dispose();
  }
}

/// Mixin for widgets that contain lists with images
mixin ImageListOptimizationMixin<T extends StatefulWidget> on State<T> {
  final Map<String, Image> _imageCache = {};
  static const int _maxCacheSize = 50;

  /// Cache an image widget
  void cacheImage(String key, Image image) {
    if (_imageCache.length >= _maxCacheSize) {
      // Remove oldest entries
      final keys = _imageCache.keys.take(_maxCacheSize ~/ 2).toList();
      for (final key in keys) {
        _imageCache.remove(key);
      }
    }
    _imageCache[key] = image;
  }

  /// Get cached image
  Image? getCachedImage(String key) {
    return _imageCache[key];
  }

  /// Clear image cache
  void clearImageCache() {
    _imageCache.clear();
  }

  @override
  void dispose() {
    clearImageCache();
    super.dispose();
  }
}
