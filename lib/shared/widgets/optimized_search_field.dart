import 'dart:async';
import 'package:flutter/material.dart';
import 'animations/app_animations.dart';
import 'performance/build_optimization_mixin.dart';

/// An optimized search field with debouncing, caching, and smooth animations
class OptimizedSearchField extends StatefulWidget {
  /// Callback when search query changes (debounced)
  final void Function(String query) onSearchChanged;

  /// Debounce duration for search queries
  final Duration debounceDuration;

  /// Hint text for the search field
  final String hintText;

  /// Whether to show search suggestions
  final bool showSuggestions;

  /// List of search suggestions
  final List<String> suggestions;

  /// Callback when a suggestion is selected
  final void Function(String suggestion)? onSuggestionSelected;

  /// Whether the search is currently loading
  final bool isLoading;

  /// Custom loading indicator
  final Widget? loadingIndicator;

  /// Animation duration for UI changes
  final Duration animationDuration;

  /// Initial search query
  final String initialQuery;

  /// Text editing controller (optional)
  final TextEditingController? controller;

  /// Focus node (optional)
  final FocusNode? focusNode;

  /// Whether to animate the search field appearance
  final bool animateAppearance;

  const OptimizedSearchField({
    super.key,
    required this.onSearchChanged,
    this.debounceDuration = const Duration(milliseconds: 300),
    this.hintText = 'Search...',
    this.showSuggestions = false,
    this.suggestions = const [],
    this.onSuggestionSelected,
    this.isLoading = false,
    this.loadingIndicator,
    this.animationDuration = AppAnimations.fastDuration,
    this.initialQuery = '',
    this.controller,
    this.focusNode,
    this.animateAppearance = true,
  });

  @override
  State<OptimizedSearchField> createState() => _OptimizedSearchFieldState();
}

class _OptimizedSearchFieldState extends State<OptimizedSearchField>
    with
        TickerProviderStateMixin,
        BuildOptimizationMixin<OptimizedSearchField> {
  late TextEditingController _controller;
  late FocusNode _focusNode;
  late AnimationController _appearanceController;
  late AnimationController _loadingController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _loadingAnimation;

  Timer? _debounceTimer;
  bool _showSuggestions = false;
  String _currentQuery = '';

  @override
  void initState() {
    super.initState();

    _controller = widget.controller ?? TextEditingController();
    _focusNode = widget.focusNode ?? FocusNode();

    // Set initial query
    if (widget.initialQuery.isNotEmpty) {
      _controller.text = widget.initialQuery;
      _currentQuery = widget.initialQuery;
    }

    // Setup animations
    _appearanceController = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );

    _loadingController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _appearanceController,
        curve: AppAnimations.defaultCurve,
      ),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, -0.1), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _appearanceController,
            curve: AppAnimations.defaultCurve,
          ),
        );

    _loadingAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _loadingController, curve: Curves.easeInOut),
    );

    // Start animations
    if (widget.animateAppearance) {
      _appearanceController.forward();
    } else {
      _appearanceController.value = 1.0;
    }

    if (widget.isLoading) {
      _loadingController.repeat();
    }

    // Setup listeners
    _controller.addListener(_onTextChanged);
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void didUpdateWidget(OptimizedSearchField oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.isLoading != oldWidget.isLoading) {
      if (widget.isLoading) {
        _loadingController.repeat();
      } else {
        _loadingController.stop();
        _loadingController.reset();
      }
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _focusNode.removeListener(_onFocusChanged);

    _debounceTimer?.cancel();
    _appearanceController.dispose();
    _loadingController.dispose();

    if (widget.controller == null) {
      _controller.dispose();
    }
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }

    super.dispose();
  }

  void _onTextChanged() {
    final query = _controller.text;

    if (query != _currentQuery) {
      _currentQuery = query;

      // Debounce the search
      _debounceTimer?.cancel();
      _debounceTimer = Timer(widget.debounceDuration, () {
        widget.onSearchChanged(query);
      });

      // Show/hide suggestions
      if (widget.showSuggestions) {
        setState(() {
          _showSuggestions = query.isNotEmpty && widget.suggestions.isNotEmpty;
        });

        // Invalidate suggestions cache when visibility changes
        invalidateCache('filteredSuggestions');
      }
    }
  }

  void _onFocusChanged() {
    if (widget.showSuggestions) {
      setState(() {
        _showSuggestions =
            _focusNode.hasFocus &&
            _currentQuery.isNotEmpty &&
            widget.suggestions.isNotEmpty;
      });
    }
  }

  void _onSuggestionTap(String suggestion) {
    _controller.text = suggestion;
    _currentQuery = suggestion;

    setState(() {
      _showSuggestions = false;
    });

    _focusNode.unfocus();

    widget.onSuggestionSelected?.call(suggestion);
    widget.onSearchChanged(suggestion);
  }

  void _clearSearch() {
    _controller.clear();
    _currentQuery = '';

    setState(() {
      _showSuggestions = false;
    });

    widget.onSearchChanged('');
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Search Field
            SearchFieldContainer(
              controller: _controller,
              focusNode: _focusNode,
              hintText: widget.hintText,
              isLoading: widget.isLoading,
              loadingIndicator: widget.loadingIndicator,
              loadingAnimation: _loadingAnimation,
              currentQuery: _currentQuery,
              onClearSearch: _clearSearch,
            ),

            // Suggestions List
            if (_showSuggestions)
              buildOnce(
                'suggestionsList',
                () {
                  final filteredSuggestions = computeOnce(
                    'filteredSuggestions',
                    () => widget.suggestions
                        .where(
                          (suggestion) => suggestion.toLowerCase().contains(
                            _currentQuery.toLowerCase(),
                          ),
                        )
                        .take(5)
                        .toList(),
                    dependencies: [widget.suggestions, _currentQuery],
                  );

                  return SearchSuggestionsList(
                    suggestions: filteredSuggestions,
                    onSuggestionTap: _onSuggestionTap,
                    animationDuration: widget.animationDuration,
                  );
                },
                dependencies: [
                  widget.suggestions,
                  _currentQuery,
                  widget.animationDuration,
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// Optimized search field container widget
class SearchFieldContainer extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String hintText;
  final bool isLoading;
  final Widget? loadingIndicator;
  final Animation<double> loadingAnimation;
  final String currentQuery;
  final VoidCallback onClearSearch;

  const SearchFieldContainer({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.hintText,
    required this.isLoading,
    this.loadingIndicator,
    required this.loadingAnimation,
    required this.currentQuery,
    required this.onClearSearch,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              red: 0,
              green: 0,
              blue: 0,
              alpha: 0.1,
            ),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(color: Colors.grey[500], fontSize: 16),
          prefixIcon: AnimatedBuilder(
            animation: loadingAnimation,
            builder: (context, child) {
              if (isLoading) {
                return Padding(
                  padding: const EdgeInsets.all(12),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child:
                        loadingIndicator ??
                        CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Theme.of(context).primaryColor,
                          ),
                        ),
                  ),
                );
              }
              return const Icon(Icons.search, color: Color(0xFF6B7280));
            },
          ),
          suffixIcon: currentQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: Color(0xFF6B7280)),
                  onPressed: onClearSearch,
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFFF7A00), width: 2),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
          ),
          filled: true,
          fillColor: const Color(0xFFF9FAFB),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
        style: const TextStyle(fontSize: 16, color: Color(0xFF1F2937)),
      ),
    );
  }
}

/// Optimized search suggestions list widget
class SearchSuggestionsList extends StatefulWidget {
  final List<String> suggestions;
  final void Function(String) onSuggestionTap;
  final Duration animationDuration;

  const SearchSuggestionsList({
    super.key,
    required this.suggestions,
    required this.onSuggestionTap,
    required this.animationDuration,
  });

  @override
  State<SearchSuggestionsList> createState() => _SearchSuggestionsListState();
}

class _SearchSuggestionsListState extends State<SearchSuggestionsList>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: AppAnimations.defaultCurve),
    );

    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: AppAnimations.defaultCurve),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          margin: const EdgeInsets.only(top: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(
                  red: 0,
                  green: 0,
                  blue: 0,
                  alpha: 0.1,
                ),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: widget.suggestions.length,
            itemBuilder: (context, index) {
              final suggestion = widget.suggestions[index];
              return SearchSuggestionItem(
                suggestion: suggestion,
                onTap: () => widget.onSuggestionTap(suggestion),
              );
            },
            separatorBuilder: (context, index) =>
                const Divider(height: 1, color: Color(0xFFE5E7EB)),
          ),
        ),
      ),
    );
  }
}

/// Individual search suggestion item widget
class SearchSuggestionItem extends StatelessWidget {
  final String suggestion;
  final VoidCallback onTap;

  const SearchSuggestionItem({
    super.key,
    required this.suggestion,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(Icons.search, size: 16, color: Colors.grey[600]),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                suggestion,
                style: const TextStyle(fontSize: 14, color: Color(0xFF1F2937)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
