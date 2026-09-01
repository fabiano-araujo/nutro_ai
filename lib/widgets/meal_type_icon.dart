import 'package:flutter/material.dart';

import '../models/meal_model.dart';

/// Pale mint squircle + dark teal line icon used on meal rows.
const Color kMealTypeIconBackground = Color(0xFFE4F3EE);
const Color kMealTypeIconForeground = Color(0xFF234F4A);

String mealTypeIdFromMealType(MealType type) {
  switch (type) {
    case MealType.breakfast:
      return 'breakfast';
    case MealType.lunch:
      return 'lunch';
    case MealType.dinner:
      return 'dinner';
    case MealType.snack:
      return 'snack';
    case MealType.freeMeal:
      return 'free_meal';
  }
}

IconData mealTypeIconData(String mealTypeId) {
  switch (mealTypeId.trim().toLowerCase()) {
    case 'breakfast':
      return Icons.coffee_outlined;
    case 'morning_snack':
      return Icons.bakery_dining_outlined;
    case 'lunch':
      return Icons.restaurant_outlined;
    case 'afternoon_snack':
    case 'snack':
      return Icons.cookie_outlined;
    case 'dinner':
      return Icons.dinner_dining_outlined;
    case 'supper':
      return Icons.nightlife_outlined;
    case 'freemeal':
    case 'free_meal':
      return Icons.restaurant_menu_outlined;
    default:
      return Icons.restaurant_menu_outlined;
  }
}

class MealTypeIcon extends StatelessWidget {
  final String mealTypeId;
  final double size;
  final double? iconSize;

  const MealTypeIcon({
    super.key,
    required this.mealTypeId,
    this.size = 48,
    this.iconSize,
  });

  factory MealTypeIcon.fromMealType(
    MealType type, {
    Key? key,
    double size = 48,
    double? iconSize,
  }) {
    return MealTypeIcon(
      key: key,
      mealTypeId: mealTypeIdFromMealType(type),
      size: size,
      iconSize: iconSize,
    );
  }

  @override
  Widget build(BuildContext context) {
    final resolvedIconSize = iconSize ?? (size * 0.48).clamp(14.0, 36.0);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: kMealTypeIconBackground,
        borderRadius: BorderRadius.circular(size * 0.33),
      ),
      child: Icon(
        mealTypeIconData(mealTypeId),
        size: resolvedIconSize,
        color: kMealTypeIconForeground,
      ),
    );
  }
}
