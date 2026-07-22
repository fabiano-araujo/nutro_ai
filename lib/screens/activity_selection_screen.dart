import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../i18n/app_localizations_extension.dart';
import '../models/activity_catalog.dart';
import '../models/manual_activity.dart';
import '../providers/activity_tracking_provider.dart';
import '../theme/app_theme.dart';
import 'activity_entry_screen.dart';

class ActivitySelectionScreen extends StatefulWidget {
  final DateTime selectedDate;

  const ActivitySelectionScreen({
    super.key,
    required this.selectedDate,
  });

  @override
  State<ActivitySelectionScreen> createState() =>
      _ActivitySelectionScreenState();
}

class _ActivitySelectionScreenState extends State<ActivitySelectionScreen> {
  final TextEditingController _searchController = TextEditingController();
  int _selectedTab = 1;
  String _query = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(
        context.read<ActivityTrackingProvider>().loadManualActivities(),
      );
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openActivity(_ActivityOption activity) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => ActivityEntryScreen(
          activityId: activity.id,
          activityName: activity.name,
          met: activity.met,
          selectedDate: widget.selectedDate,
        ),
      ),
    );
    if (!mounted || saved != true) return;
    Navigator.of(context).pop(true);
  }

  Future<void> _createCustomActivity() async {
    final draft = await showDialog<_CustomActivityDraft>(
      context: context,
      builder: (context) => const _CreateCustomActivityDialog(),
    );
    if (!mounted || draft == null) return;
    final definition =
        await context.read<ActivityTrackingProvider>().addCustomActivity(
              name: draft.name,
              met: draft.met,
            );
    if (!mounted) return;
    setState(() {
      _selectedTab = 2;
      _query = '';
      _searchController.clear();
    });
    await _openActivity(
      _ActivityOption(
        id: definition.id,
        name: definition.name,
        met: definition.met,
        isCustom: true,
      ),
    );
  }

  Future<void> _deleteCustomActivity(CustomActivityDefinition activity) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr.translate('activity_delete_custom_title')),
        content: Text(
          context.tr
              .translate('activity_delete_custom_message')
              .replaceAll('{name}', activity.name),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.tr.translate('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.tr.translate('delete')),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    await context
        .read<ActivityTrackingProvider>()
        .removeCustomActivity(activity.id);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final headerColor =
        isDarkMode ? AppTheme.darkBackgroundColor : const Color(0xFFDDF3FC);
    final surfaceColor = isDarkMode ? AppTheme.darkCardColor : Colors.white;
    final textColor = isDarkMode ? Colors.white : AppTheme.textPrimaryColor;

    return Scaffold(
      backgroundColor: headerColor,
      appBar: AppBar(
        backgroundColor: headerColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close_rounded, size: 30),
          color: textColor,
          tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
        ),
        title: Text(
          context.tr.translate('activity_screen_title'),
          style: theme.textTheme.titleLarge?.copyWith(
            color: textColor,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
                child: _buildTabs(theme, isDarkMode, textColor),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 14),
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) => setState(() => _query = value.trim()),
                  decoration: InputDecoration(
                    hintText: context.tr.translate('activity_search_hint'),
                    prefixIcon: const Icon(Icons.search_rounded, size: 29),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _query = '');
                            },
                            icon: const Icon(Icons.close_rounded),
                          ),
                    filled: true,
                    fillColor: isDarkMode
                        ? Colors.white.withValues(alpha: 0.05)
                        : const Color(0xFFF8F9FC),
                    contentPadding: const EdgeInsets.symmetric(vertical: 18),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(28),
                      borderSide: BorderSide(
                        color: textColor.withValues(alpha: 0.42),
                        width: 1.5,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(28),
                      borderSide: BorderSide(
                        color: theme.colorScheme.primary,
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Consumer<ActivityTrackingProvider>(
                  builder: (context, provider, child) {
                    final options = _optionsFor(provider);
                    if (options.isEmpty) {
                      return _buildEmptyState(theme, textColor);
                    }
                    return ListView.separated(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.fromLTRB(38, 0, 38, 28),
                      itemCount: options.length,
                      separatorBuilder: (context, index) => Divider(
                        height: 1,
                        color: textColor.withValues(alpha: 0.1),
                      ),
                      itemBuilder: (context, index) {
                        final option = options[index];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          minTileHeight: 70,
                          title: Text(
                            option.name,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: textColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          trailing: option.customDefinition == null
                              ? null
                              : IconButton(
                                  onPressed: () => _deleteCustomActivity(
                                    option.customDefinition!,
                                  ),
                                  icon: const Icon(Icons.more_vert_rounded),
                                  tooltip: context.tr.translate('delete'),
                                ),
                          onTap: () => _openActivity(option),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: _selectedTab == 2
          ? FloatingActionButton.extended(
              onPressed: _createCustomActivity,
              icon: const Icon(Icons.add_rounded),
              label: Text(context.tr.translate('activity_create_custom')),
            )
          : null,
    );
  }

  Widget _buildTabs(ThemeData theme, bool isDarkMode, Color textColor) {
    final tabs = [
      (Icons.access_time_rounded, 'activity_tab_recent'),
      (Icons.directions_run_rounded, 'activity_tab_all'),
      (Icons.bookmark_border_rounded, 'activity_tab_mine'),
    ];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(tabs.length, (index) {
        final selected = _selectedTab == index;
        return Expanded(
          child: InkWell(
            onTap: () => setState(() => _selectedTab = index),
            borderRadius: BorderRadius.circular(24),
            child: Column(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  height: 58,
                  margin: const EdgeInsets.symmetric(horizontal: 5),
                  decoration: BoxDecoration(
                    color: selected
                        ? (isDarkMode
                            ? AppTheme.primaryColorDarkMode.withValues(
                                alpha: 0.2,
                              )
                            : const Color(0xFFE3F6FD))
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: selected
                          ? Colors.transparent
                          : textColor.withValues(alpha: 0.14),
                    ),
                  ),
                  child: Icon(
                    tabs[index].$1,
                    size: 28,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  context.tr.translate(tabs[index].$2),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: textColor,
                    height: 1.15,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  List<_ActivityOption> _optionsFor(ActivityTrackingProvider provider) {
    final options = switch (_selectedTab) {
      0 => provider.recentManualActivities
          .map((entry) => _optionForRecent(entry, provider))
          .toList(),
      1 => activityCatalog
          .map(
            (activity) => _ActivityOption(
              id: activity.id,
              name: context.tr.translate(activity.nameKey),
              met: activity.met,
            ),
          )
          .toList(),
      _ => provider.customActivities
          .map(
            (activity) => _ActivityOption(
              id: activity.id,
              name: activity.name,
              met: activity.met,
              isCustom: true,
              customDefinition: activity,
            ),
          )
          .toList(),
    };
    options.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
    final normalizedQuery = _query.toLowerCase();
    if (normalizedQuery.isEmpty) return options;
    return options
        .where(
            (activity) => activity.name.toLowerCase().contains(normalizedQuery))
        .toList(growable: false);
  }

  _ActivityOption _optionForRecent(
    ManualActivityEntry entry,
    ActivityTrackingProvider provider,
  ) {
    for (final catalogItem in activityCatalog) {
      if (catalogItem.id == entry.activityId) {
        return _ActivityOption(
          id: catalogItem.id,
          name: context.tr.translate(catalogItem.nameKey),
          met: catalogItem.met,
        );
      }
    }
    for (final customActivity in provider.customActivities) {
      if (customActivity.id == entry.activityId) {
        return _ActivityOption(
          id: customActivity.id,
          name: customActivity.name,
          met: customActivity.met,
          isCustom: true,
          customDefinition: customActivity,
        );
      }
    }
    return _ActivityOption(
      id: entry.activityId,
      name: entry.activityName,
      met: 6,
      isCustom: true,
    );
  }

  Widget _buildEmptyState(ThemeData theme, Color textColor) {
    final key = _query.isNotEmpty
        ? 'activity_no_results'
        : _selectedTab == 0
            ? 'activity_no_recent'
            : 'activity_no_custom';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _query.isNotEmpty
                  ? Icons.search_off_rounded
                  : Icons.directions_run_rounded,
              size: 54,
              color: textColor.withValues(alpha: 0.38),
            ),
            const SizedBox(height: 14),
            Text(
              context.tr.translate(key),
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                color: textColor.withValues(alpha: 0.7),
              ),
            ),
            if (_selectedTab == 2 && _query.isEmpty) ...[
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: _createCustomActivity,
                icon: const Icon(Icons.add_rounded),
                label: Text(
                  context.tr.translate('activity_create_custom'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ActivityOption {
  final String id;
  final String name;
  final double met;
  final bool isCustom;
  final CustomActivityDefinition? customDefinition;

  const _ActivityOption({
    required this.id,
    required this.name,
    required this.met,
    this.isCustom = false,
    this.customDefinition,
  });
}

class _CustomActivityDraft {
  final String name;
  final double met;

  const _CustomActivityDraft(this.name, this.met);
}

class _CreateCustomActivityDialog extends StatefulWidget {
  const _CreateCustomActivityDialog();

  @override
  State<_CreateCustomActivityDialog> createState() =>
      _CreateCustomActivityDialogState();
}

class _CreateCustomActivityDialogState
    extends State<_CreateCustomActivityDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  double _met = 6;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.tr.translate('activity_create_custom')),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameController,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: context.tr.translate('activity_custom_name'),
              ),
              validator: (value) {
                if ((value ?? '').trim().length < 2) {
                  return context.tr.translate('activity_custom_name_invalid');
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<double>(
              initialValue: _met,
              decoration: InputDecoration(
                labelText: context.tr.translate('activity_intensity'),
              ),
              items: [
                DropdownMenuItem(
                  value: 3,
                  child: Text(
                    context.tr.translate('activity_intensity_light'),
                  ),
                ),
                DropdownMenuItem(
                  value: 6,
                  child: Text(
                    context.tr.translate('activity_intensity_moderate'),
                  ),
                ),
                DropdownMenuItem(
                  value: 9,
                  child: Text(
                    context.tr.translate('activity_intensity_intense'),
                  ),
                ),
              ],
              onChanged: (value) => _met = value ?? 6,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.tr.translate('cancel')),
        ),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            Navigator.of(context).pop(
              _CustomActivityDraft(_nameController.text.trim(), _met),
            );
          },
          child: Text(context.tr.translate('save')),
        ),
      ],
    );
  }
}
