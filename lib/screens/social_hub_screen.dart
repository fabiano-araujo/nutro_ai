import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/feed_provider.dart';
import '../providers/friends_provider.dart';
import '../providers/challenges_provider.dart';
import '../services/feed_service.dart';
import '../services/challenge_service.dart';
import '../theme/app_theme.dart';
import '../widgets/standard_page_header.dart';

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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    socialTabController.tabChangeCallback = (index) {
      if (mounted && index >= 0 && index < 3) {
        _tabController.animateTo(index);
      }
    };
  }

  @override
  void dispose() {
    socialTabController.tabChangeCallback = null;
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryColor =
        isDarkMode ? AppTheme.primaryColorDarkMode : AppTheme.primaryColor;

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
            // Tab bar elegante
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Container(
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? AppTheme.darkCardColor
                      : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDarkMode
                        ? AppTheme.darkBorderColor
                        : AppTheme.dividerColor,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDarkMode ? 0.18 : 0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(4),
                child: TabBar(
                  controller: _tabController,
                  dividerColor: Colors.transparent,
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicator: BoxDecoration(
                    color: primaryColor,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withValues(alpha: 0.3),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  labelColor: Colors.white,
                  unselectedLabelColor: isDarkMode
                      ? const Color(0xFFAEB7CE)
                      : AppTheme.textSecondaryColor,
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                  ),
                  tabs: const [
                    Tab(
                      height: 44,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.dynamic_feed_rounded, size: 18),
                          SizedBox(width: 6),
                          Text('Feed'),
                        ],
                      ),
                    ),
                    Tab(
                      height: 44,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.emoji_events_rounded, size: 18),
                          SizedBox(width: 6),
                          Text('Desafios'),
                        ],
                      ),
                    ),
                    Tab(
                      height: 44,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.people_rounded, size: 18),
                          SizedBox(width: 6),
                          Text('Amigos'),
                        ],
                      ),
                    ),
                  ],
                ),
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

// ==================== EMPTY STATE ====================
class _SocialEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final Color? iconColor;
  final List<Widget> actions;

  const _SocialEmptyState({
    required this.icon,
    required this.title,
    this.message,
    this.iconColor,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryColor =
        isDarkMode ? AppTheme.primaryColorDarkMode : AppTheme.primaryColor;
    final color = iconColor ?? primaryColor;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: isDarkMode ? AppTheme.darkCardColor : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDarkMode
                  ? AppTheme.darkBorderColor
                  : AppTheme.dividerColor,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDarkMode ? 0.18 : 0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      color.withValues(alpha: 0.15),
                      color.withValues(alpha: 0.06),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: color.withValues(alpha: 0.15),
                  ),
                ),
                child: Icon(icon, size: 36, color: color),
              ),
              const SizedBox(height: 20),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: isDarkMode ? Colors.white : AppTheme.textPrimaryColor,
                ),
              ),
              if (message != null) ...[
                const SizedBox(height: 10),
                Text(
                  message!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: isDarkMode
                        ? Colors.white.withValues(alpha: 0.6)
                        : AppTheme.textSecondaryColor,
                  ),
                ),
              ],
              if (actions.isNotEmpty) ...[
                const SizedBox(height: 24),
                ...actions,
              ],
            ],
          ),
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
      padding: const EdgeInsets.fromLTRB(24, 48, 24, 32),
      children: const [
        SizedBox(height: 72),
        _SocialEmptyState(
          icon: Icons.dynamic_feed_rounded,
          title: 'Seu feed esta vazio',
          message:
              'Adicione amigos para ver atividades, streaks e desafios por aqui.',
          iconColor: Color(0xFF7EC8E3),
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

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        elevation: 2,
        shadowColor: Colors.black.withValues(alpha: isDarkMode ? 0.24 : 0.08),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDarkMode
                  ? AppTheme.darkBorderColor
                  : AppTheme.dividerColor,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header com informacoes do usuario
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Row(
                  children: [
                    // Avatar com borda colorida
                    Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: typeInfo.color.withValues(alpha: 0.4),
                          width: 2,
                        ),
                      ),
                      child: CircleAvatar(
                        radius: 20,
                        backgroundColor: typeInfo.color.withValues(alpha: 0.12),
                        child: Text(
                          activity.user.name.isNotEmpty
                              ? activity.user.name[0].toUpperCase()
                              : '?',
                          style: TextStyle(
                            color: typeInfo.color,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            activity.user.name,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: isDarkMode
                                  ? Colors.white
                                  : AppTheme.textPrimaryColor,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _formatTime(activity.createdAt),
                            style: TextStyle(
                              fontSize: 12,
                              color: isDarkMode
                                  ? Colors.white.withValues(alpha: 0.45)
                                  : AppTheme.textSecondaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Badge do tipo
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: typeInfo.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: typeInfo.color.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(typeInfo.icon,
                              color: typeInfo.color, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            typeInfo.label,
                            style: TextStyle(
                              color: typeInfo.color,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Conteudo da atividade
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDarkMode
                        ? AppTheme.darkComponentColor
                        : AppTheme.surfaceColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: typeInfo.color.withValues(alpha: 0.1),
                    ),
                  ),
                  child: _buildActivityContent(context, isDarkMode, typeInfo),
                ),
              ),

              // Barra de reacoes
              Padding(
                padding: const EdgeInsets.all(12),
                child: _buildReactionsBar(context, isDarkMode),
              ),
            ],
          ),
        ),
      ),
    );
  }

  _ActivityTypeInfo _getTypeInfo() {
    final activityType = activity.type.toUpperCase();
    switch (activityType) {
      case 'CHECKIN_PROTEIN':
        return _ActivityTypeInfo(
          icon: Icons.fitness_center_rounded,
          color: const Color(0xFFFF9800),
          label: 'Proteina',
        );
      case 'CHECKIN_GOAL':
        return _ActivityTypeInfo(
          icon: Icons.flag_rounded,
          color: const Color(0xFF4CAF50),
          label: 'Meta',
        );
      case 'CHECKIN_OVER':
        return _ActivityTypeInfo(
          icon: Icons.check_circle_rounded,
          color: const Color(0xFF2196F3),
          label: 'Registro',
        );
      case 'STREAK_MILESTONE':
        return _ActivityTypeInfo(
          icon: Icons.local_fire_department_rounded,
          color: const Color(0xFFFF5722),
          label: 'Streak',
        );
      case 'FRIEND_STREAK':
        return _ActivityTypeInfo(
          icon: Icons.favorite_rounded,
          color: const Color(0xFFE91E63),
          label: 'Duo',
        );
      case 'CHALLENGE_JOIN':
        return _ActivityTypeInfo(
          icon: Icons.emoji_events_rounded,
          color: const Color(0xFFFFC107),
          label: 'Desafio',
        );
      default:
        return _ActivityTypeInfo(
          icon: Icons.check_circle_rounded,
          color: const Color(0xFF2196F3),
          label: 'Atividade',
        );
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
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
        ),
        if (detail != null) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: typeInfo.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              detail,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: typeInfo.color,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildReactionsBar(BuildContext context, bool isDarkMode) {
    final emojis = ['👏', '🔥', '💪', '😅'];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: emojis.map((emoji) {
        final count = activity.reactionCounts[emoji] ?? 0;
        final hasReacted = activity.hasReacted(emoji);
        final primaryColor = isDarkMode
            ? AppTheme.primaryColorDarkMode
            : AppTheme.primaryColor;

        return InkWell(
          onTap: () => onReact(emoji),
          borderRadius: BorderRadius.circular(999),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: hasReacted
                  ? primaryColor.withValues(alpha: 0.14)
                  : (isDarkMode
                      ? AppTheme.darkComponentColor
                      : AppTheme.surfaceColor),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: hasReacted
                    ? primaryColor.withValues(alpha: 0.3)
                    : (isDarkMode
                        ? AppTheme.darkBorderColor
                        : AppTheme.dividerColor),
                width: hasReacted ? 1.5 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(emoji, style: const TextStyle(fontSize: 16)),
                if (count > 0) ...[
                  const SizedBox(width: 5),
                  Text(
                    count.toString(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: hasReacted
                          ? primaryColor
                          : (isDarkMode
                              ? Colors.white.withValues(alpha: 0.6)
                              : AppTheme.textSecondaryColor),
                    ),
                  ),
                ],
              ],
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
  final String label;

  const _ActivityTypeInfo({
    required this.icon,
    required this.color,
    required this.label,
  });
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
            // Toggle elegante
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? AppTheme.darkCardColor
                      : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDarkMode
                        ? AppTheme.darkBorderColor
                        : AppTheme.dividerColor,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black
                          .withValues(alpha: isDarkMode ? 0.14 : 0.04),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _SegmentButton(
                        label: 'Meus Desafios',
                        icon: Icons.star_rounded,
                        isSelected: !_showPublic,
                        onTap: () => setState(() => _showPublic = false),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: _SegmentButton(
                        label: 'Publicos',
                        icon: Icons.public_rounded,
                        isSelected: _showPublic,
                        onTap: () {
                          setState(() => _showPublic = true);
                          challengesProvider.loadPublicChallenges();
                        },
                      ),
                    ),
                  ],
                ),
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
    if (provider.publicChallenges.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        children: const [
          SizedBox(height: 72),
          _SocialEmptyState(
            icon: Icons.emoji_events_rounded,
            title: 'Nenhum desafio publico',
            message:
                'Quando outros usuarios abrirem desafios, eles vao aparecer aqui.',
            iconColor: Color(0xFFFFC107),
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
        backgroundColor:
            isDarkMode ? AppTheme.darkCardColor : Colors.white,
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
                      value: 'PROTEIN_TARGET',
                      child: Text('Meta de Proteina')),
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
        backgroundColor:
            isDarkMode ? AppTheme.darkCardColor : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child:
                  Icon(Icons.qr_code_rounded, color: primaryColor, size: 20),
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
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryColor =
        isDarkMode ? AppTheme.primaryColorDarkMode : AppTheme.primaryColor;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      children: [
        const SizedBox(height: 72),
        _SocialEmptyState(
          icon: Icons.emoji_events_rounded,
          title: 'Nenhum desafio ativo',
          message:
              'Crie um desafio proprio ou entre por codigo para competir com amigos.',
          iconColor: const Color(0xFFFFC107),
          actions: [
            ElevatedButton.icon(
              onPressed: onCreateChallenge,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                backgroundColor: primaryColor,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              icon: const Icon(Icons.add_rounded, color: Colors.white),
              label: const Text('Criar Desafio',
                  style: TextStyle(
                      fontWeight: FontWeight.w600, color: Colors.white)),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: onJoinByCode,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                side: BorderSide(color: primaryColor, width: 1.5),
              ),
              icon: Icon(Icons.qr_code_rounded, color: primaryColor),
              label: Text('Entrar com Codigo',
                  style: TextStyle(
                      fontWeight: FontWeight.w600, color: primaryColor)),
            ),
          ],
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

  _ChallengeTypeInfo get _typeInfo {
    switch (challenge.type.toUpperCase()) {
      case 'LOGGING_STREAK':
        return _ChallengeTypeInfo(
          icon: Icons.local_fire_department_rounded,
          color: const Color(0xFFFF5722),
          emoji: '🔥',
        );
      case 'PROTEIN_TARGET':
        return _ChallengeTypeInfo(
          icon: Icons.fitness_center_rounded,
          color: const Color(0xFF9575CD),
          emoji: '💪',
        );
      case 'CALORIE_DEFICIT':
        return _ChallengeTypeInfo(
          icon: Icons.trending_down_rounded,
          color: const Color(0xFF4CAF50),
          emoji: '🎯',
        );
      case 'FIBER_TARGET':
        return _ChallengeTypeInfo(
          icon: Icons.eco_rounded,
          color: const Color(0xFF66BB6A),
          emoji: '🌿',
        );
      default:
        return _ChallengeTypeInfo(
          icon: Icons.emoji_events_rounded,
          color: const Color(0xFFFFC107),
          emoji: '🏆',
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDarkMode ? AppTheme.darkCardColor : Colors.white;
    final daysLeft = challenge.endDate.difference(DateTime.now()).inDays;
    final safeDaysLeft = daysLeft < 0 ? 0 : daysLeft;
    final typeInfo = _typeInfo;
    final primaryColor =
        isDarkMode ? AppTheme.primaryColorDarkMode : AppTheme.primaryColor;

    final daysColor = safeDaysLeft > 3
        ? const Color(0xFF4CAF50)
        : (safeDaysLeft > 0 ? const Color(0xFFFF9800) : const Color(0xFFE53935));

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        elevation: 2,
        shadowColor: Colors.black.withValues(alpha: isDarkMode ? 0.24 : 0.08),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDarkMode
                    ? AppTheme.darkBorderColor
                    : AppTheme.dividerColor,
              ),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Icone do tipo com emoji
                    Container(
                      width: 48,
                      height: 48,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: typeInfo.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: typeInfo.color.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Text(typeInfo.emoji,
                          style: const TextStyle(fontSize: 22)),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            challenge.name,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: isDarkMode
                                  ? Colors.white
                                  : AppTheme.textPrimaryColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.people_rounded,
                                  size: 14,
                                  color: isDarkMode
                                      ? Colors.white.withValues(alpha: 0.45)
                                      : AppTheme.textSecondaryColor),
                              const SizedBox(width: 4),
                              Text(
                                '${challenge.participantCount}/${challenge.maxParticipants} participantes',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDarkMode
                                      ? Colors.white.withValues(alpha: 0.45)
                                      : AppTheme.textSecondaryColor,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Badge de dias restantes
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: daysColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: daysColor.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.schedule_rounded,
                              size: 13, color: daysColor),
                          const SizedBox(width: 4),
                          Text(
                            '$safeDaysLeft d',
                            style: TextStyle(
                              color: daysColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (challenge.description != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDarkMode
                          ? AppTheme.darkComponentColor
                          : AppTheme.surfaceColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      challenge.description!,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color: isDarkMode
                            ? Colors.white.withValues(alpha: 0.65)
                            : AppTheme.textSecondaryColor,
                      ),
                    ),
                  ),
                ],
                if (showJoinButton && onJoin != null) ...[
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: onJoin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.login_rounded,
                          size: 18, color: Colors.white),
                      label: const Text('Entrar no Desafio',
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.white)),
                    ),
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

class _ChallengeTypeInfo {
  final IconData icon;
  final Color color;
  final String emoji;

  const _ChallengeTypeInfo({
    required this.icon,
    required this.color,
    required this.emoji,
  });
}

class _SegmentButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _SegmentButton({
    required this.label,
    required this.icon,
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
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: primaryColor.withValues(alpha: 0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected
                  ? Colors.white
                  : (isDarkMode
                      ? const Color(0xFFAEB7CE)
                      : AppTheme.textSecondaryColor),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: isSelected
                    ? Colors.white
                    : (isDarkMode
                        ? const Color(0xFFAEB7CE)
                        : AppTheme.textSecondaryColor),
              ),
            ),
          ],
        ),
      ),
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
