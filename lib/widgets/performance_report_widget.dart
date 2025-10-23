import 'package:flutter/material.dart';
import '../services/enhanced_progress_tracker.dart';
import '../models/essay_progress.dart';
import '../utils/date_time_utils.dart';
import 'enhanced_progress_charts.dart';
import 'competency_radar_chart.dart';
import 'achievement_widgets.dart';

/// Comprehensive performance report widget
class PerformanceReportWidget extends StatefulWidget {
  final PerformanceReport report;
  final String userId;
  final VoidCallback? onRefresh;

  const PerformanceReportWidget({
    Key? key,
    required this.report,
    required this.userId,
    this.onRefresh,
  }) : super(key: key);

  @override
  State<PerformanceReportWidget> createState() => _PerformanceReportWidgetState();
}

class _PerformanceReportWidgetState extends State<PerformanceReportWidget>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Relatório de Desempenho'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: widget.onRefresh,
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _shareReport,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.analytics), text: 'Visão Geral'),
            Tab(icon: Icon(Icons.show_chart), text: 'Progresso'),
            Tab(icon: Icon(Icons.radar), text: 'Competências'),
            Tab(icon: Icon(Icons.emoji_events), text: 'Conquistas'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(),
          _buildProgressTab(),
          _buildCompetenciesTab(),
          _buildAchievementsTab(),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSummaryCards(),
          const SizedBox(height: 16),
          _buildPerformanceMetrics(),
          const SizedBox(height: 16),
          _buildRecentAchievements(),
          const SizedBox(height: 16),
          _buildQuickInsights(),
        ],
      ),
    );
  }

  Widget _buildProgressTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // This would need chart data from the service
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Evolução Temporal',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    height: 200,
                    child: const Center(
                      child: Text('Gráfico de progresso temporal seria exibido aqui'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildWritingFrequencyCard(),
          const SizedBox(height: 16),
          _buildConsistencyCard(),
        ],
      ),
    );
  }

  Widget _buildCompetenciesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          _buildCompetencyRadarChart(),
          const SizedBox(height: 16),
          CompetencyAnalysisChart(
            competencyAnalysis: widget.report.competencyAnalysis,
          ),
          const SizedBox(height: 16),
          _buildCompetencyRecommendations(),
        ],
      ),
    );
  }

  Widget _buildAchievementsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          AchievementGrid(
            achievements: widget.report.achievements,
            title: 'Conquistas Recentes',
          ),
          const SizedBox(height: 16),
          _buildAchievementProgress(),
        ],
      ),
    );
  }

  Widget _buildSummaryCards() {
    final summary = widget.report.summary;
    
    return Row(
      children: [
        Expanded(
          child: _buildSummaryCard(
            'Total de Redações',
            summary.totalEssays.toString(),
            Icons.edit,
            Colors.blue,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildSummaryCard(
            'Pontuação Média',
            summary.averageScore.toStringAsFixed(0),
            Icons.star,
            Colors.amber,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildSummaryCard(
            'Melhor Nota',
            summary.bestScore.toString(),
            Icons.trending_up,
            Colors.green,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              title,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPerformanceMetrics() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Métricas de Performance',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildMetricRow(
              'Frequência de Escrita',
              '${widget.report.writingFrequency.toStringAsFixed(2)} redações/dia',
              _getFrequencyColor(widget.report.writingFrequency),
            ),
            const SizedBox(height: 8),
            _buildMetricRow(
              'Consistência',
              '${(widget.report.consistencyScore * 100).toStringAsFixed(0)}%',
              _getConsistencyColor(widget.report.consistencyScore),
            ),
            const SizedBox(height: 8),
            _buildMetricRow(
              'Taxa de Melhoria',
              '${widget.report.improvementRate.toStringAsFixed(1)} pontos/dia',
              _getImprovementColor(widget.report.improvementRate),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricRow(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRecentAchievements() {
    final recentAchievements = widget.report.achievements.take(3).toList();
    
    if (recentAchievements.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Conquistas Recentes',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            AchievementBadgeRow(
              achievements: recentAchievements,
              badgeSize: 40,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickInsights() {
    final insights = _generateInsights();
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Insights Rápidos',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ...insights.map((insight) => Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Row(
                children: [
                  Icon(
                    insight.isPositive ? Icons.trending_up : Icons.info,
                    color: insight.isPositive ? Colors.green : Colors.blue,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      insight.message,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildWritingFrequencyCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Frequência de Escrita',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: (widget.report.writingFrequency * 10).clamp(0.0, 1.0),
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(
                _getFrequencyColor(widget.report.writingFrequency),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${widget.report.writingFrequency.toStringAsFixed(2)} redações por dia',
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConsistencyCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Consistência',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: widget.report.consistencyScore,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(
                _getConsistencyColor(widget.report.consistencyScore),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${(widget.report.consistencyScore * 100).toStringAsFixed(0)}% de consistência',
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompetencyRadarChart() {
    // Convert competency analysis to radar chart format
    final competencyScores = <String, int>{};
    
    widget.report.competencyAnalysis.forEach((key, analysis) {
      competencyScores[analysis.competencyName] = analysis.averageScore.round();
    });

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Radar de Competências',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: CompetencyRadarChart(
                competencyScores: competencyScores,
                size: 250,
                animated: true,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompetencyRecommendations() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recomendações',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ...widget.report.competencyAnalysis.values
                .expand((analysis) => analysis.recommendations)
                .take(5)
                .map((recommendation) => Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    children: [
                      const Icon(Icons.lightbulb, color: Colors.amber, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          recommendation,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildAchievementProgress() {
    final totalPossibleAchievements = 20; // This would come from a predefined list
    final unlockedCount = widget.report.achievements.length;
    final progress = unlockedCount / totalPossibleAchievements;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Progresso de Conquistas',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey[300],
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.amber),
            ),
            const SizedBox(height: 8),
            Text(
              '$unlockedCount de $totalPossibleAchievements conquistas desbloqueadas',
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Color _getFrequencyColor(double frequency) {
    if (frequency >= 0.5) return Colors.green;
    if (frequency >= 0.2) return Colors.orange;
    return Colors.red;
  }

  Color _getConsistencyColor(double consistency) {
    if (consistency >= 0.8) return Colors.green;
    if (consistency >= 0.6) return Colors.orange;
    return Colors.red;
  }

  Color _getImprovementColor(double improvement) {
    if (improvement > 0) return Colors.green;
    if (improvement == 0) return Colors.grey;
    return Colors.red;
  }

  List<Insight> _generateInsights() {
    final insights = <Insight>[];
    final summary = widget.report.summary;

    // Improvement insight
    if (summary.improvementTrend > 0) {
      insights.add(Insight(
        message: 'Você está melhorando! Sua pontuação aumentou ${summary.improvementTrend.toStringAsFixed(0)} pontos em média.',
        isPositive: true,
      ));
    }

    // Consistency insight
    if (widget.report.consistencyScore > 0.8) {
      insights.add(Insight(
        message: 'Sua performance é muito consistente! Continue assim.',
        isPositive: true,
      ));
    }

    // Frequency insight
    if (widget.report.writingFrequency < 0.1) {
      insights.add(Insight(
        message: 'Tente escrever mais regularmente para melhorar seus resultados.',
        isPositive: false,
      ));
    }

    // Best competency insight
    final bestCompetency = widget.report.competencyAnalysis.entries
        .reduce((a, b) => a.value.averageScore > b.value.averageScore ? a : b);
    
    insights.add(Insight(
      message: 'Sua competência mais forte é: ${bestCompetency.value.competencyName}',
      isPositive: true,
    ));

    return insights;
  }

  void _shareReport() {
    // Implementation for sharing the report
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Funcionalidade de compartilhamento em desenvolvimento'),
      ),
    );
  }
}

class Insight {
  final String message;
  final bool isPositive;

  Insight({
    required this.message,
    required this.isPositive,
  });
}