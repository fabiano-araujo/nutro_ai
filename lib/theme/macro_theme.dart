import 'package:flutter/material.dart';

import 'app_theme.dart';

/// Centralized macro nutrition visual constants — used throughout the app.
/// Icons and colors match the meal_page.dart reference design.
class MacroTheme {
  MacroTheme._();

  // ── Colors ────────────────────────────────────────────────────────────────
  static const Color caloriesColor = AppTheme.primaryColor;
  static const Color proteinColor = Color(0xFF7D6BFF);
  static const Color carbsColor = Color(0xFFFFB248);
  static const Color fatColor = Color(0xFFD94F8A);

  // ── Icons ─────────────────────────────────────────────────────────────────
  static const IconData caloriesIcon = Icons.local_fire_department_rounded;
  static const IconData proteinIcon = Icons.fitness_center_rounded;
  static const IconData carbsIcon = Icons.grain_rounded;
  static const IconData fatIcon = Icons.opacity_rounded;

  // ── Helpers ───────────────────────────────────────────────────────────────
  static Color colorFor(MacroType type) {
    switch (type) {
      case MacroType.calories:
        return caloriesColor;
      case MacroType.protein:
        return proteinColor;
      case MacroType.carbs:
        return carbsColor;
      case MacroType.fat:
        return fatColor;
    }
  }

  static IconData iconFor(MacroType type) {
    switch (type) {
      case MacroType.calories:
        return caloriesIcon;
      case MacroType.protein:
        return proteinIcon;
      case MacroType.carbs:
        return carbsIcon;
      case MacroType.fat:
        return fatIcon;
    }
  }

  static Widget iconBadge({
    required IconData icon,
    required Color color,
    required bool isDarkMode,
    double size = 24,
    double? iconSize,
  }) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDarkMode ? 0.18 : 0.12),
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon,
        color: color,
        size: iconSize ?? size * 0.56,
      ),
    );
  }
}

enum MacroType { calories, protein, carbs, fat }
