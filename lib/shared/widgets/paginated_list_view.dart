import 'package:flutter/material.dart';
import '../models/pagination.dart';
import '../../core/themes/app_colors.dart';

/// Paginated list widget with infinite scroll loading
class PaginatedListView<T> extends StatelessWidget {
  final PaginationState<T> paginationState;
  final Widget Function(BuildContext, T, int) itemBuilder;
  final VoidCallback? onLoadMore;
  final Widget Function(BuildContext)? loadingBuilder;
  final Widget Function(BuildContext, String)? errorBuilder;
  final Widget Function(BuildContext)? emptyBuilder;
  final ScrollController? scrollController;
  final EdgeInsets padding;
  final double bottomThreshold;

  const PaginatedListView({
    super.key,
    required this.paginationState,
    required this.itemBuilder,
    this.onLoadMore,
    this.loadingBuilder,
    this.errorBuilder,
    this.emptyBuilder,
    this.scrollController,
    this.padding = const EdgeInsets.all(0),
    this.bottomThreshold = 500.0,
  });

  @override
  Widget build(BuildContext context) {
    final items = paginationState.items;
    final isLoading = paginationState.isLoading;
    final hasMore = paginationState.hasMore;
    final errorMessage = paginationState.errorMessage;

    // Empty state
    if (items.isEmpty && !isLoading && errorMessage == null) {
      return _buildEmptyState(context);
    }

    // Error state
    if (errorMessage != null && items.isEmpty) {
      return _buildErrorState(context, errorMessage);
    }

    return ListView.builder(
      controller: scrollController,
      padding: padding,
      itemCount: items.length + (hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        // Last item is loading indicator if there are more items
        if (index == items.length) {
          return _buildLoadMoreIndicator(context);
        }

        // Regular list item
        return Column(
          children: [
            itemBuilder(context, items[index], index),
            // Add divider between items except after last one
            if (index < items.length - 1)
              const Divider(height: 1, color: Color(0xFFE5E7EB)),
          ],
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    if (emptyBuilder != null) {
      return emptyBuilder!(context);
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_outlined, size: 64, color: const Color(0xFFD1D5DB)),
          const SizedBox(height: 16),
          Text(
            'No items found',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start by creating your first item',
            style: TextStyle(fontSize: 14, color: const Color(0xFF9CA3AF)),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, String error) {
    if (errorBuilder != null) {
      return errorBuilder!(context, error);
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red.withValues(alpha: 0.6),
          ),
          const SizedBox(height: 16),
          Text(
            'Something went wrong',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.primaryText,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            error,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: const Color(0xFF6B7280)),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onLoadMore,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryOrange,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadMoreIndicator(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          if (paginationState.isLoading)
            const SizedBox(
              height: 40,
              width: 40,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else if (paginationState.hasMore && onLoadMore != null)
            InkWell(
              onTap: onLoadMore,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 24,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.primaryOrange),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.arrow_downward, size: 18),
                    const SizedBox(width: 8),
                    const Text('Load More'),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Widget for handling infinite scroll with auto-loading on scroll
class InfiniteScrollListView<T> extends StatefulWidget {
  final PaginationState<T> paginationState;
  final Widget Function(BuildContext, T, int) itemBuilder;
  final VoidCallback? onLoadMore;
  final Widget Function(BuildContext)? loadingBuilder;
  final Widget Function(BuildContext, String)? errorBuilder;
  final Widget Function(BuildContext)? emptyBuilder;
  final EdgeInsets padding;
  final double scrollThreshold;

  const InfiniteScrollListView({
    super.key,
    required this.paginationState,
    required this.itemBuilder,
    this.onLoadMore,
    this.loadingBuilder,
    this.errorBuilder,
    this.emptyBuilder,
    this.padding = const EdgeInsets.all(0),
    this.scrollThreshold = 200.0,
  });

  @override
  State<InfiniteScrollListView<T>> createState() =>
      _InfiniteScrollListViewState<T>();
}

class _InfiniteScrollListViewState<T> extends State<InfiniteScrollListView<T>> {
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent -
                widget.scrollThreshold &&
        !widget.paginationState.isLoading &&
        widget.paginationState.hasMore &&
        widget.onLoadMore != null) {
      widget.onLoadMore!();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PaginatedListView<T>(
      paginationState: widget.paginationState,
      itemBuilder: widget.itemBuilder,
      scrollController: _scrollController,
      padding: widget.padding,
      loadingBuilder: widget.loadingBuilder,
      errorBuilder: widget.errorBuilder,
      emptyBuilder: widget.emptyBuilder,
    );
  }
}
