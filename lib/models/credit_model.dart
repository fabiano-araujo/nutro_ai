class CreditModel {
  static const int dailyCredits = 20;
  static const int textMessageCost = 1;
  static const int imageAnalysisCost = 3;
  static const int fileAnalysisCost = 1;
  static const int videoSummaryCost = 1;

  final int creditsRemaining;
  final DateTime lastResetDate;

  CreditModel({
    required this.creditsRemaining,
    required this.lastResetDate,
  });

  CreditModel.initial()
      : creditsRemaining = dailyCredits,
        lastResetDate = DateTime.now();

  CreditModel copyWith({
    int? creditsRemaining,
    DateTime? lastResetDate,
  }) {
    return CreditModel(
      creditsRemaining: creditsRemaining ?? this.creditsRemaining,
      lastResetDate: lastResetDate ?? this.lastResetDate,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'creditsRemaining': creditsRemaining,
      'lastResetDate': lastResetDate.toIso8601String(),
    };
  }

  factory CreditModel.fromJson(Map<String, dynamic> json) {
    return CreditModel(
      creditsRemaining: json['creditsRemaining'] as int,
      lastResetDate: DateTime.parse(json['lastResetDate'] as String),
    );
  }

  bool get needsReset {
    final now = DateTime.now();
    return !_isSameDay(lastResetDate, now);
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }
}
