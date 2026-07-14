import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../../../core/themes/app_colors.dart';
import '../../../shared/models/temple.dart';
import '../services/favorites_service.dart';
import '../services/user_temple_service.dart';
import '../services/temple_status_service.dart';
import 'temple_detail_screen.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  final FavoritesService _favoritesService = FavoritesService();
  final UserTempleService _templeService = UserTempleService();
  final TextEditingController _searchController = TextEditingController();

  List<Temple> _allFavorites = [];
  List<Temple> _filtered = [];
  bool _isLoading = true;
  String? _error;
  String _query = '';

  StreamSubscription? _favoritesSubscription;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onQueryChanged);
    _initializeServices();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _favoritesSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initializeServices() async {
    try {
      await _favoritesService.initialize();
      await _templeService.initialize();
      await _loadData();
      _setupStreams();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to initialize. Please try again.';
          _isLoading = false;
        });
      }
    }
  }

  void _setupStreams() {
    _favoritesSubscription = _favoritesService.watchFavorites().listen(
      (favoriteIds) => _loadFavoriteTemples(favoriteIds),
      onError: (e) {
        if (mounted) setState(() => _error = 'Error loading favourites.');
      },
    );
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final ids = await _favoritesService.getFavoriteTempleIds();
      await _loadFavoriteTemples(ids);
      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load favourites. Please try again.';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadFavoriteTemples(List<String> ids) async {
    if (ids.isEmpty) {
      if (mounted) {
        setState(() {
          _allFavorites = [];
          _filtered = [];
        });
      }
      return;
    }

    final futures = ids.map((id) async {
      try {
        final t = await _templeService
            .getTempleDetails(id)
            .timeout(const Duration(seconds: 10), onTimeout: () => null);
        return t != null ? t.copyWith(isFavorite: true) : null;
      } catch (_) {
        return null;
      }
    });

    final results = await Future.wait(futures);
    final temples = results.whereType<Temple>().toList();

    if (mounted) {
      setState(() {
        _allFavorites = temples;
        _filtered = _applyFilter(temples, _query);
      });
    }
  }

  void _onQueryChanged() {
    final q = _searchController.text.trim().toLowerCase();
    if (q == _query) return;
    setState(() {
      _query = q;
      _filtered = _applyFilter(_allFavorites, q);
    });
  }

  List<Temple> _applyFilter(List<Temple> temples, String q) {
    if (q.isEmpty) return temples;
    return temples.where((t) {
      return t.name.toLowerCase().contains(q) ||
          (t.location.city?.toLowerCase().contains(q) ?? false) ||
          (t.location.state?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  Future<void> _removeFavorite(Temple temple) async {
    try {
      await _favoritesService.removeFromFavorites(temple.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Removed ${temple.name} from favourites'),
            action: SnackBarAction(
              label: 'Undo',
              onPressed: () => _favoritesService.addToFavorites(temple.id),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to remove: $e')),
        );
      }
    }
  }

  void _onTempleTap(Temple temple) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TempleDetailScreen(temple: temple),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: AppColors.primaryOrange,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppColors.white,
            size: 20,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Row(
          children: [
            Icon(Icons.favorite_rounded, color: AppColors.white, size: 20),
            SizedBox(width: 8),
            Text(
              'My Favourites',
              style: TextStyle(
                color: AppColors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search favourites...',
                  hintStyle: const TextStyle(
                    color: AppColors.disabledText,
                    fontSize: 14,
                  ),
                  prefixIcon: const Icon(
                    Icons.search,
                    color: AppColors.disabledText,
                    size: 20,
                  ),
                  suffixIcon: _query.isNotEmpty
                      ? IconButton(
                          icon: const Icon(
                            Icons.clear,
                            color: AppColors.disabledText,
                            size: 18,
                          ),
                          onPressed: () => _searchController.clear(),
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
              ),
            ),
          ),

          // Count label
          if (!_isLoading && _error == null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Text(
                    _filtered.isEmpty
                        ? 'No favourites found'
                        : '${_filtered.length} favourite${_filtered.length == 1 ? '' : 's'}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.secondaryText,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

          // Content
          Expanded(
            child: _isLoading
                ? _buildLoadingState()
                : _error != null
                ? _buildErrorState()
                : _filtered.isEmpty
                ? _buildEmptyState()
                : _buildList(),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    return RefreshIndicator(
      color: AppColors.primaryOrange,
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        itemCount: _filtered.length,
        itemBuilder: (context, index) {
          final temple = _filtered[index];
          return _FavouriteListCard(
            temple: temple,
            onTap: () => _onTempleTap(temple),
            onRemove: () => _removeFavorite(temple),
          );
        },
      ),
    );
  }

  Widget _buildLoadingState() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: 6,
      itemBuilder: (_, __) => Shimmer.fromColors(
        baseColor: AppColors.lightGray,
        highlightColor: AppColors.white,
        child: Container(
          height: 110,
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(14),
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
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 56,
              color: AppColors.errorRed,
            ),
            const SizedBox(height: 16),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.secondaryText,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryOrange,
                foregroundColor: AppColors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _query.isNotEmpty
                  ? Icons.search_off_rounded
                  : Icons.favorite_border_rounded,
              size: 64,
              color: AppColors.primaryOrange.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              _query.isNotEmpty
                  ? 'No favourites match "$_query"'
                  : 'No favourites yet',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.primaryText,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _query.isNotEmpty
                  ? 'Try a different search term'
                  : 'Tap the ♥ on any temple to save it here',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.secondaryText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Favourite list card — same compact landscape style as NearbyScreen
// ---------------------------------------------------------------------------

class _FavouriteListCard extends StatelessWidget {
  final Temple temple;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _FavouriteListCard({
    required this.temple,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final status = TempleStatusService.getTempleStatus(temple);

    return Dismissible(
      key: Key('fav_${temple.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppColors.errorRed,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.delete_rounded, color: AppColors.white, size: 22),
            SizedBox(height: 4),
            Text(
              'Remove',
              style: TextStyle(
                color: AppColors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Remove Favourite'),
                content: Text(
                  'Remove ${temple.name} from your favourites?',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.errorRed,
                    ),
                    child: const Text('Remove'),
                  ),
                ],
              ),
            ) ??
            false;
      },
      onDismissed: (_) => onRemove(),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 110,
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: AppColors.black.withValues(alpha: 0.06),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              // Image
              ClipRRect(
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(14),
                ),
                child: SizedBox(
                  width: 100,
                  height: 110,
                  child: temple.images.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: temple.images.first,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Shimmer.fromColors(
                            baseColor: AppColors.lightGray,
                            highlightColor: AppColors.white,
                            child: Container(color: AppColors.lightGray),
                          ),
                          errorWidget: (_, __, ___) => _placeholder(),
                        )
                      : _placeholder(),
                ),
              ),

              // Info
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Name
                      Text(
                        temple.name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryText,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),

                      // Location
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on,
                            size: 12,
                            color: AppColors.secondaryText,
                          ),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              _locationText(),
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.secondaryText,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),

                      // Status + Saved pill
                      Row(
                        children: [
                          // Open / Closed pill
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: status.isOpen
                                  ? AppColors.successGreen
                                  : AppColors.errorRed,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              status.isOpen ? 'Open' : 'Closed',
                              style: const TextStyle(
                                fontSize: 10,
                                color: AppColors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),

                          const Spacer(),

                          // Saved heart pill
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.red.withValues(alpha: 0.35),
                                width: 1,
                              ),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.favorite_rounded,
                                  size: 10,
                                  color: Colors.red,
                                ),
                                SizedBox(width: 3),
                                Text(
                                  'Saved',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.red,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Chevron
              const Padding(
                padding: EdgeInsets.only(right: 10),
                child: Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.disabledText,
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _locationText() {
    final parts = <String>[];
    if (temple.location.city?.isNotEmpty == true) {
      parts.add(temple.location.city!);
    }
    if (temple.location.state?.isNotEmpty == true) {
      parts.add(temple.location.state!);
    }
    return parts.isEmpty ? 'Location not available' : parts.join(', ');
  }

  Widget _placeholder() {
    const images = [
      'assets/images/deities/ganesha.png',
      'assets/images/deities/krishna.png',
      'assets/images/deities/hanuman.png',
      'assets/images/deities/durga.png',
      'assets/images/deities/temple.png',
    ];
    return Image.asset(
      images[temple.id.hashCode % images.length],
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(
        color: AppColors.lightGray,
        child: const Icon(
          Icons.temple_hindu,
          size: 32,
          color: AppColors.secondaryText,
        ),
      ),
    );
  }
}
