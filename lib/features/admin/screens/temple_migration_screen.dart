import 'package:flutter/material.dart';
import '../../temple/services/temple_migration_service.dart';

/// Screen for running temple data migrations
class TempleMigrationScreen extends StatefulWidget {
  const TempleMigrationScreen({super.key});

  @override
  State<TempleMigrationScreen> createState() => _TempleMigrationScreenState();
}

class _TempleMigrationScreenState extends State<TempleMigrationScreen> {
  final TempleMigrationService _migrationService = TempleMigrationService();

  bool _isLoading = false;
  bool _isMigrating = false;
  double _progress = 0.0;
  String _statusMessage = '';
  int _templesNeedingMigration = 0;

  @override
  void initState() {
    super.initState();
    _checkMigrationStatus();
  }

  Future<void> _checkMigrationStatus() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Checking temples...';
    });

    try {
      final count = await _migrationService.countTemplesNeedingMigration();
      setState(() {
        _templesNeedingMigration = count;
        _statusMessage = count > 0
            ? '$count temples need image migration'
            : 'All temples are up to date';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Error checking migration status: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _runMigration() async {
    setState(() {
      _isMigrating = true;
      _progress = 0.0;
      _statusMessage = 'Starting migration...';
    });

    try {
      final result = await _migrationService.migrateTempleImages(
        onStatusUpdate: (status) {
          setState(() {
            _statusMessage = status;
          });
        },
        onProgress: (progress) {
          setState(() {
            _progress = progress;
          });
        },
      );

      setState(() {
        _isMigrating = false;
        _statusMessage = result.toString();
      });

      await _checkMigrationStatus();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result.success
                  ? 'Migration completed successfully!'
                  : 'Migration failed',
            ),
            backgroundColor: result.success ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isMigrating = false;
        _statusMessage = 'Migration error: $e';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Migration failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Temple Data Migration')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Image Migration',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Ensures temple images are visible to both admin and users.',
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    if (_isLoading)
                      const Center(child: CircularProgressIndicator())
                    else ...[
                      Row(
                        children: [
                          Icon(
                            _templesNeedingMigration > 0
                                ? Icons.warning
                                : Icons.check_circle,
                            color: _templesNeedingMigration > 0
                                ? Colors.orange
                                : Colors.green,
                          ),
                          const SizedBox(width: 8),
                          Expanded(child: Text(_statusMessage)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (_templesNeedingMigration > 0)
                        ElevatedButton.icon(
                          onPressed: _isMigrating ? null : _runMigration,
                          icon: const Icon(Icons.sync),
                          label: const Text('Run Migration'),
                        )
                      else
                        OutlinedButton.icon(
                          onPressed: _checkMigrationStatus,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Refresh Status'),
                        ),
                    ],
                  ],
                ),
              ),
            ),
            if (_isMigrating) ...[
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      LinearProgressIndicator(value: _progress),
                      const SizedBox(height: 8),
                      Text('${(_progress * 100).toStringAsFixed(0)}% complete'),
                      const SizedBox(height: 8),
                      Text(
                        _statusMessage,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
