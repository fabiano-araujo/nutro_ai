import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../i18n/app_localizations_extension.dart';
import '../providers/challenges_provider.dart';
import '../services/challenge_service.dart';
import '../services/social_service.dart';
import '../theme/app_theme.dart';

Color _detailBackgroundColor(bool isDarkMode) =>
    isDarkMode ? AppTheme.darkBackgroundColor : AppTheme.backgroundColor;

Color _detailSurfaceColor(bool isDarkMode) =>
    isDarkMode ? const Color(0xFF2A2A2A) : Colors.white;

Color _detailInputColor(bool isDarkMode) =>
    isDarkMode ? const Color(0xFF1F1F1F) : AppTheme.backgroundColor;

Color _detailBorderColor(bool isDarkMode) =>
    isDarkMode ? Colors.white12 : Colors.black12;

Color _detailTextColor(bool isDarkMode) =>
    isDarkMode ? Colors.white : AppTheme.textPrimaryColor;

Color _detailMutedColor(bool isDarkMode) =>
    isDarkMode ? const Color(0xFFAEB7CE) : AppTheme.textSecondaryColor;

Color _detailPrimaryColor(bool isDarkMode) =>
    isDarkMode ? AppTheme.primaryColorDarkMode : AppTheme.primaryColor;

class ChallengeDetailScreen extends StatefulWidget {
  final int challengeId;

  const ChallengeDetailScreen({Key? key, required this.challengeId})
      : super(key: key);

  @override
  State<ChallengeDetailScreen> createState() => _ChallengeDetailScreenState();
}

class _ChallengeDetailScreenState extends State<ChallengeDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context
          .read<ChallengesProvider>()
          .loadChallengeDetails(widget.challengeId);
    });
  }

  @override
  void dispose() {
    context.read<ChallengesProvider>().clearSelection();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: _detailBackgroundColor(isDarkMode),
      body: SafeArea(
        child: Consumer<ChallengesProvider>(
          builder: (context, provider, child) {
            if (provider.isLoading && provider.selectedChallenge == null) {
              return const Center(child: CircularProgressIndicator());
            }

            final challenge = provider.selectedChallenge;
            if (challenge == null) {
              return _MissingChallengeState(isDarkMode: isDarkMode);
            }

            return RefreshIndicator(
              onRefresh: () =>
                  provider.loadChallengeDetails(widget.challengeId),
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: _ChallengeTopBar(
                      challenge: challenge,
                      onBack: () => Navigator.pop(context),
                      onShare: challenge.joinCode == null
                          ? null
                          : () => _copyInviteCode(challenge),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 6, 24, 18),
                      child: _ChallengeHeroCard(
                        challenge: challenge,
                        onInvite: challenge.joinCode == null
                            ? null
                            : () => _copyInviteCode(challenge),
                      ),
                    ),
                  ),
                  if (challenge.myParticipation != null)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 18),
                        child: _MyProgressSummary(
                          participation: challenge.myParticipation!,
                          canRefresh:
                              challenge.progress?.canCheckInToday ?? false,
                          onRefresh: () => _refreshProgress(provider),
                        ),
                      ),
                    ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                      child: _SectionTitle(title: 'Classificações'),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                      child: _LeaderboardPreviewCard(
                        leaderboard: provider.leaderboard,
                        onViewAll: provider.leaderboard.length <= 4
                            ? null
                            : () => _showAllLeaderboard(
                                  context,
                                  provider.leaderboard,
                                ),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                      child: _SectionTitle(title: 'Estatísticas do grupo'),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 22),
                      child: _GroupStatsCard(
                        challenge: challenge,
                        leaderboard: provider.leaderboard,
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
                      child: _ActionButtons(
                        challenge: challenge,
                        onLeave: () => _confirmLeave(context, provider),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  void _copyInviteCode(Challenge challenge) {
    final code = challenge.joinCode;
    if (code == null) return;

    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Código "$code" copiado.')),
    );
  }

  void _confirmLeave(BuildContext context, ChallengesProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sair do desafio'),
        content: const Text(
          'Tem certeza que deseja sair deste desafio? Seu progresso será perdido.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await provider.leaveChallenge(widget.challengeId);
              if (!mounted) return;
              if (success) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Você saiu do desafio.')),
                );
              }
            },
            child: const Text('Sair', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _refreshProgress(ChallengesProvider provider) async {
    final points =
        await provider.recordProgress(challengeId: widget.challengeId);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          points != null
              ? context.tr.translate('challenge_progress_updated')
              : context.tr.translate('challenge_progress_unavailable'),
        ),
      ),
    );
  }

  void _showAllLeaderboard(
    BuildContext context,
    List<LeaderboardItem> leaderboard,
  ) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: _detailSurfaceColor(isDarkMode),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionTitle(title: 'Todas as classificações'),
                const SizedBox(height: 12),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: leaderboard.length,
                    separatorBuilder: (_, __) => Divider(
                      color: _detailBorderColor(isDarkMode),
                      height: 1,
                    ),
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: _LeaderboardRow(item: leaderboard[index]),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MissingChallengeState extends StatelessWidget {
  final bool isDarkMode;

  const _MissingChallengeState({required this.isDarkMode});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'Desafio não encontrado',
        style: TextStyle(color: _detailMutedColor(isDarkMode)),
      ),
    );
  }
}

class _ChallengeTopBar extends StatelessWidget {
  final Challenge challenge;
  final VoidCallback onBack;
  final VoidCallback? onShare;

  const _ChallengeTopBar({
    required this.challenge,
    required this.onBack,
    this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = _detailTextColor(isDarkMode);

    return SizedBox(
      height: 56,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            IconButton(
              icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor),
              onPressed: onBack,
              tooltip: 'Voltar',
            ),
            Expanded(
              child: Text(
                'Desafio',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: textColor,
                ),
              ),
            ),
            IconButton(
              icon: Icon(
                Icons.ios_share_rounded,
                color:
                    onShare == null ? _detailMutedColor(isDarkMode) : textColor,
              ),
              onPressed: onShare,
              tooltip: 'Convidar',
            ),
          ],
        ),
      ),
    );
  }
}

class _ChallengeHeroCard extends StatelessWidget {
  final Challenge challenge;
  final VoidCallback? onInvite;

  const _ChallengeHeroCard({
    required this.challenge,
    this.onInvite,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primary = _detailPrimaryColor(isDarkMode);
    final textColor = _detailTextColor(isDarkMode);
    final mutedColor = _detailMutedColor(isDarkMode);
    final progress = (challenge.completionPercent / 100).clamp(0.0, 1.0);

    return _DetailCard(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  '${challenge.name} 🏆',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: textColor,
                    height: 1.05,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              _DaysBadge(challenge: challenge),
            ],
          ),
          if (challenge.description != null &&
              challenge.description!.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              challenge.description!,
              style: TextStyle(
                fontSize: 14,
                height: 1.4,
                color: mutedColor,
              ),
            ),
          ],
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 11,
              value: progress,
              backgroundColor: _detailInputColor(isDarkMode),
              valueColor: AlwaysStoppedAnimation<Color>(primary),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                'Iniciado ${_formatShortDate(challenge.startDate)}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: mutedColor,
                ),
              ),
              const Spacer(),
              Text(
                'Acaba ${_formatShortDate(challenge.endDate)}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: mutedColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _InfoPill(
                icon: Icons.group_rounded,
                label:
                    '${challenge.participantCount}/${challenge.maxParticipants}',
              ),
              const SizedBox(width: 8),
              _InfoPill(
                icon: Icons.flag_rounded,
                label: '${challenge.targetDays} dias',
              ),
              const SizedBox(width: 8),
              _InfoPill(
                icon: Icons.bolt_rounded,
                label: challenge.typeFormatted,
              ),
            ],
          ),
          if (challenge.joinCode != null) ...[
            const SizedBox(height: 18),
            InkWell(
              onTap: onInvite,
              borderRadius: BorderRadius.circular(18),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: _detailInputColor(isDarkMode),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: _detailBorderColor(isDarkMode)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.share_rounded, size: 18, color: mutedColor),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        challenge.joinCode!,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                          color: textColor,
                        ),
                      ),
                    ),
                    Text(
                      'Convidar',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: textColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DaysBadge extends StatelessWidget {
  final Challenge challenge;

  const _DaysBadge({required this.challenge});

  @override
  Widget build(BuildContext context) {
    final days = challenge.daysRemaining.clamp(0, 9999);
    final color = days == 0
        ? const Color(0xFFE05243)
        : days <= 3
            ? const Color(0xFFFF9800)
            : const Color(0xFF4CAF50);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        '$days dias',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoPill({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Flexible(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: _detailInputColor(isDarkMode),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _detailBorderColor(isDarkMode)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: _detailMutedColor(isDarkMode)),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _detailTextColor(isDarkMode),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MyProgressSummary extends StatelessWidget {
  final MyParticipation participation;
  final bool canRefresh;
  final VoidCallback onRefresh;

  const _MyProgressSummary({
    required this.participation,
    required this.canRefresh,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primary = _detailPrimaryColor(isDarkMode);
    final foreground = AppTheme.onColor(primary);

    return _DetailCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: _InlineMetric(
              icon: Icons.bolt_rounded,
              value: '${participation.totalPoints}',
              label: 'meus pontos',
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _InlineMetric(
              icon: Icons.local_fire_department_rounded,
              value: '${participation.currentStreak}',
              label: 'dias ativos',
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            height: 42,
            child: FilledButton(
              onPressed: canRefresh ? onRefresh : null,
              style: FilledButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: foreground,
                disabledBackgroundColor: _detailInputColor(isDarkMode),
                disabledForegroundColor: _detailMutedColor(isDarkMode),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: const Icon(Icons.sync_rounded, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineMetric extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _InlineMetric({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Row(
      children: [
        Icon(icon, size: 19, color: _detailMutedColor(isDarkMode)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: _detailTextColor(isDarkMode),
                  height: 1,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _detailMutedColor(isDarkMode),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Text(
      title,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w900,
        color: _detailTextColor(isDarkMode),
      ),
    );
  }
}

class _LeaderboardPreviewCard extends StatelessWidget {
  final List<LeaderboardItem> leaderboard;
  final VoidCallback? onViewAll;

  const _LeaderboardPreviewCard({
    required this.leaderboard,
    this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final preview = leaderboard.take(4).toList();

    return _DetailCard(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        children: [
          if (leaderboard.isEmpty)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'Nenhum participante ainda',
                style: TextStyle(color: _detailMutedColor(isDarkMode)),
              ),
            )
          else
            ...preview.map(
              (item) => Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: _LeaderboardRow(item: item),
              ),
            ),
          if (onViewAll != null) ...[
            Divider(color: _detailBorderColor(isDarkMode), height: 1),
            InkWell(
              onTap: onViewAll,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Todas as classificações',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _detailMutedColor(isDarkMode),
                        ),
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: _detailMutedColor(isDarkMode),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LeaderboardRow extends StatelessWidget {
  final LeaderboardItem item;

  const _LeaderboardRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = _detailTextColor(isDarkMode);
    final mutedColor = _detailMutedColor(isDarkMode);

    return Row(
      children: [
        _UserAvatar(user: item.user),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.user.name.isEmpty ? 'Participante' : item.user.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                item.currentStreak > 0
                    ? '${item.currentStreak} dias ativos'
                    : '${item.totalPoints} pontos',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: mutedColor,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Text(
          item.rank <= 0 ? '-' : '${item.rank}º',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: textColor,
          ),
        ),
      ],
    );
  }
}

class _GroupStatsCard extends StatelessWidget {
  final Challenge challenge;
  final List<LeaderboardItem> leaderboard;

  const _GroupStatsCard({
    required this.challenge,
    required this.leaderboard,
  });

  @override
  Widget build(BuildContext context) {
    final totalPoints = leaderboard.fold<int>(
      0,
      (sum, item) => sum + item.totalPoints,
    );
    final activeDays = leaderboard.fold<int>(
      0,
      (sum, item) => sum + item.currentStreak,
    );
    final averagePerDay = challenge.durationDays <= 0
        ? 0.0
        : totalPoints / challenge.durationDays;
    final leader = leaderboard.isEmpty ? null : leaderboard.first;

    return _DetailCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        children: [
          _StatLine(
            icon: Icons.monitor_heart_rounded,
            value: '$totalPoints',
            label: 'Pontos totais',
          ),
          const SizedBox(height: 18),
          _StatLine(
            icon: Icons.calendar_month_rounded,
            value: '$activeDays',
            label: 'Dias ativos somados',
          ),
          const SizedBox(height: 18),
          _StatLine(
            icon: Icons.trending_up_rounded,
            value: _formatDecimal(averagePerDay),
            label: 'Média de pontos por dia',
          ),
          if (leader != null) ...[
            const SizedBox(height: 18),
            _LeaderStatLine(item: leader),
          ],
        ],
      ),
    );
  }
}

class _StatLine extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _StatLine({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = _detailTextColor(isDarkMode);
    final mutedColor = _detailMutedColor(isDarkMode);

    return Row(
      children: [
        Icon(icon, size: 22, color: mutedColor),
        const SizedBox(width: 16),
        SizedBox(
          width: 58,
          child: Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: textColor,
            ),
          ),
        ),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: mutedColor,
            ),
          ),
        ),
      ],
    );
  }
}

class _LeaderStatLine extends StatelessWidget {
  final LeaderboardItem item;

  const _LeaderStatLine({required this.item});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Row(
      children: [
        _UserAvatar(user: item.user, radius: 18),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.user.name.isEmpty ? 'Participante' : item.user.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: _detailTextColor(isDarkMode),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'Líder atual',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: _detailMutedColor(isDarkMode),
                ),
              ),
            ],
          ),
        ),
        Text(
          '${item.totalPoints}',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w900,
            color: _detailTextColor(isDarkMode),
          ),
        ),
      ],
    );
  }
}

class _ActionButtons extends StatelessWidget {
  final Challenge challenge;
  final VoidCallback onLeave;

  const _ActionButtons({
    required this.challenge,
    required this.onLeave,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextButton.icon(
          onPressed: onLeave,
          icon: const Icon(Icons.exit_to_app_rounded, color: Colors.red),
          label: const Text(
            'Sair do desafio',
            style: TextStyle(color: Colors.red, fontWeight: FontWeight.w700),
          ),
        ),
        Text(
          challenge.progress?.canCheckInToday == true
              ? context.tr.translate('challenge_progress_pending_today')
              : context.tr.translate('challenge_progress_done_today'),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: _detailMutedColor(isDarkMode),
          ),
        ),
      ],
    );
  }
}

class _DetailCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _DetailCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: _detailSurfaceColor(isDarkMode),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _detailBorderColor(isDarkMode)),
      ),
      child: child,
    );
  }
}

class _UserAvatar extends StatelessWidget {
  final SimpleUser user;
  final double radius;

  const _UserAvatar({
    required this.user,
    this.radius = 22,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final photo = user.photo;

    return CircleAvatar(
      radius: radius,
      backgroundColor: _detailInputColor(isDarkMode),
      backgroundImage:
          photo != null && photo.isNotEmpty ? NetworkImage(photo) : null,
      child: photo == null || photo.isEmpty
          ? Text(
              user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: _detailTextColor(isDarkMode),
              ),
            )
          : null,
    );
  }
}

String _formatShortDate(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day/$month/${date.year}';
}

String _formatDecimal(double value) {
  final text =
      value >= 10 ? value.toStringAsFixed(0) : value.toStringAsFixed(1);
  return text.replaceAll('.', ',');
}
