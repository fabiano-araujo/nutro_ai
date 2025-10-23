class Essay {
  final String id;
  final String title;
  final String text;
  final String type; // ENEM, Vestibular, etc.
  final String? themeId;
  final DateTime date;
  final DateTime updatedAt;
  final int score;
  final String status; // Corrigido, Em Análise, Rascunho, Arquivado
  final Map<String, int>? competenceScores; // Pontuação por competência
  final int wordCount;
  final int characterCount;
  final Map<String, dynamic>? metadata;
  final List<String>? tags;

  Essay({
    required this.id,
    required this.title,
    required this.text,
    required this.type,
    required this.date,
    DateTime? updatedAt,
    this.themeId,
    this.score = 0,
    this.status = 'Rascunho',
    this.competenceScores,
    int? wordCount,
    int? characterCount,
    this.metadata,
    this.tags,
  }) : 
    updatedAt = updatedAt ?? date,
    wordCount = wordCount ?? _countWords(text),
    characterCount = characterCount ?? text.length;

  static int _countWords(String text) {
    return text.trim().isEmpty ? 0 : text.trim().split(RegExp(r'\s+')).length;
  }

  factory Essay.fromJson(Map<String, dynamic> json) {
    return Essay(
      id: json['id'],
      title: json['title'],
      text: json['text'],
      type: json['type'],
      themeId: json['themeId'],
      date: DateTime.parse(json['date']),
      updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null,
      score: json['score'] ?? 0,
      status: json['status'] ?? 'Rascunho',
      competenceScores: json['competenceScores'] != null
          ? Map<String, int>.from(json['competenceScores'])
          : null,
      wordCount: json['wordCount'],
      characterCount: json['characterCount'],
      metadata: json['metadata'] != null
          ? Map<String, dynamic>.from(json['metadata'])
          : null,
      tags: json['tags'] != null
          ? List<String>.from(json['tags'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'text': text,
      'type': type,
      'themeId': themeId,
      'date': date.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'score': score,
      'status': status,
      'competenceScores': competenceScores,
      'wordCount': wordCount,
      'characterCount': characterCount,
      'metadata': metadata,
      'tags': tags,
    };
  }

  Essay copyWith({
    String? id,
    String? title,
    String? text,
    String? type,
    String? themeId,
    DateTime? date,
    DateTime? updatedAt,
    int? score,
    String? status,
    Map<String, int>? competenceScores,
    int? wordCount,
    int? characterCount,
    Map<String, dynamic>? metadata,
    List<String>? tags,
  }) {
    return Essay(
      id: id ?? this.id,
      title: title ?? this.title,
      text: text ?? this.text,
      type: type ?? this.type,
      themeId: themeId ?? this.themeId,
      date: date ?? this.date,
      updatedAt: updatedAt ?? DateTime.now(),
      score: score ?? this.score,
      status: status ?? this.status,
      competenceScores: competenceScores ?? this.competenceScores,
      wordCount: wordCount ?? (text != null ? Essay._countWords(text) : this.wordCount),
      characterCount: characterCount ?? (text != null ? text.length : this.characterCount),
      metadata: metadata ?? this.metadata,
      tags: tags ?? this.tags,
    );
  }
}
