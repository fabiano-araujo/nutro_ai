import 'package:flutter/material.dart';
import '../models/essay_progress_model.dart';
import '../utils/date_time_utils.dart';

/// Widget para exibir gráfico de linha do progresso temporal
class ProgressLineChart extends StatelessWidget {
  final List<ProgressPoint> progressHistory;
  final String title;
  final Color primaryColor;
  final double height;

  const ProgressLineChart({
    Key? key,
    required this.progressHistory,
    this.title = 'Evolução da Pontuação',
    this.primaryColor = Colors.blue,
    this.height = 200,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (progressHistory.isEmpty) {
      return _buildEmptyState();
    }

    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: height,
              child: CustomPaint(
                painter: _LineChartPainter(
                  progressHistory: progressHistory,
                  primaryColor: primaryColor,
                ),
                child: Container(),
              ),
            ),
            const SizedBox(height: 8),
            _buildLegend(context),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Card(
      elevation: 1,
      child: Container(
        height: height + 80,
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
              'Nenhum dado de progresso disponível',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 16,
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

  Widget _buildLegend(BuildContext context) {
    final minScore = progressHistory.map((p) => p.totalScore).reduce((a, b) => a < b ? a : b);
    final maxScore = progressHistory.map((p) => p.totalScore).reduce((a, b) => a > b ? a : b);
    final avgScore = progressHistory.fold(0, (sum, p) => sum + p.totalScore) / progressHistory.length;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildLegendItem('Mín', minScore.toString(), Colors.red),
        _buildLegendItem('Máx', maxScore.toString(), Colors.green),
        _buildLegendItem('Média', avgScore.toStringAsFixed(0), primaryColor),
      ],
    );
  }

  Widget _buildLegendItem(String label, String value, Color color) {
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
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }
}

/// Widget para exibir gráfico de barras por competência
class CompetencyBarChart extends StatelessWidget {
  final Map<String, CompetencyProgress> competencyProgress;
  final String title;
  final double height;

  const CompetencyBarChart({
    Key? key,
    required this.competencyProgress,
    this.title = 'Progresso por Competência',
    this.height = 250,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (competencyProgress.isEmpty) {
      return _buildEmptyState();
    }

    final sortedCompetencies = competencyProgress.entries.toList()
      ..sort((a, b) => b.value.averageScore.compareTo(a.value.averageScore));

    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: height,
              child: ListView.builder(
                itemCount: sortedCompetencies.length,
                itemBuilder: (context, index) {
                  final entry = sortedCompetencies[index];
                  return _buildCompetencyBar(context, entry.key, entry.value);
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
      elevation: 1,
      child: Container(
        height: height + 80,
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.bar_chart,
              size: 48,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Nenhum dado de competência disponível',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompetencyBar(BuildContext context, String competency, CompetencyProgress progress) {
    final percentage = progress.averageScore / 200.0; // Máximo 200 pontos
    final color = _getColorForScore(progress.averageScore);
    final trendIcon = _getTrendIcon(progress.trend);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  competency,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
              Row(
                children: [
                  Icon(trendIcon, size: 16, color: _getTrendColor(progress.trend)),
                  const SizedBox(width: 4),
                  Text(
                    progress.averageScore.toStringAsFixed(0),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 4),
          Container(
            height: 8,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(4),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: percentage,
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getColorForScore(double score) {
    if (score >= 160) return Colors.green;
    if (score >= 120) return Colors.orange;
    return Colors.red;
  }

  IconData _getTrendIcon(String trend) {
    switch (trend) {
      case 'improving':
        return Icons.trending_up;
      case 'declining':
        return Icons.trending_down;
      default:
        return Icons.trending_flat;
    }
  }

  Color _getTrendColor(String trend) {
    switch (trend) {
      case 'improving':
        return Colors.green;
      case 'declining':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}

/// Widget para exibir heatmap de atividade
class ActivityHeatmap extends StatelessWidget {
  final List<ProgressPoint> progressHistory;
  final String title;
  final double height;

  const ActivityHeatmap({
    Key? key,
    required this.progressHistory,
    this.title = 'Atividade de Escrita',
    this.height = 120,
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
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: height,
              child: _buildHeatmapGrid(context),
            ),
            const SizedBox(height: 8),
            _buildHeatmapLegend(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeatmapGrid(BuildContext context) {
    final now = DateTime.now();
    final startDate = now.subtract(const Duration(days: 90)); // Últimos 3 meses
    final activityMap = <String, int>{};

    // Contar atividades por dia
    for (final point in progressHistory) {
      if (point.date.isAfter(startDate)) {
        final dateKey = DateTimeUtils.formatDate(point.date, 'yyyy-MM-dd');
        activityMap[dateKey] = (activityMap[dateKey] ?? 0) + 1;
      }
    }

    return GridView.builder(
      scrollDirection: Axis.horizontal,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7, // 7 dias da semana
        childAspectRatio: 1,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
      ),
      itemCount: 91, // 13 semanas
      itemBuilder: (context, index) {
        final date = startDate.add(Duration(days: index));
        final dateKey = DateTimeUtils.formatDate(date, 'yyyy-MM-dd');
        final activity = activityMap[dateKey] ?? 0;
        
        return Container(
          decoration: BoxDecoration(
            color: _getHeatmapColor(activity),
            borderRadius: BorderRadius.circular(2),
          ),
          child: Tooltip(
            message: '${DateTimeUtils.formatDate(date, 'dd/MM')}: $activity redação(ões)',
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
        const Text('Menos', style: TextStyle(fontSize: 12)),
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
        const Text('Mais', style: TextStyle(fontSize: 12)),
      ],
    );
  }

  Color _getHeatmapColor(int activity) {
    if (activity == 0) return Colors.grey[200]!;
    if (activity == 1) return Colors.green[200]!;
    if (activity == 2) return Colors.green[400]!;
    if (activity == 3) return Colors.green[600]!;
    return Colors.green[800]!;
  }
}

/// Painter personalizado para o gráfico de linha
class _LineChartPainter extends CustomPainter {
  final List<ProgressPoint> progressHistory;
  final Color primaryColor;

  _LineChartPainter({
    required this.progressHistory,
    required this.primaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progressHistory.isEmpty) return;

    final paint = Paint()
      ..color = primaryColor
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final pointPaint = Paint()
      ..color = primaryColor
      ..style = PaintingStyle.fill;

    final gridPaint = Paint()
      ..color = Colors.grey[300]!
      ..strokeWidth = 0.5;

    // Desenhar grade
    _drawGrid(canvas, size, gridPaint);

    // Calcular pontos
    final points = _calculatePoints(size);

    // Desenhar linha
    final path = Path();
    path.moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    canvas.drawPath(path, paint);

    // Desenhar pontos
    for (final point in points) {
      canvas.drawCircle(point, 4, pointPaint);
    }
  }

  void _drawGrid(Canvas canvas, Size size, Paint paint) {
    // Linhas horizontais
    for (int i = 0; i <= 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }

    // Linhas verticais
    final pointCount = progressHistory.length;
    if (pointCount > 1) {
      for (int i = 0; i <= pointCount - 1; i++) {
        final x = size.width * i / (pointCount - 1);
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
      }
    }
  }

  List<Offset> _calculatePoints(Size size) {
    final minScore = progressHistory.map((p) => p.totalScore).reduce((a, b) => a < b ? a : b);
    final maxScore = progressHistory.map((p) => p.totalScore).reduce((a, b) => a > b ? a : b);
    final scoreRange = maxScore - minScore;

    return progressHistory.asMap().entries.map((entry) {
      final index = entry.key;
      final point = entry.value;

      final x = progressHistory.length > 1 
          ? size.width * index / (progressHistory.length - 1)
          : size.width / 2;

      final normalizedScore = scoreRange > 0 
          ? (point.totalScore - minScore) / scoreRange
          : 0.5;
      final y = size.height * (1 - normalizedScore);

      return Offset(x, y);
    }).toList();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}