import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../i18n/app_localizations_extension.dart';
import '../providers/meal_types_provider.dart';
import '../theme/app_theme.dart';
import '../utils/meal_type_localization.dart';
import '../widgets/meal_type_icon.dart';

const double _contentMaxWidth = 560;

String _formatStoredTimeForDisplay(BuildContext context, String value) {
  final parts = value.split(':');
  final hour = int.tryParse(parts.first) ?? 12;
  final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
  final time = TimeOfDay(
    hour: hour.clamp(0, 23).toInt(),
    minute: minute.clamp(0, 59).toInt(),
  );

  return MaterialLocalizations.of(context).formatTimeOfDay(
    time,
    alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
  );
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

class ManageMealTypesScreen extends StatefulWidget {
  const ManageMealTypesScreen({super.key});

  @override
  State<ManageMealTypesScreen> createState() => _ManageMealTypesScreenState();
}

class _ManageMealTypesScreenState extends State<ManageMealTypesScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final backgroundColor =
        isDarkMode ? AppTheme.darkBackgroundColor : AppTheme.backgroundColor;
    final textColor =
        isDarkMode ? AppTheme.darkTextColor : AppTheme.textPrimaryColor;
    final mutedColor =
        isDarkMode ? AppTheme.darkMutedTextColor : AppTheme.textSecondaryColor;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Consumer<MealTypesProvider>(
          builder: (context, provider, child) {
            return Column(
              children: [
                _buildHeader(textColor),
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints:
                          const BoxConstraints(maxWidth: _contentMaxWidth),
                      child: provider.mealTypes.isEmpty
                          ? _EmptyMealsState(
                              mutedColor: mutedColor,
                              onAdd: _showAddSheet,
                            )
                          : Column(
                              children: [
                                Padding(
                                  padding:
                                      const EdgeInsets.fromLTRB(20, 4, 20, 12),
                                  child: _AddMealButton(onTap: _showAddSheet),
                                ),
                                Padding(
                                  padding:
                                      const EdgeInsets.fromLTRB(24, 0, 24, 8),
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      context.tr
                                          .translate('reorder_meals_hint'),
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: mutedColor,
                                        height: 1.3,
                                      ),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: ReorderableListView.builder(
                                    buildDefaultDragHandles: false,
                                    padding: const EdgeInsets.fromLTRB(
                                      20,
                                      0,
                                      20,
                                      8,
                                    ),
                                    itemCount: provider.mealTypes.length,
                                    onReorder: provider.reorderMealTypes,
                                    proxyDecorator: (child, index, animation) {
                                      return AnimatedBuilder(
                                        animation: animation,
                                        builder: (context, child) {
                                          final t = Curves.easeOutCubic
                                              .transform(animation.value);
                                          return Transform.scale(
                                            scale: lerpDouble(1, 1.03, t)!,
                                            child: child,
                                          );
                                        },
                                        child: child,
                                      );
                                    },
                                    itemBuilder: (context, index) {
                                      final mealType =
                                          provider.mealTypes[index];
                                      return Padding(
                                        key: ValueKey(mealType.id),
                                        padding:
                                            const EdgeInsets.only(bottom: 12),
                                        child: _MealTypeCard(
                                          index: index,
                                          mealType: mealType,
                                          isDarkMode: isDarkMode,
                                          onEdit: () =>
                                              _showEditSheet(mealType),
                                          onDelete: () =>
                                              _showDeleteDialog(mealType),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
                if (provider.mealTypes.isNotEmpty)
                  Center(
                    child: ConstrainedBox(
                      constraints:
                          const BoxConstraints(maxWidth: _contentMaxWidth),
                      child: SafeArea(
                        top: false,
                        minimum: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                        child: SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: FilledButton.icon(
                            onPressed: _saveMealChanges,
                            icon: const Icon(Icons.check_rounded, size: 20),
                            label: Text(
                              context.tr.translate('save_changes'),
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            style: FilledButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
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
              context.tr.translate('manage_meals'),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                color: textColor,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                height: 1.15,
              ),
            ),
          ),
          SizedBox(
            width: sideWidth,
            child: Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                icon: Icon(Icons.restart_alt_rounded, color: textColor),
                tooltip: context.tr.translate('restore_default'),
                onPressed: _showResetDialog,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddSheet() {
    return _MealTypeEditorSheet.show(
      context: context,
      title: context.tr.translate('add_meal'),
      confirmLabel: context.tr.translate('add'),
      initialName: '',
      initialEmoji: '🍽️',
      initialTime: MealTypeConfig.defaultReminderTime(
        'custom',
        Provider.of<MealTypesProvider>(context, listen: false).mealTypes.length,
      ),
      onConfirm: (name, emoji, time) {
        Provider.of<MealTypesProvider>(context, listen: false).addMealType(
          name,
          emoji,
          reminderTime: time,
        );
      },
    );
  }

  Future<void> _showEditSheet(MealTypeConfig mealType) {
    return _MealTypeEditorSheet.show(
      context: context,
      title: context.tr.translate('edit_meal'),
      confirmLabel: context.tr.translate('save'),
      initialName: localizedMealTypeName(context.tr, mealType),
      initialEmoji: mealType.emoji,
      initialTime: mealType.reminderTime,
      onConfirm: (name, emoji, time) {
        Provider.of<MealTypesProvider>(context, listen: false).updateMealType(
          mealType.id,
          name: name,
          emoji: emoji,
          reminderTime: time,
        );
      },
    );
  }

  void _showDeleteDialog(MealTypeConfig mealType) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(context.tr.translate('delete_meal')),
        content: Text(
          context.tr.translate('delete_meal_confirmation').replaceAll(
                '{mealName}',
                localizedMealTypeName(context.tr, mealType),
              ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(context.tr.translate('cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor:
                  isDarkMode ? const Color(0xFFFFB4AB) : AppTheme.errorColor,
              foregroundColor: isDarkMode ? Colors.black : Colors.white,
            ),
            onPressed: () {
              Provider.of<MealTypesProvider>(context, listen: false)
                  .deleteMealType(mealType.id);
              Navigator.pop(dialogContext);
            },
            child: Text(context.tr.translate('delete')),
          ),
        ],
      ),
    );
  }

  void _saveMealChanges() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(context.tr.translate('changes_saved_successfully')),
            ),
          ],
        ),
        backgroundColor: AppTheme.primaryColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showResetDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(context.tr.translate('restore_default')),
        content: Text(
          context.tr.translate('restore_default_confirmation'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(context.tr.translate('cancel')),
          ),
          FilledButton(
            onPressed: () {
              Provider.of<MealTypesProvider>(context, listen: false)
                  .resetToDefaults();
              Navigator.pop(dialogContext);
            },
            child: Text(context.tr.translate('restore')),
          ),
        ],
      ),
    );
  }
}

class _EmptyMealsState extends StatelessWidget {
  final Color mutedColor;
  final VoidCallback onAdd;

  const _EmptyMealsState({
    required this.mutedColor,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.restaurant_menu_rounded,
              size: 42,
              color: primary,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            context.tr.translate('no_meals_registered'),
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: mutedColor,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded),
            label: Text(context.tr.translate('add_meal')),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddMealButton extends StatelessWidget {
  final VoidCallback onTap;

  const _AddMealButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;
    final textColor =
        isDarkMode ? AppTheme.darkTextColor : AppTheme.textPrimaryColor;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          decoration: BoxDecoration(
            color: primary.withValues(alpha: isDarkMode ? 0.16 : 0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: primary.withValues(alpha: isDarkMode ? 0.38 : 0.28),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 16, 14),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: primary,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(
                    Icons.add_rounded,
                    color: theme.colorScheme.onPrimary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    context.tr.translate('add_meal'),
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: primary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MealTypeCard extends StatelessWidget {
  final int index;
  final MealTypeConfig mealType;
  final bool isDarkMode;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _MealTypeCard({
    required this.index,
    required this.mealType,
    required this.isDarkMode,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final textColor =
        isDarkMode ? AppTheme.darkTextColor : AppTheme.textPrimaryColor;
    final deleteColor =
        isDarkMode ? const Color(0xFFFFB4AB) : AppTheme.errorColor;

    return Container(
      decoration: AppTheme.profileCardDecoration(isDarkMode, radius: 20),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 10, 10, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ReorderableDragStartListener(
                index: index,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                  child: Icon(
                    Icons.drag_indicator_rounded,
                    color: textColor.withValues(alpha: 0.38),
                    size: 22,
                  ),
                ),
              ),
              MealTypeIcon(mealTypeId: mealType.id),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InkWell(
                      onTap: onEdit,
                      borderRadius: BorderRadius.circular(10),
                      child: Text(
                        localizedMealTypeName(context.tr, mealType),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.1,
                          height: 1.25,
                          color: textColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: primary.withValues(
                              alpha: isDarkMode ? 0.18 : 0.10,
                            ),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.schedule_rounded,
                                size: 14,
                                color: primary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _formatStoredTimeForDisplay(
                                  context,
                                  mealType.reminderTime,
                                ),
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  height: 1,
                                  color: primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        _CircleIconButton(
                          icon: Icons.edit_rounded,
                          color: primary,
                          backgroundColor: primary.withValues(
                            alpha: isDarkMode ? 0.18 : 0.10,
                          ),
                          tooltip: context.tr.translate('edit'),
                          onTap: onEdit,
                        ),
                        const SizedBox(width: 6),
                        _CircleIconButton(
                          icon: Icons.delete_outline_rounded,
                          color: deleteColor,
                          backgroundColor: deleteColor.withValues(alpha: 0.14),
                          tooltip: context.tr.translate('delete'),
                          onTap: onDelete,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color backgroundColor;
  final String tooltip;
  final VoidCallback onTap;

  const _CircleIconButton({
    required this.icon,
    required this.color,
    required this.backgroundColor,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: backgroundColor,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 40,
            height: 40,
            child: Icon(icon, size: 18, color: color),
          ),
        ),
      ),
    );
  }
}

class _MealTypeEditorSheet extends StatefulWidget {
  final String title;
  final String confirmLabel;
  final String initialName;
  final String initialEmoji;
  final String initialTime;
  final void Function(String name, String emoji, String time) onConfirm;

  const _MealTypeEditorSheet({
    required this.title,
    required this.confirmLabel,
    required this.initialName,
    required this.initialEmoji,
    required this.initialTime,
    required this.onConfirm,
  });

  static Future<void> show({
    required BuildContext context,
    required String title,
    required String confirmLabel,
    required String initialName,
    required String initialEmoji,
    required String initialTime,
    required void Function(String name, String emoji, String time) onConfirm,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _MealTypeEditorSheet(
        title: title,
        confirmLabel: confirmLabel,
        initialName: initialName,
        initialEmoji: initialEmoji,
        initialTime: initialTime,
        onConfirm: onConfirm,
      ),
    );
  }

  @override
  State<_MealTypeEditorSheet> createState() => _MealTypeEditorSheetState();
}

class _MealTypeEditorSheetState extends State<_MealTypeEditorSheet> {
  late final TextEditingController _nameController;
  late String _emoji;
  late String _time;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _emoji = widget.initialEmoji;
    _time = widget.initialTime;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final selectedTime = await showTimePicker(
      context: context,
      initialTime: _timeOfDayFromString(_time),
    );
    if (selectedTime != null && mounted) {
      setState(() => _time = _formatTimeOfDay(selectedTime));
    }
  }

  Future<void> _pickEmoji() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => const _EmojiPickerSheet(),
    );
    if (selected != null && mounted) {
      setState(() => _emoji = selected);
    }
  }

  void _submit() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    widget.onConfirm(name, _emoji, _time);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final backgroundColor = isDarkMode ? AppTheme.darkCardColor : Colors.white;
    final textColor =
        isDarkMode ? AppTheme.darkTextColor : AppTheme.textPrimaryColor;
    final mutedColor =
        isDarkMode ? AppTheme.darkMutedTextColor : AppTheme.textSecondaryColor;
    final primary = theme.colorScheme.primary;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _contentMaxWidth),
          child: Container(
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: mutedColor.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      widget.title,
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 20),
                    GestureDetector(
                      onTap: _pickEmoji,
                      child: Column(
                        children: [
                          Container(
                            width: 76,
                            height: 76,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  primary.withValues(
                                    alpha: isDarkMode ? 0.30 : 0.20,
                                  ),
                                  primary.withValues(
                                    alpha: isDarkMode ? 0.12 : 0.07,
                                  ),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(
                                color: primary.withValues(
                                  alpha: isDarkMode ? 0.28 : 0.16,
                                ),
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              _emoji,
                              style: const TextStyle(fontSize: 36),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            context.tr.translate('select_emoji'),
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _nameController,
                      autofocus: widget.initialName.isEmpty,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        labelText: context.tr.translate('meal_name'),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: isDarkMode
                                ? AppTheme.darkBorderColor
                                : AppTheme.dividerColor,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: primary, width: 2),
                        ),
                      ),
                      onSubmitted: (_) => _submit(),
                    ),
                    const SizedBox(height: 12),
                    Material(
                      color: isDarkMode
                          ? Colors.white.withValues(alpha: 0.05)
                          : AppTheme.surfaceColor,
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        onTap: _pickTime,
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: primary.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  Icons.schedule_rounded,
                                  color: primary,
                                  size: 21,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      context.tr.translate('meal_time'),
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: mutedColor,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _formatStoredTimeForDisplay(
                                        context,
                                        _time,
                                      ),
                                      style: GoogleFonts.inter(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: textColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.chevron_right_rounded,
                                color: mutedColor,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton(
                        onPressed: _submit,
                        style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          widget.confirmLabel,
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmojiPickerSheet extends StatelessWidget {
  const _EmojiPickerSheet();

  static const List<String> _emojis = [
    '🍳',
    '🥐',
    '🥞',
    '🧇',
    '🥓',
    '🥖',
    '🥨',
    '🍞',
    '🥯',
    '🧀',
    '🥗',
    '🥙',
    '🌮',
    '🌯',
    '🥪',
    '🍕',
    '🍔',
    '🍟',
    '🌭',
    '🍿',
    '🥘',
    '🍝',
    '🍜',
    '🍲',
    '🍱',
    '🍛',
    '🍙',
    '🍚',
    '🍘',
    '🥟',
    '🍢',
    '🍣',
    '🍤',
    '🥠',
    '🍡',
    '🥧',
    '🍰',
    '🎂',
    '🍮',
    '🍭',
    '🍬',
    '🍫',
    '🍩',
    '🍪',
    '🌰',
    '🥜',
    '🍯',
    '🥛',
    '🍼',
    '☕',
    '🍵',
    '🧃',
    '🥤',
    '🍶',
    '🍺',
    '🍻',
    '🥂',
    '🍷',
    '🥃',
    '🍸',
    '🍹',
    '🍾',
    '🧊',
    '🥄',
    '🍴',
    '🥢',
    '🍽️',
    '🍎',
    '🥑',
  ];

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDarkMode ? AppTheme.darkCardColor : Colors.white;
    final textColor =
        isDarkMode ? AppTheme.darkTextColor : AppTheme.textPrimaryColor;
    final mutedColor =
        isDarkMode ? AppTheme.darkMutedTextColor : AppTheme.textSecondaryColor;

    return Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _contentMaxWidth),
        child: Container(
          height: 420,
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: mutedColor.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Text(
                  context.tr.translate('select_emoji'),
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
              ),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 6,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                  ),
                  itemCount: _emojis.length,
                  itemBuilder: (context, index) {
                    final emoji = _emojis[index];
                    return Material(
                      color: isDarkMode
                          ? Colors.white.withValues(alpha: 0.05)
                          : AppTheme.surfaceColor,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        onTap: () => Navigator.pop(context, emoji),
                        borderRadius: BorderRadius.circular(12),
                        child: Center(
                          child: Text(
                            emoji,
                            style: const TextStyle(fontSize: 28),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
