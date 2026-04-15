import 'dart:convert';

import 'package:flutter/material.dart';
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
import 'food_page.dart';

class MealPage extends StatefulWidget {
  final _MealPageData meal;

  const MealPage._({
    super.key,
    required this.meal,
  });

  factory MealPage.fromMeal({
    Key? key,
    required Meal meal,
  }) {
    return MealPage._(
      key: key,
      meal: _MealPageData.fromMeal(meal),
    );
  }

  factory MealPage.fromPlannedMeal({
    Key? key,
    required PlannedMeal meal,
  }) {
    return MealPage._(
      key: key,
      meal: _MealPageData.fromPlannedMeal(meal),
    );
  }

  @override
  State<MealPage> createState() => _MealPageState();
}

class _MealPageState extends State<MealPage> {
  late final _MealNutritionAnalysis _analysis;
  bool _isLoadingTips = false;
  _MealTips? _tips;
  String? _tipsError;

  @override
  void initState() {
    super.initState();
    _analysis = _MealNutritionAnalysis.fromMeal(widget.meal);
  }

  Future<void> _fetchTips() async {
    setState(() {
      _isLoadingTips = true;
      _tipsError = null;
    });

    try {
      final aiService = AIService();
      final authService = Provider.of<AuthService>(context, listen: false);
      final locale = Localizations.localeOf(context);
      final languageCode =
          '${locale.languageCode}_${locale.countryCode ?? locale.languageCode.toUpperCase()}';
      final userId = authService.currentUser?.id.toString() ?? '';

      final buffer = StringBuffer();
      await for (final chunk in aiService.getAnswerStream(
        _buildAiPrompt(languageCode),
        languageCode: languageCode,
        quality: 'bom',
        userId: userId,
        agentType: 'nutrition',
      )) {
        if (!mounted) {
          return;
        }
        if (chunk.startsWith('[CONEXAO_ID]')) {
          continue;
        }
        buffer.write(chunk);
      }

      final parsedTips = _parseTips(buffer.toString());

      if (!mounted) {
        return;
      }
      setState(() {
        _tips = parsedTips;
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

  String _buildAiPrompt(String languageCode) {
    final l10n = AppLocalizations.of(context);
    final meal = widget.meal;
    final foods = meal.foods
        .map(
          (food) =>
              '- ${food.name} (${food.amountLabel}, ${food.calories.toStringAsFixed(0)} kcal)',
        )
        .join('\n');

    return '''
Analise a refeição abaixo e responda APENAS com JSON válido.

Idioma da resposta: $languageCode
Nome da refeição: ${meal.resolveTitle(l10n)}
Horário: ${meal.subtitle}
Calorias: ${meal.calories.toStringAsFixed(0)} kcal
Proteína: ${meal.protein.toStringAsFixed(1)} g
Carboidratos: ${meal.carbs.toStringAsFixed(1)} g
Gorduras: ${meal.fat.toStringAsFixed(1)} g
Fibra: ${meal.fiber.toStringAsFixed(1)} g${meal.fiberIsEstimated ? ' (estimada)' : ''}
Score nutricional local: ${_analysis.score.round()}/100
Categoria local: ${l10n.translate(_analysis.quality.labelKey)}
Alimentos:
$foods

Retorne exatamente neste formato:
{
  "summary": "Resumo curto em 1 ou 2 frases.",
  "positive_points": ["Ponto positivo 1", "Ponto positivo 2"],
  "can_improve": ["Melhoria 1", "Melhoria 2"]
}

Regras:
- Seja objetivo.
- Não inclua markdown.
- Não inclua texto antes ou depois do JSON.
- Se a refeição já estiver boa, "can_improve" pode ter 0 ou 1 item.
''';
  }

  _MealTips _parseTips(String rawResponse) {
    final cleaned =
        rawResponse.replaceAll('```json', '').replaceAll('```', '').trim();

    final match = RegExp(r'\{[\s\S]*\}').firstMatch(cleaned);
    if (match != null) {
      final jsonString = match.group(0)!;
      final decoded = jsonDecode(jsonString) as Map<String, dynamic>;
      return _MealTips(
        summary: decoded['summary']?.toString().trim() ?? '',
        positivePoints: _parseStringList(decoded['positive_points']),
        canImprove: _parseStringList(decoded['can_improve']),
      );
    }

    return _MealTips(
      summary: cleaned,
      positivePoints: const [],
      canImprove: const [],
    );
  }

  List<String> _parseStringList(dynamic value) {
    if (value is! List) {
      return const [];
    }

    return value
        .map((item) => item?.toString().trim() ?? '')
        .where((item) => item.isNotEmpty)
        .toList();
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
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
        title: Text(
          meal.resolveTitle(l10n),
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeroCard(
              context,
              isDarkMode: isDarkMode,
              textColor: textColor,
              secondaryTextColor: secondaryTextColor,
            ),
            const SizedBox(height: 16),
            _buildSectionTitle(
              l10n.translate('meal_overview'),
              textColor,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _StatTile(
                    label: l10n.translate('calories'),
                    value: '${meal.calories.toStringAsFixed(0)} kcal',
                    icon: Icons.local_fire_department_rounded,
                    color: const Color(0xFFFF7D61),
                    isDarkMode: isDarkMode,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _StatTile(
                    label: l10n.translate('protein'),
                    value: '${meal.protein.toStringAsFixed(1)} g',
                    icon: Icons.fitness_center_rounded,
                    color: const Color(0xFF7D6BFF),
                    isDarkMode: isDarkMode,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _StatTile(
                    label: l10n.translate('carbs'),
                    value: '${meal.carbs.toStringAsFixed(1)} g',
                    icon: Icons.grain_rounded,
                    color: const Color(0xFFFFB248),
                    isDarkMode: isDarkMode,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _StatTile(
                    label: l10n.translate('fats'),
                    value: '${meal.fat.toStringAsFixed(1)} g',
                    icon: Icons.opacity_rounded,
                    color: const Color(0xFF37B39B),
                    isDarkMode: isDarkMode,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildSectionTitle(
              l10n.translate('nutritional_score'),
              textColor,
            ),
            const SizedBox(height: 8),
            _buildScoreCard(
              context,
              isDarkMode: isDarkMode,
              textColor: textColor,
              secondaryTextColor: secondaryTextColor,
            ),
            const SizedBox(height: 16),
            _buildSectionTitle(
              l10n.translate('meal_foods_title'),
              textColor,
            ),
            const SizedBox(height: 8),
            _buildFoodsCard(
              isDarkMode: isDarkMode,
              textColor: textColor,
              secondaryTextColor: secondaryTextColor,
            ),
            const SizedBox(height: 16),
            _buildSectionTitle(
              l10n.translate('nutrition_tips'),
              textColor,
            ),
            const SizedBox(height: 8),
            _buildTipsCard(
              context,
              isDarkMode: isDarkMode,
              textColor: textColor,
              secondaryTextColor: secondaryTextColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroCard(
    BuildContext context, {
    required bool isDarkMode,
    required Color textColor,
    required Color secondaryTextColor,
  }) {
    final l10n = AppLocalizations.of(context);
    final meal = widget.meal;
    final qualityColor = _analysis.quality.color;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDarkMode
              ? [
                  const Color(0xFF312743),
                  const Color(0xFF1F2128),
                ]
              : [
                  const Color(0xFFF3EFFF),
                  const Color(0xFFFFF6E7),
                ],
        ),
        border: Border.all(
          color: qualityColor.withValues(alpha: isDarkMode ? 0.45 : 0.24),
        ),
        boxShadow: [
          BoxShadow(
            color: qualityColor.withValues(alpha: isDarkMode ? 0.12 : 0.08),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 58,
                height: 58,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color:
                      Colors.white.withValues(alpha: isDarkMode ? 0.08 : 0.65),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(
                  meal.emoji,
                  style: const TextStyle(fontSize: 28),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      meal.resolveTitle(l10n),
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      meal.subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: secondaryTextColor,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color:
                      qualityColor.withValues(alpha: isDarkMode ? 0.18 : 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _analysis.score.round().toString(),
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: qualityColor,
                      ),
                    ),
                    Text(
                      l10n.translate('nutritional_score'),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: secondaryTextColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildHeroChip(
                label: l10n.translate(_analysis.quality.labelKey),
                color: qualityColor,
                isDarkMode: isDarkMode,
              ),
              _buildHeroChip(
                label:
                    '${meal.foods.length} ${l10n.translate('foods_count_label')}',
                color: const Color(0xFF6A8DFF),
                isDarkMode: isDarkMode,
              ),
              _buildHeroChip(
                label:
                    '${meal.fiber.toStringAsFixed(1)} g ${l10n.translate('fiber')}${meal.fiberIsEstimated ? ' • ${l10n.translate('estimated')}' : ''}',
                color: const Color(0xFF27A98B),
                isDarkMode: isDarkMode,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeroChip({
    required String label,
    required Color color,
    required bool isDarkMode,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDarkMode ? 0.18 : 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: color.withValues(alpha: isDarkMode ? 0.40 : 0.18),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _buildScoreCard(
    BuildContext context, {
    required bool isDarkMode,
    required Color textColor,
    required Color secondaryTextColor,
  }) {
    final l10n = AppLocalizations.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDarkMode ? AppTheme.darkCardColor : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDarkMode ? AppTheme.darkBorderColor : AppTheme.dividerColor,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.translate('meal_quality'),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: secondaryTextColor,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      l10n.translate(_analysis.quality.labelKey),
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: _analysis.quality.color,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: _analysis.quality.color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(
                  '${_analysis.score.round()}/100',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: _analysis.quality.color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _LevelBar(
            label: l10n.translate('protein_level'),
            value: _analysis.proteinRatio,
            amountLabel: '${widget.meal.protein.toStringAsFixed(1)} g',
            valueLabel: l10n.translate(_analysis.proteinLevelKey),
            leftLabel: l10n.translate('low'),
            rightLabel: l10n.translate('high'),
            color: const Color(0xFF7D6BFF),
            isDarkMode: isDarkMode,
          ),
          const SizedBox(height: 16),
          _LevelBar(
            label: l10n.translate('fiber_level'),
            value: _analysis.fiberRatio,
            amountLabel:
                '${widget.meal.fiber.toStringAsFixed(1)} g${widget.meal.fiberIsEstimated ? ' • ${l10n.translate('estimated')}' : ''}',
            valueLabel: l10n.translate(_analysis.fiberLevelKey),
            leftLabel: l10n.translate('low'),
            rightLabel: l10n.translate('high'),
            color: const Color(0xFF27A98B),
            isDarkMode: isDarkMode,
          ),
        ],
      ),
    );
  }

  Widget _buildFoodsCard({
    required bool isDarkMode,
    required Color textColor,
    required Color secondaryTextColor,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDarkMode ? AppTheme.darkCardColor : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDarkMode ? AppTheme.darkBorderColor : AppTheme.dividerColor,
        ),
      ),
      child: Column(
        children: [
          for (var i = 0; i < widget.meal.foods.length; i++) ...[
            _buildFoodRow(
              widget.meal.foods[i],
              textColor: textColor,
              secondaryTextColor: secondaryTextColor,
            ),
            if (i != widget.meal.foods.length - 1)
              Divider(
                height: 1,
                color: (isDarkMode ? Colors.white : Colors.black)
                    .withValues(alpha: 0.06),
              ),
          ],
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
              builder: (_) => FoodPage(food: food.foodPageModel),
            ),
          );
        },
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  food.emoji,
                  style: const TextStyle(fontSize: 22),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      food.name,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      food.amountLabel,
                      style: TextStyle(
                        fontSize: 12,
                        color: secondaryTextColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${food.calories.toStringAsFixed(0)} kcal',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: secondaryTextColor.withValues(alpha: 0.7),
                    size: 18,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTipsCard(
    BuildContext context, {
    required bool isDarkMode,
    required Color textColor,
    required Color secondaryTextColor,
  }) {
    final l10n = AppLocalizations.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDarkMode ? AppTheme.darkCardColor : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDarkMode ? AppTheme.darkBorderColor : AppTheme.dividerColor,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.translate('nutrition_tips_description'),
            style: TextStyle(
              fontSize: 13,
              height: 1.45,
              color: secondaryTextColor,
            ),
          ),
          const SizedBox(height: 16),
          if (_isLoadingTips) ...[
            Row(
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l10n.translate('analyzing_meal'),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                ),
              ],
            ),
          ] else if (_tips != null) ...[
            _TipsBlock(
              title: _tips!.summary,
              textColor: textColor,
            ),
            if (_tips!.positivePoints.isNotEmpty) ...[
              const SizedBox(height: 16),
              _TipsList(
                title: l10n.translate('positive_points'),
                items: _tips!.positivePoints,
                icon: Icons.trending_up_rounded,
                color: const Color(0xFF27A98B),
                textColor: textColor,
                secondaryTextColor: secondaryTextColor,
              ),
            ],
            if (_tips!.canImprove.isNotEmpty) ...[
              const SizedBox(height: 16),
              _TipsList(
                title: l10n.translate('can_improve'),
                items: _tips!.canImprove,
                icon: Icons.tune_rounded,
                color: const Color(0xFFFF9F43),
                textColor: textColor,
                secondaryTextColor: secondaryTextColor,
              ),
            ],
          ] else ...[
            Text(
              _tipsError ?? l10n.translate('nutrition_tips_description'),
              style: TextStyle(
                fontSize: 13,
                height: 1.45,
                color: _tipsError == null
                    ? secondaryTextColor
                    : AppTheme.errorColor,
              ),
            ),
          ],
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isLoadingTips ? null : _fetchTips,
              icon: Icon(
                _tips == null
                    ? Icons.auto_awesome_outlined
                    : Icons.refresh_rounded,
              ),
              label: Text(
                l10n.translate(
                  _tips == null ? 'get_ai_tips' : 'refresh_tips',
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
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

  Widget _buildSectionTitle(String title, Color textColor) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w800,
        color: textColor,
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final bool isDarkMode;

  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? AppTheme.darkCardColor : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: color.withValues(alpha: isDarkMode ? 0.35 : 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDarkMode
                        ? const Color(0xFFAEB7CE)
                        : AppTheme.textSecondaryColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: isDarkMode
                  ? AppTheme.darkTextColor
                  : AppTheme.textPrimaryColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _LevelBar extends StatelessWidget {
  final String label;
  final double value;
  final String amountLabel;
  final String valueLabel;
  final String leftLabel;
  final String rightLabel;
  final Color color;
  final bool isDarkMode;

  const _LevelBar({
    required this.label,
    required this.value,
    required this.amountLabel,
    required this.valueLabel,
    required this.leftLabel,
    required this.rightLabel,
    required this.color,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    final barBackground = isDarkMode
        ? Colors.white.withValues(alpha: 0.08)
        : const Color(0xFFF2F4F8);
    final textColor =
        isDarkMode ? AppTheme.darkTextColor : AppTheme.textPrimaryColor;
    final secondaryTextColor =
        isDarkMode ? const Color(0xFFAEB7CE) : AppTheme.textSecondaryColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              amountLabel,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: secondaryTextColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: Container(
            height: 12,
            color: barBackground,
            child: Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: value.clamp(0.0, 1.0),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        color.withValues(alpha: 0.35),
                        color,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Text(
              leftLabel,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: secondaryTextColor,
              ),
            ),
            const Spacer(),
            Text(
              valueLabel,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            const Spacer(),
            Text(
              rightLabel,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: secondaryTextColor,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _TipsBlock extends StatelessWidget {
  final String title;
  final Color textColor;

  const _TipsBlock({
    required this.title,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          height: 1.5,
          color: textColor,
        ),
      ),
    );
  }
}

class _TipsList extends StatelessWidget {
  final String title;
  final List<String> items;
  final IconData icon;
  final Color color;
  final Color textColor;
  final Color secondaryTextColor;

  const _TipsList({
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
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
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
                    style: TextStyle(
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
  final String emoji;
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
    required this.emoji,
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
        foodPageModel: food,
      );
    }).toList();

    return _MealPageData(
      title: meal.type.name,
      titleIsTranslationKey: true,
      subtitle: DateFormat('dd/MM • HH:mm').format(meal.dateTime),
      emoji: _mealEmojiFromType(meal.type.name),
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

    final foods = meal.foods.map((food) {
      final estimatedFiber = _estimateFiberForFood(food.name);
      totalFiber += estimatedFiber;

      return _MealPageFood(
        name: food.name,
        emoji: food.emoji,
        amountLabel: _formatAmount(food.amount, food.unit),
        calories: food.calories.toDouble(),
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
              dietaryFiber: estimatedFiber,
            ),
          ],
        ),
      );
    }).toList();

    return _MealPageData(
      title: meal.name.isNotEmpty ? meal.name : meal.type,
      titleIsTranslationKey: false,
      subtitle: meal.time,
      emoji: _mealEmojiFromType(meal.type),
      calories: meal.mealTotals.calories.toDouble(),
      protein: meal.mealTotals.protein,
      carbs: meal.mealTotals.carbs,
      fat: meal.mealTotals.fat,
      fiber: totalFiber,
      fiberIsEstimated: true,
      foods: foods,
    );
  }

  String resolveTitle(AppLocalizations l10n) {
    if (titleIsTranslationKey) {
      return l10n.translate(title);
    }
    return title;
  }
}

class _MealPageFood {
  final String name;
  final String emoji;
  final String amountLabel;
  final double calories;
  final Food foodPageModel;

  const _MealPageFood({
    required this.name,
    required this.emoji,
    required this.amountLabel,
    required this.calories,
    required this.foodPageModel,
  });
}

class _MealTips {
  final String summary;
  final List<String> positivePoints;
  final List<String> canImprove;

  const _MealTips({
    required this.summary,
    required this.positivePoints,
    required this.canImprove,
  });
}

class _MealNutritionAnalysis {
  final double score;
  final _MealQuality quality;
  final double proteinRatio;
  final double fiberRatio;
  final String proteinLevelKey;
  final String fiberLevelKey;

  const _MealNutritionAnalysis({
    required this.score,
    required this.quality,
    required this.proteinRatio,
    required this.fiberRatio,
    required this.proteinLevelKey,
    required this.fiberLevelKey,
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
      proteinRatio: proteinRatio,
      fiberRatio: fiberRatio,
      proteinLevelKey: _levelKey(proteinRatio),
      fiberLevelKey: _levelKey(fiberRatio),
    );
  }

  static String _levelKey(double ratio) {
    if (ratio >= 0.75) {
      return 'high';
    }
    if (ratio >= 0.4) {
      return 'moderate';
    }
    return 'low';
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

String _mealEmojiFromType(String type) {
  switch (type) {
    case 'breakfast':
      return '🌅';
    case 'lunch':
      return '☀️';
    case 'dinner':
      return '🌙';
    case 'snack':
      return '🍎';
    case 'freeMeal':
      return '🍽️';
    default:
      return '🍽️';
  }
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
