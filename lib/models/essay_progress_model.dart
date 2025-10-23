/// Modelo para acompanhar o progresso do usuário
class EssayProgress {
  final String userId;
  final List<ProgressPoint> progressHistory;
  final Map<String, CompetencyProgress> competencyProgress;
  final List<Achievement> achievements;
  final ProgressSummary summary;
  final DateTime lastUpdated;

  EssayProgress({
    required this.userId,
    required this.progressHistory,
    required this.competencyProgress,
    required this.achievements,
    required this.summary,
    required this.lastUpdated,
  });

  factory EssayProgress.fromJson(Map<String, dynamic> json) {
    return EssayProgress(
      userId: json['userId'],
      progressHistory: (json['progressHistory'] as List)
          .map((item) => ProgressPoint.fromJson(item))
          .toList(),
      competencyProgress: (json['competencyProgress'] as Map<String, dynamic>)
          .map((key, value) => MapEntry(key, CompetencyProgress.fromJson(value))),
      achievements: (json['achievements'] as List)
          .map((item) => Achievement.fromJson(item))
          .toList(),
      summary: ProgressSummary.fromJson(json['summary']),
      lastUpdated: DateTime.parse(json['lastUpdated']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'progressHistory': progressHistory.map((item) => item.toJson()).toList(),
      'competencyProgress': competencyProgress
          .map((key, value) => MapEntry(key, value.toJson())),
      'achievements': achievements.map((item) => item.toJson()).toList(),
      'summary': summary.toJson(),
      'lastUpdated': lastUpdated.toIso8601String(),
    };
  }
}

/// Ponto específico no progresso
class ProgressPoint {
  final DateTime date;
  final int totalScore;
  final Map<String, int> competencyScores;
  final String essayId;
  final String essayType;

  ProgressPoint({
    required this.date,
    required this.totalScore,
    required this.competencyScores,
    required this.essayId,
    required this.essayType,
  });

  factory ProgressPoint.fromJson(Map<String, dynamic> json) {
    return ProgressPoint(
      date: DateTime.parse(json['date']),
      totalScore: json['totalScore'],
      competencyScores: Map<String, int>.from(json['competencyScores']),
      essayId: json['essayId'],
      essayType: json['essayType'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date.toIso8601String(),
      'totalScore': totalScore,
      'competencyScores': competencyScores,
      'essayId': essayId,
      'essayType': essayType,
    };
  }
}

/// Progresso por competência
class CompetencyProgress {
  final String competencyName;
  final List<int> scores;
  final double averageScore;
  final double improvement;
  final String trend; // 'improving', 'stable', 'declining'
  final List<String> strengths;
  final List<String> weaknesses;

  CompetencyProgress({
    required this.competencyName,
    required this.scores,
    required this.averageScore,
    required this.improvement,
    required this.trend,
    required this.strengths,
    required this.weaknesses,
  });

  factory CompetencyProgress.fromJson(Map<String, dynamic> json) {
    return CompetencyProgress(
      competencyName: json['competencyName'],
      scores: List<int>.from(json['scores']),
      averageScore: json['averageScore'].toDouble(),
      improvement: json['improvement'].toDouble(),
      trend: json['trend'],
      strengths: List<String>.from(json['strengths']),
      weaknesses: List<String>.from(json['weaknesses']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'competencyName': competencyName,
      'scores': scores,
      'averageScore': averageScore,
      'improvement': improvement,
      'trend': trend,
      'strengths': strengths,
      'weaknesses': weaknesses,
    };
  }
}

/// Resumo do progresso
class ProgressSummary {
  final int totalEssays;
  final double averageScore;
  final double overallImprovement;
  final String strongestCompetency;
  final String weakestCompetency;
  final int essaysThisMonth;
  final int essaysThisWeek;
  final DateTime firstEssayDate;
  final DateTime lastEssayDate;

  ProgressSummary({
    required this.totalEssays,
    required this.averageScore,
    required this.overallImprovement,
    required this.strongestCompetency,
    required this.weakestCompetency,
    required this.essaysThisMonth,
    required this.essaysThisWeek,
    required this.firstEssayDate,
    required this.lastEssayDate,
  });

  factory ProgressSummary.fromJson(Map<String, dynamic> json) {
    return ProgressSummary(
      totalEssays: json['totalEssays'],
      averageScore: json['averageScore'].toDouble(),
      overallImprovement: json['overallImprovement'].toDouble(),
      strongestCompetency: json['strongestCompetency'],
      weakestCompetency: json['weakestCompetency'],
      essaysThisMonth: json['essaysThisMonth'],
      essaysThisWeek: json['essaysThisWeek'],
      firstEssayDate: DateTime.parse(json['firstEssayDate']),
      lastEssayDate: DateTime.parse(json['lastEssayDate']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'totalEssays': totalEssays,
      'averageScore': averageScore,
      'overallImprovement': overallImprovement,
      'strongestCompetency': strongestCompetency,
      'weakestCompetency': weakestCompetency,
      'essaysThisMonth': essaysThisMonth,
      'essaysThisWeek': essaysThisWeek,
      'firstEssayDate': firstEssayDate.toIso8601String(),
      'lastEssayDate': lastEssayDate.toIso8601String(),
    };
  }
}

/// Conquista/Achievement
class Achievement {
  final String id;
  final String name;
  final String description;
  final String iconName;
  final AchievementType type;
  final DateTime unlockedAt;
  final bool isUnlocked;
  final Map<String, dynamic>? metadata;

  Achievement({
    required this.id,
    required this.name,
    required this.description,
    required this.iconName,
    required this.type,
    required this.unlockedAt,
    this.isUnlocked = false,
    this.metadata,
  });

  factory Achievement.fromJson(Map<String, dynamic> json) {
    return Achievement(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      iconName: json['iconName'],
      type: AchievementType.values.firstWhere(
        (e) => e.toString().split('.').last == json['type'],
        orElse: () => AchievementType.general,
      ),
      unlockedAt: DateTime.parse(json['unlockedAt']),
      isUnlocked: json['isUnlocked'] ?? false,
      metadata: json['metadata'] != null
          ? Map<String, dynamic>.from(json['metadata'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'iconName': iconName,
      'type': type.toString().split('.').last,
      'unlockedAt': unlockedAt.toIso8601String(),
      'isUnlocked': isUnlocked,
      'metadata': metadata,
    };
  }
}

/// Tipos de conquistas
enum AchievementType {
  general,      // Conquistas gerais
  score,        // Baseadas em pontuação
  frequency,    // Baseadas em frequência
  improvement,  // Baseadas em melhoria
  competency,   // Baseadas em competências específicas
  streak,       // Baseadas em sequências
}

/// Conquistas predefinidas
class PredefinedAchievements {
  // Conquistas Gerais
  static Achievement get firstEssay => Achievement(
    id: 'first_essay',
    name: 'Primeira Redação',
    description: 'Parabéns por escrever sua primeira redação!',
    iconName: 'edit',
    type: AchievementType.general,
    unlockedAt: DateTime.now(),
  );

  static Achievement get essay10 => Achievement(
    id: 'essay_10',
    name: 'Escritor Dedicado',
    description: 'Escreveu 10 redações!',
    iconName: 'trophy',
    type: AchievementType.general,
    unlockedAt: DateTime.now(),
  );

  static Achievement get essay25 => Achievement(
    id: 'essay_25',
    name: 'Escritor Experiente',
    description: 'Escreveu 25 redações!',
    iconName: 'medal',
    type: AchievementType.general,
    unlockedAt: DateTime.now(),
  );

  static Achievement get essay50 => Achievement(
    id: 'essay_50',
    name: 'Mestre da Escrita',
    description: 'Escreveu 50 redações!',
    iconName: 'fire',
    type: AchievementType.general,
    unlockedAt: DateTime.now(),
  );

  // Conquistas de Pontuação
  static Achievement get score600Plus => Achievement(
    id: 'score_600_plus',
    name: 'Boa Pontuação',
    description: 'Conseguiu uma pontuação acima de 600 pontos!',
    iconName: 'star',
    type: AchievementType.score,
    unlockedAt: DateTime.now(),
  );

  static Achievement get score800Plus => Achievement(
    id: 'score_800_plus',
    name: 'Nota Excelente',
    description: 'Conseguiu uma pontuação acima de 800 pontos!',
    iconName: 'star',
    type: AchievementType.score,
    unlockedAt: DateTime.now(),
  );

  static Achievement get score900Plus => Achievement(
    id: 'score_900_plus',
    name: 'Quase Perfeito',
    description: 'Conseguiu uma pontuação acima de 900 pontos!',
    iconName: 'star',
    type: AchievementType.score,
    unlockedAt: DateTime.now(),
  );

  static Achievement get perfectScore => Achievement(
    id: 'perfect_score',
    name: 'Redação Perfeita',
    description: 'Conseguiu pontuação máxima de 1000 pontos!',
    iconName: 'target',
    type: AchievementType.score,
    unlockedAt: DateTime.now(),
  );

  // Conquistas de Frequência
  static Achievement get dailyWriter => Achievement(
    id: 'daily_writer',
    name: 'Escritor Diário',
    description: 'Escreveu uma redação por dia durante 3 dias!',
    iconName: 'calendar_today',
    type: AchievementType.frequency,
    unlockedAt: DateTime.now(),
  );

  static Achievement get weeklyStreak => Achievement(
    id: 'weekly_streak',
    name: 'Dedicação Semanal',
    description: 'Escreveu redações por 7 dias consecutivos!',
    iconName: 'fire',
    type: AchievementType.streak,
    unlockedAt: DateTime.now(),
  );

  static Achievement get monthlyChampion => Achievement(
    id: 'monthly_champion',
    name: 'Campeão Mensal',
    description: 'Escreveu pelo menos 10 redações em um mês!',
    iconName: 'trophy',
    type: AchievementType.frequency,
    unlockedAt: DateTime.now(),
  );

  // Conquistas de Melhoria
  static Achievement get improver => Achievement(
    id: 'improver',
    name: 'Em Evolução',
    description: 'Melhorou sua pontuação em 100 pontos!',
    iconName: 'trending_up',
    type: AchievementType.improvement,
    unlockedAt: DateTime.now(),
  );

  static Achievement get bigImprover => Achievement(
    id: 'big_improver',
    name: 'Grande Evolução',
    description: 'Melhorou sua pontuação em 200 pontos!',
    iconName: 'trending_up',
    type: AchievementType.improvement,
    unlockedAt: DateTime.now(),
  );

  // Conquistas por Competência
  static Achievement get competency1Master => Achievement(
    id: 'competency_1_master',
    name: 'Mestre da Norma Culta',
    description: 'Alcançou pontuação máxima na Competência 1!',
    iconName: 'lightbulb',
    type: AchievementType.competency,
    unlockedAt: DateTime.now(),
  );

  static Achievement get competency2Master => Achievement(
    id: 'competency_2_master',
    name: 'Mestre da Compreensão',
    description: 'Alcançou pontuação máxima na Competência 2!',
    iconName: 'lightbulb',
    type: AchievementType.competency,
    unlockedAt: DateTime.now(),
  );

  static Achievement get competency3Master => Achievement(
    id: 'competency_3_master',
    name: 'Mestre da Argumentação',
    description: 'Alcançou pontuação máxima na Competência 3!',
    iconName: 'lightbulb',
    type: AchievementType.competency,
    unlockedAt: DateTime.now(),
  );

  static Achievement get competency4Master => Achievement(
    id: 'competency_4_master',
    name: 'Mestre da Coesão',
    description: 'Alcançou pontuação máxima na Competência 4!',
    iconName: 'lightbulb',
    type: AchievementType.competency,
    unlockedAt: DateTime.now(),
  );

  static Achievement get competency5Master => Achievement(
    id: 'competency_5_master',
    name: 'Mestre da Proposta',
    description: 'Alcançou pontuação máxima na Competência 5!',
    iconName: 'lightbulb',
    type: AchievementType.competency,
    unlockedAt: DateTime.now(),
  );

  static Achievement get allCompetenciesMaster => Achievement(
    id: 'all_competencies_master',
    name: 'Mestre Completo',
    description: 'Alcançou pontuação máxima em todas as competências!',
    iconName: 'trophy',
    type: AchievementType.competency,
    unlockedAt: DateTime.now(),
  );

  // Conquistas Especiais
  static Achievement get nightOwl => Achievement(
    id: 'night_owl',
    name: 'Coruja da Madrugada',
    description: 'Escreveu uma redação após as 22h!',
    iconName: 'nightlight',
    type: AchievementType.general,
    unlockedAt: DateTime.now(),
  );

  static Achievement get earlyBird => Achievement(
    id: 'early_bird',
    name: 'Madrugador',
    description: 'Escreveu uma redação antes das 6h!',
    iconName: 'wb_sunny',
    type: AchievementType.general,
    unlockedAt: DateTime.now(),
  );

  static Achievement get speedWriter => Achievement(
    id: 'speed_writer',
    name: 'Escritor Veloz',
    description: 'Escreveu 3 redações em um dia!',
    iconName: 'speed',
    type: AchievementType.frequency,
    unlockedAt: DateTime.now(),
  );

  static List<Achievement> get all => [
    // Gerais
    firstEssay,
    essay10,
    essay25,
    essay50,
    
    // Pontuação
    score600Plus,
    score800Plus,
    score900Plus,
    perfectScore,
    
    // Frequência
    dailyWriter,
    weeklyStreak,
    monthlyChampion,
    speedWriter,
    
    // Melhoria
    improver,
    bigImprover,
    
    // Competências
    competency1Master,
    competency2Master,
    competency3Master,
    competency4Master,
    competency5Master,
    allCompetenciesMaster,
    
    // Especiais
    nightOwl,
    earlyBird,
  ];
}