import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../theme/macro_theme.dart';
import 'package:provider/provider.dart';
import '../providers/credit_provider.dart';
import '../providers/diet_plan_provider.dart';
import '../providers/nutrition_goals_provider.dart';
import '../providers/meal_types_provider.dart';
import '../services/diet_pdf_share_service.dart';
import '../widgets/weekly_calendar.dart';
import '../widgets/meal_skeleton.dart';
import '../models/diet_plan_model.dart';
import '../models/food_model.dart';
import '../models/Nutrient.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';
import '../screens/food_page.dart';
import '../screens/nutrition_goals_wizard_screen.dart';
import '../screens/login_screen.dart';
import '../screens/subscription_screen.dart';
import '../i18n/app_localizations.dart';
import '../widgets/diet_style_message_state.dart';
import '../widgets/food_icon.dart';
import '../widgets/header_streak_badge.dart';
import '../widgets/reward_ad_dialog.dart';

class _ReplacementQuickOption {
  const _ReplacementQuickOption({
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;
}

class _ReplacementNotesSheetContent extends StatefulWidget {
  const _ReplacementNotesSheetContent({
    required this.title,
    required this.description,
    required this.hintText,
    required this.confirmLabel,
    required this.initialValue,
  });

  final String title;
  final String description;
  final String hintText;
  final String confirmLabel;
  final String initialValue;

  @override
  State<_ReplacementNotesSheetContent> createState() =>
      _ReplacementNotesSheetContentState();
}

class _ReplacementNotesSheetContentState
    extends State<_ReplacementNotesSheetContent> {
  late final TextEditingController _controller;
  final Set<String> _selectedQuickNotes = {};

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _buildReplacementNotes() {
    final customNote = _controller.text.trim();
    return [
      ..._selectedQuickNotes,
      if (customNote.isNotEmpty) customNote,
    ].join('; ');
  }

  List<_ReplacementQuickOption> _buildQuickOptions(AppLocalizations l10n) {
    return [
      _ReplacementQuickOption(
        label: l10n.translate('replacement_chip_lighter'),
        icon: Icons.spa_rounded,
        color: const Color(0xFF2FA66A),
      ),
      _ReplacementQuickOption(
        label: l10n.translate('replacement_chip_lactose_free'),
        icon: Icons.no_drinks_rounded,
        color: const Color(0xFF1E9BC2),
      ),
      _ReplacementQuickOption(
        label: l10n.translate('replacement_chip_gluten_free'),
        icon: Icons.grain_rounded,
        color: const Color(0xFFFFB248),
      ),
      _ReplacementQuickOption(
        label: l10n.translate('replacement_chip_vegetarian'),
        icon: Icons.eco_rounded,
        color: const Color(0xFF5C9E3F),
      ),
      _ReplacementQuickOption(
        label: l10n.translate('replacement_chip_vegan'),
        icon: Icons.energy_savings_leaf_rounded,
        color: const Color(0xFF008C7A),
      ),
      _ReplacementQuickOption(
        label: l10n.translate('replacement_chip_budget'),
        icon: Icons.savings_rounded,
        color: const Color(0xFFB8860B),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor =
        isDarkMode ? AppTheme.darkTextColor : AppTheme.textPrimaryColor;
    final secondaryTextColor =
        isDarkMode ? const Color(0xFFAEB7CE) : AppTheme.textSecondaryColor;
    final sheetColor = isDarkMode ? AppTheme.darkCardColor : AppTheme.cardColor;
    final accentColor =
        isDarkMode ? AppTheme.primaryColorDarkMode : AppTheme.primaryColor;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final trimmedDescription = widget.description.trim();
    final quickOptions = _buildQuickOptions(l10n);

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        top: false,
        child: Container(
          decoration: BoxDecoration(
            color: sheetColor,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(24),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 24,
                offset: const Offset(0, -8),
              ),
            ],
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: secondaryTextColor.withValues(alpha: 0.28),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  widget.title,
                  style: GoogleFonts.poppins(
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
                if (trimmedDescription.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    trimmedDescription,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      height: 1.3,
                      color: secondaryTextColor,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Text(
                  l10n.translate('replacement_quick_adjustments'),
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: quickOptions.map((option) {
                    final selected = _selectedQuickNotes.contains(option.label);
                    return _buildQuickChip(
                      option: option,
                      selected: selected,
                      isDarkMode: isDarkMode,
                      textColor: textColor,
                      secondaryTextColor: secondaryTextColor,
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _controller,
                  minLines: 2,
                  maxLines: 3,
                  maxLength: 240,
                  keyboardType: TextInputType.multiline,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: l10n.translate('replacement_notes_field_label'),
                    hintText: widget.hintText,
                    alignLabelWithHint: true,
                    counterText: '',
                    contentPadding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                    filled: true,
                    fillColor: isDarkMode
                        ? Colors.black.withValues(alpha: 0.14)
                        : Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: secondaryTextColor.withValues(alpha: 0.18),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: secondaryTextColor.withValues(alpha: 0.18),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: accentColor,
                        width: 1.4,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(null),
                        child: Text(l10n.translate('cancel')),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => Navigator.of(context).pop(
                          _buildReplacementNotes(),
                        ),
                        icon: const Icon(
                          Icons.auto_awesome_rounded,
                          size: 18,
                        ),
                        label: Text(
                          widget.confirmLabel,
                          textAlign: TextAlign.center,
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accentColor,
                          foregroundColor: AppTheme.onColor(accentColor),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickChip({
    required _ReplacementQuickOption option,
    required bool selected,
    required bool isDarkMode,
    required Color textColor,
    required Color secondaryTextColor,
  }) {
    final backgroundColor = selected
        ? option.color.withValues(alpha: isDarkMode ? 0.24 : 0.13)
        : (isDarkMode
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.black.withValues(alpha: 0.035));
    final borderColor = selected
        ? option.color.withValues(alpha: isDarkMode ? 0.72 : 0.44)
        : secondaryTextColor.withValues(alpha: 0.16);
    final iconBackground = selected
        ? option.color
        : option.color.withValues(alpha: isDarkMode ? 0.18 : 0.12);
    final iconColor = selected ? AppTheme.onColor(option.color) : option.color;

    return Semantics(
      button: true,
      selected: selected,
      label: option.label,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          onTap: () {
            setState(() {
              if (selected) {
                _selectedQuickNotes.remove(option.label);
              } else {
                _selectedQuickNotes.add(option.label);
              }
            });
          },
          borderRadius: BorderRadius.circular(999),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOut,
            constraints: const BoxConstraints(minHeight: 42),
            padding: const EdgeInsets.fromLTRB(8, 7, 12, 7),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: borderColor),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: option.color.withValues(alpha: 0.16),
                        blurRadius: 12,
                        offset: const Offset(0, 5),
                      ),
                    ]
                  : const [],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: iconBackground,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    option.icon,
                    color: iconColor,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  option.label,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: selected
                        ? textColor
                        : secondaryTextColor.withValues(alpha: 0.92),
                  ),
                ),
                if (selected) ...[
                  const SizedBox(width: 6),
                  Icon(
                    Icons.check_circle_rounded,
                    size: 15,
                    color: option.color,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class PersonalizedDietScreen extends StatefulWidget {
  final VoidCallback? onOpenDrawer;
  final VoidCallback? onSearchPressed;

  const PersonalizedDietScreen({
    Key? key,
    this.onOpenDrawer,
    this.onSearchPressed,
  }) : super(key: key);

  @override
  State<PersonalizedDietScreen> createState() => _PersonalizedDietScreenState();
}

class _PersonalizedDietScreenState extends State<PersonalizedDietScreen>
    with WidgetsBindingObserver {
  final ScrollController _scrollController = ScrollController();
  static const double _scrollVisibilityThreshold = 6.0;
  bool _isHeaderCollapsed = false;
  double _lastScrollOffset = 0;
  bool _isSharingDietPdf = false;

  // Controle de refeições expandidas
  final Set<String> _expandedMeals = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scrollController.addListener(_handleScrollVisibility);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshDietGenerationJob();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.removeListener(_handleScrollVisibility);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshDietGenerationJob();
    }
  }

  void _refreshDietGenerationJob() {
    if (!mounted) return;
    unawaited(
      context.read<DietPlanProvider>().refreshActiveDietGenerationJob(),
    );
  }

  bool _isInsufficientCreditsError(String? error) {
    final normalized = _normalizeErrorForMatching(error);

    return normalized.contains('creditos insuficientes') ||
        normalized.contains('credito insuficiente') ||
        normalized.contains('saldo insuficiente') ||
        normalized.contains('insufficient credits') ||
        normalized.contains('not enough credits') ||
        normalized.contains('out of credits') ||
        normalized.contains('sem creditos') ||
        normalized.contains('creditos acabaram') ||
        normalized.contains('erro na api: 403');
  }

  bool _isInternalTextGenerationError(String? error) {
    final normalized = _normalizeErrorForMatching(error);
    return normalized.contains('erro interno ao gerar texto') ||
        normalized.contains('internal error') ||
        normalized.contains('internal server error') ||
        normalized.contains('erro na api: 500');
  }

  bool _isTextGenerationTimeoutError(String? error) {
    final normalized = _normalizeErrorForMatching(error);
    return normalized.contains('tempo limite excedido ao gerar texto') ||
        normalized.contains('timeout') ||
        normalized.contains('timed out');
  }

  String _normalizeErrorForMatching(String? error) {
    if (error == null || error.trim().isEmpty) return '';
    return _extractReadableDietError(error)
        .toLowerCase()
        .replaceAll('é', 'e')
        .replaceAll('ê', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ì', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ô', 'o')
        .replaceAll('ã', 'a')
        .replaceAll('á', 'a')
        .replaceAll('ú', 'u')
        .replaceAll('ç', 'c');
  }

  String _extractReadableDietError(String error) {
    var message = error.trim();
    var changed = true;

    while (changed) {
      changed = false;
      for (final prefix in const [
        'Erro ao gerar plano de dieta:',
        'Exception:',
      ]) {
        if (message.startsWith(prefix)) {
          message = message.substring(prefix.length).trim();
          changed = true;
        }
      }
    }

    final jsonMessageMatch =
        RegExp(r'"message"\s*:\s*"([^"]+)"').firstMatch(message);
    if (jsonMessageMatch != null) {
      return jsonMessageMatch.group(1)!.trim();
    }

    final jsonErrorMatch =
        RegExp(r'"error"\s*:\s*"([^"]+)"').firstMatch(message);
    if (jsonErrorMatch != null) {
      return jsonErrorMatch.group(1)!.trim();
    }

    final apiSeparator = message.indexOf(' - ');
    if (apiSeparator >= 0 && apiSeparator + 3 < message.length) {
      return message.substring(apiSeparator + 3).trim();
    }

    return message;
  }

  void _showDietCreditOptions({
    required DietPlanProvider dietProvider,
    required VoidCallback onRewardEarned,
  }) {
    unawaited(context.read<CreditProvider>().markCreditsExhausted());
    dietProvider.markDietGenerationInsufficientCredits();
    RewardAdDialog.show(
      context,
      onRewardEarned: onRewardEarned,
    );
  }

  Future<bool> _ensureCreditsBeforeDietRequest({
    required AuthService authService,
    required DietPlanProvider dietProvider,
    required VoidCallback onRewardEarned,
  }) async {
    final token = authService.token;
    final userId = authService.currentUser?.id;
    if (token == null || token.isEmpty || userId == null) {
      return true;
    }

    final creditProvider = context.read<CreditProvider>();
    try {
      await creditProvider.refreshCreditsFromServer(
        token: token,
        userId: userId,
      );
    } catch (e) {
      debugPrint('Não foi possível atualizar créditos antes da dieta: $e');
    }

    if (creditProvider.creditsRemaining > 0) {
      return true;
    }

    if (!mounted) {
      return false;
    }

    _showDietCreditOptions(
      dietProvider: dietProvider,
      onRewardEarned: onRewardEarned,
    );
    return false;
  }

  void _handleDietActionError({
    required DietPlanProvider dietProvider,
    required AppLocalizations l10n,
    required VoidCallback onRewardEarned,
  }) {
    if (_isInsufficientCreditsError(dietProvider.error)) {
      _showDietCreditOptions(
        dietProvider: dietProvider,
        onRewardEarned: onRewardEarned,
      );
      return;
    }

    _showDietGenerationErrorSnackBar(dietProvider, l10n);
  }

  void _showDietGenerationErrorSnackBar(
    DietPlanProvider dietProvider,
    AppLocalizations l10n,
  ) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '${l10n.translate('diet_generation_error')}\n'
                '${_buildGenerationErrorMessage(l10n, dietProvider)}',
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _handleScrollVisibility() {
    if (!_scrollController.hasClients) return;

    final currentOffset = _scrollController.offset;
    final scrollDelta = currentOffset - _lastScrollOffset;

    if (currentOffset <= 0) {
      _lastScrollOffset = 0;
      _setHeaderCollapsed(false);
      return;
    }

    if (scrollDelta.abs() < _scrollVisibilityThreshold) return;

    _lastScrollOffset = currentOffset;
    if (scrollDelta > 0) {
      _setHeaderCollapsed(true);
    } else {
      _setHeaderCollapsed(false);
    }
  }

  void _setHeaderCollapsed(bool collapsed) {
    if (_isHeaderCollapsed == collapsed) return;
    setState(() => _isHeaderCollapsed = collapsed);
  }

  void _showHeader() {
    _lastScrollOffset =
        _scrollController.hasClients ? _scrollController.offset : 0;
    _setHeaderCollapsed(false);
  }

  Widget _buildWeeklyFixedHeader(bool isDarkMode, AppLocalizations l10n) {
    final bgColor =
        isDarkMode ? AppTheme.darkBackgroundColor : AppTheme.backgroundColor;
    final textColor =
        isDarkMode ? AppTheme.darkTextColor : AppTheme.textPrimaryColor;
    return Container(
      height: 56,
      color: bgColor,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (widget.onOpenDrawer != null)
                IconButton(
                  icon: Icon(Icons.menu, color: textColor),
                  onPressed: widget.onOpenDrawer,
                  tooltip: 'Menu',
                )
              else
                const SizedBox(width: 48),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const HeaderStreakBadge(margin: EdgeInsets.only(right: 4)),
                  if (widget.onSearchPressed != null)
                    IconButton(
                      icon: Icon(Icons.search, color: textColor),
                      tooltip: 'Pesquisar alimentos',
                      onPressed: widget.onSearchPressed,
                    ),
                ],
              ),
            ],
          ),
          Text(
            l10n.translate('my_diet'),
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  // Generate diet plan for selected date
  Future<void> _generateDietPlan() async {
    final dietProvider = Provider.of<DietPlanProvider>(context, listen: false);
    final nutritionGoals =
        Provider.of<NutritionGoalsProvider>(context, listen: false);
    final authService = Provider.of<AuthService>(context, listen: false);
    final mealTypesProvider =
        Provider.of<MealTypesProvider>(context, listen: false);

    // Check if user is authenticated - open login screen automatically
    if (!authService.isAuthenticated || authService.currentUser == null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const LoginScreen(popOnSuccess: true),
        ),
      );
      return;
    }

    // Set auth on diet provider
    if (!dietProvider.isAuthenticated) {
      await dietProvider.setAuth(
        authService.token ?? '',
        authService.currentUser!.id,
      );
    }

    await dietProvider.ensureLoaded();

    // Check if trying to generate daily diet without premium
    // Weekly diet is free, daily diet is paid
    if (dietProvider.dietMode == DietMode.daily && !dietProvider.isPremium) {
      _showPremiumRequiredDialog();
      return;
    }

    if (!await _ensureCreditsBeforeDietRequest(
      authService: authService,
      dietProvider: dietProvider,
      onRewardEarned: () => unawaited(_generateDietPlan()),
    )) {
      return;
    }

    await nutritionGoals.ensureLoaded();

    // Check if nutrition goals are configured
    if (!nutritionGoals.hasConfiguredGoals) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const NutritionGoalsWizardScreen(),
        ),
      );
      return;
    }

    // Ensure meal types are loaded
    await mealTypesProvider.ensureLoaded();

    if (!dietProvider.hasCompletedDietPersonalization) {
      final shouldContinue =
          await _showDietGenerationPreferencesDialog(dietProvider);
      if (!mounted || !shouldContinue) {
        return;
      }
    }

    // Get device locale
    final locale = Localizations.localeOf(context);
    final languageCode =
        '${locale.languageCode}_${locale.countryCode ?? locale.languageCode.toUpperCase()}';

    // Get userId from authenticated user
    final userId = authService.currentUser?.id.toString() ?? '';

    // Get meal types from provider
    final mealTypes = mealTypesProvider.mealTypes;
    print(
        '🍽️ PersonalizedDietScreen: Gerando dieta com ${mealTypes.length} refeições');
    print(
        '🍽️ PersonalizedDietScreen: Tipos: ${mealTypes.map((m) => m.name).join(', ')}');

    // Generate diet plan
    await dietProvider.generateDietPlan(
      dietProvider.selectedDate,
      nutritionGoals,
      mealTypes: mealTypes,
      userId: userId,
      languageCode: languageCode,
    );

    if (!mounted) return;

    final l10n = AppLocalizations.of(context);

    if (dietProvider.error != null) {
      // Check if error is premium required
      if (dietProvider.error == 'daily_diet_premium_required') {
        _showPremiumRequiredDialog();
      } else {
        _handleDietActionError(
          dietProvider: dietProvider,
          l10n: l10n,
          onRewardEarned: () => unawaited(_generateDietPlan()),
        );
      }
    } else if (dietProvider.currentDietPlan != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(l10n.translate('diet_generated_success')),
              ),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<bool> _showDietGenerationPreferencesDialog(
    DietPlanProvider dietProvider,
  ) async {
    final l10n = AppLocalizations.of(context);
    final preferences = dietProvider.preferences;
    final nutritionGoals =
        Provider.of<NutritionGoalsProvider>(context, listen: false);
    final restrictionsController = TextEditingController(
      text: preferences.foodRestrictions.join(', '),
    );
    final favoriteFoodsController = TextEditingController(
      text: preferences.favoriteFoods.join(', '),
    );
    final avoidedFoodsController = TextEditingController(
      text: preferences.avoidedFoods.join(', '),
    );
    final routineController = TextEditingController(
      text: preferences.routineConsiderations.join(', '),
    );
    final routineFocusNode = FocusNode();
    var selectedHungriestMeal = preferences.hungriestMealTime;
    var selectedDietType = nutritionGoals.dietType;

    final quickDietTypes = const [
      DietType.aiRecommended,
      DietType.balanced,
      DietType.highProtein,
      DietType.lowCarb,
      DietType.ketogenic,
      DietType.mediterranean,
      DietType.paleo,
      DietType.lowFat,
      DietType.dash,
    ];
    final healthTokens = const [
      'hipertensao',
      'diabetes',
      'colesterol alto',
    ];

    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            return StatefulBuilder(
              builder: (context, setDialogState) {
                return AlertDialog(
                  title: Text(
                    l10n.translate('diet_generation_preferences_title'),
                  ),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.translate(
                            'diet_generation_preferences_description',
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildPreferenceOptionSection(
                          title: l10n.translate(
                            'diet_generation_preferences_diet_style_label',
                          ),
                          children: quickDietTypes
                              .map(
                                (dietType) => ChoiceChip(
                                  label: Text(
                                    nutritionGoals.getDietTypeName(
                                      dietType,
                                      context,
                                    ),
                                  ),
                                  selected: selectedDietType == dietType,
                                  onSelected: (_) {
                                    setDialogState(() {
                                      selectedDietType = dietType;
                                    });
                                  },
                                ),
                              )
                              .toList(),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: restrictionsController,
                          decoration: InputDecoration(
                            labelText: l10n.translate(
                              'diet_generation_preferences_restrictions_label',
                            ),
                            hintText: l10n.translate(
                              'diet_generation_preferences_restrictions_hint',
                            ),
                          ),
                          textInputAction: TextInputAction.next,
                          onChanged: (_) => setDialogState(() {}),
                        ),
                        const SizedBox(height: 8),
                        _buildPreferenceOptionSection(
                          title: l10n.translate(
                            'diet_generation_preferences_restrictions_quick_label',
                          ),
                          children: [
                            ChoiceChip(
                              label: Text(l10n.translate('diet_option_none')),
                              selected:
                                  restrictionsController.text.trim().isEmpty,
                              onSelected: (_) {
                                setDialogState(() {
                                  restrictionsController.clear();
                                });
                              },
                            ),
                            for (final option in const [
                              ('vegetariano', 'diet_option_vegetarian'),
                              ('vegano', 'diet_option_vegan'),
                              ('sem gluten', 'diet_option_gluten_free'),
                              ('sem lactose', 'diet_option_lactose_free'),
                            ])
                              ChoiceChip(
                                label: Text(l10n.translate(option.$2)),
                                selected: _preferenceContains(
                                  restrictionsController.text,
                                  option.$1,
                                ),
                                onSelected: (selected) {
                                  setDialogState(() {
                                    _setPreferenceToken(
                                      restrictionsController,
                                      option.$1,
                                      selected,
                                    );
                                  });
                                },
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: favoriteFoodsController,
                          decoration: InputDecoration(
                            labelText: l10n.translate(
                              'diet_generation_preferences_favorite_foods_label',
                            ),
                            hintText: l10n.translate(
                              'diet_generation_preferences_favorite_foods_hint',
                            ),
                          ),
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: avoidedFoodsController,
                          decoration: InputDecoration(
                            labelText: l10n.translate(
                              'diet_generation_preferences_avoided_foods_label',
                            ),
                            hintText: l10n.translate(
                              'diet_generation_preferences_avoided_foods_hint',
                            ),
                          ),
                          textInputAction: TextInputAction.next,
                          onChanged: (_) => setDialogState(() {}),
                        ),
                        const SizedBox(height: 8),
                        _buildPreferenceOptionSection(
                          title: l10n.translate(
                            'diet_generation_preferences_avoided_quick_label',
                          ),
                          children: [
                            ChoiceChip(
                              label: Text(l10n.translate('diet_option_none')),
                              selected:
                                  avoidedFoodsController.text.trim().isEmpty,
                              onSelected: (_) {
                                setDialogState(() {
                                  avoidedFoodsController.clear();
                                });
                              },
                            ),
                            ChoiceChip(
                              label: Text(
                                l10n.translate('diet_option_no_red_meat'),
                              ),
                              selected: _preferenceContains(
                                avoidedFoodsController.text,
                                'carne vermelha',
                              ),
                              onSelected: (selected) {
                                setDialogState(() {
                                  _setPreferenceToken(
                                    avoidedFoodsController,
                                    'carne vermelha',
                                    selected,
                                  );
                                });
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: selectedHungriestMeal,
                          decoration: InputDecoration(
                            labelText: l10n.translate(
                              'diet_generation_preferences_hungriest_label',
                            ),
                          ),
                          items: [
                            DropdownMenuItem(
                              value: 'breakfast',
                              child: Text(l10n.translate('breakfast')),
                            ),
                            DropdownMenuItem(
                              value: 'lunch',
                              child: Text(l10n.translate('lunch')),
                            ),
                            DropdownMenuItem(
                              value: 'dinner',
                              child: Text(l10n.translate('dinner')),
                            ),
                            DropdownMenuItem(
                              value: 'snack',
                              child: Text(l10n.translate('snack')),
                            ),
                          ],
                          onChanged: (value) {
                            if (value == null) {
                              return;
                            }
                            setDialogState(() {
                              selectedHungriestMeal = value;
                            });
                          },
                        ),
                        const SizedBox(height: 12),
                        _buildPreferenceOptionSection(
                          title: l10n.translate(
                            'diet_generation_preferences_health_quick_label',
                          ),
                          children: [
                            ChoiceChip(
                              label: Text(l10n.translate('diet_option_none')),
                              selected: !_preferenceContainsAny(
                                routineController.text,
                                healthTokens,
                              ),
                              onSelected: (_) {
                                setDialogState(() {
                                  _removePreferenceTokens(
                                    routineController,
                                    healthTokens,
                                  );
                                });
                              },
                            ),
                            for (final option in const [
                              (
                                'hipertensao',
                                'diet_option_high_blood_pressure'
                              ),
                              ('diabetes', 'diet_option_diabetes'),
                              (
                                'colesterol alto',
                                'diet_option_high_cholesterol'
                              ),
                            ])
                              ChoiceChip(
                                label: Text(l10n.translate(option.$2)),
                                selected: _preferenceContains(
                                  routineController.text,
                                  option.$1,
                                ),
                                onSelected: (selected) {
                                  setDialogState(() {
                                    _setPreferenceToken(
                                      routineController,
                                      option.$1,
                                      selected,
                                    );
                                  });
                                },
                              ),
                            ActionChip(
                              label: Text(l10n.translate('diet_option_other')),
                              onPressed: () {
                                setDialogState(() {});
                                routineFocusNode.requestFocus();
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: routineController,
                          focusNode: routineFocusNode,
                          decoration: InputDecoration(
                            labelText: l10n.translate(
                              'diet_generation_preferences_routine_label',
                            ),
                            hintText: l10n.translate(
                              'diet_generation_preferences_routine_hint',
                            ),
                          ),
                          maxLines: 3,
                          onChanged: (_) => setDialogState(() {}),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext, false),
                      child: Text(l10n.translate('cancel')),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        nutritionGoals.updateDietType(selectedDietType);
                        dietProvider.updateDietGenerationPreferences(
                          foodRestrictions: _splitPreferenceList(
                            restrictionsController.text,
                          ),
                          favoriteFoods: _splitPreferenceList(
                            favoriteFoodsController.text,
                          ),
                          avoidedFoods: _splitPreferenceList(
                            avoidedFoodsController.text,
                          ),
                          routineConsiderations: _splitPreferenceList(
                            routineController.text,
                          ),
                          hungriestMealTime: selectedHungriestMeal,
                          reviewedRestrictions: true,
                          reviewedFoodPreferences: true,
                          reviewedRoutineNeeds: true,
                          mergeRestrictions: false,
                          mergeFoodPreferences: false,
                          mergeRoutineConsiderations: false,
                        );
                        Navigator.pop(dialogContext, true);
                      },
                      child: Text(l10n.translate('continue')),
                    ),
                  ],
                );
              },
            );
          },
        ) ??
        false;

    restrictionsController.dispose();
    favoriteFoodsController.dispose();
    avoidedFoodsController.dispose();
    routineController.dispose();
    routineFocusNode.dispose();

    return confirmed;
  }

  Future<String?> _showReplacementNotesSheet({
    required String title,
    required String description,
    required String hintText,
    required String confirmLabel,
    String initialValue = '',
  }) async {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ReplacementNotesSheetContent(
        title: title,
        description: description,
        hintText: hintText,
        confirmLabel: confirmLabel,
        initialValue: initialValue,
      ),
    );
  }

  Widget _buildPreferenceOptionSection({
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: children,
        ),
      ],
    );
  }

  List<String> _splitPreferenceList(String rawValue) {
    return rawValue
        .split(RegExp(r'\s*(?:,|;|\n)\s*'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  bool _preferenceContains(String rawValue, String token) {
    final normalizedToken = token.trim().toLowerCase();
    return _splitPreferenceList(rawValue).any(
      (item) => item.trim().toLowerCase() == normalizedToken,
    );
  }

  bool _preferenceContainsAny(String rawValue, Iterable<String> tokens) {
    return tokens.any((token) => _preferenceContains(rawValue, token));
  }

  void _setPreferenceToken(
    TextEditingController controller,
    String token,
    bool selected,
  ) {
    final normalizedToken = token.trim().toLowerCase();
    final values = _splitPreferenceList(controller.text)
        .where((item) => item.trim().toLowerCase() != normalizedToken)
        .toList();
    if (selected) {
      values.add(token);
    }
    controller.text = values.join(', ');
    controller.selection = TextSelection.collapsed(
      offset: controller.text.length,
    );
  }

  void _removePreferenceTokens(
    TextEditingController controller,
    Iterable<String> tokens,
  ) {
    final normalizedTokens = tokens.map((token) => token.toLowerCase()).toSet();
    final values = _splitPreferenceList(controller.text)
        .where(
          (item) => !normalizedTokens.contains(item.trim().toLowerCase()),
        )
        .toList();
    controller.text = values.join(', ');
    controller.selection = TextSelection.collapsed(
      offset: controller.text.length,
    );
  }

  // Show premium required dialog for daily diet
  void _showPremiumRequiredDialog() {
    final l10n = AppLocalizations.of(context);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final buttonColor =
        isDarkMode ? AppTheme.primaryColorDarkMode : AppTheme.primaryColor;
    final buttonForegroundColor = AppTheme.onColor(buttonColor);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.workspace_premium, color: buttonColor),
            const SizedBox(width: 8),
            Text(l10n.translate('daily_diet_premium_title')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.translate('daily_diet_premium_description')),
            const SizedBox(height: 12),
            Text(
              l10n.translate('weekly_diet_free'),
              style: TextStyle(
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.translate('cancel')),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const SubscriptionScreen()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: buttonColor,
              foregroundColor: buttonForegroundColor,
            ),
            child: Text(
              l10n.translate('subscribe_now'),
              style: TextStyle(color: buttonForegroundColor),
            ),
          ),
        ],
      ),
    );
  }

  PlannedMeal? _findCurrentMeal(String mealType) {
    final meals = Provider.of<DietPlanProvider>(context, listen: false)
            .currentDietPlan
            ?.meals ??
        const <PlannedMeal>[];

    for (final meal in meals) {
      if (meal.type == mealType) {
        return meal;
      }
    }

    return null;
  }

  // Replace a single meal
  Future<void> _replaceMeal(
    String mealType, {
    String? replacementNotes,
    bool skipNotesSheet = false,
  }) async {
    final dietProvider = Provider.of<DietPlanProvider>(context, listen: false);
    final nutritionGoals =
        Provider.of<NutritionGoalsProvider>(context, listen: false);
    final authService = Provider.of<AuthService>(context, listen: false);
    final mealTypesProvider =
        Provider.of<MealTypesProvider>(context, listen: false);
    final l10n = AppLocalizations.of(context);

    if (!authService.isAuthenticated || authService.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.translate('login_required_for_diet'))),
      );
      return;
    }

    if (!dietProvider.isAuthenticated) {
      await dietProvider.setAuth(
        authService.token ?? '',
        authService.currentUser!.id,
      );
    }

    if (!await _ensureCreditsBeforeDietRequest(
      authService: authService,
      dietProvider: dietProvider,
      onRewardEarned: () => unawaited(_replaceMeal(
        mealType,
        replacementNotes: replacementNotes,
        skipNotesSheet: skipNotesSheet,
      )),
    )) {
      return;
    }

    await nutritionGoals.ensureLoaded();

    // Ensure meal types are loaded
    await mealTypesProvider.ensureLoaded();

    final selectedMeal = _findCurrentMeal(mealType);
    final mealName = selectedMeal == null
        ? mealType
        : _getMealDisplayName(selectedMeal, l10n);
    final effectiveReplacementNotes = skipNotesSheet
        ? (replacementNotes ?? '')
        : await _showReplacementNotesSheet(
            title: l10n
                .translate('replace_meal_notes_title')
                .replaceAll('{meal}', mealName),
            description: l10n.translate('replace_meal_notes_description'),
            hintText: l10n.translate('replace_meal_notes_hint'),
            confirmLabel: l10n.translate('replace_meal_confirm'),
            initialValue: replacementNotes ?? '',
          );

    if (effectiveReplacementNotes == null) {
      return;
    }

    final locale = Localizations.localeOf(context);
    final languageCode =
        '${locale.languageCode}_${locale.countryCode ?? locale.languageCode.toUpperCase()}';
    final userId = authService.currentUser?.id.toString() ?? '';

    await dietProvider.replaceMeal(
      dietProvider.selectedDate,
      mealType,
      nutritionGoals,
      mealTypes: mealTypesProvider.mealTypes,
      userId: userId,
      languageCode: languageCode,
      replacementNotes: effectiveReplacementNotes,
    );

    if (dietProvider.error != null) {
      _handleDietActionError(
        dietProvider: dietProvider,
        l10n: l10n,
        onRewardEarned: () => unawaited(_replaceMeal(
          mealType,
          replacementNotes: effectiveReplacementNotes,
          skipNotesSheet: true,
        )),
      );
    }
  }

  // Replace all meals
  Future<void> _replaceAllMeals({
    String? replacementNotes,
    bool skipNotesSheet = false,
  }) async {
    final dietProvider = Provider.of<DietPlanProvider>(context, listen: false);
    final isWeeklyMode = dietProvider.dietMode == DietMode.weekly;
    final l10n = AppLocalizations.of(context);

    final nutritionGoals =
        Provider.of<NutritionGoalsProvider>(context, listen: false);
    final authService = Provider.of<AuthService>(context, listen: false);
    final mealTypesProvider =
        Provider.of<MealTypesProvider>(context, listen: false);

    if (!authService.isAuthenticated || authService.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.translate('login_required_for_diet'))),
      );
      return;
    }

    if (!dietProvider.isAuthenticated) {
      await dietProvider.setAuth(
        authService.token ?? '',
        authService.currentUser!.id,
      );
    }

    if (!await _ensureCreditsBeforeDietRequest(
      authService: authService,
      dietProvider: dietProvider,
      onRewardEarned: () => unawaited(_replaceAllMeals(
        replacementNotes: replacementNotes,
        skipNotesSheet: skipNotesSheet,
      )),
    )) {
      return;
    }

    await nutritionGoals.ensureLoaded();

    // Ensure meal types are loaded
    await mealTypesProvider.ensureLoaded();

    final effectiveReplacementNotes = skipNotesSheet
        ? (replacementNotes ?? '')
        : await _showReplacementNotesSheet(
            title: l10n.translate('replace_all_meals'),
            description: isWeeklyMode
                ? l10n.translate('replace_all_meals_weekly_notes_description')
                : l10n.translate('replace_all_meals_daily_notes_description'),
            hintText: l10n.translate('replace_all_meals_notes_hint'),
            confirmLabel: l10n.translate('yes_generate_new'),
            initialValue: replacementNotes ?? '',
          );

    if (effectiveReplacementNotes == null) {
      return;
    }

    final locale = Localizations.localeOf(context);
    final languageCode =
        '${locale.languageCode}_${locale.countryCode ?? locale.languageCode.toUpperCase()}';
    final userId = authService.currentUser?.id.toString() ?? '';

    await dietProvider.replaceAllMeals(
      dietProvider.selectedDate,
      nutritionGoals,
      mealTypes: mealTypesProvider.mealTypes,
      userId: userId,
      languageCode: languageCode,
      replacementNotes: effectiveReplacementNotes,
    );

    if (dietProvider.error != null) {
      _handleDietActionError(
        dietProvider: dietProvider,
        l10n: l10n,
        onRewardEarned: () => unawaited(_replaceAllMeals(
          replacementNotes: effectiveReplacementNotes,
          skipNotesSheet: true,
        )),
      );
    }
  }

  Future<void> _repeatDietToOtherDays() async {
    final dietProvider = Provider.of<DietPlanProvider>(context, listen: false);
    final authService = Provider.of<AuthService>(context, listen: false);
    final l10n = AppLocalizations.of(context);

    if (!authService.isAuthenticated || authService.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.translate('login_required_for_diet'))),
      );
      return;
    }

    if (!dietProvider.isAuthenticated) {
      await dietProvider.setAuth(
        authService.token ?? '',
        authService.currentUser!.id,
      );
    }

    final selectedDates = await _showRepeatDietDialog(dietProvider);
    if (!mounted || selectedDates == null || selectedDates.isEmpty) {
      return;
    }

    final copiedCount = await dietProvider.repeatDietPlanToDates(
      dietProvider.selectedDate,
      selectedDates,
    );

    if (!mounted) return;

    if (dietProvider.error != null) {
      if (dietProvider.error == 'daily_diet_premium_required') {
        _showPremiumRequiredDialog();
      } else {
        _showDietGenerationErrorSnackBar(dietProvider, l10n);
      }
      return;
    }

    if (copiedCount > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n
                .translate('repeat_diet_success')
                .replaceAll('{count}', copiedCount.toString()),
          ),
        ),
      );
    }
  }

  Future<List<DateTime>?> _showRepeatDietDialog(
    DietPlanProvider dietProvider,
  ) async {
    final l10n = AppLocalizations.of(context);
    final baseDate = DateUtils.dateOnly(dietProvider.selectedDate);
    final candidateDates = List.generate(
      14,
      (index) => baseDate.add(Duration(days: index + 1)),
    );
    final selectedKeys = <String>{};

    return showDialog<List<DateTime>>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(l10n.translate('repeat_diet_other_days')),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.translate('repeat_diet_select_days')),
                    const SizedBox(height: 12),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 360),
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: candidateDates.map((date) {
                            final dateKey = _formatDateKey(date);
                            final hasExistingPlan =
                                dietProvider.hasDietPlanForDate(date);

                            return CheckboxListTile(
                              value: selectedKeys.contains(dateKey),
                              contentPadding: EdgeInsets.zero,
                              controlAffinity: ListTileControlAffinity.leading,
                              title: Text(_formatRepeatDateLabel(date)),
                              subtitle: hasExistingPlan
                                  ? Text(
                                      l10n.translate(
                                        'repeat_diet_replace_existing',
                                      ),
                                    )
                                  : null,
                              onChanged: (selected) {
                                setDialogState(() {
                                  if (selected == true) {
                                    selectedKeys.add(dateKey);
                                  } else {
                                    selectedKeys.remove(dateKey);
                                  }
                                });
                              },
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text(l10n.translate('cancel')),
                ),
                ElevatedButton(
                  onPressed: selectedKeys.isEmpty
                      ? null
                      : () => Navigator.pop(
                            dialogContext,
                            candidateDates
                                .where(
                                  (date) => selectedKeys
                                      .contains(_formatDateKey(date)),
                                )
                                .toList(),
                          ),
                  child: Text(l10n.translate('repeat_diet_apply')),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _formatDateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  String _formatRepeatDateLabel(DateTime date) {
    final localeName = Localizations.localeOf(context).toString();
    final formatted = DateFormat('EEE, dd/MM', localeName).format(date);
    return toBeginningOfSentenceCase(formatted) ?? formatted;
  }

  String _getMealEmoji(String mealType) {
    try {
      final configuredEmoji =
          Provider.of<MealTypesProvider>(context, listen: false)
              .getMealTypeById(mealType)
              ?.emoji
              .trim();
      if (configuredEmoji != null && configuredEmoji.isNotEmpty) {
        return configuredEmoji;
      }
    } catch (_) {
      // Keep the static fallback for isolated widget tests.
    }

    switch (mealType) {
      case 'breakfast':
        return '🍳';
      case 'lunch':
        return '🍽️';
      case 'afternoon_snack':
      case 'snack':
        return '🍎';
      case 'dinner':
        return '🍝';
      case 'supper':
        return '🥛';
      default:
        return '🍴';
    }
  }

  String _getMealDisplayName(PlannedMeal meal, AppLocalizations l10n) {
    switch (meal.type) {
      case 'breakfast':
      case 'lunch':
      case 'dinner':
      case 'snack':
        return l10n.translate(meal.type);
      default:
        return meal.name;
    }
  }

  Food _convertPlannedFoodToFood(PlannedFood plannedFood) {
    final nutrient = Nutrient(
      idFood: 0,
      servingSize: plannedFood.amount,
      servingUnit: plannedFood.unit,
      calories: plannedFood.calories.toDouble(),
      protein: plannedFood.protein,
      carbohydrate: plannedFood.carbs,
      fat: plannedFood.fat,
    );

    return Food(
      name: plannedFood.name,
      emoji: plannedFood.emoji,
      amount: '${plannedFood.amount.toStringAsFixed(0)} ${plannedFood.unit}',
      nutrients: [nutrient],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor:
          isDarkMode ? AppTheme.darkBackgroundColor : AppTheme.backgroundColor,
      body: SafeArea(
        child: Consumer<DietPlanProvider>(
          builder: (context, dietProvider, _) {
            final isWeeklyMode = dietProvider.dietMode == DietMode.weekly;
            final isLoading = dietProvider.isLoading;
            final headerHeight = isWeeklyMode ? 56.0 : 112.0;
            final header = isWeeklyMode
                ? _buildWeeklyFixedHeader(isDarkMode, l10n)
                : WeeklyCalendar(
                    selectedDate: dietProvider.selectedDate,
                    onDaySelected: (date) {
                      _showHeader();
                      dietProvider.setSelectedDate(date);
                    },
                    showAppBar: true,
                    showCalendar: true,
                    onOpenDrawer: widget.onOpenDrawer,
                    onSearchPressed: widget.onSearchPressed,
                  );

            return Column(
              children: [
                // Header some ao rolar para baixo e reaparece ao rolar para cima;
                // os chips seguem fixos.
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  height: _isHeaderCollapsed ? 0 : headerHeight,
                  child: ClipRect(
                    child: OverflowBox(
                      minHeight: 0,
                      maxHeight: headerHeight,
                      alignment: Alignment.topCenter,
                      child: header,
                    ),
                  ),
                ),

                // Chips sempre visíveis
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: _buildDietModeSelector(dietProvider, isDarkMode),
                ),

                // Conteúdo principal
                Expanded(
                  child:
                      _buildContent(isDarkMode, l10n, dietProvider, isLoading),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildDietModeSelector(
      DietPlanProvider dietProvider, bool isDarkMode) {
    final isWeekly = dietProvider.dietMode == DietMode.weekly;
    final l10n = AppLocalizations.of(context);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildDietModeCard(
          label: l10n.translate('weekly_diet'),
          selected: isWeekly,
          isDarkMode: isDarkMode,
          onTap: () {
            if (!isWeekly) {
              _showHeader();
              dietProvider.setDietMode(DietMode.weekly);
            }
          },
        ),
        const SizedBox(width: 12),
        _buildDietModeCard(
          label: l10n.translate('daily_diet'),
          selected: !isWeekly,
          isDarkMode: isDarkMode,
          onTap: () {
            if (isWeekly) {
              _showHeader();
              dietProvider.setDietMode(DietMode.daily);
            }
          },
        ),
      ],
    );
  }

  Widget _buildDietModeCard({
    required String label,
    required bool selected,
    required bool isDarkMode,
    required VoidCallback onTap,
  }) {
    final selectedColor = AppTheme.selectedPillBackgroundColor(isDarkMode);
    final selectedTextColor = AppTheme.selectedPillTextColor(isDarkMode);
    final backgroundColor = isDarkMode ? AppTheme.darkCardColor : Colors.white;
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
        selectedColor: selectedColor,
        backgroundColor: backgroundColor,
        labelStyle: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: selected
              ? selectedTextColor
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
        disabledColor: backgroundColor,
        surfaceTintColor:
            isDarkMode ? AppTheme.darkComponentColor : AppTheme.surfaceColor,
      ),
    );
  }

  Widget _buildContent(bool isDarkMode, AppLocalizations l10n,
      DietPlanProvider dietProvider, bool isLoading) {
    // Carregamento incremental
    if (isLoading && dietProvider.partialDietPlan != null) {
      return _buildLoadingWithPartialPlan(isDarkMode, l10n, dietProvider);
    }

    // Carregamento simples
    if (isLoading) {
      return _buildSimpleLoading(l10n);
    }

    final dietPlan = dietProvider.currentDietPlan;

    // Sem dieta - mostrar estado vazio
    if (dietPlan == null) {
      return _buildEmptyState(isDarkMode, l10n, dietProvider);
    }

    // Com dieta - mostrar conteúdo
    return _buildDietContent(isDarkMode, l10n, dietProvider, dietPlan);
  }

  Widget _buildSimpleLoading(AppLocalizations l10n) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(l10n.translate('generating_diet_plan')),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              l10n.translate('diet_generation_background_hint'),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingWithPartialPlan(
      bool isDarkMode, AppLocalizations l10n, DietPlanProvider dietProvider) {
    final partialPlan = dietProvider.partialDietPlan!;
    final loadedMealsCount = partialPlan.meals.length;
    final expectedMealsCount = dietProvider.expectedMealsCount;

    return Column(
      children: [
        // Macros parciais
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _buildMacroCards(partialPlan.totalNutrition, isDarkMode),
        ),
        const SizedBox(height: 12),

        // Progress indicator
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 12),
              Text(
                '${l10n.translate('generating_meals')} ($loadedMealsCount/$expectedMealsCount)',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Lista de refeições com skeletons
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(16, 2, 16, 16),
            itemCount: expectedMealsCount,
            itemBuilder: (context, index) {
              if (index < loadedMealsCount) {
                final meal = partialPlan.meals[index];
                return _buildMealCard(meal, isDarkMode);
              } else {
                return const MealSkeleton();
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(
      bool isDarkMode, AppLocalizations l10n, DietPlanProvider dietProvider) {
    final isWeeklyMode = dietProvider.dietMode == DietMode.weekly;
    final buttonColor =
        isDarkMode ? AppTheme.primaryColorDarkMode : AppTheme.primaryColor;
    return DietStyleMessageState(
      title: isWeeklyMode
          ? l10n.translate('no_weekly_diet')
          : l10n.translate('no_daily_diet'),
      message: isWeeklyMode
          ? l10n.translate('no_weekly_diet_description')
          : l10n.translate('no_daily_diet_description'),
      fallbackIcon: Icons.restaurant_menu,
      primaryActionLabel: l10n.translate('generate_diet_ai'),
      primaryActionIcon: Icons.auto_awesome,
      onPrimaryAction: _generateDietPlan,
      topSpacing: 40,
      accentColor: buttonColor,
      pinActionsToBottom: false,
    );
  }

  Widget _buildDietContent(bool isDarkMode, AppLocalizations l10n,
      DietPlanProvider dietProvider, DietPlan dietPlan) {
    final goalsProvider = Provider.of<NutritionGoalsProvider>(context);
    final mealTypesProvider = Provider.of<MealTypesProvider>(context);
    final currentTargets = DailyNutrition(
      calories: goalsProvider.caloriesGoal,
      protein: goalsProvider.proteinGoal.toDouble(),
      carbs: goalsProvider.carbsGoal.toDouble(),
      fat: goalsProvider.fatGoal.toDouble(),
    );
    final isDietOutdatedForTargets = dietPlan.isOutdatedFor(currentTargets);
    final isDietOutdatedForMealTypes =
        _isDietOutdatedForMealTypes(dietPlan, mealTypesProvider);
    final isDietOutdated =
        isDietOutdatedForTargets || isDietOutdatedForMealTypes;
    final textColor =
        isDarkMode ? AppTheme.darkTextColor : AppTheme.textPrimaryColor;
    final secondaryTextColor =
        isDarkMode ? const Color(0xFFAEB7CE) : AppTheme.textSecondaryColor;
    final isWeeklyMode = dietProvider.dietMode == DietMode.weekly;
    final accentColor = Theme.of(context).colorScheme.primary;

    return SingleChildScrollView(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cards de macros nutricionais
          _buildMacroCards(dietPlan.totalNutrition, isDarkMode),
          const SizedBox(height: 12),
          if (isDietOutdated) ...[
            _buildOutdatedDietNotice(
              isDarkMode: isDarkMode,
              l10n: l10n,
              descriptionKey: isDietOutdatedForMealTypes
                  ? 'diet_outdated_meal_types_description'
                  : 'diet_outdated_description',
            ),
            const SizedBox(height: 12),
          ],

          // Título da seção de refeições + ações alinhadas
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  l10n.translate('meals'),
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
              ),
              if (dietPlan.meals.isNotEmpty) ...[
                if (!isWeeklyMode)
                  TextButton.icon(
                    onPressed: _repeatDietToOtherDays,
                    icon: Icon(
                      Icons.repeat,
                      size: 18,
                      color: accentColor,
                    ),
                    label: Text(
                      l10n.translate('repeat_diet_other_days'),
                      style: TextStyle(color: accentColor),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: const Size(0, 36),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                TextButton.icon(
                  onPressed: _replaceAllMeals,
                  icon: Icon(Icons.refresh, size: 18, color: accentColor),
                  label: Text(
                    l10n.translate('replace_all'),
                    style: TextStyle(color: accentColor),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 36),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),

          // Lista de refeições
          if (dietPlan.meals.isEmpty)
            _buildEmptyMealsCard(
                isDarkMode, l10n, textColor, secondaryTextColor)
          else
            ...dietPlan.meals.map((meal) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildMealCardStyled(
                      meal, isDarkMode, textColor, secondaryTextColor),
                )),

          if (dietPlan.meals.isNotEmpty) ...[
            const SizedBox(height: 4),
            _buildShareDietPdfButton(isDarkMode, l10n, dietPlan),
          ],

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildShareDietPdfButton(
    bool isDarkMode,
    AppLocalizations l10n,
    DietPlan dietPlan,
  ) {
    final backgroundColor = isDarkMode ? Colors.white : AppTheme.primaryColor;
    final foregroundColor = isDarkMode ? Colors.black : Colors.white;

    return SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton.icon(
        onPressed: _isSharingDietPdf ? null : () => _shareDietPlan(dietPlan),
        icon: _isSharingDietPdf
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: foregroundColor,
                ),
              )
            : const Icon(Icons.picture_as_pdf_outlined, size: 20),
        label: Text(
          l10n.translate('share_diet_pdf'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          disabledBackgroundColor: backgroundColor.withValues(alpha: 0.62),
          disabledForegroundColor: foregroundColor.withValues(alpha: 0.85),
          side: BorderSide(
            color: isDarkMode
                ? Colors.white.withValues(alpha: 0.28)
                : Colors.black.withValues(alpha: 0.08),
            width: 1,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  bool _isDietOutdatedForMealTypes(
    DietPlan dietPlan,
    MealTypesProvider mealTypesProvider,
  ) {
    if (!mealTypesProvider.isLoaded) {
      return false;
    }

    final configuredTypeIds = mealTypesProvider.mealTypes
        .map((mealType) => mealType.id.trim())
        .where((id) => id.isNotEmpty)
        .toSet();

    if (configuredTypeIds.isEmpty) {
      return false;
    }

    final planTypeIds = dietPlan.meals
        .map((meal) => meal.type.trim())
        .where((id) => id.isNotEmpty)
        .toSet();

    if (dietPlan.meals.length != configuredTypeIds.length ||
        planTypeIds.length != configuredTypeIds.length) {
      return true;
    }

    return configuredTypeIds.any((typeId) => !planTypeIds.contains(typeId)) ||
        planTypeIds.any((typeId) => !configuredTypeIds.contains(typeId));
  }

  String _buildGenerationErrorMessage(
    AppLocalizations l10n,
    DietPlanProvider dietProvider,
  ) {
    final rawError = dietProvider.error?.trim();
    if (_isInsufficientCreditsError(rawError)) {
      return l10n.translate('chat_credit_exhausted_inline');
    }
    if (_isTextGenerationTimeoutError(rawError)) {
      return l10n.translate('diet_generation_timeout_message');
    }
    if (_isInternalTextGenerationError(rawError)) {
      return l10n.translate('diet_generation_server_error_message');
    }
    if (rawError == null ||
        rawError.isEmpty ||
        rawError == l10n.translate('diet_generation_error')) {
      return l10n.translate('try_again_or_check_connection');
    }
    return _extractReadableDietError(rawError);
  }

  Future<void> _shareDietPlan(DietPlan dietPlan) async {
    if (_isSharingDietPdf) {
      return;
    }

    final l10n = AppLocalizations.of(context);
    final dietProvider = Provider.of<DietPlanProvider>(context, listen: false);
    final goalsProvider =
        Provider.of<NutritionGoalsProvider>(context, listen: false);
    final isWeeklyMode = dietProvider.dietMode == DietMode.weekly;
    final title = isWeeklyMode
        ? l10n.translate('professional_weekly_diet_plan')
        : l10n.translate('professional_daily_diet_plan');
    final periodLabel = isWeeklyMode
        ? l10n.translate('weekly_diet')
        : DateFormat('dd/MM/yyyy').format(dietProvider.selectedDate);
    final targetNutrition = dietPlan.generatedForNutrition ??
        DailyNutrition(
          calories: goalsProvider.caloriesGoal,
          protein: goalsProvider.proteinGoal.toDouble(),
          carbs: goalsProvider.carbsGoal.toDouble(),
          fat: goalsProvider.fatGoal.toDouble(),
        );
    final labels = DietPdfLabels(
      appName: 'Nutro AI',
      generatedBy: l10n.translate('diet_pdf_generated_by'),
      shareText: l10n.translate('diet_pdf_share_text'),
      planFor: l10n.translate('diet_pdf_plan_for'),
      objective: l10n.translate('objective'),
      dietStyle: l10n.translate('diet_pdf_diet_style'),
      targetMacros: l10n.translate('diet_pdf_target_macros'),
      dailyMacros: l10n.translate('daily_macros'),
      meals: l10n.translate('meals'),
      food: l10n.translate('diet_pdf_food'),
      calories: l10n.translate('calories'),
      protein: l10n.translate('protein'),
      carbs: l10n.translate('carbs'),
      fat: l10n.translate('fat'),
      portion: l10n.translate('diet_pdf_portion'),
      nutrition: l10n.translate('diet_pdf_nutrition'),
      page: l10n.translate('diet_pdf_page'),
      tagline: l10n.translate('diet_pdf_tagline'),
      nutritionSummary: l10n.translate('diet_pdf_nutrition_summary'),
      macroDistribution: l10n.translate('diet_pdf_macro_distribution'),
      perDay: l10n.translate('diet_pdf_per_day'),
      totalPlan: l10n.translate('diet_pdf_total_plan'),
    );

    setState(() {
      _isSharingDietPdf = true;
    });

    try {
      await DietPdfShareService.shareDietPlanPdf(
        dietPlan: dietPlan,
        title: title,
        periodLabel: periodLabel,
        objective: goalsProvider.getFitnessGoalName(
          goalsProvider.fitnessGoal,
          context,
        ),
        dietStyle: goalsProvider.getDietTypeName(
          goalsProvider.dietType,
          context,
        ),
        targetNutrition: targetNutrition,
        labels: labels,
        generatedAt: DateTime.now(),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.translate('diet_pdf_share_error')),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSharingDietPdf = false;
        });
      }
    }
  }

  Widget _buildOutdatedDietNotice({
    required bool isDarkMode,
    required AppLocalizations l10n,
    required String descriptionKey,
  }) {
    final accentColor =
        isDarkMode ? const Color(0xFFFFC46B) : const Color(0xFFC87500);
    final titleColor =
        isDarkMode ? AppTheme.darkTextColor : AppTheme.textPrimaryColor;
    final bodyColor =
        isDarkMode ? const Color(0xFFAEB7CE) : AppTheme.textSecondaryColor;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: AppTheme.profileCardDecoration(isDarkMode),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.refresh_rounded,
                  color: accentColor,
                  size: 17,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.translate('diet_outdated_title'),
                      style: GoogleFonts.inter(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: titleColor,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      l10n.translate(descriptionKey),
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        height: 1.3,
                        color: bodyColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 38,
            child: OutlinedButton.icon(
              onPressed: _replaceAllMeals,
              icon: const Icon(Icons.refresh, size: 18),
              label: Text(l10n.translate('diet_outdated_generate_new')),
              style: OutlinedButton.styleFrom(
                foregroundColor: accentColor,
                visualDensity: VisualDensity.compact,
                side: BorderSide(color: accentColor.withValues(alpha: 0.45)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMacroCards(DailyNutrition nutrition, bool isDarkMode) {
    final secondaryColor =
        isDarkMode ? const Color(0xFFAEB7CE) : AppTheme.textSecondaryColor;

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
                    nutrition.calories.toString(),
                    'kcal',
                    MacroTheme.caloriesColor,
                    secondaryColor),
              ),
              _buildMacroDivider(isDarkMode),
              Expanded(
                child: _buildMacroStat(
                    MacroTheme.proteinIcon,
                    '${nutrition.protein.toStringAsFixed(0)}g',
                    'Proteína',
                    MacroTheme.proteinColor,
                    secondaryColor),
              ),
              _buildMacroDivider(isDarkMode),
              Expanded(
                child: _buildMacroStat(
                    MacroTheme.carbsIcon,
                    '${nutrition.carbs.toStringAsFixed(0)}g',
                    'Carboidrato',
                    MacroTheme.carbsColor,
                    secondaryColor),
              ),
              _buildMacroDivider(isDarkMode),
              Expanded(
                child: _buildMacroStat(
                    MacroTheme.fatIcon,
                    '${nutrition.fat.toStringAsFixed(0)}g',
                    'Gordura',
                    MacroTheme.fatColor,
                    secondaryColor),
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
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        Text(
          unit,
          style: GoogleFonts.inter(
            fontSize: 10,
            color: secondaryColor,
          ),
        ),
      ],
    );
  }

  Widget _buildMacroDivider(bool isDarkMode) {
    return VerticalDivider(
      color: isDarkMode
          ? Colors.white.withValues(alpha: 0.08)
          : Colors.black.withValues(alpha: 0.08),
      width: 1,
      thickness: 1,
      indent: 4,
      endIndent: 4,
    );
  }

  Widget _buildMacroCardCompact({
    required IconData icon,
    required String value,
    required String unit,
    required Color color,
    required bool isDarkMode,
    bool isSmall = false,
  }) {
    final secondaryColor =
        isDarkMode ? const Color(0xFFAEB7CE) : AppTheme.textSecondaryColor;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        MacroTheme.iconBadge(
          icon: icon,
          color: color,
          isDarkMode: isDarkMode,
          size: isSmall ? 22 : 26,
          iconSize: isSmall ? 13 : 15,
        ),
        SizedBox(height: isSmall ? 3 : 4),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: isSmall ? 13 : 15,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        Text(
          unit,
          style: GoogleFonts.inter(
            fontSize: isSmall ? 9.5 : 10,
            color: secondaryColor,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyMealsCard(bool isDarkMode, AppLocalizations l10n,
      Color textColor, Color secondaryTextColor) {
    return Container(
      decoration: AppTheme.profileCardDecoration(isDarkMode),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(
              Icons.restaurant_outlined,
              size: 48,
              color: secondaryTextColor.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.translate('no_meals_yet'),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: textColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              l10n.translate('add_meals_description'),
              style: TextStyle(
                fontSize: 13,
                color: secondaryTextColor,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _toggleMealExpansion(PlannedMeal meal) {
    if (meal.foods.isEmpty) return;

    setState(() {
      if (_expandedMeals.contains(meal.type)) {
        _expandedMeals.remove(meal.type);
      } else {
        _expandedMeals.add(meal.type);
      }
    });
  }

  Widget _buildMealCardStyled(PlannedMeal meal, bool isDarkMode,
      Color textColor, Color secondaryTextColor) {
    final hasFoods = meal.foods.isNotEmpty;
    final isExpanded = _expandedMeals.contains(meal.type);
    final l10n = AppLocalizations.of(context);
    final cardBorderRadius = BorderRadius.circular(24);

    return Container(
      decoration: AppTheme.profileCardDecoration(isDarkMode),
      child: Material(
        color: Colors.transparent,
        borderRadius: cardBorderRadius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: hasFoods ? () => _toggleMealExpansion(meal) : null,
          borderRadius: cardBorderRadius,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
                child: Row(
                  children: [
                    Text(
                      _getMealEmoji(meal.type),
                      style: const TextStyle(fontSize: 26),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _getMealDisplayName(meal, l10n),
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: textColor,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            hasFoods
                                ? '${meal.foods.length} ${meal.foods.length == 1 ? 'item' : 'itens'} • ${meal.mealTotals.calories.toStringAsFixed(0)} kcal'
                                : meal.time,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: secondaryTextColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (hasFoods)
                      IconButton(
                        onPressed: () => _toggleMealExpansion(meal),
                        icon: AnimatedRotation(
                          turns: isExpanded ? 0.5 : 0,
                          duration: const Duration(milliseconds: 200),
                          child: Icon(
                            Icons.keyboard_arrow_down,
                            size: 24,
                            color: secondaryTextColor.withValues(alpha: 0.7),
                          ),
                        ),
                      ),
                    IconButton(
                      onPressed: () => _replaceMeal(meal.type),
                      icon: Icon(
                        Icons.refresh,
                        size: 20,
                        color: secondaryTextColor.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
              AnimatedCrossFade(
                firstChild: const SizedBox.shrink(),
                secondChild: hasFoods
                    ? _buildExpandedFoodList(
                        meal, isDarkMode, textColor, secondaryTextColor)
                    : const SizedBox.shrink(),
                crossFadeState: isExpanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 200),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExpandedFoodList(PlannedMeal meal, bool isDarkMode,
      Color textColor, Color secondaryTextColor) {
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          height: 1,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.transparent,
                (isDarkMode ? Colors.white : Colors.black)
                    .withValues(alpha: 0.08),
                Colors.transparent,
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Column(
            children: meal.foods
                .map((food) => _buildFoodItemStyled(
                    food, isDarkMode, textColor, secondaryTextColor))
                .toList(),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMacroCardCompact(
                icon: MacroTheme.caloriesIcon,
                value: meal.mealTotals.calories.toStringAsFixed(0),
                unit: 'kcal',
                color: MacroTheme.caloriesColor,
                isDarkMode: isDarkMode,
                isSmall: true,
              ),
              _buildMacroDivider(isDarkMode),
              _buildMacroCardCompact(
                icon: MacroTheme.proteinIcon,
                value: meal.mealTotals.protein.toStringAsFixed(1),
                unit: 'g prot',
                color: MacroTheme.proteinColor,
                isDarkMode: isDarkMode,
                isSmall: true,
              ),
              _buildMacroDivider(isDarkMode),
              _buildMacroCardCompact(
                icon: MacroTheme.carbsIcon,
                value: meal.mealTotals.carbs.toStringAsFixed(1),
                unit: 'g carb',
                color: MacroTheme.carbsColor,
                isDarkMode: isDarkMode,
                isSmall: true,
              ),
              _buildMacroDivider(isDarkMode),
              _buildMacroCardCompact(
                icon: MacroTheme.fatIcon,
                value: meal.mealTotals.fat.toStringAsFixed(1),
                unit: 'g gord',
                color: MacroTheme.fatColor,
                isDarkMode: isDarkMode,
                isSmall: true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFoodItemStyled(PlannedFood food, bool isDarkMode,
      Color textColor, Color secondaryTextColor) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  FoodPage(food: _convertPlannedFoodToFood(food)),
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
                      '${food.amount.toStringAsFixed(0)} ${food.unit}',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: secondaryTextColor.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 40),
              SizedBox(
                width: 64,
                child: Text(
                  '${food.calories} kcal',
                  textAlign: TextAlign.right,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: textColor.withValues(alpha: 0.7),
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMealCard(PlannedMeal meal, bool isDarkMode) {
    final secondaryTextColor =
        isDarkMode ? const Color(0xFFAEB7CE) : AppTheme.textSecondaryColor;
    final l10n = AppLocalizations.of(context);
    final cardBorderRadius = BorderRadius.circular(24);
    final expansionShape = RoundedRectangleBorder(
      borderRadius: cardBorderRadius,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: AppTheme.profileCardDecoration(isDarkMode),
      child: Material(
        color: Colors.transparent,
        borderRadius: cardBorderRadius,
        clipBehavior: Clip.antiAlias,
        child: ExpansionTile(
          shape: expansionShape,
          collapsedShape: expansionShape,
          tilePadding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
          childrenPadding: EdgeInsets.zero,
          leading: Text(
            _getMealEmoji(meal.type),
            style: const TextStyle(fontSize: 26),
          ),
          title: Text(
            _getMealDisplayName(meal, l10n),
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w600,
              fontSize: 16,
              letterSpacing: -0.2,
              color: (isDarkMode
                      ? AppTheme.darkTextColor
                      : AppTheme.textPrimaryColor)
                  .withValues(alpha: 0.85),
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              '${meal.time} • ${meal.mealTotals.calories} kcal',
              style: GoogleFonts.inter(
                color: secondaryTextColor.withValues(alpha: 0.7),
                fontSize: 13,
              ),
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _replaceMeal(meal.type),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    child: Icon(
                      Icons.autorenew,
                      size: 18,
                      color: secondaryTextColor.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
            ],
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...meal.foods.map((food) => _buildFoodItem(food, isDarkMode)),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Container(
                      height: 1,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            (isDarkMode ? Colors.white : Colors.black)
                                .withValues(alpha: 0.05),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildMacroCardCompact(
                        icon: MacroTheme.caloriesIcon,
                        value: meal.mealTotals.calories.toStringAsFixed(0),
                        unit: 'kcal',
                        color: MacroTheme.caloriesColor,
                        isDarkMode: isDarkMode,
                        isSmall: true,
                      ),
                      _buildMacroDivider(isDarkMode),
                      _buildMacroCardCompact(
                        icon: MacroTheme.proteinIcon,
                        value: meal.mealTotals.protein.toStringAsFixed(1),
                        unit: 'g prot',
                        color: MacroTheme.proteinColor,
                        isDarkMode: isDarkMode,
                        isSmall: true,
                      ),
                      _buildMacroDivider(isDarkMode),
                      _buildMacroCardCompact(
                        icon: MacroTheme.carbsIcon,
                        value: meal.mealTotals.carbs.toStringAsFixed(1),
                        unit: 'g carb',
                        color: MacroTheme.carbsColor,
                        isDarkMode: isDarkMode,
                        isSmall: true,
                      ),
                      _buildMacroDivider(isDarkMode),
                      _buildMacroCardCompact(
                        icon: MacroTheme.fatIcon,
                        value: meal.mealTotals.fat.toStringAsFixed(1),
                        unit: 'g gord',
                        color: MacroTheme.fatColor,
                        isDarkMode: isDarkMode,
                        isSmall: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFoodItem(PlannedFood food, bool isDarkMode) {
    final textColor =
        isDarkMode ? AppTheme.darkTextColor : AppTheme.textPrimaryColor;
    final secondaryTextColor =
        isDarkMode ? const Color(0xFFAEB7CE) : AppTheme.textSecondaryColor;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  FoodPage(food: _convertPlannedFoodToFood(food)),
            ),
          );
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                child: FoodIcon(name: food.name, emoji: food.emoji, size: 28),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      food.name,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: textColor.withValues(alpha: 0.85),
                        height: 1.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 1),
                    Text(
                      '${food.amount.toStringAsFixed(0)} ${food.unit}',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: secondaryTextColor.withValues(alpha: 0.75),
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  Text(
                    '${food.calories}',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: textColor.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(width: 1),
                  Text(
                    'kcal',
                    style: GoogleFonts.inter(
                      fontSize: 8,
                      fontWeight: FontWeight.w500,
                      color: textColor.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
