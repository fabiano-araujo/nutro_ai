import 'package:flutter/material.dart';

import '../i18n/app_localizations_extension.dart';
import '../theme/app_theme.dart';

enum GuestLocalDataKind {
  goals,
  meals,
  chats,
  foods,
  preferences,
}

class GuestLocalDataPrompt extends StatelessWidget {
  final List<GuestLocalDataKind> kinds;
  final bool isResolving;
  final bool isWide;
  final VoidCallback onSave;
  final VoidCallback onDiscard;

  const GuestLocalDataPrompt({
    super.key,
    required this.kinds,
    required this.isResolving,
    required this.isWide,
    required this.onSave,
    required this.onDiscard,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final media = MediaQuery.of(context);
    final maxSheetWidth = isWide ? 440.0 : 560.0;
    final sheetColor = isDarkMode ? AppTheme.darkCardColor : Colors.white;
    final radius = isWide
        ? BorderRadius.circular(28)
        : const BorderRadius.vertical(top: Radius.circular(28));

    return Positioned.fill(
      child: Material(
        color: Colors.transparent,
        child: Stack(
          children: [
            ModalBarrier(
              dismissible: false,
              color: Colors.black.withValues(alpha: isDarkMode ? 0.62 : 0.48),
            ),
            Align(
              alignment: isWide ? Alignment.center : Alignment.bottomCenter,
              child: Padding(
                padding: isWide
                    ? const EdgeInsets.symmetric(horizontal: 24)
                    : EdgeInsets.zero,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: maxSheetWidth,
                    maxHeight: media.size.height * (isWide ? 0.82 : 0.88),
                  ),
                  child: SizedBox(
                    width: isWide ? 440 : media.size.width,
                    child: Material(
                      color: sheetColor,
                      elevation: 18,
                      shadowColor: Colors.black.withValues(alpha: 0.28),
                      borderRadius: radius,
                      clipBehavior: Clip.antiAlias,
                      child: SafeArea(
                        top: false,
                        child: SingleChildScrollView(
                          padding: EdgeInsets.fromLTRB(
                            22,
                            isWide ? 28 : 10,
                            22,
                            18,
                          ),
                          child: _GuestLocalDataPromptBody(
                            kinds: kinds,
                            isResolving: isResolving,
                            isDarkMode: isDarkMode,
                            showHandle: !isWide,
                            onSave: onSave,
                            onDiscard: onDiscard,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GuestLocalDataPromptBody extends StatelessWidget {
  final List<GuestLocalDataKind> kinds;
  final bool isResolving;
  final bool isDarkMode;
  final bool showHandle;
  final VoidCallback onSave;
  final VoidCallback onDiscard;

  const _GuestLocalDataPromptBody({
    required this.kinds,
    required this.isResolving,
    required this.isDarkMode,
    required this.showHandle,
    required this.onSave,
    required this.onDiscard,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final titleColor =
        isDarkMode ? AppTheme.darkTextColor : AppTheme.textPrimaryColor;
    final bodyColor =
        isDarkMode ? AppTheme.darkMutedTextColor : AppTheme.textSecondaryColor;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showHandle) ...[
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: isDarkMode ? Colors.white24 : const Color(0xFFD7DEE6),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
        Center(child: _buildHero()),
        const SizedBox(height: 18),
        Text(
          context.tr.translate('guest_local_data_title'),
          textAlign: TextAlign.center,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            fontSize: 22,
            height: 1.2,
            color: titleColor,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          context.tr.translate('guest_local_data_message'),
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: bodyColor,
            height: 1.45,
            fontSize: 15,
          ),
        ),
        if (kinds.isNotEmpty) ...[
          const SizedBox(height: 22),
          Text(
            context.tr.translate('guest_local_data_items_label'),
            textAlign: TextAlign.center,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: titleColor.withValues(alpha: 0.78),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: kinds
                .map(
                    (kind) => _DataKindChip(kind: kind, isDarkMode: isDarkMode))
                .toList(),
          ),
        ],
        const SizedBox(height: 26),
        SizedBox(
          height: 54,
          child: FilledButton(
            onPressed: isResolving ? null : onSave,
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              disabledBackgroundColor:
                  AppTheme.primaryColor.withValues(alpha: 0.55),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            child: isResolving
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: Colors.white,
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.check_rounded, size: 22),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          context.tr.translate('guest_local_data_save_action'),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 6),
        TextButton(
          onPressed: isResolving ? null : onDiscard,
          style: TextButton.styleFrom(
            foregroundColor: colorScheme.onSurfaceVariant,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
          child: Text(
            context.tr.translate('guest_local_data_discard_action'),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHero() {
    final accent =
        isDarkMode ? AppTheme.primaryColorDarkMode : AppTheme.primaryDarkColor;

    return SizedBox(
      width: 96,
      height: 96,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDarkMode
                    ? [
                        AppTheme.primaryColorDarkMode.withValues(alpha: 0.28),
                        AppTheme.primaryColor.withValues(alpha: 0.10),
                      ]
                    : const [
                        Color(0xFFD7F3F0),
                        Color(0xFFEEF8F6),
                      ],
              ),
            ),
          ),
          Icon(
            Icons.smartphone_rounded,
            size: 42,
            color: accent,
          ),
          Positioned(
            right: 14,
            top: 16,
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryColor.withValues(alpha: 0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.cloud_upload_rounded,
                color: Colors.white,
                size: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DataKindChip extends StatelessWidget {
  final GuestLocalDataKind kind;
  final bool isDarkMode;

  const _DataKindChip({
    required this.kind,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    final style = _styleFor(kind);
    final background = isDarkMode
        ? style.accent.withValues(alpha: 0.16)
        : style.accent.withValues(alpha: 0.12);
    final foreground = isDarkMode ? style.accent : style.darkAccent;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(style.icon, size: 15, color: foreground),
          const SizedBox(width: 6),
          Text(
            context.tr.translate(style.labelKey),
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: foreground,
            ),
          ),
        ],
      ),
    );
  }

  _KindChipStyle _styleFor(GuestLocalDataKind kind) {
    switch (kind) {
      case GuestLocalDataKind.goals:
        return const _KindChipStyle(
          icon: Icons.flag_rounded,
          labelKey: 'guest_local_data_summary_goals',
          accent: Color(0xFF26B5AD),
          darkAccent: Color(0xFF168B82),
        );
      case GuestLocalDataKind.meals:
        return const _KindChipStyle(
          icon: Icons.restaurant_rounded,
          labelKey: 'guest_local_data_summary_meals',
          accent: Color(0xFFEE8B60),
          darkAccent: Color(0xFFC96A42),
        );
      case GuestLocalDataKind.chats:
        return const _KindChipStyle(
          icon: Icons.chat_bubble_rounded,
          labelKey: 'guest_local_data_summary_chats',
          accent: Color(0xFF8B7CF6),
          darkAccent: Color(0xFF5B4EC4),
        );
      case GuestLocalDataKind.foods:
        return const _KindChipStyle(
          icon: Icons.eco_rounded,
          labelKey: 'guest_local_data_summary_foods',
          accent: Color(0xFF5DBB63),
          darkAccent: Color(0xFF2F8A46),
        );
      case GuestLocalDataKind.preferences:
        return const _KindChipStyle(
          icon: Icons.tune_rounded,
          labelKey: 'guest_local_data_summary_preferences',
          accent: Color(0xFF7A8499),
          darkAccent: Color(0xFF4E586C),
        );
    }
  }
}

class _KindChipStyle {
  final IconData icon;
  final String labelKey;
  final Color accent;
  final Color darkAccent;

  const _KindChipStyle({
    required this.icon,
    required this.labelKey,
    required this.accent,
    required this.darkAccent,
  });
}
