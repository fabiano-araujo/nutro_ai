import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/essay_progress.dart';
import '../services/enhanced_progress_tracker.dart';
import '../utils/date_time_utils.dart';

/// Enhanced temporal progress chart with multiple visualization options
class EnhancedTemporalChart extends StatefulWidget {
  final List<ChartDataPoint> chartData;
  final String title;
  final Color primaryColor;
  final Color secondaryColor;
  final double height;
  final bool showTrendLine;
  final bool showDataPoints;

  const EnhancedTemporalChart({
    Key? key,
    required this.chartData,
    this.title = 'Evolução Temporal',
    this.primaryColor = Colors.blue,
    this.secondaryColor = Colors.lightBlue,
    this.height = 250,
    this.showTrendLine = true,
    this.showDataPoints = true,
  }) : super(key: key);

  @override
  State<EnhancedTemporalChart> createState() => _EnhancedTemporalChartState();
}

class _EnhancedTemporalChartState extends State<EnhancedTemporalChart>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.chartData.isEmpty) {
      return _buildEmptyState();
    }

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 16),
            SizedBox(
              height: widget.height,
              child: AnimatedBuilder(
                animation: _animation,
                builder: (context, child) {
                  return LineChart(_buildLineChartData());
                },
              ),
            ),
            const SizedBox(height: 16),
            _buildStatistics(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          widget.title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: widget.primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '${widget.chartData.length} pontos',
            style: TextStyle(
              color: widget.primaryColor,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Card(
      elevation: 4,
      child: Container(
        height: widget.height + 100,
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.show_chart,
              size: 48,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Nenhum dado disponível',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Complete algumas redações para ver seu progresso',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  LineChartData _buildLineChartData() {
    final spots = widget.chartData.asMap().entries.map((entry) {
      return FlSpot(
        entry.key.toDouble(),
        entry.value.value * _animation.value,
      );
    }).toList();

    return LineChartData(
      gridData: FlGridData(
        show: true,
        drawVerticalLine: true,
        horizontalInterval: 100,
        verticalInterval: widget.chartData.length > 10 ? 2 : 1,
        getDrawingHorizontalLine: (value) => FlLine(
          color: Colors.grey.withOpacity(0.2),
          strokeWidth: 1,
        ),
        getDrawingVerticalLine: (value) => FlLine(
          color: Colors.grey.withOpacity(0.2),
          strokeWidth: 1,
        ),
      ),
      titlesData: FlTitlesData(
        show: true,
        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 30,
            interval: widget.chartData.length > 10 ? 2 : 1,
            getTitlesWidget: (value, meta) {
              final index = value.toInt();
              if (index >= 0 && index < widget.chartData.length) {
                final date = widget.chartData[index].date;
                return SideTitleWidget(
                  axisSide: meta.axisSide,
                  child: Text(
                    DateTimeUtils.formatShortDate(date),
                    style: const TextStyle(
                      color: Colors.grey,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                );
              }
              return Container();
            },
          ),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            interval: 100,
            reservedSize: 42,
            getTitlesWidget: (value, meta) {
              return Text(
                value.toInt().toString(),
                style: const TextStyle(
                  color: Colors.grey,
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                ),
              );
            },
          ),
        ),
      ),
      borderData: FlBorderData(
        show: true,
        border: Border.all(color: Colors.grey.withOpacity(0.3)),
      ),
      minX: 0,
      maxX: (widget.chartData.length - 1).toDouble(),
      minY: 0,
      maxY: 1000,
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: true,
          gradient: LinearGradient(
            colors: [widget.primaryColor, widget.secondaryColor],
          ),
          barWidth: 3,
          isStrokeCapRound: true,
          dotData: FlDotData(
            show: widget.showDataPoints,
            getDotPainter: (spot, percent, barData, index) {
              return FlDotCirclePainter(
                radius: 4,
                color: widget.primaryColor,
                strokeWidth: 2,
                strokeColor: Colors.white,
              );
            },
          ),
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
              colors: [
                widget.primaryColor.withOpacity(0.3),
                widget.secondaryColor.withOpacity(0.1),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
      ],
      lineTouchData: LineTouchData(
        enabled: true,
        touchTooltipData: LineTouchTooltipData(
          tooltipBgColor: Colors.blueGrey,
          getTooltipItems: (touchedSpots) {
            return touchedSpots.map((spot) {
              final index = spot.x.toInt();
              if (index >= 0 && index < widget.chartData.length) {
                final dataPoint = widget.chartData[index];
                return LineTooltipItem(
                  '${DateTimeUtils.formatDisplayDate(dataPoint.date)}\n',
                  const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                  children: [
                    TextSpan(
                      text: '${dataPoint.value.toStringAsFixed(0)} pontos',
                      style: const TextStyle(
                        color: Colors.yellow,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (dataPoint.count > 1)
                      TextSpan(
                        text: '\n${dataPoint.count} redações',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 10,
                        ),
                      ),
                  ],
                );
              }
              return null;
            }).toList();
          },
        ),
      ),
    );
  }

  Widget _buildStatistics() {
    final values = widget.chartData.map((d) => d.value).toList();
    final minValue = values.reduce((a, b) => a < b ? a : b);
    final maxValue = values.reduce((a, b) => a > b ? a : b);
    final avgValue = values.reduce((a, b) => a + b) / values.length;
    final totalEssays = widget.chartData.map((d) => d.count).reduce((a, b) => a + b);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildStatItem('Mín', minValue.toStringAsFixed(0), Colors.red),
        _buildStatItem('Máx', maxValue.toStringAsFixed(0), Colors.green),
        _buildStatItem('Média', avgValue.toStringAsFixed(0), widget.primaryColor),
        _buildStatItem('Total', totalEssays.toString(), Colors.orange),
      ],
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}

/// Enhanced competency analysis chart
class CompetencyAnalysisChart extends StatefulWidget {
  final Map<String, CompetencyAnalysis> competencyAnalysis;
  final String title;
  final double height;

  const CompetencyAnalysisChart({
    Key? key,
    required this.competencyAnalysis,
    this.title = 'Análise por Competência',
    this.height = 300,
  }) : super(key: key);

  @override
  State<CompetencyAnalysisChart> createState() => _CompetencyAnalysisChartState();
}

class _CompetencyAnalysisChartState extends State<CompetencyAnalysisChart>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.competencyAnalysis.isEmpty) {
      return _buildEmptyState();
    }

    final sortedCompetencies = widget.competencyAnalysis.entries.toList()
      ..sort((a, b) => b.value.averageScore.compareTo(a.value.averageScore));

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: widget.height,
              child: AnimatedBuilder(
                animation: _animation,
                builder: (context, child) {
                  return ListView.builder(
                    itemCount: sortedCompetencies.length,
                    itemBuilder: (context, index) {
                      final entry = sortedCompetencies[index];
                      return _buildCompetencyItem(entry.key, entry.value, index);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Card(
      elevation: 4,
      child: Container(
        height: widget.height + 80,
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.analytics,
              size: 48,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Nenhuma análise disponível',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompetencyItem(String competencyKey, CompetencyAnalysis analysis, int index) {
    final percentage = (analysis.averageScore / 200.0).clamp(0.0, 1.0);
    final color = _getCompetencyColor(index);
    final trendIcon = _getTrendIcon(analysis.trend);
    final trendColor = _getTrendColor(analysis.trend);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  analysis.competencyName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
              Row(
                children: [
                  Icon(trendIcon, size: 16, color: trendColor),
                  const SizedBox(width: 4),
                  Text(
                    analysis.averageScore.toStringAsFixed(0),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            height: 8,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(4),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: percentage * _animation.value,
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildConsistencyIndicator(analysis.consistency),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  _getPerformanceDescription(analysis.averageScore),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildConsistencyIndicator(double consistency) {
    final consistencyColor = consistency > 0.8 
        ? Colors.green 
        : consistency > 0.6 
            ? Colors.orange 
            : Colors.red;

    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: consistencyColor,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          'Consistência: ${(consistency * 100).toStringAsFixed(0)}%',
          style: TextStyle(
            fontSize: 11,
            color: consistencyColor,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Color _getCompetencyColor(int index) {
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.red,
    ];
    return colors[index % colors.length];
  }

  IconData _getTrendIcon(double trend) {
    if (trend > 5) return Icons.trending_up;
    if (trend < -5) return Icons.trending_down;
    return Icons.trending_flat;
  }

  Color _getTrendColor(double trend) {
    if (trend > 5) return Colors.green;
    if (trend < -5) return Colors.red;
    return Colors.grey;
  }

  String _getPerformanceDescription(double score) {
    if (score >= 180) return 'Excelente desempenho';
    if (score >= 160) return 'Muito bom desempenho';
    if (score >= 140) return 'Bom desempenho';
    if (score >= 120) return 'Desempenho regular';
    return 'Precisa melhorar';
  }
}

/// Activity heatmap widget
class ActivityHeatmapWidget extends StatefulWidget {
  final List<ProgressPoint> progressHistory;
  final String title;
  final double height;
  final int daysToShow;

  const ActivityHeatmapWidget({
    Key? key,
    required this.progressHistory,
    this.title = 'Atividade de Escrita',
    this.height = 120,
    this.daysToShow = 90,
  }) : super(key: key);

  @override
  State<ActivityHeatmapWidget> createState() => _ActivityHeatmapWidgetState();
}

class _ActivityHeatmapWidgetState extends State<ActivityHeatmapWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                _buildActivitySummary(),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: widget.height,
              child: AnimatedBuilder(
                animation: _animation,
                builder: (context, child) {
                  return _buildHeatmapGrid();
                },
              ),
            ),
            const SizedBox(height: 8),
            _buildHeatmapLegend(),
          ],
        ),
      ),
    );
  }

  Widget _buildActivitySummary() {
    final now = DateTime.now();
    final thisWeek = widget.progressHistory.where((p) => 
        DateTimeUtils.isThisWeek(p.date)).length;
    final thisMonth = widget.progressHistory.where((p) => 
        DateTimeUtils.isThisMonth(p.date)).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          'Esta semana: $thisWeek',
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
        Text(
          'Este mês: $thisMonth',
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildHeatmapGrid() {
    final now = DateTime.now();
    final startDate = now.subtract(Duration(days: widget.daysToShow));
    final activityMap = <String, int>{};

    // Count activities per day
    for (final point in widget.progressHistory) {
      if (point.date.isAfter(startDate)) {
        final dateKey = DateTimeUtils.formatDate(point.date, 'yyyy-MM-dd');
        activityMap[dateKey] = (activityMap[dateKey] ?? 0) + 1;
      }
    }

    final weeks = (widget.daysToShow / 7).ceil();
    
    return GridView.builder(
      scrollDirection: Axis.horizontal,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7, // 7 days of the week
        childAspectRatio: 1,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
      ),
      itemCount: widget.daysToShow,
      itemBuilder: (context, index) {
        final date = startDate.add(Duration(days: index));
        final dateKey = DateTimeUtils.formatDate(date, 'yyyy-MM-dd');
        final activity = activityMap[dateKey] ?? 0;
        
        return AnimatedContainer(
          duration: Duration(milliseconds: 100 + (index * 10)),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: _getHeatmapColor(activity).withOpacity(_animation.value),
            borderRadius: BorderRadius.circular(2),
          ),
          child: Tooltip(
            message: '${DateTimeUtils.formatDisplayDate(date)}: $activity redação${activity != 1 ? 'ões' : ''}',
            child: Container(),
          ),
        );
      },
    );
  }

  Widget _buildHeatmapLegend() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('Menos', style: TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(width: 8),
        ...List.generate(5, (index) => Container(
          width: 12,
          height: 12,
          margin: const EdgeInsets.symmetric(horizontal: 1),
          decoration: BoxDecoration(
            color: _getHeatmapColor(index),
            borderRadius: BorderRadius.circular(2),
          ),
        )),
        const SizedBox(width: 8),
        const Text('Mais', style: TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  Color _getHeatmapColor(int activity) {
    if (activity == 0) return Colors.grey[200]!;
    if (activity == 1) return Colors.green[200]!;
    if (activity == 2) return Colors.green[400]!;
    if (activity >= 3) return Colors.green[600]!;
    return Colors.green[800]!;
  }
}