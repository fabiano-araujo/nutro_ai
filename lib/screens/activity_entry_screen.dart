import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../i18n/app_localizations_extension.dart';
import '../providers/activity_tracking_provider.dart';
import '../providers/nutrition_goals_provider.dart';
import '../theme/app_theme.dart';

class ActivityEntryScreen extends StatefulWidget {
  final String activityId;
  final String activityName;
  final double met;
  final DateTime selectedDate;

  const ActivityEntryScreen({
    super.key,
    required this.activityId,
    required this.activityName,
    required this.met,
    required this.selectedDate,
  });

  @override
  State<ActivityEntryScreen> createState() => _ActivityEntryScreenState();
}

class _ActivityEntryScreenState extends State<ActivityEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _durationController;
  late final TextEditingController _caloriesController;
  bool _caloriesWereEdited = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _durationController = TextEditingController(text: '30');
    _caloriesController = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _updateEstimatedCalories();
    });
  }

  @override
  void dispose() {
    _durationController.dispose();
    _caloriesController.dispose();
    super.dispose();
  }

  void _updateEstimatedCalories() {
    if (_caloriesWereEdited) return;
    final duration = int.tryParse(_durationController.text) ?? 0;
    final weight = context.read<NutritionGoalsProvider>().weight;
    final estimated = (widget.met * 3.5 * weight / 200 * duration).round();
    _caloriesController.text = estimated.clamp(0, 100000).toString();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _isSaving) return;
    setState(() => _isSaving = true);

    await context.read<ActivityTrackingProvider>().addManualActivity(
          activityId: widget.activityId,
          activityName: widget.activityName,
          date: widget.selectedDate,
          durationMinutes: int.parse(_durationController.text),
          caloriesBurned: int.parse(_caloriesController.text),
        );

    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final backgroundColor =
        isDarkMode ? AppTheme.darkBackgroundColor : AppTheme.backgroundColor;
    final textColor = isDarkMode ? Colors.white : AppTheme.textPrimaryColor;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: textColor),
        title: Text(
          widget.activityName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleLarge?.copyWith(
            color: textColor,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: isDarkMode ? AppTheme.darkCardColor : Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: isDarkMode
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.06),
                  ),
                ),
                child: Column(
                  children: [
                    _buildDateRow(theme, textColor),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _durationController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      textInputAction: TextInputAction.next,
                      onChanged: (_) => _updateEstimatedCalories(),
                      decoration: InputDecoration(
                        labelText: context.tr.translate('activity_duration'),
                        suffixText:
                            context.tr.translate('tracking_metric_minutes'),
                        prefixIcon: const Icon(Icons.timer_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      validator: (value) {
                        final duration = int.tryParse(value ?? '');
                        if (duration == null ||
                            duration < 1 ||
                            duration > 1440) {
                          return context.tr
                              .translate('activity_invalid_duration');
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _caloriesController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: (_) => _caloriesWereEdited = true,
                      decoration: InputDecoration(
                        labelText: context.tr.translate('activity_calories'),
                        suffixText:
                            context.tr.translate('tracking_metric_calories'),
                        prefixIcon:
                            const Icon(Icons.local_fire_department_outlined),
                        helperText:
                            context.tr.translate('activity_calories_estimated'),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      validator: (value) {
                        final calories = int.tryParse(value ?? '');
                        if (calories == null ||
                            calories < 0 ||
                            calories > 100000) {
                          return context.tr
                              .translate('activity_invalid_calories');
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _isSaving ? null : _save,
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_rounded),
                label: Text(context.tr.translate('activity_save')),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDateRow(ThemeData theme, Color textColor) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            Icons.calendar_today_rounded,
            color: theme.colorScheme.primary,
            size: 21,
          ),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.tr.translate('date'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: textColor.withValues(alpha: 0.65),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                MaterialLocalizations.of(context)
                    .formatMediumDate(widget.selectedDate),
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: textColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
