import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../../../shared/models/temple.dart';
import '../../../core/themes/app_colors.dart';
import '../services/user_temple_service.dart';
import 'temple_detail_screen.dart';

/// Best Partners Screen - Shows all partner temples in a grid layout
class BestPartnersScreen extends StatefulWidget {
  const BestPartnersScreen({super.key});

  @override
  State<BestPartnersScreen> createState() => _BestPartnersScreenState();
}

class _BestPartnersScreenState extends State<BestPartnersScreen> {
  final UserTempleService _templeService = UserTempleService();
  List<Temple> _temples = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadTemples();
  }

  Future<void> _loadTemples() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      await _templeService.initialize();
      final temples = await _templeService.searchTemples('');

      if (mounted) {
        setState(() {
          _temples = temples;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load temples';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back, size: 24),
        ),
        title: const Text(
          'Best Partners',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF172B4D),
          ),
        ),
      ),
      body: _isLoading
          ? _buildLoadingState()
          : _error != null
          ? _buildErrorState()
          : _buildGridContent(),
    );
  }

  Widget _buildLoadingState() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 6,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Shimmer.fromColors(
            baseColor: Colors.grey.shade300,
            highlightColor: Colors.grey.shade100,
            child: Container(
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            _error ?? 'An error occurred',
            style: const TextStyle(fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _loadTemples, child: const Text('Retry')),
        ],
      ),
    );
  }

  Widget _buildGridContent() {
    if (_temples.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.temple_hindu, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No temples found',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _temples.length,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _buildTempleCard(_temples[index]),
        );
      },
    );
  }

  Widget _buildTempleCard(Temple temple) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TempleDetailScreen(temple: temple),
          ),
        );
      },
      child: Container(
        height: 120,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
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
                left: Radius.circular(15),
              ),
              child: Stack(
                children: [
                  temple.images.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: temple.images.first,
                          height: 120,
                          width: 120,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Shimmer.fromColors(
                            baseColor: const Color(0xFFF8F9FA),
                            highlightColor: Colors.white,
                            child: Container(
                              height: 120,
                              width: 120,
                              color: const Color(0xFFF8F9FA),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            height: 120,
                            width: 120,
                            color: const Color(0xFFF8F9FA),
                            child: const Icon(
                              Icons.temple_hindu,
                              size: 40,
                              color: AppColors.secondaryText,
                            ),
                          ),
                        )
                      : Container(
                          height: 120,
                          width: 120,
                          color: const Color(0xFFF8F9FA),
                          child: const Icon(
                            Icons.temple_hindu,
                            size: 40,
                            color: AppColors.secondaryText,
                          ),
                        ),
                  // Live Badge
                  if (temple.liveDarshan?.isCurrentlyLive == true)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.circle, size: 8, color: Colors.white),
                            SizedBox(width: 4),
                            Text(
                              'LIVE',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Name and Location
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          temple.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryText,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        if (temple.location.city != null)
                          Row(
                            children: [
                              const Icon(
                                Icons.location_on,
                                size: 14,
                                color: AppColors.secondaryText,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  temple.location.city!,
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
                      ],
                    ),

                    // Rating and Distance
                    Row(
                      children: [
                        // Rating
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.walletOrange,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.star,
                                size: 12,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                temple.averageRating.toStringAsFixed(1),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(width: 12),

                        // Distance
                        if (temple.distanceFromUser != null)
                          Row(
                            children: [
                              const Icon(
                                Icons.directions_walk,
                                size: 14,
                                color: AppColors.secondaryText,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${temple.distanceFromUser!.toStringAsFixed(1)} km',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.secondaryText,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
