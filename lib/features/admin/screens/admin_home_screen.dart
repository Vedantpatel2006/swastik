import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/themes/app_colors.dart';
import '../../../providers/auth_provider.dart';
import '../../../features/temple/widgets/temple_hero_image.dart';
import '../../../shared/services/offline/offline_temple_service.dart';
import '../../../shared/services/offline/offline_manager.dart';
import '../../../shared/services/realtime_service.dart';
import '../../temple/screens/add_temple_screen.dart';
import '../../temple/screens/edit_temple_screen.dart';
import '../../temple/screens/temple_detail_screen.dart';
import '../../auth/screens/auth_intro.dart';
import '../../temple/services/temple_service.dart';
import '../services/temple_search_service.dart';
import '../../temple/mappers/temple_mapper.dart';
import '../../../core/services/error_logger.dart';
import '../widgets/admin_notification_widget.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen>
    with TickerProviderStateMixin, RealtimeMixin {
  late AnimationController _fabAnimationController;

  String _searchQuery = '';
  String _sortBy = 'newest'; // newest, oldest, name, location
  String _filterStatus = 'all'; // all, active, inactive

  final TextEditingController _searchController = TextEditingController();

  // Smart search suggestions
  List<String> _searchSuggestions = [];
  bool _showSuggestions = false;

  final OfflineTempleService _offlineTempleService = OfflineTempleService();
  final OfflineManager _offlineManager = OfflineManager();
  final TempleService _templeService = TempleService();
  final TempleSearchService _searchService = TempleSearchService();

  List<Map<String, dynamic>> _temples = [];
  List<Map<String, dynamic>> _filteredTemples = [];

  bool _isLoading = true;
  bool _isSearching = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fabAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fabAnimationController.forward();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    try {
      await _offlineTempleService.initialize();
      await _offlineManager.initialize();
      _setupRealtimeTempleStream();
    } catch (e, stackTrace) {
      ErrorLogger.log(
        'AdminHomeScreen.initializeServices',
        e,
        stackTrace: stackTrace,
      );
      if (!mounted) return;
      setState(() {
        _error = 'Failed to initialize: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  /// Setup realtime stream for temples data using RealtimeService
  void _setupRealtimeTempleStream() {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    // Subscribe to realtime temples stream
    subscribeToRealtimeStream(
      'admin_temples',
      RealtimeService().getTemplesStream(
        orderBy: 'updatedAt',
        descending: true,
      ),
      (dynamic temples) {
        if (!mounted) return;

        if (temples is List<Map<String, dynamic>>) {
          setState(() {
            _temples = temples;
            _filteredTemples = _searchService.search(
              temples: temples,
              query: _searchQuery,
              filterStatus: _filterStatus,
              sortBy: _sortBy,
            );
            _isLoading = false;
            _error = null;
          });

          debugPrint('📡 Realtime update: ${temples.length} temples loaded');
        }
      },
      onError: (error) {
        if (mounted) {
          setState(() {
            _error = 'Realtime connection error: ${error.toString()}';
            _isLoading = false;
          });
        }
      },
    );
  }

  Future<void> _loadTemples() async {
    // This method is now used for manual refresh only
    // Realtime data is handled by _setupRealtimeTempleStream
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Restart the realtime stream
      _setupRealtimeTempleStream();
    } catch (e, stackTrace) {
      ErrorLogger.log('AdminHomeScreen.loadTemples', e, stackTrace: stackTrace);
      if (!mounted) return;
      setState(() {
        _error = 'Failed to refresh temples: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _performSearch(String query) async {
    if (query.isEmpty) {
      setState(() {
        _filteredTemples = _searchService.search(
          temples: _temples,
          query: '',
          filterStatus: _filterStatus,
          sortBy: _sortBy,
        );
        _isSearching = false;
        _showSuggestions = false;
      });
      return;
    }

    setState(() => _isSearching = true);

    try {
      final parsedQuery = _searchService.parseSmartQuery(query);

      if (parsedQuery['status'] != null) {
        _filterStatus = parsedQuery['status']!;
      }
      if (parsedQuery['sort'] != null) {
        _sortBy = parsedQuery['sort']!;
      }

      final searchText = parsedQuery['text'] ?? query;
      final results = _searchService.search(
        temples: _temples,
        query: searchText,
        filterStatus: _filterStatus,
        sortBy: _sortBy,
      );

      if (!mounted) return;

      setState(() {
        _filteredTemples = results;
        _isSearching = false;
        _showSuggestions = false;
      });
    } catch (e, stackTrace) {
      ErrorLogger.log(
        'AdminHomeScreen.performSearch',
        e,
        stackTrace: stackTrace,
        metadata: {'query': query},
      );
      if (!mounted) return;
      setState(() {
        _filteredTemples = [];
        _isSearching = false;
        _showSuggestions = false;
        _error = 'Search failed: ${e.toString()}';
      });
    }
  }

  void _generateSearchSuggestions(String query) {
    if (query.isEmpty) {
      setState(() {
        _searchSuggestions = [];
        _showSuggestions = false;
      });
      return;
    }

    final suggestions = _searchService.generateSuggestions(
      query: query,
      temples: _temples,
    );

    setState(() {
      _searchSuggestions = suggestions;
      _showSuggestions = suggestions.isNotEmpty && query.length > 1;
    });
  }

  @override
  void dispose() {
    _fabAnimationController.dispose();
    _searchService.clearCache();
    _searchController.dispose();

    // RealtimeMixin will automatically handle stream cleanup
    super.dispose();
  }

  Future<void> _handleSignOut(BuildContext context) async {
    try {
      await context.read<AuthProvider>().signOut();
      if (!mounted) return;
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Successfully signed out'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const AuthIntroScreen()),
        (route) => false,
      );
    } catch (e, stackTrace) {
      ErrorLogger.log(
        'AdminHomeScreen.handleSignOut',
        e,
        stackTrace: stackTrace,
      );
      if (!mounted) return;
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sign Out Failed: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _navigateToTempleDetail(Map<String, dynamic> templeData) {
    try {
      final temple = TempleMapper.fromMap(templeData);

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => TempleDetailScreen(temple: temple),
        ),
      );
    } catch (e, stackTrace) {
      ErrorLogger.log(
        'AdminHomeScreen.navigateToTempleDetail',
        e,
        stackTrace: stackTrace,
        metadata: {'templeId': templeData['id']},
      );
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to open temple details: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deleteTemple(
    String templeId,
    Map<String, dynamic> templeData,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Delete Temple'),
        content: Text(
          'Are you sure you want to delete "${templeData['name'] ?? 'this temple'}"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.errorRed,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    if (!mounted) return;

    try {
      final result = await _templeService.deleteTemple(
        templeId: templeId,
        onProgress: (progress) {},
        onStatusUpdate: (status) {},
      );

      if (!mounted) return;

      if (result.isSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message),
            backgroundColor: Colors.green,
          ),
        );
        await _loadTemples();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Delete Failed: ${result.error ?? 'Failed to delete temple'}',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e, stackTrace) {
      ErrorLogger.log(
        'AdminHomeScreen.deleteTemple',
        e,
        stackTrace: stackTrace,
        metadata: {'templeId': templeId},
      );
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Delete Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Create a mock TempleDocument for EditTempleScreen compatibility
  TempleDocument _createMockTempleDocument(
    String id,
    Map<String, dynamic> data,
  ) {
    // Debug: Print the data being passed to edit screen
    debugPrint('🔍 Creating mock temple document for editing:');
    debugPrint('   Temple ID: $id');
    debugPrint('   Temple Name: ${data['name']}');
    debugPrint('   Temple Location: ${data['location']}');
    debugPrint('   Data keys: ${data.keys.toList()}');

    return _MockTempleDocument(data, id);
  }

  String _formatDate(Timestamp timestamp) {
    final date = timestamp.toDate();
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  Widget _buildAdvancedSearchBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Main Search Field
          Container(
            decoration: BoxDecoration(
              color: AppColors.veryLightGray,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.borderGray),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Icon(Icons.search, color: AppColors.secondaryText),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        onChanged: (query) {
                          setState(() => _searchQuery = query);
                          _generateSearchSuggestions(query);
                          _performSearch(query);
                        },
                        decoration: const InputDecoration(
                          hintText:
                              'Search temples or try "active only", "sort by name", "live streaming"...',
                          border: InputBorder.none,
                          hintStyle: TextStyle(color: AppColors.secondaryText),
                        ),
                      ),
                    ),
                    // Filter icon
                    IconButton(
                      icon: Icon(
                        Icons.tune,
                        color: (_filterStatus != 'all' || _sortBy != 'newest')
                            ? AppColors.primaryOrange
                            : AppColors.secondaryText,
                      ),
                      onPressed: () {
                        _showFilterBottomSheet();
                      },
                      tooltip: 'Filter & Sort',
                    ),
                    if (_searchQuery.isNotEmpty)
                      IconButton(
                        icon: const Icon(
                          Icons.clear,
                          color: AppColors.secondaryText,
                        ),
                        onPressed: () {
                          setState(() {
                            _searchQuery = '';
                            _searchController.clear();
                            _filterStatus = 'all';
                            _sortBy = 'newest';
                          });
                          _performSearch('');
                        },
                      ),
                    if (_isSearching)
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                  ],
                ),

                // Search suggestions
                if (_showSuggestions && _searchSuggestions.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      children: _searchSuggestions.map((suggestion) {
                        return InkWell(
                          onTap: () {
                            _searchController.text = suggestion;
                            setState(() {
                              _searchQuery = suggestion;
                            });
                            _performSearch(suggestion);
                          },
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _getSuggestionIcon(suggestion),
                                  size: 16,
                                  color: AppColors.secondaryText,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    suggestion,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: AppColors.primaryText,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 12),
        ],
      ),
    );
  }

  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.borderGray,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Title
              const Text(
                'Filter & Sort',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryText,
                ),
              ),
              const SizedBox(height: 20),

              // Status Filter
              const Text(
                'Status',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: AppColors.primaryText,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildFilterChip('All', 'all', _filterStatus, setModalState),
                  _buildFilterChip(
                    'Active',
                    'active',
                    _filterStatus,
                    setModalState,
                  ),
                  _buildFilterChip(
                    'Inactive',
                    'inactive',
                    _filterStatus,
                    setModalState,
                  ),
                  _buildFilterChip(
                    'Live Streaming',
                    'live_streaming',
                    _filterStatus,
                    setModalState,
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Sort Options
              const Text(
                'Sort By',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: AppColors.primaryText,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildFilterChip('Newest', 'newest', _sortBy, setModalState),
                  _buildFilterChip('Oldest', 'oldest', _sortBy, setModalState),
                  _buildFilterChip('Name', 'name', _sortBy, setModalState),
                  _buildFilterChip(
                    'Location',
                    'location',
                    _sortBy,
                    setModalState,
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        setState(() {
                          _filterStatus = 'all';
                          _sortBy = 'newest';
                        });
                        _performSearch(_searchQuery);
                        Navigator.pop(context);
                      },
                      child: const Text('Clear All'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        _performSearch(_searchQuery);
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryOrange,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Apply'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(
    String label,
    String value,
    String currentValue,
    StateSetter setModalState,
  ) {
    final isSelected = currentValue == value;
    final isSortOption = [
      'newest',
      'oldest',
      'name',
      'location',
    ].contains(value);

    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setModalState(() {
          if (isSortOption) {
            _sortBy = value;
          } else {
            _filterStatus = value;
          }
        });
      },
      selectedColor: AppColors.primaryOrange.withValues(alpha: 0.1),
      checkmarkColor: AppColors.primaryOrange,
      labelStyle: TextStyle(
        color: isSelected ? AppColors.primaryOrange : AppColors.secondaryText,
        fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
      ),
      side: BorderSide(
        color: isSelected ? AppColors.primaryOrange : AppColors.borderGray,
      ),
    );
  }

  IconData _getSuggestionIcon(String suggestion) {
    final suggestionLower = suggestion.toLowerCase();

    if (suggestionLower.contains('active') ||
        suggestionLower.contains('inactive')) {
      return Icons.toggle_on;
    } else if (suggestionLower.contains('live') ||
        suggestionLower.contains('streaming')) {
      return Icons.live_tv;
    } else if (suggestionLower.contains('sort') ||
        suggestionLower.contains('first')) {
      return Icons.sort;
    } else {
      return Icons.temple_hindu;
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        // Show confirmation dialog before exiting admin panel
        final shouldExit = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Exit Admin Panel'),
            content: const Text('Do you want to exit the admin panel?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: TextButton.styleFrom(foregroundColor: Colors.orange),
                child: const Text('Exit'),
              ),
            ],
          ),
        );

        if (shouldExit == true && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.lightGray,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: Colors.orange,
          foregroundColor: Colors.white,
          elevation: 2,
          shadowColor: Colors.black26,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Temple Management',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${_temples.length} temples',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
          actions: [
            // Admin notifications badge
            AdminNotificationBadge(
              onTap: () => showAdminNotifications(context),
            ),
            // Sign out button
            IconButton(
              icon: const Icon(Icons.logout, color: Colors.white),
              tooltip: 'Sign Out',
              onPressed: () => _handleSignOut(context),
            ),
            const SizedBox(width: 4),
          ],
        ),
        body: Column(
          children: [
            // Advanced Search Bar with Integrated Filters
            _buildAdvancedSearchBar(),

            // Temple List
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.primaryOrange,
                        ),
                      ),
                    )
                  : _error != null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            size: 64,
                            color: Colors.red,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Failed to Load Temples',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _error!,
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.secondaryText,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _loadTemples,
                            child: const Text('Retry'),
                          ),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _error = null;
                              });
                            },
                            child: const Text('Dismiss'),
                          ),
                        ],
                      ),
                    )
                  : _filteredTemples.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.temple_hindu,
                            size: 64,
                            color: AppColors.secondaryText,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _searchQuery.isEmpty
                                ? 'No temples found'
                                : 'No temples match your search',
                            style: TextStyle(
                              fontSize: 18,
                              color: AppColors.secondaryText,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Total temples: ${_temples.length}',
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.secondaryText,
                            ),
                          ),
                          Text(
                            'Filtered temples: ${_filteredTemples.length}',
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.secondaryText,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _loadTemples,
                            child: const Text('Retry Loading'),
                          ),
                          if (_searchQuery.isNotEmpty)
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _searchQuery = '';
                                  _searchController.clear();
                                });
                                _performSearch('');
                              },
                              child: const Text('Clear search'),
                            ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadTemples,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _filteredTemples.length,
                        itemBuilder: (context, index) {
                          final templeData = _filteredTemples[index];
                          final templeId =
                              templeData['id'] ?? templeData['documentId'];

                          if (templeId == null || templeData.isEmpty) {
                            return const SizedBox.shrink();
                          }

                          return Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.08),
                                  blurRadius: 20,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: InkWell(
                              onTap: () => _navigateToTempleDetail(templeData),
                              onLongPress: null,
                              borderRadius: BorderRadius.circular(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Image Section with Hero Animation
                                  Stack(
                                    children: [
                                      TempleHeroImage(
                                        heroTag: 'temple_image_$templeId',
                                        imageUrl: templeData['coverPhotoUrl']
                                            ?.toString(),
                                        height: 160,
                                        width: double.infinity,
                                        borderRadius: const BorderRadius.only(
                                          topLeft: Radius.circular(16),
                                          topRight: Radius.circular(16),
                                        ),
                                      ),
                                    ],
                                  ),

                                  // Content Section
                                  Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                templeData['name']
                                                        ?.toString() ??
                                                    'Unnamed Temple',
                                                style: const TextStyle(
                                                  fontSize: 20,
                                                  fontWeight: FontWeight.w700,
                                                  color: AppColors.primaryText,
                                                ),
                                              ),
                                            ),
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Container(
                                                  decoration: BoxDecoration(
                                                    color: const Color(
                                                      0xFF3B82F6,
                                                    ).withValues(alpha: 0.1),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          10,
                                                        ),
                                                  ),
                                                  child: IconButton(
                                                    icon: const Icon(
                                                      Icons.edit_rounded,
                                                      color: AppColors
                                                          .primaryOrange,
                                                      size: 20,
                                                    ),
                                                    onPressed: () {
                                                      Navigator.of(context)
                                                          .push(
                                                            MaterialPageRoute(
                                                              builder: (context) =>
                                                                  EditTempleScreen(
                                                                    temple: _createMockTempleDocument(
                                                                      templeId,
                                                                      templeData,
                                                                    ),
                                                                  ),
                                                            ),
                                                          )
                                                          .then((_) {
                                                            // Reload temples after editing
                                                            _loadTemples();
                                                          });
                                                    },
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Container(
                                                  decoration: BoxDecoration(
                                                    color: const Color(
                                                      0xFFEF4444,
                                                    ).withValues(alpha: 0.1),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          10,
                                                        ),
                                                  ),
                                                  child: IconButton(
                                                    icon: const Icon(
                                                      Icons.delete_rounded,
                                                      color: AppColors.errorRed,
                                                      size: 20,
                                                    ),
                                                    onPressed: () =>
                                                        _deleteTemple(
                                                          templeId,
                                                          templeData,
                                                        ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),

                                        // Status indicators row
                                        Row(
                                          children: [
                                            if (templeData['location'] != null)
                                              Flexible(
                                                child: Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 12,
                                                        vertical: 6,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: const Color(
                                                      0xFF6366F1,
                                                    ).withValues(alpha: 0.1),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          20,
                                                        ),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      const Icon(
                                                        Icons
                                                            .location_on_rounded,
                                                        size: 16,
                                                        color: Color(
                                                          0xFF6366F1,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Flexible(
                                                        child: Text(
                                                          () {
                                                            final loc =
                                                                templeData['location'];
                                                            if (loc is Map) {
                                                              final city =
                                                                  loc['city']
                                                                      ?.toString() ??
                                                                  '';
                                                              final state =
                                                                  loc['state']
                                                                      ?.toString() ??
                                                                  '';
                                                              final country =
                                                                  loc['country']
                                                                      ?.toString() ??
                                                                  '';
                                                              final address =
                                                                  loc['address']
                                                                      ?.toString() ??
                                                                  '';
                                                              if (city.isNotEmpty &&
                                                                  state
                                                                      .isNotEmpty) {
                                                                final parts =
                                                                    [
                                                                          city,
                                                                          state,
                                                                          country,
                                                                        ]
                                                                        .where(
                                                                          (
                                                                            s,
                                                                          ) => s
                                                                              .isNotEmpty,
                                                                        )
                                                                        .join(
                                                                          ', ',
                                                                        );
                                                                return parts;
                                                              } else if (address
                                                                  .isNotEmpty) {
                                                                return address;
                                                              } else if (country
                                                                  .isNotEmpty) {
                                                                return country;
                                                              }
                                                            }
                                                            return loc
                                                                .toString();
                                                          }(),
                                                          style:
                                                              const TextStyle(
                                                                color: Color(
                                                                  0xFF6366F1,
                                                                ),
                                                                fontSize: 13,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w500,
                                                              ),
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),

                                            // Live streaming indicator with real-time status
                                            if (templeData['liveDarshan'] !=
                                                    null &&
                                                templeData['liveDarshan']['isConfiguredByAdmin'] ==
                                                    true) ...[
                                              if (templeData['location'] !=
                                                  null)
                                                const SizedBox(width: 8),
                                            ],
                                          ],
                                        ),
                                        if (templeData['aboutTemple'] !=
                                            null) ...[
                                          const SizedBox(height: 8),
                                          Text(
                                            templeData['aboutTemple']
                                                .toString(),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: AppColors.secondaryText,
                                              fontSize: 13,
                                              height: 1.3,
                                            ),
                                          ),
                                        ],

                                        // Temple Timings
                                        if (templeData['templeTimings'] !=
                                                null &&
                                            (templeData['templeTimings']
                                                    as List)
                                                .isNotEmpty) ...[
                                          const SizedBox(height: 6),
                                          Wrap(
                                            spacing: 6,
                                            runSpacing: 4,
                                            children: (templeData['templeTimings'] as List)
                                                .take(
                                                  2,
                                                ) // Show only first 2 timings
                                                .map(
                                                  (timing) => Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 8,
                                                          vertical: 3,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: const Color(
                                                        0xFF8B5CF6,
                                                      ).withValues(alpha: 0.1),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            8,
                                                          ),
                                                    ),
                                                    child: Text(
                                                      timing.toString(),
                                                      style: const TextStyle(
                                                        color: Color(
                                                          0xFF8B5CF6,
                                                        ),
                                                        fontSize: 10,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                      ),
                                                    ),
                                                  ),
                                                )
                                                .toList(),
                                          ),
                                        ],

                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            if (templeData['pujaPrice'] != null)
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 4,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: const Color(
                                                    0xFF10B981,
                                                  ).withValues(alpha: 0.1),
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                child: Text(
                                                  '₹${templeData['pujaPrice']}',
                                                  style: const TextStyle(
                                                    color:
                                                        AppColors.successGreen,
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                            const SizedBox(width: 8),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 4,
                                                  ),
                                              decoration: BoxDecoration(
                                                color:
                                                    (templeData['isActive'] ??
                                                        true)
                                                    ? const Color(
                                                        0xFF10B981,
                                                      ).withValues(alpha: 0.1)
                                                    : const Color(
                                                        0xFFEF4444,
                                                      ).withValues(alpha: 0.1),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                (templeData['isActive'] ?? true)
                                                    ? 'Active'
                                                    : 'Inactive',
                                                style: TextStyle(
                                                  color:
                                                      (templeData['isActive'] ??
                                                          true)
                                                      ? AppColors.successGreen
                                                      : AppColors.errorRed,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                            const Spacer(),
                                            if (templeData['createdAt'] != null)
                                              Text(
                                                _formatDate(
                                                  templeData['createdAt']
                                                      as Timestamp,
                                                ),
                                                style: const TextStyle(
                                                  color:
                                                      AppColors.secondaryText,
                                                  fontSize: 12,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
        floatingActionButton: ScaleTransition(
          scale: CurvedAnimation(
            parent: _fabAnimationController,
            curve: Curves.easeInOut,
          ),
          child: FloatingActionButton.extended(
            heroTag: "add_temple",
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const AddTempleScreen(),
                ),
              );
              // No manual reload needed — the realtime stream
              // (snapshots()) automatically emits the new temple.
            },
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
            elevation: 6,
            icon: const Icon(Icons.add_location_alt, size: 24),
            label: const Text(
              'Add Temple',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Mock TempleDocument for compatibility with EditTempleScreen
class _MockTempleDocument implements TempleDocument {
  final Map<String, dynamic> _data;
  final String _id;

  _MockTempleDocument(this._data, this._id);

  @override
  String get id => _id;

  @override
  bool get exists => true;

  @override
  Map<String, dynamic>? data() => _data;
}
