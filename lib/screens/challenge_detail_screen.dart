import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../i18n/app_localizations_extension.dart';
import '../providers/challenges_provider.dart';
import '../services/challenge_service.dart';
import '../theme/app_theme.dart';
import '../widgets/challenge_progress_widgets.dart';

class ChallengeDetailScreen extends StatefulWidget {
  final int challengeId;

  const ChallengeDetailScreen({Key? key, required this.challengeId}) : super(key: key);

  @override
  State<ChallengeDetailScreen> createState() => _ChallengeDetailScreenState();
}

class _ChallengeDetailScreenState extends State<ChallengeDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChallengesProvider>().loadChallengeDetails(widget.challengeId);
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
      backgroundColor: isDarkMode ? AppTheme.darkBackgroundColor : Colors.grey[100],
      appBar: AppBar(
        backgroundColor: isDarkMode ? AppTheme.darkBackgroundColor : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: isDarkMode ? Colors.white : Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Detalhes do Desafio',
          style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
        ),
        actions: [
          Consumer<ChallengesProvider>(
            builder: (context, provider, _) {
              if (provider.selectedChallenge?.joinCode != null) {
                return IconButton(
                  icon: Icon(Icons.share, color: isDarkMode ? Colors.white : Colors.black),
                  onPressed: () => _shareChallenge(provider.selectedChallenge!),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
      body: Consumer<ChallengesProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final challenge = provider.selectedChallenge;
          if (challenge == null) {
            return Center(
              child: Text(
                'Desafio nao encontrado',
                style: TextStyle(color: isDarkMode ? Colors.white60 : Colors.grey),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => provider.loadChallengeDetails(widget.challengeId),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ChallengeHeader(challenge: challenge),
                  const SizedBox(height: 16),
                  if (challenge.progress != null || challenge.objective != null) ...[
                    ChallengeProgressPanel(challenge: challenge),
                    const SizedBox(height: 16),
                  ],
                  if (challenge.myParticipation != null)
                    _MyProgressCard(
                      participation: challenge.myParticipation!,
                      challenge: challenge,
                    ),
                  const SizedBox(height: 16),
                  _LeaderboardSection(leaderboard: provider.leaderboard),
                  const SizedBox(height: 24),
                  _ActionButtons(
                    challenge: challenge,
                    onRefreshProgress: challenge.myParticipation == null
                        ? null
                        : () => _refreshProgress(provider),
                    onLeave: () => _confirmLeave(context, provider),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _shareChallenge(Challenge challenge) {
    final code = challenge.joinCode;
    if (code == null) return;

    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Codigo "$code" copiado para a area de transferencia!'),
        action: SnackBarAction(
          label: 'OK',
          onPressed: () {},
        ),
      ),
    );
  }

  void _confirmLeave(BuildContext context, ChallengesProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sair do Desafio'),
        content: const Text('Tem certeza que deseja sair deste desafio? Seu progresso sera perdido.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await provider.leaveChallenge(widget.challengeId);
              if (success) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Voce saiu do desafio')),
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
    final points = await provider.recordProgress(
      challengeId: widget.challengeId,
    );

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
}

class _ChallengeHeader extends StatelessWidget {
  final Challenge challenge;

  const _ChallengeHeader({required this.challenge});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final daysRemaining = challenge.daysRemaining;

    return Card(
      color: isDarkMode ? AppTheme.darkCardColor : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.withAlpha(26),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.emoji_events, color: Colors.amber, size: 32),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        challenge.name,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        challenge.typeFormatted,
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (challenge.description != null) ...[
              const SizedBox(height: 16),
              Text(
                challenge.description!,
                style: TextStyle(
                  fontSize: 14,
                  color: isDarkMode ? Colors.white70 : Colors.grey[700],
                ),
              ),
            ],
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _InfoItem(
                  icon: Icons.calendar_today,
                  label: 'Restam',
                  value: '$daysRemaining dias',
                  color: daysRemaining <= 2 ? Colors.red : Colors.green,
                ),
                _InfoItem(
                  icon: Icons.people,
                  label: 'Participantes',
                  value: '${challenge.participantCount}/${challenge.maxParticipants}',
                  color: Theme.of(context).primaryColor,
                ),
                _InfoItem(
                  icon: Icons.timer,
                  label: 'Duracao',
                  value: '${challenge.durationDays} dias',
                  color: Colors.blue,
                ),
              ],
            ),
            if (challenge.joinCode != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDarkMode ? Colors.white10 : Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.vpn_key, size: 18, color: Colors.grey),
                    const SizedBox(width: 8),
                    Text(
                      'Codigo: ${challenge.joinCode}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 1,
                        color: isDarkMode ? Colors.white70 : Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _InfoItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isDarkMode ? Colors.white54 : Colors.grey,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _MyProgressCard extends StatelessWidget {
  final MyParticipation participation;
  final Challenge challenge;

  const _MyProgressCard({
    required this.participation,
    required this.challenge,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Card(
      color: isDarkMode ? AppTheme.darkCardColor : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.person, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  'Meu Progresso',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _ProgressItem(
                  icon: Icons.star,
                  label: 'Pontos',
                  value: participation.totalPoints.toString(),
                  color: Colors.amber,
                ),
                _ProgressItem(
                  icon: Icons.local_fire_department,
                  label: 'Streak',
                  value: '${participation.currentStreak} dias',
                  color: Colors.deepOrange,
                ),
              ],
            ),
            const SizedBox(height: 20),
            _PointsBreakdown(challenge: challenge),
          ],
        ),
      ),
    );
  }
}

class _ProgressItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _ProgressItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: color.withAlpha(26),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isDarkMode ? Colors.white54 : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}

class _PointsBreakdown extends StatelessWidget {
  final Challenge challenge;

  const _PointsBreakdown({
    required this.challenge,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final goalRuleText = challenge.type.toUpperCase() == 'FIBER_TARGET'
        ? 'Bater meta de fibra'
        : 'Bater meta calorica';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.white10 : Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Como ganhar pontos:',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isDarkMode ? Colors.white70 : Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          _PointRule(emoji: '📝', text: 'Registrar refeicao', points: '+1'),
          _PointRule(emoji: '💪', text: 'Bater meta de proteina', points: '+1'),
          _PointRule(emoji: '🎯', text: goalRuleText, points: '+1'),
          _PointRule(emoji: '🔥', text: '3 dias seguidos', points: '+3 bonus'),
        ],
      ),
    );
  }
}

class _PointRule extends StatelessWidget {
  final String emoji;
  final String text;
  final String points;

  const _PointRule({
    required this.emoji,
    required this.text,
    required this.points,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                color: isDarkMode ? Colors.white60 : Colors.grey[600],
              ),
            ),
          ),
          Text(
            points,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.green,
            ),
          ),
        ],
      ),
    );
  }
}

class _LeaderboardSection extends StatelessWidget {
  final List<LeaderboardItem> leaderboard;

  const _LeaderboardSection({required this.leaderboard});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Card(
      color: isDarkMode ? AppTheme.darkCardColor : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.leaderboard, color: Colors.amber),
                const SizedBox(width: 8),
                Text(
                  'Ranking',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (leaderboard.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    'Nenhum participante ainda',
                    style: TextStyle(
                      color: isDarkMode ? Colors.white54 : Colors.grey,
                    ),
                  ),
                ),
              )
            else
              ...leaderboard.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;
                return _LeaderboardRow(item: item, index: index);
              }),
          ],
        ),
      ),
    );
  }
}

class _LeaderboardRow extends StatelessWidget {
  final LeaderboardItem item;
  final int index;

  const _LeaderboardRow({required this.item, required this.index});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final rank = item.rank;

    Color? medalColor;
    if (rank == 1) medalColor = Colors.amber;
    if (rank == 2) medalColor = Colors.grey[400];
    if (rank == 3) medalColor = Colors.brown[300];

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: rank <= 3
            ? (medalColor ?? Colors.grey).withAlpha(26)
            : isDarkMode
                ? Colors.white10
                : Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: rank == 1 ? Border.all(color: Colors.amber, width: 2) : null,
      ),
      child: Row(
        children: [
          // Rank
          SizedBox(
            width: 32,
            child: rank <= 3
                ? Icon(Icons.emoji_events, color: medalColor, size: 24)
                : Text(
                    '#$rank',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white70 : Colors.grey[700],
                    ),
                  ),
          ),
          const SizedBox(width: 12),

          // Avatar
          CircleAvatar(
            radius: 18,
            backgroundColor: Theme.of(context).primaryColor.withAlpha(51),
            child: Text(
              item.user.name.isNotEmpty ? item.user.name[0].toUpperCase() : '?',
              style: TextStyle(
                color: Theme.of(context).primaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Name
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.user.name,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
                if (item.currentStreak > 0)
                  Row(
                    children: [
                      const Icon(Icons.local_fire_department, color: Colors.deepOrange, size: 12),
                      const SizedBox(width: 2),
                      Text(
                        '${item.currentStreak} dias',
                        style: const TextStyle(fontSize: 10, color: Colors.deepOrange),
                      ),
                    ],
                  ),
              ],
            ),
          ),

          // Points
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.amber.withAlpha(26),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.star, color: Colors.amber, size: 16),
                const SizedBox(width: 4),
                Text(
                  '${item.totalPoints}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.amber,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButtons extends StatelessWidget {
  final Challenge challenge;
  final VoidCallback? onRefreshProgress;
  final VoidCallback onLeave;

  const _ActionButtons({
    required this.challenge,
    this.onRefreshProgress,
    required this.onLeave,
  });

  @override
  Widget build(BuildContext context) {
    final canRefresh = challenge.progress?.canCheckInToday ?? false;

    return Column(
      children: [
        if (onRefreshProgress != null)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: canRefresh ? onRefreshProgress : null,
              icon: const Icon(Icons.sync_rounded),
              label: Text(
                canRefresh
                    ? context.tr.translate('challenge_update_progress')
                    : ((challenge.progress?.currentValue ?? 0) > 0
                        ? context.tr.translate('challenge_progress_done_today')
                        : context.tr.translate('challenge_progress_pending_today')),
              ),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        if (onRefreshProgress != null) const SizedBox(height: 12),
        TextButton.icon(
          onPressed: onLeave,
          icon: const Icon(Icons.exit_to_app, color: Colors.red),
          label: const Text('Sair do Desafio', style: TextStyle(color: Colors.red)),
        ),
      ],
    );
  }
}
