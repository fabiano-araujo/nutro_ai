import 'package:flutter/material.dart';

class AnimatedText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final Duration animationDuration;
  final Curve animationCurve;

  const AnimatedText(
    this.text, {
    Key? key,
    this.style,
    this.animationDuration = const Duration(milliseconds: 100),
    this.animationCurve = Curves.easeInOut,
  }) : super(key: key);

  @override
  _AnimatedTextState createState() => _AnimatedTextState();
}

class _AnimatedTextState extends State<AnimatedText> {
  String _displayedText = '';
  late String _fullText;
  int _currentLength = 0;

  @override
  void initState() {
    super.initState();
    _fullText = widget.text;
    _startAnimation();
  }

  @override
  void didUpdateWidget(AnimatedText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _fullText = widget.text;
      _startAnimation();
    }
  }

  void _startAnimation() {
    _displayedText = '';
    _currentLength = 0;

    // Reinicia a animação
    _animateText();
  }

  void _animateText() {
    if (_currentLength < _fullText.length) {
      setState(() {
        // Incrementa o comprimento do texto exibido em 1-3 caracteres por vez
        final increment = (_fullText.length / 100).ceil();
        _currentLength =
            (_currentLength + increment).clamp(0, _fullText.length);
        _displayedText = _fullText.substring(0, _currentLength);
      });

      // Programa o próximo frame da animação
      Future.delayed(widget.animationDuration, _animateText);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      _displayedText,
      style: widget.style,
    );
  }
}
