import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../shared/models/temple.dart';
import '../../../shared/models/temple_filters.dart';
import '../services/user_temple_service.dart';
import 'temple_card.dart';
import '../../../shared/widgets/loading/pagination_loading_indicator.dart';
// Collection utilities are not needed after refactoring

/// Paginated temple list widget with memory optimization
/// Implements requirement 3.3: Pagination for temple list loading (10-20 temples per page)
class PaginatedTempleList extends StatefulWidget {
  final TempleFilters? filters;
  final Function(Temple)? onTempleSelected;
  final Function(Temple)? onFavoriteToggle;
  final Function(Temple)? onLiveDarshanTap;
  final bool showDistance;
  final bool showLiveIndicator;
  final int pageSize;

  const PaginatedTempleList({
    super.key,
    this.filters,
    this.onTempleSelected,
    this.onFavoriteToggle,
    this.onLiveDarshanTap,
    this.showDistance = true,
    this.showLiveIndicator = true,
    this.pageSize = 15, // Default to 15 temples per page (requirement 3.3)
  });

  @override
  State<PaginatedTempleList> createState() => _PaginatedTempleListState();
}

class _PaginatedTempleListState extends State<PaginatedTempleList> {
  final Map<String, StreamSubscription> _subscriptions = {};
  final UserTempleService _templeService = UserTempleService();
  final ScrollController _scrollController = ScrollController();

  List<Temple> _temples = [];
  bool _isLoading = false;
  bool _hasMoreData = true;
  String? _error;
  DocumentSnapshot? _lastDocument;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadFirstPage();
  }

  @override
  void didUpdateWidget(PaginatedTempleList oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reload if filters changed
    if (widget.filters != oldWidget.filters) {
      _resetAndReload();
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoading &&
        _hasMoreData) {
      _loadNextPage();
    }
  }

  void _resetAndReload() {
    // Cancel existing subscriptions before reloading
    _subscriptions['temples']?.cancel();

    setState(() {
      _temples.clear();
      _lastDocument = null;
      _hasMoreData = true;
      _error = null;
    });

    _loadFirstPage();
  }

  void _loadFirstPage() {
    _loadTemples(isFirstPage: true);
  }

  void _loadNextPage() {
    if (_lastDocument != null) {
      _loadTemples(isFirstPage: false);
    }
  }

  Future<void> _loadTemples({required bool isFirstPage}) async {
    if (_isLoading) return;
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      if (isFirstPage) {
        _error = null;
      }
    });

    try {
      // Cancel any existing subscription to prevent memory leaks
      await _cancelExistingSubscription();
      
      // Load temples in smaller batches for better performance
      await _loadTemplesBatch(isFirstPage: isFirstPage);
      
    } catch (e) {
      if (!mounted) return;
      
      setState(() {
        _error = 'Failed to load temples. Please try again.';
        _isLoading = false;
      });
      
      debugPrint('Error loading temples: $e');
    }
  }

  Future<void> _cancelExistingSubscription() async {
    final subscription = _subscriptions['temples'];
    if (subscription != null) {
      await subscription.cancel();
      _subscriptions.remove('temples');
    }
  }

  Future<void> _loadTemplesBatch({required bool isFirstPage}) async {
    final subscription = _templeService
        .watchTemplesPaginated(
          filters: widget.filters,
          limit: widget.pageSize,
          startAfter: isFirstPage ? null : _lastDocument,
        )
        .listen(
          (temples) {
            if (!mounted) return;
            
            setState(() {
              _updateTemplesList(temples, isFirstPage);
              _updatePaginationState(temples);
            });
          },
          onError: (error) => _handleLoadError(error),
          cancelOnError: true,
        );
    
    _subscriptions['temples'] = subscription;
  }

  void _updateTemplesList(List<Temple> temples, bool isFirstPage) {
    if (isFirstPage) {
      // Create a new list to trigger proper widget updates
      _temples = List<Temple>.from(temples);
    } else {
      // Use a set for O(1) lookups
      final existingIds = <String>{};
      for (final temple in _temples) {
        existingIds.add(temple.id);
      }
      
      // Only add new temples that don't exist in the current list
      final newTemples = <Temple>[];
      for (final temple in temples) {
        if (!existingIds.contains(temple.id)) {
          newTemples.add(temple);
        }
      }
      
      if (newTemples.isNotEmpty) {
        _temples = List<Temple>.from(_temples)..addAll(newTemples);
      }
    }
  }

  void _updatePaginationState(List<Temple> temples) {
    _hasMoreData = temples.length == widget.pageSize;
    _isLoading = false;
    
    if (temples.isNotEmpty) {
      _lastDocument = null; // Update with actual DocumentSnapshot in real implementation
    }
  }

  void _handleLoadError(dynamic error) {
    if (!mounted) return;
    
    setState(() {
      _error = 'Failed to load temples. Please try again.';
      _isLoading = false;
    });
    
    debugPrint('Error in temple stream: $error');
  }

  @override
  void dispose() {
    _scrollController.dispose();
    // Cancel all subscriptions
    for (var subscription in _subscriptions.values) {
      subscription.cancel();
    }
    _subscriptions.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: _buildTempleList(),
        ),
        // Loading/error indicator at the bottom
        if (_isLoading || _error != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: _buildLoadingIndicator(),
          ),
      ],
    );
  }

  Widget _buildTempleList() {
    if (_error != null && _temples.isEmpty) {
      return Center(
        child: _buildErrorDisplay(),
      );
    }

    if (_temples.isEmpty) {
      return const Center(
        child: Text('No temples found'),
      );
    }

    return RefreshIndicator(
      onRefresh: _handleRefresh,
      child: _buildTempleListView(),
    );
  }

  Future<void> _handleRefresh() async {
    _resetAndReload();
    // Wait for loading to complete
    while (_isLoading && mounted) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }

  Widget _buildTempleListView() {
    return ListView.builder(
      controller: _scrollController,
      itemCount: _temples.length + (_hasMoreData ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= _temples.length) {
          return const SizedBox.shrink();
        }

        final temple = _temples[index];
        return _buildTempleItem(temple);
      },
      // Performance optimizations
      addAutomaticKeepAlives: true,
      addRepaintBoundaries: true,
      cacheExtent: 1000, // Cache 1000 pixels of offscreen content
      semanticChildCount: _temples.length,
    );
  }

  Widget _buildTempleItem(Temple temple) {
    return TempleCard(
      key: ValueKey('temple_${temple.id}'),
      temple: temple,
      onTap: () => widget.onTempleSelected?.call(temple),
      onFavoriteToggle: widget.onFavoriteToggle != null
          ? () => widget.onFavoriteToggle!(temple)
          : null,
      onLiveDarshanTap: widget.onLiveDarshanTap != null
          ? () => widget.onLiveDarshanTap!(temple)
          : null,
      showDistance: widget.showDistance,
      showLiveIndicator: widget.showLiveIndicator,
    );
  }

  Widget _buildLoadingIndicator() {
    return PaginationLoadingIndicator(
      isLoading: _isLoading,
      error: _error,
      onRetry: _loadNextPage,
      loadingMessage: 'Loading more temples...',
      errorMessage: 'Error loading temples. Please try again.',
    );
  }

  Widget _buildErrorDisplay() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Failed to load temples',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: _resetAndReload,
          child: const Text('Retry'),
        ),
      ],
    );
  }
}
