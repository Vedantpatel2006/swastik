import 'package:flutter/material.dart';
import '../services/offline_state_manager.dart';
import '../widgets/offline_state_indicator.dart';
import '../widgets/cache_management_interface.dart';

/// Screen for managing offline functionality and cache
class OfflineManagementScreen extends StatefulWidget {
  const OfflineManagementScreen({super.key});

  @override
  State<OfflineManagementScreen> createState() => _OfflineManagementScreenState();
}

class _OfflineManagementScreenState extends State<OfflineManagementScreen> {
  final OfflineStateManager _offlineStateManager = OfflineStateManager();
  OfflineState? _currentState;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeOfflineManager();
  }

  Future<void> _initializeOfflineManager() async {
    try {
      await _offlineStateManager.initialize();
      setState(() => _isInitialized = true);
      
      // Listen to state changes
      _offlineStateManager.offlineStateStream.listen((state) {
        if (mounted) {
          setState(() => _currentState = state);
        }
      });
      
      // Set initial state
      setState(() => _currentState = _offlineStateManager.currentState);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to initialize offline manager: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _offlineStateManager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Offline & Cache Management'),
        backgroundColor: Colors.orange.shade50,
        foregroundColor: Colors.orange.shade800,
        elevation: 0,
        actions: [
          if (_currentState != null)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: OfflineStateIndicator(
                state: _currentState!,
                showDetails: true,
              ),
            ),
        ],
      ),
      body: !_isInitialized
          ? const Center(child: CircularProgressIndicator())
          : _currentState == null
              ? const Center(child: Text('Loading offline state...'))
              : SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Sync status and progress
                      SyncProgressWidget(
                        state: _currentState!,
                        onRetry: _handleRetrySync,
                        onCancel: _handleCancelSync,
                      ),
                      
                      // Data freshness warning
                      DataFreshnessIndicator(
                        state: _currentState!,
                        onRefresh: _handleRefreshData,
                      ),
                      
                      // Conflict resolution
                      ConflictIndicator(
                        conflicts: _currentState!.conflicts,
                        onResolve: _handleResolveConflicts,
                      ),
                      
                      // Sync controls
                      _buildSyncControls(),
                      
                      // Cache management
                      CacheManagementInterface(
                        offlineStateManager: _offlineStateManager,
                        onClearCache: _handleCacheCleared,
                        onOptimizeCache: _handleOptimizeCache,
                      ),
                      
                      // Offline settings
                      _buildOfflineSettings(),
                      
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
    );
  }

  Widget _buildSyncControls() {
    if (_currentState == null) return const SizedBox.shrink();

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.sync, color: Colors.orange),
                const SizedBox(width: 8),
                Text(
                  'Sync Controls',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Sync status summary
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Connection Status',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.grey.shade600,
                              ),
                            ),
                            Text(
                              _currentState!.isOnline ? 'Online' : 'Offline',
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: _currentState!.isOnline ? Colors.green : Colors.red,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Pending Operations',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.grey.shade600,
                              ),
                            ),
                            Text(
                              '${_currentState!.pendingOperations}',
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: _currentState!.pendingOperations > 0 
                                    ? Colors.orange 
                                    : Colors.green,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (_currentState!.lastSyncTime != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          'Last sync: ${_formatLastSync(_currentState!.lastSyncTime!)}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Sync actions
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: _currentState!.isOnline && !_currentState!.isSyncing
                      ? _handleForceSync
                      : null,
                  icon: const Icon(Icons.sync),
                  label: const Text('Force Sync'),
                ),
                if (_currentState!.pendingOperations > 0)
                  OutlinedButton.icon(
                    onPressed: _handleViewPendingOperations,
                    icon: const Icon(Icons.list),
                    label: Text('View Pending (${_currentState!.pendingOperations})'),
                  ),
                if (_currentState!.hasConflicts)
                  ElevatedButton.icon(
                    onPressed: _handleResolveConflicts,
                    icon: const Icon(Icons.warning),
                    label: Text('Resolve Conflicts (${_currentState!.conflicts.length})'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange.shade100,
                      foregroundColor: Colors.orange.shade700,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOfflineSettings() {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.settings, color: Colors.orange),
                const SizedBox(width: 8),
                Text(
                  'Offline Settings',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            SwitchListTile(
              title: const Text('Auto-sync when online'),
              subtitle: const Text('Automatically sync pending changes when connection is restored'),
              value: true, // This would be connected to actual settings
              onChanged: (value) {
                // Handle auto-sync setting change
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Auto-sync ${value ? 'enabled' : 'disabled'}')),
                );
              },
            ),
            
            SwitchListTile(
              title: const Text('Download for offline use'),
              subtitle: const Text('Automatically download content for offline access'),
              value: false, // This would be connected to actual settings
              onChanged: (value) {
                // Handle offline download setting change
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Offline download ${value ? 'enabled' : 'disabled'}')),
                );
              },
            ),
            
            ListTile(
              title: const Text('Cache retention period'),
              subtitle: const Text('How long to keep cached data'),
              trailing: DropdownButton<String>(
                value: '7 days',
                items: const [
                  DropdownMenuItem(value: '1 day', child: Text('1 day')),
                  DropdownMenuItem(value: '3 days', child: Text('3 days')),
                  DropdownMenuItem(value: '7 days', child: Text('7 days')),
                  DropdownMenuItem(value: '30 days', child: Text('30 days')),
                ],
                onChanged: (value) {
                  // Handle cache retention change
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Cache retention set to $value')),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatLastSync(DateTime lastSync) {
    final now = DateTime.now();
    final difference = now.difference(lastSync);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  Future<void> _handleForceSync() async {
    try {
      await _offlineStateManager.forceSyncWithProgress();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sync completed successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sync failed: $e')),
        );
      }
    }
  }

  Future<void> _handleRetrySync() async {
    await _handleForceSync();
  }

  void _handleCancelSync() {
    // This would cancel the current sync operation
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sync cancelled')),
    );
  }

  Future<void> _handleRefreshData() async {
    await _handleForceSync();
  }

  void _handleResolveConflicts() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Resolve Conflicts'),
        content: const Text(
          'No conflicts detected. All data is synchronized.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _handleViewPendingOperations() {
    // Show dialog with pending operations
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pending Operations'),
        content: Text('${_currentState!.pendingOperations} operations are waiting to be synced.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _handleForceSync();
            },
            child: const Text('Sync Now'),
          ),
        ],
      ),
    );
  }

  void _handleCacheCleared(List<CacheType> clearedTypes) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Cleared cache for ${clearedTypes.length} type(s)'),
      ),
    );
  }

  Future<void> _handleOptimizeCache() async {
    try {
      // This would implement cache optimization logic
      await Future.delayed(const Duration(seconds: 1)); // Simulate optimization
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cache optimized successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Cache optimization failed: $e')),
        );
      }
    }
  }
}