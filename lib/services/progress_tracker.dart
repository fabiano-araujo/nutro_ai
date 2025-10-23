import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/essay_progress.dart';
import '../models/achievement.dart';
import '../models/progress_summary.dart';

/// Service responsible for tracking user progress and analytics
class ProgressTracker {
  static const String _progressKey = 'essay_progress_data';
  static const String _achievementsKey = 'user_achievements';
  
  /// Get progress history for a specific user
  Future<List<ProgressPoint>> getProgressHistory(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final progressData = prefs.getString('${_progressKey}_$userId');
      
      if (progressData == null) return [];
      
      final List<dynamic> jsonList = json.decode(progressData);
      return jsonList.map((json) => ProgressPoint.fromJson(json)).toList();
    } catch (e) {
      print('Error loading progress history: $e');
      return [];
    }
  }
  
  /// Save a new progress point
  Future<void> saveProgressPoint(String userId, ProgressPoint point) async {
    try {
      final currentHistory = await getProgressHistory(userId);
      currentHistory.add(point);
      
      // Keep only last 100 entries to avoid storage bloat
      if (currentHistory.length > 100) {
        currentHistory.removeRange(0, currentHistory.length - 100);
      }
      
      final prefs = await SharedPreferences.getInstance();
      final jsonList = currentHistory.map((p) => p.toJson()).toList();
      await prefs.setString('${_progressKey}_$userId', json.encode(jsonList));
    } catch (e) {
      print('Error saving progress point: $e');
    }
  }
  
  /// Calculate progress summary for a date range
  Future<ProgressSummary> calculateSummary(String userId, DateRange range) async {
    final history = await getProgressHistory(userId);
    
    final filteredHistory = history.where((point) =>
        point.date.isAfter(range.start) && point.date.isBefore(range.end)
    ).toList();
    
    if (filteredHistory.isEmpty) {
      return ProgressSummary.empty();
    }
    
    // Calculate averages and improvements
    final totalEssays = filteredHistory.length;
    final averageScore = filteredHistory
        .map((p) => p.totalScore)
        .reduce((a, b) => a + b) / totalEssays;
    
    // Calculate competency averages
    final competencyAverages = <String, double>{};
    for (final competency in ['competencia1', 'competencia2', 'competencia3', 'competencia4', 'competencia5']) {
      final scores = filteredHistory
          .map((p) => p.competencyScores[competency] ?? 0)
          .toList();
      competencyAverages[competency] = scores.isNotEmpty 
          ? scores.reduce((a, b) => a + b) / scores.length 
          : 0.0;
    }
    
    // Calculate improvement trend
    final firstHalf = filteredHistory.take(filteredHistory.length ~/ 2).toList();
    final secondHalf = filteredHistory.skip(filteredHistory.length ~/ 2).toList();
    
    final firstHalfAvg = firstHalf.isNotEmpty 
        ? firstHalf.map((p) => p.totalScore).reduce((a, b) => a + b) / firstHalf.length
        : 0.0;
    final secondHalfAvg = secondHalf.isNotEmpty
        ? secondHalf.map((p) => p.totalScore).reduce((a, b) => a + b) / secondHalf.length
        : 0.0;
    
    final improvementTrend = secondHalfAvg - firstHalfAvg;
    
    return ProgressSummary(
      totalEssays: totalEssays,
      averageScore: averageScore,
      competencyAverages: competencyAverages,
      improvementTrend: improvementTrend,
      dateRange: range,
      bestScore: filteredHistory.map((p) => p.totalScore).reduce((a, b) => a > b ? a : b),
      worstScore: filteredHistory.map((p) => p.totalScore).reduce((a, b) => a < b ? a : b),
    );
  }
  
  /// Check and unlock new achievements
  Future<List<Achievement>> checkAchievements(String userId) async {
    final history = await getProgressHistory(userId);
    final currentAchievements = await getUserAchievements(userId);
    final newAchievements = <Achievement>[];
    
    // Define achievement criteria
    final achievementChecks = [
      _checkFirstEssayAchievement(history, currentAchievements),
      _checkConsistencyAchievement(history, currentAchievements),
      _checkImprovementAchievement(history, currentAchievements),
      _checkPerfectionistAchievement(history, currentAchievements),
      _checkDedicationAchievement(history, currentAchievements),
    ];
    
    for (final achievement in achievementChecks) {
      if (achievement != null) {
        newAchievements.add(achievement);
        await _saveAchievement(userId, achievement);
      }
    }
    
    return newAchievements;
  }
  
  /// Get user's current achievements
  Future<List<Achievement>> getUserAchievements(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final achievementsData = prefs.getString('${_achievementsKey}_$userId');
      
      if (achievementsData == null) return [];
      
      final List<dynamic> jsonList = json.decode(achievementsData);
      return jsonList.map((json) => Achievement.fromJson(json)).toList();
    } catch (e) {
      print('Error loading achievements: $e');
      return [];
    }
  }
  
  /// Save a new achievement
  Future<void> _saveAchievement(String userId, Achievement achievement) async {
    try {
      final currentAchievements = await getUserAchievements(userId);
      
      // Check if achievement already exists
      if (currentAchievements.any((a) => a.id == achievement.id)) {
        return;
      }
      
      currentAchievements.add(achievement);
      
      final prefs = await SharedPreferences.getInstance();
      final jsonList = currentAchievements.map((a) => a.toJson()).toList();
      await prefs.setString('${_achievementsKey}_$userId', json.encode(jsonList));
    } catch (e) {
      print('Error saving achievement: $e');
    }
  }
  
  /// Compare user performance with peers (mock implementation)
  Future<ComparisonData> compareWithPeers(String userId) async {
    final userHistory = await getProgressHistory(userId);
    
    if (userHistory.isEmpty) {
      return ComparisonData.empty();
    }
    
    final userAverage = userHistory
        .map((p) => p.totalScore)
        .reduce((a, b) => a + b) / userHistory.length;
    
    // Mock peer data - in real implementation, this would come from backend
    final peerAverage = 650.0; // Mock average
    final percentile = _calculatePercentile(userAverage, peerAverage);
    
    return ComparisonData(
      userAverage: userAverage,
      peerAverage: peerAverage,
      percentile: percentile,
      ranking: _calculateRanking(percentile),
    );
  }
  
  // Achievement check methods
  Achievement? _checkFirstEssayAchievement(List<ProgressPoint> history, List<Achievement> current) {
    if (history.isNotEmpty && !current.any((a) => a.id == 'first_essay')) {
      return Achievement(
        id: 'first_essay',
        title: 'Primeira Redação',
        description: 'Parabéns por escrever sua primeira redação!',
        iconPath: 'assets/images/achievements/first_essay.png',
        unlockedAt: DateTime.now(),
        category: AchievementCategory.milestone,
      );
    }
    return null;
  }
  
  Achievement? _checkConsistencyAchievement(List<ProgressPoint> history, List<Achievement> current) {
    if (history.length >= 7 && !current.any((a) => a.id == 'consistency_week')) {
      // Check if user wrote essays for 7 consecutive days
      final sortedHistory = history..sort((a, b) => a.date.compareTo(b.date));
      int consecutiveDays = 1;
      
      for (int i = 1; i < sortedHistory.length; i++) {
        final daysDiff = sortedHistory[i].date.difference(sortedHistory[i-1].date).inDays;
        if (daysDiff == 1) {
          consecutiveDays++;
          if (consecutiveDays >= 7) {
            return Achievement(
              id: 'consistency_week',
              title: 'Consistência Semanal',
              description: 'Escreveu redações por 7 dias consecutivos!',
              iconPath: 'assets/images/achievements/consistency.png',
              unlockedAt: DateTime.now(),
              category: AchievementCategory.consistency,
            );
          }
        } else {
          consecutiveDays = 1;
        }
      }
    }
    return null;
  }
  
  Achievement? _checkImprovementAchievement(List<ProgressPoint> history, List<Achievement> current) {
    if (history.length >= 5 && !current.any((a) => a.id == 'improvement_100')) {
      final sortedHistory = history..sort((a, b) => a.date.compareTo(b.date));
      final firstScore = sortedHistory.first.totalScore;
      final lastScore = sortedHistory.last.totalScore;
      
      if (lastScore - firstScore >= 100) {
        return Achievement(
          id: 'improvement_100',
          title: 'Grande Evolução',
          description: 'Melhorou sua pontuação em mais de 100 pontos!',
          iconPath: 'assets/images/achievements/improvement.png',
          unlockedAt: DateTime.now(),
          category: AchievementCategory.improvement,
        );
      }
    }
    return null;
  }
  
  Achievement? _checkPerfectionistAchievement(List<ProgressPoint> history, List<Achievement> current) {
    if (!current.any((a) => a.id == 'perfectionist') && 
        history.any((p) => p.totalScore >= 950)) {
      return Achievement(
        id: 'perfectionist',
        title: 'Perfeccionista',
        description: 'Alcançou uma pontuação acima de 950 pontos!',
        iconPath: 'assets/images/achievements/perfectionist.png',
        unlockedAt: DateTime.now(),
        category: AchievementCategory.excellence,
      );
    }
    return null;
  }
  
  Achievement? _checkDedicationAchievement(List<ProgressPoint> history, List<Achievement> current) {
    if (history.length >= 50 && !current.any((a) => a.id == 'dedication_50')) {
      return Achievement(
        id: 'dedication_50',
        title: 'Dedicação Total',
        description: 'Escreveu mais de 50 redações!',
        iconPath: 'assets/images/achievements/dedication.png',
        unlockedAt: DateTime.now(),
        category: AchievementCategory.milestone,
      );
    }
    return null;
  }
  
  double _calculatePercentile(double userScore, double peerAverage) {
    // Simplified percentile calculation
    if (userScore >= peerAverage * 1.2) return 90.0;
    if (userScore >= peerAverage * 1.1) return 80.0;
    if (userScore >= peerAverage) return 70.0;
    if (userScore >= peerAverage * 0.9) return 60.0;
    if (userScore >= peerAverage * 0.8) return 50.0;
    return 40.0;
  }
  
  String _calculateRanking(double percentile) {
    if (percentile >= 90) return 'Excelente';
    if (percentile >= 80) return 'Muito Bom';
    if (percentile >= 70) return 'Bom';
    if (percentile >= 60) return 'Regular';
    return 'Precisa Melhorar';
  }
}