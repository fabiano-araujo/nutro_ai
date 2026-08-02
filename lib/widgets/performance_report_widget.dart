import 'package:flutter/material.dart';
import '../i18n/app_localizations.dart';
import '../services/enhanced_progress_tracker.dart';
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
  State<PerformanceReportWidget> createState() =>
      _PerformanceReportWidgetState();
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
        title: Text(_translate(context, 'progress_performance_report')),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: _translate(context, 'progress_refresh'),
            onPressed: widget.onRefresh,
          ),
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: _translate(context, 'progress_share_report'),
            onPressed: _shareReport,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              icon: const Icon(Icons.analytics),
              text: _translate(context, 'progress_tab_overview'),
            ),
            Tab(
              icon: const Icon(Icons.show_chart),
              text: _translate(context, 'progress_tab_progress'),
            ),
            Tab(
              icon: const Icon(Icons.radar),
              text: _translate(context, 'progress_tab_competencies'),
            ),
            Tab(
              icon: const Icon(Icons.emoji_events),
              text: _translate(context, 'progress_achievements'),
            ),
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
                    _translate(context, 'progress_temporal_evolution'),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 200,
                    child: Center(
                      child: Text(
                        _translate(
                            context, 'progress_temporal_chart_placeholder'),
                      ),
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
            title: _translate(context, 'progress_recent_achievements'),
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
            _translate(context, 'progress_total_essays'),
            summary.totalEssays.toString(),
            Icons.edit,
            Colors.blue,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildSummaryCard(
            _translate(context, 'progress_average_score'),
            summary.averageScore.toStringAsFixed(0),
            Icons.star,
            Colors.amber,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildSummaryCard(
            _translate(context, 'progress_best_score'),
            summary.bestScore.toString(),
            Icons.trending_up,
            Colors.green,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(
      String title, String value, IconData icon, Color color) {
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
              _translate(context, 'progress_performance_metrics'),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            _buildMetricRow(
              _translate(context, 'progress_writing_frequency'),
              _translateWith(
                context,
                'progress_essays_per_day_value',
                {'value': widget.report.writingFrequency.toStringAsFixed(2)},
              ),
              _getFrequencyColor(widget.report.writingFrequency),
            ),
            const SizedBox(height: 8),
            _buildMetricRow(
              _translate(context, 'progress_consistency'),
              '${(widget.report.consistencyScore * 100).toStringAsFixed(0)}%',
              _getConsistencyColor(widget.report.consistencyScore),
            ),
            const SizedBox(height: 8),
            _buildMetricRow(
              _translate(context, 'progress_improvement_rate'),
              _translateWith(
                context,
                'progress_points_per_day_value',
                {'value': widget.report.improvementRate.toStringAsFixed(1)},
              ),
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
              _translate(context, 'progress_recent_achievements'),
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
              _translate(context, 'progress_quick_insights'),
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
              _translate(context, 'progress_writing_frequency'),
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
              _translateWith(
                context,
                'progress_essays_per_day_value',
                {'value': widget.report.writingFrequency.toStringAsFixed(2)},
              ),
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
              _translate(context, 'progress_consistency'),
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
              _translateWith(
                context,
                'progress_consistency_percentage',
                {
                  'percentage':
                      (widget.report.consistencyScore * 100).toStringAsFixed(0),
                },
              ),
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
      competencyScores[key] = analysis.averageScore.round();
    });

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _translate(context, 'progress_competency_radar'),
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
              _translate(context, 'progress_recommendations'),
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
                          const Icon(Icons.lightbulb,
                              color: Colors.amber, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _localizedServiceRecommendation(
                                context,
                                recommendation,
                              ),
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
    final totalPossibleAchievements =
        20; // This would come from a predefined list
    final unlockedCount = widget.report.achievements.length;
    final progress = unlockedCount / totalPossibleAchievements;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _translate(context, 'progress_achievement_progress'),
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
              _translateWith(
                context,
                'progress_achievements_unlocked',
                {
                  'unlocked': MaterialLocalizations.of(context)
                      .formatDecimal(unlockedCount),
                  'total': MaterialLocalizations.of(context)
                      .formatDecimal(totalPossibleAchievements),
                },
              ),
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
        message: _translateWith(
          context,
          'progress_insight_improving',
          {'points': summary.improvementTrend.toStringAsFixed(0)},
        ),
        isPositive: true,
      ));
    }

    // Consistency insight
    if (widget.report.consistencyScore > 0.8) {
      insights.add(Insight(
        message: _translate(context, 'progress_insight_consistent'),
        isPositive: true,
      ));
    }

    // Frequency insight
    if (widget.report.writingFrequency < 0.1) {
      insights.add(Insight(
        message: _translate(context, 'progress_insight_write_regularly'),
        isPositive: false,
      ));
    }

    // Best competency insight
    if (widget.report.competencyAnalysis.isNotEmpty) {
      final bestCompetency = widget.report.competencyAnalysis.entries.reduce(
        (a, b) => a.value.averageScore > b.value.averageScore ? a : b,
      );

      insights.add(Insight(
        message: _translateWith(
          context,
          'progress_strongest_competency',
          {
            'competency': _localizedCompetencyName(
              context,
              bestCompetency.key,
              fallback: bestCompetency.value.competencyName,
            ),
          },
        ),
        isPositive: true,
      ));
    }

    return insights;
  }

  void _shareReport() {
    // Implementation for sharing the report
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_translate(context, 'progress_sharing_coming_soon')),
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

String _localizedServiceRecommendation(
  BuildContext context,
  String recommendation,
) {
  final key = switch (recommendation) {
    'Foque em melhorar os fundamentos desta competência' =>
      'progress_recommendation_improve_fundamentals',
    'Pratique mais para manter regularidade' =>
      'progress_recommendation_practice_consistently',
    'Revise conceitos básicos desta competência' =>
      'progress_recommendation_review_basics',
    _ => 'progress_recommendation_generic',
  };
  return _translate(context, key);
}

String _localizedCompetencyName(
  BuildContext context,
  String value, {
  String? fallback,
}) {
  final match = RegExp(r'([1-5])').firstMatch(value);
  if (match == null) return fallback ?? value;
  return _translateWith(
    context,
    'progress_competency_number',
    {'number': match.group(1)!},
  );
}

String _translate(BuildContext context, String key) {
  return AppLocalizations.of(context).translate(key);
}

String _translateWith(
  BuildContext context,
  String key,
  Map<String, String> values,
) {
  var text = _translate(context, key);
  values.forEach((placeholder, value) {
    text = text.replaceAll('{$placeholder}', value);
  });
  return text;
}
