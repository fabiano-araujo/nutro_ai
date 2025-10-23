import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/progress_provider.dart';
import '../widgets/enhanced_progress_charts.dart';
import '../widgets/competency_radar_chart.dart';
import '../widgets/achievement_widgets.dart';
import '../widgets/performance_report_widget.dart';
import '../models/essay_progress.dart';
import '../services/enhanced_progress_tracker.dart';

/// Main progress dashboard screen
class ProgressDashboardScreen extends StatefulWidget {
  final String userId;

  const ProgressDashboardScreen({
    Key? key,
    required this.userId,
  }) : super(key: key);

  @override
  State<ProgressDashboardScreen> createState() => _ProgressDashboardScreenState();
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
        title: const Text('Progresso e Analytics'),
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range),
            onPressed: _showDateRangePicker,
          ),
          IconButton(
            icon: const Icon(Icons.assessment),
            onPressed: _showPerformanceReport,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshData,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard), text: 'Visão Geral'),
            Tab(icon: Icon(Icons.show_chart), text: 'Gráficos'),
            Tab(icon: Icon(Icons.emoji_events), text: 'Conquistas'),
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
            future: provider.getTemporalChartData(widget.userId, _selectedRange),
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                return EnhancedTemporalChart(
                  chartData: snapshot.data!,
                  title: 'Evolução Temporal',
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
            title: 'Todas as Conquistas',
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
            'Total de Redações',
            provider.totalEssaysCount.toString(),
            Icons.edit,
            Colors.blue,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildStatCard(
            'Pontuação Média',
            provider.averageScore.toStringAsFixed(0),
            Icons.star,
            Colors.amber,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildStatCard(
            'Melhor Nota',
            provider.bestScore.toString(),
            Icons.trending_up,
            Colors.green,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildStatCard(
            'Conquistas',
            provider.unlockedAchievementsCount.toString(),
            Icons.emoji_events,
            Colors.orange,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
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
              'Resumo do Progresso (Últimos 30 dias)',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSummaryItem(
                  'Redações',
                  summary.totalEssays.toString(),
                  Colors.blue,
                ),
                _buildSummaryItem(
                  'Média',
                  summary.averageScore.toStringAsFixed(0),
                  Colors.green,
                ),
                _buildSummaryItem(
                  'Melhoria',
                  '${summary.improvementTrend > 0 ? '+' : ''}${summary.improvementTrend.toStringAsFixed(0)}',
                  summary.improvementTrend > 0 ? Colors.green : Colors.red,
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (summary.strongestCompetency != null)
              Text(
                'Competência mais forte: ${summary.strongestCompetency}',
                style: const TextStyle(color: Colors.green),
              ),
            if (summary.weakestCompetency != null)
              Text(
                'Competência para melhorar: ${summary.weakestCompetency}',
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
              'Visão Geral das Competências',
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
                return const Center(
                  child: Text('Dados insuficientes para exibir o radar'),
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
              'Conquistas Recentes',
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
              'Comparação com Outros Usuários',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildComparisonItem(
                  'Sua Média',
                  comparison.userAverage.toStringAsFixed(0),
                  Colors.blue,
                ),
                _buildComparisonItem(
                  'Média Geral',
                  comparison.peerAverage.toStringAsFixed(0),
                  Colors.grey,
                ),
                _buildComparisonItem(
                  'Percentil',
                  '${comparison.percentile.toStringAsFixed(0)}%',
                  comparison.percentile >= 70 ? Colors.green : Colors.orange,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                'Classificação: ${comparison.ranking}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: comparison.percentile >= 70 ? Colors.green : Colors.orange,
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
              '$unlockedCount de $totalAchievements conquistas desbloqueadas (${(progress * 100).toStringAsFixed(0)}%)',
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
        final categoryAchievements = provider.getAchievementsByCategory(category);
        
        if (categoryAchievements.isEmpty) {
          return const SizedBox.shrink();
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: AchievementGrid(
            achievements: categoryAchievements,
            title: category.displayName,
            crossAxisCount: 3,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildErrorState(String error) {
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
            'Erro ao carregar dados',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            error,
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _refreshData,
            child: const Text('Tentar Novamente'),
          ),
        ],
      ),
    );
  }

  void _showDateRangePicker() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Selecionar Período'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Última Semana'),
              onTap: () {
                setState(() {
                  _selectedRange = DateRange.lastWeek();
                });
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('Último Mês'),
              onTap: () {
                setState(() {
                  _selectedRange = DateRange.lastMonth();
                });
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('Últimos 3 Meses'),
              onTap: () {
                setState(() {
                  _selectedRange = DateRange.lastQuarter();
                });
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('Este Ano'),
              onTap: () {
                setState(() {
                  _selectedRange = DateRange.currentYear();
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