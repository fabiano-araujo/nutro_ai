import 'package:flutter/material.dart';
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
                  'Conquistas',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (onViewAll != null)
                  TextButton(
                    onPressed: onViewAll,
                    child: const Text('Ver todas'),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (achievements.isEmpty)
              const Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.emoji_events_outlined,
                      size: 48,
                      color: Colors.grey,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Nenhuma conquista ainda',
                      style: TextStyle(color: Colors.grey),
                    ),
                    Text(
                      'Continue escrevendo para desbloquear!',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
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
    final displayAchievements = showProgress 
        ? achievements 
        : achievements.take(6).toList();

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
              achievement.title,
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
                  achievement.title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(achievement.description),
              const SizedBox(height: 12),
              _buildAchievementInfo(achievement),
              if (!achievement.isCompleted && showProgress)
                _buildProgressDetails(achievement),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Fechar'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAchievementInfo(Achievement achievement) {
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
              'Categoria: ${achievement.category.displayName}',
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
                'Desbloqueado em: ${_formatDate(achievement.unlockedAt)}',
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

  Widget _buildProgressDetails(Achievement achievement) {
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
          'Progresso',
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

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
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
                      color: _getCategoryColor(achievement.category).withOpacity(0.3),
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
            achievement.title,
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