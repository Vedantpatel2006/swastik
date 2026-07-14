import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../../../../shared/models/temple.dart';
import '../../../../core/themes/app_colors.dart';
import '../../services/temple_status_service.dart';

/// Favourite Temples Section
///
/// • When the user has favourites → horizontal scroll of favourite temple cards
///   (same compact landscape card style as NearbyTemplesSection).
/// • When the user has NO favourites → a single entry-point card that invites
///   them to explore and save temples (same card dimensions / style).
class FavouriteTemplesSection extends StatelessWidget {
  final List<Temple> temples;
  final Function(Temple) onTempleTap;

  const FavouriteTemplesSection({
    super.key,
    required this.temples,
    required this.onTempleTap,
  });

  @override
  Widget build(BuildContext context) {
    final displayTemples = temples
        .where((temple) => temple.isFavorite)
        .take(5)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header ──────────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.favorite_rounded,
                    size: 20,
                    color: AppColors.primaryOrange,
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'Favourites',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryText,
                    ),
                  ),
                ],
              ),
              if (displayTemples.isNotEmpty)
                TextButton(
                  onPressed: () => Navigator.of(
                    context,
                    rootNavigator: true,
                  ).pushNamed('/fav_temples'),
                  child: const Text(
                    'See all',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.primaryOrange,
                    ),
                  ),
                ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // ── Body ─────────────────────────────────────────────────────────────
        displayTemples.isEmpty
            ? _buildEmptyEntryCard(context)
            : SizedBox(
                height: 160,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: displayTemples.length,
                  itemBuilder: (context, index) {
                    return _FavouriteCard(
                      temple: displayTemples[index],
                      onTap: () => onTempleTap(displayTemples[index]),
                      showMargin: index < displayTemples.length - 1,
                    );
                  },
                ),
              ),
      ],
    );
  }

  /// Entry-point card shown when the user has no favourites yet.
  /// Matches the exact dimensions and shadow style of the Nearby card.
  Widget _buildEmptyEntryCard(BuildContext context) {
    return GestureDetector(
      onTap: () =>
          Navigator.of(context, rootNavigator: true).pushNamed('/fav_temples'),
      child: Container(
        height: 112,
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: AppColors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Left icon in a soft orange circle
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.primaryOrange.withValues(alpha: 0.10),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.primaryOrange.withValues(alpha: 0.25),
                  width: 1.5,
                ),
              ),
              child: const Icon(
                Icons.favorite_border_rounded,
                size: 26,
                color: AppColors.primaryOrange,
              ),
            ),

            const SizedBox(width: 14),

            // Text
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'No Favourites Yet',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryText,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Tap the ♥ on any temple to save it here for quick access.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.secondaryText,
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            // Arrow
            const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: AppColors.secondaryText,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Favourite temple card — same compact landscape style as _NearbyCard
// ─────────────────────────────────────────────────────────────────────────────

class _FavouriteCard extends StatelessWidget {
  final Temple temple;
  final VoidCallback onTap;
  final bool showMargin;

  const _FavouriteCard({
    required this.temple,
    required this.onTap,
    this.showMargin = true,
  });

  @override
  Widget build(BuildContext context) {
    final status = TempleStatusService.getTempleStatus(temple);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 270,
        height: 160,
        margin: EdgeInsets.only(right: showMargin ? 12 : 0),
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
            // Left: image
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(14),
              ),
              child: SizedBox(
                width: 100,
                height: 160,
                child: temple.images.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: temple.images.first,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Shimmer.fromColors(
                          baseColor: AppColors.lightGray,
                          highlightColor: AppColors.white,
                          child: Container(color: AppColors.lightGray),
                        ),
                        errorWidget: (_, __, ___) => _placeholder(),
                      )
                    : _placeholder(),
              ),
            ),

            // Right: info
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
                    // Temple name
                    Text(
                      temple.name,
                      style: const TextStyle(
                        fontSize: 13,
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
                          size: 11,
                          color: AppColors.secondaryText,
                        ),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            _locationText(),
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.secondaryText,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),

                    // Open/Closed pill  +  Saved pill
                    Row(
                      children: [
                        // Open / Closed pill
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
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

                        // Favourite heart pill
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 4,
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
        child: const Icon(
          Icons.temple_hindu,
          size: 36,
          color: AppColors.secondaryText,
        ),
      ),
    );
  }
}
