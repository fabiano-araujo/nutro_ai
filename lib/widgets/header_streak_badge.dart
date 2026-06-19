import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/daily_meals_provider.dart';
import '../providers/streak_provider.dart';
import '../screens/streak_screen.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../theme/macro_theme.dart';
import '../utils/streak_helper.dart';
import '../i18n/app_localizations_extension.dart';

class HeaderStreakBadge extends StatelessWidget {
  final EdgeInsetsGeometry margin;

  const HeaderStreakBadge({
    Key? key,
    this.margin = EdgeInsets.zero,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isAuthenticated = context.select<AuthService, bool>(
      (authService) => authService.isAuthenticated,
    );

    if (!isAuthenticated) {
      return const SizedBox.shrink();
    }

    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final streak = effectiveRegistrationStreak(
      context.watch<StreakProvider>(),
      context.watch<DailyMealsProvider>(),
    );
    final textColor = isDarkMode ? Colors.white : AppTheme.textPrimaryColor;
    final splashColor = MacroTheme.caloriesColor.withValues(alpha: 0.14);

    return Tooltip(
      message: context.tr.translate('streak_hero_title'),
      child: Padding(
        padding: margin,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const StreakScreen(),
              ),
            ),
            borderRadius: BorderRadius.circular(20),
            splashColor: splashColor,
            highlightColor: splashColor.withValues(alpha: 0.55),
            child: SizedBox(
              height: 40,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.local_fire_department_rounded,
                      size: 21,
                      color: MacroTheme.caloriesColor,
                    ),
                    const SizedBox(width: 3),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      transitionBuilder: (child, animation) {
                        return FadeTransition(
                          opacity: animation,
                          child: ScaleTransition(
                            scale: Tween<double>(
                              begin: 0.92,
                              end: 1,
                            ).animate(animation),
                            child: child,
                          ),
                        );
                      },
                      child: Text(
                        '$streak',
                        key: ValueKey<int>(streak),
                        style: TextStyle(
                          fontSize: 15,
                          height: 1,
                          fontWeight: FontWeight.w800,
                          color: textColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
