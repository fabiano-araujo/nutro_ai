import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../i18n/app_localizations.dart';
import '../models/essay_progress.dart';

/// Widget that displays progress charts over time
class ProgressChart extends StatelessWidget {
  final List<ProgressPoint> progressData;
  final String title;
  final ChartType chartType;
  final Color primaryColor;
  final Color secondaryColor;

  const ProgressChart({
    Key? key,
    required this.progressData,
    required this.title,
    this.chartType = ChartType.line,
    this.primaryColor = Colors.blue,
    this.secondaryColor = Colors.lightBlue,
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
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: _buildChart(context),
            ),
            const SizedBox(height: 8),
            _buildLegend(context),
          ],
        ),
      ),
    );
  }

  Widget _buildChart(BuildContext context) {
    if (progressData.isEmpty) {
      return Center(
        child: Text(_translate(context, 'progress_no_data_available')),
      );
    }

    switch (chartType) {
      case ChartType.line:
        return _buildLineChart(context);
      case ChartType.bar:
        return _buildBarChart(context);
      case ChartType.competency:
        return _buildCompetencyChart(context);
    }
  }

  Widget _buildLineChart(BuildContext context) {
    final spots = progressData.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), entry.value.totalScore.toDouble());
    }).toList();

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: true,
          horizontalInterval: 100,
          verticalInterval: 1,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: Colors.grey.withOpacity(0.3),
              strokeWidth: 1,
            );
          },
          getDrawingVerticalLine: (value) {
            return FlLine(
              color: Colors.grey.withOpacity(0.3),
              strokeWidth: 1,
            );
          },
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: 1,
              getTitlesWidget: (double value, TitleMeta meta) {
                final index = value.toInt();
                if (index >= 0 && index < progressData.length) {
                  final date = progressData[index].date;
                  return SideTitleWidget(
                    meta: meta,
                    child: Text(
                      MaterialLocalizations.of(context).formatShortDate(date),
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
              getTitlesWidget: (double value, TitleMeta meta) {
                return Text(
                  value.toInt().toString(),
                  style: const TextStyle(
                    color: Colors.grey,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                );
              },
              reservedSize: 42,
            ),
          ),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border.all(color: const Color(0xff37434d)),
        ),
        minX: 0,
        maxX: (progressData.length - 1).toDouble(),
        minY: 0,
        maxY: 1000,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            gradient: LinearGradient(
              colors: [primaryColor, secondaryColor],
            ),
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                return FlDotCirclePainter(
                  radius: 4,
                  color: primaryColor,
                  strokeWidth: 2,
                  strokeColor: Colors.white,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  primaryColor.withOpacity(0.3),
                  secondaryColor.withOpacity(0.1),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBarChart(BuildContext context) {
    final barGroups = progressData.asMap().entries.map((entry) {
      return BarChartGroupData(
        x: entry.key,
        barRods: [
          BarChartRodData(
            toY: entry.value.totalScore.toDouble(),
            color: primaryColor,
            width: 16,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(4),
              topRight: Radius.circular(4),
            ),
          ),
        ],
      );
    }).toList();

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: 1000,
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => Colors.blueGrey,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final date = progressData[group.x.toInt()].date;
              final points = rod.toY.round();
              return BarTooltipItem(
                '${MaterialLocalizations.of(context).formatShortDate(date)}\n',
                const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
                children: <TextSpan>[
                  TextSpan(
                    text: _translateWith(
                      context,
                      points == 1
                          ? 'progress_data_points_one'
                          : 'progress_data_points_other',
                      {
                        'count': MaterialLocalizations.of(context)
                            .formatDecimal(points),
                      },
                    ),
                    style: const TextStyle(
                      color: Colors.yellow,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (double value, TitleMeta meta) {
                final index = value.toInt();
                if (index >= 0 && index < progressData.length) {
                  final date = progressData[index].date;
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      MaterialLocalizations.of(context).formatShortDate(date),
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
              reservedSize: 30,
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 42,
              interval: 200,
              getTitlesWidget: (double value, TitleMeta meta) {
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
          show: false,
        ),
        barGroups: barGroups,
        gridData: FlGridData(show: false),
      ),
    );
  }

  Widget _buildCompetencyChart(BuildContext context) {
    if (progressData.isEmpty) {
      return Center(
        child: Text(_translate(context, 'progress_no_data_available')),
      );
    }

    // Calculate average scores for each competency
    final competencyAverages = <String, double>{};
    final competencyNames = List.generate(
      5,
      (index) => _translateWith(
        context,
        'progress_competency_number',
        {'number': '${index + 1}'},
      ),
    );

    for (int i = 1; i <= 5; i++) {
      final key = 'competencia$i';
      final scores = progressData
          .map((p) => p.competencyScores[key] ?? 0)
          .where((score) => score > 0)
          .toList();

      if (scores.isNotEmpty) {
        competencyAverages[competencyNames[i - 1]] =
            scores.reduce((a, b) => a + b) / scores.length;
      } else {
        competencyAverages[competencyNames[i - 1]] = 0.0;
      }
    }

    final barGroups = competencyAverages.entries.map((entry) {
      final index = competencyNames.indexOf(entry.key);
      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: entry.value,
            color: _getCompetencyColor(index),
            width: 20,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(4),
              topRight: Radius.circular(4),
            ),
          ),
        ],
      );
    }).toList();

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: 200,
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => Colors.blueGrey,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final competencyName = competencyNames[group.x.toInt()];
              final points = rod.toY.round();
              return BarTooltipItem(
                '$competencyName\n',
                const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
                children: <TextSpan>[
                  TextSpan(
                    text: _translateWith(
                      context,
                      points == 1
                          ? 'progress_data_points_one'
                          : 'progress_data_points_other',
                      {
                        'count': MaterialLocalizations.of(context)
                            .formatDecimal(points),
                      },
                    ),
                    style: const TextStyle(
                      color: Colors.yellow,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (double value, TitleMeta meta) {
                final index = value.toInt();
                if (index >= 0 && index < competencyNames.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      _translateWith(
                        context,
                        'progress_competency_short',
                        {'number': '${index + 1}'},
                      ),
                      style: const TextStyle(
                        color: Colors.grey,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  );
                }
                return Container();
              },
              reservedSize: 30,
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 42,
              interval: 40,
              getTitlesWidget: (double value, TitleMeta meta) {
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
        borderData: FlBorderData(show: false),
        barGroups: barGroups,
        gridData: FlGridData(show: false),
      ),
    );
  }

  Widget _buildLegend(BuildContext context) {
    if (chartType != ChartType.competency) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: primaryColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _translate(context, 'progress_total_score'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      );
    }

    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: List.generate(5, (index) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: _getCompetencyColor(index),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              _translateWith(
                context,
                'progress_competency_short',
                {'number': '${index + 1}'},
              ),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        );
      }),
    );
  }

  Color _getCompetencyColor(int index) {
    final colors = [
      Colors.red,
      Colors.orange,
      Colors.yellow,
      Colors.green,
      Colors.blue,
    ];
    return colors[index % colors.length];
  }
}

/// Types of charts available
enum ChartType {
  line,
  bar,
  competency,
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
