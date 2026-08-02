import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../i18n/app_localizations.dart';

class CompetencyRadarChart extends StatefulWidget {
  final Map<String, int> competencyScores;
  final bool animated;
  final double size;
  final Color primaryColor;
  final Color backgroundColor;

  const CompetencyRadarChart({
    Key? key,
    required this.competencyScores,
    this.animated = true,
    this.size = 200,
    this.primaryColor = Colors.blue,
    this.backgroundColor = Colors.grey,
  }) : super(key: key);

  @override
  State<CompetencyRadarChart> createState() => _CompetencyRadarChartState();
}

class _CompetencyRadarChartState extends State<CompetencyRadarChart>
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

    if (widget.animated) {
      _animationController.forward();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localizedScores = widget.competencyScores.map(
      (name, score) => MapEntry(_localizedRadarLabel(context, name), score),
    );

    return Container(
      width: widget.size,
      height: widget.size,
      child: widget.animated
          ? AnimatedBuilder(
              animation: _animation,
              builder: (context, child) {
                return CustomPaint(
                  painter: RadarChartPainter(
                    competencyScores: localizedScores,
                    animationValue: _animation.value,
                    primaryColor: widget.primaryColor,
                    backgroundColor: widget.backgroundColor,
                    textDirection: Directionality.of(context),
                  ),
                );
              },
            )
          : CustomPaint(
              painter: RadarChartPainter(
                competencyScores: localizedScores,
                animationValue: 1.0,
                primaryColor: widget.primaryColor,
                backgroundColor: widget.backgroundColor,
                textDirection: Directionality.of(context),
              ),
            ),
    );
  }
}

class RadarChartPainter extends CustomPainter {
  final Map<String, int> competencyScores;
  final double animationValue;
  final Color primaryColor;
  final Color backgroundColor;
  final TextDirection textDirection;

  RadarChartPainter({
    required this.competencyScores,
    required this.animationValue,
    required this.primaryColor,
    required this.backgroundColor,
    required this.textDirection,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 20;
    final competencies = competencyScores.keys.toList();
    final scores = competencyScores.values.toList();
    final maxScore = 200; // Maximum score per competency

    // Draw background grid
    _drawGrid(canvas, center, radius, competencies.length);

    // Draw competency labels
    _drawLabels(canvas, center, radius, competencies, size);

    // Draw data polygon
    _drawDataPolygon(canvas, center, radius, scores, maxScore);

    // Draw data points
    _drawDataPoints(canvas, center, radius, scores, maxScore);
  }

  void _drawGrid(Canvas canvas, Offset center, double radius, int sides) {
    final paint = Paint()
      ..color = backgroundColor.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    // Draw concentric polygons (grid lines)
    for (int i = 1; i <= 5; i++) {
      final currentRadius = radius * (i / 5);
      _drawPolygon(canvas, center, currentRadius, sides, paint);
    }

    // Draw radial lines
    final radialPaint = Paint()
      ..color = backgroundColor.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (int i = 0; i < sides; i++) {
      final angle = (2 * math.pi * i / sides) - math.pi / 2;
      final endPoint = Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );
      canvas.drawLine(center, endPoint, radialPaint);
    }
  }

  void _drawLabels(Canvas canvas, Offset center, double radius,
      List<String> competencies, Size size) {
    final textPainter = TextPainter(
      textAlign: TextAlign.center,
      textDirection: textDirection,
    );

    for (int i = 0; i < competencies.length; i++) {
      final angle = (2 * math.pi * i / competencies.length) - math.pi / 2;
      final labelRadius = radius + 25;
      final labelPosition = Offset(
        center.dx + labelRadius * math.cos(angle),
        center.dy + labelRadius * math.sin(angle),
      );

      textPainter.text = TextSpan(
        text: competencies[i],
        style: TextStyle(
          color: Colors.grey[600],
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      );
      textPainter.layout();

      // Adjust position based on angle to prevent text overlap
      double dx = labelPosition.dx - textPainter.width / 2;
      double dy = labelPosition.dy - textPainter.height / 2;

      textPainter.paint(canvas, Offset(dx, dy));
    }
  }

  void _drawDataPolygon(Canvas canvas, Offset center, double radius,
      List<int> scores, int maxScore) {
    if (scores.isEmpty) return;

    final paint = Paint()
      ..color = primaryColor.withValues(alpha: 0.3 * animationValue)
      ..style = PaintingStyle.fill;

    final strokePaint = Paint()
      ..color = primaryColor.withValues(alpha: animationValue)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final path = Path();

    for (int i = 0; i < scores.length; i++) {
      final angle = (2 * math.pi * i / scores.length) - math.pi / 2;
      final normalizedScore = (scores[i] / maxScore).clamp(0.0, 1.0);
      final pointRadius = radius * normalizedScore * animationValue;

      final point = Offset(
        center.dx + pointRadius * math.cos(angle),
        center.dy + pointRadius * math.sin(angle),
      );

      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();

    canvas.drawPath(path, paint);
    canvas.drawPath(path, strokePaint);
  }

  void _drawDataPoints(Canvas canvas, Offset center, double radius,
      List<int> scores, int maxScore) {
    final paint = Paint()
      ..color = primaryColor
      ..style = PaintingStyle.fill;

    final strokePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    for (int i = 0; i < scores.length; i++) {
      final angle = (2 * math.pi * i / scores.length) - math.pi / 2;
      final normalizedScore = (scores[i] / maxScore).clamp(0.0, 1.0);
      final pointRadius = radius * normalizedScore * animationValue;

      final point = Offset(
        center.dx + pointRadius * math.cos(angle),
        center.dy + pointRadius * math.sin(angle),
      );

      canvas.drawCircle(point, 4, strokePaint);
      canvas.drawCircle(point, 4, paint);
    }
  }

  void _drawPolygon(
      Canvas canvas, Offset center, double radius, int sides, Paint paint) {
    final path = Path();

    for (int i = 0; i < sides; i++) {
      final angle = (2 * math.pi * i / sides) - math.pi / 2;
      final point = Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );

      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}

String _localizedRadarLabel(BuildContext context, String value) {
  final match = RegExp(r'([1-5])').firstMatch(value);
  if (match == null) return value;
  return AppLocalizations.of(context)
      .translate('progress_competency_short')
      .replaceAll('{number}', match.group(1)!);
}
