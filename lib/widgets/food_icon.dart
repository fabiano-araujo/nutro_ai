import 'package:flutter/material.dart';

import '../utils/local_food_icon_resolver.dart';

class FoodIcon extends StatelessWidget {
  final String name;
  final String emoji;
  final double size;

  const FoodIcon({
    super.key,
    required this.name,
    required this.emoji,
    this.size = 24,
  });

  @override
  Widget build(BuildContext context) {
    final localIcon = resolveLocalFoodIconKind(name);
    if (localIcon != LocalFoodIconKind.chickenBreast) {
      return Text(
        emoji,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: size),
      );
    }

    return Semantics(
      label: name,
      image: true,
      child: SizedBox.square(
        dimension: size,
        child: const CustomPaint(
          painter: _ChickenBreastIconPainter(),
        ),
      ),
    );
  }
}

class _ChickenBreastIconPainter extends CustomPainter {
  const _ChickenBreastIconPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final meat = Path()
      ..moveTo(w * 0.20, h * 0.58)
      ..cubicTo(w * 0.20, h * 0.30, w * 0.45, h * 0.15, w * 0.70, h * 0.25)
      ..cubicTo(w * 0.93, h * 0.34, w * 0.94, h * 0.67, w * 0.68, h * 0.80)
      ..cubicTo(w * 0.47, h * 0.90, w * 0.22, h * 0.82, w * 0.20, h * 0.58)
      ..close();

    canvas.drawPath(meat, _fill(const Color(0xFFF0B48F)));
    canvas.drawPath(meat, _stroke(const Color(0xFFB56F4C), w * 0.045));
    canvas.save();
    canvas.clipPath(meat);
    final grill =
        _stroke(const Color(0xFF8F553D).withValues(alpha: 0.45), w * 0.06);
    for (final x in [0.33, 0.50, 0.67]) {
      canvas.drawLine(
        Offset(w * x, h * 0.27),
        Offset(w * (x - 0.14), h * 0.78),
        grill,
      );
    }
    canvas.restore();
    canvas.drawOval(
      Rect.fromLTWH(w * 0.36, h * 0.30, w * 0.25, h * 0.12),
      _fill(Colors.white.withValues(alpha: 0.22)),
    );
  }

  @override
  bool shouldRepaint(covariant _ChickenBreastIconPainter oldDelegate) {
    return false;
  }
}

Paint _fill(Color color) => Paint()
  ..color = color
  ..style = PaintingStyle.fill
  ..isAntiAlias = true;

Paint _stroke(Color color, double width) => Paint()
  ..color = color
  ..style = PaintingStyle.stroke
  ..strokeWidth = width
  ..strokeCap = StrokeCap.round
  ..strokeJoin = StrokeJoin.round
  ..isAntiAlias = true;
