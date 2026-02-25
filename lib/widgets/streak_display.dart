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
  const StreakDetailCard({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Consumer<StreakProvider>(
      builder: (context, streakProvider, child) {
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    context.tr.translate('your_streaks'),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color:
                          isDarkMode ? Colors.white : AppTheme.textPrimaryColor,
                    ),
                  ),
                  if (streakProvider.isFreezeActive)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('❄️', style: TextStyle(fontSize: 12)),
                          SizedBox(width: 4),
                          Text(
                            context.tr.translate('streak_freeze_active'),
                            style: TextStyle(
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
              const SizedBox(height: 16),
              const StreakDisplay(showLabels: true),
              const SizedBox(height: 16),
              Divider(
                color:
                    isDarkMode ? Colors.white12 : Colors.grey.withValues(alpha: 0.2),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _StatItem(
                    label: context.tr.translate('best_streak'),
                    value: streakProvider.bestOverallStreak.toString(),
                    emoji: '🏆',
                    isDarkMode: isDarkMode,
                  ),
                  _StatItem(
                    label: context.tr.translate('freezes'),
                    value: '${streakProvider.freezesAvailable}/1',
                    emoji: '❄️',
                    isDarkMode: isDarkMode,
                  ),
                ],
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
                      foregroundColor: Colors.blue,
                      side: BorderSide(color: Colors.blue.withValues(alpha: 0.5)),
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

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final String emoji;
  final bool isDarkMode;

  const _StatItem({
    required this.label,
    required this.value,
    required this.emoji,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: TextStyle(fontSize: 16)),
            const SizedBox(width: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : AppTheme.textPrimaryColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isDarkMode ? Colors.white54 : AppTheme.textSecondaryColor,
          ),
        ),
      ],
    );
  }
}
