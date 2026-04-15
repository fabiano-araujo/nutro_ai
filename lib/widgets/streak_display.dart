import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/streak_provider.dart';
import '../theme/app_theme.dart';
import '../i18n/app_localizations_extension.dart';

/// Widget compacto para exibir os 3 streaks
class StreakDisplay extends StatelessWidget {
  final bool showLabels;
  final bool compact;

  const StreakDisplay({
    Key? key,
    this.showLabels = true,
    this.compact = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<StreakProvider>(
      builder: (context, streakProvider, child) {
        if (streakProvider.isLoading && !streakProvider.hasStreak) {
          return const Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }

        final isDarkMode = Theme.of(context).brightness == Brightness.dark;

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _StreakItem(
              emoji: '🔥',
              count: streakProvider.registrationStreak,
              label: context.tr.translate('streak_registration'),
              color: Colors.orange,
              showLabel: showLabels,
              compact: compact,
              isDarkMode: isDarkMode,
              isInDanger: streakProvider.isStreakInDanger,
            ),
            SizedBox(width: compact ? 12 : 20),
            _StreakItem(
              emoji: '💪',
              count: streakProvider.proteinStreak,
              label: context.tr.translate('streak_protein'),
              color: Colors.green,
              showLabel: showLabels,
              compact: compact,
              isDarkMode: isDarkMode,
            ),
            SizedBox(width: compact ? 12 : 20),
            _StreakItem(
              emoji: '🎯',
              count: streakProvider.goalStreak,
              label: context.tr.translate('streak_goal'),
              color: Colors.blue,
              showLabel: showLabels,
              compact: compact,
              isDarkMode: isDarkMode,
            ),
          ],
        );
      },
    );
  }
}

class _StreakItem extends StatelessWidget {
  final String emoji;
  final int count;
  final String label;
  final Color color;
  final bool showLabel;
  final bool compact;
  final bool isDarkMode;
  final bool isInDanger;

  const _StreakItem({
    required this.emoji,
    required this.count,
    required this.label,
    required this.color,
    required this.showLabel,
    required this.compact,
    required this.isDarkMode,
    this.isInDanger = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: EdgeInsets.all(compact ? 8 : 12),
          decoration: BoxDecoration(
            color: isInDanger
                ? Colors.red.withValues(alpha: 0.15)
                : color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(compact ? 10 : 14),
            border: isInDanger
                ? Border.all(color: Colors.red.withValues(alpha: 0.5), width: 2)
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                emoji,
                style: TextStyle(fontSize: compact ? 18 : 24),
              ),
              SizedBox(width: compact ? 4 : 6),
              Text(
                count.toString(),
                style: TextStyle(
                  fontSize: compact ? 16 : 20,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : AppTheme.textPrimaryColor,
                ),
              ),
            ],
          ),
        ),
        if (showLabel) ...[
          SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: isDarkMode ? Colors.white70 : AppTheme.textSecondaryColor,
            ),
          ),
        ],
      ],
    );
  }
}

/// Card expandido com mais detalhes sobre os streaks
class StreakDetailCard extends StatelessWidget {
  final bool showCheckInAction;

  const StreakDetailCard({
    Key? key,
    this.showCheckInAction = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Consumer<StreakProvider>(
      builder: (context, streakProvider, child) {
        final mainStreak = streakProvider.registrationStreak;
        final bestStreak = streakProvider.bestOverallStreak;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDarkMode ? AppTheme.darkCardColor : Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hero: título + badge freeze (só quando ativo)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    context.tr.translate('streak_hero_title'),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: isDarkMode
                          ? Colors.white70
                          : AppTheme.textSecondaryColor,
                    ),
                  ),
                  if (streakProvider.isFreezeActive)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('❄️', style: TextStyle(fontSize: 12)),
                          const SizedBox(width: 4),
                          Text(
                            context.tr.translate('streak_freeze_active'),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.blue,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              // Hero big number + description
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    '🔥',
                    style: TextStyle(fontSize: mainStreak > 0 ? 44 : 36),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              '$mainStreak',
                              style: TextStyle(
                                fontSize: 38,
                                fontWeight: FontWeight.bold,
                                color: isDarkMode
                                    ? Colors.white
                                    : AppTheme.textPrimaryColor,
                                height: 1,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                mainStreak == 1
                                    ? context.tr
                                        .translate('streak_hero_day_singular')
                                    : context.tr
                                        .translate('streak_hero_day_plural'),
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: isDarkMode
                                      ? Colors.white70
                                      : AppTheme.textSecondaryColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          mainStreak == 0
                              ? context.tr.translate('streak_hero_start_hint')
                              : context.tr
                                  .translate('streak_hero_record')
                                  .replaceAll(
                                      '{count}', bestStreak.toString()),
                          style: TextStyle(
                            fontSize: 12,
                            color: isDarkMode
                                ? Colors.white54
                                : AppTheme.textSecondaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (showCheckInAction) ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: streakProvider.isLoading
                        ? null
                        : () async {
                            final success =
                                await streakProvider.performCheckIn();
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  success
                                      ? context.tr
                                          .translate('streak_checkin_success')
                                      : context.tr
                                          .translate('streak_checkin_error'),
                                ),
                              ),
                            );
                          },
                    icon: const Icon(Icons.check_circle_outline_rounded),
                    label:
                        Text(context.tr.translate('streak_checkin_action')),
                  ),
                ),
              ],
              const SizedBox(height: 14),
              // Secondary streaks as subtle rows
              _SecondaryStreakRow(
                emoji: '💪',
                label: context.tr.translate('streak_secondary_protein'),
                count: streakProvider.proteinStreak,
                suffix:
                    context.tr.translate('streak_secondary_days_suffix'),
                isDarkMode: isDarkMode,
              ),
              const SizedBox(height: 8),
              _SecondaryStreakRow(
                emoji: '🎯',
                label: context.tr.translate('streak_secondary_goal'),
                count: streakProvider.goalStreak,
                suffix:
                    context.tr.translate('streak_secondary_days_suffix'),
                isDarkMode: isDarkMode,
              ),
              if (streakProvider.isStreakInDanger) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.red.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Text('⚠️', style: TextStyle(fontSize: 20)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          context.tr.translate('streak_in_danger'),
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.red[700],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (streakProvider.freezesAvailable > 0 &&
                  !streakProvider.isFreezeActive) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (dialogContext) => AlertDialog(
                          title: Text(context.tr.translate('activate_freeze_title')),
                          content: Text(
                            context.tr.translate('activate_freeze_description')
                                .replaceAll('{count}', streakProvider.freezesAvailable.toString()),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(dialogContext, false),
                              child: Text(context.tr.translate('cancel')),
                            ),
                            ElevatedButton(
                              onPressed: () => Navigator.pop(dialogContext, true),
                              child: Text(context.tr.translate('activate')),
                            ),
                          ],
                        ),
                      );

                      if (confirmed == true) {
                        await streakProvider.activateFreeze();
                      }
                    },
                    icon: Text('❄️'),
                    label: Text(context.tr.translate('activate_freeze')),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.primary,
                      side: BorderSide(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5)),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _SecondaryStreakRow extends StatelessWidget {
  final String emoji;
  final String label;
  final int count;
  final String suffix;
  final bool isDarkMode;

  const _SecondaryStreakRow({
    required this.emoji,
    required this.label,
    required this.count,
    required this.suffix,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    final textPrimary =
        isDarkMode ? Colors.white : AppTheme.textPrimaryColor;
    final textSecondary =
        isDarkMode ? Colors.white54 : AppTheme.textSecondaryColor;

    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 18)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: textSecondary,
            ),
          ),
        ),
        Text(
          '$count ',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: textPrimary,
          ),
        ),
        Text(
          suffix,
          style: TextStyle(
            fontSize: 12,
            color: textSecondary,
          ),
        ),
      ],
    );
  }
}
