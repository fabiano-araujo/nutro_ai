import 'essay_progress.dart';

/// Summary of user progress over a specific period
class ProgressSummary {
  final int totalEssays;
  final double averageScore;
  final Map<String, double> competencyAverages;
  final double improvementTrend;
  final DateRange dateRange;
  final int bestScore;
  final int worstScore;

  ProgressSummary({
    required this.totalEssays,
    required this.averageScore,
    required this.competencyAverages,
    required this.improvementTrend,
    required this.dateRange,
    required this.bestScore,
    required this.worstScore,
  });

  factory ProgressSummary.empty() {
    return ProgressSummary(
      totalEssays: 0,
      averageScore: 0.0,
      competencyAverages: {},
      improvementTrend: 0.0,
      dateRange: DateRange(start: DateTime.now(), end: DateTime.now()),
      bestScore: 0,
      worstScore: 0,
    );
  }

  /// Get improvement percentage
  double get improvementPercentage {
    if (averageScore == 0) return 0.0;
    return (improvementTrend / averageScore) * 100;
  }

  /// Check if user is improving
  bool get isImproving => improvementTrend > 0;

  /// Get the weakest competency
  String? get weakestCompetency {
    if (competencyAverages.isEmpty) return null;
    
    String? weakest;
    double lowestScore = double.infinity;
    
    competencyAverages.forEach((competency, score) {
      if (score < lowestScore) {
        lowestScore = score;
        weakest = competency;
      }
    });
    
    return weakest;
  }

  /// Get the strongest competency
  String? get strongestCompetency {
    if (competencyAverages.isEmpty) return null;
    
    String? strongest;
    double highestScore = 0.0;
    
    competencyAverages.forEach((competency, score) {
      if (score > highestScore) {
        highestScore = score;
        strongest = competency;
      }
    });
    
    return strongest;
  }
}