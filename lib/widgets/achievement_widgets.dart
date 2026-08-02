import 'package:flutter/material.dart';
import '../i18n/app_localizations.dart';
import '../models/achievement.dart' as progress_model;
import '../models/essay_progress_model.dart' as legacy_model;
import 'state_animation.dart';

/// Widget para exibir uma conquista individual
class AchievementCard extends StatelessWidget {
  final Object achievement;
  final bool showAnimation;

  const AchievementCard({
    Key? key,
    required this.achievement,
    this.showAnimation = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: _isAchievementUnlocked(achievement) ? 4 : 2,
      child: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          gradient: _isAchievementUnlocked(achievement)
              ? LinearGradient(
                  colors: [
                    _getAchievementColor(achievement).withOpacity(0.1),
                    _getAchievementColor(achievement).withOpacity(0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildIcon(context),
            const SizedBox(height: 12),
            Text(
              _localizedAchievementName(context, achievement),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: _isAchievementUnlocked(achievement)
                        ? null
                        : Colors.grey[600],
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _localizedAchievementDescription(context, achievement),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: _isAchievementUnlocked(achievement)
                        ? null
                        : Colors.grey[500],
                  ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (_isAchievementUnlocked(achievement)) ...[
              const SizedBox(height: 8),
              Text(
                _translateWith(
                  context,
                  'progress_unlocked_on',
                  {
                    'date': MaterialLocalizations.of(context)
                        .formatFullDate(_achievementUnlockedAt(achievement)),
                  },
                ),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                      fontSize: 10,
                    ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildIcon(BuildContext context) {
    final color = _isAchievementUnlocked(achievement)
        ? _getAchievementColor(achievement)
        : Colors.grey[400];

    Widget icon = Icon(
      _getIconData(_achievementIconName(achievement)),
      size: 48,
      color: color,
    );

    if (_isAchievementUnlocked(achievement) && showAnimation) {
      return TweenAnimationBuilder<double>(
        duration: const Duration(milliseconds: 1000),
        tween: Tween(begin: 0.0, end: 1.0),
        builder: (context, value, child) {
          return Transform.scale(
            scale: 0.8 + (0.2 * value),
            child: Opacity(
              opacity: value,
              child: icon,
            ),
          );
        },
      );
    }

    return icon;
  }

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'edit':
        return Icons.edit;
      case 'star':
        return Icons.star;
      case 'calendar_today':
        return Icons.calendar_today;
      case 'lightbulb':
        return Icons.lightbulb;
      case 'trophy':
        return Icons.emoji_events;
      case 'medal':
        return Icons.military_tech;
      case 'fire':
        return Icons.local_fire_department;
      case 'target':
        return Icons.gps_fixed;
      case 'trending_up':
        return Icons.trending_up;
      case 'nightlight':
        return Icons.nightlight_round;
      case 'wb_sunny':
        return Icons.wb_sunny;
      case 'speed':
        return Icons.speed;
      default:
        return Icons.emoji_events;
    }
  }

  Color _getAchievementColor(Object achievement) {
    return _achievementColor(achievement);
  }
}

/// Widget para exibir grade de conquistas
class AchievementGrid extends StatelessWidget {
  final List<Object> achievements;
  final String? title;
  final int crossAxisCount;

  const AchievementGrid({
    Key? key,
    required this.achievements,
    this.title,
    this.crossAxisCount = 2,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (achievements.isEmpty) {
      return _buildEmptyState(context);
    }

    // Separar conquistas desbloqueadas e bloqueadas
    final unlockedAchievements =
        achievements.where(_isAchievementUnlocked).toList();
    final lockedAchievements =
        achievements.where((a) => !_isAchievementUnlocked(a)).toList();
    final sortedAchievements = [...unlockedAchievements, ...lockedAchievements];

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
                  title ?? _translate(context, 'progress_achievements'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                _buildProgressIndicator(context),
              ],
            ),
            const SizedBox(height: 16),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                childAspectRatio: 0.8,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: sortedAchievements.length,
              itemBuilder: (context, index) {
                return AchievementCard(
                  achievement: sortedAchievements[index],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Card(
      elevation: 1,
      child: Container(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            StateAnimation(
              fallbackIcon: Icons.emoji_events,
              size: 120,
              accentColor: Colors.amber,
            ),
            const SizedBox(height: 16),
            Text(
              _translate(context, 'progress_no_achievements_available'),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              _translate(context, 'progress_complete_essays_to_unlock'),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[500],
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressIndicator(BuildContext context) {
    final unlockedCount = achievements.where(_isAchievementUnlocked).length;
    final totalCount = achievements.length;
    final progress = totalCount > 0 ? unlockedCount / totalCount : 0.0;

    return Row(
      children: [
        Text(
          '$unlockedCount/$totalCount',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 60,
          height: 6,
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.grey[300],
            valueColor: AlwaysStoppedAnimation<Color>(
              Theme.of(context).primaryColor,
            ),
          ),
        ),
      ],
    );
  }
}

/// Widget para exibir conquista recém-desbloqueada
class AchievementUnlockedDialog extends StatefulWidget {
  final Object achievement;
  final VoidCallback? onDismiss;

  const AchievementUnlockedDialog({
    Key? key,
    required this.achievement,
    this.onDismiss,
  }) : super(key: key);

  @override
  State<AchievementUnlockedDialog> createState() =>
      _AchievementUnlockedDialogState();
}

class _AchievementUnlockedDialogState extends State<AchievementUnlockedDialog>
    with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late AnimationController _rotationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();

    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _rotationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.elasticOut,
    ));

    _rotationAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _rotationController,
      curve: Curves.easeInOut,
    ));

    _scaleController.forward();
    _rotationController.forward();
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: AnimatedBuilder(
        animation: Listenable.merge([_scaleAnimation, _rotationAnimation]),
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              padding: const EdgeInsets.all(24.0),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Transform.rotate(
                    angle: _rotationAnimation.value * 0.1,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.emoji_events,
                        size: 64,
                        color: Colors.amber,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _translate(context, 'progress_achievement_unlocked'),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.amber,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _localizedAchievementName(context, widget.achievement),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _localizedAchievementDescription(
                      context,
                      widget.achievement,
                    ),
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      widget.onDismiss?.call();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 12,
                      ),
                    ),
                    child: Text(_translate(context, 'continue')),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Widget para exibir badge compacto de conquista
class AchievementBadge extends StatelessWidget {
  final Object achievement;
  final double size;

  const AchievementBadge({
    Key? key,
    required this.achievement,
    this.size = 32,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message:
          '${_localizedAchievementName(context, achievement)}\n${_localizedAchievementDescription(context, achievement)}',
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: _isAchievementUnlocked(achievement)
              ? _getAchievementColor(achievement)
              : Colors.grey[300],
          shape: BoxShape.circle,
          boxShadow: _isAchievementUnlocked(achievement)
              ? [
                  BoxShadow(
                    color: _getAchievementColor(achievement).withOpacity(0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Icon(
          _getIconData(_achievementIconName(achievement)),
          size: size * 0.6,
          color: _isAchievementUnlocked(achievement)
              ? Colors.white
              : Colors.grey[600],
        ),
      ),
    );
  }

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'edit':
        return Icons.edit;
      case 'star':
        return Icons.star;
      case 'calendar_today':
        return Icons.calendar_today;
      case 'lightbulb':
        return Icons.lightbulb;
      case 'trophy':
        return Icons.emoji_events;
      case 'medal':
        return Icons.military_tech;
      case 'fire':
        return Icons.local_fire_department;
      case 'target':
        return Icons.gps_fixed;
      default:
        return Icons.emoji_events;
    }
  }

  Color _getAchievementColor(Object achievement) {
    return _achievementColor(achievement);
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

String _achievementId(Object achievement) {
  if (achievement is legacy_model.Achievement) return achievement.id;
  if (achievement is progress_model.Achievement) return achievement.id;
  return '';
}

String _achievementName(Object achievement) {
  if (achievement is legacy_model.Achievement) return achievement.name;
  if (achievement is progress_model.Achievement) return achievement.title;
  return '';
}

String _achievementDescription(Object achievement) {
  if (achievement is legacy_model.Achievement) return achievement.description;
  if (achievement is progress_model.Achievement) return achievement.description;
  return '';
}

DateTime _achievementUnlockedAt(Object achievement) {
  if (achievement is legacy_model.Achievement) return achievement.unlockedAt;
  if (achievement is progress_model.Achievement) return achievement.unlockedAt;
  return DateTime.fromMillisecondsSinceEpoch(0);
}

bool _isAchievementUnlocked(Object achievement) {
  if (achievement is legacy_model.Achievement) return achievement.isUnlocked;
  if (achievement is progress_model.Achievement) return achievement.isCompleted;
  return false;
}

String _achievementIconName(Object achievement) {
  if (achievement is legacy_model.Achievement) return achievement.iconName;
  if (achievement is progress_model.Achievement) {
    return switch (achievement.category) {
      progress_model.AchievementCategory.milestone => 'trophy',
      progress_model.AchievementCategory.consistency => 'calendar_today',
      progress_model.AchievementCategory.improvement => 'trending_up',
      progress_model.AchievementCategory.excellence => 'star',
      progress_model.AchievementCategory.dedication => 'fire',
      progress_model.AchievementCategory.competency => 'lightbulb',
    };
  }
  return 'trophy';
}

Color _achievementColor(Object achievement) {
  if (achievement is legacy_model.Achievement) {
    return switch (achievement.type) {
      legacy_model.AchievementType.general => Colors.blue,
      legacy_model.AchievementType.score => Colors.amber,
      legacy_model.AchievementType.frequency => Colors.green,
      legacy_model.AchievementType.improvement => Colors.purple,
      legacy_model.AchievementType.competency => Colors.orange,
      legacy_model.AchievementType.streak => Colors.red,
    };
  }
  if (achievement is progress_model.Achievement) {
    return switch (achievement.category) {
      progress_model.AchievementCategory.milestone => Colors.purple,
      progress_model.AchievementCategory.consistency => Colors.green,
      progress_model.AchievementCategory.improvement => Colors.orange,
      progress_model.AchievementCategory.excellence => Colors.amber,
      progress_model.AchievementCategory.dedication => Colors.blue,
      progress_model.AchievementCategory.competency => Colors.red,
    };
  }
  return Colors.grey;
}

String _localizedAchievementName(
  BuildContext context,
  Object achievement,
) {
  final key = _achievementKeyById[_achievementId(achievement)];
  return key == null
      ? _achievementName(achievement)
      : _translate(context, 'progress_achievement_${key}_title');
}

String _localizedAchievementDescription(
  BuildContext context,
  Object achievement,
) {
  final key = _achievementKeyById[_achievementId(achievement)];
  return key == null
      ? _achievementDescription(achievement)
      : _translate(context, 'progress_achievement_${key}_description');
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

/// Widget para exibir lista horizontal de badges
class AchievementBadgeRow extends StatelessWidget {
  final List<Object> achievements;
  final double badgeSize;
  final int maxVisible;

  const AchievementBadgeRow({
    Key? key,
    required this.achievements,
    this.badgeSize = 32,
    this.maxVisible = 5,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final unlockedAchievements =
        achievements.where(_isAchievementUnlocked).toList();
    final visibleAchievements = unlockedAchievements.take(maxVisible).toList();
    final remainingCount = unlockedAchievements.length - maxVisible;

    return Row(
      children: [
        ...visibleAchievements.map((achievement) => Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: AchievementBadge(
                achievement: achievement,
                size: badgeSize,
              ),
            )),
        if (remainingCount > 0)
          Container(
            width: badgeSize,
            height: badgeSize,
            decoration: BoxDecoration(
              color: Colors.grey[400],
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '+$remainingCount',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: badgeSize * 0.3,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
