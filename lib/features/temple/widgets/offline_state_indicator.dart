import 'package:flutter/material.dart';
import '../services/offline_state_manager.dart';
import '../../../shared/services/offline/offline_manager.dart';

/// Widget that displays current offline state and sync status
class OfflineStateIndicator extends StatelessWidget {
  final OfflineState state;
  final VoidCallback? onTap;
  final bool showDetails;

  const OfflineStateIndicator({
    super.key,
    required this.state,
    this.onTap,
    this.showDetails = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: _getStatusColor(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _getStatusColor(context).withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_getStatusIcon(), size: 16, color: _getIconColor(context)),
            const SizedBox(width: 6),
            Text(
              _getStatusText(),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: _getTextColor(context),
                fontWeight: FontWeight.w500,
              ),
            ),
            if (showDetails && state.pendingOperations > 0) ...[
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${state.pendingOperations}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.orange.shade700,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  IconData _getStatusIcon() {
    if (!state.isOnline) return Icons.cloud_off;

    switch (state.syncStatus) {
      case SyncStatus.syncing:
        return Icons.sync;
      case SyncStatus.success:
      case SyncStatus.synced:
        return Icons.cloud_done;
      case SyncStatus.error:
      case SyncStatus.failed:
        return Icons.cloud_off;
      case SyncStatus.conflict:
        return Icons.warning;
      case SyncStatus.pending:
        return Icons.cloud_queue;
      case SyncStatus.offline:
        return Icons.cloud_off;
      case SyncStatus.idle:
        return Icons.cloud;
    }
  }

  Color _getStatusColor(BuildContext context) {
    if (!state.isOnline) {
      return Colors.grey.withValues(alpha: 0.1);
    }

    switch (state.syncStatus) {
      case SyncStatus.syncing:
        return Colors.blue.withValues(alpha: 0.1);
      case SyncStatus.success:
      case SyncStatus.synced:
        return Colors.green.withValues(alpha: 0.1);
      case SyncStatus.error:
      case SyncStatus.failed:
        return Colors.red.withValues(alpha: 0.1);
      case SyncStatus.conflict:
        return Colors.orange.withValues(alpha: 0.1);
      case SyncStatus.pending:
        return Colors.amber.withValues(alpha: 0.1);
      case SyncStatus.offline:
        return Colors.grey.withValues(alpha: 0.1);
      case SyncStatus.idle:
        return Colors.grey.withValues(alpha: 0.05);
    }
  }

  Color _getIconColor(BuildContext context) {
    if (!state.isOnline) return Colors.grey;

    switch (state.syncStatus) {
      case SyncStatus.syncing:
        return Colors.orange;
      case SyncStatus.success:
      case SyncStatus.synced:
        return Colors.green;
      case SyncStatus.error:
      case SyncStatus.failed:
        return Colors.red;
      case SyncStatus.conflict:
        return Colors.orange;
      case SyncStatus.pending:
        return Colors.amber.shade700;
      case SyncStatus.offline:
        return Colors.grey;
      case SyncStatus.idle:
        return Colors.grey.shade600;
    }
  }

  Color _getTextColor(BuildContext context) {
    return _getIconColor(context);
  }

  String _getStatusText() {
    if (!state.isOnline) return 'Offline';

    switch (state.syncStatus) {
      case SyncStatus.syncing:
        return 'Syncing...';
      case SyncStatus.success:
        return 'Synced';
      case SyncStatus.synced:
        return 'Up to date';
      case SyncStatus.error:
      case SyncStatus.failed:
        return 'Sync failed';
      case SyncStatus.conflict:
        return 'Conflicts';
      case SyncStatus.pending:
        return 'Pending';
      case SyncStatus.offline:
        return 'Offline';
      case SyncStatus.idle:
        return 'Ready';
    }
  }
}

/// Detailed sync progress widget
class SyncProgressWidget extends StatelessWidget {
  final OfflineState state;
  final VoidCallback? onRetry;
  final VoidCallback? onCancel;

  const SyncProgressWidget({
    super.key,
    required this.state,
    this.onRetry,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    if (!state.isSyncing && state.syncStatus != SyncStatus.error) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  state.isSyncing ? Icons.sync : Icons.error,
                  color: state.isSyncing ? Colors.orange : Colors.red,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    state.isSyncing ? 'Syncing Data' : 'Sync Failed',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (state.isSyncing && onCancel != null)
                  TextButton(onPressed: onCancel, child: const Text('Cancel')),
              ],
            ),
            const SizedBox(height: 8),
            if (state.isSyncing) ...[
              LinearProgressIndicator(
                value: state.syncProgress,
                backgroundColor: Colors.grey.shade200,
              ),
              const SizedBox(height: 8),
              Text(
                state.currentSyncOperation ?? 'Syncing...',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
              ),
              Text(
                '${(state.syncProgress * 100).toInt()}% complete',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.grey.shade500),
              ),
            ] else ...[
              Text(
                'Failed to sync data. Check your connection and try again.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              if (onRetry != null)
                ElevatedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry Sync'),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Widget showing offline data freshness warning
class DataFreshnessIndicator extends StatelessWidget {
  final OfflineState state;
  final VoidCallback? onRefresh;

  const DataFreshnessIndicator({
    super.key,
    required this.state,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (!state.isDataStale || state.isOnline) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        border: Border.all(color: Colors.amber.shade200),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.schedule, color: Colors.amber.shade700, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Data may be outdated',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: Colors.amber.shade800,
                  ),
                ),
                if (state.lastSyncTime != null)
                  Text(
                    'Last updated: ${_formatLastSync(state.lastSyncTime!)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.amber.shade700,
                    ),
                  ),
              ],
            ),
          ),
          if (onRefresh != null && state.isOnline)
            TextButton(
              onPressed: onRefresh,
              child: Text(
                'Refresh',
                style: TextStyle(color: Colors.amber.shade700),
              ),
            ),
        ],
      ),
    );
  }

  String _formatLastSync(DateTime lastSync) {
    final now = DateTime.now();
    final difference = now.difference(lastSync);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }
}

/// Conflict resolution indicator
class ConflictIndicator extends StatelessWidget {
  final List<ConflictInfo> conflicts;
  final VoidCallback? onResolve;

  const ConflictIndicator({super.key, required this.conflicts, this.onResolve});

  @override
  Widget build(BuildContext context) {
    if (conflicts.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        border: Border.all(color: Colors.orange.shade200),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.warning, color: Colors.orange.shade700, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${conflicts.length} data conflict${conflicts.length > 1 ? 's' : ''} need resolution',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: Colors.orange.shade800,
                  ),
                ),
                Text(
                  'Some data was modified both locally and on the server',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.orange.shade700,
                  ),
                ),
              ],
            ),
          ),
          if (onResolve != null)
            TextButton(
              onPressed: onResolve,
              child: Text(
                'Resolve',
                style: TextStyle(color: Colors.orange.shade700),
              ),
            ),
        ],
      ),
    );
  }
}
