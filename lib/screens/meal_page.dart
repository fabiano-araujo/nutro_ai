import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../i18n/app_localizations.dart';
import '../models/Nutrient.dart';
import '../models/diet_plan_model.dart';
import '../models/food_model.dart';
import '../models/meal_model.dart';
import '../services/ai_service.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../theme/macro_theme.dart';
import '../widgets/food_icon.dart';
import '../widgets/meal_type_icon.dart';
import 'food_page.dart';

class MealPage extends StatefulWidget {
  final _MealPageData meal;
  final bool showFiber;

  const MealPage._({
    super.key,
    required this.meal,
    required this.showFiber,
  });

  factory MealPage.fromMeal({
    Key? key,
    required Meal meal,
    bool showFiber = false,
  }) {
    return MealPage._(
      key: key,
      meal: _MealPageData.fromMeal(meal),
      showFiber: showFiber,
    );
  }

  factory MealPage.fromPlannedMeal({
    Key? key,
    required PlannedMeal meal,
    bool showFiber = false,
  }) {
    return MealPage._(
      key: key,
      meal: _MealPageData.fromPlannedMeal(meal),
      showFiber: showFiber,
    );
  }

  @override
  State<MealPage> createState() => _MealPageState();
}

class _MealPageState extends State<MealPage> {
  late final _MealNutritionAnalysis _analysis;
  bool _isLoadingTips = false;
  MealAnalysisResult? _tips;
  String? _tipsError;

  @override
  void initState() {
    super.initState();
    _analysis = _MealNutritionAnalysis.fromMeal(widget.meal);
  }

  Future<void> _fetchTips() async {
    if (_isLoadingTips) {
      return;
    }

    setState(() {
      _isLoadingTips = true;
      _tipsError = null;
    });

    try {
      final aiService = AIService();
      final locale = Localizations.localeOf(context);
      final languageCode =
          '${locale.languageCode}_${locale.countryCode ?? locale.languageCode.toUpperCase()}';
      var userId = '';
      try {
        final authService = Provider.of<AuthService>(context, listen: false);
        userId = authService.currentUser?.id.toString() ?? '';
      } catch (_) {}

      final meal = widget.meal;
      final result = await aiService.analyzeMeal(
        name: meal.resolveTitle(AppLocalizations.of(context)),
        languageCode: languageCode,
        userId: userId,
        time: meal.resolveSubtitle(locale),
        calories: meal.calories,
        protein: meal.protein,
        carbs: meal.carbs,
        fat: meal.fat,
        fiber: meal.fiber,
        includeFiber: widget.showFiber,
        foods: meal.foods
            .map(
              (food) => {
                'name': food.name,
                'portion': food.amountLabel,
                'calories': food.calories,
                'protein': food.protein,
                'carbs': food.carbs,
                'fat': food.fat,
                if (widget.showFiber) 'fiber': food.fiber,
              },
            )
            .toList(),
      );

      if (!mounted) {
        return;
      }
      setState(() {
        _tips = result;
      });
    } on AIServiceException catch (error) {
      if (!mounted) {
        return;
      }
      final l10n = AppLocalizations.of(context);
      setState(() {
        _tipsError = l10n.translate(
          error.code == 'insufficient_credits'
              ? 'chat_credit_exhausted_inline'
              : 'meal_tips_error',
        );
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _tipsError = AppLocalizations.of(context).translate('meal_tips_error');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingTips = false;
        });
      }
    }
  }

  _MealQuality get _displayedQuality {
    switch (_tips?.quality) {
      case 'great':
        return _MealQuality.great;
      case 'good':
        return _MealQuality.good;
      case 'needs_improvement':
        return _MealQuality.needsImprovement;
      default:
        return _analysis.quality;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor =
        isDarkMode ? AppTheme.darkBackgroundColor : AppTheme.backgroundColor;
    final textColor =
        isDarkMode ? AppTheme.darkTextColor : AppTheme.textPrimaryColor;
    final secondaryTextColor =
        isDarkMode ? const Color(0xFFAEB7CE) : AppTheme.textSecondaryColor;
    final meal = widget.meal;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness:
              isDarkMode ? Brightness.light : Brightness.dark,
          statusBarBrightness: isDarkMode ? Brightness.dark : Brightness.light,
        ),
        iconTheme: IconThemeData(color: textColor),
        title: Text(
          meal.resolveTitle(l10n),
          style: GoogleFonts.poppins(
            color: textColor,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildOverviewCard(
              isDarkMode: isDarkMode,
              textColor: textColor,
              secondaryTextColor: secondaryTextColor,
            ),
            const SizedBox(height: 12),
            _buildMacroCards(isDarkMode),
            const SizedBox(height: 20),
            _buildSectionTitle(l10n.translate('meal_foods_title'), textColor),
            const SizedBox(height: 12),
            _buildFoodsCard(
              isDarkMode: isDarkMode,
              textColor: textColor,
              secondaryTextColor: secondaryTextColor,
            ),
            const SizedBox(height: 20),
            _buildSectionTitle(l10n.translate('nutrition_tips'), textColor),
            const SizedBox(height: 12),
            _buildAiCard(
              isDarkMode: isDarkMode,
              textColor: textColor,
              secondaryTextColor: secondaryTextColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, Color textColor) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            color: isDarkMode
                ? AppTheme.primaryColorDarkMode
                : AppTheme.primaryColor,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: AppTheme.headingMedium.copyWith(
              color: textColor.withValues(alpha: 0.9),
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOverviewCard({
    required bool isDarkMode,
    required Color textColor,
    required Color secondaryTextColor,
  }) {
    final l10n = AppLocalizations.of(context);
    final meal = widget.meal;
    final foodCount = meal.foods.length;
    final foodCountLabel = l10n
        .translate(
          foodCount == 1 ? 'meal_item_count_one' : 'meal_item_count_other',
        )
        .replaceAll('{count}', foodCount.toString());
    final quality = _displayedQuality;
    final timeLabel = meal.resolveSubtitle(Localizations.localeOf(context));

    return Container(
      width: double.infinity,
      decoration: AppTheme.profileCardDecoration(isDarkMode, radius: 20),
      padding: const EdgeInsets.fromLTRB(14, 13, 12, 13),
      child: Row(
        children: [
          MealTypeIcon(mealTypeId: meal.typeId),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  meal.resolveTitle(l10n),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.1,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      MacroTheme.caloriesIcon,
                      size: 13,
                      color: MacroTheme.caloriesColor,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '${meal.calories.toStringAsFixed(0)} kcal',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: MacroTheme.caloriesColor,
                      ),
                    ),
                    _buildDot(secondaryTextColor),
                    Flexible(
                      child: Text(
                        foodCountLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: secondaryTextColor,
                        ),
                      ),
                    ),
                  ],
                ),
                if (timeLabel.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    timeLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: secondaryTextColor.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: quality.color.withValues(alpha: isDarkMode ? 0.18 : 0.10),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              l10n.translate(quality.labelKey),
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: quality.color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDot(Color secondaryTextColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Container(
        width: 3,
        height: 3,
        decoration: BoxDecoration(
          color: secondaryTextColor.withValues(alpha: 0.5),
          shape: BoxShape.circle,
        ),
      ),
    );
  }

  Widget _buildMacroCards(bool isDarkMode) {
    final l10n = AppLocalizations.of(context);
    final secondaryColor =
        isDarkMode ? const Color(0xFFAEB7CE) : AppTheme.textSecondaryColor;
    final meal = widget.meal;

    return Container(
      decoration: AppTheme.profileCardDecoration(isDarkMode),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: IntrinsicHeight(
          child: Row(
            children: [
              Expanded(
                child: _buildMacroStat(
                  MacroTheme.caloriesIcon,
                  meal.calories.toStringAsFixed(0),
                  'kcal',
                  MacroTheme.caloriesColor,
                  secondaryColor,
                ),
              ),
              _buildMacroDivider(isDarkMode),
              Expanded(
                child: _buildMacroStat(
                  MacroTheme.proteinIcon,
                  '${meal.protein.toStringAsFixed(0)}g',
                  l10n.translate('protein'),
                  MacroTheme.proteinColor,
                  secondaryColor,
                ),
              ),
              _buildMacroDivider(isDarkMode),
              Expanded(
                child: _buildMacroStat(
                  MacroTheme.carbsIcon,
                  '${meal.carbs.toStringAsFixed(0)}g',
                  l10n.translate('carbohydrates'),
                  MacroTheme.carbsColor,
                  secondaryColor,
                ),
              ),
              _buildMacroDivider(isDarkMode),
              Expanded(
                child: _buildMacroStat(
                  MacroTheme.fatIcon,
                  '${meal.fat.toStringAsFixed(0)}g',
                  l10n.translate('fat'),
                  MacroTheme.fatColor,
                  secondaryColor,
                ),
              ),
              _buildMacroDivider(isDarkMode),
              Expanded(
                key: const ValueKey('meal-fiber-macro'),
                child: Tooltip(
                  message: widget.showFiber
                      ? l10n.translate('fiber')
                      : l10n.translate('tap_for_premium'),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: widget.showFiber
                          ? null
                          : () =>
                              Navigator.of(context).pushNamed('/subscription'),
                      borderRadius: BorderRadius.circular(12),
                      child: _buildMacroStat(
                        widget.showFiber
                            ? MacroTheme.fiberIcon
                            : Icons.workspace_premium_rounded,
                        widget.showFiber
                            ? '${meal.fiber.toStringAsFixed(0)}g'
                            : l10n.translate('premium'),
                        l10n.translate('fiber'),
                        MacroTheme.fiberColor,
                        secondaryColor,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMacroStat(IconData icon, String value, String unit, Color color,
      Color secondaryColor) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        MacroTheme.iconBadge(
          icon: icon,
          color: color,
          isDarkMode: Theme.of(context).brightness == Brightness.dark,
          size: 26,
          iconSize: 15,
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            maxLines: 1,
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
        Text(
          unit,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.inter(
            fontSize: 10,
            color: secondaryColor,
          ),
        ),
      ],
    );
  }

  Widget _buildMacroDivider(bool isDarkMode) {
    return Container(
      width: 1,
      height: 42,
      color: isDarkMode
          ? Colors.white.withValues(alpha: 0.08)
          : Colors.black.withValues(alpha: 0.07),
    );
  }

  Widget _buildFoodsCard({
    required bool isDarkMode,
    required Color textColor,
    required Color secondaryTextColor,
  }) {
    final l10n = AppLocalizations.of(context);
    if (widget.meal.foods.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: AppTheme.profileCardDecoration(isDarkMode, radius: 20),
        child: Column(
          children: [
            Icon(
              Icons.restaurant_outlined,
              size: 40,
              color: secondaryTextColor.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 10),
            Text(
              l10n.translate('meal_foods_empty'),
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: textColor.withValues(alpha: 0.85),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      decoration: AppTheme.profileCardDecoration(isDarkMode, radius: 20),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Column(
              children: [
                for (var i = 0; i < widget.meal.foods.length; i++)
                  _buildFoodRow(
                    widget.meal.foods[i],
                    textColor: textColor,
                    secondaryTextColor: secondaryTextColor,
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Row(
              children: [
                _buildMealMacroStat(
                  MacroTheme.caloriesIcon,
                  MacroTheme.caloriesColor,
                  widget.meal.calories.toStringAsFixed(0),
                  'kcal',
                  isDarkMode,
                ),
                _buildMacroDivider(isDarkMode),
                _buildMealMacroStat(
                  MacroTheme.proteinIcon,
                  MacroTheme.proteinColor,
                  '${widget.meal.protein.toStringAsFixed(1)} g',
                  l10n.translate('protein_short'),
                  isDarkMode,
                ),
                _buildMacroDivider(isDarkMode),
                _buildMealMacroStat(
                  MacroTheme.carbsIcon,
                  MacroTheme.carbsColor,
                  '${widget.meal.carbs.toStringAsFixed(1)} g',
                  l10n.translate('carbs_short'),
                  isDarkMode,
                ),
                _buildMacroDivider(isDarkMode),
                _buildMealMacroStat(
                  MacroTheme.fatIcon,
                  MacroTheme.fatColor,
                  '${widget.meal.fat.toStringAsFixed(1)} g',
                  l10n.translate('fats_short'),
                  isDarkMode,
                ),
                _buildMacroDivider(isDarkMode),
                _buildMealMacroStat(
                  widget.showFiber
                      ? MacroTheme.fiberIcon
                      : Icons.workspace_premium_rounded,
                  MacroTheme.fiberColor,
                  widget.showFiber
                      ? '${widget.meal.fiber.toStringAsFixed(1)} g'
                      : l10n.translate('premium'),
                  l10n.translate('fiber'),
                  isDarkMode,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMealMacroStat(
    IconData icon,
    Color color,
    String value,
    String label,
    bool isDarkMode,
  ) {
    final secondaryColor =
        isDarkMode ? const Color(0xFFAEB7CE) : AppTheme.textSecondaryColor;

    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: isDarkMode ? 0.18 : 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              maxLines: 1,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
                color: color,
              ),
            ),
          ),
          const SizedBox(height: 1),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: secondaryColor.withValues(alpha: 0.85),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFoodRow(
    _MealPageFood food, {
    required Color textColor,
    required Color secondaryTextColor,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => FoodPage(
                food: food.foodPageModel,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                child: FoodIcon(name: food.name, emoji: food.emoji, size: 27),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      food.name,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: textColor.withValues(alpha: 0.9),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      food.amountLabel,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: secondaryTextColor.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${food.calories.toStringAsFixed(0)} kcal',
                textAlign: TextAlign.right,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: textColor.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAiCard({
    required bool isDarkMode,
    required Color textColor,
    required Color secondaryTextColor,
  }) {
    final l10n = AppLocalizations.of(context);
    final accentColor =
        isDarkMode ? AppTheme.primaryColorDarkMode : AppTheme.primaryColor;
    final buttonBackground = isDarkMode ? Colors.white : AppTheme.primaryColor;
    final buttonForeground = isDarkMode ? Colors.black : Colors.white;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: AppTheme.profileCardDecoration(isDarkMode, radius: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_isLoadingTips)
            _buildAiLoading(textColor, secondaryTextColor, accentColor)
          else if (_tips != null)
            _buildAiResult(
              isDarkMode: isDarkMode,
              textColor: textColor,
              secondaryTextColor: secondaryTextColor,
            )
          else
            _buildAiEmptyState(
              textColor: textColor,
              secondaryTextColor: secondaryTextColor,
              accentColor: accentColor,
            ),
          if (!_isLoadingTips) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                key: const ValueKey('meal-ai-cta'),
                onPressed: widget.meal.foods.isEmpty ? null : _fetchTips,
                icon: Icon(
                  _tips == null
                      ? Icons.auto_awesome_rounded
                      : Icons.refresh_rounded,
                  size: 20,
                ),
                label: Text(
                  l10n.translate(
                    _tips == null ? 'get_ai_tips' : 'refresh_tips',
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: buttonBackground,
                  foregroundColor: buttonForeground,
                  disabledBackgroundColor:
                      buttonBackground.withValues(alpha: 0.62),
                  disabledForegroundColor:
                      buttonForeground.withValues(alpha: 0.85),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAiEmptyState({
    required Color textColor,
    required Color secondaryTextColor,
    required Color accentColor,
  }) {
    final l10n = AppLocalizations.of(context);
    return Column(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.auto_awesome_rounded,
            color: accentColor,
            size: 26,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          l10n.translate('nutrition_tips_description'),
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 13,
            height: 1.45,
            color: secondaryTextColor,
          ),
        ),
        if (_tipsError != null) ...[
          const SizedBox(height: 10),
          Text(
            _tipsError!,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 13,
              height: 1.4,
              color: AppTheme.errorColor,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildAiLoading(
    Color textColor,
    Color secondaryTextColor,
    Color accentColor,
  ) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              color: accentColor,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            l10n.translate('analyzing_meal'),
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.translate('nutrition_tips_description'),
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 12,
              height: 1.4,
              color: secondaryTextColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAiResult({
    required bool isDarkMode,
    required Color textColor,
    required Color secondaryTextColor,
  }) {
    final l10n = AppLocalizations.of(context);
    final tips = _tips!;
    final quality = _displayedQuality;
    final accentColor =
        isDarkMode ? AppTheme.primaryColorDarkMode : AppTheme.primaryColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: isDarkMode ? 0.14 : 0.08),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.auto_awesome_rounded, size: 18, color: accentColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.translate(quality.labelKey),
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: quality.color,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                tips.summary,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  height: 1.45,
                  fontWeight: FontWeight.w500,
                  color: textColor,
                ),
              ),
            ],
          ),
        ),
        if (tips.highlights.isNotEmpty) ...[
          const SizedBox(height: 14),
          _AiInsightList(
            title: l10n.translate('positive_points'),
            items: tips.highlights,
            icon: Icons.check_circle_rounded,
            color: const Color(0xFF2FA66A),
            textColor: textColor,
            secondaryTextColor: secondaryTextColor,
          ),
        ],
        if (tips.improvements.isNotEmpty) ...[
          const SizedBox(height: 14),
          _AiInsightList(
            title: l10n.translate('can_improve'),
            items: tips.improvements,
            icon: Icons.lightbulb_rounded,
            color: const Color(0xFFC87500),
            textColor: textColor,
            secondaryTextColor: secondaryTextColor,
          ),
        ],
        if (tips.nextStep.isNotEmpty) ...[
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: quality.color.withValues(alpha: isDarkMode ? 0.16 : 0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.flag_rounded, size: 18, color: quality.color),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.translate('meal_ai_next_step'),
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        tips.nextStep,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          height: 1.45,
                          color: secondaryTextColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _AiInsightList extends StatelessWidget {
  final String title;
  final List<String> items;
  final IconData icon;
  final Color color;
  final Color textColor;
  final Color secondaryTextColor;

  const _AiInsightList({
    required this.title,
    required this.items,
    required this.icon,
    required this.color,
    required this.textColor,
    required this.secondaryTextColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.only(top: 6),
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    item,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      height: 1.45,
                      color: secondaryTextColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _MealPageData {
  final String title;
  final bool titleIsTranslationKey;
  final String subtitle;
  final DateTime? dateTime;
  final String typeId;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final double fiber;
  final bool fiberIsEstimated;
  final List<_MealPageFood> foods;

  const _MealPageData({
    required this.title,
    required this.titleIsTranslationKey,
    required this.subtitle,
    this.dateTime,
    required this.typeId,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.fiber,
    required this.fiberIsEstimated,
    required this.foods,
  });

  factory _MealPageData.fromMeal(Meal meal) {
    var totalFiber = 0.0;
    var estimatedFiber = false;

    final foods = meal.foods.map((food) {
      final nutrient =
          food.nutrients?.isNotEmpty == true ? food.nutrients!.first : null;
      final exactFiber = nutrient?.dietaryFiber;
      final fiber = exactFiber ?? _estimateFiberForFood(food.name);

      if (exactFiber == null) {
        estimatedFiber = true;
      }

      totalFiber += fiber;

      return _MealPageFood(
        name: food.name,
        emoji: food.emoji,
        amountLabel: food.amount ?? '',
        calories: food.calories.toDouble(),
        protein: food.protein,
        carbs: food.carbs,
        fat: food.fat,
        fiber: fiber,
        foodPageModel: food,
      );
    }).toList();

    return _MealPageData(
      title: meal.type.name,
      titleIsTranslationKey: true,
      subtitle: '',
      dateTime: meal.dateTime,
      typeId: meal.type.name,
      calories: meal.totalCalories.toDouble(),
      protein: meal.totalProtein,
      carbs: meal.totalCarbs,
      fat: meal.totalFat,
      fiber: totalFiber,
      fiberIsEstimated: estimatedFiber,
      foods: foods,
    );
  }

  factory _MealPageData.fromPlannedMeal(PlannedMeal meal) {
    var totalFiber = 0.0;
    final hasStoredFiber =
        meal.mealTotals.fiber > 0 || meal.foods.any((food) => food.fiber > 0);

    final foods = meal.foods.map((food) {
      final fiber =
          hasStoredFiber ? food.fiber : _estimateFiberForFood(food.name);
      totalFiber += fiber;

      return _MealPageFood(
        name: food.name,
        emoji: food.emoji,
        amountLabel: _formatAmount(food.amount, food.unit),
        calories: food.calories.toDouble(),
        protein: food.protein,
        carbs: food.carbs,
        fat: food.fat,
        fiber: fiber,
        foodPageModel: Food(
          name: food.name,
          amount: _formatAmount(food.amount, food.unit),
          emoji: food.emoji,
          nutrients: [
            Nutrient(
              idFood: 0,
              servingSize: food.amount,
              servingUnit: food.unit,
              calories: food.calories.toDouble(),
              protein: food.protein,
              carbohydrate: food.carbs,
              fat: food.fat,
              dietaryFiber: fiber,
            ),
          ],
        ),
      );
    }).toList();

    return _MealPageData(
      title: meal.name.isNotEmpty ? meal.name : meal.type,
      titleIsTranslationKey: false,
      subtitle: meal.time,
      typeId: meal.type,
      calories: meal.mealTotals.calories.toDouble(),
      protein: meal.mealTotals.protein,
      carbs: meal.mealTotals.carbs,
      fat: meal.mealTotals.fat,
      fiber: totalFiber,
      fiberIsEstimated: !hasStoredFiber,
      foods: foods,
    );
  }

  String resolveTitle(AppLocalizations l10n) {
    if (titleIsTranslationKey) {
      return l10n.translate(title);
    }
    return title;
  }

  String resolveSubtitle(Locale locale) {
    final localeName = locale.toLanguageTag();
    if (dateTime != null) {
      return DateFormat.yMd(localeName).add_jm().format(dateTime!);
    }

    final timeMatch = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(subtitle);
    if (timeMatch == null) return subtitle;

    final hour = int.tryParse(timeMatch.group(1)!);
    final minute = int.tryParse(timeMatch.group(2)!);
    if (hour == null || minute == null || hour > 23 || minute > 59) {
      return subtitle;
    }
    return DateFormat.jm(localeName).format(DateTime(2000, 1, 1, hour, minute));
  }
}

class _MealPageFood {
  final String name;
  final String emoji;
  final String amountLabel;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final double fiber;
  final Food foodPageModel;

  const _MealPageFood({
    required this.name,
    required this.emoji,
    required this.amountLabel,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.fiber,
    required this.foodPageModel,
  });
}

class _MealNutritionAnalysis {
  final double score;
  final _MealQuality quality;

  const _MealNutritionAnalysis({
    required this.score,
    required this.quality,
  });

  factory _MealNutritionAnalysis.fromMeal(_MealPageData meal) {
    final normalizedNames =
        meal.foods.map((food) => _normalizeFoodName(food.name)).toList();
    final uniqueFoods = normalizedNames.toSet().length;
    final plantFoods = normalizedNames.where(_isPlantForwardFood).length;
    final processedFoods = normalizedNames.where(_isProcessedFood).length;

    final proteinRatio = (meal.protein / 30.0).clamp(0.0, 1.0);
    final fiberRatio = (meal.fiber / 10.0).clamp(0.0, 1.0);
    final varietyRatio = (uniqueFoods / 4.0).clamp(0.0, 1.0);
    final plantRatio = meal.foods.isEmpty
        ? 0.0
        : (plantFoods / meal.foods.length).clamp(0.0, 1.0);
    final processedPenalty = meal.foods.isEmpty
        ? 0.0
        : (processedFoods / meal.foods.length).clamp(0.0, 1.0);

    double balanceRatio = 0.0;
    if (meal.protein >= 18 && meal.carbs >= 18 && meal.fat >= 6) {
      balanceRatio = 1.0;
    } else if (meal.protein >= 12 && (meal.carbs >= 12 || meal.fat >= 5)) {
      balanceRatio = 0.65;
    } else if (meal.protein > 0 || meal.carbs > 0 || meal.fat > 0) {
      balanceRatio = 0.35;
    }

    final rawScore = 22 +
        (proteinRatio * 28) +
        (fiberRatio * 24) +
        (balanceRatio * 14) +
        (varietyRatio * 8) +
        (plantRatio * 10) -
        (processedPenalty * 18);
    final score = rawScore.clamp(0.0, 100.0);

    final quality = score >= 78
        ? _MealQuality.great
        : score >= 55
            ? _MealQuality.good
            : _MealQuality.needsImprovement;

    return _MealNutritionAnalysis(
      score: score,
      quality: quality,
    );
  }
}

enum _MealQuality {
  needsImprovement('meal_quality_needs_improvement', Color(0xFFFF8A4C)),
  good('meal_quality_good', Color(0xFF4E8DFF)),
  great('meal_quality_great', Color(0xFF27A98B));

  final String labelKey;
  final Color color;

  const _MealQuality(this.labelKey, this.color);
}

String _formatAmount(double amount, String unit) {
  final rounded =
      amount % 1 == 0 ? amount.toStringAsFixed(0) : amount.toStringAsFixed(1);
  return '$rounded $unit';
}

double _estimateFiberForFood(String foodName) {
  final normalized = _normalizeFoodName(foodName);

  const veryHighFiber = [
    'feijao',
    'lentilha',
    'grao de bico',
    'grao-de-bico',
    'ervilha',
    'aveia',
    'chia',
    'linhaca',
    'granola',
    'brocolis',
    'broccoli',
    'couve',
    'salada',
    'beans',
    'oats',
    'lentils',
    'chickpea',
  ];

  const mediumFiber = [
    'banana',
    'maca',
    'pera',
    'laranja',
    'morango',
    'abacate',
    'arroz integral',
    'pao integral',
    'wrap integral',
    'batata doce',
    'mandioca',
    'fruta',
    'vegetal',
    'legume',
    'fruit',
    'whole',
    'sweet potato',
    'brown rice',
  ];

  const lowFiber = [
    'arroz',
    'massa',
    'macarrao',
    'pao',
    'tapioca',
    'iogurte',
    'leite',
    'ovo',
    'frango',
    'carne',
    'peixe',
    'queijo',
    'rice',
    'bread',
    'egg',
    'chicken',
    'beef',
  ];

  if (veryHighFiber.any(normalized.contains)) {
    return 4.0;
  }

  if (mediumFiber.any(normalized.contains)) {
    return 2.5;
  }

  if (lowFiber.any(normalized.contains)) {
    return 0.8;
  }

  return 1.2;
}

bool _isPlantForwardFood(String foodName) {
  final normalized = _normalizeFoodName(foodName);
  const plantKeywords = [
    'fruta',
    'banana',
    'maca',
    'morango',
    'laranja',
    'abacate',
    'salada',
    'brocolis',
    'couve',
    'espinafre',
    'legume',
    'feijao',
    'lentilha',
    'grao',
    'aveia',
    'chia',
    'linhaca',
    'fruit',
    'vegetable',
    'salad',
    'beans',
    'lentils',
    'oats',
  ];

  return plantKeywords.any(normalized.contains);
}

bool _isProcessedFood(String foodName) {
  final normalized = _normalizeFoodName(foodName);
  const processedKeywords = [
    'refrigerante',
    'salgadinho',
    'bolacha',
    'biscoito',
    'chocolate',
    'bolo',
    'sorvete',
    'pizza',
    'hamburguer',
    'hamburger',
    'batata frita',
    'frito',
    'frita',
    'bacon',
    'salsicha',
    'linguica',
    'salame',
    'soda',
    'fries',
    'cake',
    'cookie',
    'candy',
    'sausage',
  ];

  return processedKeywords.any(normalized.contains);
}

String _normalizeFoodName(String value) {
  const replacements = {
    'á': 'a',
    'à': 'a',
    'ã': 'a',
    'â': 'a',
    'ä': 'a',
    'é': 'e',
    'è': 'e',
    'ê': 'e',
    'ë': 'e',
    'í': 'i',
    'ì': 'i',
    'î': 'i',
    'ï': 'i',
    'ó': 'o',
    'ò': 'o',
    'õ': 'o',
    'ô': 'o',
    'ö': 'o',
    'ú': 'u',
    'ù': 'u',
    'û': 'u',
    'ü': 'u',
    'ç': 'c',
  };

  var normalized = value.toLowerCase().trim();
  replacements.forEach((from, to) {
    normalized = normalized.replaceAll(from, to);
  });
  return normalized;
}
