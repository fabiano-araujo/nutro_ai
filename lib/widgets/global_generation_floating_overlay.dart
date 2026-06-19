import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../i18n/app_localizations_extension.dart';
import '../providers/diet_plan_provider.dart';
import '../providers/profile_shape_preview_provider.dart';
import '../theme/app_theme.dart';

class GlobalGenerationFloatingOverlay extends StatelessWidget {
  const GlobalGenerationFloatingOverlay({
    super.key,
    required this.child,
    required this.onOpenDietGeneration,
    required this.onOpenProfileShapeGeneration,
  });

  final Widget child;
  final VoidCallback onOpenDietGeneration;
  final VoidCallback onOpenProfileShapeGeneration;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        _FloatingGenerationCards(
          onOpenDietGeneration: onOpenDietGeneration,
          onOpenProfileShapeGeneration: onOpenProfileShapeGeneration,
        ),
      ],
    );
  }
}

class _FloatingGenerationCards extends StatelessWidget {
  const _FloatingGenerationCards({
    required this.onOpenDietGeneration,
    required this.onOpenProfileShapeGeneration,
  });

  final VoidCallback onOpenDietGeneration;
  final VoidCallback onOpenProfileShapeGeneration;

  @override
  Widget build(BuildContext context) {
    final dietProvider = context.watch<DietPlanProvider>();
    final shapeProvider = context.watch<ProfileShapePreviewProvider>();
    final showDiet = dietProvider.hasActiveDietGenerationJob;
    final showShape = shapeProvider.hasActiveProfileShapeGenerationJob ||
        shapeProvider.isGenerating;

    if (!showDiet && !showShape) {
      return const SizedBox.shrink();
    }

    final width = MediaQuery.sizeOf(context).width;
    final isWide = width >= 720;
    final maxCardWidth =
        isWide ? 300.0 : (width - 32).clamp(0.0, 280.0).toDouble();
    final cards = <Widget>[
      if (showDiet)
        _GenerationCard(
          icon: Icons.ramen_dining_outlined,
          title: context.tr.translate('global_generation_diet_title'),
          message: context.tr.translate('global_generation_diet_body'),
          onTap: onOpenDietGeneration,
        ),
      if (showShape)
        _GenerationCard(
          icon: Icons.auto_awesome_rounded,
          title: context.tr.translate('global_generation_shape_title'),
          message: context.tr.translate('global_generation_shape_body'),
          onTap: onOpenProfileShapeGeneration,
        ),
    ];

    return Positioned(
      left: null,
      right: 16,
      bottom: isWide ? 24 : 92,
      child: SafeArea(
        top: false,
        left: false,
        child: Align(
          alignment: Alignment.bottomRight,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: maxCardWidth,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < cards.length; i++) ...[
                  if (i > 0) const SizedBox(height: 8),
                  cards[i],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GenerationCard extends StatelessWidget {
  const _GenerationCard({
    required this.icon,
    required this.title,
    required this.message,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String message;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final primary =
        isDarkMode ? AppTheme.primaryColorDarkMode : AppTheme.primaryColor;
    final background = isDarkMode ? AppTheme.darkCardColor : Colors.white;
    final borderColor = isDarkMode
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.08);
    final titleColor = isDarkMode ? Colors.white : AppTheme.textPrimaryColor;
    final bodyColor = isDarkMode
        ? Colors.white.withValues(alpha: 0.68)
        : AppTheme.textSecondaryColor;

    return Semantics(
      button: true,
      label: '$title. $message',
      child: Material(
        color: background,
        elevation: 8,
        shadowColor: Colors.black.withValues(alpha: isDarkMode ? 0.38 : 0.14),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 32,
                  height: 32,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: primary,
                        backgroundColor: primary.withValues(alpha: 0.12),
                      ),
                      Icon(icon, size: 15, color: primary),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: titleColor,
                      fontWeight: FontWeight.w800,
                      height: 1.05,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 19,
                  color: bodyColor,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
