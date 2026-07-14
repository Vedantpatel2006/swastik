import 'dart:async';
import 'package:flutter/material.dart';

/// Utilities for optimizing state management to prevent unnecessary rebuilds
class StateManagementOptimization {
  StateManagementOptimization._();

  /// Debounces state updates to prevent excessive rebuilds
  static Timer? _debounceTimer;

  static void debounceSetState(
    VoidCallback setState,
    VoidCallback updateFunction, {
    Duration delay = const Duration(milliseconds: 100),
  }) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(delay, () {
      updateFunction();
      setState();
    });
  }

  /// Throttles state updates to limit rebuild frequency
  static DateTime? _lastThrottleTime;

  static void throttleSetState(
    VoidCallback setState,
    VoidCallback updateFunction, {
    Duration interval = const Duration(milliseconds: 100),
  }) {
    final now = DateTime.now();
    if (_lastThrottleTime == null ||
        now.difference(_lastThrottleTime!) >= interval) {
      _lastThrottleTime = now;
      updateFunction();
      setState();
    }
  }

  /// Batches multiple state updates into a single rebuild
  static void batchStateUpdates(
    VoidCallback setState,
    List<VoidCallback> updates,
  ) {
    // Execute all updates
    for (final update in updates) {
      update();
    }

    // Single setState call for all updates
    setState();
  }
}

/// Mixin for optimizing state management in stateful widgets
mixin StateOptimizationMixin<T extends StatefulWidget> on State<T> {
  Timer? _debounceTimer;
  DateTime? _lastThrottleTime;
  final List<VoidCallback> _batchedUpdates = [];
  Timer? _batchTimer;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _batchTimer?.cancel();
    super.dispose();
  }

  /// Debounced setState to prevent excessive rebuilds
  void debouncedSetState(
    VoidCallback updateFunction, {
    Duration delay = const Duration(milliseconds: 100),
  }) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(delay, () {
      if (mounted) {
        setState(() {
          updateFunction();
        });
      }
    });
  }

  /// Throttled setState to limit rebuild frequency
  void throttledSetState(
    VoidCallback updateFunction, {
    Duration interval = const Duration(milliseconds: 100),
  }) {
    final now = DateTime.now();
    if (_lastThrottleTime == null ||
        now.difference(_lastThrottleTime!) >= interval) {
      _lastThrottleTime = now;
      if (mounted) {
        setState(() {
          updateFunction();
        });
      }
    }
  }

  /// Batches state updates to reduce rebuild frequency
  void batchStateUpdate(VoidCallback updateFunction) {
    _batchedUpdates.add(updateFunction);

    _batchTimer?.cancel();
    _batchTimer = Timer(const Duration(milliseconds: 16), () {
      if (mounted && _batchedUpdates.isNotEmpty) {
        setState(() {
          for (final update in _batchedUpdates) {
            update();
          }
        });
        _batchedUpdates.clear();
      }
    });
  }

  /// Safe setState that checks if widget is still mounted
  void safeSetState(VoidCallback updateFunction) {
    if (mounted) {
      setState(() {
        updateFunction();
      });
    }
  }

  /// Conditional setState that only rebuilds if condition is met
  void conditionalSetState(bool condition, VoidCallback updateFunction) {
    if (condition && mounted) {
      setState(() {
        updateFunction();
      });
    }
  }
}

/// Widget that demonstrates state management optimization
class StateOptimizationDemo extends StatefulWidget {
  const StateOptimizationDemo({super.key});

  @override
  State<StateOptimizationDemo> createState() => _StateOptimizationDemoState();
}

class _StateOptimizationDemoState extends State<StateOptimizationDemo>
    with StateOptimizationMixin<StateOptimizationDemo> {
  int _counter = 0;
  String _searchQuery = '';
  bool _isLoading = false;
  List<String> _items = [];

  void _incrementCounter() {
    // Use debounced setState for rapid increments
    debouncedSetState(() {
      _counter++;
    });
  }

  void _updateSearchQuery(String query) {
    // Use throttled setState for search input
    throttledSetState(() {
      _searchQuery = query;
    });
  }

  void _performBatchUpdate() {
    // Batch multiple state changes
    batchStateUpdate(() => _isLoading = true);
    batchStateUpdate(() => _items.add('New item ${_items.length + 1}'));
    batchStateUpdate(() => _counter++);

    // Simulate async operation
    Future.delayed(const Duration(seconds: 1), () {
      batchStateUpdate(() => _isLoading = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('State Optimization Demo')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text('Counter: $_counter'),
            const SizedBox(height: 16),

            TextField(
              onChanged: _updateSearchQuery,
              decoration: const InputDecoration(
                labelText: 'Search (throttled)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            Text('Search Query: $_searchQuery'),
            const SizedBox(height: 16),

            if (_isLoading)
              const CircularProgressIndicator()
            else
              Text('Items: ${_items.length}'),

            const SizedBox(height: 16),

            Expanded(
              child: ListView.builder(
                itemCount: _items.length,
                itemBuilder: (context, index) =>
                    ListTile(title: Text(_items[index])),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(
            heroTag: 'fab_increment_debounced',
            onPressed: _incrementCounter,
            tooltip: 'Increment (debounced)',
            child: const Icon(Icons.add),
          ),
          const SizedBox(height: 8),
          FloatingActionButton(
            heroTag: 'fab_batch_update',
            onPressed: _performBatchUpdate,
            tooltip: 'Batch Update',
            child: const Icon(Icons.batch_prediction),
          ),
        ],
      ),
    );
  }
}

/// Optimized provider-like state management for preventing unnecessary rebuilds
class OptimizedStateProvider<T> extends InheritedWidget {
  final T value;
  final bool Function(T oldValue, T newValue)? shouldRebuild;

  const OptimizedStateProvider({
    super.key,
    required this.value,
    required super.child,
    this.shouldRebuild,
  });

  static OptimizedStateProvider<T>? of<T>(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<OptimizedStateProvider<T>>();
  }

  @override
  bool updateShouldNotify(OptimizedStateProvider<T> oldWidget) {
    if (shouldRebuild != null) {
      return shouldRebuild!(oldWidget.value, value);
    }
    return oldWidget.value != value;
  }
}

/// Selector widget that only rebuilds when specific parts of state change
class StateSelector<T, R> extends StatefulWidget {
  final T state;
  final R Function(T state) selector;
  final Widget Function(BuildContext context, R selectedState) builder;
  final bool Function(R previous, R current)? shouldRebuild;

  const StateSelector({
    super.key,
    required this.state,
    required this.selector,
    required this.builder,
    this.shouldRebuild,
  });

  @override
  State<StateSelector<T, R>> createState() => _StateSelectorState<T, R>();
}

class _StateSelectorState<T, R> extends State<StateSelector<T, R>> {
  late R _selectedState;

  @override
  void initState() {
    super.initState();
    _selectedState = widget.selector(widget.state);
  }

  @override
  void didUpdateWidget(StateSelector<T, R> oldWidget) {
    super.didUpdateWidget(oldWidget);

    final newSelectedState = widget.selector(widget.state);
    final shouldUpdate =
        widget.shouldRebuild?.call(_selectedState, newSelectedState) ??
        (_selectedState != newSelectedState);

    if (shouldUpdate) {
      _selectedState = newSelectedState;
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(context, _selectedState);
  }
}

/// Memoized widget that only rebuilds when dependencies change
class MemoizedWidget extends StatefulWidget {
  final List<dynamic> dependencies;
  final Widget Function() builder;

  const MemoizedWidget({
    super.key,
    required this.dependencies,
    required this.builder,
  });

  @override
  State<MemoizedWidget> createState() => _MemoizedWidgetState();
}

class _MemoizedWidgetState extends State<MemoizedWidget> {
  Widget? _cachedWidget;
  List<dynamic>? _lastDependencies;

  @override
  Widget build(BuildContext context) {
    // Check if dependencies have changed
    if (_cachedWidget == null ||
        _lastDependencies == null ||
        !_dependenciesEqual(_lastDependencies!, widget.dependencies)) {
      _cachedWidget = widget.builder();
      _lastDependencies = List.from(widget.dependencies);
    }

    return _cachedWidget!;
  }

  bool _dependenciesEqual(List<dynamic> a, List<dynamic> b) {
    if (a.length != b.length) return false;

    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }

    return true;
  }
}

/// Example of using MemoizedWidget
class MemoizedWidgetExample extends StatefulWidget {
  const MemoizedWidgetExample({super.key});

  @override
  State<MemoizedWidgetExample> createState() => _MemoizedWidgetExampleState();
}

class _MemoizedWidgetExampleState extends State<MemoizedWidgetExample> {
  int _counter = 0;
  String _text = 'Hello';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Memoized Widget Example')),
      body: Column(
        children: [
          Text('Counter: $_counter'),
          Text('Text: $_text'),

          // This widget only rebuilds when _text changes, not when _counter changes
          MemoizedWidget(
            dependencies: [_text],
            builder: () => Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Memoized: $_text',
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(
            heroTag: 'fab_counter_add',
            onPressed: () => setState(() => _counter++),
            child: const Icon(Icons.add),
          ),
          const SizedBox(height: 8),
          FloatingActionButton(
            heroTag: 'fab_text_update',
            onPressed: () =>
                setState(() => _text = 'Updated ${DateTime.now().millisecond}'),
            child: const Icon(Icons.text_fields),
          ),
        ],
      ),
    );
  }
}
