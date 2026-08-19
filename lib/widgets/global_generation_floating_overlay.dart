import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../i18n/app_localizations_extension.dart';
import '../providers/diet_plan_provider.dart';
import '../providers/profile_shape_preview_provider.dart';
import '../screens/main_navigation.dart';
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
  static const _leftMargin = 8.0;
  static const _rightMargin = 8.0;
  static const _topMargin = 12.0;
  static const _phoneHomeInitialBottom = 154.0;
  static const _phoneTabInitialBottom = 92.0;
  static const _wideInitialBottom = 24.0;
  static const _cardHeight = 46.0;
  static const _cardSpacing = 8.0;

  final GlobalKey _cardKey = GlobalKey();
  Offset? _position;
  bool _isDragging = false;

  Size _currentCardSize({
    required double fallbackWidth,
    required double fallbackHeight,
  }) {
    final renderObject = _cardKey.currentContext?.findRenderObject();
    if (renderObject is RenderBox && renderObject.hasSize) {
      return renderObject.size;
    }
    return Size(fallbackWidth, fallbackHeight);
  }

  Offset _defaultPosition({
    required Size overlaySize,
    required EdgeInsets safeInsets,
    required double cardWidth,
    required double cardHeight,
    required bool isWide,
    required int selectedTabIndex,
  }) {
    final initialBottom = isWide
        ? _wideInitialBottom
        : selectedTabIndex == 0
            ? _phoneHomeInitialBottom
            : _phoneTabInitialBottom;
    return Offset(
      overlaySize.width - safeInsets.right - _rightMargin - cardWidth,
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
    final minLeft = safeInsets.left + _leftMargin;
    final maxLeft =
        overlaySize.width - safeInsets.right - _rightMargin - cardWidth;
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

  void _handlePanStart({
    required Size overlaySize,
    required EdgeInsets safeInsets,
    required double fallbackCardWidth,
    required double fallbackCardHeight,
    required int selectedTabIndex,
  }) {
    final cardSize = _currentCardSize(
      fallbackWidth: fallbackCardWidth,
      fallbackHeight: fallbackCardHeight,
    );
    final initialPosition = _clampPosition(
      position: _position ??
          _defaultPosition(
            overlaySize: overlaySize,
            safeInsets: safeInsets,
            cardWidth: cardSize.width,
            cardHeight: cardSize.height,
            isWide: overlaySize.width >= 720,
            selectedTabIndex: selectedTabIndex,
          ),
      overlaySize: overlaySize,
      safeInsets: safeInsets,
      cardWidth: cardSize.width,
      cardHeight: cardSize.height,
    );

    setState(() {
      _position = initialPosition;
      _isDragging = true;
    });
  }

  void _handlePanUpdate({
    required DragUpdateDetails details,
    required Size overlaySize,
    required EdgeInsets safeInsets,
    required double fallbackCardWidth,
    required double fallbackCardHeight,
    required int selectedTabIndex,
  }) {
    final cardSize = _currentCardSize(
      fallbackWidth: fallbackCardWidth,
      fallbackHeight: fallbackCardHeight,
    );
    final currentPosition = _position ??
        _defaultPosition(
          overlaySize: overlaySize,
          safeInsets: safeInsets,
          cardWidth: cardSize.width,
          cardHeight: cardSize.height,
          isWide: overlaySize.width >= 720,
          selectedTabIndex: selectedTabIndex,
        );

    setState(() {
      _position = _clampPosition(
        position: currentPosition + details.delta,
        overlaySize: overlaySize,
        safeInsets: safeInsets,
        cardWidth: cardSize.width,
        cardHeight: cardSize.height,
      );
    });
  }

  void _finishDrag({
    required Size overlaySize,
    required EdgeInsets safeInsets,
    required double fallbackCardWidth,
    required double fallbackCardHeight,
  }) {
    final currentPosition = _position;
    if (currentPosition == null) {
      setState(() {
        _isDragging = false;
      });
      return;
    }

    final cardSize = _currentCardSize(
      fallbackWidth: fallbackCardWidth,
      fallbackHeight: fallbackCardHeight,
    );
    final boundedPosition = _clampPosition(
      position: currentPosition,
      overlaySize: overlaySize,
      safeInsets: safeInsets,
      cardWidth: cardSize.width,
      cardHeight: cardSize.height,
    );
    final leftEdge = safeInsets.left + _leftMargin;
    final rightEdge =
        overlaySize.width - safeInsets.right - _rightMargin - cardSize.width;
    final boundedRightEdge = rightEdge < leftEdge ? leftEdge : rightEdge;
    final distanceFromLeft = (boundedPosition.dx - leftEdge).abs();
    final distanceFromRight = (boundedRightEdge - boundedPosition.dx).abs();
    final snappedLeft =
        distanceFromLeft <= distanceFromRight ? leftEdge : boundedRightEdge;

    setState(() {
      _position = Offset(snappedLeft, boundedPosition.dy);
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

    return ValueListenableBuilder<int>(
      valueListenable: navigationController.selectedIndexNotifier,
      builder: (context, selectedTabIndex, _) {
        return Positioned.fill(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final overlaySize =
                  Size(constraints.maxWidth, constraints.maxHeight);
              final safeInsets = MediaQuery.paddingOf(context);
              final cardSize = _currentCardSize(
                fallbackWidth: maxCardWidth,
                fallbackHeight: estimatedCardHeight,
              );
              final resolvedPosition = _clampPosition(
                position: _position ??
                    _defaultPosition(
                      overlaySize: overlaySize,
                      safeInsets: safeInsets,
                      cardWidth: cardSize.width,
                      cardHeight: cardSize.height,
                      isWide: isWide,
                      selectedTabIndex: selectedTabIndex,
                    ),
                overlaySize: overlaySize,
                safeInsets: safeInsets,
                cardWidth: cardSize.width,
                cardHeight: cardSize.height,
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
                key: _cardKey,
                behavior: HitTestBehavior.translucent,
                onPanStart: (_) => _handlePanStart(
                  overlaySize: overlaySize,
                  safeInsets: safeInsets,
                  fallbackCardWidth: maxCardWidth,
                  fallbackCardHeight: estimatedCardHeight,
                  selectedTabIndex: selectedTabIndex,
                ),
                onPanUpdate: (details) => _handlePanUpdate(
                  details: details,
                  overlaySize: overlaySize,
                  safeInsets: safeInsets,
                  fallbackCardWidth: maxCardWidth,
                  fallbackCardHeight: estimatedCardHeight,
                  selectedTabIndex: selectedTabIndex,
                ),
                onPanEnd: (_) => _finishDrag(
                  overlaySize: overlaySize,
                  safeInsets: safeInsets,
                  fallbackCardWidth: maxCardWidth,
                  fallbackCardHeight: estimatedCardHeight,
                ),
                onPanCancel: () => _finishDrag(
                  overlaySize: overlaySize,
                  safeInsets: safeInsets,
                  fallbackCardWidth: maxCardWidth,
                  fallbackCardHeight: estimatedCardHeight,
                ),
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
                    left: _position == null ? null : resolvedPosition.dx,
                    right: _position == null
                        ? safeInsets.right + _rightMargin
                        : null,
                    top: resolvedPosition.dy,
                    child: positionedCard,
                  ),
                ],
              );
            },
          ),
        );
      },
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
