import 'package:flutter/material.dart';

/// Enhanced ListView.builder with lazy loading and memory optimization
class OptimizedListView<T> extends StatefulWidget {
  final List<T> items;
  final Widget Function(BuildContext context, T item, int index) itemBuilder;
  final ScrollController? controller;
  final EdgeInsets? padding;
  final bool shrinkWrap;
  final ScrollPhysics? physics;
  final bool enableLazyLoading;
  final double? itemExtent;
  final Widget? separator;
  final bool addAutomaticKeepAlives;
  final bool addRepaintBoundaries;
  final bool addSemanticIndexes;
  final Clip clipBehavior;
  final String? restorationId;
  final ScrollViewKeyboardDismissBehavior keyboardDismissBehavior;

  const OptimizedListView({
    super.key,
    required this.items,
    required this.itemBuilder,
    this.controller,
    this.padding,
    this.shrinkWrap = false,
    this.physics,
    this.enableLazyLoading = true,
    this.itemExtent,
    this.separator,
    this.addAutomaticKeepAlives = true,
    this.addRepaintBoundaries = true,
    this.addSemanticIndexes = true,
    this.clipBehavior = Clip.hardEdge,
    this.restorationId,
    this.keyboardDismissBehavior = ScrollViewKeyboardDismissBehavior.manual,
  });

  @override
  State<OptimizedListView<T>> createState() => _OptimizedListViewState<T>();
}

class _OptimizedListViewState<T> extends State<OptimizedListView<T>> {
  late ScrollController _scrollController;
  final Map<int, Widget> _itemCache = <int, Widget>{};

  @override
  void initState() {
    super.initState();
    _scrollController = widget.controller ?? ScrollController();
    if (widget.enableLazyLoading) {
      _scrollController.addListener(_onScroll);
    }
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      _scrollController.dispose();
    } else if (widget.enableLazyLoading) {
      _scrollController.removeListener(_onScroll);
    }
    _itemCache.clear();
    super.dispose();
  }

  void _onScroll() {
    if (!mounted) return;

    try {
      // Clear cache for items that are far from viewport to save memory
      final scrollOffset = _scrollController.offset;
      final viewportHeight = _scrollController.position.viewportDimension;
      final itemHeight = widget.itemExtent ?? 100.0; // Estimate if not provided

      final firstVisibleIndex = (scrollOffset / itemHeight).floor();
      final lastVisibleIndex = ((scrollOffset + viewportHeight) / itemHeight)
          .ceil();

      // Keep a buffer of items around the visible area
      const bufferSize = 10;
      final startIndex = (firstVisibleIndex - bufferSize).clamp(
        0,
        widget.items.length - 1,
      );
      final endIndex = (lastVisibleIndex + bufferSize).clamp(
        0,
        widget.items.length - 1,
      );

      // Remove items from cache that are outside the buffer
      _itemCache.removeWhere(
        (index, _) => index < startIndex || index > endIndex,
      );
    } catch (e) {
      // Handle scroll calculation errors gracefully
      debugPrint('Scroll calculation error: $e');
    }
  }

  Widget _buildItem(BuildContext context, int index) {
    try {
      if (widget.enableLazyLoading && _itemCache.containsKey(index)) {
        return _itemCache[index]!;
      }

      final item = widget.items[index];
      final builtItem = widget.itemBuilder(context, item, index);

      if (widget.enableLazyLoading) {
        try {
          _itemCache[index] = builtItem;
        } catch (e) {
          // Handle caching errors gracefully - continue without caching
          debugPrint('Widget caching error for index $index: $e');
        }
      }

      return builtItem;
    } catch (e) {
      // Handle widget building errors gracefully
      debugPrint('Widget building error for index $index: $e');
      return Container(
        height: 50,
        child: const Center(child: Text('Error loading item')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.separator != null) {
      return ListView.separated(
        controller: _scrollController,
        padding: widget.padding,
        shrinkWrap: widget.shrinkWrap,
        physics: widget.physics,
        itemCount: widget.items.length,
        separatorBuilder: (context, index) => widget.separator!,
        itemBuilder: (context, index) => _buildItem(context, index),
        addAutomaticKeepAlives: widget.addAutomaticKeepAlives,
        addRepaintBoundaries: widget.addRepaintBoundaries,
        addSemanticIndexes: widget.addSemanticIndexes,
        clipBehavior: widget.clipBehavior,
        restorationId: widget.restorationId,
        keyboardDismissBehavior: widget.keyboardDismissBehavior,
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: widget.padding,
      shrinkWrap: widget.shrinkWrap,
      physics: widget.physics,
      itemCount: widget.items.length,
      itemExtent: widget.itemExtent,
      itemBuilder: (context, index) => _buildItem(context, index),
      addAutomaticKeepAlives: widget.addAutomaticKeepAlives,
      addRepaintBoundaries: widget.addRepaintBoundaries,
      addSemanticIndexes: widget.addSemanticIndexes,
      clipBehavior: widget.clipBehavior,
      restorationId: widget.restorationId,
      keyboardDismissBehavior: widget.keyboardDismissBehavior,
    );
  }
}

/// Enhanced GridView.builder with lazy loading and memory optimization
class OptimizedGridView<T> extends StatefulWidget {
  final List<T> items;
  final Widget Function(BuildContext context, T item, int index) itemBuilder;
  final SliverGridDelegate gridDelegate;
  final ScrollController? controller;
  final EdgeInsets? padding;
  final bool shrinkWrap;
  final ScrollPhysics? physics;
  final bool enableLazyLoading;
  final bool addAutomaticKeepAlives;
  final bool addRepaintBoundaries;
  final bool addSemanticIndexes;
  final Clip clipBehavior;
  final String? restorationId;
  final ScrollViewKeyboardDismissBehavior keyboardDismissBehavior;

  const OptimizedGridView({
    super.key,
    required this.items,
    required this.itemBuilder,
    required this.gridDelegate,
    this.controller,
    this.padding,
    this.shrinkWrap = false,
    this.physics,
    this.enableLazyLoading = true,
    this.addAutomaticKeepAlives = true,
    this.addRepaintBoundaries = true,
    this.addSemanticIndexes = true,
    this.clipBehavior = Clip.hardEdge,
    this.restorationId,
    this.keyboardDismissBehavior = ScrollViewKeyboardDismissBehavior.manual,
  });

  @override
  State<OptimizedGridView<T>> createState() => _OptimizedGridViewState<T>();
}

class _OptimizedGridViewState<T> extends State<OptimizedGridView<T>> {
  late ScrollController _scrollController;
  final Map<int, Widget> _itemCache = <int, Widget>{};

  @override
  void initState() {
    super.initState();
    _scrollController = widget.controller ?? ScrollController();
    if (widget.enableLazyLoading) {
      _scrollController.addListener(_onScroll);
    }
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      _scrollController.dispose();
    } else if (widget.enableLazyLoading) {
      _scrollController.removeListener(_onScroll);
    }
    _itemCache.clear();
    super.dispose();
  }

  void _onScroll() {
    if (!mounted) return;

    try {
      // Clear cache for items that are far from viewport to save memory
      final scrollOffset = _scrollController.offset;
      final viewportHeight = _scrollController.position.viewportDimension;

      // Estimate visible items based on grid delegate
      int crossAxisCount = 2; // Default fallback
      if (widget.gridDelegate is SliverGridDelegateWithFixedCrossAxisCount) {
        crossAxisCount =
            (widget.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount)
                .crossAxisCount;
      }

      const estimatedItemHeight = 200.0; // Estimate
      final itemsPerScreen =
          ((viewportHeight / estimatedItemHeight).ceil() * crossAxisCount);
      final firstVisibleIndex =
          ((scrollOffset / estimatedItemHeight).floor() * crossAxisCount);

      // Keep a buffer of items around the visible area
      const bufferSize = 20;
      final startIndex = (firstVisibleIndex - bufferSize).clamp(
        0,
        widget.items.length - 1,
      );
      final endIndex = (firstVisibleIndex + itemsPerScreen + bufferSize).clamp(
        0,
        widget.items.length - 1,
      );

      // Remove items from cache that are outside the buffer
      _itemCache.removeWhere(
        (index, _) => index < startIndex || index > endIndex,
      );
    } catch (e) {
      // Handle scroll calculation errors gracefully
      debugPrint('Grid scroll calculation error: $e');
    }
  }

  Widget _buildItem(BuildContext context, int index) {
    try {
      if (widget.enableLazyLoading && _itemCache.containsKey(index)) {
        return _itemCache[index]!;
      }

      final item = widget.items[index];
      final builtItem = widget.itemBuilder(context, item, index);

      if (widget.enableLazyLoading) {
        try {
          _itemCache[index] = builtItem;
        } catch (e) {
          // Handle caching errors gracefully - continue without caching
          debugPrint('Widget caching error for index $index: $e');
        }
      }

      return builtItem;
    } catch (e) {
      // Handle widget building errors gracefully
      debugPrint('Widget building error for index $index: $e');
      return Container(
        height: 200,
        child: const Center(child: Text('Error loading item')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      controller: _scrollController,
      padding: widget.padding,
      shrinkWrap: widget.shrinkWrap,
      physics: widget.physics,
      gridDelegate: widget.gridDelegate,
      itemCount: widget.items.length,
      itemBuilder: (context, index) => _buildItem(context, index),
      addAutomaticKeepAlives: widget.addAutomaticKeepAlives,
      addRepaintBoundaries: widget.addRepaintBoundaries,
      addSemanticIndexes: widget.addSemanticIndexes,
      clipBehavior: widget.clipBehavior,
      restorationId: widget.restorationId,
      keyboardDismissBehavior: widget.keyboardDismissBehavior,
    );
  }
}

/// Utility class for list optimization configurations
class ListOptimizationConfig {
  final bool enableLazyLoading;
  final bool enableItemCaching;
  final int cacheBufferSize;
  final bool addRepaintBoundaries;
  final bool addAutomaticKeepAlives;
  final ScrollPhysics? physics;

  const ListOptimizationConfig({
    this.enableLazyLoading = true,
    this.enableItemCaching = true,
    this.cacheBufferSize = 10,
    this.addRepaintBoundaries = true,
    this.addAutomaticKeepAlives = true,
    this.physics,
  });

  /// Configuration optimized for image-heavy lists
  static const ListOptimizationConfig imageHeavy = ListOptimizationConfig(
    enableLazyLoading: true,
    enableItemCaching: false, // Don't cache image widgets to save memory
    cacheBufferSize: 5,
    addRepaintBoundaries: true,
    addAutomaticKeepAlives: false, // Don't keep images alive
  );

  /// Configuration optimized for text-heavy lists
  static const ListOptimizationConfig textHeavy = ListOptimizationConfig(
    enableLazyLoading: true,
    enableItemCaching: true,
    cacheBufferSize: 20,
    addRepaintBoundaries: true,
    addAutomaticKeepAlives: true,
  );

  /// Configuration optimized for complex widget lists
  static const ListOptimizationConfig complexWidgets = ListOptimizationConfig(
    enableLazyLoading: true,
    enableItemCaching: true,
    cacheBufferSize: 10,
    addRepaintBoundaries: true,
    addAutomaticKeepAlives: false,
  );
}
