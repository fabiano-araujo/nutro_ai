import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/meal_types_provider.dart';
import '../theme/app_theme.dart';
import '../i18n/app_localizations_extension.dart';

class ManageMealTypesScreen extends StatefulWidget {
  const ManageMealTypesScreen({Key? key}) : super(key: key);

  @override
  State<ManageMealTypesScreen> createState() => _ManageMealTypesScreenState();
}

class _ManageMealTypesScreenState extends State<ManageMealTypesScreen> {
  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor =
        isDarkMode ? AppTheme.darkBackgroundColor : AppTheme.backgroundColor;
    final textColor =
        isDarkMode ? AppTheme.darkTextColor : AppTheme.textPrimaryColor;
    final borderColor =
        isDarkMode ? AppTheme.darkBorderColor : AppTheme.dividerColor;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          context.tr.translate('manage_meals'),
          style: AppTheme.headingLarge.copyWith(
            color: textColor,
            fontSize: 20,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: textColor),
            tooltip: context.tr.translate('restore_default'),
            onPressed: _showResetDialog,
          ),
        ],
      ),
      body: Consumer<MealTypesProvider>(
        builder: (context, provider, child) {
          if (provider.mealTypes.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.restaurant_menu,
                    size: 64,
                    color: textColor.withValues(alpha: 0.3),
                  ),
                  SizedBox(height: 16),
                  Text(
                    context.tr.translate('no_meals_registered'),
                    style: TextStyle(
                      fontSize: 16,
                      color: textColor.withValues(alpha: 0.5),
                    ),
                  ),
                  SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _showAddDialog,
                    icon: Icon(Icons.add_rounded),
                    label: Text(context.tr.translate('add_meal')),
                    style: FilledButton.styleFrom(
                      padding:
                          EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _showAddDialog,
                    icon: Icon(Icons.add_rounded, size: 20),
                    label: Text(
                      context.tr.translate('add_meal'),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: textColor,
                      side: BorderSide(color: borderColor),
                      padding: EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: ReorderableListView.builder(
                  padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
                  itemCount: provider.mealTypes.length,
                  onReorder: (oldIndex, newIndex) {
                    provider.reorderMealTypes(oldIndex, newIndex);
                  },
                  itemBuilder: (context, index) {
                    final mealType = provider.mealTypes[index];
                    return _MealTypeCard(
                      key: ValueKey(mealType.id),
                      index: index,
                      mealType: mealType,
                      isDarkMode: isDarkMode,
                      onEdit: () => _showEditDialog(mealType),
                      onDelete: () => _showDeleteDialog(mealType),
                    );
                  },
                ),
              ),
              SafeArea(
                top: false,
                minimum: EdgeInsets.fromLTRB(20, 12, 20, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      _saveMealChanges();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      padding: EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 1,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.save_rounded, size: 20),
                        SizedBox(width: 8),
                        Text(
                          context.tr.translate('save_changes'),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showAddDialog() {
    final nameController = TextEditingController();
    String selectedEmoji = '🍽️';
    String selectedTime = MealTypeConfig.defaultReminderTime(
      'custom',
      Provider.of<MealTypesProvider>(context, listen: false).mealTypes.length,
    );

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text(context.tr.translate('add_meal')),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: context.tr.translate('meal_name'),
                    border: OutlineInputBorder(),
                  ),
                  autofocus: true,
                ),
                SizedBox(height: 16),
                _buildTimePickerRow(
                  context: context,
                  time: selectedTime,
                  onChanged: (time) {
                    setState(() {
                      selectedTime = time;
                    });
                  },
                ),
                SizedBox(height: 16),
                Row(
                  children: [
                    Text(context.tr.translate('emoji_label')),
                    SizedBox(width: 12),
                    GestureDetector(
                      onTap: () {
                        _showEmojiPicker(context, (emoji) {
                          setState(() {
                            selectedEmoji = emoji;
                          });
                        });
                      },
                      child: Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          selectedEmoji,
                          style: TextStyle(fontSize: 32),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(context.tr.translate('cancel')),
              ),
              ElevatedButton(
                onPressed: () {
                  final name = nameController.text.trim();
                  if (name.isNotEmpty) {
                    Provider.of<MealTypesProvider>(context, listen: false)
                        .addMealType(
                      name,
                      selectedEmoji,
                      reminderTime: selectedTime,
                    );
                    Navigator.pop(context);
                  }
                },
                child: Text(context.tr.translate('add')),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showEditDialog(MealTypeConfig mealType) {
    final nameController = TextEditingController(text: mealType.name);
    String selectedEmoji = mealType.emoji;
    String selectedTime = mealType.reminderTime;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text(context.tr.translate('edit_meal')),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: context.tr.translate('meal_name'),
                    border: OutlineInputBorder(),
                  ),
                  autofocus: true,
                ),
                SizedBox(height: 16),
                _buildTimePickerRow(
                  context: context,
                  time: selectedTime,
                  onChanged: (time) {
                    setState(() {
                      selectedTime = time;
                    });
                  },
                ),
                SizedBox(height: 16),
                Row(
                  children: [
                    Text(context.tr.translate('emoji_label')),
                    SizedBox(width: 12),
                    GestureDetector(
                      onTap: () {
                        _showEmojiPicker(context, (emoji) {
                          setState(() {
                            selectedEmoji = emoji;
                          });
                        });
                      },
                      child: Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          selectedEmoji,
                          style: TextStyle(fontSize: 32),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(context.tr.translate('cancel')),
              ),
              ElevatedButton(
                onPressed: () {
                  final name = nameController.text.trim();
                  if (name.isNotEmpty) {
                    Provider.of<MealTypesProvider>(context, listen: false)
                        .updateMealType(
                      mealType.id,
                      name: name,
                      emoji: selectedEmoji,
                      reminderTime: selectedTime,
                    );
                    Navigator.pop(context);
                  }
                },
                child: Text(context.tr.translate('save')),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTimePickerRow({
    required BuildContext context,
    required String time,
    required ValueChanged<String> onChanged,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            context.tr.translate('meal_time'),
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        OutlinedButton.icon(
          onPressed: () async {
            final selectedTime = await showTimePicker(
              context: context,
              initialTime: _timeOfDayFromString(time),
            );

            if (selectedTime != null) {
              onChanged(_formatTimeOfDay(selectedTime));
            }
          },
          icon: Icon(Icons.schedule_rounded, size: 18),
          label: Text(time),
        ),
      ],
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

  void _showDeleteDialog(MealTypeConfig mealType) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.tr.translate('delete_meal')),
        content: Text(
          context.tr
              .translate('delete_meal_confirmation')
              .replaceAll('{mealName}', mealType.name),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(context.tr.translate('cancel')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
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
    // The changes are automatically saved in the provider via SharedPreferences
    // Show a confirmation snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 12),
            Text(context.tr.translate('changes_saved_successfully')),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        margin: EdgeInsets.all(16),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _showResetDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.tr.translate('restore_default')),
        content: Text(
          context.tr.translate('restore_default_confirmation'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(context.tr.translate('cancel')),
          ),
          ElevatedButton(
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

  void _showEmojiPicker(
      BuildContext context, Function(String) onEmojiSelected) {
    final emojis = [
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
      '🍿',
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
      '🥗',
      '🥙',
    ];

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.tr.translate('select_emoji')),
        content: Container(
          width: double.maxFinite,
          height: 300,
          child: GridView.builder(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 6,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
            ),
            itemCount: emojis.length,
            itemBuilder: (context, index) {
              return GestureDetector(
                onTap: () {
                  onEmojiSelected(emojis[index]);
                  Navigator.pop(dialogContext);
                },
                child: Container(
                  decoration: BoxDecoration(
                    border:
                        Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      emojis[index],
                      style: TextStyle(fontSize: 28),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(context.tr.translate('cancel')),
          ),
        ],
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
    Key? key,
    required this.index,
    required this.mealType,
    required this.isDarkMode,
    required this.onEdit,
    required this.onDelete,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final cardColor = isDarkMode ? AppTheme.darkCardColor : AppTheme.cardColor;
    final textColor =
        isDarkMode ? AppTheme.darkTextColor : AppTheme.textPrimaryColor;
    final mutedColor = textColor.withValues(alpha: 0.62);
    final actionBackground = isDarkMode
        ? Colors.white.withValues(alpha: 0.08)
        : AppTheme.surfaceColor;
    final deleteColor = isDarkMode ? Color(0xFFFFB4AB) : AppTheme.errorColor;

    return Card(
      margin: EdgeInsets.only(bottom: 10),
      elevation: isDarkMode ? 0 : 1,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isDarkMode
              ? Colors.white.withValues(alpha: 0.04)
              : AppTheme.dividerColor.withValues(alpha: 0.55),
        ),
      ),
      color: cardColor,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            // Drag handle
            SizedBox(
              width: 28,
              height: 52,
              child: Center(
                child: ReorderableDragStartListener(
                  index: index,
                  child: Icon(
                    Icons.drag_handle_rounded,
                    color: textColor.withValues(alpha: 0.42),
                  ),
                ),
              ),
            ),
            SizedBox(width: 10),

            // Emoji
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: isDarkMode
                    ? Colors.white.withValues(alpha: 0.06)
                    : AppTheme.surfaceColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  mealType.emoji,
                  style: TextStyle(fontSize: 24),
                ),
              ),
            ),
            SizedBox(width: 14),

            // Name and reminder time
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    mealType.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                  ),
                  SizedBox(height: 3),
                  Row(
                    children: [
                      Icon(
                        Icons.schedule_rounded,
                        size: 14,
                        color: mutedColor,
                      ),
                      SizedBox(width: 4),
                      Text(
                        mealType.reminderTime,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: mutedColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(width: 8),

            // Edit button
            IconButton(
              style: IconButton.styleFrom(
                backgroundColor: actionBackground,
                foregroundColor: textColor.withValues(alpha: 0.88),
                fixedSize: Size(40, 40),
                minimumSize: Size(40, 40),
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: Icon(Icons.edit_rounded, size: 20),
              onPressed: onEdit,
            ),
            SizedBox(width: 4),

            // Delete button
            IconButton(
              style: IconButton.styleFrom(
                backgroundColor: deleteColor.withValues(alpha: 0.12),
                foregroundColor: deleteColor,
                fixedSize: Size(40, 40),
                minimumSize: Size(40, 40),
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: Icon(Icons.delete_rounded, size: 20),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}
