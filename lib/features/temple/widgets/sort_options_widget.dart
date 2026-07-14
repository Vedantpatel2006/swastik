import 'package:flutter/material.dart';
import '../../../shared/models/temple_filters.dart';
import '../services/search_manager.dart';

/// Widget for displaying and selecting sort options for search results
/// Implements sorting by distance, rating, popularity, and alphabetical order
/// Provides immediate reordering without new search requirement (Requirements 4.1, 4.2, 4.3, 4.4, 4.5)
class SortOptionsWidget extends StatelessWidget {
  final SortOptions currentSortOptions;
  final Function(SortOptions) onSortChanged;
  final bool showDistanceSort;
  final bool isCompact;

  const SortOptionsWidget({
    super.key,
    required this.currentSortOptions,
    required this.onSortChanged,
    this.showDistanceSort = true,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isCompact) {
      return _buildCompactSortOptions(context);
    }
    return _buildFullSortOptions(context);
  }

  Widget _buildCompactSortOptions(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.sort, size: 20, color: Colors.grey),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<SortOption>(
                value: currentSortOptions.sortBy,
                isDense: true,
                onChanged: (SortOption? newSortBy) {
                  if (newSortBy != null) {
                    onSortChanged(currentSortOptions.copyWith(sortBy: newSortBy));
                  }
                },
                items: _getSortOptions().map<DropdownMenuItem<SortOption>>((SortOption value) {
                  return DropdownMenuItem<SortOption>(
                    value: value,
                    child: Text(
                      value.displayName,
                      style: const TextStyle(fontSize: 14),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: () {
              onSortChanged(currentSortOptions.copyWith(
                ascending: !currentSortOptions.ascending,
              ));
            },
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.all(8),
              child: Icon(
                currentSortOptions.ascending
                    ? Icons.arrow_upward
                    : Icons.arrow_downward,
                size: 18,
                color: Theme.of(context).primaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFullSortOptions(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.sort, color: Colors.grey),
              const SizedBox(width: 8),
              Text(
                'Sort by',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              _buildSortDirectionToggle(context),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _getSortOptions().map((sortOption) {
              final isSelected = currentSortOptions.sortBy == sortOption;
              return _buildSortChip(context, sortOption, isSelected);
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSortDirectionToggle(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildDirectionButton(
            context,
            icon: Icons.arrow_upward,
            label: 'Asc',
            isSelected: currentSortOptions.ascending,
            onTap: () {
              if (!currentSortOptions.ascending) {
                onSortChanged(currentSortOptions.copyWith(ascending: true));
              }
            },
          ),
          _buildDirectionButton(
            context,
            icon: Icons.arrow_downward,
            label: 'Desc',
            isSelected: !currentSortOptions.ascending,
            onTap: () {
              if (currentSortOptions.ascending) {
                onSortChanged(currentSortOptions.copyWith(ascending: false));
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDirectionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Theme.of(context).primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : Colors.grey[600],
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isSelected ? Colors.white : Colors.grey[600],
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSortChip(BuildContext context, SortOption sortOption, bool isSelected) {
    return InkWell(
      onTap: () {
        onSortChanged(currentSortOptions.copyWith(sortBy: sortOption));
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Theme.of(context).primaryColor : Colors.grey[100],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Theme.of(context).primaryColor : Theme.of(context).dividerColor,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _getSortIcon(sortOption),
              size: 16,
              color: isSelected ? Colors.white : Colors.grey[600],
            ),
            const SizedBox(width: 6),
            Text(
              sortOption.displayName,
              style: TextStyle(
                fontSize: 14,
                color: isSelected ? Colors.white : Colors.grey[700],
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<SortOption> _getSortOptions() {
    final options = [
      SortOption.name,
      SortOption.rating,
      SortOption.popularity,
      SortOption.visitCount,
      SortOption.updatedAt,
      SortOption.tradition,
    ];

    // Only include distance sort if location is available
    if (showDistanceSort) {
      options.insert(1, SortOption.distance);
    }

    return options;
  }

  IconData _getSortIcon(SortOption sortOption) {
    switch (sortOption) {
      case SortOption.name:
        return Icons.sort_by_alpha;
      case SortOption.distance:
        return Icons.near_me;
      case SortOption.rating:
        return Icons.star;
      case SortOption.popularity:
        return Icons.trending_up;
      case SortOption.visitCount:
        return Icons.people;
      case SortOption.updatedAt:
        return Icons.schedule;
      case SortOption.tradition:
        return Icons.category;
      case SortOption.createdAt:
        return Icons.add_circle_outline;
    }
  }
}

/// Sort options bottom sheet for mobile-friendly selection
class SortOptionsBottomSheet extends StatelessWidget {
  final SortOptions currentSortOptions;
  final Function(SortOptions) onSortChanged;
  final bool showDistanceSort;

  const SortOptionsBottomSheet({
    super.key,
    required this.currentSortOptions,
    required this.onSortChanged,
    this.showDistanceSort = true,
  });

  static Future<void> show(
    BuildContext context, {
    required SortOptions currentSortOptions,
    required Function(SortOptions) onSortChanged,
    bool showDistanceSort = true,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return SortOptionsBottomSheet(
          currentSortOptions: currentSortOptions,
          onSortChanged: onSortChanged,
          showDistanceSort: showDistanceSort,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            
            // Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  const Icon(Icons.sort, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text(
                    'Sort Options',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Sort options
            SortOptionsWidget(
              currentSortOptions: currentSortOptions,
              onSortChanged: (newSortOptions) {
                onSortChanged(newSortOptions);
                Navigator.of(context).pop();
              },
              showDistanceSort: showDistanceSort,
              isCompact: false,
            ),
            
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}