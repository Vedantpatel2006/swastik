import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../../../shared/models/temple.dart';
import '../../../shared/models/temple_filters.dart';
import '../services/user_temple_service.dart';
import '../services/temple_status_service.dart';
import '../screens/temple_detail_screen.dart';
import '../../../core/themes/app_colors.dart';
import '../../user/services/location_select_service.dart';
import '../../user/widgets/location_selector_bottom_sheet.dart';

/// Nearby Temples Screen
/// Shows all temples sorted by distance from the user's current location.
/// Includes a search bar to filter by name.
class NearbyScreen extends StatefulWidget {
  const NearbyScreen({super.key});

  @override
  State<NearbyScreen> createState() => _NearbyScreenState();
}

class _NearbyScreenState extends State<NearbyScreen> {
  final UserTempleService _templeService = UserTempleService();
  final LocationSelectService _locationSelectService = LocationSelectService();
  final TextEditingController _searchController = TextEditingController();

  List<Temple> _allNearby = [];
  List<Temple> _filtered = [];
  bool _isLoading = true;
  String? _error;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _locationSelectService.initialize().then((_) => _loadTemples());
    _searchController.addListener(_onQueryChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onQueryChanged() {
    final q = _searchController.text.trim().toLowerCase();
    if (q == _query) return;
    setState(() {
      _query = q;
      _filtered = _applyFilter(_allNearby, q);
    });
  }

  List<Temple> _applyFilter(List<Temple> temples, String q) {
    if (q.isEmpty) return temples;
    return temples
        .where((t) => t.name.toLowerCase().contains(q))
        .toList();
  }

  Future<void> _loadTemples() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await _templeService.initialize();

      final userLocation = _locationSelectService.getCurrentLocationObject();
      final filters = userLocation != null
          ? TempleFilters(userLocation: userLocation)
          : null;

      final temples = await _templeService.searchTemples('', filters: filters);

      // Keep only temples that have a calculated distance, sorted nearest first
      final nearby = temples
          .where((t) => t.distanceFromUser != null)
          .toList()
        ..sort(
          (a, b) => (a.distanceFromUser ?? double.maxFinite)
              .compareTo(b.distanceFromUser ?? double.maxFinite),
        );

      if (mounted) {
        setState(() {
          _allNearby = nearby;
          _filtered = _applyFilter(nearby, _query);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load nearby temples. Please try again.';
          _isLoading = false;
        });
      }
    }
  }

  void _showLocationSelector() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        builder: (context, scrollController) => LocationSelectorBottomSheet(
          currentLocation: 'Current Location',
          onLocationSelected: (_) => _loadTemples(),
        ),
      ),
    );
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
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.white, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Row(
          children: [
            Icon(Icons.near_me_rounded, color: AppColors.white, size: 20),
            SizedBox(width: 8),
            Text(
              'Nearby Temples',
              style: TextStyle(
                color: AppColors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Change location',
            icon: const Icon(Icons.my_location_rounded,
                color: AppColors.white, size: 22),
            onPressed: _showLocationSelector,
          ),
        ],
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
                  hintText: 'Search nearby temples...',
                  hintStyle: const TextStyle(
                    color: AppColors.disabledText,
                    fontSize: 14,
                  ),
                  prefixIcon: const Icon(Icons.search,
                      color: AppColors.disabledText, size: 20),
                  suffixIcon: _query.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear,
                              color: AppColors.disabledText, size: 18),
                          onPressed: () {
                            _searchController.clear();
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                ),
              ),
            ),
          ),

          // Results count
          if (!_isLoading && _error == null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Text(
                    _filtered.isEmpty
                        ? 'No temples found'
                        : '${_filtered.length} temple${_filtered.length == 1 ? '' : 's'} nearby',
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
      onRefresh: _loadTemples,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        itemCount: _filtered.length,
        itemBuilder: (context, index) {
          return _NearbyListCard(
            temple: _filtered[index],
            onTap: () => _onTempleTap(_filtered[index]),
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
            const Icon(Icons.error_outline_rounded,
                size: 56, color: AppColors.errorRed),
            const SizedBox(height: 16),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 14, color: AppColors.secondaryText),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _loadTemples,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryOrange,
                foregroundColor: AppColors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final hasLocation =
        _locationSelectService.getCurrentLocationObject() != null;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasLocation
                  ? Icons.temple_hindu_outlined
                  : Icons.location_off_rounded,
              size: 64,
              color: AppColors.primaryOrange.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              hasLocation
                  ? (_query.isNotEmpty
                      ? 'No temples match "$_query"'
                      : 'No temples found nearby')
                  : 'Location not available',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.primaryText,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              hasLocation
                  ? (_query.isNotEmpty
                      ? 'Try a different search term'
                      : 'Try expanding your search area')
                  : 'Enable location to find temples near you',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 13, color: AppColors.secondaryText),
            ),
            if (!hasLocation) ...[
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _showLocationSelector,
                icon: const Icon(Icons.my_location_rounded),
                label: const Text('Set Location'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryOrange,
                  foregroundColor: AppColors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// List card widget
// ---------------------------------------------------------------------------

class _NearbyListCard extends StatelessWidget {
  final Temple temple;
  final VoidCallback onTap;

  const _NearbyListCard({required this.temple, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final status = TempleStatusService.getTempleStatus(temple);
    final distanceKm = temple.distanceFromUser;

    return GestureDetector(
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
                  left: Radius.circular(14)),
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
                    horizontal: 12, vertical: 10),
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
                        const Icon(Icons.location_on,
                            size: 12, color: AppColors.secondaryText),
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

                    // Status + Distance
                    Row(
                      children: [
                        // Open / Closed pill
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
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

                        // Distance pill
                        if (distanceKm != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 9, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.primaryOrange
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: AppColors.primaryOrange
                                    .withValues(alpha: 0.35),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.near_me_rounded,
                                    size: 10,
                                    color: AppColors.primaryOrange),
                                const SizedBox(width: 3),
                                Text(
                                  '${distanceKm.toStringAsFixed(1)} km',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primaryOrange,
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
              child: Icon(Icons.chevron_right_rounded,
                  color: AppColors.disabledText, size: 20),
            ),
          ],
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
        child: const Icon(Icons.temple_hindu,
            size: 32, color: AppColors.secondaryText),
      ),
    );
  }
}
