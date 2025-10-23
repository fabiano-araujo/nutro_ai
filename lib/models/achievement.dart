/// Represents a user achievement/badge
class Achievement {
  final String id;
  final String title;
  final String description;
  final String iconPath;
  final DateTime unlockedAt;
  final AchievementCategory category;
  final int? requiredValue;
  final int? currentValue;

  Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.iconPath,
    required this.unlockedAt,
    required this.category,
    this.requiredValue,
    this.currentValue,
  });

  factory Achievement.fromJson(Map<String, dynamic> json) {
    return Achievement(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      iconPath: json['iconPath'] as String,
      unlockedAt: DateTime.parse(json['unlockedAt'] as String),
      category: AchievementCategory.values.firstWhere(
        (e) => e.toString() == json['category'],
        orElse: () => AchievementCategory.milestone,
      ),
      requiredValue: json['requiredValue'] as int?,
      currentValue: json['currentValue'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'iconPath': iconPath,
      'unlockedAt': unlockedAt.toIso8601String(),
      'category': category.toString(),
      'requiredValue': requiredValue,
      'currentValue': currentValue,
    };
  }

  /// Check if achievement is completed
  bool get isCompleted => currentValue != null && requiredValue != null 
      ? currentValue! >= requiredValue! 
      : true;

  /// Get progress percentage for achievements with progress tracking
  double get progressPercentage {
    if (requiredValue == null || currentValue == null) return 100.0;
    return (currentValue! / requiredValue!) * 100;
  }
}

/// Categories for organizing achievements
enum AchievementCategory {
  milestone,    // First essay, 10th essay, etc.
  consistency,  // Daily streaks, weekly goals
  improvement,  // Score improvements
  excellence,   // High scores, perfect scores
  dedication,   // Total essays written
  competency,   // Specific competency achievements
}

/// Extension to get display names for achievement categories
extension AchievementCategoryExtension on AchievementCategory {
  String get displayName {
    switch (this) {
      case AchievementCategory.milestone:
        return 'Marco';
      case AchievementCategory.consistency:
        return 'Consistência';
      case AchievementCategory.improvement:
        return 'Melhoria';
      case AchievementCategory.excellence:
        return 'Excelência';
      case AchievementCategory.dedication:
        return 'Dedicação';
      case AchievementCategory.competency:
        return 'Competência';
    }
  }

  String get description {
    switch (this) {
      case AchievementCategory.milestone:
        return 'Conquistas por marcos importantes';
      case AchievementCategory.consistency:
        return 'Conquistas por prática regular';
      case AchievementCategory.improvement:
        return 'Conquistas por evolução';
      case AchievementCategory.excellence:
        return 'Conquistas por excelência';
      case AchievementCategory.dedication:
        return 'Conquistas por dedicação';
      case AchievementCategory.competency:
        return 'Conquistas por competências específicas';
    }
  }
}