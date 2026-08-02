import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../i18n/app_localizations.dart';
import '../providers/progress_provider.dart';
import '../widgets/enhanced_progress_charts.dart';
import '../widgets/competency_radar_chart.dart';
import '../widgets/achievement_widgets.dart';
import '../widgets/performance_report_widget.dart';
import '../models/essay_progress.dart';
import '../models/achievement.dart';
import '../services/enhanced_progress_tracker.dart';

/// Main progress dashboard screen
class ProgressDashboardScreen extends StatefulWidget {
  final String userId;

  const ProgressDashboardScreen({
    Key? key,
    required this.userId,
  }) : super(key: key);

  @override
  State<ProgressDashboardScreen> createState() =>
      _ProgressDashboardScreenState();
}

class _ProgressDashboardScreenState extends State<ProgressDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DateRange _selectedRange = DateRange.lastMonth();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    // Load initial data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProgressProvider>().loadProgressData(widget.userId);
    });
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
        title: Text(_translate(context, 'progress_analytics_title')),
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range),
            tooltip: _translate(context, 'progress_select_period'),
            onPressed: _showDateRangePicker,
          ),
          IconButton(
            icon: const Icon(Icons.assessment),
            tooltip: _translate(context, 'progress_performance_report'),
            onPressed: _showPerformanceReport,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: _translate(context, 'progress_refresh'),
            onPressed: _refreshData,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              icon: const Icon(Icons.dashboard),
              text: _translate(context, 'progress_tab_overview'),
            ),
            Tab(
              icon: const Icon(Icons.show_chart),
              text: _translate(context, 'progress_tab_charts'),
            ),
            Tab(
              icon: const Icon(Icons.emoji_events),
              text: _translate(context, 'progress_achievements'),
            ),
          ],
        ),
      ),
      body: Consumer<ProgressProvider>(
        builder: (context, progressProvider, child) {
          if (progressProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (progressProvider.error != null) {
            return _buildErrorState(progressProvider.error!);
          }

          return TabBarView(
            controller: _tabController,
            children: [
              _buildOverviewTab(progressProvider),
              _buildChartsTab(progressProvider),
              _buildAchievementsTab(progressProvider),
            ],
          );
        },
      ),
    );
  }

  Widget _buildOverviewTab(ProgressProvider provider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildQuickStats(provider),
          const SizedBox(height: 16),
          _buildProgressSummaryCard(provider),
          const SizedBox(height: 16),
          _buildCompetencyOverview(provider),
          const SizedBox(height: 16),
          _buildRecentAchievements(provider),
          const SizedBox(height: 16),
          _buildComparisonCard(provider),
        ],
      ),
    );
  }

  Widget _buildChartsTab(ProgressProvider provider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          FutureBuilder<List<ChartDataPoint>>(
            future:
                provider.getTemporalChartData(widget.userId, _selectedRange),
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                return EnhancedTemporalChart(
                  chartData: snapshot.data!,
                  title: _translate(context, 'progress_temporal_evolution'),
                );
              }
              return const CircularProgressIndicator();
            },
          ),
          const SizedBox(height: 16),
          CompetencyAnalysisChart(
            competencyAnalysis: provider.competencyAnalysis,
          ),
          const SizedBox(height: 16),
          ActivityHeatmapWidget(
            progressHistory: provider.progressHistory,
          ),
        ],
      ),
    );
  }

  Widget _buildAchievementsTab(ProgressProvider provider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          _buildAchievementStats(provider),
          const SizedBox(height: 16),
          AchievementGrid(
            achievements: provider.achievements,
            title: _translate(context, 'progress_all_achievements'),
            crossAxisCount: 2,
          ),
          const SizedBox(height: 16),
          _buildAchievementsByCategory(provider),
        ],
      ),
    );
  }

  Widget _buildQuickStats(ProgressProvider provider) {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            _translate(context, 'progress_total_essays'),
            provider.totalEssaysCount.toString(),
            Icons.edit,
            Colors.blue,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildStatCard(
            _translate(context, 'progress_average_score'),
            provider.averageScore.toStringAsFixed(0),
            Icons.star,
            Colors.amber,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildStatCard(
            _translate(context, 'progress_best_score'),
            provider.bestScore.toString(),
            Icons.trending_up,
            Colors.green,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildStatCard(
            _translate(context, 'progress_achievements'),
            provider.unlockedAchievementsCount.toString(),
            Icons.emoji_events,
            Colors.orange,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(
              value,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
            ),
            Text(
              title,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressSummaryCard(ProgressProvider provider) {
    final summary = provider.currentSummary;
    if (summary == null) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _translate(context, 'progress_summary_last_30_days'),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSummaryItem(
                  _translate(context, 'progress_essays'),
                  summary.totalEssays.toString(),
                  Colors.blue,
                ),
                _buildSummaryItem(
                  _translate(context, 'progress_average'),
                  summary.averageScore.toStringAsFixed(0),
                  Colors.green,
                ),
                _buildSummaryItem(
                  _translate(context, 'progress_improvement'),
                  '${summary.improvementTrend > 0 ? '+' : ''}${summary.improvementTrend.toStringAsFixed(0)}',
                  summary.improvementTrend > 0 ? Colors.green : Colors.red,
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (summary.strongestCompetency != null)
              Text(
                _translateWith(
                  context,
                  'progress_strongest_competency',
                  {
                    'competency': _localizedCompetencyName(
                      context,
                      summary.strongestCompetency!,
                    ),
                  },
                ),
                style: const TextStyle(color: Colors.green),
              ),
            if (summary.weakestCompetency != null)
              Text(
                _translateWith(
                  context,
                  'progress_competency_to_improve',
                  {
                    'competency': _localizedCompetencyName(
                      context,
                      summary.weakestCompetency!,
                    ),
                  },
                ),
                style: const TextStyle(color: Colors.orange),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildCompetencyOverview(ProgressProvider provider) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _translate(context, 'progress_competency_overview'),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            FutureBuilder<Map<String, double>>(
              future: provider.getRadarChartData(widget.userId),
              builder: (context, snapshot) {
                if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                  final competencyScores = snapshot.data!.map(
                    (key, value) => MapEntry(key, value.round()),
                  );

                  return Center(
                    child: CompetencyRadarChart(
                      competencyScores: competencyScores,
                      size: 200,
                      animated: true,
                    ),
                  );
                }
                return Center(
                  child: Text(
                    _translate(context, 'progress_insufficient_radar_data'),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentAchievements(ProgressProvider provider) {
    final recentAchievements = provider.getRecentAchievements();

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
              maxVisible: 5,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComparisonCard(ProgressProvider provider) {
    final comparison = provider.comparisonData;
    if (comparison == null) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _translate(context, 'progress_compare_users'),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildComparisonItem(
                  _translate(context, 'progress_your_average'),
                  comparison.userAverage.toStringAsFixed(0),
                  Colors.blue,
                ),
                _buildComparisonItem(
                  _translate(context, 'progress_peer_average'),
                  comparison.peerAverage.toStringAsFixed(0),
                  Colors.grey,
                ),
                _buildComparisonItem(
                  _translate(context, 'progress_percentile'),
                  '${comparison.percentile.toStringAsFixed(0)}%',
                  comparison.percentile >= 70 ? Colors.green : Colors.orange,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                _translateWith(
                  context,
                  'progress_ranking',
                  {
                    'ranking': _localizedRanking(
                      context,
                      comparison.percentile,
                    ),
                  },
                ),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: comparison.percentile >= 70
                      ? Colors.green
                      : Colors.orange,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComparisonItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildAchievementStats(ProgressProvider provider) {
    final totalAchievements = 20; // This would come from a predefined list
    final unlockedCount = provider.unlockedAchievementsCount;
    final progress = unlockedCount / totalAchievements;

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
                'progress_achievements_unlocked_with_percentage',
                {
                  'unlocked': MaterialLocalizations.of(context)
                      .formatDecimal(unlockedCount),
                  'total': MaterialLocalizations.of(context)
                      .formatDecimal(totalAchievements),
                  'percentage': (progress * 100).toStringAsFixed(0),
                },
              ),
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAchievementsByCategory(ProgressProvider provider) {
    final categories = AchievementCategory.values;

    return Column(
      children: categories.map((category) {
        final categoryAchievements =
            provider.getAchievementsByCategory(category);

        if (categoryAchievements.isEmpty) {
          return const SizedBox.shrink();
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: AchievementGrid(
            achievements: categoryAchievements,
            title: _localizedCategory(context, category),
            crossAxisCount: 3,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildErrorState(String _) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red,
          ),
          const SizedBox(height: 16),
          Text(
            _translate(context, 'progress_load_error_title'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            _translate(context, 'progress_load_error'),
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _refreshData,
            child: Text(_translate(context, 'try_again')),
          ),
        ],
      ),
    );
  }

  void _showDateRangePicker() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_translate(context, 'progress_select_period')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(_translate(context, 'progress_last_week')),
              onTap: () {
                setState(() {
                  _selectedRange = DateRange.lastWeek();
                });
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: Text(_translate(context, 'progress_last_month')),
              onTap: () {
                setState(() {
                  _selectedRange = DateRange.lastMonth();
                });
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: Text(_translate(context, 'progress_last_three_months')),
              onTap: () {
                setState(() {
                  _selectedRange = DateRange.lastQuarter();
                });
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: Text(_translate(context, 'progress_this_year')),
              onTap: () {
                setState(() {
                  final now = DateTime.now();
                  _selectedRange = DateRange(
                    start: DateTime(now.year),
                    end: now,
                  );
                });
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showPerformanceReport() async {
    final provider = context.read<ProgressProvider>();

    // Generate performance report
    await provider.generatePerformanceReport(widget.userId, _selectedRange);

    if (provider.performanceReport != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PerformanceReportWidget(
            report: provider.performanceReport!,
            userId: widget.userId,
            onRefresh: _refreshData,
          ),
        ),
      );
    }
  }

  void _refreshData() {
    context.read<ProgressProvider>().refresh(widget.userId);
  }
}

String _localizedCompetencyName(BuildContext context, String value) {
  final match = RegExp(r'([1-5])').firstMatch(value);
  if (match == null) return value;
  return _translateWith(
    context,
    'progress_competency_number',
    {'number': match.group(1)!},
  );
}

String _localizedCategory(
  BuildContext context,
  AchievementCategory category,
) {
  final key = switch (category) {
    AchievementCategory.milestone => 'milestone',
    AchievementCategory.consistency => 'consistency',
    AchievementCategory.improvement => 'improvement',
    AchievementCategory.excellence => 'excellence',
    AchievementCategory.dedication => 'dedication',
    AchievementCategory.competency => 'competency',
  };
  return _translate(context, 'progress_achievement_category_$key');
}

String _localizedRanking(BuildContext context, double percentile) {
  final key = percentile >= 90
      ? 'excellent'
      : percentile >= 80
          ? 'very_good'
          : percentile >= 70
              ? 'good'
              : percentile >= 60
                  ? 'regular'
                  : 'needs_improvement';
  return _translate(context, 'progress_level_$key');
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
