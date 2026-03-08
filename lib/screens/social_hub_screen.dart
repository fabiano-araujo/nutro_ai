import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/feed_provider.dart';
import '../providers/friends_provider.dart';
import '../providers/challenges_provider.dart';
import '../services/feed_service.dart';
import '../services/challenge_service.dart';
import '../theme/app_theme.dart';
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

const double _kSocialRadius = 28;

Color _socialPanelColor(bool isDarkMode) {
  return isDarkMode ? const Color(0xFF2A2D33) : Colors.white;
}

Color _socialMutedSurface(bool isDarkMode) {
  return isDarkMode ? const Color(0xFF343943) : AppTheme.surfaceColor;
}

Border _socialBorder(BuildContext context, bool isDarkMode, {double alpha = 0.08}) {
  return Border.all(
    color: isDarkMode
        ? Colors.white.withValues(alpha: alpha)
        : Theme.of(context).primaryColor.withValues(alpha: alpha + 0.02),
    width: 1,
  );
}

List<BoxShadow> _socialShadow(bool isDarkMode) {
  if (isDarkMode) {
    return const [];
  }

  return [
    BoxShadow(
      color: const Color(0xFF111827).withValues(alpha: 0.08),
      blurRadius: 24,
      offset: const Offset(0, 14),
    ),
  ];
}

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

    // Registrar callback para mudanca de aba via notificacao
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
    final backgroundGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: isDarkMode
          ? const [
              Color(0xFF121317),
              Color(0xFF1A1C22),
              Color(0xFF14161B),
            ]
          : [
              const Color(0xFFF8F4FD),
              AppTheme.backgroundColor,
              const Color(0xFFF1EBFA),
            ],
    );

    return DecoratedBox(
      decoration: BoxDecoration(gradient: backgroundGradient),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            Positioned(
              top: -110,
              right: -40,
              child: _SocialBackdropOrb(
                size: 240,
                color: Theme.of(context).primaryColor.withValues(
                      alpha: isDarkMode ? 0.16 : 0.18,
                    ),
              ),
            ),
            Positioned(
              top: 110,
              left: -70,
              child: _SocialBackdropOrb(
                size: 180,
                color: const Color(0xFFDDB9E8).withValues(
                  alpha: isDarkMode ? 0.08 : 0.18,
                ),
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: isDarkMode
                              ? [
                                  _socialPanelColor(true).withValues(alpha: 0.96),
                                  const Color(0xFF21242B).withValues(alpha: 0.96),
                                ]
                              : [
                                  Colors.white.withValues(alpha: 0.92),
                                  const Color(0xFFF4EEF9).withValues(alpha: 0.96),
                                ],
                        ),
                        borderRadius: BorderRadius.circular(_kSocialRadius),
                        border: _socialBorder(context, isDarkMode, alpha: 0.07),
                        boxShadow: _socialShadow(isDarkMode),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              if (widget.onOpenDrawer != null)
                                _SocialHeaderButton(
                                  icon: Icons.menu,
                                  onTap: widget.onOpenDrawer,
                                )
                              else
                                const SizedBox(width: 44),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Social',
                                      style: TextStyle(
                                        fontSize: 30,
                                        fontWeight: FontWeight.w700,
                                        color: isDarkMode ? Colors.white : Colors.black87,
                                        height: 1.1,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Feed, desafios e amigos em um lugar so',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: isDarkMode
                                            ? Colors.white.withValues(alpha: 0.62)
                                            : AppTheme.textSecondaryColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              _SocialHeaderButton(
                                icon: Icons.groups_2_outlined,
                                isActive: true,
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: isDarkMode
                                  ? Colors.white.withValues(alpha: 0.06)
                                  : AppTheme.surfaceColor.withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(22),
                              border: _socialBorder(context, isDarkMode, alpha: 0.05),
                            ),
                            child: TabBar(
                              controller: _tabController,
                              dividerColor: Colors.transparent,
                              indicatorSize: TabBarIndicatorSize.tab,
                              indicator: BoxDecoration(
                                color: Theme.of(context).primaryColor.withValues(
                                      alpha: isDarkMode ? 0.26 : 0.16,
                                    ),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: Theme.of(context).primaryColor.withValues(alpha: 0.2),
                                ),
                              ),
                              labelColor:
                                  isDarkMode ? Colors.white : AppTheme.textPrimaryColor,
                              unselectedLabelColor: isDarkMode
                                  ? Colors.white.withValues(alpha: 0.62)
                                  : AppTheme.textSecondaryColor,
                              labelStyle: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                              tabs: const [
                                Tab(icon: Icon(Icons.dynamic_feed), text: 'Feed'),
                                Tab(icon: Icon(Icons.emoji_events), text: 'Desafios'),
                                Tab(icon: Icon(Icons.people), text: 'Amigos'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.fromLTRB(12, 0, 12, 0),
                      decoration: BoxDecoration(
                        color: isDarkMode
                            ? const Color(0xFF16181D).withValues(alpha: 0.88)
                            : Colors.white.withValues(alpha: 0.54),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(32),
                        ),
                        border: _socialBorder(context, isDarkMode, alpha: 0.05),
                      ),
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(32),
                        ),
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            _FeedTab(),
                            _ChallengesTab(),
                            _FriendsTab(),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SocialBackdropOrb extends StatelessWidget {
  final double size;
  final Color color;

  const _SocialBackdropOrb({
    required this.size,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color,
              color.withValues(alpha: 0),
            ],
          ),
        ),
      ),
    );
  }
}

class _SocialHeaderButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final bool isActive;

  const _SocialHeaderButton({
    required this.icon,
    this.onTap,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: isActive
          ? Theme.of(context).primaryColor.withValues(alpha: isDarkMode ? 0.2 : 0.12)
          : (isDarkMode
              ? Colors.white.withValues(alpha: 0.06)
              : AppTheme.surfaceColor.withValues(alpha: 0.95)),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isActive
              ? Theme.of(context).primaryColor.withValues(alpha: 0.2)
              : (isDarkMode
                  ? Colors.white.withValues(alpha: 0.08)
                  : Theme.of(context).primaryColor.withValues(alpha: 0.05)),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(
            icon,
            color: isDarkMode ? Colors.white : AppTheme.textPrimaryColor,
          ),
        ),
      ),
    );
  }
}

class _SocialEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final List<Widget> actions;

  const _SocialEmptyState({
    required this.icon,
    required this.title,
    this.message,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: _socialPanelColor(isDarkMode).withValues(alpha: isDarkMode ? 0.96 : 0.94),
            borderRadius: BorderRadius.circular(24),
            border: _socialBorder(context, isDarkMode, alpha: 0.06),
            boxShadow: _socialShadow(isDarkMode),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Icon(
                  icon,
                  size: 34,
                  color: Theme.of(context).primaryColor,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
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
                        ? Colors.white.withValues(alpha: 0.68)
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
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            itemCount: feedProvider.activities.length + (feedProvider.hasMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == feedProvider.activities.length) {
                // Load more indicator
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
                onReact: (emoji) => feedProvider.toggleReaction(activity.id, emoji),
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
          icon: Icons.dynamic_feed_outlined,
          title: 'Seu feed esta vazio',
          message: 'Adicione amigos para ver atividades, streaks e desafios por aqui.',
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

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _socialPanelColor(isDarkMode).withValues(alpha: isDarkMode ? 0.96 : 0.98),
        borderRadius: BorderRadius.circular(24),
        border: _socialBorder(context, isDarkMode, alpha: 0.06),
        boxShadow: _socialShadow(isDarkMode),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: Theme.of(context).primaryColor.withValues(alpha: 0.16),
                  child: Text(
                    activity.user.name.isNotEmpty
                        ? activity.user.name[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                      color: Theme.of(context).primaryColor,
                      fontWeight: FontWeight.w700,
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
                          color: isDarkMode ? Colors.white : AppTheme.textPrimaryColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatTime(activity.createdAt),
                        style: TextStyle(
                          fontSize: 12,
                          color: isDarkMode
                              ? Colors.white.withValues(alpha: 0.5)
                              : AppTheme.textSecondaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _socialMutedSurface(isDarkMode),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(child: _buildTypeIcon()),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _socialMutedSurface(isDarkMode),
                borderRadius: BorderRadius.circular(20),
                border: _socialBorder(context, isDarkMode, alpha: 0.04),
              ),
              child: _buildActivityContent(context, isDarkMode),
            ),
            const SizedBox(height: 14),
            _buildReactionsBar(context, isDarkMode),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeIcon() {
    IconData icon;
    Color color;
    final activityType = activity.type.toUpperCase();

    switch (activityType) {
      case 'CHECKIN_PROTEIN':
        icon = Icons.fitness_center;
        color = Colors.orange;
        break;
      case 'CHECKIN_GOAL':
        icon = Icons.flag;
        color = Colors.green;
        break;
      case 'CHECKIN_OVER':
        icon = Icons.warning;
        color = Colors.red;
        break;
      case 'STREAK_MILESTONE':
        icon = Icons.local_fire_department;
        color = Colors.deepOrange;
        break;
      case 'FRIEND_STREAK':
        icon = Icons.favorite;
        color = Colors.pink;
        break;
      case 'CHALLENGE_JOIN':
        icon = Icons.emoji_events;
        color = Colors.amber;
        break;
      default:
        icon = Icons.check_circle;
        color = Colors.blue;
    }

    return Icon(icon, color: color, size: 24);
  }

  Widget _buildActivityContent(BuildContext context, bool isDarkMode) {
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
            fontSize: 16,
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
        ),
        if (detail != null) ...[
          const SizedBox(height: 4),
          Text(
            detail,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).primaryColor,
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

        return InkWell(
          onTap: () => onReact(emoji),
          borderRadius: BorderRadius.circular(999),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: hasReacted
                  ? Theme.of(context).primaryColor.withValues(alpha: 0.16)
                  : _socialMutedSurface(isDarkMode),
              borderRadius: BorderRadius.circular(999),
              border: hasReacted
                  ? Border.all(
                      color: Theme.of(context).primaryColor.withValues(alpha: 0.22),
                    )
                  : _socialBorder(context, isDarkMode, alpha: 0.04),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(emoji, style: const TextStyle(fontSize: 16)),
                if (count > 0) ...[
                  const SizedBox(width: 6),
                  Text(
                    count.toString(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDarkMode
                          ? Colors.white.withValues(alpha: 0.72)
                          : AppTheme.textSecondaryColor,
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
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? Colors.white.withValues(alpha: 0.04)
                      : Colors.white.withValues(alpha: 0.56),
                  borderRadius: BorderRadius.circular(22),
                  border: _socialBorder(context, isDarkMode, alpha: 0.05),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _ToggleButton(
                        label: 'Meus Desafios',
                        isSelected: !_showPublic,
                        onTap: () => setState(() => _showPublic = false),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _ToggleButton(
                        label: 'Publicos',
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
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        itemCount: provider.myChallenges.length,
        itemBuilder: (context, index) {
          final challenge = provider.myChallenges[index];
          return _ChallengeCard(
            challenge: challenge,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ChallengeDetailScreen(challengeId: challenge.id),
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
            icon: Icons.emoji_events_outlined,
            title: 'Nenhum desafio publico disponivel',
            message: 'Quando outros usuarios abrirem desafios, eles vao aparecer aqui.',
          ),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
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

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _socialPanelColor(Theme.of(ctx).brightness == Brightness.dark),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Criar Desafio'),
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
                  DropdownMenuItem(value: 'LOGGING_STREAK', child: Text('Streak de Registro')),
                  DropdownMenuItem(value: 'PROTEIN_TARGET', child: Text('Meta de Proteina')),
                  DropdownMenuItem(value: 'CALORIE_DEFICIT', child: Text('Deficit Calorico')),
                  DropdownMenuItem(value: 'FIBER_TARGET', child: Text('Meta de Fibra')),
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
                  description: descController.text.isEmpty ? null : descController.text,
                  type: selectedType,
                );
                Navigator.pop(ctx);
              }
            },
            child: const Text('Criar'),
          ),
        ],
      ),
    );
  }

  void _showJoinByCodeDialog(BuildContext context) {
    final codeController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _socialPanelColor(Theme.of(ctx).brightness == Brightness.dark),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Entrar com Codigo'),
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
                final success = await provider.joinByCode(codeController.text.toUpperCase());
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
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      children: [
        const SizedBox(height: 72),
        _SocialEmptyState(
          icon: Icons.emoji_events_outlined,
          title: 'Nenhum desafio ativo',
          message: 'Crie um desafio proprio ou entre por codigo para competir com amigos.',
          actions: [
            ElevatedButton.icon(
              onPressed: onCreateChallenge,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              ),
              icon: const Icon(Icons.add),
              label: const Text('Criar Desafio'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onJoinByCode,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              ),
              icon: const Icon(Icons.qr_code),
              label: const Text('Entrar com Codigo'),
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

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final daysLeft = challenge.endDate.difference(DateTime.now()).inDays;
    final safeDaysLeft = daysLeft < 0 ? 0 : daysLeft;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _socialPanelColor(isDarkMode).withValues(alpha: isDarkMode ? 0.96 : 0.98),
        borderRadius: BorderRadius.circular(24),
        border: _socialBorder(context, isDarkMode, alpha: 0.06),
        boxShadow: _socialShadow(isDarkMode),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.emoji_events,
                      color: Colors.amber,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      challenge.name,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: isDarkMode ? Colors.white : AppTheme.textPrimaryColor,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: (safeDaysLeft > 3 ? Colors.green : Colors.orange)
                          .withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: (safeDaysLeft > 3 ? Colors.green : Colors.orange)
                            .withValues(alpha: 0.28),
                      ),
                    ),
                    child: Text(
                      '$safeDaysLeft dias',
                      style: TextStyle(
                        color: safeDaysLeft > 3 ? Colors.green[700] : Colors.orange[800],
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              if (challenge.description != null) ...[
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _socialMutedSurface(isDarkMode),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Text(
                    challenge.description!,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.45,
                      color: isDarkMode
                          ? Colors.white.withValues(alpha: 0.72)
                          : AppTheme.textSecondaryColor,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.people,
                    size: 16,
                    color: isDarkMode
                        ? Colors.white.withValues(alpha: 0.5)
                        : AppTheme.textSecondaryColor,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${challenge.participantCount}/${challenge.maxParticipants}',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDarkMode
                          ? Colors.white.withValues(alpha: 0.5)
                          : AppTheme.textSecondaryColor,
                    ),
                  ),
                  const Spacer(),
                  if (showJoinButton && onJoin != null)
                    ElevatedButton(
                      onPressed: onJoin,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        minimumSize: const Size(0, 36),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text('Entrar'),
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

class _ToggleButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ToggleButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).primaryColor.withValues(alpha: isDarkMode ? 0.22 : 0.16)
              : (isDarkMode
                  ? Colors.white.withValues(alpha: 0.04)
                  : Colors.white.withValues(alpha: 0.72)),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? Theme.of(context).primaryColor.withValues(alpha: 0.22)
                : (isDarkMode
                    ? Colors.white.withValues(alpha: 0.05)
                    : Theme.of(context).primaryColor.withValues(alpha: 0.04)),
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: isSelected
                  ? (isDarkMode ? Colors.white : Theme.of(context).primaryColor)
                  : isDarkMode
                      ? Colors.white.withValues(alpha: 0.7)
                      : AppTheme.textSecondaryColor,
            ),
          ),
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
