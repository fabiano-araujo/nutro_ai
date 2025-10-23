import 'package:flutter/material.dart';

class AnimatedGradientBackground extends StatefulWidget {
  final Widget child;
  final List<Color>? colors;
  final Duration duration;

  const AnimatedGradientBackground({
    Key? key,
    required this.child,
    this.colors,
    this.duration = const Duration(seconds: 20),
  }) : super(key: key);

  @override
  _AnimatedGradientBackgroundState createState() =>
      _AnimatedGradientBackgroundState();
}

class _AnimatedGradientBackgroundState extends State<AnimatedGradientBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    )..repeat(reverse: true);
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    // Cores diferentes para modo claro e escuro
    final colors = widget.colors ??
        (isDarkMode
            ? [
                Color(0xFF1E1E2E), // Azul escuro
                Color(0xFF191927), // Quase preto azulado
                Color(0xFF252538), // Azul marinho escuro
              ]
            : [
                Color(0xFFF0F8FF), // Alice Blue
                Color(0xFFE6F0F8), // Azul muito claro
                Color(0xFFF8F8F8), // Quase branco
              ]);

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: colors,
              stops: [
                0.0,
                _animation.value * 0.5 + 0.3,
                1.0,
              ],
            ),
          ),
          child: widget.child,
        );
      },
    );
  }
}
