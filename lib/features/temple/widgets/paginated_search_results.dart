import 'package:flutter/material.dart';
import '../../../shared/models/temple.dart';
import '../../../shared/models/temple_filters.dart';
import '../services/enhanced_search_manager.dart';
import '../services/search_manager.dart';
import '../../../shared/utils/error_handler.dart';
import 'search_result_card.dart';
import 'sort_options_widget.dart';

/// Paginated search results list with comprehensive temple cards
/// Implements seamless loading of additional results as user scrolls
/// Supports sorting and filtering with immediate reordering
/// (Requirements 5.5, 4.2)
class PaginatedSearchResults extends StatefulWidget {
  final String query;
  final SearchFilters filters;
  final SortOptions sortOptions;
  final Function(SortOptions) onSortChanged;
  final Function(Temple) onTempleSelected;
  final Function(Temple)? onFavoriteToggle;
  final Function(Temple)? onLiveDarshanTap;
  final bool showSortOptions;
  final bool showDistance;
  final ScrollController? scrollController;
  final String? userId;

  const PaginatedSearchResults({
    super.key,
    required this.query,
    required this.filters,
    required this.sortOptions,
    required this.onSortChanged,
    required this.onTempleSelected,
    this.onFavoriteToggle,
    this.onLiveDarshanTap,
    this.showSortOptions = true,
    this.showDistance = true,
    this.scrollController,
    this.userId,
  });

  @override
  State<PaginatedSearchResults> createState() => _PaginatedSearchResultsState();
}

class _PaginatedSearchResultsState extends State<PaginatedSearchResults> {
  final EnhancedSearchManager _searchManager = EnhancedSearchManager();
  final ScrollController _scrollController = ScrollController();
  
  List<Temple> _temples = [];
  bool _isLoading = false;
  bool _hasMoreResults = true;
  String? _error;
  int _currentPage = 0;
  static const int _pageSize = 20;

  @override
  void initState() {
    super.initState();
    _setupScrollController();
    _performInitialSearch();
  }

  @override
  void didUpdateWidget(PaginatedSearchResults oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Re-attach scroll listener if controller changed
    if (oldWidget.scrollController != widget.scrollController) {
      final oldController = oldWidget.scrollController ?? _scrollController;
      final newController = widget.scrollController ?? _scrollController;

      if (oldController != newController) {
        oldController.removeListener(_onScroll);
        newController.addListener(_onScroll);
      }
    }
    
    // Check if search parameters changed
    if (oldWidget.query != widget.query ||
        !oldWidget.filters.isEquivalentTo(widget.filters) ||
        oldWidget.sortOptions != widget.sortOptions) {
      _resetAndSearch();
    }
  }

  void _setupScrollController() {
    final controller = widget.scrollController ?? _scrollController;
    controller.addListener(_onScroll);
  }

  void _onScroll() {
    final controller = widget.scrollController ?? _scrollController;
    if (controller.position.pixels >= controller.position.maxScrollExtent - 200) {
      _loadMoreResults();
    }
  }

  Future<void> _performInitialSearch() async {
    if (_isLoading) return;
    
    setState(() {
      _isLoading = true;
      _error = null;
      _temples.clear();
      _currentPage = 0;
      _hasMoreResults = true;
    });

    final results = await ErrorHandler.safeExecute(
      () => _searchManager.performEnhancedSearch(
        query: widget.query,
        filters: widget.filters,
        sortBy: widget.sortOptions,
        userId: widget.userId,
        limit: _pageSize,
        offset: 0,
      ),
      context: 'PaginatedSearchResults._performInitialSearch',
      fallbackValue: SearchResults(
        temples: [],
        totalCount: 0,
        searchTime: Duration.zero,
      ),
    );

    if (mounted && results != null) {
      setState(() {
        _temples = results.temples;
        _hasMoreResults = results.temples.length == _pageSize;
        _currentPage = 1;
        _isLoading = false;
      });
    } else if (mounted) {
      setState(() {
        _error = 'Failed to load search results';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMoreResults() async {
    if (_isLoading || !_hasMoreResults) return;

    setState(() {
      _isLoading = true;
    });

    final results = await ErrorHandler.safeExecute(
      () => _searchManager.performEnhancedSearch(
        query: widget.query,
        filters: widget.filters,
        sortBy: widget.sortOptions,
        userId: widget.userId,
        limit: _pageSize,
        offset: _currentPage * _pageSize,
      ),
      context: 'PaginatedSearchResults._loadMoreResults',
      fallbackValue: SearchResults(
        temples: [],
        totalCount: 0,
        searchTime: Duration.zero,
      ),
    );

    if (mounted && results != null) {
      setState(() {
        _temples.addAll(results.temples);
        _hasMoreResults = results.temples.length == _pageSize;
        _currentPage++;
        _isLoading = false;
      });
    } else if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _resetAndSearch() {
    _performInitialSearch();
  }

  @override
  void dispose() {
    if (widget.scrollController == null) {
      _scrollController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Sort options
        if (widget.showSortOptions)
          SortOptionsWidget(
            currentSortOptions: widget.sortOptions,
            onSortChanged: widget.onSortChanged,
            showDistanceSort: widget.showDistance,
            isCompact: true,
          ),
        
        // Results
        Expanded(
          child: _buildResultsList(),
        ),
      ],
    );
  }

  Widget _buildResultsList() {
    if (_error != null && _temples.isEmpty) {
      return _buildErrorState();
    }

    if (_temples.isEmpty && _isLoading) {
      return _buildLoadingState();
    }

    if (_temples.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _performInitialSearch,
      child: ListView.builder(
        controller: widget.scrollController ?? _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _temples.length + (_hasMoreResults ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= _temples.length) {
            return _buildLoadingIndicator();
          }

          final temple = _temples[index];
          return SearchResultCard(
            temple: temple,
            onTap: () => widget.onTempleSelected(temple),
            onFavoriteToggle: widget.onFavoriteToggle != null
                ? () => widget.onFavoriteToggle!(temple)
                : null,
            onLiveDarshanTap: widget.onLiveDarshanTap != null
                ? () => widget.onLiveDarshanTap!(temple)
                : null,
            showDistance: widget.showDistance,
            animationIndex: index < 10 ? index : null, // Only animate first 10 items
          );
        },
      ),
    );
  }

  Widget _buildLoadingState() {
    return ListView.builder(
      itemCount: 5,
      itemBuilder: (context, index) {
        return const SearchResultLoadingCard();
      },
    );
  }

  Widget _buildLoadingIndicator() {
    return Container(
      padding: const EdgeInsets.all(16),
      alignment: Alignment.center,
      child: const CircularProgressIndicator(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                'No temples found',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.query.isNotEmpty
                    ? 'Try adjusting your search terms or filters'
                    : 'Try searching for temples in your area',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: Colors.grey[500]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _resetAndSearch,
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Something went wrong',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Colors.grey[600],
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? 'An unexpected error occurred',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _resetAndSearch,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Search results header with count and sort options
class SearchResultsHeader extends StatelessWidget {
  final int totalResults;
  final String query;
  final SortOptions sortOptions;
  final Function(SortOptions) onSortChanged;
  final bool showDistanceSort;
  final Duration? searchTime;

  const SearchResultsHeader({
    super.key,
    required this.totalResults,
    required this.query,
    required this.sortOptions,
    required this.onSortChanged,
    this.showDistanceSort = true,
    this.searchTime,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
            color: Colors.grey[200]!,
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Results count and search time
          Row(
            children: [
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: Theme.of(context).textTheme.bodyMedium,
                    children: [
                      TextSpan(
                        text: '$totalResults results',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      if (query.isNotEmpty) ...[
                        const TextSpan(
                          text: ' for ',
                          style: TextStyle(color: Colors.grey),
                        ),
                        TextSpan(
                          text: '"$query"',
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                      if (searchTime != null) ...[
                        TextSpan(
                          text: ' (${searchTime!.inMilliseconds}ms)',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              // Sort button
              InkWell(
                onTap: () {
                  SortOptionsBottomSheet.show(
                    context,
                    currentSortOptions: sortOptions,
                    onSortChanged: onSortChanged,
                    showDistanceSort: showDistanceSort,
                  );
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.sort, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        sortOptions.sortBy.displayName,
                        style: const TextStyle(fontSize: 14),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        sortOptions.ascending
                            ? Icons.arrow_upward
                            : Icons.arrow_downward,
                        size: 14,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}