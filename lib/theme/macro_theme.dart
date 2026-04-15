import 'package:flutter/material.dart';

/// Centralized macro nutrition visual constants — used throughout the app.
/// Icons and colors match the meal_page.dart reference design.
class MacroTheme {
  MacroTheme._();

  // ── Colors ────────────────────────────────────────────────────────────────
  static const Color caloriesColor = Color(0xFFFF7D61);
  static const Color proteinColor  = Color(0xFF7D6BFF);
  static const Color carbsColor    = Color(0xFFFFB248);
  static const Color fatColor      = Color(0xFF37B39B);

  // ── Icons ─────────────────────────────────────────────────────────────────
  static const IconData caloriesIcon = Icons.local_fire_department_rounded;
  static const IconData proteinIcon  = Icons.fitness_center_rounded;
  static const IconData carbsIcon    = Icons.grain_rounded;
  static const IconData fatIcon      = Icons.opacity_rounded;

  // ── Helpers ───────────────────────────────────────────────────────────────
  static Color colorFor(MacroType type) {
    switch (type) {
      case MacroType.calories: return caloriesColor;
      case MacroType.protein:  return proteinColor;
      case MacroType.carbs:    return carbsColor;
      case MacroType.fat:      return fatColor;
    }
  }

  static IconData iconFor(MacroType type) {
    switch (type) {
      case MacroType.calories: return caloriesIcon;
      case MacroType.protein:  return proteinIcon;
      case MacroType.carbs:    return carbsIcon;
      case MacroType.fat:      return fatIcon;
    }
  }
}

enum MacroType { calories, protein, carbs, fat }
