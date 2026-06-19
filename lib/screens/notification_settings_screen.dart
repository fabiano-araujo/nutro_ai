import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../i18n/app_localizations_extension.dart';
import '../models/notification_preferences.dart';
import '../providers/meal_types_provider.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import 'manage_meal_types_screen.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  NotificationPreferences _preferences = NotificationPreferences.defaults;
  final Set<NotificationPreferenceType> _savingTypes =
      <NotificationPreferenceType>{};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<MealTypesProvider>().ensureLoaded();
      }
    });
  }

  Future<void> _loadPreferences() async {
    try {
      final preferences = await NotificationService().getPreferences();
      if (!mounted) return;
      setState(() {
        _preferences = preferences;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showSnackBar(context.tr.translate('notification_update_error'));
    }
  }

  Future<void> _setPreference(
    NotificationPreferenceType type,
    bool enabled,
  ) async {
    if (_savingTypes.contains(type)) return;

    final previousPreferences = _preferences;
    setState(() {
      _preferences = _preferences.copyWithType(type, enabled);
      _savingTypes.add(type);
    });

    try {
      final updatedPreferences = await NotificationService().setPreference(
        type,
        enabled,
      );

      if (!mounted) return;
      setState(() => _preferences = updatedPreferences);

      if (enabled && !updatedPreferences.isEnabled(type)) {
        _showSnackBar(context.tr.translate('notification_permission_denied'));
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _preferences = previousPreferences);
      _showSnackBar(context.tr.translate('notification_update_error'));
    } finally {
      if (mounted) {
        setState(() => _savingTypes.remove(type));
      }
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final backgroundColor =
        isDarkMode ? AppTheme.darkBackgroundColor : AppTheme.backgroundColor;
    final textColor = isDarkMode ? Colors.white : const Color(0xFF1F2933);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(textColor),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                      child: Consumer<MealTypesProvider>(
                        builder: (context, mealTypesProvider, child) {
                          return Column(
                            children: [
                              _buildNotificationTile(
                                theme: theme,
                                icon: Icons.restaurant_menu_rounded,
                                iconColor: const Color(0xFFC4C8C2),
                                title: context.tr.translate('meal_reminders'),
                                subtitle: context.tr
                                    .translate('notification_meal_schedule'),
                                type: NotificationPreferenceType.mealReminders,
                              ),
                              const SizedBox(height: 12),
                              _buildMealTimesPanel(theme, mealTypesProvider),
                              const SizedBox(height: 20),
                              _buildNotificationTile(
                                theme: theme,
                                icon: Icons.monitor_weight_outlined,
                                iconColor: const Color(0xFF8ECFC3),
                                title: context.tr.translate('weight_reminders'),
                                subtitle: _weightScheduleSummary(),
                                type:
                                    NotificationPreferenceType.weightReminders,
                              ),
                              const SizedBox(height: 12),
                              _buildWeightReminderSettingsPanel(theme),
                              const SizedBox(height: 20),
                              _buildNotificationTile(
                                theme: theme,
                                icon: Icons.menu_book_rounded,
                                iconColor: const Color(0xFF263247),
                                title:
                                    context.tr.translate('personalized_tips'),
                                subtitle: _translatedSchedule(
                                  'notification_tip_schedule',
                                  _preferences.personalizedTipTime,
                                ),
                                type:
                                    NotificationPreferenceType.personalizedTips,
                              ),
                              const SizedBox(height: 12),
                              _buildStandaloneReminderTimePanel(
                                theme: theme,
                                title: context.tr.translate(
                                  'personalized_tip_time',
                                ),
                                time: _preferences.personalizedTipTime,
                                type:
                                    NotificationPreferenceType.personalizedTips,
                              ),
                            ],
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(Color textColor) {
    const sideWidth = 56.0;

    return SizedBox(
      height: 64,
      child: Row(
        children: [
          SizedBox(
            width: sideWidth,
            child: Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                icon: Icon(Icons.arrow_back_rounded, color: textColor),
                tooltip: context.tr.translate('back'),
                onPressed: () => Navigator.maybePop(context),
              ),
            ),
          ),
          Expanded(
            child: Text(
              context.tr.translate('notification_settings_title'),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: textColor,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                height: 1.05,
              ),
            ),
          ),
          const SizedBox(width: sideWidth),
        ],
      ),
    );
  }

  Widget _buildNotificationTile({
    required ThemeData theme,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required NotificationPreferenceType type,
  }) {
    final isDarkMode = theme.brightness == Brightness.dark;
    final enabled = _preferences.isEnabled(type);
    final isSaving = _savingTypes.contains(type);
    final textColor = _textColor(isDarkMode);
    final subtitleColor = _mutedTextColor(isDarkMode);
    final radius = BorderRadius.circular(20);

    return Container(
      decoration: AppTheme.profileCardDecoration(isDarkMode, radius: 20),
      child: Material(
        color: Colors.transparent,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: isSaving ? null : () => _setPreference(type, !enabled),
          borderRadius: radius,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: isDarkMode ? 0.18 : 0.1),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(icon, color: iconColor, size: 23),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          height: 1.16,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: subtitleColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 50,
                  child: Center(
                    child: isSaving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.2),
                          )
                        : Transform.scale(
                            scale: 0.82,
                            child: Switch(
                              value: enabled,
                              activeThumbColor: theme.colorScheme.primary,
                              activeTrackColor: theme.colorScheme.primary
                                  .withValues(alpha: 0.34),
                              onChanged: (value) => _setPreference(type, value),
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMealTimesPanel(
    ThemeData theme,
    MealTypesProvider mealTypesProvider,
  ) {
    final isDarkMode = theme.brightness == Brightness.dark;
    final textColor = _textColor(isDarkMode);
    final mutedColor = _mutedTextColor(isDarkMode);
    final mealTypes = mealTypesProvider.mealTypes;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      decoration: AppTheme.profileCardDecoration(isDarkMode, radius: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr.translate('meal_reminder_times'),
                      style: TextStyle(
                        color: textColor,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        height: 1.18,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      context.tr.translate('meal_reminder_times_hint'),
                      style: TextStyle(
                        color: mutedColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: _openMealManager,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text(context.tr.translate('add_meal_short')),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (mealTypesProvider.mealTypes.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                context.tr.translate('no_meals_registered'),
                style: TextStyle(color: mutedColor),
              ),
            )
          else
            for (var index = 0; index < mealTypes.length; index++) ...[
              _buildMealTimeRow(theme, mealTypes[index]),
              if (index < mealTypes.length - 1)
                Divider(
                  height: 1,
                  thickness: 1,
                  indent: 50,
                  color: _dividerColor(isDarkMode),
                ),
            ],
        ],
      ),
    );
  }

  Widget _buildMealTimeRow(ThemeData theme, MealTypeConfig mealType) {
    final isDarkMode = theme.brightness == Brightness.dark;
    final textColor = _textColor(isDarkMode);
    final mutedColor = _mutedTextColor(isDarkMode);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: _secondarySurfaceColor(isDarkMode),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Center(
              child: Text(
                mealType.emoji,
                style: const TextStyle(fontSize: 21),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              mealType.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: textColor,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _pickMealTime(mealType),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.schedule_rounded, size: 17, color: mutedColor),
                    const SizedBox(width: 7),
                    Text(
                      mealType.reminderTime,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeightReminderSettingsPanel(ThemeData theme) {
    final isDarkMode = theme.brightness == Brightness.dark;
    final textColor = _textColor(isDarkMode);
    final mutedColor = _mutedTextColor(isDarkMode);
    final primaryColor = theme.colorScheme.primary;
    final isSaving =
        _savingTypes.contains(NotificationPreferenceType.weightReminders);
    final radius = BorderRadius.circular(20);

    return Container(
      decoration: AppTheme.profileCardDecoration(isDarkMode, radius: 20),
      child: Material(
        color: Colors.transparent,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: isSaving ? null : _openWeightReminderSettings,
          borderRadius: radius,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(
                      alpha: isDarkMode ? 0.18 : 0.1,
                    ),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(
                    Icons.event_repeat_rounded,
                    size: 22,
                    color: primaryColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr.translate('weight_reminder_config_title'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          height: 1.18,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _weightSettingsSubtitle(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: mutedColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.2),
                      )
                    : Icon(
                        Icons.chevron_right_rounded,
                        size: 24,
                        color: mutedColor,
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStandaloneReminderTimePanel({
    required ThemeData theme,
    required String title,
    required String time,
    required NotificationPreferenceType type,
  }) {
    final isDarkMode = theme.brightness == Brightness.dark;
    final textColor = _textColor(isDarkMode);
    final primaryColor = theme.colorScheme.primary;
    final isSaving = _savingTypes.contains(type);
    final radius = BorderRadius.circular(20);

    return Container(
      decoration: AppTheme.profileCardDecoration(isDarkMode, radius: 20),
      child: Material(
        color: Colors.transparent,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: isSaving ? null : () => _pickPreferenceTime(type, time),
          borderRadius: radius,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(
                      alpha: isDarkMode ? 0.18 : 0.1,
                    ),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(
                    Icons.schedule_rounded,
                    size: 22,
                    color: primaryColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      height: 1.18,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.2),
                      )
                    : Text(
                        time,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _textColor(bool isDarkMode) {
    return isDarkMode ? AppTheme.darkTextColor : AppTheme.textPrimaryColor;
  }

  Color _mutedTextColor(bool isDarkMode) {
    return isDarkMode
        ? AppTheme.darkMutedTextColor
        : AppTheme.textSecondaryColor;
  }

  Color _secondarySurfaceColor(bool isDarkMode) {
    return isDarkMode ? AppTheme.darkComponentColor : AppTheme.surfaceColor;
  }

  Color _dividerColor(bool isDarkMode) {
    return isDarkMode
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.05);
  }

  Future<void> _pickMealTime(MealTypeConfig mealType) async {
    final initialTime = _timeOfDayFromString(mealType.reminderTime);
    final selectedTime = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );

    if (selectedTime == null || !mounted) return;

    final formattedTime = _formatTimeOfDay(selectedTime);
    await context.read<MealTypesProvider>().updateMealType(
          mealType.id,
          reminderTime: formattedTime,
        );
  }

  Future<void> _pickPreferenceTime(
    NotificationPreferenceType type,
    String currentTime,
  ) async {
    if (_savingTypes.contains(type)) return;

    final selectedTime = await showTimePicker(
      context: context,
      initialTime: _timeOfDayFromString(currentTime),
    );

    if (selectedTime == null || !mounted) return;

    final formattedTime = _formatTimeOfDay(selectedTime);
    final previousPreferences = _preferences;
    setState(() {
      _preferences = _preferences.copyWithReminderTime(type, formattedTime);
      _savingTypes.add(type);
    });

    try {
      final updatedPreferences = await NotificationService().setReminderTime(
        type,
        formattedTime,
      );

      if (!mounted) return;
      setState(() => _preferences = updatedPreferences);
    } catch (_) {
      if (!mounted) return;
      setState(() => _preferences = previousPreferences);
      _showSnackBar(context.tr.translate('notification_update_error'));
    } finally {
      if (mounted) {
        setState(() => _savingTypes.remove(type));
      }
    }
  }

  Future<void> _openWeightReminderSettings() async {
    if (_savingTypes.contains(NotificationPreferenceType.weightReminders)) {
      return;
    }

    final result = await showModalBottomSheet<_WeightReminderSettings>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _WeightReminderSettingsSheet(
        initialTime: _preferences.weightReminderTime,
        initialWeekdays: _preferences.weightReminderWeekdays,
      ),
    );

    if (result == null || !mounted) return;
    await _saveWeightReminderSettings(result);
  }

  Future<void> _saveWeightReminderSettings(
    _WeightReminderSettings settings,
  ) async {
    final previousPreferences = _preferences;
    setState(() {
      _preferences = _preferences.copyWithWeightReminderSettings(
        reminderTime: settings.time,
        weekdays: settings.weekdays,
      );
      _savingTypes.add(NotificationPreferenceType.weightReminders);
    });

    try {
      final updatedPreferences =
          await NotificationService().setWeightReminderSettings(
        reminderTime: settings.time,
        weekdays: settings.weekdays,
      );

      if (!mounted) return;
      setState(() => _preferences = updatedPreferences);
    } catch (_) {
      if (!mounted) return;
      setState(() => _preferences = previousPreferences);
      _showSnackBar(context.tr.translate('notification_update_error'));
    } finally {
      if (mounted) {
        setState(
          () => _savingTypes.remove(NotificationPreferenceType.weightReminders),
        );
      }
    }
  }

  Future<void> _openMealManager() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const ManageMealTypesScreen(),
      ),
    );

    if (!mounted) return;
    await context.read<MealTypesProvider>().ensureLoaded();
    await NotificationService().syncScheduledNotifications();
  }

  TimeOfDay _timeOfDayFromString(String value) {
    final parts = value.split(':');
    final hour = int.tryParse(parts.first) ?? 12;
    final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    return TimeOfDay(
      hour: hour.clamp(0, 23).toInt(),
      minute: minute.clamp(0, 59).toInt(),
    );
  }

  String _formatTimeOfDay(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  String _weightScheduleSummary() {
    return context.tr
        .translate('notification_weight_schedule')
        .replaceAll('{count}', _preferences.weightReminderFrequency.toString())
        .replaceAll(
            '{days}', _weekdayListLabel(_preferences.weightReminderWeekdays))
        .replaceAll('{time}', _preferences.weightReminderTime);
  }

  String _weightSettingsSubtitle() {
    return '${_preferences.weightReminderFrequency}x - '
        '${_weekdayListLabel(_preferences.weightReminderWeekdays)} - '
        '${_preferences.weightReminderTime}';
  }

  String _translatedSchedule(String key, String time) {
    return context.tr.translate(key).replaceAll('{time}', time);
  }

  String _weekdayListLabel(List<int> weekdays) {
    return weekdays.map(_weekdayLabel).join(', ');
  }

  String _weekdayLabel(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return context.tr.translate('weekday_mon');
      case DateTime.tuesday:
        return context.tr.translate('weekday_tue');
      case DateTime.wednesday:
        return context.tr.translate('weekday_wed');
      case DateTime.thursday:
        return context.tr.translate('weekday_thu');
      case DateTime.friday:
        return context.tr.translate('weekday_fri');
      case DateTime.saturday:
        return context.tr.translate('weekday_sat');
      case DateTime.sunday:
        return context.tr.translate('weekday_sun');
      default:
        return weekday.toString();
    }
  }
}

class _WeightReminderSettings {
  const _WeightReminderSettings({
    required this.time,
    required this.weekdays,
  });

  final String time;
  final List<int> weekdays;
}

class _WeightReminderSettingsSheet extends StatefulWidget {
  const _WeightReminderSettingsSheet({
    required this.initialTime,
    required this.initialWeekdays,
  });

  final String initialTime;
  final List<int> initialWeekdays;

  @override
  State<_WeightReminderSettingsSheet> createState() =>
      _WeightReminderSettingsSheetState();
}

class _WeightReminderSettingsSheetState
    extends State<_WeightReminderSettingsSheet> {
  late String _time;
  late List<int> _weekdays;

  @override
  void initState() {
    super.initState();
    _time = widget.initialTime;
    _weekdays =
        NotificationPreferences.normalizeWeekdays(widget.initialWeekdays) ??
            NotificationPreferences.defaults.weightReminderWeekdays;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final sheetColor = isDarkMode ? AppTheme.darkCardColor : Colors.white;
    final textColor = isDarkMode ? Colors.white : const Color(0xFF1F2933);
    final mutedColor =
        isDarkMode ? const Color(0xFFADB5C5) : const Color(0xFF8B95A8);
    final primaryColor = theme.colorScheme.primary;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: sheetColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: mutedColor.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        context.tr.translate('weight_reminder_config_title'),
                        style: TextStyle(
                          color: textColor,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: context.tr.translate('cancel'),
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(Icons.close_rounded, color: textColor),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildTimeButton(theme, textColor, mutedColor),
                const SizedBox(height: 22),
                Text(
                  context.tr.translate('weight_reminder_frequency'),
                  style: TextStyle(
                    color: textColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (var count = 1; count <= 7; count++)
                      ChoiceChip(
                        label: Text('${count}x'),
                        selected: _weekdays.length == count,
                        selectedColor: primaryColor.withValues(alpha: 0.16),
                        labelStyle: TextStyle(
                          color: _weekdays.length == count
                              ? primaryColor
                              : textColor,
                          fontWeight: FontWeight.w700,
                        ),
                        onSelected: (_) => _setFrequency(count),
                      ),
                  ],
                ),
                const SizedBox(height: 22),
                Text(
                  context.tr.translate('weight_reminder_days'),
                  style: TextStyle(
                    color: textColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final weekday in _allWeekdays)
                      FilterChip(
                        label: Text(_weekdayLabel(context, weekday)),
                        selected: _weekdays.contains(weekday),
                        selectedColor: primaryColor.withValues(alpha: 0.16),
                        checkmarkColor: primaryColor,
                        labelStyle: TextStyle(
                          color: _weekdays.contains(weekday)
                              ? primaryColor
                              : textColor,
                          fontWeight: FontWeight.w700,
                        ),
                        onSelected: (_) => _toggleWeekday(weekday),
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(context.tr.translate('cancel')),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => Navigator.of(context).pop(
                          _WeightReminderSettings(
                            time: _time,
                            weekdays: _weekdays,
                          ),
                        ),
                        icon: const Icon(Icons.check_rounded, size: 18),
                        label: Text(context.tr.translate('save')),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTimeButton(
    ThemeData theme,
    Color textColor,
    Color mutedColor,
  ) {
    final isDarkMode = theme.brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _pickTime,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
            color: isDarkMode
                ? Colors.white.withValues(alpha: 0.06)
                : AppTheme.backgroundColor,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              Icon(Icons.schedule_rounded, color: mutedColor, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  context.tr.translate('weight_reminder_time'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                _time,
                style: TextStyle(
                  color: textColor,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickTime() async {
    final selectedTime = await showTimePicker(
      context: context,
      initialTime: _timeOfDayFromString(_time),
    );

    if (selectedTime == null || !mounted) return;

    setState(() => _time = _formatTimeOfDay(selectedTime));
  }

  void _setFrequency(int count) {
    setState(() {
      _weekdays = _resizeWeekdays(_weekdays, count);
    });
  }

  void _toggleWeekday(int weekday) {
    setState(() {
      final nextWeekdays = List<int>.from(_weekdays);
      if (nextWeekdays.contains(weekday)) {
        if (nextWeekdays.length == 1) return;
        nextWeekdays.remove(weekday);
      } else {
        nextWeekdays.add(weekday);
      }
      nextWeekdays.sort();
      _weekdays = nextWeekdays;
    });
  }

  List<int> _resizeWeekdays(List<int> weekdays, int count) {
    final normalized =
        NotificationPreferences.normalizeWeekdays(weekdays)?.toList() ??
            <int>[DateTime.monday];

    if (normalized.length > count) {
      return normalized.take(count).toList();
    }

    final nextWeekdays = List<int>.from(normalized);
    for (final weekday in _allWeekdays) {
      if (nextWeekdays.length >= count) break;
      if (!nextWeekdays.contains(weekday)) {
        nextWeekdays.add(weekday);
      }
    }
    nextWeekdays.sort();
    return nextWeekdays;
  }

  TimeOfDay _timeOfDayFromString(String value) {
    final parts = value.split(':');
    final hour = int.tryParse(parts.first) ?? 12;
    final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    return TimeOfDay(
      hour: hour.clamp(0, 23).toInt(),
      minute: minute.clamp(0, 59).toInt(),
    );
  }

  String _formatTimeOfDay(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  String _weekdayLabel(BuildContext context, int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return context.tr.translate('weekday_mon');
      case DateTime.tuesday:
        return context.tr.translate('weekday_tue');
      case DateTime.wednesday:
        return context.tr.translate('weekday_wed');
      case DateTime.thursday:
        return context.tr.translate('weekday_thu');
      case DateTime.friday:
        return context.tr.translate('weekday_fri');
      case DateTime.saturday:
        return context.tr.translate('weekday_sat');
      case DateTime.sunday:
        return context.tr.translate('weekday_sun');
      default:
        return weekday.toString();
    }
  }

  static const _allWeekdays = [
    DateTime.monday,
    DateTime.tuesday,
    DateTime.wednesday,
    DateTime.thursday,
    DateTime.friday,
    DateTime.saturday,
    DateTime.sunday,
  ];
}
