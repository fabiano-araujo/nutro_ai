/// Represents a single progress point in time
class ProgressPoint {
  final String essayId;
  final DateTime date;
  final int totalScore;
  final Map<String, int> competencyScores;
  final String essayType;
  final String? theme;

  ProgressPoint({
    required this.essayId,
    required this.date,
    required this.totalScore,
    required this.competencyScores,
    required this.essayType,
    this.theme,
  });

  factory ProgressPoint.fromJson(Map<String, dynamic> json) {
    return ProgressPoint(
      essayId: json['essayId'] as String,
      date: DateTime.parse(json['date'] as String),
      totalScore: json['totalScore'] as int,
      competencyScores: Map<String, int>.from(json['competencyScores'] as Map),
      essayType: json['essayType'] as String,
      theme: json['theme'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'essayId': essayId,
      'date': date.toIso8601String(),
      'totalScore': totalScore,
      'competencyScores': competencyScores,
      'essayType': essayType,
      'theme': theme,
    };
  }
}

/// Represents a date range for filtering progress data
class DateRange {
  final DateTime start;
  final DateTime end;

  DateRange({
    required this.start,
    required this.end,
  });

  /// Create a date range for the last 30 days
  factory DateRange.lastMonth() {
    final now = DateTime.now();
    return DateRange(
      start: now.subtract(const Duration(days: 30)),
      end: now,
    );
  }

  /// Create a date range for the last 7 days
  factory DateRange.lastWeek() {
    final now = DateTime.now();
    return DateRange(
      start: now.subtract(const Duration(days: 7)),
      end: now,
    );
  }

  /// Create a date range for the last 90 days
  factory DateRange.lastQuarter() {
    final now = DateTime.now();
    return DateRange(
      start: now.subtract(const Duration(days: 90)),
      end: now,
    );
  }
}



/// Data for comparing user performance with peers
class ComparisonData {
  final double userAverage;
  final double peerAverage;
  final double percentile;
  final String ranking;

  ComparisonData({
    required this.userAverage,
    required this.peerAverage,
    required this.percentile,
    required this.ranking,
  });

  factory ComparisonData.empty() {
    return ComparisonData(
      userAverage: 0.0,
      peerAverage: 0.0,
      percentile: 0.0,
      ranking: 'Sem dados',
    );
  }

  /// Check if user is above peer average
  bool get isAboveAverage => userAverage > peerAverage;

  /// Get the difference from peer average
  double get differenceFromAverage => userAverage - peerAverage;

  /// Get performance level based on percentile
  String get performanceLevel {
    if (percentile >= 90) return 'Excelente';
    if (percentile >= 75) return 'Muito Bom';
    if (percentile >= 50) return 'Bom';
    if (percentile >= 25) return 'Regular';
    return 'Precisa Melhorar';
  }
}