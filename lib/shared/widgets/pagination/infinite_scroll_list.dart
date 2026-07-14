import 'dart:async';
import 'package:flutter/material.dart';
import '../loading/pagination_loading_indicator.dart';
import '../../../shared/models/temple.dart';
import '../../../features/temple/widgets/temple_card.dart';

/// Generic infinite scroll list widget
class InfiniteScrollList<T> extends StatefulWidget {
  final Stream<List<T>> dataStream;
  final Future<void> Function() onLoadMore;
  final Future<void> Function() onRefresh;
  final Widget Function(BuildContext context, T item, int index) itemBuilder;
  final Widget Function(BuildContext context)? emptyBuilder;
  final Widget Function(BuildContext context, String error)? errorBuilder;
  final Widget Function(BuildContext context)? loadingBuilder;
  final ScrollController? scrollController;
  final EdgeInsets? padding;
  final bool shrinkWrap;
  final ScrollPhysics? physics;
  final double loadMoreThreshold;

  const InfiniteScrollList({
    super.key,
    required this.dataStream,
    required this.onLoadMore,
    required this.onRefresh,
    required this.itemBuilder,
    this.emptyBuilder,
    this.errorBuilder,
    this.loadingBuilder,
    this.scrollController,
    this.padding,
    this.shrinkWrap = false,
    this.physics,
    this.loadMoreThreshold = 200.0,
  });

  @override
  State<InfiniteScrollList<T>> createState() => _InfiniteScrollListState<T>();
}

class _InfiniteScrollListState<T> extends State<InfiniteScrollList<T>>
    with AutomaticKeepAliveClientMixin {
  late final ScrollController _scrollController;

  StreamSubscription<List<T>>? _dataSubscription;
  List<T> _items = [];
  bool _isLoading = false;
  bool _hasError = false;
  String? _errorMessage;
  bool _hasMore = true;
  bool _isLoadingMore = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scrollController = widget.scrollController ?? ScrollController();

    _scrollController.addListener(_onScroll);
    _setupDataStream();
  }

  @override
  void didUpdateWidget(InfiniteScrollList<T> oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.dataStream != oldWidget.dataStream) {
      _setupDataStream();
    }
  }

  void _setupDataStream() {
    _dataSubscription?.cancel();

    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = null;
    });

    _dataSubscription = widget.dataStream.listen(
      _onDataReceived,
      onError: _onDataError,
    );
  }

  void _onDataReceived(List<T> items) {
    if (!mounted) return;

    setState(() {
      _items = items;
      _isLoading = false;
      _isLoadingMore = false;
      _hasError = false;
      _errorMessage = null;
      _hasMore = items.isNotEmpty; // Assume more data if we received items
    });
  }

  void _onDataError(dynamic error) {
    if (!mounted) return;

    setState(() {
      _isLoading = false;
      _isLoadingMore = false;
      _hasError = true;
      _errorMessage = error.toString();
    });
  }

  void _onScroll() {
    if (!mounted) return;

    // Check if we need to load more data
    if (_shouldLoadMore()) {
      _loadMore();
    }
  }

  bool _shouldLoadMore() {
    if (_isLoadingMore || !_hasMore || _hasError) return false;

    final position = _scrollController.position;
    return position.pixels >=
        position.maxScrollExtent - widget.loadMoreThreshold;
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      await widget.onLoadMore();
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = 'Failed to load more items: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
    }
  }

  Future<void> _handleRefresh() async {
    try {
      await widget.onRefresh();
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = 'Failed to refresh: $e';
        });
      }
    }
  }

  @override
  void dispose() {
    _dataSubscription?.cancel();
    if (widget.scrollController == null) {
      _scrollController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_isLoading && _items.isEmpty) {
      return _buildLoadingState();
    }

    if (_hasError && _items.isEmpty) {
      return _buildErrorState();
    }

    if (_items.isEmpty) {
      return _buildEmptyState();
    }

    return _buildListView();
  }

  Widget _buildLoadingState() {
    if (widget.loadingBuilder != null) {
      return widget.loadingBuilder!(context);
    }

    return const Center(child: CircularProgressIndicator());
  }

  Widget _buildErrorState() {
    if (widget.errorBuilder != null) {
      return widget.errorBuilder!(context, _errorMessage ?? 'Unknown error');
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 16),
          Text(
            'Something went wrong',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            _errorMessage ?? 'Unknown error occurred',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _handleRefresh, child: const Text('Retry')),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    if (widget.emptyBuilder != null) {
      return widget.emptyBuilder!(context);
    }

    return const Center(child: Text('No items found'));
  }

  Widget _buildListView() {
    return RefreshIndicator(
      onRefresh: _handleRefresh,
      child: CustomScrollView(
        controller: _scrollController,
        physics: widget.physics,
        shrinkWrap: widget.shrinkWrap,
        semanticChildCount: _items.length,
        slivers: [
          SliverPadding(
            padding: widget.padding ?? EdgeInsets.zero,
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  if (index >= _items.length) {
                    return null;
                  }

                  final item = _items[index];

                  return RepaintBoundary(
                    key: ValueKey('item_$index'),
                    child: widget.itemBuilder(context, item, index),
                  );
                },
                childCount: _items.length,
                addAutomaticKeepAlives: true,
                addRepaintBoundaries: false, // We handle this manually
                addSemanticIndexes: true,
              ),
            ),
          ),
          if (_isLoadingMore || _hasError)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: _buildBottomIndicator(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBottomIndicator() {
    if (_hasError) {
      return PaginationLoadingIndicator(
        isLoading: false,
        error: _errorMessage,
        onRetry: _loadMore,
        errorMessage: 'Failed to load more items',
      );
    }

    if (_isLoadingMore) {
      return const PaginationLoadingIndicator(
        isLoading: true,
        loadingMessage: 'Loading more items...',
      );
    }

    return const SizedBox.shrink();
  }
}

/// Specialized infinite scroll list for temples
class InfiniteTempleScrollList extends StatelessWidget {
  final Stream<List<Temple>> templeStream;
  final Future<void> Function() onLoadMore;
  final Future<void> Function() onRefresh;
  final Function(Temple)? onTempleSelected;
  final Function(Temple)? onFavoriteToggle;
  final Function(Temple)? onLiveDarshanTap;
  final bool showDistance;
  final bool showLiveIndicator;
  final ScrollController? scrollController;
  final EdgeInsets? padding;

  const InfiniteTempleScrollList({
    super.key,
    required this.templeStream,
    required this.onLoadMore,
    required this.onRefresh,
    this.onTempleSelected,
    this.onFavoriteToggle,
    this.onLiveDarshanTap,
    this.showDistance = true,
    this.showLiveIndicator = true,
    this.scrollController,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return InfiniteScrollList<Temple>(
      dataStream: templeStream,
      onLoadMore: onLoadMore,
      onRefresh: onRefresh,
      scrollController: scrollController,
      padding: padding,
      itemBuilder: (context, temple, index) {
        return TempleCard(
          key: ValueKey('temple_${temple.id}'),
          temple: temple,
          onTap: onTempleSelected != null
              ? () => onTempleSelected!(temple)
              : null,
          onFavoriteToggle: onFavoriteToggle != null
              ? () => onFavoriteToggle!(temple)
              : null,
          onLiveDarshanTap: onLiveDarshanTap != null
              ? () => onLiveDarshanTap!(temple)
              : null,
          showDistance: showDistance,
          showLiveIndicator: showLiveIndicator,
        );
      },
      emptyBuilder: (context) => const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.temple_hindu, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No temples found',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              'Try adjusting your search filters',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      ),
      errorBuilder: (context, error) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Failed to load temples',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
