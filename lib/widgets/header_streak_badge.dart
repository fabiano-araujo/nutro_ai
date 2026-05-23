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
    final surfaceColor = isDarkMode ? const Color(0xFF1F1F1F) : Colors.white;
    final borderColor = isDarkMode ? Colors.white12 : Colors.black12;

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
            borderRadius: BorderRadius.circular(18),
            child: Container(
              height: 34,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: borderColor),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.local_fire_department_rounded,
                    size: 18,
                    color: MacroTheme.caloriesColor,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$streak',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: textColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
