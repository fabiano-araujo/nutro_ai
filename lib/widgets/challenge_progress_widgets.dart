import 'package:flutter/material.dart';

import '../i18n/app_localizations_extension.dart';
import '../services/challenge_service.dart';
import '../theme/app_theme.dart';

class ChallengeProgressPanel extends StatelessWidget {
  final Challenge challenge;
  final bool compact;

  const ChallengeProgressPanel({
    super.key,
    required this.challenge,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final progress = challenge.progress;
    final objective = challenge.objective;
    if (progress == null || objective == null) {
      return const SizedBox.shrink();
    }

    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDarkMode
        ? Colors.white.withValues(alpha: 0.08)
        : AppTheme.dividerColor.withValues(alpha: 0.6);

    return Container(
      padding: EdgeInsets.all(compact ? 12 : 16),
      decoration: BoxDecoration(
        color: isDarkMode ? AppTheme.darkComponentColor : AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(compact ? 14 : 16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr.translate('challenge_objective_label'),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                        color: isDarkMode
                            ? Colors.white54
                            : AppTheme.textSecondaryColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      objective.label.isNotEmpty
                          ? objective.label
                          : challenge.typeFormatted,
                      style: TextStyle(
                        fontSize: compact ? 13 : 14,
                        fontWeight: FontWeight.w600,
                        color: isDarkMode
                            ? Colors.white
                            : AppTheme.textPrimaryColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _ChallengeStatusChip(challenge: challenge),
            ],
          ),
          SizedBox(height: compact ? 12 : 16),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${progress.completedDays}/${progress.targetDays} ${context.tr.translate('challenge_days_completed')}',
                  style: TextStyle(
                    fontSize: compact ? 12 : 13,
                    fontWeight: FontWeight.w600,
                    color: isDarkMode
                        ? Colors.white70
                        : AppTheme.textPrimaryColor,
                  ),
                ),
              ),
              Text(
                '${progress.percent.toStringAsFixed(progress.percent % 1 == 0 ? 0 : 1)}%',
                style: TextStyle(
                  fontSize: compact ? 12 : 13,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: compact ? 8 : 10,
              value: (progress.percent / 100).clamp(0, 1),
              backgroundColor: isDarkMode
                  ? Colors.white12
                  : AppTheme.dividerColor.withValues(alpha: 0.5),
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).primaryColor,
              ),
            ),
          ),
          SizedBox(height: compact ? 12 : 16),
          Row(
            children: [
              Expanded(
                child: _MetricPill(
                  label: context.tr.translate('challenge_today_metric'),
                  value: _formatCurrentMetric(progress),
                  compact: compact,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetricPill(
                  label: context.tr.translate('challenge_target_metric'),
                  value: _formatTargetMetric(
                    context,
                    challenge,
                    objective,
                    progress,
                  ),
                  compact: compact,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatCurrentMetric(ChallengeProgress progress) {
    switch (challenge.type.toUpperCase()) {
      case 'LOGGING_STREAK':
        return '${progress.currentValue.toInt()}/1';
      case 'PROTEIN_TARGET':
      case 'FIBER_TARGET':
        return '${_formatNumber(progress.currentValue)} g';
      case 'CALORIE_DEFICIT':
        return '${_formatNumber(progress.currentValue)} kcal';
      default:
        return _formatNumber(progress.currentValue);
    }
  }

  String _formatTargetMetric(
    BuildContext context,
    Challenge challenge,
    ChallengeObjective objective,
    ChallengeProgress progress,
  ) {
    switch (challenge.type.toUpperCase()) {
      case 'LOGGING_STREAK':
        return '${objective.targetDays} ${context.tr.translate('challenge_days_completed')}';
      case 'PROTEIN_TARGET':
      case 'FIBER_TARGET':
        return '${_formatNumber(progress.targetValue)} g';
      case 'CALORIE_DEFICIT':
        return '${_formatNumber(progress.targetValue)} kcal';
      default:
        return _formatNumber(progress.targetValue);
    }
  }

  String _formatNumber(double value) {
    if (value % 1 == 0) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(1);
  }
}

class _ChallengeStatusChip extends StatelessWidget {
  final Challenge challenge;

  const _ChallengeStatusChip({required this.challenge});

  @override
  Widget build(BuildContext context) {
    final progress = challenge.progress;
    final isParticipant = challenge.myParticipation != null;

    late final String label;
    late final Color backgroundColor;
    late final Color foregroundColor;

    if (!isParticipant) {
      label = context.tr.translate('challenge_join_to_track');
      backgroundColor = Colors.blue.withValues(alpha: 0.12);
      foregroundColor = Colors.blue;
    } else if (progress?.canCheckInToday == true) {
      label = context.tr.translate('challenge_checkin_available');
      backgroundColor = Colors.green.withValues(alpha: 0.12);
      foregroundColor = Colors.green;
    } else if ((progress?.currentValue ?? 0) > 0) {
      label = context.tr.translate('challenge_updated_today');
      backgroundColor = Colors.orange.withValues(alpha: 0.12);
      foregroundColor = Colors.orange.shade800;
    } else {
      label = context.tr.translate('challenge_waiting_today');
      backgroundColor = Colors.grey.withValues(alpha: 0.14);
      foregroundColor = Colors.grey.shade700;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: foregroundColor,
        ),
      ),
    );
  }
}

class _MetricPill extends StatelessWidget {
  final String label;
  final String value;
  final bool compact;

  const _MetricPill({
    required this.label,
    required this.value,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 12,
        vertical: compact ? 10 : 12,
      ),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.white10 : Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: compact ? 10 : 11,
              color: isDarkMode
                  ? Colors.white54
                  : AppTheme.textSecondaryColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: compact ? 12 : 13,
              fontWeight: FontWeight.w700,
              color:
                  isDarkMode ? Colors.white : AppTheme.textPrimaryColor,
            ),
          ),
        ],
      ),
    );
  }
}
