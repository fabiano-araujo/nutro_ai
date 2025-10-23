import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/essay_progress.dart';
import '../models/achievement.dart';
import '../models/progress_summary.dart';
import '../utils/date_time_utils.dart';

/// Enhanced progress tracker with comprehensive analytics and achievements
class EnhancedProgressTracker {
  static const String _progressKey = 'enhanced_essay_progress';
  static const String _achievementsKey = 'user_achievements_v2';
  static const String _statisticsKey = 'progress_statistics';
  
  /// Get progress history for a specific user
  Future<List<ProgressPoint>> getProgressHistory(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final progressData = prefs.getString('${_progressKey}_$userId');
      
      if (progressData == null) return [];
      
      final List<dynamic> jsonList = json.decode(progressData);
      return jsonList.map((json) => ProgressPoint.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Error loading progress history: $e');
      return [];
    }
  }
  
  /// Save a new progress point
  Future<void> saveProgressPoint(String userId, ProgressPoint point) async {
    try {
      final currentHistory = await getProgressHistory(userId);
      currentHistory.add(point);
      
      // Sort by date to maintain chronological order
      currentHistory.sort((a, b) => a.date.compareTo(b.date));
      
      // Keep only last 200 entries to avoid storage bloat
      if (currentHistory.length > 200) {
        currentHistory.removeRange(0, currentHistory.length - 200);
      }
      
      final prefs = await SharedPreferences.getInstance();
      final jsonList = currentHistory.map((p) => p.toJson()).toList();
      await prefs.setString('${_progressKey}_$userId', json.encode(jsonList));
      
      // Update statistics
      await _updateStatistics(userId, currentHistory);
      
      // Check for new achievements
      await checkAchievements(userId);
    } catch (e) {
      debugPrint('Error saving progress point: $e');
    }
  }
  
  /// Calculate comprehensive progress summary for a date range
  Future<ProgressSummary> calculateSummary(String userId, DateRange range) async {
    final history = await getProgressHistory(userId);
    
    final filteredHistory = history.where((point) =>
        point.date.isAfter(range.start) && point.date.isBefore(range.end)
    ).toList();
    
    if (filteredHistory.isEmpty) {
      return ProgressSummary.empty();
    }
    
    // Calculate basic metrics
    final totalEssays = filteredHistory.length;
    final averageScore = filteredHistory
        .map((p) => p.totalScore)
        .reduce((a, b) => a + b) / totalEssays;
    
    // Calculate competency averages
    final competencyAverages = <String, double>{};
    final competencyNames = ['competencia1', 'competencia2', 'competencia3', 'competencia4', 'competencia5'];
    
    for (final competency in competencyNames) {
      final scores = filteredHistory
          .map((p) => p.competencyScores[competency] ?? 0)
          .where((score) => score > 0)
          .toList();
      
      if (scores.isNotEmpty) {
        competencyAverages[competency] = scores.reduce((a, b) => a + b) / scores.length;
      } else {
        competencyAverages[competency] = 0.0;
      }
    }
    
    // Calculate improvement trend
    final improvementTrend = _calculateImprovementTrend(filteredHistory);
    
    // Find best and worst scores
    final scores = filteredHistory.map((p) => p.totalScore).toList();
    final bestScore = scores.reduce((a, b) => a > b ? a : b);
    final worstScore = scores.reduce((a, b) => a < b ? a : b);
    
    return ProgressSummary(
      totalEssays: totalEssays,
      averageScore: averageScore,
      competencyAverages: competencyAverages,
      improvementTrend: improvementTrend,
      dateRange: range,
      bestScore: bestScore,
      worstScore: worstScore,
    );
  }
  
  /// Generate detailed competency analysis
  Future<Map<String, CompetencyAnalysis>> analyzeCompetencies(String userId) async {
    final history = await getProgressHistory(userId);
    final competencyAnalysis = <String, CompetencyAnalysis>{};
    
    final competencyNames = {
      'competencia1': 'Domínio da Norma Culta',
      'competencia2': 'Compreensão do Tema',
      'competencia3': 'Argumentação e Coesão',
      'competencia4': 'Mecanismos Linguísticos',
      'competencia5': 'Proposta de Intervenção',
    };
    
    for (final entry in competencyNames.entries) {
      final scores = history
          .map((p) => p.competencyScores[entry.key] ?? 0)
          .where((score) => score > 0)
          .toList();
      
      if (scores.isNotEmpty) {
        final analysis = _analyzeCompetencyScores(entry.value, scores);
        competencyAnalysis[entry.key] = analysis;
      }
    }
    
    return competencyAnalysis;
  }
  
  /// Generate temporal progress charts data
  Future<List<ChartDataPoint>> generateTemporalChartData(String userId, DateRange range) async {
    final history = await getProgressHistory(userId);
    
    final filteredHistory = history.where((point) =>
        point.date.isAfter(range.start) && point.date.isBefore(range.end)
    ).toList();
    
    // Group by date and calculate daily averages
    final dailyScores = <String, List<int>>{};
    
    for (final point in filteredHistory) {
      final dateKey = DateTimeUtils.formatDate(point.date, 'yyyy-MM-dd');
      dailyScores[dateKey] = (dailyScores[dateKey] ?? [])..add(point.totalScore);
    }
    
    final chartData = <ChartDataPoint>[];
    final sortedDates = dailyScores.keys.toList()..sort();
    
    for (final dateKey in sortedDates) {
      final scores = dailyScores[dateKey]!;
      final averageScore = scores.reduce((a, b) => a + b) / scores.length;
      final date = DateTime.parse(dateKey);
      
      chartData.add(ChartDataPoint(
        date: date,
        value: averageScore,
        count: scores.length,
      ));
    }
    
    return chartData;
  }
  
  /// Generate competency radar chart data
  Future<Map<String, double>> generateRadarChartData(String userId) async {
    final history = await getProgressHistory(userId);
    
    if (history.isEmpty) return {};
    
    // Calculate recent averages (last 10 essays or all if less than 10)
    final recentHistory = history.length > 10 
        ? history.sublist(history.length - 10)
        : history;
    
    final competencyAverages = <String, double>{};
    final competencyNames = {
      'competencia1': 'Norma Culta',
      'competencia2': 'Compreensão',
      'competencia3': 'Argumentação',
      'competencia4': 'Coesão',
      'competencia5': 'Proposta',
    };
    
    for (final entry in competencyNames.entries) {
      final scores = recentHistory
          .map((p) => p.competencyScores[entry.key] ?? 0)
          .where((score) => score > 0)
          .toList();
      
      if (scores.isNotEmpty) {
        competencyAverages[entry.value] = scores.reduce((a, b) => a + b) / scores.length;
      } else {
        competencyAverages[entry.value] = 0.0;
      }
    }
    
    return competencyAverages;
  }
  
  /// Check and unlock new achievements
  Future<List<Achievement>> checkAchievements(String userId) async {
    final history = await getProgressHistory(userId);
    final currentAchievements = await getUserAchievements(userId);
    final newAchievements = <Achievement>[];
    
    // Define achievement checks
    final achievementChecks = [
      _checkMilestoneAchievements(history, currentAchievements),
      _checkScoreAchievements(history, currentAchievements),
      _checkConsistencyAchievements(history, currentAchievements),
      _checkImprovementAchievements(history, currentAchievements),
      _checkCompetencyAchievements(history, currentAchievements),
      _checkSpecialAchievements(history, currentAchievements),
    ];
    
    for (final achievements in achievementChecks) {
      newAchievements.addAll(achievements);
    }
    
    // Save new achievements
    if (newAchievements.isNotEmpty) {
      await _saveAchievements(userId, [...currentAchievements, ...newAchievements]);
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
      debugPrint('Error loading achievements: $e');
      return [];
    }
  }
  
  /// Generate performance report
  Future<PerformanceReport> generatePerformanceReport(String userId, DateRange range) async {
    final history = await getProgressHistory(userId);
    final summary = await calculateSummary(userId, range);
    final competencyAnalysis = await analyzeCompetencies(userId);
    final achievements = await getUserAchievements(userId);
    
    // Calculate additional metrics
    final writingFrequency = _calculateWritingFrequency(history, range);
    final consistencyScore = _calculateConsistencyScore(history, range);
    final improvementRate = _calculateImprovementRate(history);
    
    return PerformanceReport(
      summary: summary,
      competencyAnalysis: competencyAnalysis,
      achievements: achievements.where((a) => a.unlockedAt.isAfter(range.start)).toList(),
      writingFrequency: writingFrequency,
      consistencyScore: consistencyScore,
      improvementRate: improvementRate,
      generatedAt: DateTime.now(),
    );
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
    final peerAverage = 650.0 + (userAverage * 0.1); // Slightly adaptive mock
    final percentile = _calculatePercentile(userAverage, peerAverage);
    final ranking = _calculateRanking(percentile);
    
    return ComparisonData(
      userAverage: userAverage,
      peerAverage: peerAverage,
      percentile: percentile,
      ranking: ranking,
    );
  }
  
  // Private helper methods
  
  double _calculateImprovementTrend(List<ProgressPoint> history) {
    if (history.length < 4) return 0.0;
    
    // Compare first quarter with last quarter
    final firstQuarter = history.take(history.length ~/ 4).toList();
    final lastQuarter = history.skip(history.length * 3 ~/ 4).toList();
    
    final firstAvg = firstQuarter.map((p) => p.totalScore).reduce((a, b) => a + b) / firstQuarter.length;
    final lastAvg = lastQuarter.map((p) => p.totalScore).reduce((a, b) => a + b) / lastQuarter.length;
    
    return lastAvg - firstAvg;
  }
  
  CompetencyAnalysis _analyzeCompetencyScores(String competencyName, List<int> scores) {
    final average = scores.reduce((a, b) => a + b) / scores.length;
    final trend = _calculateTrend(scores);
    final consistency = _calculateConsistency(scores);
    
    final strengths = <String>[];
    final weaknesses = <String>[];
    final recommendations = <String>[];
    
    // Analyze performance
    if (average >= 160) {
      strengths.add('Pontuação consistentemente alta');
    } else if (average < 120) {
      weaknesses.add('Pontuação abaixo da média esperada');
      recommendations.add('Foque em melhorar os fundamentos desta competência');
    }
    
    if (consistency > 0.8) {
      strengths.add('Performance consistente');
    } else {
      weaknesses.add('Performance inconsistente');
      recommendations.add('Pratique mais para manter regularidade');
    }
    
    if (trend > 0) {
      strengths.add('Tendência de melhoria');
    } else if (trend < 0) {
      weaknesses.add('Tendência de declínio');
      recommendations.add('Revise conceitos básicos desta competência');
    }
    
    return CompetencyAnalysis(
      competencyName: competencyName,
      averageScore: average,
      trend: trend,
      consistency: consistency,
      strengths: strengths,
      weaknesses: weaknesses,
      recommendations: recommendations,
    );
  }
  
  double _calculateTrend(List<int> scores) {
    if (scores.length < 3) return 0.0;
    
    final firstHalf = scores.take(scores.length ~/ 2).toList();
    final secondHalf = scores.skip(scores.length ~/ 2).toList();
    
    final firstAvg = firstHalf.reduce((a, b) => a + b) / firstHalf.length;
    final secondAvg = secondHalf.reduce((a, b) => a + b) / secondHalf.length;
    
    return secondAvg - firstAvg;
  }
  
  double _calculateConsistency(List<int> scores) {
    if (scores.length < 2) return 1.0;
    
    final average = scores.reduce((a, b) => a + b) / scores.length;
    final variance = scores.map((score) => (score - average) * (score - average)).reduce((a, b) => a + b) / scores.length;
    final standardDeviation = variance > 0 ? variance : 1.0;
    
    // Return consistency score (higher is more consistent)
    return 1.0 / (1.0 + standardDeviation / 100.0);
  }
  
  List<Achievement> _checkMilestoneAchievements(List<ProgressPoint> history, List<Achievement> current) {
    final achievements = <Achievement>[];
    final totalEssays = history.length;
    
    final milestones = [
      (1, 'first_essay', 'Primeira Redação', 'Parabéns por escrever sua primeira redação!'),
      (5, 'essay_5', 'Primeiros Passos', 'Escreveu 5 redações!'),
      (10, 'essay_10', 'Escritor Dedicado', 'Escreveu 10 redações!'),
      (25, 'essay_25', 'Escritor Experiente', 'Escreveu 25 redações!'),
      (50, 'essay_50', 'Mestre da Escrita', 'Escreveu 50 redações!'),
      (100, 'essay_100', 'Centurião', 'Escreveu 100 redações!'),
    ];
    
    for (final milestone in milestones) {
      if (totalEssays >= milestone.$1 && !_hasAchievement(current, milestone.$2)) {
        achievements.add(Achievement(
          id: milestone.$2,
          title: milestone.$3,
          description: milestone.$4,
          iconPath: 'assets/images/achievements/${milestone.$2}.png',
          unlockedAt: DateTime.now(),
          category: AchievementCategory.milestone,
        ));
      }
    }
    
    return achievements;
  }
  
  List<Achievement> _checkScoreAchievements(List<ProgressPoint> history, List<Achievement> current) {
    final achievements = <Achievement>[];
    
    if (history.isEmpty) return achievements;
    
    final maxScore = history.map((p) => p.totalScore).reduce((a, b) => a > b ? a : b);
    
    final scoreThresholds = [
      (600, 'score_600', 'Boa Pontuação', 'Alcançou 600+ pontos!'),
      (700, 'score_700', 'Muito Bom', 'Alcançou 700+ pontos!'),
      (800, 'score_800', 'Excelente', 'Alcançou 800+ pontos!'),
      (900, 'score_900', 'Quase Perfeito', 'Alcançou 900+ pontos!'),
      (1000, 'score_1000', 'Redação Perfeita', 'Pontuação máxima de 1000 pontos!'),
    ];
    
    for (final threshold in scoreThresholds) {
      if (maxScore >= threshold.$1 && !_hasAchievement(current, threshold.$2)) {
        achievements.add(Achievement(
          id: threshold.$2,
          title: threshold.$3,
          description: threshold.$4,
          iconPath: 'assets/images/achievements/${threshold.$2}.png',
          unlockedAt: DateTime.now(),
          category: AchievementCategory.excellence,
        ));
      }
    }
    
    return achievements;
  }
  
  List<Achievement> _checkConsistencyAchievements(List<ProgressPoint> history, List<Achievement> current) {
    final achievements = <Achievement>[];
    
    // Check daily streak
    final dailyStreak = _calculateDailyStreak(history);
    if (dailyStreak >= 3 && !_hasAchievement(current, 'daily_streak_3')) {
      achievements.add(Achievement(
        id: 'daily_streak_3',
        title: 'Escritor Diário',
        description: 'Escreveu por 3 dias consecutivos!',
        iconPath: 'assets/images/achievements/daily_streak.png',
        unlockedAt: DateTime.now(),
        category: AchievementCategory.consistency,
      ));
    }
    
    if (dailyStreak >= 7 && !_hasAchievement(current, 'daily_streak_7')) {
      achievements.add(Achievement(
        id: 'daily_streak_7',
        title: 'Semana Perfeita',
        description: 'Escreveu por 7 dias consecutivos!',
        iconPath: 'assets/images/achievements/weekly_streak.png',
        unlockedAt: DateTime.now(),
        category: AchievementCategory.consistency,
      ));
    }
    
    // Check monthly consistency
    final thisMonth = DateTime.now();
    final monthStart = DateTimeUtils.startOfMonth(thisMonth);
    final monthlyEssays = history.where((p) => p.date.isAfter(monthStart)).length;
    
    if (monthlyEssays >= 10 && !_hasAchievement(current, 'monthly_champion')) {
      achievements.add(Achievement(
        id: 'monthly_champion',
        title: 'Campeão Mensal',
        description: 'Escreveu 10+ redações neste mês!',
        iconPath: 'assets/images/achievements/monthly_champion.png',
        unlockedAt: DateTime.now(),
        category: AchievementCategory.consistency,
      ));
    }
    
    return achievements;
  }
  
  List<Achievement> _checkImprovementAchievements(List<ProgressPoint> history, List<Achievement> current) {
    final achievements = <Achievement>[];
    
    if (history.length < 5) return achievements;
    
    final sortedHistory = history..sort((a, b) => a.date.compareTo(b.date));
    final firstScore = sortedHistory.first.totalScore;
    final bestScore = sortedHistory.map((p) => p.totalScore).reduce((a, b) => a > b ? a : b);
    final improvement = bestScore - firstScore;
    
    if (improvement >= 100 && !_hasAchievement(current, 'improvement_100')) {
      achievements.add(Achievement(
        id: 'improvement_100',
        title: 'Em Evolução',
        description: 'Melhorou 100+ pontos!',
        iconPath: 'assets/images/achievements/improvement.png',
        unlockedAt: DateTime.now(),
        category: AchievementCategory.improvement,
      ));
    }
    
    if (improvement >= 200 && !_hasAchievement(current, 'improvement_200')) {
      achievements.add(Achievement(
        id: 'improvement_200',
        title: 'Grande Evolução',
        description: 'Melhorou 200+ pontos!',
        iconPath: 'assets/images/achievements/big_improvement.png',
        unlockedAt: DateTime.now(),
        category: AchievementCategory.improvement,
      ));
    }
    
    return achievements;
  }
  
  List<Achievement> _checkCompetencyAchievements(List<ProgressPoint> history, List<Achievement> current) {
    final achievements = <Achievement>[];
    
    final competencyNames = {
      'competencia1': ('competency_1_master', 'Mestre da Norma Culta'),
      'competencia2': ('competency_2_master', 'Mestre da Compreensão'),
      'competencia3': ('competency_3_master', 'Mestre da Argumentação'),
      'competencia4': ('competency_4_master', 'Mestre da Coesão'),
      'competencia5': ('competency_5_master', 'Mestre da Proposta'),
    };
    
    for (final entry in competencyNames.entries) {
      final competencyKey = entry.key;
      final achievementId = entry.value.$1;
      final title = entry.value.$2;
      
      final hasMaxScore = history.any((p) => 
          p.competencyScores[competencyKey] != null && 
          p.competencyScores[competencyKey]! >= 200);
      
      if (hasMaxScore && !_hasAchievement(current, achievementId)) {
        achievements.add(Achievement(
          id: achievementId,
          title: title,
          description: 'Alcançou pontuação máxima nesta competência!',
          iconPath: 'assets/images/achievements/$achievementId.png',
          unlockedAt: DateTime.now(),
          category: AchievementCategory.competency,
        ));
      }
    }
    
    return achievements;
  }
  
  List<Achievement> _checkSpecialAchievements(List<ProgressPoint> history, List<Achievement> current) {
    final achievements = <Achievement>[];
    
    // Night owl achievement
    final hasNightEssay = history.any((p) => p.date.hour >= 22);
    if (hasNightEssay && !_hasAchievement(current, 'night_owl')) {
      achievements.add(Achievement(
        id: 'night_owl',
        title: 'Coruja da Madrugada',
        description: 'Escreveu uma redação após 22h!',
        iconPath: 'assets/images/achievements/night_owl.png',
        unlockedAt: DateTime.now(),
        category: AchievementCategory.dedication,
      ));
    }
    
    // Early bird achievement
    final hasEarlyEssay = history.any((p) => p.date.hour < 6);
    if (hasEarlyEssay && !_hasAchievement(current, 'early_bird')) {
      achievements.add(Achievement(
        id: 'early_bird',
        title: 'Madrugador',
        description: 'Escreveu uma redação antes das 6h!',
        iconPath: 'assets/images/achievements/early_bird.png',
        unlockedAt: DateTime.now(),
        category: AchievementCategory.dedication,
      ));
    }
    
    return achievements;
  }
  
  int _calculateDailyStreak(List<ProgressPoint> history) {
    if (history.isEmpty) return 0;
    
    final sortedHistory = history..sort((a, b) => b.date.compareTo(a.date));
    final today = DateTime.now();
    int streak = 0;
    
    for (int i = 0; i < sortedHistory.length; i++) {
      final expectedDate = today.subtract(Duration(days: i));
      final hasEssayOnDate = sortedHistory.any((p) => 
          DateTimeUtils.isSameDay(p.date, expectedDate));
      
      if (hasEssayOnDate) {
        streak++;
      } else {
        break;
      }
    }
    
    return streak;
  }
  
  double _calculateWritingFrequency(List<ProgressPoint> history, DateRange range) {
    final filteredHistory = history.where((p) => 
        p.date.isAfter(range.start) && p.date.isBefore(range.end)).toList();
    
    final daysDiff = range.end.difference(range.start).inDays;
    return daysDiff > 0 ? filteredHistory.length / daysDiff : 0.0;
  }
  
  double _calculateConsistencyScore(List<ProgressPoint> history, DateRange range) {
    final filteredHistory = history.where((p) => 
        p.date.isAfter(range.start) && p.date.isBefore(range.end)).toList();
    
    if (filteredHistory.length < 2) return 0.0;
    
    final scores = filteredHistory.map((p) => p.totalScore).toList();
    return _calculateConsistency(scores);
  }
  
  double _calculateImprovementRate(List<ProgressPoint> history) {
    if (history.length < 10) return 0.0;
    
    final sortedHistory = history..sort((a, b) => a.date.compareTo(b.date));
    final firstTen = sortedHistory.take(10).toList();
    final lastTen = sortedHistory.skip(sortedHistory.length - 10).toList();
    
    final firstAvg = firstTen.map((p) => p.totalScore).reduce((a, b) => a + b) / 10;
    final lastAvg = lastTen.map((p) => p.totalScore).reduce((a, b) => a + b) / 10;
    
    final daysDiff = lastTen.last.date.difference(firstTen.first.date).inDays;
    return daysDiff > 0 ? (lastAvg - firstAvg) / daysDiff : 0.0;
  }
  
  bool _hasAchievement(List<Achievement> achievements, String achievementId) {
    return achievements.any((a) => a.id == achievementId);
  }
  
  double _calculatePercentile(double userScore, double peerAverage) {
    // Simplified percentile calculation
    final ratio = userScore / peerAverage;
    if (ratio >= 1.3) return 95.0;
    if (ratio >= 1.2) return 90.0;
    if (ratio >= 1.1) return 80.0;
    if (ratio >= 1.0) return 70.0;
    if (ratio >= 0.9) return 60.0;
    if (ratio >= 0.8) return 50.0;
    return 40.0;
  }
  
  String _calculateRanking(double percentile) {
    if (percentile >= 90) return 'Excelente';
    if (percentile >= 80) return 'Muito Bom';
    if (percentile >= 70) return 'Bom';
    if (percentile >= 60) return 'Regular';
    return 'Precisa Melhorar';
  }
  
  Future<void> _updateStatistics(String userId, List<ProgressPoint> history) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final statistics = {
        'totalEssays': history.length,
        'averageScore': history.isNotEmpty 
            ? history.map((p) => p.totalScore).reduce((a, b) => a + b) / history.length
            : 0.0,
        'lastUpdated': DateTime.now().toIso8601String(),
      };
      
      await prefs.setString('${_statisticsKey}_$userId', json.encode(statistics));
    } catch (e) {
      debugPrint('Error updating statistics: $e');
    }
  }
  
  Future<void> _saveAchievements(String userId, List<Achievement> achievements) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = achievements.map((a) => a.toJson()).toList();
      await prefs.setString('${_achievementsKey}_$userId', json.encode(jsonList));
    } catch (e) {
      debugPrint('Error saving achievements: $e');
    }
  }
}

/// Data point for charts
class ChartDataPoint {
  final DateTime date;
  final double value;
  final int count;

  ChartDataPoint({
    required this.date,
    required this.value,
    required this.count,
  });
}

/// Competency analysis result
class CompetencyAnalysis {
  final String competencyName;
  final double averageScore;
  final double trend;
  final double consistency;
  final List<String> strengths;
  final List<String> weaknesses;
  final List<String> recommendations;

  CompetencyAnalysis({
    required this.competencyName,
    required this.averageScore,
    required this.trend,
    required this.consistency,
    required this.strengths,
    required this.weaknesses,
    required this.recommendations,
  });
}

/// Comprehensive performance report
class PerformanceReport {
  final ProgressSummary summary;
  final Map<String, CompetencyAnalysis> competencyAnalysis;
  final List<Achievement> achievements;
  final double writingFrequency;
  final double consistencyScore;
  final double improvementRate;
  final DateTime generatedAt;

  PerformanceReport({
    required this.summary,
    required this.competencyAnalysis,
    required this.achievements,
    required this.writingFrequency,
    required this.consistencyScore,
    required this.improvementRate,
    required this.generatedAt,
  });
}