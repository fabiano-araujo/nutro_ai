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

    return Scaffold(
      appBar: AppBar(
        backgroundColor: isDarkMode ? AppTheme.darkBackgroundColor : Colors.white,
        elevation: 0,
        leading: widget.onOpenDrawer != null
            ? IconButton(
                icon: Icon(Icons.menu,
                    color: isDarkMode ? Colors.white : Colors.black),
                onPressed: widget.onOpenDrawer,
              )
            : null,
        title: Text(
          'Social',
          style: TextStyle(
            color: isDarkMode ? Colors.white : Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Theme.of(context).primaryColor,
          labelColor: Theme.of(context).primaryColor,
          unselectedLabelColor: isDarkMode ? Colors.white60 : Colors.grey,
          tabs: const [
            Tab(icon: Icon(Icons.dynamic_feed), text: 'Feed'),
            Tab(icon: Icon(Icons.emoji_events), text: 'Desafios'),
            Tab(icon: Icon(Icons.people), text: 'Amigos'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _FeedTab(),
          _ChallengesTab(),
          _FriendsTab(),
        ],
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
          return _EmptyFeedState();
        }

        return RefreshIndicator(
          onRefresh: feedProvider.refresh,
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
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
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.dynamic_feed_outlined,
              size: 80,
              color: isDarkMode ? Colors.white24 : Colors.grey[300],
            ),
            const SizedBox(height: 16),
            Text(
              'Seu feed esta vazio',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Adicione amigos para ver suas atividades aqui!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isDarkMode ? Colors.white60 : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
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

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: isDarkMode ? AppTheme.darkCardColor : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Theme.of(context).primaryColor.withOpacity(0.2),
                  child: Text(
                    activity.user.name.isNotEmpty
                        ? activity.user.name[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                      color: Theme.of(context).primaryColor,
                      fontWeight: FontWeight.bold,
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
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? Colors.white : Colors.black87,
                        ),
                      ),
                      Text(
                        _formatTime(activity.createdAt),
                        style: TextStyle(
                          fontSize: 12,
                          color: isDarkMode ? Colors.white54 : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildTypeIcon(),
              ],
            ),

            const SizedBox(height: 12),

            // Content
            _buildActivityContent(context, isDarkMode),

            const SizedBox(height: 12),

            // Reactions
            _buildReactionsBar(context, isDarkMode),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeIcon() {
    IconData icon;
    Color color;

    switch (activity.type) {
      case 'checkin_protein':
        icon = Icons.fitness_center;
        color = Colors.orange;
        break;
      case 'checkin_goal':
        icon = Icons.flag;
        color = Colors.green;
        break;
      case 'checkin_over':
        icon = Icons.warning;
        color = Colors.red;
        break;
      case 'streak_milestone':
        icon = Icons.local_fire_department;
        color = Colors.deepOrange;
        break;
      case 'friend_streak':
        icon = Icons.favorite;
        color = Colors.pink;
        break;
      case 'challenge_join':
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

    switch (activity.type) {
      case 'checkin_protein':
        message = 'Bateu a meta de proteina!';
        if (!activity.isPrivate && activity.data != null) {
          final protein = activity.data!['protein'];
          final goal = activity.data!['proteinGoal'];
          if (protein != null && goal != null) {
            detail = '${protein}g / ${goal}g';
          }
        }
        break;
      case 'checkin_goal':
        message = 'Atingiu o objetivo calorico!';
        if (!activity.isPrivate && activity.data != null) {
          final cal = activity.data!['calories'];
          final goal = activity.data!['calorieGoal'];
          if (cal != null && goal != null) {
            detail = '$cal / $goal kcal';
          }
        }
        break;
      case 'checkin_over':
        message = 'Registrou o dia';
        break;
      case 'streak_milestone':
        final days = activity.data?['days'] ?? 0;
        message = 'Alcancou $days dias de streak!';
        break;
      case 'friend_streak':
        final friendName = activity.data?['friendName'] ?? 'amigo';
        final days = activity.data?['days'] ?? 0;
        message = 'Duo streak de $days dias com $friendName!';
        break;
      case 'challenge_join':
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

    return Row(
      children: [
        // Emoji buttons
        ...emojis.map((emoji) {
          final count = activity.reactionCounts[emoji] ?? 0;
          final hasReacted = activity.hasReacted(emoji);

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              onTap: () => onReact(emoji),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: hasReacted
                      ? Theme.of(context).primaryColor.withOpacity(0.2)
                      : isDarkMode
                          ? Colors.white10
                          : Colors.grey[100],
                  borderRadius: BorderRadius.circular(20),
                  border: hasReacted
                      ? Border.all(color: Theme.of(context).primaryColor)
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(emoji, style: const TextStyle(fontSize: 16)),
                    if (count > 0) ...[
                      const SizedBox(width: 4),
                      Text(
                        count.toString(),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: isDarkMode ? Colors.white70 : Colors.black54,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        }),
      ],
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
            // Toggle
            Padding(
              padding: const EdgeInsets.all(16),
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

            // Content
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
        padding: const EdgeInsets.symmetric(horizontal: 16),
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
      return Center(
        child: Text(
          'Nenhum desafio publico disponivel',
          style: TextStyle(
            color: isDarkMode ? Colors.white60 : Colors.grey,
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
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
                value: selectedType,
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
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.emoji_events_outlined,
              size: 80,
              color: isDarkMode ? Colors.white24 : Colors.grey[300],
            ),
            const SizedBox(height: 16),
            Text(
              'Nenhum desafio ativo',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onCreateChallenge,
              icon: const Icon(Icons.add),
              label: const Text('Criar Desafio'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onJoinByCode,
              icon: const Icon(Icons.qr_code),
              label: const Text('Entrar com Codigo'),
            ),
          ],
        ),
      ),
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

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: isDarkMode ? AppTheme.darkCardColor : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.emoji_events,
                    color: Colors.amber,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      challenge.name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: daysLeft > 3 ? Colors.green : Colors.orange,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$daysLeft dias',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              if (challenge.description != null) ...[
                const SizedBox(height: 8),
                Text(
                  challenge.description!,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDarkMode ? Colors.white60 : Colors.grey[600],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.people,
                    size: 16,
                    color: isDarkMode ? Colors.white54 : Colors.grey,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${challenge.participantCount}/${challenge.maxParticipants}',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDarkMode ? Colors.white54 : Colors.grey,
                    ),
                  ),
                  const Spacer(),
                  if (showJoinButton && onJoin != null)
                    ElevatedButton(
                      onPressed: onJoin,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        minimumSize: const Size(0, 32),
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
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).primaryColor
              : isDarkMode
                  ? Colors.white10
                  : Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: isSelected
                  ? Colors.white
                  : isDarkMode
                      ? Colors.white70
                      : Colors.black87,
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

        return FriendsScreen(isEmbedded: true);
      },
    );
  }
}
