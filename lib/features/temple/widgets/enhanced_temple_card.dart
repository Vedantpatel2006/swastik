import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../../../core/themes/app_colors.dart';
import '../../../shared/models/temple.dart';
import '../services/temple_status_service.dart';
import 'pulsing_live_badge.dart';

class EnhancedTempleCard extends StatelessWidget {
  final Temple temple;
  final VoidCallback? onTap;
  final VoidCallback? onFavoriteToggle;
  final VoidCallback? onLiveDarshanTap;
  final int? index;

  const EnhancedTempleCard({
    super.key,
    required this.temple,
    this.onTap,
    this.onFavoriteToggle,
    this.onLiveDarshanTap,
    this.index,
  });

  @override
  Widget build(BuildContext context) {
    final isLive = temple.liveDarshan?.isCurrentlyLive == true;
    final status = TempleStatusService.getTempleStatus(temple);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
            spreadRadius: -2,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                _buildImage(),
                const SizedBox(width: 14),
                Expanded(child: _buildInfo(isLive, status)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Image with shimmer placeholder ──────────────────────────────────────────

  Widget _buildImage() {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: temple.images.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: temple.images.first,
                width: 80,
                height: 80,
                fit: BoxFit.cover,
                placeholder: (context, url) => Shimmer.fromColors(
                  baseColor: AppColors.lightGray,
                  highlightColor: AppColors.white,
                  child: Container(
                    width: 80,
                    height: 80,
                    color: AppColors.lightGray,
                  ),
                ),
                errorWidget: (context, url, error) => _fallbackImage(),
              )
            : _fallbackImage(),
      ),
    );
  }

  Widget _fallbackImage() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.orange.shade300, Colors.orange.shade500],
        ),
      ),
      child: const Center(
        child: Icon(Icons.temple_hindu, color: Colors.white, size: 32),
      ),
    );
  }

  // ── Info column ─────────────────────────────────────────────────────────────

  Widget _buildInfo(bool isLive, TempleStatus status) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Row 1 — Name + LIVE badge
        Row(
          children: [
            Expanded(
              child: Text(
                temple.name,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1A1A),
                  height: 1.3,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isLive) ...[const SizedBox(width: 8), const PulsingLiveBadge()],
          ],
        ),

        // Row 2 — Deity name (if available)
        if (temple.mainDeity != null && temple.mainDeity!.isNotEmpty) ...[
          const SizedBox(height: 3),
          Row(
            children: [
              const Icon(
                Icons.auto_awesome,
                size: 11,
                color: AppColors.primaryOrange,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  temple.mainDeity!,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.primaryOrange,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],

        const SizedBox(height: 5),

        // Row 3 — Location
        if (temple.location.city != null)
          Row(
            children: [
              Icon(Icons.location_on, size: 13, color: Colors.grey.shade500),
              const SizedBox(width: 3),
              Expanded(
                child: Text(
                  temple.location.city!,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w400,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

        const SizedBox(height: 7),

        // Row 4 — Open/Closed | Distance | Rating | Actions
        Row(
          children: [
            // Open / Closed badge
            _buildStatusBadge(status),

            const SizedBox(width: 8),

            // Distance
            if (temple.distanceFromUser != null) ...[
              const Icon(
                Icons.navigation,
                size: 11,
                color: AppColors.primaryOrange,
              ),
              const SizedBox(width: 3),
              Text(
                '${temple.distanceFromUser!.toStringAsFixed(1)} km',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.primaryText,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 8),
            ],

            // Rating
            if (temple.averageRating > 0) ...[
              Icon(Icons.star, size: 13, color: Colors.amber.shade600),
              const SizedBox(width: 3),
              Text(
                temple.averageRating.toStringAsFixed(1),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
            ],

            const Spacer(),

            // Action icons
            if (onFavoriteToggle != null)
              GestureDetector(
                onTap: onFavoriteToggle,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    temple.isFavorite ? Icons.favorite : Icons.favorite_border,
                    size: 18,
                    color: temple.isFavorite
                        ? Colors.red
                        : Colors.grey.shade400,
                  ),
                ),
              ),

            if (isLive && onLiveDarshanTap != null) ...[
              const SizedBox(width: 4),
              GestureDetector(
                onTap: onLiveDarshanTap,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    Icons.play_circle_filled,
                    size: 18,
                    color: Colors.red.shade600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildStatusBadge(TempleStatus status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: status.isOpen ? AppColors.successGreen : AppColors.errorRed,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        status.getStatusWithTime(),
        style: const TextStyle(
          fontSize: 9,
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
