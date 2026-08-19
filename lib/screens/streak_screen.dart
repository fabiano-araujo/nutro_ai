import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../controllers/navigation_controller.dart';
import '../i18n/app_localizations_extension.dart';
import '../providers/daily_meals_provider.dart';
import '../providers/friends_provider.dart';
import '../providers/nutrition_goals_provider.dart';
import '../providers/streak_provider.dart';
import '../services/social_service.dart';
import '../services/streak_widget_service.dart';
import '../theme/app_theme.dart';
import '../theme/macro_theme.dart';
import '../utils/streak_helper.dart';
import '../widgets/diet_style_message_state.dart';
import 'friends_screen.dart';
import 'streak_widget_onboarding_screen.dart';

Color _streakInputFillColor(bool isDarkMode) => isDarkMode
    ? AppTheme.darkComponentColor
    : AppTheme.surfaceColor.withValues(alpha: 0.62);

Color _streakBorderColor(bool isDarkMode) => isDarkMode
    ? AppTheme.darkBorderColor.withValues(alpha: 0.46)
    : AppTheme.dividerColor.withValues(alpha: 0.75);

Color _streakMutedTextColor(bool isDarkMode) =>
    isDarkMode ? AppTheme.darkMutedTextColor : AppTheme.textSecondaryColor;

Color _streakPrimaryColor(bool isDarkMode) =>
    isDarkMode ? AppTheme.primaryColorDarkMode : AppTheme.primaryColor;

enum _StreakCalendarMode { registration, protein, calories }

Color _calendarMarkColor(_StreakCalendarMode mode) {
  switch (mode) {
    case _StreakCalendarMode.registration:
      return MacroTheme.caloriesColor;
    case _StreakCalendarMode.protein:
      return MacroTheme.proteinColor;
    case _StreakCalendarMode.calories:
      return MacroTheme.caloriesColor;
  }
}

bool _calorieModeAllowsBelowGoal(FitnessGoal goal) {
  switch (goal) {
    case FitnessGoal.loseWeight:
    case FitnessGoal.loseWeightSlowly:
    case FitnessGoal.maintainWeight:
      return true;
    case FitnessGoal.gainWeightSlowly:
    case FitnessGoal.gainWeight:
      return false;
  }
}

bool _calorieModeAllowsAboveGoal(FitnessGoal goal) {
  switch (goal) {
    case FitnessGoal.loseWeight:
    case FitnessGoal.loseWeightSlowly:
      return false;
    case FitnessGoal.maintainWeight:
    case FitnessGoal.gainWeightSlowly:
    case FitnessGoal.gainWeight:
      return true;
  }
}

String _calendarModeLabel(BuildContext context, _StreakCalendarMode mode) {
  switch (mode) {
    case _StreakCalendarMode.registration:
      return context.tr.translate('streak_calendar_logged_day');
    case _StreakCalendarMode.protein:
      return context.tr.translate('streak_secondary_protein');
    case _StreakCalendarMode.calories:
      return context.tr.translate('streak_secondary_goal');
  }
}

int _resolveProteinStreak({
  required StreakProvider streakProvider,
  required DailyMealsProvider mealsProvider,
  required int proteinTarget,
}) {
  final localStreak = mealsProvider.getCurrentProteinGoalStreak(
    proteinTarget: proteinTarget,
  );
  final backendStreak = streakProvider.proteinStreak;
  final lastDate = streakProvider.streak?.proteinLastDate;
  if (backendStreak <= localStreak || lastDate == null) {
    return localStreak;
  }

  final knowsLastDate = mealsProvider.hasNutritionDataOn(lastDate);
  final lastDateStillHits = mealsProvider.hasHitProteinGoalOn(
    lastDate,
    proteinTarget: proteinTarget,
  );
  return knowsLastDate && !lastDateStillHits ? localStreak : backendStreak;
}

int _resolveCalorieStreak({
  required StreakProvider streakProvider,
  required DailyMealsProvider mealsProvider,
  required int calorieGoal,
  required bool allowBelowGoal,
  required bool allowAboveGoal,
}) {
  final localStreak = mealsProvider.getCurrentCalorieGoalStreak(
    calorieGoal: calorieGoal,
    allowBelowGoal: allowBelowGoal,
    allowAboveGoal: allowAboveGoal,
  );
  final backendStreak = streakProvider.goalStreak;
  final lastDate = streakProvider.streak?.goalLastDate;
  if (backendStreak <= localStreak || lastDate == null) {
    return localStreak;
  }

  final knowsLastDate = mealsProvider.hasNutritionDataOn(lastDate);
  final lastDateStillHits = mealsProvider.hasHitCalorieGoalOn(
    lastDate,
    calorieGoal: calorieGoal,
    allowBelowGoal: allowBelowGoal,
    allowAboveGoal: allowAboveGoal,
  );
  return knowsLastDate && !lastDateStillHits ? localStreak : backendStreak;
}

class StreakScreen extends StatefulWidget {
  const StreakScreen({super.key});

  @override
  State<StreakScreen> createState() => _StreakScreenState();
}

class _StreakScreenState extends State<StreakScreen> {
  int _selectedTab = 0;
  late DateTime _visibleMonth;
  _StreakCalendarMode _calendarMode = _StreakCalendarMode.registration;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _visibleMonth = DateTime(now.year, now.month);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _refreshData();
      }
    });
  }

  Future<void> _refreshData() {
    return Future.wait([
      context.read<StreakProvider>().refresh(),
      context.read<FriendsProvider>().refresh(),
    ]);
  }

  void _previousMonth() {
    setState(() {
      _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month - 1);
    });
  }

  void _nextMonth() {
    final now = DateTime.now();
    final currentMonth = DateTime(now.year, now.month);
    if (!_visibleMonth.isBefore(currentMonth)) return;

    setState(() {
      _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + 1);
    });
  }

  void _setCalendarMode(_StreakCalendarMode mode) {
    final nextMode =
        _calendarMode == mode ? _StreakCalendarMode.registration : mode;
    final streak = context.read<StreakProvider>().streak;
    final targetDate = switch (nextMode) {
      _StreakCalendarMode.registration => streak?.registrationLastDate,
      _StreakCalendarMode.protein => streak?.proteinLastDate,
      _StreakCalendarMode.calories => streak?.goalLastDate,
    };

    setState(() {
      _calendarMode = nextMode;
      if (targetDate != null && !targetDate.isAfter(DateTime.now())) {
        _visibleMonth = DateTime(targetDate.year, targetDate.month);
      }
    });
  }

  Future<void> _shareStreak() async {
    final count = effectiveRegistrationStreak(
      context.read<StreakProvider>(),
      context.read<DailyMealsProvider>(),
    );
    final message = context.tr
        .translate(
          count == 1
              ? 'streak_share_message_one'
              : 'streak_share_message_other',
        )
        .replaceAll('{count}', count.toString());
    await SharePlus.instance.share(ShareParams(text: message));
  }

  void _openFriends() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const FriendsScreen(isEmbedded: false),
      ),
    );
  }

  void _completeCommitment() {
    HapticFeedback.mediumImpact();
    navigationController.changeTab(0);
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDarkMode ? Colors.white : AppTheme.textPrimaryColor;

    return Scaffold(
      backgroundColor:
          isDarkMode ? AppTheme.darkBackgroundColor : AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness:
              isDarkMode ? Brightness.light : Brightness.dark,
          statusBarBrightness: isDarkMode ? Brightness.dark : Brightness.light,
        ),
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: Icon(Icons.close_rounded, color: textColor, size: 28),
          tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          context.tr.translate('streak_screen_title'),
          style: theme.textTheme.titleLarge?.copyWith(
            color: textColor,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: IconButton(
              icon: Icon(Icons.ios_share_rounded, color: textColor, size: 24),
              tooltip: context.tr.translate('streak_share_tooltip'),
              onPressed: _shareStreak,
            ),
          ),
        ],
        centerTitle: true,
        scrolledUnderElevation: 0,
        elevation: 0,
      ),
      body: Stack(
        children: [
          Column(
            children: [
              _StreakModeTabs(
                selectedIndex: _selectedTab,
                onChanged: (index) => setState(() => _selectedTab = index),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _refreshData,
                  color: _streakPrimaryColor(isDarkMode),
                  child: _selectedTab == 0
                      ? _PersonalStreakTab(
                          key: const ValueKey('personal-streak-tab'),
                          visibleMonth: _visibleMonth,
                          calendarMode: _calendarMode,
                          onPreviousMonth: _previousMonth,
                          onNextMonth: _nextMonth,
                          onCalendarModeChanged: _setCalendarMode,
                        )
                      : _FriendsStreakTab(
                          key: const ValueKey('friends-streak-tab'),
                          onInviteFriends: _openFriends,
                        ),
                ),
              ),
            ],
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _StreakCommitmentBar(
              onPressed: _completeCommitment,
            ),
          ),
        ],
      ),
    );
  }
}

class _StreakCommitmentBar extends StatelessWidget {
  final VoidCallback onPressed;

  const _StreakCommitmentBar({
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final background =
        isDarkMode ? AppTheme.darkBackgroundColor : AppTheme.backgroundColor;

    return ColoredBox(
      color: background.withValues(alpha: 0.98),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(24, 10, 24, 14),
        child: SizedBox(
          width: double.infinity,
          height: 58,
          child: FilledButton.icon(
            onPressed: onPressed,
            icon: const Icon(
              Icons.local_fire_department_rounded,
              size: 22,
            ),
            label: Text(context.tr.translate('streak_commit_cta')),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              elevation: 2,
              shadowColor: AppTheme.primaryDarkColor.withValues(alpha: 0.35),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              textStyle: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StreakModeTabs extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  const _StreakModeTabs({
    required this.selectedIndex,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _StreakModeChip(
            label: context.tr.translate('streak_tab_personal'),
            selected: selectedIndex == 0,
            isDarkMode: isDarkMode,
            onTap: () => onChanged(0),
          ),
          const SizedBox(width: 12),
          _StreakModeChip(
            label: context.tr.translate('streak_tab_friends'),
            selected: selectedIndex == 1,
            isDarkMode: isDarkMode,
            onTap: () => onChanged(1),
          ),
        ],
      ),
    );
  }
}

class _StreakModeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final bool isDarkMode;
  final VoidCallback onTap;

  const _StreakModeChip({
    required this.label,
    required this.selected,
    required this.isDarkMode,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final selectedBackground = AppTheme.selectedPillBackgroundColor(isDarkMode);
    final selectedForeground = AppTheme.selectedPillTextColor(isDarkMode);
    final unselectedBackground =
        isDarkMode ? AppTheme.darkCardColor : Colors.white;
    final unselectedBorderColor =
        isDarkMode ? AppTheme.darkBorderColor : AppTheme.dividerColor;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.profileCardShadow(isDarkMode),
      ),
      child: ChoiceChip(
        label: SizedBox(
          width: 100,
          child: Text(
            label,
            textAlign: TextAlign.center,
          ),
        ),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: selectedBackground,
        backgroundColor: unselectedBackground,
        labelStyle: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: selected
              ? selectedForeground
              : (isDarkMode ? Colors.grey[400] : Colors.grey[700]),
        ),
        showCheckmark: false,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: selected
              ? BorderSide.none
              : BorderSide(color: unselectedBorderColor),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        pressElevation: 0,
        elevation: 0,
        disabledColor: unselectedBackground,
        surfaceTintColor:
            isDarkMode ? AppTheme.darkComponentColor : AppTheme.surfaceColor,
      ),
    );
  }
}

class _PersonalStreakTab extends StatelessWidget {
  final DateTime visibleMonth;
  final _StreakCalendarMode calendarMode;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;
  final ValueChanged<_StreakCalendarMode> onCalendarModeChanged;

  const _PersonalStreakTab({
    super.key,
    required this.visibleMonth,
    required this.calendarMode,
    required this.onPreviousMonth,
    required this.onNextMonth,
    required this.onCalendarModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer3<StreakProvider, DailyMealsProvider,
        NutritionGoalsProvider>(
      builder: (context, streakProvider, mealsProvider, goalsProvider, _) {
        final isLoading = streakProvider.isLoading && !streakProvider.hasStreak;
        final effectiveStreak =
            effectiveRegistrationStreak(streakProvider, mealsProvider);
        final allowCalorieBelowGoal =
            _calorieModeAllowsBelowGoal(goalsProvider.fitnessGoal);
        final allowCalorieAboveGoal =
            _calorieModeAllowsAboveGoal(goalsProvider.fitnessGoal);
        final effectiveProteinStreak = _resolveProteinStreak(
          streakProvider: streakProvider,
          mealsProvider: mealsProvider,
          proteinTarget: goalsProvider.proteinGoal,
        );
        final effectiveCalorieStreak = _resolveCalorieStreak(
          streakProvider: streakProvider,
          mealsProvider: mealsProvider,
          calorieGoal: goalsProvider.caloriesGoal,
          allowBelowGoal: allowCalorieBelowGoal,
          allowAboveGoal: allowCalorieAboveGoal,
        );

        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 124),
          children: [
            if (isLoading)
              const SizedBox(
                height: 320,
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              _StreakCelebrationHero(
                registrationStreak: effectiveStreak,
              ),
              const SizedBox(height: 24),
              _SectionTitle(
                title: context.tr.translate('streak_challenge_section'),
              ),
              const SizedBox(height: 10),
              _MilestoneChallengeCard(streak: effectiveStreak),
              const SizedBox(height: 24),
              _SectionTitle(
                title: context.tr.translate('streak_overview_section'),
              ),
              const SizedBox(height: 10),
              _RollingWeekCard(mealsProvider: mealsProvider),
              const SizedBox(height: 24),
              _SectionTitle(
                title: context.tr.translate('streak_summary_section'),
              ),
              const SizedBox(height: 10),
              _StreakSummaryCard(
                bestStreak: math.max(
                  streakProvider.streak?.registrationBestStreak ?? 0,
                  effectiveStreak,
                ),
                freezesAvailable: streakProvider.freezesAvailable,
              ),
              _StreakHomeWidgetCard(
                mealsProvider: mealsProvider,
                streak: effectiveStreak,
              ),
              _StreakDetailsExpansion(
                proteinStreak: effectiveProteinStreak,
                calorieStreak: effectiveCalorieStreak,
                selectedMode: calendarMode,
                onModeSelected: onCalendarModeChanged,
                calendar: _StreakCalendarCard(
                  visibleMonth: visibleMonth,
                  mealsProvider: mealsProvider,
                  goalsProvider: goalsProvider,
                  mode: calendarMode,
                  registrationLastDate:
                      streakProvider.streak?.registrationLastDate,
                  proteinLastDate: streakProvider.streak?.proteinLastDate,
                  calorieLastDate: streakProvider.streak?.goalLastDate,
                  onPreviousMonth: onPreviousMonth,
                  onNextMonth: onNextMonth,
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

const _streakFlameOrange = Color(0xFFFF7A32);

class _StreakCelebrationHero extends StatelessWidget {
  final int registrationStreak;

  const _StreakCelebrationHero({required this.registrationStreak});

  @override
  Widget build(BuildContext context) {
    final hasStarted = registrationStreak > 0;
    final messageKey = registrationStreak == 0
        ? 'streak_hero_start_hint'
        : registrationStreak == 1
            ? 'streak_hero_started'
            : 'streak_hero_continue';

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF176E69), Color(0xFF4E45B8), Color(0xFF8C69E8)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4E45B8).withValues(alpha: 0.26),
            blurRadius: 26,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          const Positioned(
            right: -34,
            top: -46,
            child: _HeroGlow(size: 190),
          ),
          Positioned(
            left: -80,
            bottom: -120,
            child: _HeroGlow(
              size: 220,
              color: Colors.white.withValues(alpha: 0.08),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$registrationStreak',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 68,
                              height: 0.9,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -2,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            context.tr.translate(
                              registrationStreak == 1
                                  ? 'streak_widget_day_one'
                                  : 'streak_widget_days_other',
                            ),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              height: 1,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _AnimatedHeroFlame(active: hasStarted),
                  ],
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 15,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF141918).withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(
                        hasStarted ? '🎉' : '🍽️',
                        style: const TextStyle(fontSize: 26),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          context.tr.translate(messageKey),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            height: 1.28,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AnimatedHeroFlame extends StatefulWidget {
  final bool active;

  const _AnimatedHeroFlame({required this.active});

  @override
  State<_AnimatedHeroFlame> createState() => _AnimatedHeroFlameState();
}

class _AnimatedHeroFlameState extends State<_AnimatedHeroFlame>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _shouldAnimate = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1650),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncAnimation();
  }

  @override
  void didUpdateWidget(covariant _AnimatedHeroFlame oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active != widget.active) {
      _syncAnimation();
    }
  }

  void _syncAnimation() {
    final shouldAnimate =
        widget.active && !MediaQuery.disableAnimationsOf(context);
    if (_shouldAnimate == shouldAnimate) return;
    _shouldAnimate = shouldAnimate;
    if (shouldAnimate) {
      _controller.repeat();
    } else {
      _controller
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final phase = _controller.value * math.pi * 2;
          final pulse = math.sin(phase);
          final sway = _shouldAnimate ? math.sin(phase + (math.pi / 3)) : 0.0;

          return Transform.translate(
            key: const ValueKey('streak-animated-flame'),
            offset: Offset(0, -2.5 * pulse),
            child: Transform.rotate(
              angle: sway * 0.025,
              child: Transform.scale(
                scale: 1 + (pulse * 0.035),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Opacity(
                      opacity: widget.active ? 0.16 + (pulse * 0.035) : 0.06,
                      child: Transform.scale(
                        scale: 0.92 + (pulse * 0.04),
                        child: Container(
                          width: 124,
                          height: 124,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [Color(0xFFFFD75B), Color(0x00FF7138)],
                            ),
                          ),
                        ),
                      ),
                    ),
                    ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0xFFFFE05B),
                          Color(0xFFFF9D2E),
                          Color(0xFFFF5B36),
                        ],
                      ).createShader(bounds),
                      child: Icon(
                        Icons.local_fire_department_rounded,
                        color: widget.active
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.48),
                        size: 124,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _HeroGlow extends StatelessWidget {
  final double size;
  final Color color;

  const _HeroGlow({
    required this.size,
    this.color = const Color(0x26FFFFFF),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _MilestoneChallengeCard extends StatelessWidget {
  final int streak;

  const _MilestoneChallengeCard({required this.streak});

  int get _target {
    if (streak < 3) return 3;
    if (streak < 7) return 7;
    if (streak < 14) return 14;
    return ((streak ~/ 7) + 1) * 7;
  }

  @override
  Widget build(BuildContext context) {
    final target = _target;
    final displayCurrent = streak.clamp(0, target);
    final progress = target == 0 ? 0.0 : (displayCurrent / target);

    return _SocialStyleCard(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  context.tr
                      .translate('streak_challenge_next')
                      .replaceAll('{target}', target.toString()),
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                context.tr
                    .translate('streak_challenge_day_progress')
                    .replaceAll('{current}', displayCurrent.toString())
                    .replaceAll('{target}', target.toString()),
                style: TextStyle(
                  color: _streakMutedTextColor(
                    Theme.of(context).brightness == Brightness.dark,
                  ),
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 12,
              color: _streakFlameOrange,
              backgroundColor: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white.withValues(alpha: 0.1)
                  : const Color(0xFFE6E9ED),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              for (final milestone in const [3, 7, 14]) ...[
                if (milestone != 3) const SizedBox(width: 8),
                Expanded(
                  child: _MilestoneChip(
                    milestone: milestone,
                    achieved: streak >= milestone,
                    active: milestone == target,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _MilestoneChip extends StatelessWidget {
  final int milestone;
  final bool achieved;
  final bool active;

  const _MilestoneChip({
    required this.milestone,
    required this.achieved,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final color = achieved || active
        ? _streakFlameOrange
        : _streakMutedTextColor(isDarkMode);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: achieved ? 0.16 : 0.07),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: color.withValues(alpha: active ? 0.6 : 0.22)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            achieved ? Icons.check_circle_rounded : Icons.flag_rounded,
            color: color,
            size: 16,
          ),
          const SizedBox(width: 5),
          Text(
            '$milestone',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _RollingWeekCard extends StatelessWidget {
  final DailyMealsProvider mealsProvider;

  const _RollingWeekCard({required this.mealsProvider});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final days = List.generate(
      7,
      (index) => today.subtract(Duration(days: 6 - index)),
    );

    return _SocialStyleCard(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 18),
      child: Row(
        children: [
          for (final day in days)
            Expanded(
              child: _RollingWeekDay(
                label: _weekdayLabel(context, day.weekday),
                logged: mealsProvider.hasMealsOn(day),
                isToday: day == today,
                isDarkMode: isDarkMode,
              ),
            ),
        ],
      ),
    );
  }

  String _weekdayLabel(BuildContext context, int weekday) {
    final keys = <int, String>{
      DateTime.monday: 'day_mon_short',
      DateTime.tuesday: 'day_tue_short',
      DateTime.wednesday: 'day_wed_short',
      DateTime.thursday: 'day_thu_short',
      DateTime.friday: 'day_fri_short',
      DateTime.saturday: 'day_sat_short',
      DateTime.sunday: 'day_sun_short',
    };
    return context.tr.translate(keys[weekday]!);
  }
}

class _RollingWeekDay extends StatelessWidget {
  final String label;
  final bool logged;
  final bool isToday;
  final bool isDarkMode;

  const _RollingWeekDay({
    required this.label,
    required this.logged,
    required this.isToday,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    final inactive = _streakMutedTextColor(isDarkMode).withValues(alpha: 0.42);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          maxLines: 1,
          style: TextStyle(
            color: isToday ? _streakFlameOrange : inactive,
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 10),
        Icon(
          Icons.local_fire_department_rounded,
          color: logged ? _streakFlameOrange : inactive,
          size: 34,
        ),
        const SizedBox(height: 5),
        Container(
          width: 5,
          height: 5,
          decoration: BoxDecoration(
            color: isToday ? _streakFlameOrange : Colors.transparent,
            shape: BoxShape.circle,
          ),
        ),
      ],
    );
  }
}

class _StreakSummaryCard extends StatelessWidget {
  final int bestStreak;
  final int freezesAvailable;

  const _StreakSummaryCard({
    required this.bestStreak,
    required this.freezesAvailable,
  });

  @override
  Widget build(BuildContext context) {
    final protectionKey = freezesAvailable == 1
        ? 'streak_protection_one'
        : 'streak_protection_other';
    return _SocialStyleCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          _StreakSummaryRow(
            icon: Icons.local_fire_department_rounded,
            iconColor: _streakFlameOrange,
            label: context.tr.translate('streak_best_registration'),
            value: '$bestStreak',
          ),
          Divider(
            height: 1,
            color: _streakBorderColor(
              Theme.of(context).brightness == Brightness.dark,
            ),
          ),
          _StreakSummaryRow(
            icon: Icons.shield_rounded,
            iconColor: const Color(0xFF66C8FF),
            label: context.tr
                .translate(protectionKey)
                .replaceAll('{count}', freezesAvailable.toString()),
            value: '$freezesAvailable/2',
          ),
        ],
      ),
    );
  }
}

class _StreakSummaryRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  const _StreakSummaryRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(icon, color: iconColor, size: 27),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: isDarkMode ? Colors.white : AppTheme.textPrimaryColor,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            value,
            style: TextStyle(
              color: isDarkMode ? Colors.white : AppTheme.textPrimaryColor,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _StreakHomeWidgetCard extends StatefulWidget {
  final DailyMealsProvider mealsProvider;
  final int streak;

  const _StreakHomeWidgetCard({
    required this.mealsProvider,
    required this.streak,
  });

  @override
  State<_StreakHomeWidgetCard> createState() => _StreakHomeWidgetCardState();
}

class _StreakHomeWidgetCardState extends State<_StreakHomeWidgetCard>
    with WidgetsBindingObserver {
  bool? _isSupported;
  bool _isAdded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshState();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshState();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _refreshState() async {
    final supported = await StreakWidgetService.isSupported();
    final added = supported && await StreakWidgetService.isAdded();
    if (!mounted) return;
    setState(() {
      _isSupported = supported;
      _isAdded = added;
    });
  }

  Future<void> _openWidgetSetup() async {
    final now = DateTime.now();
    final nutrition = widget.mealsProvider.getNutritionSnapshotForDate(now);
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => StreakWidgetOnboardingScreen(
          initialStep: 1,
          calories: (nutrition['calories'] as num?)?.round() ?? 0,
          calorieGoal: (nutrition['calorieGoal'] as num?)?.round() ??
              widget.mealsProvider.caloriesGoal,
          streak: widget.streak,
        ),
      ),
    );
    await _refreshState();
  }

  @override
  Widget build(BuildContext context) {
    // Depois que o launcher confirma a instalação, não mantemos um card de
    // status ocupando espaço. O widget passa a ser acessível pela tela
    // inicial do Android e o CTA de compromisso continua fixo abaixo.
    if (_isSupported != true || _isAdded) return const SizedBox.shrink();
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primary = _streakPrimaryColor(isDarkMode);

    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 16),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              primary.withValues(alpha: isDarkMode ? 0.24 : 0.14),
              const Color(0xFF6251D7).withValues(alpha: isDarkMode ? 0.2 : 0.1),
            ],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: primary.withValues(alpha: 0.36)),
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(
                Icons.widgets_rounded,
                color: primary,
                size: 30,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr.translate('streak_widget_card_title'),
                    style: TextStyle(
                      color:
                          isDarkMode ? Colors.white : AppTheme.textPrimaryColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    context.tr.translate('streak_widget_card_body'),
                    style: TextStyle(
                      color: _streakMutedTextColor(isDarkMode),
                      fontSize: 12,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 10),
                  FilledButton.icon(
                    onPressed: _openWidgetSetup,
                    icon: const Icon(
                      Icons.add_to_home_screen_rounded,
                      size: 18,
                    ),
                    label: Text(
                      context.tr.translate('streak_intro_widget_cta'),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: primary,
                      foregroundColor:
                          isDarkMode ? const Color(0xFF10201F) : Colors.white,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StreakDetailsExpansion extends StatelessWidget {
  final int proteinStreak;
  final int calorieStreak;
  final _StreakCalendarMode selectedMode;
  final ValueChanged<_StreakCalendarMode> onModeSelected;
  final Widget calendar;

  const _StreakDetailsExpansion({
    required this.proteinStreak,
    required this.calorieStreak,
    required this.selectedMode,
    required this.onModeSelected,
    required this.calendar,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Material(
      type: MaterialType.transparency,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 2),
          childrenPadding: EdgeInsets.zero,
          backgroundColor: Colors.transparent,
          collapsedBackgroundColor: Colors.transparent,
          shape: const Border(),
          collapsedShape: const Border(),
          iconColor: _streakPrimaryColor(isDarkMode),
          collapsedIconColor: _streakMutedTextColor(isDarkMode),
          title: Text(
            context.tr.translate('streak_details_title'),
            style: TextStyle(
              color: isDarkMode ? Colors.white : AppTheme.textPrimaryColor,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          children: [
            _StreakStatsGrid(
              proteinStreak: proteinStreak,
              calorieStreak: calorieStreak,
              selectedMode: selectedMode,
              onModeSelected: onModeSelected,
            ),
            const SizedBox(height: 12),
            calendar,
          ],
        ),
      ),
    );
  }
}

class _StreakStatsGrid extends StatelessWidget {
  final int proteinStreak;
  final int calorieStreak;
  final _StreakCalendarMode selectedMode;
  final ValueChanged<_StreakCalendarMode> onModeSelected;

  const _StreakStatsGrid({
    required this.proteinStreak,
    required this.calorieStreak,
    required this.selectedMode,
    required this.onModeSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _MiniStatCard(
            icon: MacroTheme.proteinIcon,
            color: MacroTheme.proteinColor,
            value: '$proteinStreak',
            label: context.tr.translate('streak_secondary_protein'),
            selected: selectedMode == _StreakCalendarMode.protein,
            onTap: () => onModeSelected(_StreakCalendarMode.protein),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MiniStatCard(
            icon: MacroTheme.caloriesIcon,
            color: MacroTheme.caloriesColor,
            value: '$calorieStreak',
            label: context.tr.translate('streak_secondary_goal'),
            selected: selectedMode == _StreakCalendarMode.calories,
            onTap: () => onModeSelected(_StreakCalendarMode.calories),
          ),
        ),
      ],
    );
  }
}

class _MiniStatCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String value;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _MiniStatCard({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = selected
        ? color.withValues(alpha: isDarkMode ? 0.18 : 0.11)
        : AppTheme.profileCardColor(isDarkMode);
    final borderColor = selected
        ? color.withValues(alpha: isDarkMode ? 0.62 : 0.48)
        : _streakBorderColor(isDarkMode);

    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            constraints: const BoxConstraints(minHeight: 112),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: borderColor,
                width: selected ? 1.3 : 1,
              ),
              boxShadow: AppTheme.profileCardShadow(isDarkMode),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MacroTheme.iconBadge(
                  icon: icon,
                  color: color,
                  isDarkMode: isDarkMode,
                  size: 28,
                  iconSize: 16,
                ),
                const SizedBox(height: 18),
                Text(
                  value,
                  style: TextStyle(
                    color:
                        isDarkMode ? Colors.white : AppTheme.textPrimaryColor,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected
                        ? (isDarkMode
                            ? Colors.white
                            : AppTheme.textPrimaryColor)
                        : _streakMutedTextColor(isDarkMode),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    height: 1.2,
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

class _StreakCalendarCard extends StatelessWidget {
  final DateTime visibleMonth;
  final DailyMealsProvider mealsProvider;
  final NutritionGoalsProvider goalsProvider;
  final _StreakCalendarMode mode;
  final DateTime? registrationLastDate;
  final DateTime? proteinLastDate;
  final DateTime? calorieLastDate;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;

  const _StreakCalendarCard({
    required this.visibleMonth,
    required this.mealsProvider,
    required this.goalsProvider,
    required this.mode,
    required this.registrationLastDate,
    required this.proteinLastDate,
    required this.calorieLastDate,
    required this.onPreviousMonth,
    required this.onNextMonth,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final now = DateTime.now();
    final currentMonth = DateTime(now.year, now.month);
    final canGoNext = visibleMonth.isBefore(currentMonth);
    final monthLabel =
        MaterialLocalizations.of(context).formatMonthYear(visibleMonth);
    final markColor = _calendarMarkColor(mode);
    final modeLabel = _calendarModeLabel(context, mode);

    return _SocialStyleCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  context.tr.translate('streak_calendar_title'),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color:
                        isDarkMode ? Colors.white : AppTheme.textPrimaryColor,
                  ),
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: markColor.withValues(alpha: isDarkMode ? 0.18 : 0.1),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: markColor.withValues(alpha: 0.42)),
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 132),
                  child: Text(
                    modeLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color:
                          isDarkMode ? Colors.white : AppTheme.textPrimaryColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      height: 1,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            decoration: BoxDecoration(
              color: _streakInputFillColor(isDarkMode),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _streakBorderColor(isDarkMode)),
            ),
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 14),
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: onPreviousMonth,
                      tooltip: context.tr.translate('streak_previous_month'),
                      icon: const Icon(Icons.chevron_left_rounded, size: 28),
                    ),
                    Expanded(
                      child: Text(
                        monthLabel,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: isDarkMode
                              ? Colors.white
                              : AppTheme.textPrimaryColor,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: canGoNext ? onNextMonth : null,
                      tooltip: context.tr.translate('streak_next_month'),
                      icon: const Icon(Icons.chevron_right_rounded, size: 28),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                _WeekdayHeader(isDarkMode: isDarkMode),
                const SizedBox(height: 4),
                _CalendarGrid(
                  visibleMonth: visibleMonth,
                  mealsProvider: mealsProvider,
                  goalsProvider: goalsProvider,
                  mode: mode,
                  registrationLastDate: registrationLastDate,
                  proteinLastDate: proteinLastDate,
                  calorieLastDate: calorieLastDate,
                ),
                const SizedBox(height: 12),
                _CalendarLegend(
                  isDarkMode: isDarkMode,
                  mode: mode,
                  markColor: markColor,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WeekdayHeader extends StatelessWidget {
  final bool isDarkMode;

  const _WeekdayHeader({required this.isDarkMode});

  @override
  Widget build(BuildContext context) {
    final labels = [
      context.tr.translate('day_sun_short'),
      context.tr.translate('day_mon_short'),
      context.tr.translate('day_tue_short'),
      context.tr.translate('day_wed_short'),
      context.tr.translate('day_thu_short'),
      context.tr.translate('day_fri_short'),
      context.tr.translate('day_sat_short'),
    ];

    return Row(
      children: labels
          .map(
            (label) => Expanded(
              child: Center(
                child: Text(
                  label,
                  style: TextStyle(
                    color: _streakMutedTextColor(isDarkMode),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _CalendarGrid extends StatelessWidget {
  final DateTime visibleMonth;
  final DailyMealsProvider mealsProvider;
  final NutritionGoalsProvider goalsProvider;
  final _StreakCalendarMode mode;
  final DateTime? registrationLastDate;
  final DateTime? proteinLastDate;
  final DateTime? calorieLastDate;

  const _CalendarGrid({
    required this.visibleMonth,
    required this.mealsProvider,
    required this.goalsProvider,
    required this.mode,
    required this.registrationLastDate,
    required this.proteinLastDate,
    required this.calorieLastDate,
  });

  @override
  Widget build(BuildContext context) {
    final firstDay = DateTime(visibleMonth.year, visibleMonth.month);
    final daysInMonth =
        DateUtils.getDaysInMonth(visibleMonth.year, visibleMonth.month);
    final leadingEmptyCells = firstDay.weekday % 7;
    final totalCells = leadingEmptyCells + daysInMonth;
    final rowCount = (totalCells / 7).ceil();

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: rowCount * 7,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        childAspectRatio: 1,
      ),
      itemBuilder: (context, index) {
        final dayNumber = index - leadingEmptyCells + 1;
        if (dayNumber < 1 || dayNumber > daysInMonth) {
          return const SizedBox.shrink();
        }

        final date = DateTime(visibleMonth.year, visibleMonth.month, dayNumber);
        final isLastRegistration = _isSameDate(date, registrationLastDate);
        final isLastProtein = _isSameDate(date, proteinLastDate);
        final isLastCalorie = _isSameDate(date, calorieLastDate);
        final knowsNutritionData = mealsProvider.hasNutritionDataOn(date);
        final isMarked = switch (mode) {
          _StreakCalendarMode.registration =>
            mealsProvider.hasMealsOn(date) || isLastRegistration,
          _StreakCalendarMode.protein => mealsProvider.hasHitProteinGoalOn(
                date,
                proteinTarget: goalsProvider.proteinGoal,
              ) ||
              (isLastProtein && !knowsNutritionData),
          _StreakCalendarMode.calories => mealsProvider.hasHitCalorieGoalOn(
                date,
                calorieGoal: goalsProvider.caloriesGoal,
                allowBelowGoal:
                    _calorieModeAllowsBelowGoal(goalsProvider.fitnessGoal),
                allowAboveGoal:
                    _calorieModeAllowsAboveGoal(goalsProvider.fitnessGoal),
              ) ||
              (isLastCalorie && !knowsNutritionData),
        };
        final isToday = _isSameDate(date, DateTime.now());
        final isFuture = date.isAfter(DateTime.now());

        return _CalendarDayCell(
          day: dayNumber,
          isToday: isToday,
          isMarked: isMarked,
          isFuture: isFuture,
          markColor: _calendarMarkColor(mode),
        );
      },
    );
  }
}

class _CalendarDayCell extends StatelessWidget {
  final int day;
  final bool isToday;
  final bool isMarked;
  final bool isFuture;
  final Color markColor;

  const _CalendarDayCell({
    required this.day,
    required this.isToday,
    required this.isMarked,
    required this.isFuture,
    required this.markColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primary = _streakPrimaryColor(isDarkMode);
    final textColor = isFuture
        ? _streakMutedTextColor(isDarkMode).withValues(alpha: 0.38)
        : isToday
            ? AppTheme.onColor(primary)
            : isDarkMode
                ? Colors.white
                : AppTheme.textPrimaryColor;

    return Center(
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: isToday
              ? primary
              : isMarked
                  ? markColor.withValues(alpha: 0.14)
                  : Colors.transparent,
          shape: BoxShape.circle,
          border: isMarked && !isToday
              ? Border.all(color: markColor.withValues(alpha: 0.5))
              : null,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Text(
              '$day',
              style: TextStyle(
                color: textColor,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (isMarked)
              Positioned(
                bottom: 5,
                child: Container(
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isToday ? AppTheme.onColor(primary) : markColor,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CalendarLegend extends StatelessWidget {
  final bool isDarkMode;
  final _StreakCalendarMode mode;
  final Color markColor;

  const _CalendarLegend({
    required this.isDarkMode,
    required this.mode,
    required this.markColor,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: [
        _LegendItem(
          color: markColor,
          label: _calendarModeLabel(context, mode),
          isDarkMode: isDarkMode,
        ),
        _LegendItem(
          color: _streakPrimaryColor(isDarkMode),
          label: context.tr.translate('streak_today'),
          isDarkMode: isDarkMode,
        ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final bool isDarkMode;

  const _LegendItem({
    required this.color,
    required this.label,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            color: _streakMutedTextColor(isDarkMode),
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _FriendsStreakTab extends StatelessWidget {
  final VoidCallback onInviteFriends;

  const _FriendsStreakTab({
    super.key,
    required this.onInviteFriends,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<FriendsProvider>(
      builder: (context, friendsProvider, _) {
        final hasDuoStreaks = friendsProvider.duoStreaks.isNotEmpty;
        final showLoading = friendsProvider.isLoading &&
            !hasDuoStreaks &&
            friendsProvider.friendCount == 0;

        if (showLoading) {
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: const [
              SizedBox(
                height: 320,
                child: Center(child: CircularProgressIndicator()),
              ),
            ],
          );
        }

        if (!hasDuoStreaks) {
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            children: [
              SizedBox(
                height: MediaQuery.of(context).size.height - 190,
                child: DietStyleMessageState(
                  title: context.tr.translate('streak_friend_empty_title'),
                  message: context.tr.translate('streak_friend_empty_message'),
                  fallbackIcon: Icons.people_alt_rounded,
                  primaryActionLabel:
                      context.tr.translate('streak_invite_friends'),
                  primaryActionIcon: Icons.person_add_rounded,
                  onPrimaryAction: onInviteFriends,
                  topSpacing: 20,
                  illustrationSize: 168,
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                ),
              ),
            ],
          );
        }

        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 124),
          children: [
            _FriendsOverviewCard(
              friendCount: friendsProvider.friendCount,
              duoCount: friendsProvider.duoStreakCount,
              onInviteFriends: onInviteFriends,
            ),
            const SizedBox(height: 12),
            _SectionTitle(title: context.tr.translate('streak_duo_title')),
            const SizedBox(height: 8),
            ...friendsProvider.duoStreaks.map(
              (duo) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _DuoStreakTile(
                  duoStreak: duo,
                  onCheckIn: () async {
                    final success =
                        await friendsProvider.duoCheckIn(duo.friendshipId);
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          success
                              ? context.tr
                                  .translate('streak_friend_checkin_success')
                              : context.tr
                                  .translate('streak_friend_checkin_error'),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _FriendsOverviewCard extends StatelessWidget {
  final int friendCount;
  final int duoCount;
  final VoidCallback onInviteFriends;

  const _FriendsOverviewCard({
    required this.friendCount,
    required this.duoCount,
    required this.onInviteFriends,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primary = _streakPrimaryColor(isDarkMode);
    final foreground = AppTheme.onColor(primary);

    return _SocialStyleCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(Icons.group_rounded, color: primary, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr.translate('streak_friend_progress_title'),
                      style: TextStyle(
                        color: isDarkMode
                            ? Colors.white
                            : AppTheme.textPrimaryColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      context.tr
                          .translate('streak_friend_progress_message')
                          .replaceAll('{friends}', friendCount.toString())
                          .replaceAll('{duos}', duoCount.toString()),
                      style: TextStyle(
                        color: _streakMutedTextColor(isDarkMode),
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onInviteFriends,
              icon: Icon(Icons.person_add_rounded, color: foreground, size: 18),
              label: Text(
                context.tr.translate('streak_invite_friends'),
                style: TextStyle(
                  color: foreground,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: foreground,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DuoStreakTile extends StatelessWidget {
  final DuoStreak duoStreak;
  final VoidCallback onCheckIn;

  const _DuoStreakTile({
    required this.duoStreak,
    required this.onCheckIn,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final currentStreak = duoStreak.friendStreak?.currentStreak ?? 0;
    final bestStreak = duoStreak.friendStreak?.bestStreak ?? 0;
    final primary = _streakPrimaryColor(isDarkMode);
    const streakColor = MacroTheme.caloriesColor;

    return _SocialStyleCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: streakColor.withValues(alpha: 0.14),
            child: Text(
              duoStreak.friend.name.isNotEmpty
                  ? duoStreak.friend.name[0].toUpperCase()
                  : '?',
              style: const TextStyle(
                color: streakColor,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  duoStreak.friend.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color:
                        isDarkMode ? Colors.white : AppTheme.textPrimaryColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 7),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _SmallPill(
                      icon: Icons.local_fire_department_rounded,
                      label: '$currentStreak ${context.tr.translate(
                        currentStreak == 1
                            ? 'challenge_days_completed_one'
                            : 'challenge_days_completed_other',
                      )}',
                      color: streakColor,
                    ),
                    _SmallPill(
                      icon: Icons.emoji_events_rounded,
                      label: context.tr
                          .translate('streak_friend_best')
                          .replaceAll('{count}', bestStreak.toString()),
                      color: primary,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _CheckInDot(
                    label: context.tr.translate('streak_you'),
                    checked: duoStreak.myCheckIn,
                  ),
                  const SizedBox(width: 8),
                  _CheckInDot(
                    label: _firstName(duoStreak.friend.name),
                    checked: duoStreak.friendCheckIn,
                  ),
                ],
              ),
              if (!duoStreak.myCheckIn) ...[
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: onCheckIn,
                  style: FilledButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: AppTheme.onColor(primary),
                    minimumSize: const Size(0, 32),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    context.tr.translate('streak_duo_checkin'),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _CheckInDot extends StatelessWidget {
  final String label;
  final bool checked;

  const _CheckInDot({
    required this.label,
    required this.checked,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final color = checked
        ? _streakPrimaryColor(isDarkMode)
        : _streakMutedTextColor(isDarkMode);

    return Column(
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: checked ? color.withValues(alpha: 0.15) : Colors.transparent,
            shape: BoxShape.circle,
            border: Border.all(
              color: color.withValues(alpha: checked ? 0.6 : 0.35),
              width: 1.5,
            ),
          ),
          child: checked
              ? Icon(Icons.check_rounded, color: color, size: 14)
              : null,
        ),
        const SizedBox(height: 3),
        Text(
          label.length > 6 ? '${label.substring(0, 6)}.' : label,
          style: TextStyle(
            color: color,
            fontSize: 9,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _SmallPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _SmallPill({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Text(
      title,
      style: TextStyle(
        color: isDarkMode ? Colors.white : AppTheme.textPrimaryColor,
        fontSize: 18,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _SocialStyleCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _SocialStyleCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: padding,
      decoration: AppTheme.profileCardDecoration(isDarkMode),
      child: child,
    );
  }
}

bool _isSameDate(DateTime? a, DateTime? b) {
  if (a == null || b == null) return false;
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

String _firstName(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return '?';
  return trimmed.split(RegExp(r'\s+')).first;
}
