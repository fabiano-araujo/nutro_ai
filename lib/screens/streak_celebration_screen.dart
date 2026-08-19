import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../i18n/app_localizations_extension.dart';
import '../theme/app_theme.dart';

@immutable
class StreakCelebrationEvent {
  final int eventId;
  final int currentStreak;
  final DateTime effectiveDate;
  final List<DateTime> missedDates;
  final bool freezeRecovered;
  final int freezesAvailable;

  const StreakCelebrationEvent({
    required this.eventId,
    required this.currentStreak,
    required this.effectiveDate,
    required this.missedDates,
    required this.freezeRecovered,
    required this.freezesAvailable,
  })  : assert(eventId >= 0),
        assert(currentStreak > 0),
        assert(freezesAvailable >= 0);
}

class StreakCelebrationScreen extends StatefulWidget {
  final StreakCelebrationEvent event;
  final VoidCallback? onCompleted;

  const StreakCelebrationScreen({
    super.key,
    required this.event,
    this.onCompleted,
  });

  @override
  State<StreakCelebrationScreen> createState() =>
      _StreakCelebrationScreenState();
}

class _StreakCelebrationScreenState extends State<StreakCelebrationScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entryController;
  late final Animation<double> _entryOpacity;
  late final Animation<double> _entryScale;
  bool? _animationsDisabled;
  int _pageIndex = 0;

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    final curved = CurvedAnimation(
      parent: _entryController,
      curve: Curves.easeOutCubic,
    );
    _entryOpacity = curved;
    _entryScale = Tween<double>(begin: 0.92, end: 1).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: Curves.easeOutBack,
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final disabled = MediaQuery.disableAnimationsOf(context);
    if (_animationsDisabled == disabled) return;
    _animationsDisabled = disabled;
    if (disabled) {
      _entryController.value = 1;
    } else {
      _entryController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _entryController.dispose();
    super.dispose();
  }

  void _restartEntryAnimation() {
    if (MediaQuery.disableAnimationsOf(context)) {
      _entryController.value = 1;
      return;
    }
    _entryController.forward(from: 0);
  }

  void _continue() {
    if (_pageIndex == 0 && widget.event.freezeRecovered) {
      HapticFeedback.selectionClick();
      setState(() => _pageIndex = 1);
      _restartEntryAnimation();
      return;
    }

    HapticFeedback.lightImpact();
    widget.onCompleted?.call();
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop(widget.event.eventId);
    }
  }

  void _returnToStreakPage() {
    setState(() => _pageIndex = 0);
    _restartEntryAnimation();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final background = isDarkMode ? AppTheme.darkBackgroundColor : Colors.white;
    final overlayStyle =
        (isDarkMode ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark)
            .copyWith(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: background,
      systemNavigationBarIconBrightness:
          isDarkMode ? Brightness.light : Brightness.dark,
    );
    final transitionDuration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 280);

    return PopScope(
      canPop: _pageIndex == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _pageIndex == 1) {
          _returnToStreakPage();
        }
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: overlayStyle,
        child: Scaffold(
          backgroundColor: background,
          body: SafeArea(
            bottom: false,
            child: Column(
              children: [
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final compact = constraints.maxHeight < 610 ||
                          MediaQuery.sizeOf(context).width < 350;
                      return SingleChildScrollView(
                        padding: EdgeInsets.fromLTRB(
                          compact ? 18 : 24,
                          compact ? 6 : 24,
                          compact ? 18 : 24,
                          12,
                        ),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: math.max(0, constraints.maxHeight - 18),
                          ),
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 430),
                              child: AnimatedSwitcher(
                                duration: transitionDuration,
                                switchInCurve: Curves.easeOutCubic,
                                switchOutCurve: Curves.easeInCubic,
                                transitionBuilder: (child, animation) {
                                  return FadeTransition(
                                    opacity: animation,
                                    child: SlideTransition(
                                      position: Tween<Offset>(
                                        begin: const Offset(0.05, 0),
                                        end: Offset.zero,
                                      ).animate(animation),
                                      child: child,
                                    ),
                                  );
                                },
                                child: _pageIndex == 0
                                    ? _StreakPage(
                                        key: const ValueKey(
                                          'streak-celebration-streak-page',
                                        ),
                                        event: widget.event,
                                        compact: compact,
                                        entryOpacity: _entryOpacity,
                                        entryScale: _entryScale,
                                      )
                                    : _FreezeRecoveredPage(
                                        key: const ValueKey(
                                          'streak-celebration-freeze-page',
                                        ),
                                        event: widget.event,
                                        compact: compact,
                                        entryOpacity: _entryOpacity,
                                        entryScale: _entryScale,
                                      ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                SafeArea(
                  top: false,
                  minimum: const EdgeInsets.fromLTRB(24, 10, 24, 18),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 280),
                    child: SizedBox(
                      width: double.infinity,
                      height: 58,
                      child: FilledButton(
                        key: const ValueKey(
                          'streak-celebration-continue-button',
                        ),
                        onPressed: _continue,
                        style: FilledButton.styleFrom(
                          backgroundColor: isDarkMode
                              ? AppTheme.primaryColorDarkMode
                              : const Color(0xFF203448),
                          foregroundColor: isDarkMode
                              ? const Color(0xFF0D1817)
                              : Colors.white,
                          shape: const StadiumBorder(),
                          textStyle: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        child: Text(
                          context.tr.translate(
                            'streak_celebration_continue',
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StreakPage extends StatelessWidget {
  final StreakCelebrationEvent event;
  final bool compact;
  final Animation<double> entryOpacity;
  final Animation<double> entryScale;

  const _StreakPage({
    super.key,
    required this.event,
    required this.compact,
    required this.entryOpacity,
    required this.entryScale,
  });

  @override
  Widget build(BuildContext context) {
    final suffix = context.tr.translate(
      event.currentStreak == 1
          ? 'streak_celebration_day_one'
          : 'streak_celebration_days_other',
    );
    final celebrationLabel = '${event.currentStreak} $suffix';
    final nextStreak = event.currentStreak + 1;

    return Semantics(
      scopesRoute: true,
      namesRoute: true,
      label: celebrationLabel,
      explicitChildNodes: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            image: true,
            label: celebrationLabel,
            child: ExcludeSemantics(
              child: FadeTransition(
                opacity: entryOpacity,
                child: ScaleTransition(
                  scale: entryScale,
                  child: _FlameStreakIllustration(
                    streak: event.currentStreak,
                    compact: compact,
                  ),
                ),
              ),
            ),
          ),
          SizedBox(height: compact ? 2 : 8),
          Semantics(
            header: true,
            label: celebrationLabel,
            child: ExcludeSemantics(
              child: Text(
                suffix,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      color: _celebrationOrange,
                      fontSize: compact ? 30 : 38,
                      height: 1.05,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.8,
                    ),
              ),
            ),
          ),
          SizedBox(height: compact ? 14 : 28),
          _FiveDayStreakStrip(event: event, compact: compact),
          SizedBox(height: compact ? 14 : 28),
          Text(
            context.tr
                .translate('streak_celebration_message')
                .replaceAll('{next}', nextStreak.toString()),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: _secondaryTextColor(context),
                  fontSize: compact ? 17 : 21,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

class _FreezeRecoveredPage extends StatelessWidget {
  final StreakCelebrationEvent event;
  final bool compact;
  final Animation<double> entryOpacity;
  final Animation<double> entryScale;

  const _FreezeRecoveredPage({
    super.key,
    required this.event,
    required this.compact,
    required this.entryOpacity,
    required this.entryScale,
  });

  @override
  Widget build(BuildContext context) {
    final title = context.tr.translate('streak_celebration_freeze_title');
    final body = context.tr.translate('streak_celebration_freeze_body');
    final protectionKey = event.freezesAvailable == 1
        ? 'streak_protection_one'
        : 'streak_protection_other';
    final protectionLabel = context.tr
        .translate(protectionKey)
        .replaceAll('{count}', event.freezesAvailable.toString());

    return Semantics(
      scopesRoute: true,
      namesRoute: true,
      label: '$title. $body',
      explicitChildNodes: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            image: true,
            label: '$title. $protectionLabel',
            child: ExcludeSemantics(
              child: FadeTransition(
                opacity: entryOpacity,
                child: ScaleTransition(
                  scale: entryScale,
                  child: _FreezeGiftIllustration(
                    compact: compact,
                    freezesAvailable: event.freezesAvailable,
                  ),
                ),
              ),
            ),
          ),
          SizedBox(height: compact ? 14 : 28),
          Semantics(
            header: true,
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    color: _primaryTextColor(context),
                    fontSize: compact ? 31 : 42,
                    height: 1.16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -1,
                  ),
            ),
          ),
          SizedBox(height: compact ? 12 : 22),
          Text(
            body,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: _secondaryTextColor(context),
                  fontSize: compact ? 17 : 20,
                  height: 1.35,
                  fontWeight: FontWeight.w500,
                ),
          ),
        ],
      ),
    );
  }
}

const _celebrationOrange = Color(0xFFF2A74A);
const _celebrationYellow = Color(0xFFFFE57C);
const _freezeBlue = Color(0xFF9ADAF8);

Color _primaryTextColor(BuildContext context) {
  return Theme.of(context).brightness == Brightness.dark
      ? AppTheme.darkTextColor
      : const Color(0xFF34465B);
}

Color _secondaryTextColor(BuildContext context) {
  return Theme.of(context).brightness == Brightness.dark
      ? AppTheme.darkMutedTextColor
      : const Color(0xFF56677A);
}

class _FlameStreakIllustration extends StatelessWidget {
  final int streak;
  final bool compact;

  const _FlameStreakIllustration({
    required this.streak,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    final background = Theme.of(context).brightness == Brightness.dark
        ? AppTheme.darkBackgroundColor
        : Colors.white;
    final height = compact ? 142.0 : 218.0;
    final flameSize = compact ? 132.0 : 190.0;
    final numberSize = compact ? 86.0 : 116.0;
    final strokeWidth = compact ? 7.0 : 9.0;

    return SizedBox(
      key: const ValueKey('streak-celebration-flame-illustration'),
      height: height,
      width: double.infinity,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [_celebrationYellow, _celebrationOrange],
            ).createShader(bounds),
            child: Icon(
              Icons.local_fire_department_rounded,
              size: flameSize,
              color: Colors.white,
            ),
          ),
          Positioned(
            left: 34,
            right: 34,
            bottom: 0,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Stack(
                children: [
                  Text(
                    '$streak',
                    style: TextStyle(
                      height: 0.9,
                      fontSize: numberSize,
                      fontWeight: FontWeight.w900,
                      foreground: Paint()
                        ..style = PaintingStyle.stroke
                        ..strokeJoin = StrokeJoin.round
                        ..strokeWidth = strokeWidth
                        ..color = _celebrationOrange,
                    ),
                  ),
                  Text(
                    '$streak',
                    style: TextStyle(
                      color: background,
                      height: 0.9,
                      fontSize: numberSize,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _CelebrationDayState { filled, protected, empty }

class _FiveDayStreakStrip extends StatelessWidget {
  final StreakCelebrationEvent event;
  final bool compact;

  const _FiveDayStreakStrip({required this.event, required this.compact});

  @override
  Widget build(BuildContext context) {
    final effectiveDate = _dateOnly(event.effectiveDate);
    final days = List<DateTime>.generate(
      5,
      (index) => effectiveDate.add(Duration(days: index - 2)),
    );
    final missed = event.missedDates.map(_dateKey).toSet();
    final states = <int, _CelebrationDayState>{};
    var remainingFilledDays = event.currentStreak;

    for (var index = 2; index >= 0; index--) {
      final day = days[index];
      if (missed.contains(_dateKey(day))) {
        states[index] = _CelebrationDayState.protected;
      } else if (remainingFilledDays > 0) {
        states[index] = _CelebrationDayState.filled;
        remainingFilledDays--;
      } else {
        states[index] = _CelebrationDayState.empty;
      }
    }
    states[3] = _CelebrationDayState.empty;
    states[4] = _CelebrationDayState.empty;

    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Container(
      key: const ValueKey('streak-celebration-five-day-strip'),
      constraints: BoxConstraints(minHeight: compact ? 92 : 108),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 14,
        vertical: compact ? 12 : 15,
      ),
      decoration: BoxDecoration(
        color: isDarkMode ? AppTheme.darkCardColor : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color:
              isDarkMode ? AppTheme.darkBorderColor : const Color(0xFFE3E8EC),
        ),
        boxShadow: isDarkMode
            ? null
            : const [
                BoxShadow(
                  color: Color(0x0D243447),
                  blurRadius: 16,
                  offset: Offset(0, 6),
                ),
              ],
      ),
      child: Row(
        children: [
          for (var index = 0; index < days.length; index++)
            Expanded(
              child: _CelebrationDay(
                key: ValueKey(
                  'streak-celebration-day-${index - 2}-${states[index]!.name}',
                ),
                date: days[index],
                state: states[index]!,
                compact: compact,
              ),
            ),
        ],
      ),
    );
  }
}

class _CelebrationDay extends StatelessWidget {
  final DateTime date;
  final _CelebrationDayState state;
  final bool compact;

  const _CelebrationDay({
    super.key,
    required this.date,
    required this.state,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    final dateLabel = MaterialLocalizations.of(context).formatFullDate(date);
    final statusLabel = switch (state) {
      _CelebrationDayState.filled =>
        context.tr.translate('streak_calendar_logged_day'),
      _CelebrationDayState.protected =>
        context.tr.translate('streak_freeze_active'),
      _CelebrationDayState.empty => '',
    };
    final semanticLabel =
        statusLabel.isEmpty ? dateLabel : '$dateLabel: $statusLabel';
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Semantics(
      image: true,
      label: semanticLabel,
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _weekdayLabel(context, date.weekday),
            maxLines: 1,
            style: TextStyle(
              color: _primaryTextColor(context),
              fontSize: compact ? 12 : 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: compact ? 7 : 10),
          SizedBox.square(
            dimension: compact ? 31 : 36,
            child: switch (state) {
              _CelebrationDayState.filled => const _SmallFlameMark(),
              _CelebrationDayState.protected => Icon(
                  Icons.ac_unit_rounded,
                  color: _freezeBlue,
                  size: compact ? 29 : 34,
                ),
              _CelebrationDayState.empty => Center(
                  child: Container(
                    width: compact ? 25 : 29,
                    height: compact ? 25 : 29,
                    decoration: BoxDecoration(
                      color: isDarkMode
                          ? AppTheme.darkComponentColor
                          : const Color(0xFFEEF3F7),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            },
          ),
        ],
      ),
    );
  }
}

class _SmallFlameMark extends StatelessWidget {
  const _SmallFlameMark();

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.bottomCenter,
      children: const [
        Icon(
          Icons.local_fire_department_rounded,
          color: _celebrationOrange,
          size: 36,
        ),
        Padding(
          padding: EdgeInsets.only(bottom: 5),
          child: Icon(
            Icons.local_fire_department_rounded,
            color: _celebrationYellow,
            size: 18,
          ),
        ),
      ],
    );
  }
}

class _FreezeGiftIllustration extends StatelessWidget {
  final bool compact;
  final int freezesAvailable;

  const _FreezeGiftIllustration({
    required this.compact,
    required this.freezesAvailable,
  });

  @override
  Widget build(BuildContext context) {
    final height = compact ? 222.0 : 286.0;
    return SizedBox(
      key: const ValueKey('streak-celebration-freeze-illustration'),
      height: height,
      width: double.infinity,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Positioned(
            top: 0,
            child: Icon(
              Icons.ac_unit_rounded,
              color: _freezeBlue,
              size: compact ? 94 : 126,
            ),
          ),
          Positioned(
            left: compact ? 28 : 54,
            top: compact ? 27 : 44,
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: _freezeBlue,
              size: 31,
            ),
          ),
          Positioned(
            right: compact ? 25 : 48,
            top: compact ? 60 : 82,
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: _freezeBlue,
              size: 25,
            ),
          ),
          Positioned(
            right: compact ? 8 : 24,
            top: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: _freezeBlue.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(99),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.ac_unit_rounded,
                    color: _freezeBlue,
                    size: 17,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$freezesAvailable',
                    style: TextStyle(
                      color: _primaryTextColor(context),
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: compact ? 12 : 36,
            right: compact ? 43 : 68,
            bottom: 0,
            child: _GiftBox(compact: compact),
          ),
          Positioned(
            right: compact ? 6 : 27,
            bottom: compact ? 1 : 4,
            child: _CelebrationMascot(compact: compact),
          ),
        ],
      ),
    );
  }
}

class _GiftBox extends StatelessWidget {
  final bool compact;

  const _GiftBox({required this.compact});

  @override
  Widget build(BuildContext context) {
    final boxHeight = compact ? 86.0 : 110.0;
    return SizedBox(
      height: compact ? 126 : 158,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          Container(
            height: boxHeight,
            decoration: BoxDecoration(
              color: const Color(0xFFEC7041),
              borderRadius: BorderRadius.circular(compact ? 13 : 17),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x15243847),
                  blurRadius: 12,
                  offset: Offset(0, 8),
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 0,
            child: Container(
              width: compact ? 35 : 45,
              height: boxHeight,
              color: const Color(0xFFFFE15D),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: boxHeight - (compact ? 9 : 12),
            child: Transform.rotate(
              angle: -0.025,
              child: Container(
                height: compact ? 26 : 33,
                decoration: BoxDecoration(
                  color: const Color(0xFFE86535),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Center(
                  child: Container(
                    width: compact ? 35 : 45,
                    color: const Color(0xFFFFE15D),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: compact ? 30 : 42,
            child: Transform.rotate(
              angle: -0.62,
              child: Container(
                width: compact ? 57 : 70,
                height: compact ? 31 : 38,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: const Color(0xFFFFE15D),
                    width: compact ? 9 : 11,
                  ),
                  borderRadius:
                      const BorderRadius.all(Radius.elliptical(60, 35)),
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            right: compact ? 30 : 42,
            child: Transform.rotate(
              angle: 0.62,
              child: Container(
                width: compact ? 57 : 70,
                height: compact ? 31 : 38,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: const Color(0xFFFFE15D),
                    width: compact ? 9 : 11,
                  ),
                  borderRadius:
                      const BorderRadius.all(Radius.elliptical(60, 35)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CelebrationMascot extends StatelessWidget {
  final bool compact;

  const _CelebrationMascot({required this.compact});

  @override
  Widget build(BuildContext context) {
    final width = compact ? 42.0 : 52.0;
    final bodyHeight = compact ? 70.0 : 88.0;
    return SizedBox(
      width: width,
      height: bodyHeight + 15,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          Container(
            width: width,
            height: bodyHeight,
            decoration: const BoxDecoration(
              color: Color(0xFF64B95E),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(32),
                topRight: Radius.circular(32),
                bottomLeft: Radius.circular(15),
                bottomRight: Radius.circular(15),
              ),
            ),
          ),
          Positioned(
            top: compact ? 17 : 22,
            left: compact ? 12 : 15,
            child: const _MascotEye(),
          ),
          Positioned(
            top: compact ? 17 : 22,
            right: compact ? 12 : 15,
            child: const _MascotEye(),
          ),
          Positioned(
            top: compact ? 36 : 45,
            child: Container(
              width: compact ? 22 : 28,
              height: compact ? 22 : 28,
              decoration: const BoxDecoration(
                color: Color(0xFFFFD342),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            left: compact ? 10 : 13,
            bottom: 0,
            child: Container(
              width: 5,
              height: 20,
              decoration: BoxDecoration(
                color: const Color(0xFF4AA34B),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          Positioned(
            right: compact ? 10 : 13,
            bottom: 0,
            child: Container(
              width: 5,
              height: 20,
              decoration: BoxDecoration(
                color: const Color(0xFF4AA34B),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MascotEye extends StatelessWidget {
  const _MascotEye();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 4,
      height: 6,
      decoration: const BoxDecoration(
        color: Color(0xFF17372E),
        shape: BoxShape.circle,
      ),
    );
  }
}

DateTime _dateOnly(DateTime value) {
  return DateTime(value.year, value.month, value.day);
}

int _dateKey(DateTime value) {
  return value.year * 10000 + value.month * 100 + value.day;
}

String _weekdayLabel(BuildContext context, int weekday) {
  final key = switch (weekday) {
    DateTime.monday => 'day_mon_short',
    DateTime.tuesday => 'day_tue_short',
    DateTime.wednesday => 'day_wed_short',
    DateTime.thursday => 'day_thu_short',
    DateTime.friday => 'day_fri_short',
    DateTime.saturday => 'day_sat_short',
    _ => 'day_sun_short',
  };
  final label = context.tr.translate(key).trim();
  return label.isEmpty ? '' : label.substring(0, 1).toUpperCase();
}
