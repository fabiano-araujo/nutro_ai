class EssayCorrection {
  final String id;
  final String essayId;
  final int totalScore;
  final Map<String, int> competencyScores;
  final List<DetailedFeedback> feedback;
  final List<EssaySuggestion> suggestions;
  final DateTime correctedAt;
  final String correctionVersion;

  EssayCorrection({
    required this.id,
    required this.essayId,
    required this.totalScore,
    required this.competencyScores,
    required this.feedback,
    required this.suggestions,
    required this.correctedAt,
    this.correctionVersion = '1.0',
  });

  factory EssayCorrection.fromJson(Map<String, dynamic> json) {
    return EssayCorrection(
      id: json['id'],
      essayId: json['essayId'],
      totalScore: json['totalScore'],
      competencyScores: Map<String, int>.from(json['competencyScores']),
      feedback: (json['feedback'] as List)
          .map((item) => DetailedFeedback.fromJson(item))
          .toList(),
      suggestions: (json['suggestions'] as List)
          .map((item) => EssaySuggestion.fromJson(item))
          .toList(),
      correctedAt: DateTime.parse(json['correctedAt']),
      correctionVersion: json['correctionVersion'] ?? '1.0',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'essayId': essayId,
      'totalScore': totalScore,
      'competencyScores': competencyScores,
      'feedback': feedback.map((item) => item.toJson()).toList(),
      'suggestions': suggestions.map((item) => item.toJson()).toList(),
      'correctedAt': correctedAt.toIso8601String(),
      'correctionVersion': correctionVersion,
    };
  }
}

class DetailedFeedback {
  final String competency;
  final int score;
  final String summary;
  final List<SpecificComment> comments;
  final List<ImprovementTip> tips;

  DetailedFeedback({
    required this.competency,
    required this.score,
    required this.summary,
    required this.comments,
    required this.tips,
  });

  factory DetailedFeedback.fromJson(Map<String, dynamic> json) {
    return DetailedFeedback(
      competency: json['competency'],
      score: json['score'],
      summary: json['summary'],
      comments: (json['comments'] as List)
          .map((item) => SpecificComment.fromJson(item))
          .toList(),
      tips: (json['tips'] as List)
          .map((item) => ImprovementTip.fromJson(item))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'competency': competency,
      'score': score,
      'summary': summary,
      'comments': comments.map((item) => item.toJson()).toList(),
      'tips': tips.map((item) => item.toJson()).toList(),
    };
  }
}

class SpecificComment {
  final String text;
  final String type; // positive, negative, neutral
  final int? startPosition;
  final int? endPosition;

  SpecificComment({
    required this.text,
    required this.type,
    this.startPosition,
    this.endPosition,
  });

  factory SpecificComment.fromJson(Map<String, dynamic> json) {
    return SpecificComment(
      text: json['text'],
      type: json['type'],
      startPosition: json['startPosition'],
      endPosition: json['endPosition'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'text': text,
      'type': type,
      'startPosition': startPosition,
      'endPosition': endPosition,
    };
  }
}

class ImprovementTip {
  final String title;
  final String description;
  final String category; // grammar, style, structure, content
  final int priority; // 1-5, where 1 is highest priority

  ImprovementTip({
    required this.title,
    required this.description,
    required this.category,
    this.priority = 3,
  });

  factory ImprovementTip.fromJson(Map<String, dynamic> json) {
    return ImprovementTip(
      title: json['title'],
      description: json['description'],
      category: json['category'],
      priority: json['priority'] ?? 3,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'category': category,
      'priority': priority,
    };
  }
}

enum SuggestionPriority { low, medium, high, critical }

class EssaySuggestion {
  final String type; // grammar, style, structure, content
  final String originalText;
  final String suggestedText;
  final String explanation;
  final int startPosition;
  final int endPosition;
  final SuggestionPriority priority;

  EssaySuggestion({
    required this.type,
    required this.originalText,
    required this.suggestedText,
    required this.explanation,
    required this.startPosition,
    required this.endPosition,
    this.priority = SuggestionPriority.medium,
  });

  factory EssaySuggestion.fromJson(Map<String, dynamic> json) {
    return EssaySuggestion(
      type: json['type'],
      originalText: json['originalText'],
      suggestedText: json['suggestedText'],
      explanation: json['explanation'],
      startPosition: json['startPosition'],
      endPosition: json['endPosition'],
      priority: SuggestionPriority.values.firstWhere(
        (e) => e.toString().split('.').last == json['priority'],
        orElse: () => SuggestionPriority.medium,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'originalText': originalText,
      'suggestedText': suggestedText,
      'explanation': explanation,
      'startPosition': startPosition,
      'endPosition': endPosition,
      'priority': priority.toString().split('.').last,
    };
  }
}