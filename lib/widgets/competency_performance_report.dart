import 'package:flutter/material.dart';
import '../models/essay_progress.dart';
import '../models/progress_summary.dart';

/// Widget that displays detailed performance reports by competency
class CompetencyPerformanceReport extends StatelessWidget {
  final ProgressSummary summary;
  final List<ProgressPoint> recentProgress;
  final VoidCallback? onCompetencyTap;

  const CompetencyPerformanceReport({
    Key? key,
    required this.summary,
    required this.recentProgress,
    this.onCompetencyTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Relatório de Desempenho por Competência',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildOverallStats(context),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
            _buildCompetencyBreakdown(context),
            const SizedBox(height: 16),
            _buildRecommendations(context),
          ],
        ),
      ),
    );
  }

  Widget _buildOverallStats(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            context,
            'Média Geral',
            summary.averageScore.toStringAsFixed(1),
            Icons.analytics,
            Colors.blue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            context,
            'Melhor Nota',
            summary.bestScore.toString(),
            Icons.star,
            Colors.amber,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            context,
            'Tendência',
            summary.isImproving ? '+${summary.improvementTrend.toStringAsFixed(1)}' : summary.improvementTrend.toStringAsFixed(1),
            summary.isImproving ? Icons.trending_up : Icons.trending_down,
            summary.isImproving ? Colors.green : Colors.red,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(BuildContext context, String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildCompetencyBreakdown(BuildContext context) {
    final competencies = [
      CompetencyInfo('Competência 1', 'Domínio da modalidade escrita formal da língua portuguesa', 'competencia1'),
      CompetencyInfo('Competência 2', 'Compreender a proposta de redação e aplicar conceitos', 'competencia2'),
      CompetencyInfo('Competência 3', 'Selecionar, relacionar, organizar e interpretar informações', 'competencia3'),
      CompetencyInfo('Competência 4', 'Demonstrar conhecimento dos mecanismos linguísticos', 'competencia4'),
      CompetencyInfo('Competência 5', 'Elaborar proposta de intervenção para o problema abordado', 'competencia5'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Desempenho por Competência',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ...competencies.map((competency) => _buildCompetencyItem(context, competency)),
      ],
    );
  }

  Widget _buildCompetencyItem(BuildContext context, CompetencyInfo competency) {
    final score = summary.competencyAverages[competency.key] ?? 0.0;
    final maxScore = 200.0;
    final percentage = (score / maxScore) * 100;
    final level = _getPerformanceLevel(percentage);

    return GestureDetector(
      onTap: onCompetencyTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    competency.title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getLevelColor(level).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    level,
                    style: TextStyle(
                      color: _getLevelColor(level),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              competency.description,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: LinearProgressIndicator(
                    value: percentage / 100,
                    backgroundColor: Colors.grey.withOpacity(0.3),
                    valueColor: AlwaysStoppedAnimation<Color>(_getLevelColor(level)),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${score.toStringAsFixed(1)}/200',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            _buildCompetencyTrend(context, competency.key),
          ],
        ),
      ),
    );
  }

  Widget _buildCompetencyTrend(BuildContext context, String competencyKey) {
    if (recentProgress.length < 2) {
      return const SizedBox.shrink();
    }

    final recentScores = recentProgress
        .map((p) => p.competencyScores[competencyKey] ?? 0)
        .where((score) => score > 0)
        .toList();

    if (recentScores.length < 2) {
      return const SizedBox.shrink();
    }

    final firstHalf = recentScores.take(recentScores.length ~/ 2).toList();
    final secondHalf = recentScores.skip(recentScores.length ~/ 2).toList();

    final firstAvg = firstHalf.reduce((a, b) => a + b) / firstHalf.length;
    final secondAvg = secondHalf.reduce((a, b) => a + b) / secondHalf.length;
    final trend = secondAvg - firstAvg;

    return Row(
      children: [
        Icon(
          trend > 0 ? Icons.trending_up : trend < 0 ? Icons.trending_down : Icons.trending_flat,
          size: 16,
          color: trend > 0 ? Colors.green : trend < 0 ? Colors.red : Colors.grey,
        ),
        const SizedBox(width: 4),
        Text(
          trend > 0 
              ? 'Melhorando (+${trend.toStringAsFixed(1)})'
              : trend < 0 
                  ? 'Declinando (${trend.toStringAsFixed(1)})'
                  : 'Estável',
          style: TextStyle(
            fontSize: 12,
            color: trend > 0 ? Colors.green : trend < 0 ? Colors.red : Colors.grey,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildRecommendations(BuildContext context) {
    final recommendations = _generateRecommendations();
    
    if (recommendations.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(),
        const SizedBox(height: 16),
        Text(
          'Recomendações',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ...recommendations.map((recommendation) => _buildRecommendationItem(context, recommendation)),
      ],
    );
  }

  Widget _buildRecommendationItem(BuildContext context, String recommendation) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 6),
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              recommendation,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  String _getPerformanceLevel(double percentage) {
    if (percentage >= 90) return 'Excelente';
    if (percentage >= 80) return 'Muito Bom';
    if (percentage >= 70) return 'Bom';
    if (percentage >= 60) return 'Regular';
    if (percentage >= 50) return 'Suficiente';
    return 'Insuficiente';
  }

  Color _getLevelColor(String level) {
    switch (level) {
      case 'Excelente':
        return Colors.green;
      case 'Muito Bom':
        return Colors.lightGreen;
      case 'Bom':
        return Colors.blue;
      case 'Regular':
        return Colors.orange;
      case 'Suficiente':
        return Colors.amber;
      case 'Insuficiente':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  List<String> _generateRecommendations() {
    final recommendations = <String>[];
    
    // Find weakest competency
    final weakest = summary.weakestCompetency;
    if (weakest != null) {
      final competencyNumber = _getCompetencyNumber(weakest);
      switch (competencyNumber) {
        case 1:
          recommendations.add('Foque em revisar gramática, ortografia e pontuação para melhorar a Competência 1.');
          break;
        case 2:
          recommendations.add('Pratique a interpretação de temas e desenvolvimento de argumentos para a Competência 2.');
          break;
        case 3:
          recommendations.add('Trabalhe na organização de ideias e estruturação de parágrafos para a Competência 3.');
          break;
        case 4:
          recommendations.add('Estude conectivos e coesão textual para aprimorar a Competência 4.');
          break;
        case 5:
          recommendations.add('Pratique a elaboração de propostas de intervenção detalhadas para a Competência 5.');
          break;
      }
    }

    // General recommendations based on overall performance
    if (summary.averageScore < 600) {
      recommendations.add('Considere revisar os fundamentos da redação ENEM e praticar mais regularmente.');
    }

    if (!summary.isImproving && summary.totalEssays > 5) {
      recommendations.add('Varie os temas de redação para desenvolver diferentes habilidades argumentativas.');
    }

    if (summary.totalEssays < 10) {
      recommendations.add('Continue praticando! Quanto mais redações você escrever, melhor será seu desempenho.');
    }

    return recommendations;
  }

  int _getCompetencyNumber(String competencyKey) {
    switch (competencyKey) {
      case 'competencia1':
        return 1;
      case 'competencia2':
        return 2;
      case 'competencia3':
        return 3;
      case 'competencia4':
        return 4;
      case 'competencia5':
        return 5;
      default:
        return 1;
    }
  }
}

/// Information about a specific competency
class CompetencyInfo {
  final String title;
  final String description;
  final String key;

  CompetencyInfo(this.title, this.description, this.key);
}