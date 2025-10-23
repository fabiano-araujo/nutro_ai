import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/progress_tracker.dart';
import '../services/auth_service.dart';
import '../models/essay_progress.dart';
import '../models/progress_summary.dart';
import '../models/achievement.dart';
import '../widgets/progress_chart.dart';
import '../widgets/achievement_display.dart';
import '../widgets/competency_performance_report.dart';

/// Screen that displays comprehensive progress analytics and achievements
class ProgressAnalyticsScreen extends StatefulWidget {
  const ProgressAnalyticsScreen({Key? key}) : super(key: key);

  @override
  State<ProgressAnalyticsScreen> createState() => _ProgressAnalyticsScreenState();
}

class _ProgressAnalyticsScreenState extends State<ProgressAnalyticsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ProgressTracker _progressTracker = ProgressTracker();
  
  List<ProgressPoint> _progressHistory = [];
  List<Achievement> _achievements = [];
  ProgressSummary _summary = ProgressSummary.empty();
  DateRange _selectedRange = DateRange.lastMonth();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final userId = authService.currentUser?.id.toString() ?? 'anonymous';
      
      // Load progress history
      _progressHistory = await _progressTracker.getProgressHistory(userId);
      
      // Load achievements
      _achievements = await _progressTracker.getUserAchievements(userId);
      
      // Calculate summary for selected range
      _summary = await _progressTracker.calculateSummary(userId, _selectedRange);
      
      // Check for new achievements
      final newAchievements = await _progressTracker.checkAchievements(userId);
      if (newAchievements.isNotEmpty) {
        _showNewAchievements(newAchievements);
        // Reload achievements to include new ones
        _achievements = await _progressTracker.getUserAchievements(userId);
      }
    } catch (e) {
      print('Error loading progress data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao carregar dados de progresso: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showNewAchievements(List<Achievement> newAchievements) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.emoji_events, color: Colors.amber, size: 28),
              SizedBox(width: 8),
              Text('Nova Conquista!'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: newAchievements.map((achievement) {
              return ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: Colors.amber,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.star, color: Colors.white),
                ),
                title: Text(achievement.title),
                subtitle: Text(achievement.description),
              );
            }).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Continuar'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Progresso e Analytics'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.analytics), text: 'Gráficos'),
            Tab(icon: Icon(Icons.emoji_events), text: 'Conquistas'),
            Tab(icon: Icon(Icons.assessment), text: 'Relatórios'),
          ],
        ),
        actions: [
          PopupMenuButton<DateRange>(
            icon: const Icon(Icons.date_range),
            onSelected: (DateRange range) {
              setState(() {
                _selectedRange = range;
              });
              _loadData();
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem(
                value: null,
                child: Text('Período', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              PopupMenuItem(
                value: DateRange.lastWeek(),
                child: const Text('Última semana'),
              ),
              PopupMenuItem(
                value: DateRange.lastMonth(),
                child: const Text('Último mês'),
              ),
              PopupMenuItem(
                value: DateRange.lastQuarter(),
                child: const Text('Últimos 3 meses'),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildChartsTab(),
                _buildAchievementsTab(),
                _buildReportsTab(),
              ],
            ),
    );
  }

  Widget _buildChartsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          _buildSummaryCards(),
          const SizedBox(height: 16),
          ProgressChart(
            progressData: _progressHistory.where((p) =>
                p.date.isAfter(_selectedRange.start) &&
                p.date.isBefore(_selectedRange.end)
            ).toList(),
            title: 'Evolução da Pontuação Total',
            chartType: ChartType.line,
            primaryColor: Theme.of(context).primaryColor,
          ),
          const SizedBox(height: 16),
          ProgressChart(
            progressData: _progressHistory.where((p) =>
                p.date.isAfter(_selectedRange.start) &&
                p.date.isBefore(_selectedRange.end)
            ).toList(),
            title: 'Desempenho por Competência',
            chartType: ChartType.competency,
            primaryColor: Theme.of(context).primaryColor,
          ),
        ],
      ),
    );
  }

  Widget _buildAchievementsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          AchievementDisplay(
            achievements: _achievements,
            showProgress: true,
            onViewAll: () {
              // Navigate to detailed achievements screen
            },
          ),
          const SizedBox(height: 16),
          _buildAchievementStats(),
        ],
      ),
    );
  }

  Widget _buildReportsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          CompetencyPerformanceReport(
            summary: _summary,
            recentProgress: _progressHistory.where((p) =>
                p.date.isAfter(_selectedRange.start) &&
                p.date.isBefore(_selectedRange.end)
            ).toList(),
            onCompetencyTap: () {
              // Navigate to detailed competency analysis
            },
          ),
          const SizedBox(height: 16),
          _buildComparisonCard(),
        ],
      ),
    );
  }

  Widget _buildSummaryCards() {
    return Row(
      children: [
        Expanded(
          child: _buildSummaryCard(
            'Total de Redações',
            _summary.totalEssays.toString(),
            Icons.edit,
            Colors.blue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSummaryCard(
            'Média Geral',
            _summary.averageScore.toStringAsFixed(1),
            Icons.analytics,
            Colors.green,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSummaryCard(
            'Conquistas',
            _achievements.length.toString(),
            Icons.emoji_events,
            Colors.amber,
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

  Widget _buildAchievementStats() {
    final categoryStats = <AchievementCategory, int>{};
    for (final achievement in _achievements) {
      categoryStats[achievement.category] = (categoryStats[achievement.category] ?? 0) + 1;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Conquistas por Categoria',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ...categoryStats.entries.map((entry) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(entry.key.displayName),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        entry.value.toString(),
                        style: TextStyle(
                          color: Theme.of(context).primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildComparisonCard() {
    return FutureBuilder(
      future: _progressTracker.compareWithPeers(
        Provider.of<AuthService>(context, listen: false).currentUser?.id.toString() ?? 'anonymous'
      ),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        final comparison = snapshot.data!;
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
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        Text(
                          'Sua Média',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        Text(
                          comparison.userAverage.toStringAsFixed(1),
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      children: [
                        Text(
                          'Média Geral',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        Text(
                          comparison.peerAverage.toStringAsFixed(1),
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      children: [
                        Text(
                          'Percentil',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        Text(
                          '${comparison.percentile.toStringAsFixed(0)}%',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: comparison.isAboveAverage ? Colors.green : Colors.orange,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: comparison.isAboveAverage 
                        ? Colors.green.withOpacity(0.1)
                        : Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    comparison.isAboveAverage
                        ? 'Você está acima da média! Continue assim!'
                        : 'Continue praticando para melhorar sua posição!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: comparison.isAboveAverage ? Colors.green : Colors.orange,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}