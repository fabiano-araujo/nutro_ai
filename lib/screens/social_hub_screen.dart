import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/feed_provider.dart';
import '../providers/friends_provider.dart';
import '../providers/challenges_provider.dart';
import '../services/feed_service.dart';
import '../services/challenge_service.dart';
import '../theme/app_theme.dart';
import '../widgets/standard_page_header.dart';
import '../widgets/diet_style_message_state.dart';

import 'friends_screen.dart';
import 'challenge_detail_screen.dart';

// Controlador global para gerenciar a navegacao interna do SocialHubScreen
class SocialTabController {
  static final SocialTabController _instance = SocialTabController._internal();

  factory SocialTabController() => _instance;

  SocialTabController._internal();

  Function(int)? tabChangeCallback;

  void changeTab(int index) {
    if (tabChangeCallback != null) {
      tabChangeCallback!(index);
    }
  }
}

final socialTabController = SocialTabController();

class SocialHubScreen extends StatefulWidget {
  final VoidCallback? onOpenDrawer;

  const SocialHubScreen({Key? key, this.onOpenDrawer}) : super(key: key);

  @override
  State<SocialHubScreen> createState() => _SocialHubScreenState();
}

class _SocialHubScreenState extends State<SocialHubScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<String> _tabLabels = const ['Feed', 'Desafios', 'Amigos'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_handleTabChanged);

    socialTabController.tabChangeCallback = (index) {
      if (mounted && index >= 0 && index < 3) {
        _tabController.animateTo(index);
      }
    };
  }

  void _handleTabChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    socialTabController.tabChangeCallback = null;
    _tabController.removeListener(_handleTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDarkMode ? AppTheme.darkBackgroundColor : AppTheme.backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            StandardPageHeader(
              title: 'Social',
              onOpenDrawer: widget.onOpenDrawer,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
              child: Row(
                children: List.generate(_tabLabels.length, (index) {
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        right: index == _tabLabels.length - 1 ? 0 : 8,
                      ),
                      child: _SocialModeChip(
                        label: _tabLabels[index],
                        isSelected: _tabController.index == index,
                        onTap: () => _tabController.animateTo(index),
                      ),
                    ),
                  );
                }),
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _FeedTab(),
                  _ChallengesTab(),
                  _FriendsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== FEED TAB ====================
class _FeedTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<FeedProvider>(
      builder: (context, feedProvider, child) {
        if (feedProvider.isLoading && feedProvider.activities.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (feedProvider.error != null && feedProvider.activities.isEmpty) {
          return RefreshIndicator(
            onRefresh: feedProvider.refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              children: [
                DietStyleMessageState(
                  title: 'Nao foi possivel carregar o feed',
                  message:
                      'Verifique sua conexao e tente novamente para buscar as atividades sociais.',
                  fallbackIcon: Icons.cloud_off_rounded,
                  primaryActionLabel: 'Tentar novamente',
                  primaryActionIcon: Icons.refresh_rounded,
                  onPrimaryAction: feedProvider.refresh,
                  topSpacing: 56,
                ),
              ],
            ),
          );
        }

        if (feedProvider.isEmpty) {
          return RefreshIndicator(
            onRefresh: feedProvider.refresh,
            child: _EmptyFeedState(),
          );
        }

        return RefreshIndicator(
          onRefresh: feedProvider.refresh,
          color: Theme.of(context).primaryColor,
          edgeOffset: 8,
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            itemCount:
                feedProvider.activities.length + (feedProvider.hasMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == feedProvider.activities.length) {
                if (!feedProvider.isLoadingMore) {
                  feedProvider.loadMore();
                }
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(),
                  ),
                );
              }

              final activity = feedProvider.activities[index];
              return _FeedActivityCard(
                activity: activity,
                onReact: (emoji) =>
                    feedProvider.toggleReaction(activity.id, emoji),
              );
            },
          ),
        );
      },
    );
  }
}

class _EmptyFeedState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      children: [
        DietStyleMessageState(
          title: 'Seu feed esta vazio',
          message:
              'Adicione amigos para acompanhar atividades, streaks e desafios por aqui.',
          fallbackIcon: Icons.dynamic_feed_rounded,
          primaryActionLabel: 'Encontrar amigos',
          primaryActionIcon: Icons.people_alt_rounded,
          onPrimaryAction: () => socialTabController.changeTab(2),
          topSpacing: 56,
        ),
      ],
    );
  }
}

class _FeedActivityCard extends StatelessWidget {
  final FeedActivity activity;
  final Function(String) onReact;

  const _FeedActivityCard({
    required this.activity,
    required this.onReact,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDarkMode ? AppTheme.darkCardColor : Colors.white;
    final typeInfo = _getTypeInfo();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1.5,
      shadowColor: isDarkMode
          ? Colors.black.withValues(alpha: 0.3)
          : Colors.black.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      color: cardColor,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor:
                        Theme.of(context).primaryColor.withValues(alpha: 0.12),
                    child: Text(
                      activity.user.name.isNotEmpty
                          ? activity.user.name[0].toUpperCase()
                          : '?',
                      style: TextStyle(
                        color: Theme.of(context).primaryColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          activity.user.name,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: isDarkMode
                                ? Colors.white
                                : AppTheme.textPrimaryColor,
                          ),
                        ),
                        Text(
                          _formatTime(activity.createdAt),
                          style: TextStyle(
                            fontSize: 11,
                            color: isDarkMode
                                ? Colors.white.withValues(alpha: 0.4)
                                : AppTheme.textSecondaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(typeInfo.icon, color: typeInfo.color, size: 20),
                ],
              ),
              const SizedBox(height: 10),
              // Mensagem
              _buildActivityContent(context, isDarkMode, typeInfo),
              const SizedBox(height: 10),
              // Reacoes
              _buildReactionsBar(context, isDarkMode),
            ],
          ),
        ),
      );
  }

  _ActivityTypeInfo _getTypeInfo() {
    final activityType = activity.type.toUpperCase();
    switch (activityType) {
      case 'CHECKIN_PROTEIN':
        return _ActivityTypeInfo(
            Icons.fitness_center_rounded, const Color(0xFFFF9800));
      case 'CHECKIN_GOAL':
        return _ActivityTypeInfo(
            Icons.flag_rounded, const Color(0xFF4CAF50));
      case 'CHECKIN_OVER':
        return _ActivityTypeInfo(
            Icons.check_circle_rounded, const Color(0xFF2196F3));
      case 'STREAK_MILESTONE':
        return _ActivityTypeInfo(
            Icons.local_fire_department_rounded, const Color(0xFFFF5722));
      case 'FRIEND_STREAK':
        return _ActivityTypeInfo(
            Icons.favorite_rounded, const Color(0xFFE91E63));
      case 'CHALLENGE_JOIN':
        return _ActivityTypeInfo(
            Icons.emoji_events_rounded, const Color(0xFFFFC107));
      default:
        return _ActivityTypeInfo(
            Icons.check_circle_rounded, const Color(0xFF2196F3));
    }
  }

  Widget _buildActivityContent(
      BuildContext context, bool isDarkMode, _ActivityTypeInfo typeInfo) {
    String message;
    String? detail;
    final activityType = activity.type.toUpperCase();

    switch (activityType) {
      case 'CHECKIN_PROTEIN':
        message = 'Bateu a meta de proteina!';
        if (!activity.isPrivate && activity.data != null) {
          final protein = activity.data!['protein'];
          final goal = activity.data!['proteinGoal'];
          if (protein != null && goal != null) {
            detail = '${protein}g / ${goal}g';
          }
        }
        break;
      case 'CHECKIN_GOAL':
        message = 'Atingiu o objetivo calorico!';
        if (!activity.isPrivate && activity.data != null) {
          final cal = activity.data!['calories'];
          final goal = activity.data!['calorieGoal'];
          if (cal != null && goal != null) {
            detail = '$cal / $goal kcal';
          }
        }
        break;
      case 'CHECKIN_OVER':
        message = 'Registrou o dia';
        break;
      case 'STREAK_MILESTONE':
        final days = activity.data?['days'] ?? 0;
        message = 'Alcancou $days dias de streak!';
        break;
      case 'FRIEND_STREAK':
        final friendName = activity.data?['friendName'] ?? 'amigo';
        final days = activity.data?['days'] ?? 0;
        message = 'Duo streak de $days dias com $friendName!';
        break;
      case 'CHALLENGE_JOIN':
        final challengeName = activity.data?['challengeName'] ?? 'desafio';
        message = 'Entrou no desafio "$challengeName"';
        break;
      default:
        message = 'Atividade no app';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          message,
          style: TextStyle(
            fontSize: 14,
            color: isDarkMode ? Colors.white : AppTheme.textPrimaryColor,
          ),
        ),
        if (detail != null) ...[
          const SizedBox(height: 4),
          Text(
            detail,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: typeInfo.color,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildReactionsBar(BuildContext context, bool isDarkMode) {
    final emojis = ['👏', '🔥', '💪', '😅'];
    final primaryColor =
        isDarkMode ? AppTheme.primaryColorDarkMode : AppTheme.primaryColor;

    return Row(
      children: emojis.map((emoji) {
        final count = activity.reactionCounts[emoji] ?? 0;
        final hasReacted = activity.hasReacted(emoji);

        return Padding(
          padding: const EdgeInsets.only(right: 6),
          child: InkWell(
            onTap: () => onReact(emoji),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: hasReacted
                    ? primaryColor.withValues(alpha: 0.1)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: hasReacted
                      ? primaryColor.withValues(alpha: 0.25)
                      : (isDarkMode
                          ? AppTheme.darkBorderColor
                          : AppTheme.dividerColor),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(emoji, style: const TextStyle(fontSize: 14)),
                  if (count > 0) ...[
                    const SizedBox(width: 4),
                    Text(
                      count.toString(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: hasReacted
                            ? primaryColor
                            : (isDarkMode
                                ? Colors.white.withValues(alpha: 0.5)
                                : AppTheme.textSecondaryColor),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inMinutes < 1) {
      return 'agora';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}min';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h';
    } else if (diff.inDays == 1) {
      return 'ontem';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d';
    } else {
      return '${dateTime.day}/${dateTime.month}';
    }
  }
}

class _ActivityTypeInfo {
  final IconData icon;
  final Color color;

  const _ActivityTypeInfo(this.icon, this.color);
}

// ==================== CHALLENGES TAB ====================
class _ChallengesTab extends StatefulWidget {
  @override
  State<_ChallengesTab> createState() => _ChallengesTabState();
}

class _ChallengesTabState extends State<_ChallengesTab> {
  bool _showPublic = false;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Consumer<ChallengesProvider>(
      builder: (context, challengesProvider, child) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Row(
                children: [
                  _TextTab(
                    label: 'Meus Desafios',
                    isSelected: !_showPublic,
                    onTap: () => setState(() => _showPublic = false),
                  ),
                  const SizedBox(width: 20),
                  _TextTab(
                    label: 'Publicos',
                    isSelected: _showPublic,
                    onTap: () {
                      setState(() => _showPublic = true);
                      challengesProvider.loadPublicChallenges();
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: challengesProvider.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _showPublic
                      ? _buildPublicChallenges(challengesProvider, isDarkMode)
                      : _buildMyChallenges(challengesProvider, isDarkMode),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMyChallenges(ChallengesProvider provider, bool isDarkMode) {
    if (provider.error != null && provider.myChallenges.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        children: [
          DietStyleMessageState(
            title: 'Nao foi possivel carregar os desafios',
            message:
                'Verifique sua conexao e tente novamente para ver seus desafios.',
            fallbackIcon: Icons.cloud_off_rounded,
            primaryActionLabel: 'Tentar novamente',
            primaryActionIcon: Icons.refresh_rounded,
            onPrimaryAction: provider.refresh,
            topSpacing: 48,
          ),
        ],
      );
    }

    if (provider.myChallenges.isEmpty) {
      return _EmptyChallengesState(
        onCreateChallenge: () => _showCreateChallengeDialog(context),
        onJoinByCode: () => _showJoinByCodeDialog(context),
      );
    }

    return RefreshIndicator(
      onRefresh: provider.refresh,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        itemCount: provider.myChallenges.length,
        itemBuilder: (context, index) {
          final challenge = provider.myChallenges[index];
          return _ChallengeCard(
            challenge: challenge,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    ChallengeDetailScreen(challengeId: challenge.id),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPublicChallenges(ChallengesProvider provider, bool isDarkMode) {
    if (provider.error != null && provider.publicChallenges.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        children: [
          DietStyleMessageState(
            title: 'Nao foi possivel carregar os desafios',
            message: 'Tente atualizar novamente para buscar desafios publicos.',
            fallbackIcon: Icons.cloud_off_rounded,
            primaryActionLabel: 'Tentar novamente',
            primaryActionIcon: Icons.refresh_rounded,
            onPrimaryAction: provider.loadPublicChallenges,
            topSpacing: 48,
          ),
        ],
      );
    }

    if (provider.publicChallenges.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        children: const [
          DietStyleMessageState(
            title: 'Nenhum desafio publico',
            message:
                'Quando outros usuarios abrirem desafios, eles vao aparecer aqui.',
            fallbackIcon: Icons.emoji_events_rounded,
            topSpacing: 48,
          ),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      itemCount: provider.publicChallenges.length,
      itemBuilder: (context, index) {
        final challenge = provider.publicChallenges[index];
        return _ChallengeCard(
          challenge: challenge,
          showJoinButton: true,
          onTap: () {},
          onJoin: () => provider.joinChallenge(challenge.id),
        );
      },
    );
  }

  void _showCreateChallengeDialog(BuildContext context) {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    String selectedType = 'LOGGING_STREAK';
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryColor =
        isDarkMode ? AppTheme.primaryColorDarkMode : AppTheme.primaryColor;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDarkMode ? AppTheme.darkCardColor : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.emoji_events_rounded,
                  color: primaryColor, size: 20),
            ),
            const SizedBox(width: 12),
            const Text('Criar Desafio'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Nome do desafio',
                  hintText: '7 dias registrando',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descController,
                decoration: const InputDecoration(
                  labelText: 'Descricao (opcional)',
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: selectedType,
                decoration: const InputDecoration(labelText: 'Tipo'),
                items: const [
                  DropdownMenuItem(
                      value: 'LOGGING_STREAK',
                      child: Text('Streak de Registro')),
                  DropdownMenuItem(
                      value: 'PROTEIN_TARGET', child: Text('Meta de Proteina')),
                  DropdownMenuItem(
                      value: 'CALORIE_DEFICIT',
                      child: Text('Deficit Calorico')),
                  DropdownMenuItem(
                      value: 'FIBER_TARGET', child: Text('Meta de Fibra')),
                ],
                onChanged: (val) => selectedType = val ?? 'LOGGING_STREAK',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isNotEmpty) {
                final provider = context.read<ChallengesProvider>();
                await provider.createChallenge(
                  name: nameController.text,
                  description:
                      descController.text.isEmpty ? null : descController.text,
                  type: selectedType,
                );
                Navigator.pop(ctx);
              }
            },
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Criar'),
          ),
        ],
      ),
    );
  }

  void _showJoinByCodeDialog(BuildContext context) {
    final codeController = TextEditingController();
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryColor =
        isDarkMode ? AppTheme.primaryColorDarkMode : AppTheme.primaryColor;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDarkMode ? AppTheme.darkCardColor : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.qr_code_rounded, color: primaryColor, size: 20),
            ),
            const SizedBox(width: 12),
            const Text('Entrar com Codigo'),
          ],
        ),
        content: TextField(
          controller: codeController,
          decoration: const InputDecoration(
            labelText: 'Codigo do desafio',
            hintText: 'Ex: ABC12345',
          ),
          textCapitalization: TextCapitalization.characters,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (codeController.text.isNotEmpty) {
                final provider = context.read<ChallengesProvider>();
                final success = await provider
                    .joinByCode(codeController.text.toUpperCase());
                Navigator.pop(ctx);
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Entrou no desafio!')),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Codigo invalido')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Entrar'),
          ),
        ],
      ),
    );
  }
}

class _EmptyChallengesState extends StatelessWidget {
  final VoidCallback onCreateChallenge;
  final VoidCallback onJoinByCode;

  const _EmptyChallengesState({
    required this.onCreateChallenge,
    required this.onJoinByCode,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      children: [
        DietStyleMessageState(
          title: 'Nenhum desafio ativo',
          message:
              'Crie um desafio proprio ou entre por codigo para competir com amigos.',
          fallbackIcon: Icons.emoji_events_rounded,
          primaryActionLabel: 'Criar desafio',
          primaryActionIcon: Icons.add_rounded,
          onPrimaryAction: onCreateChallenge,
          secondaryActionLabel: 'Entrar com codigo',
          secondaryActionIcon: Icons.qr_code_rounded,
          onSecondaryAction: onJoinByCode,
          topSpacing: 48,
        ),
      ],
    );
  }
}

class _ChallengeCard extends StatelessWidget {
  final Challenge challenge;
  final VoidCallback onTap;
  final bool showJoinButton;
  final VoidCallback? onJoin;

  const _ChallengeCard({
    required this.challenge,
    required this.onTap,
    this.showJoinButton = false,
    this.onJoin,
  });

  IconData get _typeIcon {
    switch (challenge.type.toUpperCase()) {
      case 'LOGGING_STREAK':
        return Icons.local_fire_department_rounded;
      case 'PROTEIN_TARGET':
        return Icons.fitness_center_rounded;
      case 'CALORIE_DEFICIT':
        return Icons.trending_down_rounded;
      case 'FIBER_TARGET':
        return Icons.eco_rounded;
      default:
        return Icons.emoji_events_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDarkMode ? AppTheme.darkCardColor : Colors.white;
    final primaryColor =
        isDarkMode ? AppTheme.primaryColorDarkMode : AppTheme.primaryColor;
    final daysLeft = challenge.endDate.difference(DateTime.now()).inDays;
    final safeDaysLeft = daysLeft < 0 ? 0 : daysLeft;
    final daysColor = safeDaysLeft > 3
        ? const Color(0xFF4CAF50)
        : (safeDaysLeft > 0
            ? const Color(0xFFFF9800)
            : const Color(0xFFE53935));

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1.5,
      shadowColor: isDarkMode
          ? Colors.black.withValues(alpha: 0.3)
          : Colors.black.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      color: cardColor,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(_typeIcon, color: primaryColor, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        challenge.name,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: isDarkMode
                              ? Colors.white
                              : AppTheme.textPrimaryColor,
                        ),
                      ),
                    ),
                    Text(
                      '$safeDaysLeft d',
                      style: TextStyle(
                        color: daysColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      '${challenge.participantCount}/${challenge.maxParticipants} participantes',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDarkMode
                            ? Colors.white.withValues(alpha: 0.45)
                            : AppTheme.textSecondaryColor,
                      ),
                    ),
                    if (challenge.description != null) ...[
                      Text(
                        '  ·  ',
                        style: TextStyle(
                          color: isDarkMode
                              ? Colors.white.withValues(alpha: 0.2)
                              : AppTheme.dividerColor,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          challenge.description!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDarkMode
                                ? Colors.white.withValues(alpha: 0.45)
                                : AppTheme.textSecondaryColor,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (showJoinButton && onJoin != null) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: onJoin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                      ),
                      child: const Text('Entrar',
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: Colors.white)),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
  }
}

class _TextTab extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _TextTab({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryColor =
        isDarkMode ? AppTheme.primaryColorDarkMode : AppTheme.primaryColor;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected
                    ? (isDarkMode ? Colors.white : AppTheme.textPrimaryColor)
                    : (isDarkMode
                        ? Colors.white.withValues(alpha: 0.45)
                        : AppTheme.textSecondaryColor),
              ),
            ),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 2,
            width: isSelected ? 24 : 0,
            decoration: BoxDecoration(
              color: primaryColor,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        ],
      ),
    );
  }
}

class _SocialModeChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _SocialModeChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryColor =
        isDarkMode ? AppTheme.primaryColorDarkMode : AppTheme.primaryColor;
    final unselectedBorderColor =
        isDarkMode ? AppTheme.darkBorderColor : AppTheme.dividerColor;
    final cardColor = isDarkMode ? AppTheme.darkCardColor : Colors.white;

    return ChoiceChip(
      label: SizedBox(
        width: double.infinity,
        child: Text(
          label,
          textAlign: TextAlign.center,
        ),
      ),
      selected: isSelected,
      onSelected: (_) => onTap(),
      selectedColor: primaryColor,
      backgroundColor: cardColor,
      labelStyle: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: isSelected
            ? Colors.white
            : (isDarkMode ? Colors.grey[400] : Colors.grey[700]),
      ),
      showCheckmark: false,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected ? primaryColor : unselectedBorderColor,
          width: 1,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    );
  }
}

// ==================== FRIENDS TAB ====================
class _FriendsTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<FriendsProvider>(
      builder: (context, friendsProvider, child) {
        if (friendsProvider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        return Padding(
          padding: const EdgeInsets.only(top: 4),
          child: FriendsScreen(isEmbedded: true),
        );
      },
    );
  }
}
