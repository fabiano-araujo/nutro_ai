import 'dart:io';

import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../models/diet_plan_model.dart';

class DietPdfLabels {
  const DietPdfLabels({
    required this.appName,
    required this.generatedBy,
    required this.shareText,
    required this.planFor,
    required this.objective,
    required this.dietStyle,
    required this.targetMacros,
    required this.dailyMacros,
    required this.meals,
    required this.food,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.portion,
    required this.nutrition,
    required this.page,
    this.tagline = '',
    this.nutritionSummary = '',
    this.macroDistribution = '',
    this.perDay = '',
    this.totalPlan = '',
  });

  final String appName;
  final String generatedBy;
  final String shareText;
  final String planFor;
  final String objective;
  final String dietStyle;
  final String targetMacros;
  final String dailyMacros;
  final String meals;
  final String food;
  final String calories;
  final String protein;
  final String carbs;
  final String fat;
  final String portion;
  final String nutrition;
  final String page;

  // Optional professional labels (fall back gracefully when empty).
  final String tagline;
  final String nutritionSummary;
  final String macroDistribution;
  final String perDay;
  final String totalPlan;
}

class DietPdfShareService {
  const DietPdfShareService._();

  // ── Brand (emerald) — premium nutrition identity, aligned with app green ──
  static const PdfColor _brand = PdfColor.fromInt(0xFF12A07A);
  static const PdfColor _brandDeep = PdfColor.fromInt(0xFF0B7A5E);

  // ── Neutrals ──────────────────────────────────────────────────────────────
  static const PdfColor _ink = PdfColor.fromInt(0xFF1A1F2B);
  static const PdfColor _ink2 = PdfColor.fromInt(0xFF3A4254);
  static const PdfColor _muted = PdfColor.fromInt(0xFF8A93A6);
  static const PdfColor _faint = PdfColor.fromInt(0xFFC2C9D6);
  static const PdfColor _paper = PdfColor.fromInt(0xFFF5F8FB);
  static const PdfColor _line = PdfColor.fromInt(0xFFE7ECF3);
  static const PdfColor _hair = PdfColor.fromInt(0xFFF1F4F9);

  // ── Macros (canonical app palette — MacroTheme) ────────────────────────────
  static const PdfColor _cal = PdfColor.fromInt(0xFF26B5AD);
  static const PdfColor _calDeep = PdfColor.fromInt(0xFF168B82);
  static const PdfColor _pro = PdfColor.fromInt(0xFF7D6BFF);
  static const PdfColor _car = PdfColor.fromInt(0xFFFFB248);
  static const PdfColor _fat = PdfColor.fromInt(0xFFD94F8A);
  static const PdfColor _calSoft = PdfColor.fromInt(0xFFE1F6F5);
  static const PdfColor _proSoft = PdfColor.fromInt(0xFFECEAFF);
  static const PdfColor _carSoft = PdfColor.fromInt(0xFFFFF3DD);
  static const PdfColor _fatSoft = PdfColor.fromInt(0xFFFBE4EE);

  static Future<void> shareDietPlanPdf({
    required DietPlan dietPlan,
    required String title,
    required String periodLabel,
    required String objective,
    required String dietStyle,
    required DailyNutrition targetNutrition,
    required DietPdfLabels labels,
    required DateTime generatedAt,
  }) async {
    final bytes = await buildDietPlanPdfBytes(
      dietPlan: dietPlan,
      title: title,
      periodLabel: periodLabel,
      objective: objective,
      dietStyle: dietStyle,
      targetNutrition: targetNutrition,
      labels: labels,
      generatedAt: generatedAt,
    );

    final tempDir = await getTemporaryDirectory();
    final timestamp = DateFormat('yyyyMMdd_HHmm').format(generatedAt);
    final fileName = _safeFileName('nutro_dieta_$timestamp.pdf');
    final file = File('${tempDir.path}${Platform.pathSeparator}$fileName');
    await file.writeAsBytes(bytes, flush: true);

    final generatedDate = DateFormat('dd/MM/yyyy').format(generatedAt);
    await Share.shareXFiles(
      [
        XFile(
          file.path,
          mimeType: 'application/pdf',
          name: fileName,
        ),
      ],
      subject: title,
      text: '${labels.shareText}\n${labels.generatedBy} $generatedDate.',
    );
  }

  static Future<Uint8List> buildDietPlanPdfBytes({
    required DietPlan dietPlan,
    required String title,
    required String periodLabel,
    required String objective,
    required String dietStyle,
    required DailyNutrition targetNutrition,
    required DietPdfLabels labels,
    required DateTime generatedAt,
  }) async {
    final logo = await _loadLogo();
    final fonts = await _loadFonts();
    final generatedDate = DateFormat('dd/MM/yyyy').format(generatedAt);
    final document = pw.Document(
      theme: pw.ThemeData.withFont(
        base: fonts.regular,
        bold: fonts.bold,
      ),
      title: title,
      author: labels.appName,
      creator: labels.appName,
    );

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(34, 32, 34, 28),
        footer: (context) => pw.Container(
          padding: const pw.EdgeInsets.only(top: 8),
          decoration: const pw.BoxDecoration(
            border: pw.Border(
              top: pw.BorderSide(color: _line, width: 0.8),
            ),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                labels.appName,
                style: pw.TextStyle(
                  color: _muted,
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(
                '${labels.page} ${context.pageNumber}/${context.pagesCount}',
                style: const pw.TextStyle(color: _muted, fontSize: 9),
              ),
            ],
          ),
        ),
        build: (context) => [
          _buildHero(
            logo: logo,
            title: title,
            periodLabel: periodLabel,
            generatedText: '${labels.generatedBy} $generatedDate.',
            labels: labels,
          ),
          pw.SizedBox(height: 16),
          _buildSummaryChips(
            objective: objective,
            dietStyle: dietStyle,
            periodLabel: periodLabel,
            labels: labels,
          ),
          pw.SizedBox(height: 14),
          pw.Inseparable(
            child: _buildNutritionSummary(
              planned: dietPlan.totalNutrition,
              labels: labels,
            ),
          ),
          pw.SizedBox(height: 18),
          _buildSectionHeader(labels.meals, dietPlan.meals.length),
          pw.SizedBox(height: 10),
          for (var i = 0; i < dietPlan.meals.length; i++) ...[
            if (i > 0) pw.SizedBox(height: 10),
            pw.Inseparable(child: _buildMealCard(dietPlan.meals[i], labels)),
          ],
        ],
      ),
    );

    return document.save();
  }

  // ── Hero ────────────────────────────────────────────────────────────────
  static pw.Widget _buildHero({
    required pw.MemoryImage? logo,
    required String title,
    required String periodLabel,
    required String generatedText,
    required DietPdfLabels labels,
  }) {
    return pw.ClipRRect(
      horizontalRadius: 22,
      verticalRadius: 22,
      child: pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.all(22),
        decoration: pw.BoxDecoration(
          gradient: pw.LinearGradient(
            begin: pw.Alignment.topLeft,
            end: pw.Alignment.bottomRight,
            colors: [_brandDeep, const PdfColor.fromInt(0xFF16B98A)],
          ),
        ),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Container(
              width: 54,
              height: 54,
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(
                color: PdfColors.white,
                borderRadius: pw.BorderRadius.circular(15),
              ),
              child: logo == null
                  ? pw.Center(
                      child: pw.Text(
                        'N',
                        style: pw.TextStyle(
                          color: _brandDeep,
                          fontSize: 26,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    )
                  : pw.Image(logo, fit: pw.BoxFit.contain),
            ),
            pw.SizedBox(width: 15),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    _cleanText(labels.appName).toUpperCase(),
                    style: pw.TextStyle(
                      color: PdfColor(1, 1, 1, 0.92),
                      fontSize: 10.5,
                      fontWeight: pw.FontWeight.bold,
                      letterSpacing: 1.6,
                    ),
                  ),
                  if (labels.tagline.trim().isNotEmpty) ...[
                    pw.SizedBox(height: 3),
                    pw.Text(
                      _cleanText(labels.tagline),
                      style: pw.TextStyle(
                        color: PdfColor(1, 1, 1, 0.74),
                        fontSize: 9,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                  pw.SizedBox(height: 11),
                  pw.Text(
                    _cleanText(title),
                    style: pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 23,
                      fontWeight: pw.FontWeight.bold,
                      lineSpacing: 2,
                    ),
                  ),
                  pw.SizedBox(height: 12),
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: pw.BoxDecoration(
                          color: PdfColors.white,
                          borderRadius: pw.BorderRadius.circular(8),
                        ),
                        child: pw.Text(
                          _cleanText(periodLabel),
                          style: pw.TextStyle(
                            color: _brandDeep,
                            fontSize: 8.5,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                      pw.SizedBox(width: 10),
                      pw.Expanded(
                        child: pw.Text(
                          _cleanText(generatedText),
                          maxLines: 1,
                          style: pw.TextStyle(
                            color: PdfColor(1, 1, 1, 0.82),
                            fontSize: 8.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Summary chips (objective / style / period) ────────────────────────────
  static pw.Widget _buildSummaryChips({
    required String objective,
    required String dietStyle,
    required String periodLabel,
    required DietPdfLabels labels,
  }) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(child: _infoChip(labels.objective, objective)),
        pw.SizedBox(width: 9),
        pw.Expanded(child: _infoChip(labels.dietStyle, dietStyle)),
        pw.SizedBox(width: 9),
        pw.Expanded(child: _infoChip(labels.planFor, periodLabel)),
      ],
    );
  }

  static pw.Widget _infoChip(String label, String value) {
    return pw.Container(
      constraints: const pw.BoxConstraints(minHeight: 54),
      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        border: pw.Border.all(color: _line, width: 1),
        borderRadius: pw.BorderRadius.circular(13),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        mainAxisAlignment: pw.MainAxisAlignment.center,
        children: [
          pw.Row(
            children: [
              _dot(_brand, 6),
              pw.SizedBox(width: 6),
              pw.Expanded(
                child: pw.Text(
                  _cleanText(label).toUpperCase(),
                  maxLines: 1,
                  style: pw.TextStyle(
                    color: _muted,
                    fontSize: 7.5,
                    fontWeight: pw.FontWeight.bold,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 5),
          pw.Text(
            _cleanText(value),
            maxLines: 2,
            style: pw.TextStyle(
              color: _ink,
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
              lineSpacing: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  // ── Nutrition summary (simple overview of the diet's macros) ───────────────
  static pw.Widget _buildNutritionSummary({
    required DailyNutrition planned,
    required DietPdfLabels labels,
  }) {
    final summaryTitle = labels.nutritionSummary.trim().isNotEmpty
        ? labels.nutritionSummary
        : labels.targetMacros;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          children: [
            _accentBar(height: 18),
            pw.SizedBox(width: 9),
            pw.Text(
              _cleanText(summaryTitle),
              style: pw.TextStyle(
                color: _ink,
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 11),
        pw.Row(
          children: [
            pw.Expanded(
              child: _statCard(
                _calSoft,
                _cal,
                labels.calories,
                '${planned.calories}',
                'kcal',
              ),
            ),
            pw.SizedBox(width: 9),
            pw.Expanded(
              child: _statCard(
                _proSoft,
                _pro,
                labels.protein,
                _formatGrams(planned.protein),
                'g',
              ),
            ),
            pw.SizedBox(width: 9),
            pw.Expanded(
              child: _statCard(
                _carSoft,
                _car,
                labels.carbs,
                _formatGrams(planned.carbs),
                'g',
              ),
            ),
            pw.SizedBox(width: 9),
            pw.Expanded(
              child: _statCard(
                _fatSoft,
                _fat,
                labels.fat,
                _formatGrams(planned.fat),
                'g',
              ),
            ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _statCard(
    PdfColor softBg,
    PdfColor dotColor,
    String label,
    String value,
    String unit,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 11, vertical: 11),
      decoration: pw.BoxDecoration(
        color: softBg,
        borderRadius: pw.BorderRadius.circular(13),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.RichText(
            text: pw.TextSpan(
              children: [
                pw.TextSpan(
                  text: value,
                  style: pw.TextStyle(
                    color: _ink,
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.TextSpan(
                  text: ' $unit',
                  style: const pw.TextStyle(color: _muted, fontSize: 9),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 7),
          pw.Row(
            children: [
              _dot(dotColor, 6),
              pw.SizedBox(width: 5),
              pw.Expanded(
                child: pw.Text(
                  _cleanText(label),
                  maxLines: 1,
                  style: const pw.TextStyle(color: _ink2, fontSize: 9),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Section header ─────────────────────────────────────────────────────────
  static pw.Widget _buildSectionHeader(String title, int count) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            _accentBar(height: 18),
            pw.SizedBox(width: 9),
            pw.Text(
              _cleanText(title),
              style: pw.TextStyle(
                color: _ink,
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ],
        ),
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: pw.BoxDecoration(
            color: _paper,
            borderRadius: pw.BorderRadius.circular(20),
          ),
          child: pw.Text(
            '$count',
            style: pw.TextStyle(
              color: _muted,
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  // ── Meal card ──────────────────────────────────────────────────────────────
  static pw.Widget _buildMealCard(PlannedMeal meal, DietPdfLabels labels) {
    final totals = meal.mealTotals;
    final hasMacros = totals.protein > 0 || totals.carbs > 0 || totals.fat > 0;

    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(13),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: pw.BorderRadius.circular(15),
        border: pw.Border.all(color: _line, width: 1),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      _cleanText(meal.name),
                      style: pw.TextStyle(
                        color: _ink,
                        fontSize: 13.5,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    if (_cleanText(meal.time).isNotEmpty) ...[
                      pw.SizedBox(height: 5),
                      _timePill(meal.time),
                    ],
                  ],
                ),
              ),
              pw.SizedBox(width: 10),
              _kcalPill(totals.calories),
            ],
          ),
          if (hasMacros) ...[
            pw.SizedBox(height: 10),
            _mealMacroChips(totals, labels),
          ],
          if (meal.foods.isNotEmpty) ...[
            pw.SizedBox(height: 9),
            pw.Container(height: 1, color: _line),
            pw.SizedBox(height: 1),
            ..._buildFoodRows(meal.foods, labels),
          ],
        ],
      ),
    );
  }

  static pw.Widget _timePill(String time) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: pw.BoxDecoration(
        color: _paper,
        borderRadius: pw.BorderRadius.circular(7),
      ),
      child: pw.Text(
        _cleanText(time),
        style: const pw.TextStyle(color: _ink2, fontSize: 8.5),
      ),
    );
  }

  static pw.Widget _kcalPill(int calories) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: pw.BoxDecoration(
        color: _calSoft,
        borderRadius: pw.BorderRadius.circular(9),
      ),
      child: pw.RichText(
        text: pw.TextSpan(
          children: [
            pw.TextSpan(
              text: '$calories',
              style: pw.TextStyle(
                color: _ink,
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.TextSpan(
              text: ' kcal',
              style: pw.TextStyle(
                color: _calDeep,
                fontSize: 8.5,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Full macro names at the top of each meal (e.g. "Proteína 29g").
  static pw.Widget _mealMacroChips(
      DailyNutrition totals, DietPdfLabels labels) {
    return pw.Wrap(
      spacing: 16,
      runSpacing: 5,
      children: [
        _macroChip(_pro, labels.protein, totals.protein),
        _macroChip(_car, labels.carbs, totals.carbs),
        _macroChip(_fat, labels.fat, totals.fat),
      ],
    );
  }

  static pw.Widget _macroChip(PdfColor color, String label, double grams) {
    return pw.Row(
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        _dot(color, 6),
        pw.SizedBox(width: 6),
        pw.RichText(
          text: pw.TextSpan(
            children: [
              pw.TextSpan(
                text: '${_cleanText(label)} ',
                style: const pw.TextStyle(color: _ink2, fontSize: 9),
              ),
              pw.TextSpan(
                text: '${_formatGrams(grams)}g',
                style: pw.TextStyle(
                  color: _ink,
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static List<pw.Widget> _buildFoodRows(
    List<PlannedFood> foods,
    DietPdfLabels labels,
  ) {
    final rows = <pw.Widget>[];
    for (var i = 0; i < foods.length; i++) {
      rows.add(_foodRow(foods[i], labels));
      if (i < foods.length - 1) {
        rows.add(pw.Container(height: 1, color: _hair));
      }
    }
    return rows;
  }

  static pw.Widget _foodRow(PlannedFood food, DietPdfLabels labels) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 6),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          _dot(_faint, 6),
          pw.SizedBox(width: 10),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  _cleanText(food.name),
                  maxLines: 2,
                  style: const pw.TextStyle(color: _ink2, fontSize: 10.5),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  _formatFoodPortion(food),
                  style: const pw.TextStyle(color: _muted, fontSize: 8.5),
                ),
              ],
            ),
          ),
          pw.SizedBox(width: 8),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.RichText(
                text: pw.TextSpan(
                  children: [
                    pw.TextSpan(
                      text: '${food.calories}',
                      style: pw.TextStyle(
                        color: _ink,
                        fontSize: 10.5,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.TextSpan(
                      text: ' kcal',
                      style: const pw.TextStyle(color: _muted, fontSize: 8),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                _foodMacroLine(food, labels),
                style: const pw.TextStyle(color: _muted, fontSize: 8),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Shared primitives ──────────────────────────────────────────────────────
  static pw.Widget _dot(PdfColor color, double size) {
    return pw.Container(
      width: size,
      height: size,
      decoration: pw.BoxDecoration(
        color: color,
        shape: pw.BoxShape.circle,
      ),
    );
  }

  static pw.Widget _accentBar({double height = 16}) {
    return pw.Container(
      width: 4,
      height: height,
      decoration: pw.BoxDecoration(
        color: _brand,
        borderRadius: pw.BorderRadius.circular(2),
      ),
    );
  }

  // ── Assets ─────────────────────────────────────────────────────────────────
  static Future<pw.MemoryImage?> _loadLogo() async {
    try {
      final data = await rootBundle.load('assets/images/logo.png');
      return pw.MemoryImage(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      );
    } catch (_) {
      return null;
    }
  }

  static Future<_DietPdfFonts> _loadFonts() async {
    try {
      final regular = await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
      final bold = await rootBundle.load('assets/fonts/Roboto-Bold.ttf');
      return _DietPdfFonts(
        regular: pw.Font.ttf(regular),
        bold: pw.Font.ttf(bold),
      );
    } catch (_) {
      return _DietPdfFonts(
        regular: pw.Font.helvetica(),
        bold: pw.Font.helveticaBold(),
      );
    }
  }

  // ── Formatting ─────────────────────────────────────────────────────────────
  static String _foodMacroLine(PlannedFood food, DietPdfLabels labels) {
    return '${_shortLabel(labels.protein)} ${_formatGrams(food.protein)}g  '
        '·  ${_shortLabel(labels.carbs)} ${_formatGrams(food.carbs)}g  '
        '·  ${_shortLabel(labels.fat)} ${_formatGrams(food.fat)}g';
  }

  static String _formatFoodPortion(PlannedFood food) {
    return '${_formatAmount(food.amount)} ${food.unit}';
  }

  static String _formatAmount(double value) {
    return value == value.roundToDouble()
        ? value.round().toString()
        : value.toStringAsFixed(1);
  }

  static String _formatGrams(double value) {
    return value == value.roundToDouble()
        ? value.round().toString()
        : value.toStringAsFixed(1);
  }

  static String _shortLabel(String label) {
    final clean = _cleanText(label);
    return clean.isEmpty ? '' : clean.substring(0, 1).toUpperCase();
  }

  static String _safeFileName(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9_.-]+'), '_')
        .replaceAll(RegExp(r'_+'), '_');
  }

  static String _cleanText(String value) {
    final buffer = StringBuffer();
    for (final rune in value.runes) {
      if (rune == 0xfe0f || rune > 0xffff) {
        continue;
      }
      if (rune < 32 && rune != 10) {
        continue;
      }
      buffer.writeCharCode(rune);
    }
    return buffer.toString().trim();
  }
}

class _DietPdfFonts {
  const _DietPdfFonts({
    required this.regular,
    required this.bold,
  });

  final pw.Font regular;
  final pw.Font bold;
}
