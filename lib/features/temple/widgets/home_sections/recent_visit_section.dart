import 'package:flutter/material.dart';
import '../../../../shared/models/temple.dart';
import '../../../../core/themes/app_colors.dart';
import '../temple_card_horizontal.dart';

/// Recent Visit Section - Shows recently visited temples
class RecentVisitSection extends StatelessWidget {
  final List<Temple> temples;
  final Function(Temple) onTempleTap;

  const RecentVisitSection({
    super.key,
    required this.temples,
    required this.onTempleTap,
  });

  @override
  Widget build(BuildContext context) {
    final displayTemples = temples
        .where((temple) => temple.lastVisited != null)
        .toList()
      ..sort((a, b) => b.lastVisited!.compareTo(a.lastVisited!));

    final recentTemples = displayTemples.take(5).toList();

    // Hide entirely when user has no visit history
    if (recentTemples.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Recent Visit',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryText,
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(
                    context,
                    rootNavigator: true,
                  ).pushNamed('/temple_search');
                },
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
        SizedBox(
          height: 260,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: recentTemples.length,
            itemBuilder: (context, index) {
              final temple = recentTemples[index];
              return TempleCardHorizontal(
                temple: temple,
                onTap: () => onTempleTap(temple),
                showMargin: index < recentTemples.length - 1,
              );
            },
          ),
        ),
      ],
    );
  }
}
