import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../i18n/app_localizations_extension.dart';
import '../providers/challenges_provider.dart';
import '../providers/friends_provider.dart';
import '../providers/streak_provider.dart';
import '../theme/app_theme.dart';

class SocialSummaryCard extends StatelessWidget {
  final VoidCallback? onOpenSocialHub;

  const SocialSummaryCard({
    super.key,
    this.onOpenSocialHub,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer3<StreakProvider, FriendsProvider, ChallengesProvider>(
      builder: (context, streakProvider, friendsProvider, challengesProvider, _) {
        final isDarkMode = Theme.of(context).brightness == Brightness.dark;
        final isLoading = (streakProvider.isLoading && !streakProvider.hasStreak) ||
            (friendsProvider.isLoading && friendsProvider.friendCount == 0) ||
            (challengesProvider.isLoading &&
                challengesProvider.activeChallengeCount == 0 &&
                challengesProvider.publicChallengeCount == 0);

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDarkMode ? AppTheme.darkCardColor : Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDarkMode ? 0.22 : 0.06),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.hub_rounded,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.tr.translate('social_summary_title'),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: isDarkMode
                                ? Colors.white
                                : AppTheme.textPrimaryColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          context.tr.translate('social_summary_subtitle'),
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
                  IconButton(
                    onPressed: onOpenSocialHub,
                    tooltip: context.tr.translate('social_open_hub'),
                    icon: const Icon(Icons.arrow_forward_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: CircularProgressIndicator(),
                  ),
                )
              else ...[
                Row(
                  children: [
                    Expanded(
                      child: _SummaryStat(
                        icon: Icons.local_fire_department_rounded,
                        color: const Color(0xFFFF6B35),
                        label: context.tr.translate('social_summary_streak'),
                        value: '${streakProvider.primaryStreak}',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _SummaryStat(
                        icon: Icons.people_alt_rounded,
                        color: const Color(0xFF4E8CFF),
                        label: context.tr.translate('social_summary_duo'),
                        value: '${friendsProvider.duoStreakCount}',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _SummaryStat(
                        icon: Icons.emoji_events_rounded,
                        color: const Color(0xFFF4B400),
                        label: context.tr.translate('social_summary_challenges'),
                        value: '${challengesProvider.activeChallengeCount}',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (streakProvider.isFreezeActive)
                      _StatusPill(
                        label: context.tr.translate('streak_freeze_active'),
                        color: Colors.blue,
                      ),
                    if (streakProvider.isStreakInDanger)
                      _StatusPill(
                        label: context.tr.translate('streak_in_danger_short'),
                        color: Colors.red,
                      ),
                    _StatusPill(
                      label:
                          '${friendsProvider.friendCount} ${context.tr.translate('social_summary_friends')}',
                      color: Colors.teal,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _PreviewSection(
                  title: context.tr.translate('social_summary_duo_preview'),
                  emptyLabel: context.tr.translate('social_summary_duo_empty'),
                  children: friendsProvider.previewDuoStreaks.map((duo) {
                    final streak = duo.friendStreak?.currentStreak ?? 0;
                    return _PreviewRow(
                      title: duo.friend.name,
                      subtitle:
                          '$streak ${context.tr.translate('challenge_days_completed')}',
                      trailing: duo.myCheckIn
                          ? context.tr.translate('challenge_updated_today')
                          : context.tr.translate('challenge_waiting_today'),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
                _PreviewSection(
                  title: context.tr.translate('social_summary_challenge_preview'),
                  emptyLabel:
                      context.tr.translate('social_summary_challenge_empty'),
                  children: challengesProvider.previewChallenges.map((challenge) {
                    final progress = challenge.progress;
                    return _PreviewRow(
                      title: challenge.name,
                      subtitle: progress == null
                          ? challenge.typeFormatted
                          : '${progress.completedDays}/${progress.targetDays} ${context.tr.translate('challenge_days_completed')}',
                      trailing: progress == null
                          ? '--'
                          : '${progress.percent.toStringAsFixed(0)}%',
                    );
                  }).toList(),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: onOpenSocialHub,
                    icon: const Icon(Icons.hub_rounded),
                    label: Text(context.tr.translate('social_open_hub')),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
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

class _SummaryStat extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;

  const _SummaryStat({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDarkMode ? AppTheme.darkComponentColor : AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: isDarkMode ? Colors.white : AppTheme.textPrimaryColor,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: isDarkMode
                  ? Colors.white54
                  : AppTheme.textSecondaryColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusPill({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _PreviewSection extends StatelessWidget {
  final String title;
  final String emptyLabel;
  final List<Widget> children;

  const _PreviewSection({
    required this.title,
    required this.emptyLabel,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: isDarkMode ? Colors.white70 : AppTheme.textPrimaryColor,
          ),
        ),
        const SizedBox(height: 8),
        if (children.isEmpty)
          Text(
            emptyLabel,
            style: TextStyle(
              fontSize: 12,
              color: isDarkMode ? Colors.white54 : AppTheme.textSecondaryColor,
            ),
          )
        else
          ...children,
      ],
    );
  }
}

class _PreviewRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final String trailing;

  const _PreviewRow({
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDarkMode ? Colors.white10 : AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDarkMode
                          ? Colors.white
                          : AppTheme.textPrimaryColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDarkMode
                          ? Colors.white54
                          : AppTheme.textSecondaryColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              trailing,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).primaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
