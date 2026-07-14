import 'package:flutter/material.dart';

/// Virtual scrolling widget for very large datasets (>1000 items)
class VirtualScrollView<T> extends StatefulWidget {
  final List<T> items;
  final Widget Function(BuildContext context, T item, int index) itemBuilder;
  final double itemHeight;
  final ScrollController? controller;
  final EdgeInsets? padding;
  final bool shrinkWrap;
  final ScrollPhysics? physics;
  final int bufferSize;
  final bool animateItems;
  final Duration animationDuration;
  final Curve animationCurve;

  const VirtualScrollView({
    super.key,
    required this.items,
    required this.itemBuilder,
    required this.itemHeight,
    this.controller,
    this.padding,
    this.shrinkWrap = false,
    this.physics,
    this.bufferSize = 10,
    this.animateItems = false,
    this.animationDuration = const Duration(milliseconds: 200),
    this.animationCurve = Curves.easeInOut,
  });

  @override
  State<VirtualScrollView<T>> createState() => _VirtualScrollViewState<T>();
}

class _VirtualScrollViewState<T> extends State<VirtualScrollView<T>>
    with TickerProviderStateMixin {
  late ScrollController _scrollController;
  int _firstVisibleIndex = 0;
  int _lastVisibleIndex = 0;
  final Map<int, Widget> _builtItems = {};
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _scrollController = widget.controller ?? ScrollController();
    _scrollController.addListener(_onScroll);

    if (widget.animateItems) {
      _animationController = AnimationController(
        duration: widget.animationDuration,
        vsync: this,
      );
    }

    _calculateVisibleRange();
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      _scrollController.dispose();
    } else {
      _scrollController.removeListener(_onScroll);
    }

    if (widget.animateItems) {
      _animationController.dispose();
    }

    _builtItems.clear();
    super.dispose();
  }

  void _onScroll() {
    _calculateVisibleRange();
  }

  void _calculateVisibleRange() {
    if (!_scrollController.hasClients) return;

    final scrollOffset = _scrollController.offset;
    final viewportHeight = _scrollController.position.viewportDimension;

    final firstIndex = (scrollOffset / widget.itemHeight).floor();
    final lastIndex = ((scrollOffset + viewportHeight) / widget.itemHeight)
        .ceil();

    final newFirstIndex = (firstIndex - widget.bufferSize).clamp(
      0,
      widget.items.length - 1,
    );
    final newLastIndex = (lastIndex + widget.bufferSize).clamp(
      0,
      widget.items.length - 1,
    );

    if (newFirstIndex != _firstVisibleIndex ||
        newLastIndex != _lastVisibleIndex) {
      setState(() {
        _firstVisibleIndex = newFirstIndex;
        _lastVisibleIndex = newLastIndex;
      });

      // Clean up items outside the visible range
      _builtItems.removeWhere(
        (index, _) => index < _firstVisibleIndex || index > _lastVisibleIndex,
      );

      if (widget.animateItems) {
        _animationController.forward(from: 0);
      }
    }
  }

  Widget _buildItem(int index) {
    if (_builtItems.containsKey(index)) {
      return _builtItems[index]!;
    }

    final item = widget.items[index];
    final builtItem = widget.itemBuilder(context, item, index);

    Widget finalItem = SizedBox(height: widget.itemHeight, child: builtItem);

    if (widget.animateItems) {
      finalItem = AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return FadeTransition(
            opacity: _animationController,
            child: SlideTransition(
              position:
                  Tween<Offset>(
                    begin: const Offset(0, 0.1),
                    end: Offset.zero,
                  ).animate(
                    CurvedAnimation(
                      parent: _animationController,
                      curve: widget.animationCurve,
                    ),
                  ),
              child: child,
            ),
          );
        },
        child: finalItem,
      );
    }

    _builtItems[index] = finalItem;
    return finalItem;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalHeight = widget.items.length * widget.itemHeight;

        return SingleChildScrollView(
          controller: _scrollController,
          physics: widget.physics,
          padding: widget.padding,
          child: SizedBox(
            height: widget.shrinkWrap ? null : totalHeight,
            child: Stack(
              children: [
                // Build only visible items
                for (
                  int i = _firstVisibleIndex;
                  i <= _lastVisibleIndex && i < widget.items.length;
                  i++
                )
                  Positioned(
                    top: i * widget.itemHeight,
                    left: 0,
                    right: 0,
                    height: widget.itemHeight,
                    child: _buildItem(i),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Advanced list view with nested scroll support and proper physics
class AdvancedListView<T> extends StatefulWidget {
  final List<T> items;
  final Widget Function(BuildContext context, T item, int index) itemBuilder;
  final ScrollController? controller;
  final EdgeInsets? padding;
  final bool shrinkWrap;
  final ScrollPhysics? physics;
  final bool enableNestedScrolling;
  final double? itemExtent;
  final Widget? separator;
  final bool reverse;
  final Axis scrollDirection;

  const AdvancedListView({
    super.key,
    required this.items,
    required this.itemBuilder,
    this.controller,
    this.padding,
    this.shrinkWrap = false,
    this.physics,
    this.enableNestedScrolling = false,
    this.itemExtent,
    this.separator,
    this.reverse = false,
    this.scrollDirection = Axis.vertical,
  });

  @override
  State<AdvancedListView<T>> createState() => _AdvancedListViewState<T>();
}

class _AdvancedListViewState<T> extends State<AdvancedListView<T>> {
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = widget.controller ?? ScrollController();
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      _scrollController.dispose();
    }
    super.dispose();
  }

  ScrollPhysics _getOptimalPhysics() {
    if (widget.physics != null) return widget.physics!;

    if (widget.enableNestedScrolling) {
      return const NeverScrollableScrollPhysics();
    }

    if (widget.shrinkWrap) {
      return const NeverScrollableScrollPhysics();
    }

    return const AlwaysScrollableScrollPhysics();
  }

  @override
  Widget build(BuildContext context) {
    Widget listView;

    if (widget.separator != null) {
      listView = ListView.separated(
        controller: _scrollController,
        padding: widget.padding,
        shrinkWrap: widget.shrinkWrap,
        physics: _getOptimalPhysics(),
        reverse: widget.reverse,
        scrollDirection: widget.scrollDirection,
        itemCount: widget.items.length,
        separatorBuilder: (context, index) => widget.separator!,
        itemBuilder: (context, index) {
          final item = widget.items[index];
          return widget.itemBuilder(context, item, index);
        },
      );
    } else {
      listView = ListView.builder(
        controller: _scrollController,
        padding: widget.padding,
        shrinkWrap: widget.shrinkWrap,
        physics: _getOptimalPhysics(),
        reverse: widget.reverse,
        scrollDirection: widget.scrollDirection,
        itemCount: widget.items.length,
        itemExtent: widget.itemExtent,
        itemBuilder: (context, index) {
          final item = widget.items[index];
          return widget.itemBuilder(context, item, index);
        },
      );
    }

    if (widget.enableNestedScrolling) {
      return NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [],
        body: listView,
      );
    }

    return listView;
  }
}

/// Item caching and recycling system for complex list items
class ListItemCache<T> {
  final Map<Type, Queue<Widget>> _recycledWidgets = {};
  final Map<String, Widget> _cachedItems = {};
  final int maxCacheSize;
  final int maxRecycleSize;

  ListItemCache({this.maxCacheSize = 100, this.maxRecycleSize = 20});

  /// Get a cached item or create a new one
  Widget getOrCreateItem<W extends Widget>(String key, W Function() creator) {
    // Try to get from cache first
    if (_cachedItems.containsKey(key)) {
      return _cachedItems[key]!;
    }

    // Try to recycle an existing widget
    final recycledQueue = _recycledWidgets[W];
    if (recycledQueue != null && recycledQueue.isNotEmpty) {
      final recycled = recycledQueue.removeFirst();
      _cachedItems[key] = recycled;
      return recycled;
    }

    // Create new widget
    final newWidget = creator();
    _cacheItem(key, newWidget);
    return newWidget;
  }

  /// Cache an item
  void _cacheItem(String key, Widget widget) {
    if (_cachedItems.length >= maxCacheSize) {
      // Remove oldest items
      final keysToRemove = _cachedItems.keys.take(maxCacheSize ~/ 4).toList();
      for (final key in keysToRemove) {
        final removed = _cachedItems.remove(key);
        if (removed != null) {
          _recycleWidget(removed);
        }
      }
    }
    _cachedItems[key] = widget;
  }

  /// Recycle a widget for reuse
  void _recycleWidget(Widget widget) {
    final type = widget.runtimeType;
    final queue = _recycledWidgets.putIfAbsent(type, () => Queue<Widget>());

    if (queue.length < maxRecycleSize) {
      queue.add(widget);
    }
  }

  /// Clear all caches
  void clear() {
    _cachedItems.clear();
    _recycledWidgets.clear();
  }

  /// Get cache statistics
  Map<String, int> getStats() {
    return {
      'cachedItems': _cachedItems.length,
      'recycledTypes': _recycledWidgets.length,
      'totalRecycled': _recycledWidgets.values.fold(
        0,
        (sum, queue) => sum + queue.length,
      ),
    };
  }
}

/// Queue implementation for widget recycling
class Queue<T> {
  final List<T> _items = [];

  void add(T item) => _items.add(item);
  T removeFirst() => _items.removeAt(0);
  bool get isNotEmpty => _items.isNotEmpty;
  int get length => _items.length;
  void clear() => _items.clear();
}

/// Efficient rendering patterns utility
class EfficientRenderingPatterns {
  /// Create a repaint boundary for expensive widgets
  static Widget withRepaintBoundary(Widget child) {
    return RepaintBoundary(child: child);
  }

  /// Create a keep alive wrapper for important widgets
  static Widget withKeepAlive(Widget child, {bool keepAlive = true}) {
    return KeepAlive(keepAlive: keepAlive, child: child);
  }

  /// Create an optimized list item with all performance enhancements
  static Widget optimizedListItem({
    required Widget child,
    bool addRepaintBoundary = true,
    bool keepAlive = false,
    String? semanticLabel,
  }) {
    Widget result = child;

    if (addRepaintBoundary) {
      result = RepaintBoundary(child: result);
    }

    if (keepAlive) {
      result = KeepAlive(keepAlive: true, child: result);
    }

    if (semanticLabel != null) {
      result = Semantics(label: semanticLabel, child: result);
    }

    return result;
  }
}

/// Keep alive wrapper widget
class KeepAlive extends StatefulWidget {
  final Widget child;
  final bool keepAlive;

  const KeepAlive({super.key, required this.child, this.keepAlive = true});

  @override
  State<KeepAlive> createState() => _KeepAliveState();
}

class _KeepAliveState extends State<KeepAlive>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => widget.keepAlive;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
