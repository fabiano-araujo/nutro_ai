import 'package:flutter/foundation.dart';
import '../models/essay_progress.dart';
import '../models/progress_summary.dart';
import '../models/achievement.dart';
import '../services/enhanced_progress_tracker.dart';

/// Provider for managing progress tracking state
class ProgressProvider with ChangeNotifier {
  final EnhancedProgressTracker _progressTracker = EnhancedProgressTracker();
  
  List<ProgressPoint> _progressHistory = [];
  List<Achievement> _achievements = [];
  ProgressSummary? _currentSummary;
  Map<String, CompetencyAnalysis> _competencyAnalysis = {};
  PerformanceReport? _performanceReport;
  ComparisonData? _comparisonData;
  
  bool _isLoading = false;
  String? _error;

  // Getters
  List<ProgressPoint> get progressHistory => _progressHistory;
  List<Achievement> get achievements => _achievements;
  ProgressSummary? get currentSummary => _currentSummary;
  Map<String, CompetencyAnalysis> get competencyAnalysis => _competencyAnalysis;
  PerformanceReport? get performanceReport => _performanceReport;
  ComparisonData? get comparisonData => _comparisonData;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Load progress data for a user
  Future<void> loadProgressData(String userId) async {
    _setLoading(true);
    _clearError();

    try {
      // Load progress history
      _progressHistory = await _progressTracker.getProgressHistory(userId);
      
      // Load achievements
      _achievements = await _progressTracker.getUserAchievements(userId);
      
      // Calculate current summary (last 30 days)
      final range = DateRange.lastMonth();
      _currentSummary = await _progressTracker.calculateSummary(userId, range);
      
      // Analyze competencies
      _competencyAnalysis = await _progressTracker.analyzeCompetencies(userId);
      
      // Load comparison data
      _comparisonData = await _progressTracker.compareWithPeers(userId);
      
      notifyListeners();
    } catch (e) {
      _setError('Erro ao carregar dados de progresso: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Add a new progress point
  Future<void> addProgressPoint(String userId, ProgressPoint point) async {
    try {
      await _progressTracker.saveProgressPoint(userId, point);
      
      // Check for new achievements
      final newAchievements = await _progressTracker.checkAchievements(userId);
      
      // Reload data to reflect changes
      await loadProgressData(userId);
      
      // Notify about new achievements
      if (newAchievements.isNotEmpty) {
        _notifyNewAchievements(newAchievements);
      }
    } catch (e) {
      _setError('Erro ao salvar progresso: $e');
    }
  }

  /// Generate comprehensive performance report
  Future<void> generatePerformanceReport(String userId, DateRange range) async {
    _setLoading(true);
    _clearError();

    try {
      _performanceReport = await _progressTracker.generatePerformanceReport(userId, range);
      notifyListeners();
    } catch (e) {
      _setError('Erro ao gerar relatório: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Get temporal chart data
  Future<List<ChartDataPoint>> getTemporalChartData(String userId, DateRange range) async {
    try {
      return await _progressTracker.generateTemporalChartData(userId, range);
    } catch (e) {
      _setError('Erro ao gerar dados do gráfico: $e');
      return [];
    }
  }

  /// Get radar chart data
  Future<Map<String, double>> getRadarChartData(String userId) async {
    try {
      return await _progressTracker.generateRadarChartData(userId);
    } catch (e) {
      _setError('Erro ao gerar dados do radar: $e');
      return {};
    }
  }

  /// Get progress summary for different time ranges
  Future<ProgressSummary> getSummaryForRange(String userId, DateRange range) async {
    try {
      return await _progressTracker.calculateSummary(userId, range);
    } catch (e) {
      _setError('Erro ao calcular resumo: $e');
      return ProgressSummary.empty();
    }
  }

  /// Get achievements by category
  List<Achievement> getAchievementsByCategory(AchievementCategory category) {
    return _achievements.where((a) => a.category == category).toList();
  }

  /// Get recent achievements (last 7 days)
  List<Achievement> getRecentAchievements() {
    final weekAgo = DateTime.now().subtract(const Duration(days: 7));
    return _achievements.where((a) => a.unlockedAt.isAfter(weekAgo)).toList();
  }

  /// Get unlocked achievements count
  int get unlockedAchievementsCount => _achievements.length;

  /// Get total essays count
  int get totalEssaysCount => _progressHistory.length;

  /// Get average score
  double get averageScore {
    if (_progressHistory.isEmpty) return 0.0;
    return _progressHistory.map((p) => p.totalScore).reduce((a, b) => a + b) / _progressHistory.length;
  }

  /// Get best score
  int get bestScore {
    if (_progressHistory.isEmpty) return 0;
    return _progressHistory.map((p) => p.totalScore).reduce((a, b) => a > b ? a : b);
  }

  /// Get improvement trend
  double get improvementTrend {
    if (_progressHistory.length < 4) return 0.0;
    
    final sortedHistory = List<ProgressPoint>.from(_progressHistory)
      ..sort((a, b) => a.date.compareTo(b.date));
    
    final firstQuarter = sortedHistory.take(sortedHistory.length ~/ 4).toList();
    final lastQuarter = sortedHistory.skip(sortedHistory.length * 3 ~/ 4).toList();
    
    final firstAvg = firstQuarter.map((p) => p.totalScore).reduce((a, b) => a + b) / firstQuarter.length;
    final lastAvg = lastQuarter.map((p) => p.totalScore).reduce((a, b) => a + b) / lastQuarter.length;
    
    return lastAvg - firstAvg;
  }

  /// Get writing frequency (essays per day in last 30 days)
  double get writingFrequency {
    final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
    final recentEssays = _progressHistory.where((p) => p.date.isAfter(thirtyDaysAgo)).length;
    return recentEssays / 30.0;
  }

  /// Get consistency score
  double get consistencyScore {
    if (_progressHistory.length < 3) return 0.0;
    
    final scores = _progressHistory.map((p) => p.totalScore).toList();
    final average = scores.reduce((a, b) => a + b) / scores.length;
    final variance = scores.map((score) => (score - average) * (score - average)).reduce((a, b) => a + b) / scores.length;
    
    // Return consistency score (higher is more consistent)
    return 1.0 / (1.0 + variance / 10000.0);
  }

  /// Get strongest competency
  String? get strongestCompetency {
    if (_competencyAnalysis.isEmpty) return null;
    
    final strongest = _competencyAnalysis.entries
        .reduce((a, b) => a.value.averageScore > b.value.averageScore ? a : b);
    
    return strongest.value.competencyName;
  }

  /// Get weakest competency
  String? get weakestCompetency {
    if (_competencyAnalysis.isEmpty) return null;
    
    final weakest = _competencyAnalysis.entries
        .reduce((a, b) => a.value.averageScore < b.value.averageScore ? a : b);
    
    return weakest.value.competencyName;
  }

  /// Check if user has specific achievement
  bool hasAchievement(String achievementId) {
    return _achievements.any((a) => a.id == achievementId);
  }

  /// Get achievement progress for achievements with progress tracking
  double getAchievementProgress(String achievementId) {
    final achievement = _achievements.firstWhere(
      (a) => a.id == achievementId,
      orElse: () => Achievement(
        id: achievementId,
        title: '',
        description: '',
        iconPath: '',
        unlockedAt: DateTime.now(),
        category: AchievementCategory.milestone,
      ),
    );
    
    return achievement.progressPercentage;
  }

  /// Refresh all data
  Future<void> refresh(String userId) async {
    await loadProgressData(userId);
  }

  /// Clear all data
  void clearData() {
    _progressHistory.clear();
    _achievements.clear();
    _currentSummary = null;
    _competencyAnalysis.clear();
    _performanceReport = null;
    _comparisonData = null;
    _clearError();
    notifyListeners();
  }

  // Private methods
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _error = error;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
  }

  void _notifyNewAchievements(List<Achievement> newAchievements) {
    // This could trigger a callback or event for showing achievement notifications
    debugPrint('New achievements unlocked: ${newAchievements.map((a) => a.title).join(', ')}');
  }
}

/// Extension to add convenience methods to DateRange
extension DateRangeExtension on DateRange {
  /// Create a date range for the last 30 days
  static DateRange lastMonth() {
    final now = DateTime.now();
    return DateRange(
      start: now.subtract(const Duration(days: 30)),
      end: now,
    );
  }

  /// Create a date range for the last 7 days
  static DateRange lastWeek() {
    final now = DateTime.now();
    return DateRange(
      start: now.subtract(const Duration(days: 7)),
      end: now,
    );
  }

  /// Create a date range for the last 90 days
  static DateRange lastQuarter() {
    final now = DateTime.now();
    return DateRange(
      start: now.subtract(const Duration(days: 90)),
      end: now,
    );
  }

  /// Create a date range for the current year
  static DateRange currentYear() {
    final now = DateTime.now();
    return DateRange(
      start: DateTime(now.year, 1, 1),
      end: now,
    );
  }
}