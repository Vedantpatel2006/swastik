import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../shared/models/temple_filters.dart';
import '../screens/temple_search_screen.dart';

/// Search button widget that opens the dedicated search screen
class SearchButtonWidget extends StatelessWidget {
  final String? placeholder;
  final String? initialQuery;
  final TempleFilters? initialFilters;
  final String? userId;
  final EdgeInsetsGeometry? margin;
  final bool enabled;

  const SearchButtonWidget({
    super.key,
    this.placeholder,
    this.initialQuery,
    this.initialFilters,
    this.userId,
    this.margin,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin ?? const EdgeInsets.all(16),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        elevation: 2,
        shadowColor: Colors.black.withValues(alpha: 0.1),
        child: InkWell(
          onTap: enabled ? () => _openSearchScreen(context) : null,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.grey[300]!,
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.search,
                  color: Colors.grey[600],
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    placeholder ?? 'Search temples, locations, traditions...',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 16,
                    ),
                  ),
                ),
                if (initialFilters?.hasFilters == true) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Filtered',
                      style: TextStyle(
                        fontSize: 10,
                        color: Theme.of(context).primaryColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openSearchScreen(BuildContext context) {
    // Provide haptic feedback
    HapticFeedback.lightImpact();

    // Navigate to search screen
    Navigator.of(context).push(
      TempleSearchRoute.route(
        initialQuery: initialQuery,
        initialFilters: initialFilters,
        userId: userId,
      ),
    );
  }
}

/// Compact search button for app bars or tight spaces
class CompactSearchButton extends StatelessWidget {
  final String? initialQuery;
  final TempleFilters? initialFilters;
  final String? userId;
  final Color? iconColor;
  final double? iconSize;

  const CompactSearchButton({
    super.key,
    this.initialQuery,
    this.initialFilters,
    this.userId,
    this.iconColor,
    this.iconSize,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(
        Icons.search,
        color: iconColor,
        size: iconSize,
      ),
      onPressed: () => _openSearchScreen(context),
      tooltip: 'Search Temples',
    );
  }

  void _openSearchScreen(BuildContext context) {
    HapticFeedback.lightImpact();

    Navigator.of(context).push(
      TempleSearchRoute.route(
        initialQuery: initialQuery,
        initialFilters: initialFilters,
        userId: userId,
      ),
    );
  }
}

/// Search bar widget that looks like a text field but opens search screen
class SearchBarWidget extends StatelessWidget {
  final String? placeholder;
  final String? initialQuery;
  final TempleFilters? initialFilters;
  final String? userId;
  final bool autofocus;
  final EdgeInsetsGeometry? padding;

  const SearchBarWidget({
    super.key,
    this.placeholder,
    this.initialQuery,
    this.initialFilters,
    this.userId,
    this.autofocus = false,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ?? const EdgeInsets.all(16),
      child: GestureDetector(
        onTap: () => _openSearchScreen(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.grey[300]!,
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.search,
                color: Colors.grey[600],
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  initialQuery?.isNotEmpty == true 
                      ? initialQuery!
                      : placeholder ?? 'Search temples...',
                  style: TextStyle(
                    color: initialQuery?.isNotEmpty == true 
                        ? Colors.black87 
                        : Colors.grey[600],
                    fontSize: 16,
                  ),
                ),
              ),
              if (initialFilters?.hasFilters == true) ...[
                const SizedBox(width: 8),
                Icon(
                  Icons.filter_list,
                  color: Theme.of(context).primaryColor,
                  size: 18,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _openSearchScreen(BuildContext context) {
    HapticFeedback.lightImpact();

    Navigator.of(context).push(
      TempleSearchRoute.route(
        initialQuery: initialQuery,
        initialFilters: initialFilters,
        userId: userId,
      ),
    );
  }
}