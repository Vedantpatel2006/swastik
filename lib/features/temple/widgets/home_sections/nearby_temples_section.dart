import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../../../../shared/models/temple.dart';
import '../../../../core/themes/app_colors.dart';
import '../../services/temple_status_service.dart';

/// Nearby Temples Section
/// Layout: compact wide-card (landscape) horizontal scroll
/// Image left | Name, location, status, distance pill right
class NearbyTemplesSection extends StatelessWidget {
  final List<Temple> temples;
  final Function(Temple) onTempleTap;
  final VoidCallback? onEnableLocation;

  const NearbyTemplesSection({
    super.key,
    required this.temples,
    required this.onTempleTap,
    this.onEnableLocation,
  });

  @override
  Widget build(BuildContext context) {
    final nearbyTemples =
        temples.where((t) => t.distanceFromUser != null).toList()
          ..sort(
            (a, b) => (a.distanceFromUser ?? double.maxFinite)
                .compareTo(b.distanceFromUser ?? double.maxFinite),
          );

    final displayTemples = nearbyTemples.take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.near_me_rounded,
                    size: 20,
                    color: AppColors.primaryOrange,
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'Nearby',
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
                  ).pushNamed('/nearby'),
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

        displayTemples.isEmpty
            ? _buildEmptyState(context)
            : SizedBox(
                height: 160,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: displayTemples.length,
                  itemBuilder: (context, index) {
                    return _NearbyCard(
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

  Widget _buildEmptyState(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Icon + text row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryOrange.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.location_off_rounded,
                  size: 24,
                  color: AppColors.primaryOrange,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Location Not Available',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryText,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Enable location to find temples near you',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Enable Location button
          GestureDetector(
            onTap: onEnableLocation ?? () {},
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 9),
              decoration: BoxDecoration(
                color: AppColors.primaryOrange,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.my_location_rounded,
                    size: 14,
                    color: AppColors.white,
                  ),
                  SizedBox(width: 5),
                  Text(
                    'Enable Location',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NearbyCard extends StatelessWidget {
  final Temple temple;
  final VoidCallback onTap;
  final bool showMargin;

  const _NearbyCard({
    required this.temple,
    required this.onTap,
    this.showMargin = true,
  });

  @override
  Widget build(BuildContext context) {
    final status = TempleStatusService.getTempleStatus(temple);
    final distanceKm = temple.distanceFromUser;

    // Parse today's timing text for display (e.g. "6:00 AM - 9:00 PM")
    final timingDisplay = _getTodayTimingDisplay();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 310,
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
                width: 120,
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

                    // Opening / closing time line
                    if (timingDisplay != null)
                      Row(
                        children: [
                          Icon(
                            Icons.access_time_rounded,
                            size: 11,
                            color: status.isOpen
                                ? AppColors.successGreen
                                : AppColors.errorRed,
                          ),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              timingDisplay,
                              style: TextStyle(
                                fontSize: 11,
                                color: status.isOpen
                                    ? AppColors.successGreen
                                    : AppColors.errorRed,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),

                    // Open/Closed badge  +  Distance pill
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

                        // Distance pill
                        if (distanceKm != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primaryOrange.withValues(
                                alpha: 0.1,
                              ),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: AppColors.primaryOrange.withValues(
                                  alpha: 0.35,
                                ),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.near_me_rounded,
                                  size: 10,
                                  color: AppColors.primaryOrange,
                                ),
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
          ],
        ),
      ),
    );
  }

  /// Returns today's timing string, e.g. "6:00 AM – 9:00 PM"
  /// Returns null when no timing data is available.
  String? _getTodayTimingDisplay() {
    if (temple.timings.isEmpty) return null;
    final now = DateTime.now();
    final days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    final dayName = days[now.weekday - 1];
    final timing =
        temple.timings[dayName] ??
        temple.timings['Daily'] ??
        temple.timings['All Days'];
    if (timing == null || timing.trim().isEmpty) return null;
    // Normalise separator to en-dash for display
    return timing.replaceAll(' - ', ' – ');
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
