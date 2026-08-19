import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../i18n/app_localizations_extension.dart';
import '../services/streak_widget_service.dart';
import '../theme/app_theme.dart';

class StreakWidgetOnboardingScreen extends StatefulWidget {
  final int calories;
  final int calorieGoal;
  final int streak;
  final int initialStep;

  const StreakWidgetOnboardingScreen({
    super.key,
    required this.calories,
    required this.calorieGoal,
    required this.streak,
    this.initialStep = 0,
  });

  @override
  State<StreakWidgetOnboardingScreen> createState() =>
      _StreakWidgetOnboardingScreenState();
}

class _StreakWidgetOnboardingScreenState
    extends State<StreakWidgetOnboardingScreen> {
  late int _step;
  bool _requestingPin = false;

  @override
  void initState() {
    super.initState();
    _step = widget.initialStep.clamp(0, 1);
  }

  Future<void> _continue() async {
    if (_step == 0) {
      HapticFeedback.selectionClick();
      setState(() => _step = 1);
      return;
    }

    if (_requestingPin) return;
    setState(() => _requestingPin = true);
    await StreakWidgetService.update(
      StreakWidgetSnapshot(
        calories: widget.calories,
        calorieGoal: widget.calorieGoal,
        streak: widget.streak,
        date: DateTime.now(),
      ),
    );
    final result = await StreakWidgetService.requestPin();
    if (!mounted) return;

    switch (result) {
      case StreakWidgetPinResult.requested:
      case StreakWidgetPinResult.alreadyAdded:
        Navigator.of(context).pop(result);
        return;
      case StreakWidgetPinResult.unsupported:
      case StreakWidgetPinResult.failed:
        setState(() => _requestingPin = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.tr.translate('streak_widget_unavailable'),
            ),
          ),
        );
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final compact = mediaQuery.size.height < 700;
    final bottomInset = mediaQuery.padding.bottom;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: const Color(0xFF101716),
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFF101716),
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF172524), Color(0xFF101716)],
              stops: [0, 0.72],
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Column(
              children: [
                SizedBox(
                  height: 54,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: AnimatedOpacity(
                      opacity: _step == 1 ? 1 : 0,
                      duration: const Duration(milliseconds: 180),
                      child: IconButton(
                        onPressed: _step == 1
                            ? () => Navigator.maybePop(context)
                            : null,
                        tooltip: MaterialLocalizations.of(context)
                            .closeButtonTooltip,
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                          size: 30,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0.06, 0),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    ),
                    child: _step == 0
                        ? _ChallengeStep(
                            key: const ValueKey('challenge'),
                            compact: compact,
                          )
                        : _WidgetStep(
                            key: const ValueKey('widget'),
                            compact: compact,
                            calories: widget.calories,
                            calorieGoal: widget.calorieGoal,
                            streak: widget.streak,
                          ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(24, 12, 24, bottomInset + 18),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: double.infinity,
                        height: 58,
                        child: FilledButton(
                          onPressed: _requestingPin ? null : _continue,
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF101716),
                            disabledBackgroundColor:
                                Colors.white.withValues(alpha: 0.72),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          child: _requestingPin
                              ? const SizedBox.square(
                                  dimension: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Color(0xFF101716),
                                  ),
                                )
                              : Text(
                                  context.tr.translate(
                                    _step == 0
                                        ? 'streak_intro_challenge_cta'
                                        : 'streak_intro_widget_cta',
                                  ),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                        ),
                      ),
                      if (_step == 1) ...[
                        const SizedBox(height: 4),
                        TextButton(
                          onPressed: _requestingPin
                              ? null
                              : () => Navigator.of(context).pop(),
                          style: TextButton.styleFrom(
                            foregroundColor:
                                Colors.white.withValues(alpha: 0.72),
                          ),
                          child: Text(
                            context.tr.translate('streak_intro_not_now'),
                          ),
                        ),
                      ],
                    ],
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

class _ChallengeStep extends StatelessWidget {
  final bool compact;

  const _ChallengeStep({super.key, required this.compact});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        children: [
          SizedBox(height: compact ? 12 : 38),
          const _ThreeDayIllustration(),
          SizedBox(height: compact ? 22 : 42),
          Text(
            context.tr.translate('streak_intro_challenge_title'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              height: 1.08,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.8,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            context.tr.translate('streak_intro_challenge_body'),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.84),
              fontSize: 18,
              height: 1.4,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _WidgetStep extends StatelessWidget {
  final bool compact;
  final int calories;
  final int calorieGoal;
  final int streak;

  const _WidgetStep({
    super.key,
    required this.compact,
    required this.calories,
    required this.calorieGoal,
    required this.streak,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        children: [
          SizedBox(height: compact ? 4 : 24),
          _WidgetIllustration(
            calories: calories,
            calorieGoal: calorieGoal,
            streak: streak,
          ),
          SizedBox(height: compact ? 22 : 42),
          Text(
            context.tr.translate('streak_intro_widget_title'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              height: 1.08,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.8,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            context.tr.translate('streak_intro_widget_body'),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.84),
              fontSize: 18,
              height: 1.4,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _ThreeDayIllustration extends StatelessWidget {
  const _ThreeDayIllustration();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 250,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 220,
            height: 220,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppTheme.primaryColor.withValues(alpha: 0.32),
                  AppTheme.primaryColor.withValues(alpha: 0),
                ],
              ),
            ),
          ),
          Container(
            width: 188,
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
            decoration: BoxDecoration(
              color: const Color(0xFF243230),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.12),
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x44000000),
                  blurRadius: 28,
                  offset: Offset(0, 14),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(
                    3,
                    (index) => Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: index == 0
                            ? AppTheme.primaryColor
                            : Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Icon(
                        index == 0 ? Icons.check_rounded : Icons.add_rounded,
                        color: index == 0
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.5),
                        size: 24,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const _FlameIcon(size: 94),
              ],
            ),
          ),
          Positioned(
            right: 48,
            top: 24,
            child: Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFFFD6AA), width: 3),
              ),
              child: const Center(child: _FlameIcon(size: 34)),
            ),
          ),
        ],
      ),
    );
  }
}

class _WidgetIllustration extends StatelessWidget {
  final int calories;
  final int calorieGoal;
  final int streak;

  const _WidgetIllustration({
    required this.calories,
    required this.calorieGoal,
    required this.streak,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 250,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 260,
            height: 210,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(48),
              gradient: RadialGradient(
                colors: [
                  const Color(0xFF7757F7).withValues(alpha: 0.34),
                  const Color(0xFF7757F7).withValues(alpha: 0),
                ],
              ),
            ),
          ),
          Transform.rotate(
            angle: -0.035,
            child: Container(
              width: 294,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFF273331),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x55000000),
                    blurRadius: 32,
                    offset: Offset(0, 18),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const _FlameIcon(size: 60),
                      const SizedBox(height: 4),
                      Text(
                        '$streak',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 28,
                          height: 1,
                        ),
                      ),
                      Text(
                        context.tr.translate(
                          streak == 1
                              ? 'streak_widget_day_one'
                              : 'streak_widget_days_other',
                        ),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.68),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    height: 90,
                    width: 1,
                    margin: const EdgeInsets.symmetric(horizontal: 18),
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          context.tr.translate('streak_widget_today'),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$calories kcal',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 25,
                          ),
                        ),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(99),
                          child: LinearProgressIndicator(
                            value: calorieGoal <= 0
                                ? 0
                                : (calories / calorieGoal).clamp(0.0, 1.0),
                            minHeight: 7,
                            backgroundColor:
                                Colors.white.withValues(alpha: 0.1),
                            color: AppTheme.primaryColorDarkMode,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${calorieGoal.clamp(1, 999999)} kcal',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.58),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
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

class _FlameIcon extends StatelessWidget {
  final double size;

  const _FlameIcon({required this.size});

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (bounds) => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFFFD34E), Color(0xFFFF8A24), Color(0xFFFF4D3D)],
      ).createShader(bounds),
      child: Icon(
        Icons.local_fire_department_rounded,
        size: size,
        color: Colors.white,
      ),
    );
  }
}
