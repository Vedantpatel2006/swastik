import 'package:flutter/material.dart';
import '../../../core/themes/app_colors.dart';
import '../../../shared/models/temple.dart';
import '../../../shared/widgets/maps/static_map_preview.dart';

/// Temple card widget with static map preview for better memory efficiency
class TempleCardWithMap extends StatelessWidget {
  final Temple temple;
  final VoidCallback? onTap;
  final VoidCallback? onFavoriteToggle;
  final bool showDistance;
  final bool showLiveIndicator;
  final bool useStaticMap;

  const TempleCardWithMap({
    super.key,
    required this.temple,
    this.onTap,
    this.onFavoriteToggle,
    this.showDistance = false,
    this.showLiveIndicator = true,
    this.useStaticMap = true,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [_buildImageSection(), _buildContentSection()],
        ),
      ),
    );
  }

  Widget _buildImageSection() {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
          child: SizedBox(
            height: 200,
            width: double.infinity,
            child: temple.images.isNotEmpty
                ? Image.network(
                    temple.images.first,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        _buildImageFallback(),
                  )
                : _buildImageFallback(),
          ),
        ),

        // Live indicator
        if (showLiveIndicator && temple.liveDarshan?.isCurrentlyLive == true)
          Positioned(
            top: 8,
            left: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.liveRed,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'LIVE',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

        // Favorite button
        Positioned(
          top: 8,
          right: 8,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onFavoriteToggle,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.9),
                shape: BoxShape.circle,
              ),
              child: Icon(
                temple.isFavorite ? Icons.favorite : Icons.favorite_border,
                color: temple.isFavorite
                    ? AppColors.errorRed
                    : AppColors.disabledText,
                size: 20,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildImageFallback() {
    return Container(
      color: AppColors.mediumGray,
      child: const Center(
        child: Icon(
          Icons.temple_hindu,
          size: 48,
          color: AppColors.disabledText,
        ),
      ),
    );
  }

  Widget _buildContentSection() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  temple.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          const SizedBox(height: 4),

          Text(
            '${temple.location.city ?? ''}, ${temple.location.state ?? ''}',
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.secondaryText,
            ),
          ),

          const SizedBox(height: 8),

          Row(
            children: [
              if (showDistance && temple.distanceFromUser != null)
                Expanded(
                  child: Row(
                    children: [
                      const Icon(
                        Icons.location_on,
                        size: 16,
                        color: AppColors.secondaryText,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${temple.distanceFromUser!.toStringAsFixed(1)} km away',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.secondaryText,
                        ),
                      ),
                    ],
                  ),
                ),

              if (useStaticMap)
                CompactStaticMapPreview(
                  latitude: temple.location.latitude,
                  longitude: temple.location.longitude,
                  size: 50,
                  onTap: () {
                    _showFullMapView();
                  },
                ),
            ],
          ),

          const SizedBox(height: 8),

          if (temple.timings.isNotEmpty)
            Row(
              children: [
                const Icon(
                  Icons.access_time,
                  size: 16,
                  color: AppColors.secondaryText,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    temple.timings.values.first,
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
    );
  }

  void _showFullMapView() {
    // This would open a full map view with the temple location
  }
}

/// Compact temple card for grid views with static map
class CompactTempleCardWithMap extends StatelessWidget {
  final Temple temple;
  final VoidCallback? onTap;
  final VoidCallback? onFavoriteToggle;

  const CompactTempleCardWithMap({
    super.key,
    required this.temple,
    this.onTap,
    this.onFavoriteToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(12),
                    ),
                    child: Container(
                      width: double.infinity,
                      color: AppColors.mediumGray,
                      child: temple.images.isNotEmpty
                          ? Image.network(
                              temple.images.first,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  const Icon(Icons.temple_hindu, size: 32),
                            )
                          : const Icon(Icons.temple_hindu, size: 32),
                    ),
                  ),

                  // Live indicator
                  if (temple.liveDarshan?.isCurrentlyLive == true)
                    Positioned(
                      top: 4,
                      left: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.liveRed,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'LIVE',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),

                  // Favorite button
                  Positioned(
                    top: 4,
                    right: 4,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: onFavoriteToggle,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.9),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          temple.isFavorite
                              ? Icons.favorite
                              : Icons.favorite_border,
                          color: temple.isFavorite
                              ? AppColors.errorRed
                              : AppColors.disabledText,
                          size: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      temple.name,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${temple.location.city ?? ''}, ${temple.location.state ?? ''}',
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.secondaryText,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),

                    Align(
                      alignment: Alignment.centerRight,
                      child: CompactStaticMapPreview(
                        latitude: temple.location.latitude,
                        longitude: temple.location.longitude,
                        size: 24,
                        onTap: onTap,
                      ),
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
