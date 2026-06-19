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
    if (localIcon == null) {
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
        child: CustomPaint(
          painter: _LocalFoodIconPainter(localIcon),
        ),
      ),
    );
  }
}

class _LocalFoodIconPainter extends CustomPainter {
  const _LocalFoodIconPainter(this.kind);

  final LocalFoodIconKind kind;

  @override
  void paint(Canvas canvas, Size size) {
    switch (kind) {
      case LocalFoodIconKind.avocado:
        return _paintAvocado(canvas, size);
      case LocalFoodIconKind.banana:
        return _paintBanana(canvas, size);
      case LocalFoodIconKind.beans:
        return _paintBeans(canvas, size);
      case LocalFoodIconKind.bread:
        return _paintBread(canvas, size);
      case LocalFoodIconKind.broccoli:
        return _paintBroccoli(canvas, size);
      case LocalFoodIconKind.chickenBreast:
        return _paintChickenBreast(canvas, size);
      case LocalFoodIconKind.egg:
        return _paintEgg(canvas, size);
      case LocalFoodIconKind.honey:
        return _paintHoney(canvas, size);
      case LocalFoodIconKind.oil:
        return _paintOil(canvas, size);
      case LocalFoodIconKind.peanut:
        return _paintPeanut(canvas, size);
      case LocalFoodIconKind.rice:
        return _paintRice(canvas, size);
      case LocalFoodIconKind.sweetPotato:
        return _paintSweetPotato(canvas, size);
      case LocalFoodIconKind.tapioca:
        return _paintTapioca(canvas, size);
      case LocalFoodIconKind.tomato:
        return _paintTomato(canvas, size);
    }
  }

  void _paintAvocado(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    canvas.save();
    canvas.translate(w * 0.50, h * 0.52);
    canvas.rotate(-0.35);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: w * 0.78, height: h * 0.92),
      _fill(const Color(0xFF6FA64B)),
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: w * 0.55, height: h * 0.68),
      _fill(const Color(0xFFEAF0A8)),
    );
    canvas.drawCircle(
        Offset(0, h * 0.12), w * 0.15, _fill(const Color(0xFF9B6A32)));
    canvas.drawCircle(Offset(-w * 0.10, -h * 0.16), w * 0.10,
        _fill(Colors.white.withValues(alpha: 0.35)));
    canvas.restore();
  }

  void _paintBanana(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final shadow = Path()
      ..moveTo(w * 0.18, h * 0.30)
      ..cubicTo(w * 0.42, h * 0.93, w * 0.80, h * 0.86, w * 0.86, h * 0.26);
    canvas.drawPath(shadow, _stroke(const Color(0xFFAA7A1C), w * 0.23));
    canvas.drawPath(shadow, _stroke(const Color(0xFFFFD95A), w * 0.17));

    final inner = Path()
      ..moveTo(w * 0.25, h * 0.34)
      ..cubicTo(w * 0.45, h * 0.78, w * 0.70, h * 0.75, w * 0.78, h * 0.30);
    canvas.drawPath(inner, _stroke(const Color(0xFFFFF0A5), w * 0.05));
    canvas.drawCircle(
        Offset(w * 0.86, h * 0.25), w * 0.05, _fill(const Color(0xFF6F4D1E)));
    canvas.drawCircle(
        Offset(w * 0.17, h * 0.30), w * 0.04, _fill(const Color(0xFF6F4D1E)));
  }

  void _paintBeans(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    _drawRotatedOval(
      canvas,
      Offset(w * 0.36, h * 0.40),
      Size(w * 0.34, h * 0.48),
      -0.65,
      _fill(const Color(0xFFA72F23)),
    );
    _drawRotatedOval(
      canvas,
      Offset(w * 0.62, h * 0.48),
      Size(w * 0.33, h * 0.46),
      0.50,
      _fill(const Color(0xFFC7462E)),
    );
    _drawRotatedOval(
      canvas,
      Offset(w * 0.47, h * 0.66),
      Size(w * 0.30, h * 0.41),
      1.10,
      _fill(const Color(0xFF8E281E)),
    );
    _drawBeanHighlight(canvas, Offset(w * 0.28, h * 0.30), w * 0.07);
    _drawBeanHighlight(canvas, Offset(w * 0.57, h * 0.37), w * 0.06);
    _drawBeanHighlight(canvas, Offset(w * 0.39, h * 0.57), w * 0.05);
  }

  void _paintBread(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    canvas.save();
    canvas.translate(w * 0.50, h * 0.50);
    canvas.rotate(-0.70);
    final bread = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: w * 0.43, height: h * 0.90),
      Radius.circular(w * 0.23),
    );
    canvas.drawRRect(bread, _fill(const Color(0xFFE69B2E)));
    canvas.drawRRect(bread, _stroke(const Color(0xFFB56B19), w * 0.045));
    for (final y in [-0.23, 0.0, 0.23]) {
      canvas.drawLine(
        Offset(-w * 0.12, h * y),
        Offset(w * 0.10, h * (y - 0.10)),
        _stroke(const Color(0xFFFFCE73), w * 0.055),
      );
    }
    canvas.restore();
  }

  void _paintBroccoli(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final stem = Path()
      ..moveTo(w * 0.42, h * 0.86)
      ..lineTo(w * 0.58, h * 0.86)
      ..lineTo(w * 0.55, h * 0.50)
      ..lineTo(w * 0.45, h * 0.50)
      ..close();
    canvas.drawPath(stem, _fill(const Color(0xFF83B84A)));
    canvas.drawPath(stem, _stroke(const Color(0xFF4B8136), w * 0.035));

    final florets = [
      Offset(w * 0.32, h * 0.40),
      Offset(w * 0.47, h * 0.28),
      Offset(w * 0.62, h * 0.38),
      Offset(w * 0.50, h * 0.45),
    ];
    for (final center in florets) {
      canvas.drawCircle(center, w * 0.18, _fill(const Color(0xFF3FA94E)));
      canvas.drawCircle(
          center, w * 0.18, _stroke(const Color(0xFF267D3D), w * 0.035));
    }
    canvas.drawCircle(
      Offset(w * 0.41, h * 0.24),
      w * 0.06,
      _fill(Colors.white.withValues(alpha: 0.22)),
    );
  }

  void _paintChickenBreast(Canvas canvas, Size size) {
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

  void _paintEgg(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    canvas.save();
    canvas.translate(w * 0.50, h * 0.50);
    canvas.rotate(-0.20);
    final white = Rect.fromCenter(
      center: Offset.zero,
      width: w * 0.78,
      height: h * 0.92,
    );
    canvas.drawOval(white, _fill(const Color(0xFFFFF8E7)));
    canvas.drawOval(white, _stroke(const Color(0xFFE2D4BD), w * 0.04));
    canvas.drawCircle(
      Offset(w * 0.08, h * 0.10),
      w * 0.18,
      _fill(const Color(0xFFF7AE2B)),
    );
    canvas.drawCircle(
      Offset(w * 0.02, h * 0.04),
      w * 0.055,
      _fill(Colors.white.withValues(alpha: 0.35)),
    );
    canvas.restore();
  }

  void _paintHoney(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final jar = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.23, h * 0.26, w * 0.54, h * 0.60),
      Radius.circular(w * 0.12),
    );
    canvas.drawRRect(jar, _fill(const Color(0xFFE89216)));
    canvas.drawRRect(jar, _stroke(const Color(0xFFAE650F), w * 0.035));
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.32, h * 0.17, w * 0.36, h * 0.13),
        Radius.circular(w * 0.04),
      ),
      _fill(const Color(0xFFB36E23)),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.31, h * 0.42, w * 0.38, h * 0.20),
        Radius.circular(w * 0.06),
      ),
      _fill(const Color(0xFFFFC34E)),
    );
    canvas.drawCircle(
      Offset(w * 0.40, h * 0.36),
      w * 0.07,
      _fill(Colors.white.withValues(alpha: 0.25)),
    );
  }

  void _paintOil(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final drop = Path()
      ..moveTo(w * 0.50, h * 0.08)
      ..cubicTo(w * 0.82, h * 0.42, w * 0.78, h * 0.90, w * 0.50, h * 0.90)
      ..cubicTo(w * 0.22, h * 0.90, w * 0.18, h * 0.42, w * 0.50, h * 0.08)
      ..close();
    canvas.drawPath(drop, _fill(const Color(0xFFFFC94B)));
    canvas.drawPath(drop, _stroke(const Color(0xFFD7891D), w * 0.045));
    canvas.drawOval(
      Rect.fromLTWH(w * 0.38, h * 0.28, w * 0.18, h * 0.32),
      _fill(Colors.white.withValues(alpha: 0.30)),
    );
    canvas.drawCircle(
      Offset(w * 0.59, h * 0.68),
      w * 0.07,
      _fill(const Color(0xFFF4A72D).withValues(alpha: 0.55)),
    );
  }

  void _paintPeanut(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    _drawRotatedOval(
      canvas,
      Offset(w * 0.38, h * 0.50),
      Size(w * 0.34, h * 0.54),
      0.70,
      _fill(const Color(0xFFE4A349)),
    );
    _drawRotatedOval(
      canvas,
      Offset(w * 0.61, h * 0.50),
      Size(w * 0.34, h * 0.54),
      0.70,
      _fill(const Color(0xFFD88B32)),
    );
    _drawRotatedOval(
      canvas,
      Offset(w * 0.38, h * 0.50),
      Size(w * 0.34, h * 0.54),
      0.70,
      _stroke(const Color(0xFF9C6121), w * 0.035),
    );
    _drawRotatedOval(
      canvas,
      Offset(w * 0.61, h * 0.50),
      Size(w * 0.34, h * 0.54),
      0.70,
      _stroke(const Color(0xFF9C6121), w * 0.035),
    );
    for (final dot in [
      Offset(w * 0.32, h * 0.42),
      Offset(w * 0.43, h * 0.58),
      Offset(w * 0.57, h * 0.42),
      Offset(w * 0.67, h * 0.58),
    ]) {
      canvas.drawCircle(dot, w * 0.025,
          _fill(const Color(0xFF7F4E1C).withValues(alpha: 0.45)));
    }
  }

  void _paintRice(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final rice = Path()
      ..moveTo(w * 0.18, h * 0.49)
      ..cubicTo(w * 0.25, h * 0.22, w * 0.75, h * 0.22, w * 0.82, h * 0.49)
      ..close();
    canvas.drawPath(rice, _fill(const Color(0xFFFFFEF3)));
    canvas.drawPath(rice, _stroke(const Color(0xFFD8D8CE), w * 0.03));
    final bowl = Path()
      ..moveTo(w * 0.14, h * 0.49)
      ..quadraticBezierTo(w * 0.50, h * 0.95, w * 0.86, h * 0.49)
      ..close();
    canvas.drawPath(bowl, _fill(const Color(0xFF8BD1D3)));
    canvas.drawPath(bowl, _stroke(const Color(0xFF4A9BA0), w * 0.035));
    canvas.drawLine(
      Offset(w * 0.25, h * 0.59),
      Offset(w * 0.75, h * 0.59),
      _stroke(Colors.white.withValues(alpha: 0.45), w * 0.03),
    );
  }

  void _paintSweetPotato(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    canvas.save();
    canvas.translate(w * 0.50, h * 0.52);
    canvas.rotate(-0.55);
    final potato = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: w * 0.45, height: h * 0.88),
      Radius.circular(w * 0.24),
    );
    canvas.drawRRect(potato, _fill(const Color(0xFFC23D83)));
    canvas.drawRRect(potato, _stroke(const Color(0xFF8B275D), w * 0.035));
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.02, h * 0.08),
        width: w * 0.28,
        height: h * 0.34,
      ),
      _fill(const Color(0xFFFFC45F)),
    );
    canvas.restore();
  }

  void _paintTapioca(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final disk = Rect.fromLTWH(w * 0.10, h * 0.12, w * 0.80, h * 0.76);
    canvas.drawOval(disk, _fill(const Color(0xFFF3D6A7)));
    canvas.drawOval(disk, _stroke(const Color(0xFFC58F52), w * 0.035));
    canvas.save();
    final path = Path()..addOval(disk);
    canvas.clipPath(path);
    for (final x in [-0.05, 0.18, 0.41, 0.64]) {
      canvas.drawLine(
        Offset(w * x, h * 0.22),
        Offset(w * (x + 0.42), h * 0.82),
        _stroke(const Color(0xFFFFE9C5).withValues(alpha: 0.65), w * 0.055),
      );
    }
    canvas.restore();
  }

  void _paintTomato(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    canvas.drawCircle(
      Offset(w * 0.50, h * 0.55),
      w * 0.34,
      _fill(const Color(0xFFE83A35)),
    );
    canvas.drawCircle(
      Offset(w * 0.50, h * 0.55),
      w * 0.34,
      _stroke(const Color(0xFFA72525), w * 0.035),
    );
    final leaf = Path()
      ..moveTo(w * 0.50, h * 0.25)
      ..lineTo(w * 0.40, h * 0.40)
      ..lineTo(w * 0.50, h * 0.36)
      ..lineTo(w * 0.60, h * 0.40)
      ..close();
    canvas.drawPath(leaf, _fill(const Color(0xFF3FA94E)));
    canvas.drawCircle(
      Offset(w * 0.39, h * 0.43),
      w * 0.07,
      _fill(Colors.white.withValues(alpha: 0.20)),
    );
  }

  void _drawRotatedOval(
    Canvas canvas,
    Offset center,
    Size size,
    double angle,
    Paint paint,
  ) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset.zero, width: size.width, height: size.height),
      paint,
    );
    canvas.restore();
  }

  void _drawBeanHighlight(Canvas canvas, Offset center, double radius) {
    canvas.drawCircle(
        center, radius, _fill(Colors.white.withValues(alpha: 0.25)));
  }

  @override
  bool shouldRepaint(covariant _LocalFoodIconPainter oldDelegate) {
    return oldDelegate.kind != kind;
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
