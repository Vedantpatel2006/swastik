import 'package:flutter/material.dart';
import '../../../shared/models/temple.dart';
import 'temple_card.dart';

class TempleSection extends StatelessWidget {
  final String title;
  final List<Temple> temples;
  final Function(Temple) onTempleTap;
  final Function(Temple) onFavoriteToggle;
  final Function(Temple) onLiveDarshanTap;
  final Function(Temple) onBookingTap;
  final VoidCallback? onSeeAll;
  final IconData? icon;

  const TempleSection({
    super.key,
    required this.title,
    required this.temples,
    required this.onTempleTap,
    required this.onFavoriteToggle,
    required this.onLiveDarshanTap,
    required this.onBookingTap,
    this.onSeeAll,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    if (temples.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 32), // Add spacing between sections
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16), // Increased padding
            child: Row(
              children: [
                if (icon != null) ...[
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF7A00).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: const Color(0xFFFF7A00), size: 20),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 20, // Slightly larger
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: TextButton(
                    onPressed:
                        onSeeAll ??
                        () {
                          // Navigate to temple search/discovery screen with filter
                          Navigator.pushNamed(
                            context,
                            '/temple_search',
                            arguments: {
                              'title': title,
                              'initialTemples': temples,
                            },
                          );
                    },
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      'See All',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFFF7A00),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 440, // Increased height for better card display
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemCount: temples.length,
              itemBuilder: (context, index) {
                final temple = temples[index];
                return SizedBox(
                  width: 340, // Increased width for better content display
                  child: Padding(
                    padding: const EdgeInsets.only(right: 0),
                    child: TempleCard(
                      temple: temple,
                      margin: EdgeInsets.fromLTRB(16, 4, index == temples.length - 1 ? 16 : 0, 16),
                      onTap: () => onTempleTap(temple),
                      onFavoriteToggle: () => onFavoriteToggle(temple),
                      onLiveDarshanTap: () => onLiveDarshanTap(temple),
                      onBookingTap: () => onBookingTap(temple),
                      showDistance: true,
                      showLiveIndicator: true,
                      showBookingButton: true,
                      showShareButton: true,
                      animationIndex: index,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
