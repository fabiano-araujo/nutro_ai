import 'package:flutter/material.dart';
import '../i18n/app_localizations.dart';
import '../models/achievement.dart';

/// Widget that displays user achievements and badges
class AchievementDisplay extends StatelessWidget {
  final List<Achievement> achievements;
  final bool showProgress;
  final VoidCallback? onViewAll;

  const AchievementDisplay({
    Key? key,
    required this.achievements,
    this.showProgress = false,
    this.onViewAll,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _translate(context, 'progress_achievements'),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                if (onViewAll != null)
                  TextButton(
                    onPressed: onViewAll,
                    child: Text(_translate(context, 'progress_view_all')),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (achievements.isEmpty)
              Center(
                child: Column(
                  children: [
                    const Icon(
                      Icons.emoji_events_outlined,
                      size: 48,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _translate(context, 'progress_no_achievements_yet'),
                      style: const TextStyle(color: Colors.grey),
                    ),
                    Text(
                      _translate(context, 'progress_keep_writing_to_unlock'),
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              )
            else
              _buildAchievementGrid(context),
          ],
        ),
      ),
    );
  }

  Widget _buildAchievementGrid(BuildContext context) {
    final displayAchievements =
        showProgress ? achievements : achievements.take(6).toList();

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 1.0,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: displayAchievements.length,
      itemBuilder: (context, index) {
        final achievement = displayAchievements[index];
        return _buildAchievementItem(context, achievement);
      },
    );
  }

  Widget _buildAchievementItem(BuildContext context, Achievement achievement) {
    return GestureDetector(
      onTap: () => _showAchievementDetails(context, achievement),
      child: Container(
        decoration: BoxDecoration(
          color: achievement.isCompleted
              ? Theme.of(context).primaryColor.withOpacity(0.1)
              : Colors.grey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: achievement.isCompleted
                ? Theme.of(context).primaryColor
                : Colors.grey,
            width: 2,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildAchievementIcon(achievement),
            const SizedBox(height: 4),
            Text(
              _localizedAchievementTitle(context, achievement),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: achievement.isCompleted
                        ? Theme.of(context).primaryColor
                        : Colors.grey,
                  ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (showProgress && !achievement.isCompleted)
              _buildProgressIndicator(achievement),
          ],
        ),
      ),
    );
  }

  Widget _buildAchievementIcon(Achievement achievement) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: achievement.isCompleted
            ? _getCategoryColor(achievement.category)
            : Colors.grey.withOpacity(0.3),
      ),
      child: Icon(
        _getCategoryIcon(achievement.category),
        color: achievement.isCompleted ? Colors.white : Colors.grey,
        size: 24,
      ),
    );
  }

  Widget _buildProgressIndicator(Achievement achievement) {
    if (achievement.requiredValue == null || achievement.currentValue == null) {
      return Container();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 4.0),
      child: LinearProgressIndicator(
        value: achievement.progressPercentage / 100,
        backgroundColor: Colors.grey.withOpacity(0.3),
        valueColor: AlwaysStoppedAnimation<Color>(
          _getCategoryColor(achievement.category),
        ),
      ),
    );
  }

  void _showAchievementDetails(BuildContext context, Achievement achievement) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              _buildAchievementIcon(achievement),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _localizedAchievementTitle(context, achievement),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_localizedAchievementDescription(context, achievement)),
              const SizedBox(height: 12),
              _buildAchievementInfo(context, achievement),
              if (!achievement.isCompleted && showProgress)
                _buildProgressDetails(context, achievement),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(_translate(context, 'close')),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAchievementInfo(BuildContext context, Achievement achievement) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.category,
              size: 16,
              color: Colors.grey[600],
            ),
            const SizedBox(width: 4),
            Text(
              _translateWith(
                context,
                'progress_achievement_category_label',
                {'category': _localizedCategory(context, achievement.category)},
              ),
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        if (achievement.isCompleted)
          Row(
            children: [
              Icon(
                Icons.access_time,
                size: 16,
                color: Colors.grey[600],
              ),
              const SizedBox(width: 4),
              Text(
                _translateWith(
                  context,
                  'progress_unlocked_on',
                  {
                    'date': MaterialLocalizations.of(context)
                        .formatFullDate(achievement.unlockedAt),
                  },
                ),
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildProgressDetails(BuildContext context, Achievement achievement) {
    if (achievement.requiredValue == null || achievement.currentValue == null) {
      return Container();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        const Divider(),
        const SizedBox(height: 8),
        Text(
          _translate(context, 'progress_tab_progress'),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: achievement.progressPercentage / 100,
          backgroundColor: Colors.grey.withOpacity(0.3),
          valueColor: AlwaysStoppedAnimation<Color>(
            _getCategoryColor(achievement.category),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${achievement.currentValue}/${achievement.requiredValue} (${achievement.progressPercentage.toStringAsFixed(1)}%)',
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Color _getCategoryColor(AchievementCategory category) {
    switch (category) {
      case AchievementCategory.milestone:
        return Colors.purple;
      case AchievementCategory.consistency:
        return Colors.green;
      case AchievementCategory.improvement:
        return Colors.orange;
      case AchievementCategory.excellence:
        return Colors.amber;
      case AchievementCategory.dedication:
        return Colors.blue;
      case AchievementCategory.competency:
        return Colors.red;
    }
  }

  IconData _getCategoryIcon(AchievementCategory category) {
    switch (category) {
      case AchievementCategory.milestone:
        return Icons.flag;
      case AchievementCategory.consistency:
        return Icons.schedule;
      case AchievementCategory.improvement:
        return Icons.trending_up;
      case AchievementCategory.excellence:
        return Icons.star;
      case AchievementCategory.dedication:
        return Icons.favorite;
      case AchievementCategory.competency:
        return Icons.school;
    }
  }
}

/// Widget for displaying a single achievement badge
class AchievementBadge extends StatelessWidget {
  final Achievement achievement;
  final double size;
  final bool showTitle;

  const AchievementBadge({
    Key? key,
    required this.achievement,
    this.size = 60,
    this.showTitle = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: achievement.isCompleted
                ? _getCategoryColor(achievement.category)
                : Colors.grey.withOpacity(0.3),
            boxShadow: achievement.isCompleted
                ? [
                    BoxShadow(
                      color: _getCategoryColor(achievement.category)
                          .withOpacity(0.3),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
          child: Icon(
            _getCategoryIcon(achievement.category),
            color: achievement.isCompleted ? Colors.white : Colors.grey,
            size: size * 0.4,
          ),
        ),
        if (showTitle) ...[
          const SizedBox(height: 8),
          Text(
            _localizedAchievementTitle(context, achievement),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: achievement.isCompleted
                      ? Theme.of(context).primaryColor
                      : Colors.grey,
                ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }

  Color _getCategoryColor(AchievementCategory category) {
    switch (category) {
      case AchievementCategory.milestone:
        return Colors.purple;
      case AchievementCategory.consistency:
        return Colors.green;
      case AchievementCategory.improvement:
        return Colors.orange;
      case AchievementCategory.excellence:
        return Colors.amber;
      case AchievementCategory.dedication:
        return Colors.blue;
      case AchievementCategory.competency:
        return Colors.red;
    }
  }

  IconData _getCategoryIcon(AchievementCategory category) {
    switch (category) {
      case AchievementCategory.milestone:
        return Icons.flag;
      case AchievementCategory.consistency:
        return Icons.schedule;
      case AchievementCategory.improvement:
        return Icons.trending_up;
      case AchievementCategory.excellence:
        return Icons.star;
      case AchievementCategory.dedication:
        return Icons.favorite;
      case AchievementCategory.competency:
        return Icons.school;
    }
  }
}

const Map<String, String> _achievementKeyById = {
  'first_essay': 'first_essay',
  'essay_5': 'essay_5',
  'essay_10': 'essay_10',
  'essay_25': 'essay_25',
  'essay_50': 'essay_50',
  'essay_100': 'essay_100',
  'score_600': 'score_600',
  'score_600_plus': 'score_600',
  'score_700': 'score_700',
  'score_800': 'score_800',
  'score_800_plus': 'score_800',
  'score_900': 'score_900',
  'score_900_plus': 'score_900',
  'score_1000': 'score_1000',
  'perfect_score': 'score_1000',
  'daily_streak_3': 'daily_streak_3',
  'daily_writer': 'daily_streak_3',
  'daily_streak_7': 'daily_streak_7',
  'weekly_streak': 'daily_streak_7',
  'consistency_week': 'daily_streak_7',
  'monthly_champion': 'monthly_champion',
  'improvement_100': 'improvement_100',
  'improver': 'improvement_100',
  'improvement_200': 'improvement_200',
  'big_improver': 'improvement_200',
  'competency_1_master': 'competency_1_master',
  'competency_2_master': 'competency_2_master',
  'competency_3_master': 'competency_3_master',
  'competency_4_master': 'competency_4_master',
  'competency_5_master': 'competency_5_master',
  'all_competencies_master': 'all_competencies_master',
  'night_owl': 'night_owl',
  'early_bird': 'early_bird',
  'speed_writer': 'speed_writer',
  'perfectionist': 'perfectionist',
  'dedication_50': 'dedication_50',
};

String _localizedAchievementTitle(
  BuildContext context,
  Achievement achievement,
) {
  final key = _achievementKeyById[achievement.id];
  return key == null
      ? achievement.title
      : _translate(context, 'progress_achievement_${key}_title');
}

String _localizedAchievementDescription(
  BuildContext context,
  Achievement achievement,
) {
  final key = _achievementKeyById[achievement.id];
  return key == null
      ? achievement.description
      : _translate(context, 'progress_achievement_${key}_description');
}

String _localizedCategory(
  BuildContext context,
  AchievementCategory category,
) {
  final key = switch (category) {
    AchievementCategory.milestone => 'milestone',
    AchievementCategory.consistency => 'consistency',
    AchievementCategory.improvement => 'improvement',
    AchievementCategory.excellence => 'excellence',
    AchievementCategory.dedication => 'dedication',
    AchievementCategory.competency => 'competency',
  };
  return _translate(context, 'progress_achievement_category_$key');
}

String _translate(BuildContext context, String key) {
  return AppLocalizations.of(context).translate(key);
}

String _translateWith(
  BuildContext context,
  String key,
  Map<String, String> values,
) {
  var text = _translate(context, key);
  values.forEach((placeholder, value) {
    text = text.replaceAll('{$placeholder}', value);
  });
  return text;
}
