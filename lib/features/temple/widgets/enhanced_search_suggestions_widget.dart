import 'dart:async';
import 'package:flutter/material.dart';
import '../services/enhanced_search_manager.dart';

/// Widget that displays enhanced search suggestions with history and location suggestions
/// Implements requirements 6.3, 6.4 for recent searches and location suggestions
class EnhancedSearchSuggestionsWidget extends StatefulWidget {
  final String userId;
  final String currentQuery;
  final Function(String) onSuggestionSelected;
  final VoidCallback? onClearHistory;

  const EnhancedSearchSuggestionsWidget({
    super.key,
    required this.userId,
    required this.currentQuery,
    required this.onSuggestionSelected,
    this.onClearHistory,
  });

  @override
  State<EnhancedSearchSuggestionsWidget> createState() => _EnhancedSearchSuggestionsWidgetState();
}

class _EnhancedSearchSuggestionsWidgetState extends State<EnhancedSearchSuggestionsWidget> {
  final EnhancedSearchManager _searchManager = EnhancedSearchManager();
  List<String> _recentSearches = [];
  List<String> _locationSuggestions = [];
  List<String> _searchSuggestions = [];
  bool _isLoading = false;
  StreamSubscription<List<String>>? _suggestionsSubscription;

  @override
  void initState() {
    super.initState();
    _loadSuggestions();
  }

  @override
  void didUpdateWidget(EnhancedSearchSuggestionsWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentQuery != widget.currentQuery || oldWidget.userId != widget.userId) {
      _loadSuggestions();
    }
  }

  @override
  void dispose() {
    _suggestionsSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadSuggestions() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      // Load different types of suggestions based on query
      if (widget.currentQuery.isEmpty) {
        // For empty query, show recent searches
        final recentSearches = await _searchManager.getRecentSearches(
          widget.userId,
          limit: 8,
        );
        
        if (mounted) {
          setState(() {
            _recentSearches = recentSearches;
            _locationSuggestions = [];
            _searchSuggestions = [];
          });
        }
      } else {
        // For non-empty query, get comprehensive suggestions
        final locationSuggestions = await _searchManager.getLocationSuggestions(
          userId: widget.userId,
          query: widget.currentQuery,
          limit: 3,
        );

        // Cancel previous subscription before creating a new one
        await _suggestionsSubscription?.cancel();
        
        // Get search suggestions stream
        _suggestionsSubscription = _searchManager
            .getSearchSuggestions(widget.currentQuery, userId: widget.userId)
            .listen((suggestions) {
          if (mounted) {
            setState(() {
              _searchSuggestions = suggestions;
            });
          }
        });

        if (mounted) {
          setState(() {
            _recentSearches = [];
            _locationSuggestions = locationSuggestions;
          });
        }
      }
    } catch (e) {
      debugPrint('EnhancedSearchSuggestionsWidget: Error loading suggestions - $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: CircularProgressIndicator(),
        ),
      );
    }

    final hasRecentSearches = _recentSearches.isNotEmpty;
    final hasLocationSuggestions = _locationSuggestions.isNotEmpty;
    final hasSearchSuggestions = _searchSuggestions.isNotEmpty;

    if (!hasRecentSearches && !hasLocationSuggestions && !hasSearchSuggestions) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Recent searches section (for empty query)
        if (hasRecentSearches) ...[
          _buildSectionHeader(
            'Recent Searches',
            onClear: widget.onClearHistory,
          ),
          _buildSuggestionsList(_recentSearches, SuggestionType.recent),
        ],

        // Location suggestions section
        if (hasLocationSuggestions) ...[
          _buildSectionHeader('Locations'),
          _buildSuggestionsList(_locationSuggestions, SuggestionType.location),
        ],

        // Search suggestions section
        if (hasSearchSuggestions) ...[
          if (hasLocationSuggestions) const Divider(height: 1),
          _buildSectionHeader('Suggestions'),
          _buildSuggestionsList(_searchSuggestions, SuggestionType.search),
        ],
      ],
    );
  }

  Widget _buildSectionHeader(String title, {VoidCallback? onClear}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          if (onClear != null)
            TextButton(
              onPressed: onClear,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                minimumSize: const Size(0, 32),
              ),
              child: Text(
                'Clear',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.secondary,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSuggestionsList(List<String> suggestions, SuggestionType type) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: suggestions.length,
      itemBuilder: (context, index) {
        final suggestion = suggestions[index];
        return _buildSuggestionTile(suggestion, type);
      },
    );
  }

  Widget _buildSuggestionTile(String suggestion, SuggestionType type) {
    IconData icon;
    Color iconColor;
    
    switch (type) {
      case SuggestionType.recent:
        icon = Icons.history;
        iconColor = Theme.of(context).colorScheme.secondary;
        break;
      case SuggestionType.location:
        icon = Icons.location_on_outlined;
        iconColor = Theme.of(context).colorScheme.primary;
        break;
      case SuggestionType.search:
        icon = Icons.search;
        iconColor = Theme.of(context).colorScheme.onSurface;
        break;
    }

    return ListTile(
      dense: true,
      leading: Icon(
        icon,
        size: 20,
        color: iconColor,
      ),
      title: Text(
        suggestion,
        style: Theme.of(context).textTheme.bodyMedium,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: type == SuggestionType.recent
          ? IconButton(
              icon: const Icon(Icons.north_west, size: 16),
              onPressed: () => widget.onSuggestionSelected(suggestion),
              tooltip: 'Use this search',
            )
          : null,
      onTap: () => widget.onSuggestionSelected(suggestion),
    );
  }
}

enum SuggestionType {
  recent,
  location,
  search,
}