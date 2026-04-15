import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class StateAnimation extends StatelessWidget {
  static const String noDataAsset = 'assets/animations/no_data.lottie';

  final double size;
  final IconData fallbackIcon;
  final Color? accentColor;

  const StateAnimation({
    super.key,
    required this.fallbackIcon,
    this.size = 160,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedColor = accentColor ?? Theme.of(context).colorScheme.primary;

    return Lottie.asset(
      noDataAsset,
      width: size,
      height: size,
      fit: BoxFit.contain,
      decoder: _decodeDotLottie,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: resolvedColor.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(
            fallbackIcon,
            size: size * 0.4,
            color: resolvedColor.withValues(alpha: 0.55),
          ),
        );
      },
    );
  }

  static Future<LottieComposition?> _decodeDotLottie(List<int> bytes) {
    return LottieComposition.decodeZip(
      bytes,
      filePicker: (files) {
        for (final file in files) {
          if (file.name.startsWith('animations/') &&
              file.name.endsWith('.json')) {
            return file;
          }
        }

        for (final file in files) {
          if (file.name.endsWith('.json')) {
            return file;
          }
        }

        return null;
      },
    );
  }
}
