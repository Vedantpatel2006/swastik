import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../shared/models/temple.dart';
import '../../../core/themes/app_colors.dart';
import '../services/temple_status_service.dart';
import '../services/temple_share_service.dart';

/// Optimized temple card widget that minimizes setState calls and prevents overflow
/// This is a memory-optimized version of TempleCard for use in large lists
class OptimizedTempleCard extends StatelessWidget {
  final Temple temple;
  final VoidCallback? onTap;
  final VoidCallback? onFavoriteToggle;
  final VoidCallback? onBookingTap;
  final bool showDistance;
  final bool showLiveIndicator;
  final bool showBookingButton;
  final bool showStatusIndicator;
  final bool showShareButton;

  const OptimizedTempleCard({
    super.key,
    required this.temple,
    this.onTap,
    this.onFavoriteToggle,
    this.onBookingTap,
    this.showDistance = true,
    this.showLiveIndicator = true,
    this.showBookingButton = true,
    this.showStatusIndicator = true,
    this.showShareButton = true,
  });

  @override
  Widget build(BuildContext context) {
    return OptimizedTempleCardContent(
      temple: temple,
      onTap: onTap,
      onFavoriteToggle: onFavoriteToggle,
      onBookingTap: onBookingTap,
      showDistance: showDistance,
      showLiveIndicator: showLiveIndicator,
      showBookingButton: showBookingButton,
      showStatusIndicator: showStatusIndicator,
      showShareButton: showShareButton,
    );
  }
}

/// Optimized temple card content widget
class OptimizedTempleCardContent extends StatelessWidget {
  final Temple temple;
  final VoidCallback? onTap;
  final VoidCallback? onFavoriteToggle;
  final VoidCallback? onBookingTap;
  final bool showDistance;
  final bool showLiveIndicator;
  final bool showBookingButton;
  final bool showStatusIndicator;
  final bool showShareButton;

  const OptimizedTempleCardContent({
    super.key,
    required this.temple,
    this.onTap,
    this.onFavoriteToggle,
    this.onBookingTap,
    this.showDistance = true,
    this.showLiveIndicator = true,
    this.showBookingButton = true,
    this.showStatusIndicator = true,
    this.showShareButton = true,
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
          children: [
            OptimizedTempleImageSection(
              temple: temple,
              showLiveIndicator: showLiveIndicator,
              onFavoriteToggle: onFavoriteToggle,
            ),
            OptimizedTempleContentSection(
              temple: temple,
              showDistance: showDistance,
            ),
            if (showBookingButton || showStatusIndicator || showShareButton)
              OptimizedActionButtons(
                temple: temple,
                onBookingTap: onBookingTap,
                showBookingButton: showBookingButton,
                showStatusIndicator: showStatusIndicator,
                showShareButton: showShareButton,
              ),
          ],
        ),
      ),
    );
  }
}

/// Optimized temple image section widget
class OptimizedTempleImageSection extends StatelessWidget {
  final Temple temple;
  final bool showLiveIndicator;
  final VoidCallback? onFavoriteToggle;

  const OptimizedTempleImageSection({
    super.key,
    required this.temple,
    required this.showLiveIndicator,
    this.onFavoriteToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: temple.images.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: temple.images.first,
                    fit: BoxFit.cover,
                    memCacheWidth: 400, // Limit memory cache size
                    memCacheHeight: 225, // 16:9 aspect ratio
                    maxWidthDiskCache: 800, // Limit disk cache size
                    maxHeightDiskCache: 450,
                    placeholder: (context, url) => Container(
                      color: Colors.grey[200],
                      child: const Center(child: CircularProgressIndicator()),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: Colors.grey[200],
                      child: const Icon(
                        Icons.temple_hindu,
                        size: 48,
                        color: Colors.grey,
                      ),
                    ),
                  )
                : Container(
                    color: Colors.grey[200],
                    child: const Icon(
                      Icons.temple_hindu,
                      size: 48,
                      color: Colors.grey,
                    ),
                  ),
          ),
        ),
        // Live indicator (static, no animations to reduce memory usage)
        if (showLiveIndicator && temple.liveDarshan?.isCurrentlyLive == true)
          const Positioned(top: 8, left: 8, child: OptimizedLiveIndicator()),
        // Favorite button (static, no animations)
        if (onFavoriteToggle != null)
          Positioned(
            top: 8,
            right: 8,
            child: OptimizedFavoriteButton(
              temple: temple,
              onFavoriteToggle: onFavoriteToggle!,
            ),
          ),
      ],
    );
  }
}

/// Optimized live indicator widget
class OptimizedLiveIndicator extends StatelessWidget {
  const OptimizedLiveIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF4444), Color(0xFFCC0000)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withValues(alpha: 0.5),
            blurRadius: 8,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          const Text(
            'LIVE',
            style: TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// Optimized favorite button widget
class OptimizedFavoriteButton extends StatelessWidget {
  final Temple temple;
  final VoidCallback onFavoriteToggle;

  const OptimizedFavoriteButton({
    super.key,
    required this.temple,
    required this.onFavoriteToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: GestureDetector(
      behavior: HitTestBehavior.opaque,
        onTap: onFavoriteToggle,
        child: Icon(
          temple.isFavorite ? Icons.favorite : Icons.favorite_border,
          size: 20,
          color: temple.isFavorite ? Colors.red : Colors.grey[600],
        ),
      ),
    );
  }
}

/// Optimized temple content section widget
class OptimizedTempleContentSection extends StatelessWidget {
  final Temple temple;
  final bool showDistance;

  const OptimizedTempleContentSection({
    super.key,
    required this.temple,
    required this.showDistance,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Temple name with overflow protection
          Text(
            temple.name,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1F2937),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          // Location with overflow protection
          Row(
            children: [
              Icon(Icons.location_on, size: 14, color: Colors.grey[600]),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  '${temple.location.city ?? ''}, ${temple.location.state ?? ''}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Traditions with overflow protection
          if (temple.traditions.isNotEmpty)
            OptimizedTraditionsWidget(traditions: temple.traditions),
          const SizedBox(height: 8),
          // Distance and visit count with overflow protection
          OptimizedFooterWidget(temple: temple, showDistance: showDistance),
        ],
      ),
    );
  }
}

/// Optimized traditions widget
class OptimizedTraditionsWidget extends StatelessWidget {
  final List<String> traditions;

  const OptimizedTraditionsWidget({super.key, required this.traditions});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: traditions.take(2).map((tradition) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFFFF7A00).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            tradition,
            style: const TextStyle(
              fontSize: 10,
              color: Color(0xFFFF7A00),
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),
    );
  }
}

/// Optimized footer widget
class OptimizedFooterWidget extends StatelessWidget {
  final Temple temple;
  final bool showDistance;

  const OptimizedFooterWidget({
    super.key,
    required this.temple,
    required this.showDistance,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (showDistance && temple.distanceFromUser != null) ...[
          Icon(Icons.directions_walk, size: 14, color: Colors.grey[600]),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              '${temple.distanceFromUser!.toStringAsFixed(1)} km',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const Spacer(),
        ],
        if (temple.visitCount > 0) ...[
          Icon(Icons.people, size: 14, color: Colors.grey[600]),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              '${temple.visitCount} visits',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ],
    );
  }
}

/// Optimized action buttons widget
class OptimizedActionButtons extends StatelessWidget {
  final Temple temple;
  final VoidCallback? onBookingTap;
  final bool showBookingButton;
  final bool showStatusIndicator;
  final bool showShareButton;

  const OptimizedActionButtons({
    super.key,
    required this.temple,
    this.onBookingTap,
    required this.showBookingButton,
    required this.showStatusIndicator,
    required this.showShareButton,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        children: [
          if (showStatusIndicator) _buildStatusIndicator(),
          const Spacer(),
          if (showBookingButton && temple.acceptsBookings)
            _buildBookingButton(),
          if (showBookingButton && temple.acceptsBookings && showShareButton)
            const SizedBox(width: 8),
          if (showShareButton) _buildShareButton(context),
        ],
      ),
    );
  }

  Widget _buildStatusIndicator() {
    final status = TempleStatusService.getTempleStatus(temple);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: status.statusColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: status.statusColor.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: status.statusColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            status.getStatusWithTime(),
            style: TextStyle(
              color: status.statusColor,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildBookingButton() {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onBookingTap?.call();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          gradient: AppColors.orangeGradient,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryOrange.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.calendar_today, size: 14, color: Colors.white),
            const SizedBox(width: 6),
            const Text(
              'Book',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShareButton(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        TempleShareService.shareTemple(temple, context: context);
      },
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[300]!, width: 1),
        ),
        child: Icon(Icons.share, size: 16, color: Colors.grey[700]),
      ),
    );
  }
}

/// Efficient temple card builder for use in virtual scrolling
class TempleCardBuilder {
  /// Creates an optimized temple card with minimal memory footprint
  static Widget buildOptimized({
    required Temple temple,
    VoidCallback? onTap,
    VoidCallback? onFavoriteToggle,
    bool showDistance = true,
    bool showLiveIndicator = true,
  }) {
    return OptimizedTempleCard(
      temple: temple,
      onTap: onTap,
      onFavoriteToggle: onFavoriteToggle,
      showDistance: showDistance,
      showLiveIndicator: showLiveIndicator,
    );
  }

  /// Creates a temple card with error boundary
  static Widget buildSafe({
    required Temple temple,
    VoidCallback? onTap,
    VoidCallback? onFavoriteToggle,
    bool showDistance = true,
    bool showLiveIndicator = true,
    Widget? fallback,
  }) {
    return buildOptimized(
      temple: temple,
      onTap: onTap,
      onFavoriteToggle: onFavoriteToggle,
      showDistance: showDistance,
      showLiveIndicator: showLiveIndicator,
    );
  }
}
