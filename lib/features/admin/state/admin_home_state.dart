import '../../../shared/models/temple.dart';

/// Immutable state class for AdminHomeScreen
class AdminHomeState {
  final List<Temple> temples;
  final List<Temple> filteredTemples;
  final bool isLoading;
  final bool isSearching;
  final String? error;
  final String searchQuery;
  final String sortBy;
  final String filterStatus;
  final List<String> searchSuggestions;
  final bool showSuggestions;

  const AdminHomeState({
    this.temples = const [],
    this.filteredTemples = const [],
    this.isLoading = false,
    this.isSearching = false,
    this.error,
    this.searchQuery = '',
    this.sortBy = 'newest',
    this.filterStatus = 'all',
    this.searchSuggestions = const [],
    this.showSuggestions = false,
  });

  /// Create a copy with updated fields
  AdminHomeState copyWith({
    List<Temple>? temples,
    List<Temple>? filteredTemples,
    bool? isLoading,
    bool? isSearching,
    String? error,
    bool clearError = false,
    String? searchQuery,
    String? sortBy,
    String? filterStatus,
    List<String>? searchSuggestions,
    bool? showSuggestions,
  }) {
    return AdminHomeState(
      temples: temples ?? this.temples,
      filteredTemples: filteredTemples ?? this.filteredTemples,
      isLoading: isLoading ?? this.isLoading,
      isSearching: isSearching ?? this.isSearching,
      error: clearError ? null : (error ?? this.error),
      searchQuery: searchQuery ?? this.searchQuery,
      sortBy: sortBy ?? this.sortBy,
      filterStatus: filterStatus ?? this.filterStatus,
      searchSuggestions: searchSuggestions ?? this.searchSuggestions,
      showSuggestions: showSuggestions ?? this.showSuggestions,
    );
  }

  /// Check if there are any temples
  bool get hasTemples => temples.isNotEmpty;

  /// Check if there are any filtered results
  bool get hasFilteredResults => filteredTemples.isNotEmpty;

  /// Check if search is active
  bool get isSearchActive => searchQuery.isNotEmpty;

  /// Check if filters are applied
  bool get hasFiltersApplied => filterStatus != 'all' || sortBy != 'newest';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is AdminHomeState &&
        other.temples == temples &&
        other.filteredTemples == filteredTemples &&
        other.isLoading == isLoading &&
        other.isSearching == isSearching &&
        other.error == error &&
        other.searchQuery == searchQuery &&
        other.sortBy == sortBy &&
        other.filterStatus == filterStatus &&
        other.searchSuggestions == searchSuggestions &&
        other.showSuggestions == showSuggestions;
  }

  @override
  int get hashCode {
    return temples.hashCode ^
        filteredTemples.hashCode ^
        isLoading.hashCode ^
        isSearching.hashCode ^
        error.hashCode ^
        searchQuery.hashCode ^
        sortBy.hashCode ^
        filterStatus.hashCode ^
        searchSuggestions.hashCode ^
        showSuggestions.hashCode;
  }
}
