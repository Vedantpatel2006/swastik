import 'package:flutter/material.dart';

import '../../../core/themes/app_colors.dart';
import '../../../shared/models/notification.dart';
import '../../../shared/services/notification_service.dart';
import '../../../core/services/localization_service.dart';

/// Widget for managing user notification preferences
class NotificationPreferencesWidget extends StatefulWidget {
  final String userId;
  final NotificationPreferences? initialPreferences;

  const NotificationPreferencesWidget({
    super.key,
    required this.userId,
    this.initialPreferences,
  });

  @override
  State<NotificationPreferencesWidget> createState() =>
      _NotificationPreferencesWidgetState();
}

class _NotificationPreferencesWidgetState
    extends State<NotificationPreferencesWidget> {
  late NotificationPreferences _preferences;
  bool _isLoading = false;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _preferences = widget.initialPreferences ?? _getDefaultPreferences();
  }

  NotificationPreferences _getDefaultPreferences() {
    return NotificationPreferences(
      userId: widget.userId,
      updatedAt: DateTime.now(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_getLocalizedText('notification_preferences')),
        actions: [
          if (_hasChanges)
            TextButton(
              onPressed: _isLoading ? null : _savePreferences,
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_getLocalizedText('save')),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildGeneralSettings(),
            const SizedBox(height: 24),
            _buildNotificationTypes(),
            const SizedBox(height: 24),
            _buildLocationSettings(),
            const SizedBox(height: 24),
            _buildSoundAndVibration(),
            const SizedBox(height: 24),
            _buildQuietHours(),
          ],
        ),
      ),
    );
  }

  Widget _buildGeneralSettings() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _getLocalizedText('general_settings'),
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: Text(_getLocalizedText('enable_notifications')),
              subtitle: Text(_getLocalizedText('enable_notifications_desc')),
              value: _preferences.enablePushNotifications,
              onChanged: (value) {
                setState(() {
                  _preferences = _preferences.copyWith(
                    enablePushNotifications: value,
                    updatedAt: DateTime.now(),
                  );
                  _hasChanges = true;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationTypes() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _getLocalizedText('notification_types'),
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: Text(_getLocalizedText('temple_updates')),
              subtitle: Text(_getLocalizedText('temple_updates_desc')),
              value: _preferences.enableTempleUpdates,
              onChanged: _preferences.enablePushNotifications
                  ? (value) {
                      setState(() {
                        _preferences = _preferences.copyWith(
                          enableTempleUpdates: value,
                          updatedAt: DateTime.now(),
                        );
                        _hasChanges = true;
                      });
                    }
                  : null,
            ),
            SwitchListTile(
              title: Text(_getLocalizedText('event_reminders')),
              subtitle: Text(_getLocalizedText('event_reminders_desc')),
              value: _preferences.enableEventReminders,
              onChanged: _preferences.enablePushNotifications
                  ? (value) {
                      setState(() {
                        _preferences = _preferences.copyWith(
                          enableEventReminders: value,
                          updatedAt: DateTime.now(),
                        );
                        _hasChanges = true;
                      });
                    }
                  : null,
            ),
            SwitchListTile(
              title: Text(_getLocalizedText('booking_reminders')),
              subtitle: Text(_getLocalizedText('booking_reminders_desc')),
              value: _preferences.enableBookingReminders,
              onChanged: _preferences.enablePushNotifications
                  ? (value) {
                      setState(() {
                        _preferences = _preferences.copyWith(
                          enableBookingReminders: value,
                          updatedAt: DateTime.now(),
                        );
                        _hasChanges = true;
                      });
                    }
                  : null,
            ),
            SwitchListTile(
              title: Text(_getLocalizedText('live_stream_notifications')),
              subtitle: Text(
                _getLocalizedText('live_stream_notifications_desc'),
              ),
              value: _preferences.enableLiveStreamNotifications,
              onChanged: _preferences.enablePushNotifications
                  ? (value) {
                      setState(() {
                        _preferences = _preferences.copyWith(
                          enableLiveStreamNotifications: value,
                          updatedAt: DateTime.now(),
                        );
                        _hasChanges = true;
                      });
                    }
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationSettings() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _getLocalizedText('location_settings'),
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: Text(_getLocalizedText('location_notifications')),
              subtitle: Text(_getLocalizedText('location_notifications_desc')),
              value: _preferences.enableLocationNotifications,
              onChanged: _preferences.enablePushNotifications
                  ? (value) {
                      setState(() {
                        _preferences = _preferences.copyWith(
                          enableLocationNotifications: value,
                          updatedAt: DateTime.now(),
                        );
                        _hasChanges = true;
                      });
                    }
                  : null,
            ),
            ListTile(
              title: Text(_getLocalizedText('notification_radius')),
              subtitle: Text('${_preferences.locationRadiusKm.toInt()} km'),
              trailing: SizedBox(
                width: 200,
                child: Slider(
                  value: _preferences.locationRadiusKm,
                  min: 1.0,
                  max: 50.0,
                  divisions: 49,
                  label: '${_preferences.locationRadiusKm.toInt()} km',
                  onChanged:
                      _preferences.enablePushNotifications &&
                          _preferences.enableLocationNotifications
                      ? (value) {
                          setState(() {
                            _preferences = _preferences.copyWith(
                              locationRadiusKm: value,
                              updatedAt: DateTime.now(),
                            );
                            _hasChanges = true;
                          });
                        }
                      : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSoundAndVibration() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _getLocalizedText('sound_vibration'),
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: Text(_getLocalizedText('enable_sound')),
              value: _preferences.enableSoundNotifications,
              onChanged: _preferences.enablePushNotifications
                  ? (value) {
                      setState(() {
                        _preferences = _preferences.copyWith(
                          enableSoundNotifications: value,
                          updatedAt: DateTime.now(),
                        );
                        _hasChanges = true;
                      });
                    }
                  : null,
            ),
            SwitchListTile(
              title: Text(_getLocalizedText('enable_vibration')),
              value: _preferences.enableVibrationNotifications,
              onChanged: _preferences.enablePushNotifications
                  ? (value) {
                      setState(() {
                        _preferences = _preferences.copyWith(
                          enableVibrationNotifications: value,
                          updatedAt: DateTime.now(),
                        );
                        _hasChanges = true;
                      });
                    }
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuietHours() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _getLocalizedText('quiet_hours'),
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: Text(_getLocalizedText('enable_quiet_hours')),
              subtitle: Text(_getLocalizedText('enable_quiet_hours_desc')),
              value: _preferences.enableQuietHours,
              onChanged: _preferences.enablePushNotifications
                  ? (value) {
                      setState(() {
                        _preferences = _preferences.copyWith(
                          enableQuietHours: value,
                          updatedAt: DateTime.now(),
                        );
                        _hasChanges = true;
                      });
                    }
                  : null,
            ),
            if (_preferences.enableQuietHours) ...[
              Row(
                children: [
                  Expanded(
                    child: ListTile(
                      title: Text(_getLocalizedText('start_time')),
                      subtitle: Text(_preferences.quietHoursStart),
                      onTap: () => _selectTime(true),
                    ),
                  ),
                  Expanded(
                    child: ListTile(
                      title: Text(_getLocalizedText('end_time')),
                      subtitle: Text(_preferences.quietHoursEnd),
                      onTap: () => _selectTime(false),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _selectTime(bool isStartTime) async {
    final currentTime = isStartTime
        ? _preferences.quietHoursStart
        : _preferences.quietHoursEnd;
    final parts = currentTime.split(':');
    final initialTime = TimeOfDay(
      hour: int.parse(parts[0]),
      minute: int.parse(parts[1]),
    );

    final selectedTime = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );

    if (selectedTime != null) {
      final timeString =
          '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}';
      setState(() {
        _preferences = _preferences.copyWith(
          quietHoursStart: isStartTime
              ? timeString
              : _preferences.quietHoursStart,
          quietHoursEnd: isStartTime ? _preferences.quietHoursEnd : timeString,
          updatedAt: DateTime.now(),
        );
        _hasChanges = true;
      });
    }
  }

  Future<void> _savePreferences() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final notificationService = NotificationService();
      await notificationService.updateNotificationPreferences(_preferences);
      setState(() {
        _hasChanges = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_getLocalizedText('preferences_saved')),
            backgroundColor: AppColors.successGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_getLocalizedText('error_saving_preferences')),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _getLocalizedText(String key) {
    return LocalizationService.getLocalizedText(key);
  }
}
