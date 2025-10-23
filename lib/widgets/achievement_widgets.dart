import 'package:flutter/material.dart';
import '../models/essay_progress_model.dart';

/// Widget para exibir uma conquista individual
class AchievementCard extends StatelessWidget {
  final Achievement achievement;
  final bool showAnimation;

  const AchievementCard({
    Key? key,
    required this.achievement,
    this.showAnimation = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: achievement.isUnlocked ? 4 : 2,
      child: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          gradient: achievement.isUnlocked
              ? LinearGradient(
                  colors: [
                    _getAchievementColor(achievement.type).withOpacity(0.1),
                    _getAchievementColor(achievement.type).withOpacity(0.05),
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
              achievement.name,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: achievement.isUnlocked ? null : Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              achievement.description,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: achievement.isUnlocked ? null : Colors.grey[500],
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (achievement.isUnlocked) ...[
              const SizedBox(height: 8),
              Text(
                'Desbloqueado em ${_formatDate(achievement.unlockedAt)}',
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
    final color = achievement.isUnlocked 
        ? _getAchievementColor(achievement.type)
        : Colors.grey[400];

    Widget icon = Icon(
      _getIconData(achievement.iconName),
      size: 48,
      color: color,
    );

    if (achievement.isUnlocked && showAnimation) {
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

  Color _getAchievementColor(AchievementType type) {
    switch (type) {
      case AchievementType.general:
        return Colors.blue;
      case AchievementType.score:
        return Colors.amber;
      case AchievementType.frequency:
        return Colors.green;
      case AchievementType.improvement:
        return Colors.purple;
      case AchievementType.competency:
        return Colors.orange;
      case AchievementType.streak:
        return Colors.red;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}

/// Widget para exibir grade de conquistas
class AchievementGrid extends StatelessWidget {
  final List<Achievement> achievements;
  final String title;
  final int crossAxisCount;

  const AchievementGrid({
    Key? key,
    required this.achievements,
    this.title = 'Conquistas',
    this.crossAxisCount = 2,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (achievements.isEmpty) {
      return _buildEmptyState(context);
    }

    // Separar conquistas desbloqueadas e bloqueadas
    final unlockedAchievements = achievements.where((a) => a.isUnlocked).toList();
    final lockedAchievements = achievements.where((a) => !a.isUnlocked).toList();
    final sortedAchievements = [...unlockedAchievements, ...lockedAchievements];

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
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
      elevation: 4,
      child: Container(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.emoji_events,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Nenhuma conquista disponível',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Complete redações para desbloquear conquistas!',
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
    final unlockedCount = achievements.where((a) => a.isUnlocked).length;
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
  final Achievement achievement;
  final VoidCallback? onDismiss;

  const AchievementUnlockedDialog({
    Key? key,
    required this.achievement,
    this.onDismiss,
  }) : super(key: key);

  @override
  State<AchievementUnlockedDialog> createState() => _AchievementUnlockedDialogState();
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
                    'Conquista Desbloqueada!',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.amber,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.achievement.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.achievement.description,
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
                    child: const Text('Continuar'),
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
  final Achievement achievement;
  final double size;

  const AchievementBadge({
    Key? key,
    required this.achievement,
    this.size = 32,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '${achievement.name}\n${achievement.description}',
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: achievement.isUnlocked 
              ? _getAchievementColor(achievement.type)
              : Colors.grey[300],
          shape: BoxShape.circle,
          boxShadow: achievement.isUnlocked ? [
            BoxShadow(
              color: _getAchievementColor(achievement.type).withOpacity(0.3),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ] : null,
        ),
        child: Icon(
          _getIconData(achievement.iconName),
          size: size * 0.6,
          color: achievement.isUnlocked ? Colors.white : Colors.grey[600],
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

  Color _getAchievementColor(AchievementType type) {
    switch (type) {
      case AchievementType.general:
        return Colors.blue;
      case AchievementType.score:
        return Colors.amber;
      case AchievementType.frequency:
        return Colors.green;
      case AchievementType.improvement:
        return Colors.purple;
      case AchievementType.competency:
        return Colors.orange;
      case AchievementType.streak:
        return Colors.red;
    }
  }
}

/// Widget para exibir lista horizontal de badges
class AchievementBadgeRow extends StatelessWidget {
  final List<Achievement> achievements;
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
    final unlockedAchievements = achievements.where((a) => a.isUnlocked).toList();
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