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

class _FloatingGenerationCards extends StatefulWidget {
  const _FloatingGenerationCards({
    required this.onOpenDietGeneration,
    required this.onOpenProfileShapeGeneration,
  });

  final VoidCallback onOpenDietGeneration;
  final VoidCallback onOpenProfileShapeGeneration;

  @override
  State<_FloatingGenerationCards> createState() =>
      _FloatingGenerationCardsState();
}

class _FloatingGenerationCardsState extends State<_FloatingGenerationCards> {
  static const _horizontalMargin = 16.0;
  static const _topMargin = 12.0;
  static const _phoneInitialBottom = 154.0;
  static const _wideInitialBottom = 24.0;
  static const _cardHeight = 46.0;
  static const _cardSpacing = 8.0;

  Offset? _position;
  bool _isDragging = false;

  Offset _defaultPosition({
    required Size overlaySize,
    required EdgeInsets safeInsets,
    required double cardWidth,
    required double cardHeight,
    required bool isWide,
  }) {
    final initialBottom = isWide ? _wideInitialBottom : _phoneInitialBottom;
    return Offset(
      overlaySize.width - safeInsets.right - _horizontalMargin - cardWidth,
      overlaySize.height - safeInsets.bottom - initialBottom - cardHeight,
    );
  }

  Offset _clampPosition({
    required Offset position,
    required Size overlaySize,
    required EdgeInsets safeInsets,
    required double cardWidth,
    required double cardHeight,
  }) {
    final minLeft = safeInsets.left + _horizontalMargin;
    final maxLeft =
        overlaySize.width - safeInsets.right - _horizontalMargin - cardWidth;
    final minTop = safeInsets.top + _topMargin;
    final maxTop =
        overlaySize.height - safeInsets.bottom - _topMargin - cardHeight;
    final boundedMaxLeft = maxLeft < minLeft ? minLeft : maxLeft;
    final boundedMaxTop = maxTop < minTop ? minTop : maxTop;

    return Offset(
      position.dx.clamp(minLeft, boundedMaxLeft).toDouble(),
      position.dy.clamp(minTop, boundedMaxTop).toDouble(),
    );
  }

  void _handlePanStart(DragStartDetails details) {
    setState(() {
      _isDragging = true;
    });
  }

  void _handlePanUpdate({
    required DragUpdateDetails details,
    required Size overlaySize,
    required EdgeInsets safeInsets,
    required double cardWidth,
    required double cardHeight,
  }) {
    final currentPosition = _position ??
        _defaultPosition(
          overlaySize: overlaySize,
          safeInsets: safeInsets,
          cardWidth: cardWidth,
          cardHeight: cardHeight,
          isWide: overlaySize.width >= 720,
        );

    setState(() {
      _position = _clampPosition(
        position: currentPosition + details.delta,
        overlaySize: overlaySize,
        safeInsets: safeInsets,
        cardWidth: cardWidth,
        cardHeight: cardHeight,
      );
    });
  }

  void _handlePanEnd(DragEndDetails details) {
    setState(() {
      _isDragging = false;
    });
  }

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
        isWide ? 260.0 : (width - 32).clamp(0.0, 232.0).toDouble();
    final cards = <Widget>[
      if (showDiet)
        _GenerationCard(
          icon: Icons.ramen_dining_outlined,
          title: context.tr.translate('global_generation_diet_title'),
          message: context.tr.translate('global_generation_diet_body'),
          onTap: widget.onOpenDietGeneration,
        ),
      if (showShape)
        _GenerationCard(
          icon: Icons.auto_awesome_rounded,
          title: context.tr.translate('global_generation_shape_title'),
          message: context.tr.translate('global_generation_shape_body'),
          onTap: widget.onOpenProfileShapeGeneration,
        ),
    ];

    final estimatedCardHeight = (cards.length * _cardHeight) +
        ((cards.length - 1).clamp(0, cards.length) * _cardSpacing);

    return Positioned.fill(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final overlaySize = Size(constraints.maxWidth, constraints.maxHeight);
          final safeInsets = MediaQuery.paddingOf(context);
          final resolvedPosition = _clampPosition(
            position: _position ??
                _defaultPosition(
                  overlaySize: overlaySize,
                  safeInsets: safeInsets,
                  cardWidth: maxCardWidth,
                  cardHeight: estimatedCardHeight,
                  isWide: isWide,
                ),
            overlaySize: overlaySize,
            safeInsets: safeInsets,
            cardWidth: maxCardWidth,
            cardHeight: estimatedCardHeight,
          );

          final cardColumn = ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: maxCardWidth,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < cards.length; i++) ...[
                  if (i > 0) const SizedBox(height: _cardSpacing),
                  cards[i],
                ],
              ],
            ),
          );

          final positionedCard = GestureDetector(
            behavior: HitTestBehavior.translucent,
            onPanStart: _handlePanStart,
            onPanUpdate: (details) => _handlePanUpdate(
              details: details,
              overlaySize: overlaySize,
              safeInsets: safeInsets,
              cardWidth: maxCardWidth,
              cardHeight: estimatedCardHeight,
            ),
            onPanEnd: _handlePanEnd,
            onPanCancel: () {
              setState(() {
                _isDragging = false;
              });
            },
            child: cardColumn,
          );

          return Stack(
            clipBehavior: Clip.none,
            children: [
              AnimatedPositioned(
                duration: _isDragging
                    ? Duration.zero
                    : const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                left: resolvedPosition.dx,
                top: resolvedPosition.dy,
                child: positionedCard,
              ),
            ],
          );
        },
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
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 30,
                  height: 30,
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
                const SizedBox(width: 8),
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
                const SizedBox(width: 5),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
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
