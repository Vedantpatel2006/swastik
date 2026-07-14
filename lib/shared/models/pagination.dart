/// Pagination model for handling paginated lists with lazy loading
class PaginationState<T> {
  final List<T> items;
  final bool isLoading;
  final bool hasMore;
  final int pageSize;
  final int currentPage;
  final String? errorMessage;

  const PaginationState({
    this.items = const [],
    this.isLoading = false,
    this.hasMore = true,
    this.pageSize = 20,
    this.currentPage = 0,
    this.errorMessage,
  });

  /// Copy with method for updating pagination state
  PaginationState<T> copyWith({
    List<T>? items,
    bool? isLoading,
    bool? hasMore,
    int? pageSize,
    int? currentPage,
    String? errorMessage,
  }) {
    return PaginationState<T>(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      pageSize: pageSize ?? this.pageSize,
      currentPage: currentPage ?? this.currentPage,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  /// Add new items to the list (when loading next page)
  PaginationState<T> addItems(List<T> newItems) {
    final updatedItems = [...items, ...newItems];
    return copyWith(
      items: updatedItems,
      isLoading: false,
      hasMore: newItems.length >= pageSize,
      currentPage: currentPage + 1,
    );
  }

  /// Reset pagination state
  PaginationState<T> reset() {
    return PaginationState<T>(
      items: const [],
      isLoading: false,
      hasMore: true,
      pageSize: pageSize,
      currentPage: 0,
    );
  }

  /// Set error message and reset loading state
  PaginationState<T> withError(String error) {
    return copyWith(
      isLoading: false,
      errorMessage: error,
    );
  }

  /// Set loading state
  PaginationState<T> withLoading() {
    return copyWith(isLoading: true, errorMessage: null);
  }

  @override
  String toString() =>
      'PaginationState(items: ${items.length}, isLoading: $isLoading, hasMore: $hasMore, page: $currentPage)';
}

/// Pagination query model for requesting specific pages
class PaginationQuery {
  final int pageSize;
  final int page;
  final String? sortBy;
  final bool descending;
  final Map<String, dynamic>? filters;

  const PaginationQuery({
    this.pageSize = 20,
    this.page = 0,
    this.sortBy,
    this.descending = true,
    this.filters,
  });

  /// Get offset for database query (for API pagination)
  int get offset => page * pageSize;

  /// Copy with method
  PaginationQuery copyWith({
    int? pageSize,
    int? page,
    String? sortBy,
    bool? descending,
    Map<String, dynamic>? filters,
  }) {
    return PaginationQuery(
      pageSize: pageSize ?? this.pageSize,
      page: page ?? this.page,
      sortBy: sortBy ?? this.sortBy,
      descending: descending ?? this.descending,
      filters: filters ?? this.filters,
    );
  }

  /// Get next page query
  PaginationQuery nextPage() {
    return copyWith(page: page + 1);
  }

  /// Reset to first page
  PaginationQuery reset() {
    return PaginationQuery(
      pageSize: pageSize,
      sortBy: sortBy,
      descending: descending,
      filters: filters,
    );
  }

  @override
  String toString() =>
      'PaginationQuery(page: $page, size: $pageSize, sort: $sortBy)';
}
