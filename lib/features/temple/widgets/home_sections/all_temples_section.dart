import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../../../../shared/models/temple.dart';
import '../../../../core/themes/app_colors.dart';
import '../../../../shared/constants/deity_assets.dart';
import '../../services/temple_status_service.dart';

/// All Temples Section — 2-column photo grid with deity filter chips
class AllTemplesSection extends StatefulWidget {
  final List<Temple> temples;
  final Function(Temple) onTempleTap;

  const AllTemplesSection({
    super.key,
    required this.temples,
    required this.onTempleTap,
  });

  @override
  State<AllTemplesSection> createState() => _AllTemplesSectionState();
}

class _AllTemplesSectionState extends State<AllTemplesSection> {
  String _selectedDeityFilter = 'All';

  @override
  Widget build(BuildContext context) {
    final filteredTemples = _selectedDeityFilter == 'All'
        ? widget.temples
        : widget.temples
              .where(
                (t) =>
                    DeityAssets.matchesDeity(t.mainDeity, _selectedDeityFilter),
              )
              .toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          const Text(
            'All Temples',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.primaryText,
            ),
          ),

          const SizedBox(height: 14),

          // Deity filter chips — horizontal scroll
          SizedBox(
            height: 90,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: DeityAssets.deityCategories.length,
              itemBuilder: (context, index) {
                final deity = DeityAssets.deityCategories[index];
                final name = deity['name'] as String;
                final isSelected = _selectedDeityFilter == name;

                return GestureDetector(
                  onTap: () => setState(() => _selectedDeityFilter = name),
                  child: Container(
                    width: 64,
                    margin: const EdgeInsets.only(right: 10),
                    child: Column(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 54,
                          height: 54,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primaryOrange.withValues(alpha: 0.1)
                                : AppColors.lightGray,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.primaryOrange
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.asset(
                              deity['image'] as String,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Icon(
                                Icons.temple_hindu,
                                size: 26,
                                color: isSelected
                                    ? AppColors.primaryOrange
                                    : AppColors.secondaryText,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          name,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: isSelected
                                ? AppColors.primaryOrange
                                : AppColors.secondaryText,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 14),

          // 2-column photo grid
          filteredTemples.isEmpty
              ? _buildEmptyState()
              : GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.8,
                  ),
                  itemCount: filteredTemples.length,
                  itemBuilder: (context, index) {
                    return _TempleGridCell(
                      temple: filteredTemples[index],
                      onTap: () => widget.onTempleTap(filteredTemples[index]),
                    );
                  },
                ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.temple_hindu, size: 48, color: AppColors.borderGray),
            const SizedBox(height: 12),
            const Text(
              'No temples found',
              style: TextStyle(fontSize: 14, color: AppColors.secondaryText),
            ),
            const SizedBox(height: 4),
            const Text(
              'Try selecting a different deity',
              style: TextStyle(fontSize: 12, color: AppColors.disabledText),
            ),
          ],
        ),
      ),
    );
  }
}

class _TempleGridCell extends StatelessWidget {
  final Temple temple;
  final VoidCallback onTap;

  const _TempleGridCell({required this.temple, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final status = TempleStatusService.getTempleStatus(temple);

    return GestureDetector(
      onTap: onTap,
      child: Container(
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            Expanded(
              flex: 6,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(14),
                    ),
                    child: _buildImage(),
                  ),
                ],
              ),
            ),

            // Text info
            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Name
                    Text(
                      temple.name,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryText,
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),

                    // Location
                    Text(
                      _locationText(),
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.secondaryText,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),

                    // Open/Closed badge with time
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: status.isOpen
                            ? AppColors.successGreen.withValues(alpha: 0.12)
                            : AppColors.errorRed.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        status.getStatusWithTime(),
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: status.isOpen
                              ? AppColors.successGreen
                              : AppColors.errorRed,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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

  Widget _buildImage() {
    const placeholders = [
      'assets/images/deities/ganesha.png',
      'assets/images/deities/krishna.png',
      'assets/images/deities/hanuman.png',
      'assets/images/deities/durga.png',
      'assets/images/deities/lakshmi.png',
      'assets/images/deities/vishnu.png',
      'assets/images/deities/temple.png',
    ];

    if (temple.images.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: temple.images.first,
        fit: BoxFit.cover,
        placeholder: (_, __) => Shimmer.fromColors(
          baseColor: AppColors.lightGray,
          highlightColor: AppColors.white,
          child: Container(color: AppColors.lightGray),
        ),
        errorWidget: (_, __, ___) => Image.asset(
          placeholders[temple.id.hashCode % placeholders.length],
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            color: AppColors.lightGray,
            child: const Icon(
              Icons.temple_hindu,
              color: AppColors.secondaryText,
              size: 36,
            ),
          ),
        ),
      );
    }

    return Image.asset(
      placeholders[temple.id.hashCode % placeholders.length],
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(
        color: AppColors.lightGray,
        child: const Icon(
          Icons.temple_hindu,
          color: AppColors.secondaryText,
          size: 36,
        ),
      ),
    );
  }

  String _locationText() {
    final parts = <String>[];
    if (temple.location.city?.isNotEmpty == true)
      parts.add(temple.location.city!);
    if (temple.location.state?.isNotEmpty == true)
      parts.add(temple.location.state!);
    return parts.isEmpty ? 'Location not available' : parts.join(', ');
  }
}
