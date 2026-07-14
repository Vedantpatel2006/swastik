import 'package:flutter/material.dart';
import 'app_animations.dart';
import 'micro_animations.dart';

/// Animations for search results and filtering
class SearchAnimations {
  /// Creates a staggered animation for search results appearing
  static Widget staggeredSearchResults({
    required List<Widget> children,
    Duration staggerDelay = const Duration(milliseconds: 100),
    Duration itemDuration = AppAnimations.normalDuration,
    Curve curve = AppAnimations.interactionCurve,
  }) {
    return _StaggeredSearchResultsWidget(
      children: children,
      staggerDelay: staggerDelay,
      itemDuration: itemDuration,
      curve: curve,
    );
  }

  /// Creates an animated search bar with expanding/contracting behavior
  static Widget animatedSearchBar({
    required TextEditingController controller,
    required VoidCallback onTap,
    required ValueChanged<String> onChanged,
    String hintText = 'Search temples...',
    bool isExpanded = false,
    Duration duration = AppAnimations.normalDuration,
    VoidCallback? onClear,
  }) {
    return _AnimatedSearchBarWidget(
      controller: controller,
      onTap: onTap,
      onChanged: onChanged,
      hintText: hintText,
      isExpanded: isExpanded,
      duration: duration,
      onClear: onClear,
    );
  }

  /// Creates animated filter chips that slide in from the side
  static Widget animatedFilterChips({
    required List<FilterChipData> chips,
    Duration staggerDelay = const Duration(milliseconds: 50),
    Duration itemDuration = AppAnimations.normalDuration,
  }) {
    return _AnimatedFilterChipsWidget(
      chips: chips,
      staggerDelay: staggerDelay,
      itemDuration: itemDuration,
    );
  }

  /// Creates a search suggestion dropdown with fade and slide animation
  static Widget animatedSearchSuggestions({
    required List<String> suggestions,
    required ValueChanged<String> onSuggestionTap,
    bool isVisible = false,
    Duration duration = AppAnimations.normalDuration,
  }) {
    return _AnimatedSearchSuggestionsWidget(
      suggestions: suggestions,
      onSuggestionTap: onSuggestionTap,
      isVisible: isVisible,
      duration: duration,
    );
  }

  /// Creates a "no results" animation with a gentle bounce
  static Widget noResultsAnimation({
    String message = 'No temples found',
    String subtitle = 'Try adjusting your search or filters',
    IconData icon = Icons.search_off,
  }) {
    return _NoResultsAnimationWidget(
      message: message,
      subtitle: subtitle,
      icon: icon,
    );
  }

  /// Creates a search loading state with typing animation
  static Widget searchLoadingAnimation({
    String text = 'Searching',
    Duration typingDuration = const Duration(milliseconds: 100),
  }) {
    return _SearchLoadingAnimationWidget(
      text: text,
      typingDuration: typingDuration,
    );
  }
}

/// Data class for filter chips
class FilterChipData {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final IconData? icon;
  final int? count;

  const FilterChipData({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.icon,
    this.count,
  });
}

/// Staggered search results widget
class _StaggeredSearchResultsWidget extends StatefulWidget {
  final List<Widget> children;
  final Duration staggerDelay;
  final Duration itemDuration;
  final Curve curve;

  const _StaggeredSearchResultsWidget({
    required this.children,
    required this.staggerDelay,
    required this.itemDuration,
    required this.curve,
  });

  @override
  State<_StaggeredSearchResultsWidget> createState() =>
      _StaggeredSearchResultsWidgetState();
}

class _StaggeredSearchResultsWidgetState
    extends State<_StaggeredSearchResultsWidget>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<double>> _fadeAnimations;
  late List<Animation<Offset>> _slideAnimations;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startStaggeredAnimations();
  }

  void _initializeAnimations() {
    _controllers = List.generate(
      widget.children.length,
      (index) =>
          AnimationController(duration: widget.itemDuration, vsync: this),
    );

    _fadeAnimations = _controllers.map((controller) {
      return Tween<double>(
        begin: 0.0,
        end: 1.0,
      ).animate(CurvedAnimation(parent: controller, curve: widget.curve));
    }).toList();

    _slideAnimations = _controllers.map((controller) {
      return Tween<Offset>(
        begin: const Offset(0, 0.3),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: controller, curve: widget.curve));
    }).toList();
  }

  void _startStaggeredAnimations() {
    for (int i = 0; i < _controllers.length; i++) {
      Future.delayed(widget.staggerDelay * i, () {
        if (mounted) {
          _controllers[i].forward();
        }
      });
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(widget.children.length, (index) {
        return AnimatedBuilder(
          animation: _controllers[index],
          builder: (context, child) {
            return SlideTransition(
              position: _slideAnimations[index],
              child: FadeTransition(
                opacity: _fadeAnimations[index],
                child: widget.children[index],
              ),
            );
          },
        );
      }),
    );
  }
}

/// Animated search bar widget
class _AnimatedSearchBarWidget extends StatefulWidget {
  final TextEditingController controller;
  final VoidCallback onTap;
  final ValueChanged<String> onChanged;
  final String hintText;
  final bool isExpanded;
  final Duration duration;
  final VoidCallback? onClear;

  const _AnimatedSearchBarWidget({
    required this.controller,
    required this.onTap,
    required this.onChanged,
    required this.hintText,
    required this.isExpanded,
    required this.duration,
    this.onClear,
  });

  @override
  State<_AnimatedSearchBarWidget> createState() =>
      _AnimatedSearchBarWidgetState();
}

class _AnimatedSearchBarWidgetState extends State<_AnimatedSearchBarWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _widthAnimation;
  late Animation<double> _borderRadiusAnimation;
  late Animation<Color?> _colorAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: widget.duration, vsync: this);

    _widthAnimation = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: AppAnimations.defaultCurve),
    );

    _borderRadiusAnimation = Tween<double>(begin: 25.0, end: 12.0).animate(
      CurvedAnimation(parent: _controller, curve: AppAnimations.defaultCurve),
    );

    _colorAnimation = ColorTween(begin: Colors.grey[100], end: Colors.white)
        .animate(
          CurvedAnimation(
            parent: _controller,
            curve: AppAnimations.defaultCurve,
          ),
        );

    if (widget.isExpanded) {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(_AnimatedSearchBarWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isExpanded != oldWidget.isExpanded) {
      if (widget.isExpanded) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return FractionallySizedBox(
          widthFactor: _widthAnimation.value,
          child: GestureDetector(
            onTap: widget.onTap,
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: _colorAnimation.value,
                borderRadius: BorderRadius.circular(
                  _borderRadiusAnimation.value,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Icon(Icons.search, color: Colors.grey),
                  ),
                  Expanded(
                    child: Text(
                      widget.controller.text.isNotEmpty
                          ? widget.controller.text
                          : widget.hintText,
                      style: TextStyle(
                        color: widget.controller.text.isNotEmpty
                            ? Colors.black87
                            : Colors.grey[600],
                        fontSize: 16,
                      ),
                    ),
                  ),
                  if (widget.controller.text.isNotEmpty &&
                      widget.onClear != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 16),
                      child: MicroAnimations.bounceOnTap(
                        onTap: widget.onClear,
                        child: const Icon(Icons.clear, color: Colors.grey),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Animated filter chips widget
class _AnimatedFilterChipsWidget extends StatefulWidget {
  final List<FilterChipData> chips;
  final Duration staggerDelay;
  final Duration itemDuration;

  const _AnimatedFilterChipsWidget({
    required this.chips,
    required this.staggerDelay,
    required this.itemDuration,
  });

  @override
  State<_AnimatedFilterChipsWidget> createState() =>
      _AnimatedFilterChipsWidgetState();
}

class _AnimatedFilterChipsWidgetState extends State<_AnimatedFilterChipsWidget>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<Offset>> _slideAnimations;
  late List<Animation<double>> _fadeAnimations;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startStaggeredAnimations();
  }

  void _initializeAnimations() {
    _controllers = List.generate(
      widget.chips.length,
      (index) =>
          AnimationController(duration: widget.itemDuration, vsync: this),
    );

    _slideAnimations = _controllers.map((controller) {
      return Tween<Offset>(
        begin: const Offset(-1.0, 0),
        end: Offset.zero,
      ).animate(
        CurvedAnimation(
          parent: controller,
          curve: AppAnimations.interactionCurve,
        ),
      );
    }).toList();

    _fadeAnimations = _controllers.map((controller) {
      return Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: controller, curve: AppAnimations.defaultCurve),
      );
    }).toList();
  }

  void _startStaggeredAnimations() {
    for (int i = 0; i < _controllers.length; i++) {
      Future.delayed(widget.staggerDelay * i, () {
        if (mounted) {
          _controllers[i].forward();
        }
      });
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: List.generate(widget.chips.length, (index) {
          final chip = widget.chips[index];
          return AnimatedBuilder(
            animation: _controllers[index],
            builder: (context, child) {
              return SlideTransition(
                position: _slideAnimations[index],
                child: FadeTransition(
                  opacity: _fadeAnimations[index],
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: MicroAnimations.bounceOnTap(
                      onTap: chip.onTap,
                      child: AnimatedContainer(
                        duration: AppAnimations.fastDuration,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: chip.isSelected
                              ? const Color(0xFFFF6B35)
                              : Colors.grey[200],
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: chip.isSelected
                                ? const Color(0xFFFF6B35)
                                : Colors.grey[300]!,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (chip.icon != null) ...[
                              Icon(
                                chip.icon,
                                size: 16,
                                color: chip.isSelected
                                    ? Colors.white
                                    : Colors.grey[600],
                              ),
                              const SizedBox(width: 4),
                            ],
                            Text(
                              chip.label,
                              style: TextStyle(
                                color: chip.isSelected
                                    ? Colors.white
                                    : Colors.grey[700],
                                fontWeight: chip.isSelected
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                            ),
                            if (chip.count != null && chip.count! > 0) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: chip.isSelected
                                      ? Colors.white.withValues(alpha: 0.3)
                                      : Colors.grey[300],
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  chip.count.toString(),
                                  style: TextStyle(
                                    color: chip.isSelected
                                        ? Colors.white
                                        : Colors.grey[700],
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        }),
      ),
    );
  }
}

/// Animated search suggestions widget
class _AnimatedSearchSuggestionsWidget extends StatefulWidget {
  final List<String> suggestions;
  final ValueChanged<String> onSuggestionTap;
  final bool isVisible;
  final Duration duration;

  const _AnimatedSearchSuggestionsWidget({
    required this.suggestions,
    required this.onSuggestionTap,
    required this.isVisible,
    required this.duration,
  });

  @override
  State<_AnimatedSearchSuggestionsWidget> createState() =>
      _AnimatedSearchSuggestionsWidgetState();
}

class _AnimatedSearchSuggestionsWidgetState
    extends State<_AnimatedSearchSuggestionsWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: widget.duration, vsync: this);

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: AppAnimations.defaultCurve),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, -0.2), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _controller,
            curve: AppAnimations.defaultCurve,
          ),
        );

    if (widget.isVisible) {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(_AnimatedSearchSuggestionsWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isVisible != oldWidget.isVisible) {
      if (widget.isVisible) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.suggestions.isEmpty) return const SizedBox.shrink();

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return SlideTransition(
          position: _slideAnimation,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
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
                children: widget.suggestions.map((suggestion) {
                  return MicroAnimations.bounceOnTap(
                    onTap: () => widget.onSuggestionTap(suggestion),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.search,
                            size: 16,
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              suggestion,
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// No results animation widget
class _NoResultsAnimationWidget extends StatefulWidget {
  final String message;
  final String subtitle;
  final IconData icon;

  const _NoResultsAnimationWidget({
    required this.message,
    required this.subtitle,
    required this.icon,
  });

  @override
  State<_NoResultsAnimationWidget> createState() =>
      _NoResultsAnimationWidgetState();
}

class _NoResultsAnimationWidgetState extends State<_NoResultsAnimationWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _bounceAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: AppAnimations.slowDuration,
      vsync: this,
    );

    _bounceAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: AppAnimations.bounceCurve),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
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
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return FadeTransition(
          opacity: _fadeAnimation,
          child: Transform.scale(
            scale: _bounceAnimation.value,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(widget.icon, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  widget.message,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.subtitle,
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Search loading animation with typing effect
class _SearchLoadingAnimationWidget extends StatefulWidget {
  final String text;
  final Duration typingDuration;

  const _SearchLoadingAnimationWidget({
    required this.text,
    required this.typingDuration,
  });

  @override
  State<_SearchLoadingAnimationWidget> createState() =>
      _SearchLoadingAnimationWidgetState();
}

class _SearchLoadingAnimationWidgetState
    extends State<_SearchLoadingAnimationWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<int> _typingAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.typingDuration * widget.text.length,
      vsync: this,
    );

    _typingAnimation = IntTween(
      begin: 0,
      end: widget.text.length,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _typingAnimation,
      builder: (context, child) {
        final displayText = widget.text.substring(0, _typingAnimation.value);
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              displayText,
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            Container(
              width: 2,
              height: 20,
              color: const Color(0xFFFF6B35),
              margin: const EdgeInsets.only(left: 2),
            ),
          ],
        );
      },
    );
  }
}
