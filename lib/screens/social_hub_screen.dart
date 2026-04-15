import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/feed_provider.dart';
import '../providers/friends_provider.dart';
import '../providers/challenges_provider.dart';
import '../providers/streak_provider.dart';
import '../services/auth_service.dart';
import '../services/feed_service.dart';
import '../services/challenge_service.dart';
import '../theme/app_theme.dart';
import '../widgets/challenge_progress_widgets.dart';
import '../widgets/streak_display.dart';
import '../widgets/standard_page_header.dart';
import '../widgets/diet_style_message_state.dart';

import 'friends_screen.dart';
import 'challenge_detail_screen.dart';
import 'login_screen.dart';

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
  // Apenas 2 abas: Social e Desafios
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabChanged);

    // Compatibilidade: índices externos 0-3 mapeados para 0-1
    socialTabController.tabChangeCallback = (index) {
      if (!mounted) return;
      if (index <= 1) {
        _tabController.animateTo(0); // Social
      } else {
        _tabController.animateTo(1); // Desafios
      }
    };

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshData();
    });
  }

  void _handleTabChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _refreshData() async {
    await Future.wait([
      context.read<StreakProvider>().refresh(),
      context.read<FeedProvider>().refresh(),
      context.read<FriendsProvider>().refresh(),
      context.read<ChallengesProvider>().loadOverview(),
    ]);
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
    final authService = context.watch<AuthService>();
    final primaryColor =
        isDarkMode ? AppTheme.primaryColorDarkMode : AppTheme.primaryColor;

    // Tela de login se não autenticado
    if (!authService.isAuthenticated) {
      return Scaffold(
        backgroundColor: isDarkMode
            ? AppTheme.darkBackgroundColor
            : AppTheme.backgroundColor,
        body: SafeArea(
          child: Column(
            children: [
              StandardPageHeader(
                title: 'Comunidade',
                onOpenDrawer: widget.onOpenDrawer,
              ),
              Expanded(
                child: DietStyleMessageState(
                  title: 'Entre para acessar a Comunidade',
                  message:
                      'Faça login para ver seus desafios, acompanhar amigos e manter suas sequências.',
                  fallbackIcon: Icons.people_alt_rounded,
                  primaryActionLabel: 'Entrar',
                  primaryActionIcon: Icons.login_rounded,
                  onPrimaryAction: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  ),
                  topSpacing: 56,
                  pinActionsToBottom: true,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor:
          isDarkMode ? AppTheme.darkBackgroundColor : AppTheme.backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            StandardPageHeader(
              title: 'Comunidade',
              onOpenDrawer: widget.onOpenDrawer,
            ),
            // Tab bar simples com só 2 abas
            Container(
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: isDarkMode
                        ? AppTheme.darkBorderColor
                        : AppTheme.dividerColor,
                    width: 1,
                  ),
                ),
              ),
              child: TabBar(
                controller: _tabController,
                labelColor: primaryColor,
                unselectedLabelColor:
                    isDarkMode ? Colors.white38 : Colors.grey[500],
                indicatorColor: primaryColor,
                indicatorWeight: 2.5,
                indicatorSize: TabBarIndicatorSize.label,
                labelStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                ),
                tabs: const [
                  Tab(text: 'Social'),
                  Tab(text: 'Desafios'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _SocialTab(onRefresh: _refreshData),
                  _ChallengesTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== ABA SOCIAL ====================
// Mostra: sequência + feed de atividades dos amigos.
// Gerenciar amigos: botão no topo da lista.
class _SocialTab extends StatelessWidget {
  final Future<void> Function() onRefresh;

  const _SocialTab({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Consumer2<FeedProvider, FriendsProvider>(
      builder: (context, feedProvider, friendsProvider, _) {
        final isLoading =
            feedProvider.isLoading && feedProvider.activities.isEmpty;

        if (isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        return RefreshIndicator(
          onRefresh: onRefresh,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // Card de sequência sempre no topo
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16, 20, 16, 0),
                  child: StreakDetailCard(),
                ),
              ),

              // Cabeçalho "Amigos" com botão de gerenciar
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 28, 16, 12),
                  child: Row(
                    children: [
                      Text(
                        'Amigos',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white
                              : AppTheme.textPrimaryColor,
                        ),
                      ),
                      const Spacer(),
                      _FriendsHeaderButton(),
                    ],
                  ),
                ),
              ),

              // Conteúdo: feed ou estado vazio
              if (feedProvider.error != null && feedProvider.activities.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _InfoCard(
                      icon: Icons.cloud_off_rounded,
                      message: 'Não foi possível carregar. Puxe para atualizar.',
                    ),
                  ),
                )
              else if (feedProvider.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _EmptyFriendsCard(),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
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
                        return _ActivityCard(
                          activity: activity,
                          onReact: (emoji) =>
                              feedProvider.toggleReaction(activity.id, emoji),
                        );
                      },
                      childCount: feedProvider.activities.length +
                          (feedProvider.hasMore ? 1 : 0),
                    ),
                  ),
                ),

              const SliverToBoxAdapter(child: SizedBox(height: 40)),
            ],
          ),
        );
      },
    );
  }
}

/// Botão no header que abre a tela de amigos
class _FriendsHeaderButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryColor =
        isDarkMode ? AppTheme.primaryColorDarkMode : AppTheme.primaryColor;

    return Consumer<FriendsProvider>(
      builder: (context, friendsProvider, _) {
        final hasPending = friendsProvider.hasPendingRequests;

        return GestureDetector(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const FriendsScreen(isEmbedded: false),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hasPending)
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(right: 6),
                  decoration: const BoxDecoration(
                    color: Colors.redAccent,
                    shape: BoxShape.circle,
                  ),
                ),
              Text(
                hasPending ? 'Pedidos pendentes' : 'Gerenciar amigos',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: primaryColor,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Card vazio quando não há amigos/feed
class _EmptyFriendsCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryColor =
        isDarkMode ? AppTheme.primaryColorDarkMode : AppTheme.primaryColor;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
      decoration: BoxDecoration(
        color: isDarkMode ? AppTheme.darkCardColor : Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Icon(
            Icons.people_alt_rounded,
            size: 48,
            color: primaryColor.withValues(alpha: 0.35),
          ),
          const SizedBox(height: 14),
          Text(
            'Adicione amigos para começar',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDarkMode ? Colors.white : AppTheme.textPrimaryColor,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Quando seus amigos registrarem refeições ou baterem metas, você vai ver aqui.',
            style: TextStyle(
              fontSize: 13,
              color: isDarkMode ? Colors.white54 : AppTheme.textSecondaryColor,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const FriendsScreen(isEmbedded: false),
                ),
              ),
              icon: const Icon(Icons.person_add_rounded,
                  size: 18, color: Colors.white),
              label: const Text(
                'Adicionar amigos',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Card de informação simples (erro, aviso)
class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String message;

  const _InfoCard({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? AppTheme.darkCardColor : Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon,
              size: 24,
              color: isDarkMode ? Colors.white38 : Colors.grey[400]),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 13,
                color:
                    isDarkMode ? Colors.white54 : AppTheme.textSecondaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ==================== CARD DE ATIVIDADE ====================
class _ActivityCard extends StatelessWidget {
  final FeedActivity activity;
  final Function(String) onReact;

  const _ActivityCard({required this.activity, required this.onReact});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final typeInfo = _typeInfo;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? AppTheme.darkCardColor : Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabeçalho
          Row(
            children: [
              CircleAvatar(
                radius: 19,
                backgroundColor:
                    Theme.of(context).primaryColor.withValues(alpha: 0.12),
                child: Text(
                  activity.user.name.isNotEmpty
                      ? activity.user.name[0].toUpperCase()
                      : '?',
                  style: TextStyle(
                    color: Theme.of(context).primaryColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
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
                        fontSize: 12,
                        color: isDarkMode
                            ? Colors.white38
                            : AppTheme.textSecondaryColor,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: typeInfo.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(typeInfo.icon, color: typeInfo.color, size: 17),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Mensagem da atividade
          Text(
            _message,
            style: TextStyle(
              fontSize: 14,
              color: isDarkMode ? Colors.white : AppTheme.textPrimaryColor,
            ),
          ),
          if (_detail != null) ...[
            const SizedBox(height: 3),
            Text(
              _detail!,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: typeInfo.color,
              ),
            ),
          ],
          const SizedBox(height: 10),
          // Reações
          _ReactionsRow(
              activity: activity, onReact: onReact, isDarkMode: isDarkMode),
        ],
      ),
    );
  }

  _TypeInfo get _typeInfo {
    switch (activity.type.toUpperCase()) {
      case 'CHECKIN_PROTEIN':
        return _TypeInfo(Icons.fitness_center_rounded, const Color(0xFFFF9800));
      case 'CHECKIN_GOAL':
        return _TypeInfo(Icons.flag_rounded, const Color(0xFF4CAF50));
      case 'CHECKIN_OVER':
        return _TypeInfo(Icons.check_circle_rounded, const Color(0xFF2196F3));
      case 'STREAK_MILESTONE':
        return _TypeInfo(
            Icons.local_fire_department_rounded, const Color(0xFFFF5722));
      case 'FRIEND_STREAK':
        return _TypeInfo(Icons.favorite_rounded, const Color(0xFFE91E63));
      case 'CHALLENGE_JOIN':
        return _TypeInfo(Icons.emoji_events_rounded, const Color(0xFFFFC107));
      default:
        return _TypeInfo(Icons.check_circle_rounded, const Color(0xFF2196F3));
    }
  }

  String get _message {
    switch (activity.type.toUpperCase()) {
      case 'CHECKIN_PROTEIN':
        return 'Bateu a meta de proteína!';
      case 'CHECKIN_GOAL':
        return 'Atingiu o objetivo calórico!';
      case 'CHECKIN_OVER':
        return 'Registrou as refeições do dia';
      case 'STREAK_MILESTONE':
        final days = activity.data?['days'] ?? 0;
        return 'Alcançou $days dias de sequência!';
      case 'FRIEND_STREAK':
        final friendName = activity.data?['friendName'] ?? 'amigo';
        final days = activity.data?['days'] ?? 0;
        return 'Sequência em duo de $days dias com $friendName!';
      case 'CHALLENGE_JOIN':
        final challengeName = activity.data?['challengeName'] ?? 'desafio';
        return 'Entrou no desafio "$challengeName"';
      default:
        return 'Atividade no app';
    }
  }

  String? get _detail {
    if (activity.isPrivate || activity.data == null) return null;
    switch (activity.type.toUpperCase()) {
      case 'CHECKIN_PROTEIN':
        final p = activity.data!['protein'];
        final g = activity.data!['proteinGoal'];
        if (p != null && g != null) return '${p}g de ${g}g';
        return null;
      case 'CHECKIN_GOAL':
        final c = activity.data!['calories'];
        final g = activity.data!['calorieGoal'];
        if (c != null && g != null) return '$c de $g kcal';
        return null;
      default:
        return null;
    }
  }

  String _formatTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'agora';
    if (diff.inMinutes < 60) return '${diff.inMinutes}min atrás';
    if (diff.inHours < 24) return '${diff.inHours}h atrás';
    if (diff.inDays == 1) return 'ontem';
    if (diff.inDays < 7) return '${diff.inDays} dias atrás';
    return '${dt.day}/${dt.month}';
  }
}

class _TypeInfo {
  final IconData icon;
  final Color color;
  const _TypeInfo(this.icon, this.color);
}

class _ReactionsRow extends StatelessWidget {
  final FeedActivity activity;
  final Function(String) onReact;
  final bool isDarkMode;

  const _ReactionsRow(
      {required this.activity,
      required this.onReact,
      required this.isDarkMode});

  @override
  Widget build(BuildContext context) {
    final emojis = ['👏', '🔥', '💪', '😅'];
    final primaryColor = isDarkMode
        ? AppTheme.primaryColorDarkMode
        : AppTheme.primaryColor;

    return Row(
      children: emojis.map((emoji) {
        final count = activity.reactionCounts[emoji] ?? 0;
        final reacted = activity.hasReacted(emoji);

        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: GestureDetector(
            onTap: () => onReact(emoji),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: reacted
                    ? primaryColor.withValues(alpha: 0.1)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: reacted
                      ? primaryColor.withValues(alpha: 0.3)
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
                      '$count',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: reacted
                            ? primaryColor
                            : (isDarkMode
                                ? Colors.white54
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
}

// ==================== ABA DESAFIOS ====================
class _ChallengesTab extends StatefulWidget {
  @override
  State<_ChallengesTab> createState() => _ChallengesTabState();
}

class _ChallengesTabState extends State<_ChallengesTab> {
  bool _showPublic = false;

  @override
  Widget build(BuildContext context) {
    return Consumer<ChallengesProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading && provider.myChallenges.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        return Column(
          children: [
            // Botões de ação
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: _PrimaryButton(
                      label: 'Criar desafio',
                      icon: Icons.add_rounded,
                      onTap: () => _showCreateDialog(context),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _OutlineButton(
                      label: 'Entrar com código',
                      icon: Icons.qr_code_rounded,
                      onTap: () => _showJoinCodeDialog(context),
                    ),
                  ),
                ],
              ),
            ),

            // Toggle Meus / Públicos
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: _SegmentedToggle(
                options: const ['Meus desafios', 'Públicos'],
                selectedIndex: _showPublic ? 1 : 0,
                onChanged: (i) {
                  setState(() => _showPublic = i == 1);
                  if (i == 1) provider.loadPublicChallenges();
                },
              ),
            ),

            // Lista
            Expanded(
              child: _showPublic
                  ? _PublicChallengesList(provider: provider)
                  : _MyChallengesList(
                      provider: provider,
                      onCreateTap: () => _showCreateDialog(context),
                      onCodeTap: () => _showJoinCodeDialog(context),
                    ),
            ),
          ],
        );
      },
    );
  }

  void _showCreateDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String type = 'LOGGING_STREAK';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark ? AppTheme.primaryColorDarkMode : AppTheme.primaryColor;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppTheme.darkCardColor : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Novo desafio',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nome do desafio',
                  hintText: 'Ex: 7 dias registrando',
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: descCtrl,
                decoration:
                    const InputDecoration(labelText: 'Descrição (opcional)'),
                maxLines: 2,
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: type,
                decoration: const InputDecoration(labelText: 'Tipo'),
                items: const [
                  DropdownMenuItem(
                      value: 'LOGGING_STREAK',
                      child: Text('Registrar refeições')),
                  DropdownMenuItem(
                      value: 'PROTEIN_TARGET', child: Text('Meta de proteína')),
                  DropdownMenuItem(
                      value: 'CALORIE_DEFICIT', child: Text('Déficit calórico')),
                  DropdownMenuItem(
                      value: 'FIBER_TARGET', child: Text('Meta de fibra')),
                ],
                onChanged: (v) => type = v ?? 'LOGGING_STREAK',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.isNotEmpty) {
                await context.read<ChallengesProvider>().createChallenge(
                      name: nameCtrl.text,
                      description:
                          descCtrl.text.isEmpty ? null : descCtrl.text,
                      type: type,
                    );
                Navigator.pop(ctx);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: primary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child:
                const Text('Criar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showJoinCodeDialog(BuildContext context) {
    final codeCtrl = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark ? AppTheme.primaryColorDarkMode : AppTheme.primaryColor;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppTheme.darkCardColor : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Entrar com código',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        content: TextField(
          controller: codeCtrl,
          decoration: const InputDecoration(
            labelText: 'Código do desafio',
            hintText: 'Ex: ABC12345',
          ),
          textCapitalization: TextCapitalization.characters,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              if (codeCtrl.text.isNotEmpty) {
                final ok = await context
                    .read<ChallengesProvider>()
                    .joinByCode(codeCtrl.text.toUpperCase());
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content:
                          Text(ok ? 'Entrou no desafio!' : 'Código inválido')),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: primary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child:
                const Text('Entrar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _MyChallengesList extends StatelessWidget {
  final ChallengesProvider provider;
  final VoidCallback onCreateTap;
  final VoidCallback onCodeTap;

  const _MyChallengesList({
    required this.provider,
    required this.onCreateTap,
    required this.onCodeTap,
  });

  @override
  Widget build(BuildContext context) {
    if (provider.myChallenges.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          _EmptyChallengesCard(
            onCreateTap: onCreateTap,
            onCodeTap: onCodeTap,
          ),
        ],
      );
    }

    return RefreshIndicator(
      onRefresh: provider.refresh,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
        itemCount: provider.myChallenges.length,
        itemBuilder: (context, i) => _ChallengeCard(
          challenge: provider.myChallenges[i],
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChallengeDetailScreen(
                  challengeId: provider.myChallenges[i].id),
            ),
          ),
        ),
      ),
    );
  }
}

class _PublicChallengesList extends StatelessWidget {
  final ChallengesProvider provider;

  const _PublicChallengesList({required this.provider});

  @override
  Widget build(BuildContext context) {
    if (provider.publicChallenges.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          _InfoCard(
            icon: Icons.emoji_events_rounded,
            message: 'Nenhum desafio público disponível no momento.',
          ),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
      itemCount: provider.publicChallenges.length,
      itemBuilder: (context, i) => _ChallengeCard(
        challenge: provider.publicChallenges[i],
        showJoinButton: true,
        onTap: () {},
        onJoin: () => provider.joinChallenge(provider.publicChallenges[i].id),
      ),
    );
  }
}

class _EmptyChallengesCard extends StatelessWidget {
  final VoidCallback onCreateTap;
  final VoidCallback onCodeTap;

  const _EmptyChallengesCard({
    required this.onCreateTap,
    required this.onCodeTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryColor =
        isDarkMode ? AppTheme.primaryColorDarkMode : AppTheme.primaryColor;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
      decoration: BoxDecoration(
        color: isDarkMode ? AppTheme.darkCardColor : Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Icon(
            Icons.emoji_events_rounded,
            size: 48,
            color: primaryColor.withValues(alpha: 0.35),
          ),
          const SizedBox(height: 14),
          Text(
            'Nenhum desafio ativo',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDarkMode ? Colors.white : AppTheme.textPrimaryColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Crie um desafio ou entre em um com um código de amigo.',
            style: TextStyle(
              fontSize: 13,
              color: isDarkMode ? Colors.white54 : AppTheme.textSecondaryColor,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onCreateTap,
              icon: const Icon(Icons.add_rounded, size: 18, color: Colors.white),
              label: const Text('Criar desafio',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onCodeTap,
              icon: Icon(Icons.qr_code_rounded, size: 18, color: primaryColor),
              label: Text('Entrar com código',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: primaryColor)),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: primaryColor.withValues(alpha: 0.4)),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
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

  IconData get _icon {
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark ? AppTheme.primaryColorDarkMode : AppTheme.primaryColor;
    final daysLeft =
        challenge.endDate.difference(DateTime.now()).inDays.clamp(0, 9999);
    final daysColor = daysLeft > 3
        ? const Color(0xFF4CAF50)
        : (daysLeft > 0 ? const Color(0xFFFF9800) : const Color(0xFFE53935));

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkCardColor : Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(_icon, color: primary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        challenge.name,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : AppTheme.textPrimaryColor,
                        ),
                      ),
                      Text(
                        '${challenge.participantCount}/${challenge.maxParticipants} participantes',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? Colors.white38
                              : AppTheme.textSecondaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: daysColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$daysLeft dias',
                    style: TextStyle(
                      color: daysColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            if (challenge.progress != null || challenge.objective != null) ...[
              const SizedBox(height: 12),
              ChallengeProgressPanel(challenge: challenge, compact: true),
            ],
            if (showJoinButton && onJoin != null) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onJoin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Participar',
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: Colors.white)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ==================== WIDGETS DE SUPORTE ====================

class _SegmentedToggle extends StatelessWidget {
  final List<String> options;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  const _SegmentedToggle({
    required this.options,
    required this.selectedIndex,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark ? AppTheme.primaryColorDarkMode : AppTheme.primaryColor;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCardColor : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        children: List.generate(options.length, (i) {
          final selected = i == selectedIndex;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: selected
                      ? (isDark ? AppTheme.darkBackgroundColor : Colors.white)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 6,
                            offset: const Offset(0, 1),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  options[i],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight:
                        selected ? FontWeight.w600 : FontWeight.w400,
                    color: selected
                        ? primary
                        : (isDark ? Colors.white38 : Colors.grey[500]),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _PrimaryButton(
      {required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark ? AppTheme.primaryColorDarkMode : AppTheme.primaryColor;

    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18, color: Colors.white),
      label: Text(label,
          style: const TextStyle(fontSize: 13, color: Colors.white)),
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
    );
  }
}

class _OutlineButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _OutlineButton(
      {required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark ? AppTheme.primaryColorDarkMode : AppTheme.primaryColor;

    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label, style: const TextStyle(fontSize: 13)),
      style: OutlinedButton.styleFrom(
        foregroundColor: primary,
        side: BorderSide(color: primary.withValues(alpha: 0.5)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
    );
  }
}
