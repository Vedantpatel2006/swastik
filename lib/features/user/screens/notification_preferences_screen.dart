import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/themes/app_colors.dart';
import '../../../shared/models/notification.dart';
import '../../../shared/services/notification_service.dart';
import '../../../core/services/localization_service.dart';
import '../../../providers/auth_provider.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../../../shared/widgets/common/error_widget.dart';

/// Screen for managing notification preferences with regional customization
class NotificationPreferencesScreen extends StatefulWidget {
  const NotificationPreferencesScreen({super.key});

  @override
  State<NotificationPreferencesScreen> createState() =>
      _NotificationPreferencesScreenState();
}

class _NotificationPreferencesScreenState
    extends State<NotificationPreferencesScreen> {
  NotificationPreferences? _preferences;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;

  // Form controllers
  late bool _enableNotifications;
  late bool _enableFestivalNotifications;
  late bool _enableEventNotifications;
  late bool _enableEmergencyNotifications;
  late bool _enableLocationNotifications;
  late List<String> _culturalEventCategories;
  late List<String> _interestedDistricts;
  late double _locationRadiusKm;
  late bool _enableSound;
  late bool _enableVibration;
  late TimeOfDay _quietHoursStart;
  late TimeOfDay _quietHoursEnd;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.currentUser?.uid;

      if (userId != null) {
        final notificationService = NotificationService();
        final preferences = await notificationService
            .getNotificationPreferences(userId);

        _preferences = preferences;
        _initializeFormValues(preferences);
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _initializeFormValues(NotificationPreferences preferences) {
    _enableNotifications = preferences.enablePushNotifications;
    _enableFestivalNotifications = preferences.enableFestivalNotifications;
    _enableEventNotifications = preferences.enableEventReminders;
    _enableEmergencyNotifications = preferences.enableEmergencyNotifications;
    _enableLocationNotifications = preferences.enableLocationNotifications;
    _culturalEventCategories = List.from(preferences.culturalEventCategories);
    _interestedDistricts = List.from(preferences.interestedDistricts);
    _locationRadiusKm = preferences.locationRadiusKm;
    _enableSound = preferences.enableSoundNotifications;
    _enableVibration = preferences.enableVibrationNotifications;
    _quietHoursStart = _parseTime(preferences.quietHoursStart);
    _quietHoursEnd = _parseTime(preferences.quietHoursEnd);
  }

  TimeOfDay _parseTime(String timeString) {
    final parts = timeString.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  String _formatTime(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _savePreferences() async {
    if (_preferences == null) return;

    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      final updatedPreferences = _preferences!.copyWith(
        enablePushNotifications: _enableNotifications,
        enableFestivalNotifications: _enableFestivalNotifications,
        enableEventReminders: _enableEventNotifications,
        enableEmergencyNotifications: _enableEmergencyNotifications,
        enableLocationNotifications: _enableLocationNotifications,
        culturalEventCategories: _culturalEventCategories,
        interestedDistricts: _interestedDistricts,
        locationRadiusKm: _locationRadiusKm,
        enableSoundNotifications: _enableSound,
        enableVibrationNotifications: _enableVibration,
        quietHoursStart: _formatTime(_quietHoursStart),
        quietHoursEnd: _formatTime(_quietHoursEnd),
        updatedAt: DateTime.now(),
      );

      final notificationService = NotificationService();
      await notificationService.updateNotificationPreferences(
        updatedPreferences,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              LocalizationService.getLocalizedText('preferences_saved'),
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              LocalizationService.getLocalizedText('error_saving_preferences'),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.creamBackground,
      appBar: AppBar(
        title: Text(
          LocalizationService.getLocalizedText('notification_preferences'),
          style: const TextStyle(
            color: AppColors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: AppColors.primaryOrange,
        foregroundColor: AppColors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.white),
        actions: [
          if (!_isLoading && !_isSaving)
            TextButton(
              onPressed: _savePreferences,
              child: const Text(
                'Save',
                style: TextStyle(
                  color: AppColors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ),
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.white),
                ),
              ),
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const LoadingWidget();
    }

    if (_error != null) {
      return ErrorDisplayWidget(error: _error!, onRetry: _loadPreferences);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildGeneralSettings(),
          const SizedBox(height: 24),
          _buildNotificationTypes(),
          const SizedBox(height: 24),
          _buildCulturalCategories(),
          const SizedBox(height: 24),
          _buildLanguagePreferences(),
          const SizedBox(height: 24),
          _buildLocationSettings(),
          const SizedBox(height: 24),
          _buildSoundVibrationSettings(),
          const SizedBox(height: 24),
          _buildQuietHours(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildGeneralSettings() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              LocalizationService.getLocalizedText('general_settings'),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.primaryText,
              ),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                LocalizationService.getLocalizedText('enable_notifications'),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: AppColors.primaryText,
                ),
              ),
              subtitle: Text(
                LocalizationService.getLocalizedText(
                  'enable_notifications_desc',
                ),
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.secondaryText,
                ),
              ),
              value: _enableNotifications,
              activeColor: AppColors.primaryOrange,
              onChanged: (value) {
                setState(() {
                  _enableNotifications = value;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationTypes() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              LocalizationService.getLocalizedText('notification_types'),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.primaryText,
              ),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                LocalizationService.getLocalizedText('festival_notifications'),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: AppColors.primaryText,
                ),
              ),
              subtitle: Text(
                LocalizationService.getLocalizedText(
                  'festival_notifications_desc',
                ),
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.secondaryText,
                ),
              ),
              value: _enableFestivalNotifications,
              activeColor: AppColors.primaryOrange,
              onChanged: _enableNotifications
                  ? (value) {
                      setState(() {
                        _enableFestivalNotifications = value;
                      });
                    }
                  : null,
            ),
            const Divider(height: 1, color: AppColors.borderGray),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                LocalizationService.getLocalizedText('event_notifications'),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: AppColors.primaryText,
                ),
              ),
              subtitle: Text(
                LocalizationService.getLocalizedText(
                  'event_notifications_desc',
                ),
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.secondaryText,
                ),
              ),
              value: _enableEventNotifications,
              activeColor: AppColors.primaryOrange,
              onChanged: _enableNotifications
                  ? (value) {
                      setState(() {
                        _enableEventNotifications = value;
                      });
                    }
                  : null,
            ),
            const Divider(height: 1, color: AppColors.borderGray),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                LocalizationService.getLocalizedText('emergency_notifications'),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: AppColors.primaryText,
                ),
              ),
              subtitle: Text(
                LocalizationService.getLocalizedText(
                  'emergency_notifications_desc',
                ),
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.secondaryText,
                ),
              ),
              value: _enableEmergencyNotifications,
              activeColor: AppColors.primaryOrange,
              onChanged: _enableNotifications
                  ? (value) {
                      setState(() {
                        _enableEmergencyNotifications = value;
                      });
                    }
                  : null,
            ),
            const Divider(height: 1, color: AppColors.borderGray),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                LocalizationService.getLocalizedText('location_notifications'),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: AppColors.primaryText,
                ),
              ),
              subtitle: Text(
                LocalizationService.getLocalizedText(
                  'location_notifications_desc',
                ),
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.secondaryText,
                ),
              ),
              value: _enableLocationNotifications,
              activeColor: AppColors.primaryOrange,
              onChanged: _enableNotifications
                  ? (value) {
                      setState(() {
                        _enableLocationNotifications = value;
                      });
                    }
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCulturalCategories() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              LocalizationService.getLocalizedText('cultural_categories'),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.primaryText,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8.0,
              runSpacing: 8.0,
              children: _culturalEventCategories.map((category) {
                return FilterChip(
                  label: Text(category),
                  selected: true,
                  selectedColor: AppColors.primaryOrange.withValues(
                    alpha: 0.15,
                  ),
                  checkmarkColor: AppColors.primaryOrange,
                  labelStyle: const TextStyle(
                    color: AppColors.primaryOrange,
                    fontWeight: FontWeight.w500,
                  ),
                  side: const BorderSide(color: AppColors.primaryOrange),
                  onSelected: _enableNotifications
                      ? (selected) {
                          setState(() {
                            if (!selected) {
                              _culturalEventCategories.remove(category);
                            }
                          });
                        }
                      : null,
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguagePreferences() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              LocalizationService.getLocalizedText('language_preferences'),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.primaryText,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8.0,
              runSpacing: 8.0,
              children: ['en', 'hi', 'gu'].map((langCode) {
                final langName =
                    {
                      'en': 'English',
                      'hi': 'Hindi',
                      'gu': 'Gujarati',
                    }[langCode] ??
                    langCode;
                return FilterChip(
                  label: Text(langName),
                  selected: true,
                  selectedColor: AppColors.primaryOrange.withValues(
                    alpha: 0.15,
                  ),
                  checkmarkColor: AppColors.primaryOrange,
                  labelStyle: const TextStyle(
                    color: AppColors.primaryOrange,
                    fontWeight: FontWeight.w500,
                  ),
                  side: const BorderSide(color: AppColors.primaryOrange),
                  onSelected: null,
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationSettings() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              LocalizationService.getLocalizedText('location_settings'),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.primaryText,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  LocalizationService.getLocalizedText('notification_radius'),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: AppColors.primaryText,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primaryOrange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '${_locationRadiusKm.toInt()} km',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryOrange,
                    ),
                  ),
                ),
              ],
            ),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: AppColors.primaryOrange,
                inactiveTrackColor: AppColors.borderGray,
                thumbColor: AppColors.primaryOrange,
                overlayColor: AppColors.primaryOrange.withValues(alpha: 0.2),
              ),
              child: Slider(
                value: _locationRadiusKm,
                min: 1.0,
                max: 50.0,
                divisions: 49,
                onChanged: _enableNotifications && _enableLocationNotifications
                    ? (value) {
                        setState(() {
                          _locationRadiusKm = value;
                        });
                      }
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSoundVibrationSettings() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              LocalizationService.getLocalizedText('sound_vibration'),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.primaryText,
              ),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                LocalizationService.getLocalizedText('enable_sound'),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: AppColors.primaryText,
                ),
              ),
              value: _enableSound,
              activeColor: AppColors.primaryOrange,
              onChanged: _enableNotifications
                  ? (value) {
                      setState(() {
                        _enableSound = value;
                      });
                    }
                  : null,
            ),
            const Divider(height: 1, color: AppColors.borderGray),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                LocalizationService.getLocalizedText('enable_vibration'),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: AppColors.primaryText,
                ),
              ),
              value: _enableVibration,
              activeColor: AppColors.primaryOrange,
              onChanged: _enableNotifications
                  ? (value) {
                      setState(() {
                        _enableVibration = value;
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
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              LocalizationService.getLocalizedText('quiet_hours'),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.primaryText,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'No notifications will be sent during these hours',
              style: TextStyle(fontSize: 12, color: AppColors.secondaryText),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: _enableNotifications
                        ? () async {
                            final time = await showTimePicker(
                              context: context,
                              initialTime: _quietHoursStart,
                              builder: (context, child) => Theme(
                                data: Theme.of(context).copyWith(
                                  colorScheme: Theme.of(context).colorScheme
                                      .copyWith(
                                        primary: AppColors.primaryOrange,
                                      ),
                                ),
                                child: child!,
                              ),
                            );
                            if (time != null) {
                              setState(() {
                                _quietHoursStart = time;
                              });
                            }
                          }
                        : null,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.veryLightGray,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.borderGray),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            LocalizationService.getLocalizedText('start_time'),
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.secondaryText,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _formatTime(_quietHoursStart),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primaryText,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: _enableNotifications
                        ? () async {
                            final time = await showTimePicker(
                              context: context,
                              initialTime: _quietHoursEnd,
                              builder: (context, child) => Theme(
                                data: Theme.of(context).copyWith(
                                  colorScheme: Theme.of(context).colorScheme
                                      .copyWith(
                                        primary: AppColors.primaryOrange,
                                      ),
                                ),
                                child: child!,
                              ),
                            );
                            if (time != null) {
                              setState(() {
                                _quietHoursEnd = time;
                              });
                            }
                          }
                        : null,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.veryLightGray,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.borderGray),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            LocalizationService.getLocalizedText('end_time'),
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.secondaryText,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _formatTime(_quietHoursEnd),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primaryText,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
