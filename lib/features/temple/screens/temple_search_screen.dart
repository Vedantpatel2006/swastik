import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../../core/themes/app_colors.dart';
import '../../../shared/models/temple.dart';
import '../../../shared/models/temple_filters.dart';
import '../services/enhanced_search_manager.dart';
import '../services/search_manager.dart';
import '../widgets/paginated_search_results.dart';
import '../screens/temple_detail_screen.dart';
import '../../../shared/utils/error_handler.dart';

/// Dedicated search screen for temple discovery
/// Provides comprehensive search functionality with filters, suggestions, and results
class TempleSearchScreen extends StatefulWidget {
  final String? initialQuery;
  final TempleFilters? initialFilters;
  final String? userId;

  const TempleSearchScreen({
    super.key,
    this.initialQuery,
    this.initialFilters,
    this.userId,
  });

  @override
  State<TempleSearchScreen> createState() => _TempleSearchScreenState();
}

class _TempleSearchScreenState extends State<TempleSearchScreen> {
  // Controllers and Focus
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  // Services
  final EnhancedSearchManager _searchManager = EnhancedSearchManager();

  // State
  String _currentQuery = '';
  SearchFilters _currentFilters = const SearchFilters();
  SortOptions _currentSortOptions = const SortOptions();
  Timer? _searchDebounce;
  String? _userId;

  @override
  void initState() {
    super.initState();
    
    _initializeSearch();
    _setupListeners();
    
    // Handle route arguments
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (args != null) {
        final initialQuery = args['initialQuery'] as String?;
        final initialFilters = args['initialFilters'] as TempleFilters?;
        final userId = args['userId'] as String?;

        if (initialQuery != null) {
          _searchController.text = initialQuery;
          setState(() {
            _currentQuery = initialQuery;
          });
        }

        // Store userId if provided
        if (userId != null) {
          _userId = userId;
        }

        // Store filters in state so PaginatedSearchResults picks them up
        if (initialFilters != null) {
          setState(() {
            _currentFilters = SearchFilters(
              searchQuery: initialFilters.searchQuery,
              traditions: initialFilters.traditions,
              features: initialFilters.features,
              maxDistance: initialFilters.maxDistance,
              userLocation: initialFilters.userLocation,
              hasLiveDarshan: initialFilters.hasLiveDarshan,
              isActive: initialFilters.isActive,
              cities: initialFilters.cities,
              states: initialFilters.states,
              sortBy: initialFilters.sortBy,
              ascending: initialFilters.ascending,
            );
          });
        }
      } else {
        // Use constructor parameters as fallback
        if (widget.initialQuery != null) {
          _searchController.text = widget.initialQuery!;
          setState(() {
            _currentQuery = widget.initialQuery!;
          });
        }

        if (widget.userId != null) {
          _userId = widget.userId;
        }

        if (widget.initialFilters != null) {
          setState(() {
            _currentFilters = SearchFilters(
              searchQuery: widget.initialFilters!.searchQuery,
              traditions: widget.initialFilters!.traditions,
              features: widget.initialFilters!.features,
              maxDistance: widget.initialFilters!.maxDistance,
              userLocation: widget.initialFilters!.userLocation,
              hasLiveDarshan: widget.initialFilters!.hasLiveDarshan,
              isActive: widget.initialFilters!.isActive,
              cities: widget.initialFilters!.cities,
              states: widget.initialFilters!.states,
              sortBy: widget.initialFilters!.sortBy,
              ascending: widget.initialFilters!.ascending,
            );
          });
        }
      }
    });
  }

  void _initializeSearch() {
    // Set initial values
    if (widget.initialQuery?.isNotEmpty == true) {
      _searchController.text = widget.initialQuery!;
      _currentQuery = widget.initialQuery!;
    }

    // Initialize search manager with error handling
    ErrorHandler.safeExecute(
      () async {
      try {
        await _searchManager.initialize();
        if (kDebugMode) {
          debugPrint(
            'TempleSearchScreen: Search manager initialized successfully',
          );
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint(
            'TempleSearchScreen: Error initializing search manager: $e',
          );
        }
        // Continue without initialization - search will still work with basic functionality
      }
    },
      context: 'TempleSearchScreen.initializeSearch',
    );
  }

  void _setupListeners() {
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    final query = _searchController.text;
    
    if (_searchDebounce?.isActive ?? false) _searchDebounce!.cancel();
    
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted && query != _currentQuery) {
        setState(() {
          _currentQuery = query;
        });
      }
    });
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _currentQuery = '';
    });
  }

  void _onTempleSelected(Temple temple) {
    // Navigate to temple detail screen using consistent route
    try {
      Navigator.pushNamed(context, '/temple_detail', arguments: temple);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error navigating to temple detail: $e');
      }
      // Fallback navigation
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => TempleDetailScreen(temple: temple),
        ),
      );
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.creamBackground,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.primaryText),
        title: const Text(
          'Search Temples',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.primaryText,
          ),
        ),
        centerTitle: true,
        actions: [_buildFilterButton()],
      ),
      body: Column(
        children: [
          _buildSearchHeader(),
          Expanded(
            child: _buildSearchResults()),
        ],
      ),
    );
  }

  Widget _buildFilterButton() {
    final hasActiveFilters =
        _currentFilters.hasLiveDarshan == true ||
        (_currentFilters.traditions?.isNotEmpty ?? false) ||
        (_currentFilters.features?.isNotEmpty ?? false) ||
        // Only count distance as active when a user location is present;
        // without a location the distance filter has no effect.
        (_currentFilters.maxDistance != null &&
            _currentFilters.userLocation != null) ||
        (_currentFilters.cities?.isNotEmpty ?? false) ||
        (_currentFilters.states?.isNotEmpty ?? false);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          icon: const Icon(Icons.tune_rounded),
          color: hasActiveFilters
              ? AppColors.primaryOrange
              : AppColors.primaryText,
          tooltip: 'Filters',
          onPressed: _showFilterSheet,
        ),
        if (hasActiveFilters)
          Positioned(
            right: 8,
            top: 8,
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: AppColors.primaryOrange,
                shape: BoxShape.circle,
              ),
            ),
          ),
      ],
    );
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _FilterBottomSheet(
        currentFilters: _currentFilters,
        currentSortOptions: _currentSortOptions,
        onApply: (filters, sortOptions) {
          setState(() {
            _currentFilters = filters;
            _currentSortOptions = sortOptions;
          });
        },
        onClear: () {
          setState(() {
            _currentFilters = const SearchFilters();
            _currentSortOptions = const SortOptions();
          });
        },
      ),
    );
  }

  Widget _buildSearchHeader() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        children: [
          _buildSearchField(),
          const SizedBox(height: 12),
          _buildSearchStats(),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.veryLightGray,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _searchFocusNode.hasFocus 
              ? AppColors.primaryOrange
              : Colors.transparent,
          width: 2,
        ),
      ),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        decoration: InputDecoration(
          hintText: 'Search temples, locations, traditions...',
          prefixIcon: const Icon(Icons.search, color: AppColors.secondaryText),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: _clearSearch,
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
        textInputAction: TextInputAction.search,
        onSubmitted: (value) {
          _searchFocusNode.unfocus();
        },
      ),
    );
  }

  Widget _buildSearchStats() {
    return Row(
      children: [
        Expanded(
          child: Text(
            _currentQuery.isEmpty 
                ? 'Enter search terms or browse all temples'
                : 'Searching for "${_currentQuery}"',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.secondaryText,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchResults() {
    return PaginatedSearchResults(
      query: _currentQuery,
      filters: _currentFilters,
      sortOptions: _currentSortOptions,
      userId: _userId ?? widget.userId,
      onSortChanged: (sortOptions) {
        setState(() {
          _currentSortOptions = sortOptions;
        });
      },
      onTempleSelected: _onTempleSelected,
      scrollController: _scrollController,
      showSortOptions: false,
    );
  }
}

// ---------------------------------------------------------------------------
// Filter Bottom Sheet
// ---------------------------------------------------------------------------

class _FilterBottomSheet extends StatefulWidget {
  final SearchFilters currentFilters;
  final SortOptions currentSortOptions;
  final void Function(SearchFilters, SortOptions) onApply;
  final VoidCallback onClear;

  const _FilterBottomSheet({
    required this.currentFilters,
    required this.currentSortOptions,
    required this.onApply,
    required this.onClear,
  });

  @override
  State<_FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends State<_FilterBottomSheet> {
  late bool _hasLiveDarshan;
  late double? _maxDistance;
  late SortOption _sortBy;

  // Simplified: only 3 distance options
  static const _distances = <_DistanceOption>[
    _DistanceOption(null, 'Any'),
    _DistanceOption(10.0, '10 km'),
    _DistanceOption(25.0, '25 km'),
    _DistanceOption(50.0, '50 km'),
  ];

  // Simplified: only 4 sort options
  static const _sortOptions = <_SortItem>[
    _SortItem(SortOption.name, 'Name', Icons.sort_by_alpha),
    _SortItem(SortOption.distance, 'Nearest', Icons.near_me),
    _SortItem(SortOption.rating, 'Rating', Icons.star_rounded),
    _SortItem(SortOption.popularity, 'Popular', Icons.trending_up),
  ];

  @override
  void initState() {
    super.initState();
    _hasLiveDarshan = widget.currentFilters.hasLiveDarshan ?? false;
    _maxDistance = widget.currentFilters.maxDistance;
    _sortBy = widget.currentSortOptions.sortBy;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHandle(),
            _buildHeader(),
            const Divider(height: 1),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLiveDarshanToggle(),
                    const SizedBox(height: 20),
                    _buildDistanceSection(),
                    const SizedBox(height: 20),
                    _buildSortSection(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
            _buildApplyButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildHandle() => Container(
    margin: const EdgeInsets.only(top: 12, bottom: 4),
    width: 40,
    height: 4,
    decoration: BoxDecoration(
      color: Colors.grey[300],
      borderRadius: BorderRadius.circular(2),
    ),
  );

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 8, 12),
      child: Row(
        children: [
          const Text(
            'Sort & Filter',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.primaryText,
            ),
          ),
          const Spacer(),
          TextButton(
            onPressed: () {
              // Reset local state first so the sheet shows cleared values
              // if it is reopened before the parent rebuilds.
              setState(() {
                _hasLiveDarshan = false;
                _maxDistance = null;
                _sortBy = SortOption.name;
              });
              widget.onClear();
              Navigator.pop(context);
            },
            child: const Text(
              'Reset',
              style: TextStyle(color: AppColors.primaryOrange),
            ),
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close, color: AppColors.secondaryText),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveDarshanToggle() {
    return InkWell(
      onTap: () => setState(() => _hasLiveDarshan = !_hasLiveDarshan),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: _hasLiveDarshan
              ? AppColors.liveRed.withValues(alpha: 0.08)
              : AppColors.veryLightGray,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _hasLiveDarshan ? AppColors.liveRed : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.live_tv_rounded,
              color: _hasLiveDarshan
                  ? AppColors.liveRed
                  : AppColors.secondaryText,
              size: 20,
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Live Darshan Only',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: AppColors.primaryText,
                ),
              ),
            ),
            Switch(
              value: _hasLiveDarshan,
              activeColor: AppColors.liveRed,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              onChanged: (val) => setState(() => _hasLiveDarshan = val),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDistanceSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Distance',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: AppColors.secondaryText,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: _distances.map((opt) {
            final selected = _maxDistance == opt.value;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _maxDistance = opt.value),
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.primaryOrange
                        : AppColors.veryLightGray,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: selected
                          ? AppColors.primaryOrange
                          : Colors.transparent,
                    ),
                  ),
                  child: Text(
                    opt.label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: selected ? Colors.white : AppColors.primaryText,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        // Warn the user when a distance is selected but location is unavailable.
        if (_maxDistance != null &&
            widget.currentFilters.userLocation == null) ...[
          const SizedBox(height: 8),
          Row(
            children: const [
              Icon(
                Icons.info_outline,
                size: 14,
                color: AppColors.secondaryText,
              ),
              SizedBox(width: 4),
              Expanded(
                child: Text(
                  'Enable location permission for distance filtering to work.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.secondaryText,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildSortSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Sort By',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: AppColors.secondaryText,
          ),
        ),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 3.2,
          children: _sortOptions.map((opt) {
            final selected = _sortBy == opt.value;
            return GestureDetector(
              onTap: () => setState(() => _sortBy = opt.value),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.primaryOrange
                      : AppColors.veryLightGray,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: selected
                        ? AppColors.primaryOrange
                        : Colors.transparent,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      opt.icon,
                      size: 16,
                      color: selected ? Colors.white : AppColors.secondaryText,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      opt.label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: selected ? Colors.white : AppColors.primaryText,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildApplyButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryOrange,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            elevation: 0,
          ),
          onPressed: () {
            // Build a fresh SearchFilters so toggling off a filter actually
            // clears it (copyWith can't set a field back to null).
            widget.onApply(
              SearchFilters(
                // Preserve filters that are not managed by this sheet
                traditions: widget.currentFilters.traditions,
                features: widget.currentFilters.features,
                cities: widget.currentFilters.cities,
                states: widget.currentFilters.states,
                userLocation: widget.currentFilters.userLocation,
                isActive: widget.currentFilters.isActive,
                // Managed by this sheet
                hasLiveDarshan: _hasLiveDarshan ? true : null,
                maxDistance: _maxDistance,
              ),
              SortOptions(sortBy: _sortBy),
            );
            Navigator.pop(context);
          },
          child: const Text(
            'Apply',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}

class _DistanceOption {
  final double? value;
  final String label;
  const _DistanceOption(this.value, this.label);
}

class _SortItem {
  final SortOption value;
  final String label;
  final IconData icon;
  const _SortItem(this.value, this.label, this.icon);
}

/// Search screen route helper
class TempleSearchRoute {
  static const String routeName = '/temple-search';

  static Route<dynamic> route({
    String? initialQuery,
    TempleFilters? initialFilters,
    String? userId,
  }) {
    return MaterialPageRoute(
      builder: (context) => TempleSearchScreen(
        initialQuery: initialQuery,
        initialFilters: initialFilters,
        userId: userId,
      ),
      settings: const RouteSettings(name: routeName),
    );
  }
}