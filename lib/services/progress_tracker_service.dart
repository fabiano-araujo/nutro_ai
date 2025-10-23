import 'package:flutter/foundation.dart';
import '../models/essay_model.dart';
import '../models/essay_progress_model.dart';
import '../services/storage_service.dart';

/// Serviço para rastrear e analisar o progresso do usuário
class ProgressTrackerService {
  static const String _progressKey = 'essay_progress';
  final StorageService _storageService = StorageService();

  /// Obtém o histórico de progresso do usuário
  Future<List<ProgressPoint>> getProgressHistory(String userId) async {
    try {
      final progressData = await _storageService.getData(_progressKey);
      if (progressData != null) {
        final progress = EssayProgress.fromJson(progressData);
        return progress.progressHistory;
      }
      return [];
    } catch (e) {
      debugPrint('Erro ao obter histórico de progresso: $e');
      return [];
    }
  }

  /// Adiciona um novo ponto de progresso
  Future<void> addProgressPoint(Essay essay) async {
    if (essay.status != 'Corrigido' || essay.competenceScores == null) {
      return;
    }

    try {
      final currentProgress = await _getCurrentProgress(essay.id);
      final newPoint = ProgressPoint(
        date: DateTime.now(),
        totalScore: essay.score,
        competencyScores: essay.competenceScores!,
        essayId: essay.id,
        essayType: essay.type,
      );

      currentProgress.progressHistory.add(newPoint);
      
      // Manter apenas os últimos 50 pontos para performance
      if (currentProgress.progressHistory.length > 50) {
        currentProgress.progressHistory.removeAt(0);
      }

      await _saveProgress(currentProgress);
    } catch (e) {
      debugPrint('Erro ao adicionar ponto de progresso: $e');
    }
  }

  /// Calcula resumo do progresso para um período específico
  Future<ProgressSummary> calculateSummary(String userId, {DateRange? range}) async {
    try {
      final progress = await _getCurrentProgress(userId);
      final history = range != null 
          ? _filterByDateRange(progress.progressHistory, range)
          : progress.progressHistory;

      if (history.isEmpty) {
        return _createEmptySummary();
      }

      final totalEssays = history.length;
      final averageScore = history.fold(0.0, (sum, point) => sum + point.totalScore) / totalEssays;
      
      // Calcular melhoria geral (comparar primeiros 25% com últimos 25%)
      final improvement = _calculateOverallImprovement(history);
      
      // Encontrar competência mais forte e mais fraca
      final competencyAnalysis = _analyzeCompetencies(history);
      
      // Contar redações por período
      final now = DateTime.now();
      final thisWeek = history.where((p) => 
          p.date.isAfter(now.subtract(const Duration(days: 7)))).length;
      final thisMonth = history.where((p) => 
          p.date.isAfter(now.subtract(const Duration(days: 30)))).length;

      return ProgressSummary(
        totalEssays: totalEssays,
        averageScore: averageScore,
        overallImprovement: improvement,
        strongestCompetency: competencyAnalysis['strongest'] ?? 'N/A',
        weakestCompetency: competencyAnalysis['weakest'] ?? 'N/A',
        essaysThisWeek: thisWeek,
        essaysThisMonth: thisMonth,
        firstEssayDate: history.first.date,
        lastEssayDate: history.last.date,
      );
    } catch (e) {
      debugPrint('Erro ao calcular resumo: $e');
      return _createEmptySummary();
    }
  }

  /// Analisa progresso por competência
  Future<Map<String, CompetencyProgress>> analyzeCompetencyProgress(String userId) async {
    try {
      final progress = await _getCurrentProgress(userId);
      final competencyMap = <String, CompetencyProgress>{};

      // Obter todas as competências únicas
      final competencies = <String>{};
      for (final point in progress.progressHistory) {
        competencies.addAll(point.competencyScores.keys);
      }

      for (final competency in competencies) {
        final scores = progress.progressHistory
            .where((p) => p.competencyScores.containsKey(competency))
            .map((p) => p.competencyScores[competency]!)
            .toList();

        if (scores.isNotEmpty) {
          final average = scores.fold(0.0, (sum, score) => sum + score) / scores.length;
          final improvement = _calculateCompetencyImprovement(scores);
          final trend = _determineTrend(scores);
          final analysis = _analyzeCompetencyStrengthsWeaknesses(competency, scores);

          competencyMap[competency] = CompetencyProgress(
            competencyName: competency,
            scores: scores,
            averageScore: average,
            improvement: improvement,
            trend: trend,
            strengths: analysis['strengths'] ?? [],
            weaknesses: analysis['weaknesses'] ?? [],
          );
        }
      }

      return competencyMap;
    } catch (e) {
      debugPrint('Erro ao analisar progresso por competência: $e');
      return {};
    }
  }

  /// Verifica e desbloqueia conquistas
  Future<List<Achievement>> checkAchievements(String userId) async {
    try {
      final progress = await _getCurrentProgress(userId);
      final newAchievements = <Achievement>[];

      // Verificar conquistas gerais
      _checkGeneralAchievements(progress, newAchievements);
      
      // Verificar conquistas de pontuação
      _checkScoreAchievements(progress, newAchievements);
      
      // Verificar conquistas de frequência
      _checkFrequencyAchievements(progress, newAchievements);
      
      // Verificar conquistas de melhoria
      _checkImprovementAchievements(progress, newAchievements);
      
      // Verificar conquistas de competência
      _checkCompetencyAchievements(progress, newAchievements);
      
      // Verificar conquistas especiais
      _checkSpecialAchievements(progress, newAchievements);

      // Salvar novas conquistas
      if (newAchievements.isNotEmpty) {
        progress.achievements.addAll(newAchievements.map((a) => 
            a.copyWith(unlockedAt: DateTime.now(), isUnlocked: true)));
        await _saveProgress(progress);
      }

      return newAchievements;
    } catch (e) {
      debugPrint('Erro ao verificar conquistas: $e');
      return [];
    }
  }

  void _checkGeneralAchievements(EssayProgress progress, List<Achievement> newAchievements) {
    final totalEssays = progress.progressHistory.length;

    // Primeira redação
    if (totalEssays >= 1 && !_hasAchievement(progress.achievements, 'first_essay')) {
      newAchievements.add(PredefinedAchievements.firstEssay);
    }

    // 10 redações
    if (totalEssays >= 10 && !_hasAchievement(progress.achievements, 'essay_10')) {
      newAchievements.add(PredefinedAchievements.essay10);
    }

    // 25 redações
    if (totalEssays >= 25 && !_hasAchievement(progress.achievements, 'essay_25')) {
      newAchievements.add(PredefinedAchievements.essay25);
    }

    // 50 redações
    if (totalEssays >= 50 && !_hasAchievement(progress.achievements, 'essay_50')) {
      newAchievements.add(PredefinedAchievements.essay50);
    }
  }

  void _checkScoreAchievements(EssayProgress progress, List<Achievement> newAchievements) {
    final scores = progress.progressHistory.map((p) => p.totalScore).toList();
    final maxScore = scores.isNotEmpty ? scores.reduce((a, b) => a > b ? a : b) : 0;

    // 600+ pontos
    if (maxScore >= 600 && !_hasAchievement(progress.achievements, 'score_600_plus')) {
      newAchievements.add(PredefinedAchievements.score600Plus);
    }

    // 800+ pontos
    if (maxScore >= 800 && !_hasAchievement(progress.achievements, 'score_800_plus')) {
      newAchievements.add(PredefinedAchievements.score800Plus);
    }

    // 900+ pontos
    if (maxScore >= 900 && !_hasAchievement(progress.achievements, 'score_900_plus')) {
      newAchievements.add(PredefinedAchievements.score900Plus);
    }

    // Pontuação perfeita
    if (maxScore >= 1000 && !_hasAchievement(progress.achievements, 'perfect_score')) {
      newAchievements.add(PredefinedAchievements.perfectScore);
    }
  }

  void _checkFrequencyAchievements(EssayProgress progress, List<Achievement> newAchievements) {
    // Escritor diário (3 dias consecutivos)
    if (_hasDailyStreak(progress.progressHistory, 3) && 
        !_hasAchievement(progress.achievements, 'daily_writer')) {
      newAchievements.add(PredefinedAchievements.dailyWriter);
    }

    // Sequência semanal
    if (_hasWeeklyStreak(progress.progressHistory) && 
        !_hasAchievement(progress.achievements, 'weekly_streak')) {
      newAchievements.add(PredefinedAchievements.weeklyStreak);
    }

    // Campeão mensal
    if (_hasMonthlyChampion(progress.progressHistory) && 
        !_hasAchievement(progress.achievements, 'monthly_champion')) {
      newAchievements.add(PredefinedAchievements.monthlyChampion);
    }

    // Escritor veloz (3 redações em um dia)
    if (_hasSpeedWriter(progress.progressHistory) && 
        !_hasAchievement(progress.achievements, 'speed_writer')) {
      newAchievements.add(PredefinedAchievements.speedWriter);
    }
  }

  void _checkImprovementAchievements(EssayProgress progress, List<Achievement> newAchievements) {
    if (progress.progressHistory.length < 2) return;

    final scores = progress.progressHistory.map((p) => p.totalScore).toList();
    final firstScore = scores.first;
    final maxScore = scores.reduce((a, b) => a > b ? a : b);
    final improvement = maxScore - firstScore;

    // Melhoria de 100 pontos
    if (improvement >= 100 && !_hasAchievement(progress.achievements, 'improver')) {
      newAchievements.add(PredefinedAchievements.improver);
    }

    // Melhoria de 200 pontos
    if (improvement >= 200 && !_hasAchievement(progress.achievements, 'big_improver')) {
      newAchievements.add(PredefinedAchievements.bigImprover);
    }
  }

  void _checkCompetencyAchievements(EssayProgress progress, List<Achievement> newAchievements) {
    final competencyMastery = <String, bool>{};

    for (final point in progress.progressHistory) {
      for (final entry in point.competencyScores.entries) {
        if (entry.value >= 200) {
          competencyMastery[entry.key] = true;
        }
      }
    }

    // Verificar maestria individual
    if (competencyMastery['Competência 1'] == true && 
        !_hasAchievement(progress.achievements, 'competency_1_master')) {
      newAchievements.add(PredefinedAchievements.competency1Master);
    }

    if (competencyMastery['Competência 2'] == true && 
        !_hasAchievement(progress.achievements, 'competency_2_master')) {
      newAchievements.add(PredefinedAchievements.competency2Master);
    }

    if (competencyMastery['Competência 3'] == true && 
        !_hasAchievement(progress.achievements, 'competency_3_master')) {
      newAchievements.add(PredefinedAchievements.competency3Master);
    }

    if (competencyMastery['Competência 4'] == true && 
        !_hasAchievement(progress.achievements, 'competency_4_master')) {
      newAchievements.add(PredefinedAchievements.competency4Master);
    }

    if (competencyMastery['Competência 5'] == true && 
        !_hasAchievement(progress.achievements, 'competency_5_master')) {
      newAchievements.add(PredefinedAchievements.competency5Master);
    }

    // Verificar maestria completa
    final allCompetenciesMastered = competencyMastery.length >= 5 && 
        competencyMastery.values.every((mastered) => mastered);
    
    if (allCompetenciesMastered && 
        !_hasAchievement(progress.achievements, 'all_competencies_master')) {
      newAchievements.add(PredefinedAchievements.allCompetenciesMaster);
    }
  }

  void _checkSpecialAchievements(EssayProgress progress, List<Achievement> newAchievements) {
    for (final point in progress.progressHistory) {
      final hour = point.date.hour;

      // Coruja da madrugada (após 22h)
      if (hour >= 22 && !_hasAchievement(progress.achievements, 'night_owl')) {
        newAchievements.add(PredefinedAchievements.nightOwl);
      }

      // Madrugador (antes das 6h)
      if (hour < 6 && !_hasAchievement(progress.achievements, 'early_bird')) {
        newAchievements.add(PredefinedAchievements.earlyBird);
      }
    }
  }

  /// Obtém dados de comparação com outros usuários (simulado)
  Future<ComparisonData> compareWithPeers(String userId) async {
    try {
      final summary = await calculateSummary(userId);
      
      // Simular dados de comparação (em produção viria do backend)
      return ComparisonData(
        userAverageScore: summary.averageScore,
        peerAverageScore: 720.0, // Média simulada
        userRanking: 15, // Posição simulada
        totalUsers: 100, // Total simulado
        percentile: 85.0, // Percentil simulado
      );
    } catch (e) {
      debugPrint('Erro ao comparar com pares: $e');
      return ComparisonData(
        userAverageScore: 0.0,
        peerAverageScore: 0.0,
        userRanking: 0,
        totalUsers: 0,
        percentile: 0.0,
      );
    }
  }

  // Métodos auxiliares privados

  Future<EssayProgress> _getCurrentProgress(String userId) async {
    try {
      final progressData = await _storageService.getData(_progressKey);
      if (progressData != null) {
        return EssayProgress.fromJson(progressData);
      }
    } catch (e) {
      debugPrint('Erro ao obter progresso atual: $e');
    }

    // Retornar progresso vazio se não existir
    return EssayProgress(
      userId: userId,
      progressHistory: [],
      competencyProgress: {},
      achievements: [],
      summary: _createEmptySummary(),
      lastUpdated: DateTime.now(),
    );
  }

  Future<void> _saveProgress(EssayProgress progress) async {
    try {
      final updatedProgress = EssayProgress(
        userId: progress.userId,
        progressHistory: progress.progressHistory,
        competencyProgress: progress.competencyProgress,
        achievements: progress.achievements,
        summary: progress.summary,
        lastUpdated: DateTime.now(),
      );
      
      await _storageService.saveData(_progressKey, updatedProgress.toJson());
    } catch (e) {
      debugPrint('Erro ao salvar progresso: $e');
    }
  }

  List<ProgressPoint> _filterByDateRange(List<ProgressPoint> history, DateRange range) {
    return history.where((point) => 
        point.date.isAfter(range.start) && point.date.isBefore(range.end)).toList();
  }

  double _calculateOverallImprovement(List<ProgressPoint> history) {
    if (history.length < 4) return 0.0;

    final firstQuarter = history.take(history.length ~/ 4).toList();
    final lastQuarter = history.skip(history.length * 3 ~/ 4).toList();

    final firstAvg = firstQuarter.fold(0.0, (sum, p) => sum + p.totalScore) / firstQuarter.length;
    final lastAvg = lastQuarter.fold(0.0, (sum, p) => sum + p.totalScore) / lastQuarter.length;

    return lastAvg - firstAvg;
  }

  Map<String, String> _analyzeCompetencies(List<ProgressPoint> history) {
    final competencyAverages = <String, double>{};

    for (final point in history) {
      for (final entry in point.competencyScores.entries) {
        competencyAverages[entry.key] = 
            (competencyAverages[entry.key] ?? 0.0) + entry.value;
      }
    }

    // Calcular médias
    competencyAverages.updateAll((key, value) => value / history.length);

    final sorted = competencyAverages.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return {
      'strongest': sorted.isNotEmpty ? sorted.first.key : 'N/A',
      'weakest': sorted.isNotEmpty ? sorted.last.key : 'N/A',
    };
  }

  double _calculateCompetencyImprovement(List<int> scores) {
    if (scores.length < 2) return 0.0;
    
    final firstHalf = scores.take(scores.length ~/ 2).toList();
    final secondHalf = scores.skip(scores.length ~/ 2).toList();

    final firstAvg = firstHalf.fold(0.0, (sum, score) => sum + score) / firstHalf.length;
    final secondAvg = secondHalf.fold(0.0, (sum, score) => sum + score) / secondHalf.length;

    return secondAvg - firstAvg;
  }

  String _determineTrend(List<int> scores) {
    if (scores.length < 3) return 'stable';

    final recent = scores.skip(scores.length - 3).toList();
    final improvement = recent.last - recent.first;

    if (improvement > 10) return 'improving';
    if (improvement < -10) return 'declining';
    return 'stable';
  }

  Map<String, List<String>> _analyzeCompetencyStrengthsWeaknesses(String competency, List<int> scores) {
    final average = scores.fold(0.0, (sum, score) => sum + score) / scores.length;
    
    final strengths = <String>[];
    final weaknesses = <String>[];

    if (average >= 160) {
      strengths.add('Pontuação consistentemente alta');
    }
    if (scores.any((s) => s >= 180)) {
      strengths.add('Já alcançou pontuação excelente');
    }
    if (average < 120) {
      weaknesses.add('Pontuação abaixo da média');
    }
    if (scores.where((s) => s < 100).length > scores.length * 0.3) {
      weaknesses.add('Inconsistência na performance');
    }

    return {'strengths': strengths, 'weaknesses': weaknesses};
  }

  bool _hasAchievement(List<Achievement> achievements, String achievementId) {
    return achievements.any((a) => a.id == achievementId && a.isUnlocked);
  }

  bool _hasDailyStreak(List<ProgressPoint> history, int days) {
    if (history.length < days) return false;

    final recent = history.skip(history.length - days).toList();
    final dates = recent.map((p) => p.date).toList()..sort();

    for (int i = 1; i < dates.length; i++) {
      if (dates[i].difference(dates[i-1]).inDays > 1) {
        return false;
      }
    }
    return true;
  }

  bool _hasWeeklyStreak(List<ProgressPoint> history) {
    if (history.length < 7) return false;

    final recent = history.skip(history.length - 7).toList();
    final dates = recent.map((p) => p.date).toList()..sort();

    for (int i = 1; i < dates.length; i++) {
      if (dates[i].difference(dates[i-1]).inDays > 1) {
        return false;
      }
    }
    return true;
  }

  bool _hasMonthlyChampion(List<ProgressPoint> history) {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final essaysThisMonth = history.where((p) => p.date.isAfter(startOfMonth)).length;
    return essaysThisMonth >= 10;
  }

  bool _hasSpeedWriter(List<ProgressPoint> history) {
    final dailyCounts = <String, int>{};
    
    for (final point in history) {
      final dateKey = '${point.date.year}-${point.date.month}-${point.date.day}';
      dailyCounts[dateKey] = (dailyCounts[dateKey] ?? 0) + 1;
    }
    
    return dailyCounts.values.any((count) => count >= 3);
  }

  bool _hasMasteredCompetency5(List<ProgressPoint> history) {
    return history.any((p) => 
        p.competencyScores.containsKey('Competência 5') && 
        p.competencyScores['Competência 5']! >= 200);
  }

  ProgressSummary _createEmptySummary() {
    final now = DateTime.now();
    return ProgressSummary(
      totalEssays: 0,
      averageScore: 0.0,
      overallImprovement: 0.0,
      strongestCompetency: 'N/A',
      weakestCompetency: 'N/A',
      essaysThisWeek: 0,
      essaysThisMonth: 0,
      firstEssayDate: now,
      lastEssayDate: now,
    );
  }
}

/// Classe para definir período de tempo
class DateRange {
  final DateTime start;
  final DateTime end;

  DateRange({required this.start, required this.end});
}

/// Dados de comparação com outros usuários
class ComparisonData {
  final double userAverageScore;
  final double peerAverageScore;
  final int userRanking;
  final int totalUsers;
  final double percentile;

  ComparisonData({
    required this.userAverageScore,
    required this.peerAverageScore,
    required this.userRanking,
    required this.totalUsers,
    required this.percentile,
  });
}

/// Extensão para Achievement com copyWith
extension AchievementExtension on Achievement {
  Achievement copyWith({
    String? id,
    String? name,
    String? description,
    String? iconName,
    AchievementType? type,
    DateTime? unlockedAt,
    bool? isUnlocked,
    Map<String, dynamic>? metadata,
  }) {
    return Achievement(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      iconName: iconName ?? this.iconName,
      type: type ?? this.type,
      unlockedAt: unlockedAt ?? this.unlockedAt,
      isUnlocked: isUnlocked ?? this.isUnlocked,
      metadata: metadata ?? this.metadata,
    );
  }
}