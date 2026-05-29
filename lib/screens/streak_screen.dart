import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../i18n/app_localizations_extension.dart';
import '../providers/daily_meals_provider.dart';
import '../providers/friends_provider.dart';
import '../providers/streak_provider.dart';
import '../services/social_service.dart';
import '../theme/app_theme.dart';
import '../utils/streak_helper.dart';
import '../widgets/diet_style_message_state.dart';
import 'friends_screen.dart';

Color _streakSurfaceColor(bool isDarkMode) =>
    isDarkMode ? const Color(0xFF2A2A2A) : Colors.white;

Color _streakInputFillColor(bool isDarkMode) =>
    isDarkMode ? const Color(0xFF1F1F1F) : AppTheme.backgroundColor;

Color _streakBorderColor(bool isDarkMode) =>
    isDarkMode ? Colors.white12 : Colors.black12;

Color _streakMutedTextColor(bool isDarkMode) =>
    isDarkMode ? const Color(0xFFAEB7CE) : AppTheme.textSecondaryColor;

Color _streakPrimaryColor(bool isDarkMode) =>
    isDarkMode ? AppTheme.primaryColorDarkMode : AppTheme.primaryColor;

class StreakScreen extends StatefulWidget {
  const StreakScreen({super.key});

  @override
  State<StreakScreen> createState() => _StreakScreenState();
}

class _StreakScreenState extends State<StreakScreen> {
  int _selectedTab = 0;
  late DateTime _visibleMonth;

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

  Future<void> _shareStreak() async {
    final count = effectiveRegistrationStreak(
      context.read<StreakProvider>(),
      context.read<DailyMealsProvider>(),
    );
    final message = context.tr
        .translate('streak_share_message')
        .replaceAll('{count}', count.toString());
    await Share.share(message);
  }

  void _openFriends() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const FriendsScreen(isEmbedded: false),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDarkMode ? AppTheme.darkBackgroundColor : AppTheme.backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _StreakHeader(onShare: _shareStreak),
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
                        onPreviousMonth: _previousMonth,
                        onNextMonth: _nextMonth,
                      )
                    : _FriendsStreakTab(
                        key: const ValueKey('friends-streak-tab'),
                        onInviteFriends: _openFriends,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StreakHeader extends StatelessWidget {
  final VoidCallback onShare;

  const _StreakHeader({required this.onShare});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDarkMode ? Colors.white : AppTheme.textPrimaryColor;

    return SizedBox(
      height: 56,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          children: [
            SizedBox(
              width: 56,
              child: IconButton(
                icon: Icon(Icons.close_rounded, color: textColor, size: 28),
                tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ),
            Expanded(
              child: Text(
                context.tr.translate('streak_screen_title'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: textColor,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  height: 1.05,
                ),
              ),
            ),
            SizedBox(
              width: 56,
              child: IconButton(
                icon: Icon(Icons.ios_share_rounded, color: textColor, size: 24),
                tooltip: context.tr.translate('streak_share_tooltip'),
                onPressed: onShare,
              ),
            ),
          ],
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

    return Container(
      color:
          isDarkMode ? AppTheme.darkBackgroundColor : AppTheme.backgroundColor,
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 14),
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
    final selectedBackground =
        isDarkMode ? Colors.white : AppTheme.primaryColor;
    final selectedForeground =
        isDarkMode ? Colors.black : AppTheme.onColor(selectedBackground);
    final unselectedBackground =
        isDarkMode ? AppTheme.darkCardColor : Colors.white;
    final unselectedBorderColor =
        isDarkMode ? AppTheme.darkBorderColor : AppTheme.dividerColor;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 124,
        height: 42,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? selectedBackground : unselectedBackground,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? selectedBackground : unselectedBorderColor,
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: selected
                ? selectedForeground
                : _streakMutedTextColor(isDarkMode),
          ),
        ),
      ),
    );
  }
}

class _PersonalStreakTab extends StatelessWidget {
  final DateTime visibleMonth;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;

  const _PersonalStreakTab({
    super.key,
    required this.visibleMonth,
    required this.onPreviousMonth,
    required this.onNextMonth,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer2<StreakProvider, DailyMealsProvider>(
      builder: (context, streakProvider, mealsProvider, _) {
        final isLoading = streakProvider.isLoading && !streakProvider.hasStreak;
        final effectiveStreak =
            effectiveRegistrationStreak(streakProvider, mealsProvider);

        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 2, 16, 32),
          children: [
            if (isLoading)
              const SizedBox(
                height: 320,
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              _PersonalHeroCard(
                streakProvider: streakProvider,
                registrationStreak: effectiveStreak,
              ),
              const SizedBox(height: 12),
              _FreezeStatusCard(streakProvider: streakProvider),
              const SizedBox(height: 12),
              _StreakStatsGrid(streakProvider: streakProvider),
              const SizedBox(height: 12),
              _StreakCalendarCard(
                visibleMonth: visibleMonth,
                mealsProvider: mealsProvider,
                registrationLastDate:
                    streakProvider.streak?.registrationLastDate,
                onPreviousMonth: onPreviousMonth,
                onNextMonth: onNextMonth,
              ),
            ],
          ],
        );
      },
    );
  }
}

class _PersonalHeroCard extends StatelessWidget {
  final StreakProvider streakProvider;
  final int registrationStreak;

  const _PersonalHeroCard({
    required this.streakProvider,
    required this.registrationStreak,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final mainStreak = registrationStreak;
    final bestStreak = math.max(streakProvider.bestOverallStreak, mainStreak);
    final dayLabel = mainStreak == 1
        ? context.tr.translate('streak_hero_day_singular')
        : context.tr.translate('streak_hero_day_plural');

    return _SocialStyleCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr.translate('streak_hero_title'),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _streakMutedTextColor(isDarkMode),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '$mainStreak',
                      style: TextStyle(
                        fontSize: 56,
                        fontWeight: FontWeight.w800,
                        height: 0.95,
                        color: isDarkMode
                            ? Colors.white
                            : AppTheme.textPrimaryColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        dayLabel,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: _streakMutedTextColor(isDarkMode),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  mainStreak == 0
                      ? context.tr.translate('streak_hero_start_hint')
                      : context.tr
                          .translate('streak_hero_record')
                          .replaceAll('{count}', bestStreak.toString()),
                  style: TextStyle(
                    fontSize: 13,
                    color: _streakMutedTextColor(isDarkMode),
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: const Color(0xFFFF6B35).withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.local_fire_department_rounded,
              color: mainStreak > 0
                  ? const Color(0xFFFF6B35)
                  : _streakMutedTextColor(isDarkMode).withValues(alpha: 0.5),
              size: 62,
            ),
          ),
        ],
      ),
    );
  }
}

class _FreezeStatusCard extends StatelessWidget {
  final StreakProvider streakProvider;

  const _FreezeStatusCard({required this.streakProvider});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primary = _streakPrimaryColor(isDarkMode);
    final freezes = streakProvider.freezesAvailable;
    final hasFreeze = freezes > 0;
    final title = hasFreeze
        ? context.tr
            .translate('streak_freeze_available_title')
            .replaceAll('{count}', freezes.toString())
        : context.tr.translate('streak_freeze_none_title');
    final message = hasFreeze
        ? context.tr.translate('streak_freeze_available_message')
        : context.tr.translate('streak_freeze_none_message');

    return _SocialStyleCard(
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.lightBlueAccent.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(
              Icons.shield_rounded,
              color: Colors.lightBlueAccent.shade700,
              size: 30,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color:
                        isDarkMode ? Colors.white : AppTheme.textPrimaryColor,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: TextStyle(
                    fontSize: 12,
                    color: _streakMutedTextColor(isDarkMode),
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () => _showFreezeInfo(context),
                    style: TextButton.styleFrom(
                      foregroundColor: primary,
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 32),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      context.tr.translate('streak_get_more_freezes'),
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showFreezeInfo(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.tr.translate('streak_freeze_info_title')),
        content: Text(context.tr.translate('streak_freeze_info_message')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(context.tr.translate('ok')),
          ),
        ],
      ),
    );
  }
}

class _StreakStatsGrid extends StatelessWidget {
  final StreakProvider streakProvider;

  const _StreakStatsGrid({required this.streakProvider});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _MiniStatCard(
            icon: Icons.fitness_center_rounded,
            color: const Color(0xFF35A853),
            value: '${streakProvider.proteinStreak}',
            label: context.tr.translate('streak_secondary_protein'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MiniStatCard(
            icon: Icons.flag_rounded,
            color: const Color(0xFF4E8CFF),
            value: '${streakProvider.goalStreak}',
            label: context.tr.translate('streak_secondary_goal'),
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

  const _MiniStatCard({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      constraints: const BoxConstraints(minHeight: 112),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _streakSurfaceColor(isDarkMode),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _streakBorderColor(isDarkMode)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 18),
          Text(
            value,
            style: TextStyle(
              color: isDarkMode ? Colors.white : AppTheme.textPrimaryColor,
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
              color: _streakMutedTextColor(isDarkMode),
              fontSize: 11,
              fontWeight: FontWeight.w600,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _StreakCalendarCard extends StatelessWidget {
  final DateTime visibleMonth;
  final DailyMealsProvider mealsProvider;
  final DateTime? registrationLastDate;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;

  const _StreakCalendarCard({
    required this.visibleMonth,
    required this.mealsProvider,
    required this.registrationLastDate,
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

    return _SocialStyleCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr.translate('streak_calendar_title'),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: isDarkMode ? Colors.white : AppTheme.textPrimaryColor,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            decoration: BoxDecoration(
              color: _streakInputFillColor(isDarkMode),
              borderRadius: BorderRadius.circular(18),
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
                  registrationLastDate: registrationLastDate,
                ),
                const SizedBox(height: 12),
                _CalendarLegend(isDarkMode: isDarkMode),
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
  final DateTime? registrationLastDate;

  const _CalendarGrid({
    required this.visibleMonth,
    required this.mealsProvider,
    required this.registrationLastDate,
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
        final hasMeal = mealsProvider.hasMealsOn(date);
        final isLastRegistration = _isSameDate(date, registrationLastDate);
        final isMarked = hasMeal || isLastRegistration;
        final isToday = _isSameDate(date, DateTime.now());
        final isFuture = date.isAfter(DateTime.now());

        return _CalendarDayCell(
          day: dayNumber,
          isToday: isToday,
          isMarked: isMarked,
          isFuture: isFuture,
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

  const _CalendarDayCell({
    required this.day,
    required this.isToday,
    required this.isMarked,
    required this.isFuture,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primary = _streakPrimaryColor(isDarkMode);
    final markColor = const Color(0xFFFF6B35);
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

  const _CalendarLegend({required this.isDarkMode});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: [
        _LegendItem(
          color: const Color(0xFFFF6B35),
          label: context.tr.translate('streak_calendar_logged_day'),
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
          padding: const EdgeInsets.fromLTRB(16, 2, 16, 32),
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
    const streakColor = Color(0xFFFF6B35);

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
                      label:
                          '$currentStreak ${context.tr.translate('challenge_days_completed')}',
                      color: streakColor,
                    ),
                    _SmallPill(
                      icon: Icons.emoji_events_rounded,
                      label: context.tr
                          .translate('streak_friend_best')
                          .replaceAll('{count}', bestStreak.toString()),
                      color: const Color(0xFFF4B400),
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
                    backgroundColor: streakColor,
                    foregroundColor: Colors.white,
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
    final color = checked ? const Color(0xFF4CAF50) : Colors.grey;

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
              ? const Icon(Icons.check_rounded,
                  color: Color(0xFF4CAF50), size: 14)
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
      decoration: BoxDecoration(
        color: _streakSurfaceColor(isDarkMode),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _streakBorderColor(isDarkMode)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDarkMode ? 0.18 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
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
