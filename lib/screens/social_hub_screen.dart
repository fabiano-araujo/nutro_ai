import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/feed_provider.dart';
import '../providers/friends_provider.dart';
import '../providers/challenges_provider.dart';
import '../providers/streak_provider.dart';
import '../services/auth_service.dart';
import '../services/feed_service.dart';
import '../services/social_service.dart';
import '../services/challenge_service.dart';
import '../theme/app_theme.dart';
import '../widgets/diet_style_message_state.dart';
import '../widgets/header_streak_badge.dart';

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

Color _socialSurfaceColor(bool isDarkMode) =>
    isDarkMode ? const Color(0xFF2A2A2A) : Colors.white;

Color _socialInputFillColor(bool isDarkMode) =>
    isDarkMode ? const Color(0xFF1F1F1F) : AppTheme.backgroundColor;

Color _socialBorderColor(bool isDarkMode) =>
    isDarkMode ? Colors.white12 : Colors.black12;

Color _socialMutedTextColor(bool isDarkMode) =>
    isDarkMode ? const Color(0xFFAEB7CE) : AppTheme.textSecondaryColor;

Color _socialPrimaryColor(bool isDarkMode) =>
    isDarkMode ? AppTheme.primaryColorDarkMode : AppTheme.primaryColor;

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
  bool _showPublicChallenges = false;
  bool _isHeaderCollapsed = false;

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

  void _handleScrollVisibility(ScrollNotification notification) {
    final shouldCollapse = notification.metrics.pixels > 12;
    if (shouldCollapse == _isHeaderCollapsed) return;
    setState(() => _isHeaderCollapsed = shouldCollapse);
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
    final primaryColor = _socialPrimaryColor(isDarkMode);
    final fabForegroundColor = AppTheme.onColor(primaryColor);
    // Tela de login se não autenticado
    if (!authService.isAuthenticated) {
      return Scaffold(
        backgroundColor: isDarkMode
            ? AppTheme.darkBackgroundColor
            : AppTheme.backgroundColor,
        body: SafeArea(
          child: Column(
            children: [
              _SocialShellHeader(onOpenDrawer: widget.onOpenDrawer),
              const _SocialHero(
                icon: Icons.people_alt_rounded,
                title: 'Comunidade',
                subtitle: 'Entre para acompanhar amigos e desafios.',
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
      floatingActionButton: _tabController.index == 1
          ? Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: FloatingActionButton.extended(
                onPressed: () => _showCreateChallengeDialog(context),
                backgroundColor: primaryColor,
                foregroundColor: fabForegroundColor,
                elevation: 0,
                icon: Icon(Icons.add_rounded, color: fabForegroundColor),
                label: Text(
                  'Criar desafio',
                  style: TextStyle(
                    color: fabForegroundColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22),
                ),
              ),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: SafeArea(
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              height: _isHeaderCollapsed ? 0 : 76,
              child: ClipRect(
                child: OverflowBox(
                  minHeight: 0,
                  maxHeight: 76,
                  alignment: Alignment.topCenter,
                  child: _SocialShellHeader(
                    onOpenDrawer: widget.onOpenDrawer,
                    title: _tabController.index == 0 ? 'Amigos' : 'Comunidade',
                    subtitle: _tabController.index == 0
                        ? 'Atualizações recentes'
                        : 'Crie desafios e compare o progresso.',
                    showStreakBadge: true,
                    trailing: _tabController.index == 0
                        ? const _SocialFriendsHeaderActions()
                        : null,
                  ),
                ),
              ),
            ),
            _SocialModeTabs(
              selectedIndex: _tabController.index,
              onChanged: (index) {
                setState(() {
                  _tabController.index = index;
                  _isHeaderCollapsed = false;
                });
                if (index == 1) {
                  context.read<ChallengesProvider>().loadOverview();
                }
              },
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _tabController.index == 0
                    ? _refreshData
                    : context.read<ChallengesProvider>().refresh,
                child: NotificationListener<ScrollNotification>(
                  onNotification: (notification) {
                    _handleScrollVisibility(notification);
                    return false;
                  },
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.only(
                      bottom: _tabController.index == 1 ? 108 : 32,
                    ),
                    child: _tabController.index == 0
                        ? _SocialTabContent(onRefresh: _refreshData)
                        : _ChallengesContent(
                            showPublic: _showPublicChallenges,
                            onShowPublicChanged: (showPublic) {
                              setState(
                                  () => _showPublicChallenges = showPublic);
                              if (showPublic) {
                                context
                                    .read<ChallengesProvider>()
                                    .loadPublicChallenges();
                              }
                            },
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

  void _showCreateChallengeDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String type = 'LOGGING_STREAK';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = _socialPrimaryColor(isDark);
    final foreground = AppTheme.onColor(primary);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _socialSurfaceColor(isDark),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
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
                      value: 'CALORIE_DEFICIT',
                      child: Text('Déficit calórico')),
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
                      description: descCtrl.text.isEmpty ? null : descCtrl.text,
                      type: type,
                    );
                Navigator.pop(ctx);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: primary,
              foregroundColor: foreground,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Criar', style: TextStyle(color: foreground)),
          ),
        ],
      ),
    );
  }
}

class _SocialShellHeader extends StatelessWidget {
  final VoidCallback? onOpenDrawer;
  final String title;
  final String? subtitle;
  final bool showStreakBadge;
  final Widget? trailing;

  const _SocialShellHeader({
    this.onOpenDrawer,
    this.title = 'Social',
    this.subtitle,
    this.showStreakBadge = false,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDarkMode ? Colors.white : AppTheme.textPrimaryColor;
    final sideWidth =
        trailing != null ? 128.0 : (showStreakBadge ? 76.0 : 48.0);

    return SizedBox(
      height: subtitle == null ? 52 : 76,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Row(
          children: [
            if (onOpenDrawer != null)
              SizedBox(
                width: sideWidth,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    icon: Icon(Icons.menu_rounded, color: textColor),
                    onPressed: onOpenDrawer,
                    tooltip: 'Menu',
                  ),
                ),
              )
            else
              SizedBox(width: sideWidth),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: textColor,
                      height: 1.05,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 5),
                    Text(
                      subtitle!,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: _socialMutedTextColor(isDarkMode),
                        height: 1.15,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            SizedBox(
              width: sideWidth,
              child: trailing != null
                  ? Align(alignment: Alignment.centerRight, child: trailing!)
                  : showStreakBadge
                      ? const Align(
                          alignment: Alignment.centerRight,
                          child: HeaderStreakBadge(),
                        )
                      : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _SocialFriendsHeaderActions extends StatelessWidget {
  const _SocialFriendsHeaderActions();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: const [
        HeaderStreakBadge(),
        SizedBox(width: 6),
        _FriendsHeaderIconButton(),
      ],
    );
  }
}

class _SocialHero extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _SocialHero({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primary = _socialPrimaryColor(isDarkMode);
    final textColor = isDarkMode ? Colors.white : AppTheme.textPrimaryColor;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
      child: Column(
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              color: _socialInputFillColor(isDarkMode),
              shape: BoxShape.circle,
              border: Border.all(color: _socialBorderColor(isDarkMode)),
            ),
            child: Icon(icon, color: primary, size: 30),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              color: textColor,
              height: 1.08,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              height: 1.35,
              color: _socialMutedTextColor(isDarkMode),
            ),
          ),
        ],
      ),
    );
  }
}

class _SocialModeTabs extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  const _SocialModeTabs({
    required this.selectedIndex,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _SocialModeChip(
            label: 'Social',
            selected: selectedIndex == 0,
            isDarkMode: isDarkMode,
            onTap: () => onChanged(0),
          ),
          const SizedBox(width: 12),
          _SocialModeChip(
            label: 'Desafios',
            selected: selectedIndex == 1,
            isDarkMode: isDarkMode,
            onTap: () => onChanged(1),
          ),
        ],
      ),
    );
  }
}

class _SocialModeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final bool isDarkMode;
  final VoidCallback onTap;

  const _SocialModeChip({
    required this.label,
    required this.selected,
    required this.isDarkMode,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final selectedColor =
        isDarkMode ? AppTheme.primaryColorDarkMode : AppTheme.primaryColor;
    final selectedTextColor = AppTheme.onColor(selectedColor);
    final unselectedBorderColor =
        isDarkMode ? AppTheme.darkBorderColor : AppTheme.dividerColor;
    final cardColor = isDarkMode ? AppTheme.darkCardColor : Colors.white;
    final unselectedTextColor =
        isDarkMode ? Colors.grey[400]! : Colors.grey[700]!;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 141,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? selectedColor : cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? selectedColor : unselectedBorderColor,
            width: 1,
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? selectedTextColor : unselectedTextColor,
          ),
        ),
      ),
    );
  }
}

// ==================== ABA SOCIAL ====================
// Mostra: sequência + feed de atividades dos amigos.
// Gerenciar amigos: botão no topo da lista.
class _SocialTabContent extends StatelessWidget {
  final Future<void> Function() onRefresh;

  const _SocialTabContent({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Consumer2<FeedProvider, FriendsProvider>(
      builder: (context, feedProvider, friendsProvider, _) {
        final isLoading =
            feedProvider.isLoading && feedProvider.activities.isEmpty;

        if (isLoading) {
          return const SizedBox(
            height: 240,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        return Column(
          children: [
            if (feedProvider.error != null && feedProvider.activities.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: _InfoCard(
                  icon: Icons.cloud_off_rounded,
                  message: 'Não foi possível carregar. Puxe para atualizar.',
                ),
              )
            else if (feedProvider.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: _EmptyFriendsCard(),
              )
            else ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Column(
                  children: [
                    ...feedProvider.activities.map((activity) {
                      return _ActivityCard(
                        activity: activity,
                        onReact: (emoji) =>
                            feedProvider.toggleReaction(activity.id, emoji),
                      );
                    }),
                    if (feedProvider.hasMore)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Builder(
                          builder: (context) {
                            if (!feedProvider.isLoadingMore) {
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                feedProvider.loadMore();
                              });
                            }
                            return const CircularProgressIndicator();
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

/// Botão no header que abre a tela de amigos
class _FriendsHeaderIconButton extends StatelessWidget {
  const _FriendsHeaderIconButton();

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = _socialPrimaryColor(isDarkMode);

    return Consumer<FriendsProvider>(
      builder: (context, friendsProvider, _) {
        final hasPending = friendsProvider.hasPendingRequests;

        return Tooltip(
          message: hasPending ? 'Pedidos de amizade' : 'Gerenciar amigos',
          child: InkWell(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const FriendsScreen(isEmbedded: false),
              ),
            ),
            borderRadius: BorderRadius.circular(18),
            child: Container(
              width: 36,
              height: 34,
              decoration: BoxDecoration(
                color: _socialInputFillColor(isDarkMode),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: _socialBorderColor(isDarkMode)),
              ),
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  Icon(
                    Icons.group_rounded,
                    size: 18,
                    color: primaryColor,
                  ),
                  if (hasPending)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: Colors.redAccent,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
            ),
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
    final primaryColor = _socialPrimaryColor(isDarkMode);
    final foregroundColor = AppTheme.onColor(primaryColor);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
      decoration: BoxDecoration(
        color: _socialSurfaceColor(isDarkMode),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _socialBorderColor(isDarkMode)),
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
              color: _socialMutedTextColor(isDarkMode),
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
              icon: Icon(Icons.person_add_rounded,
                  size: 18, color: foregroundColor),
              label: Text(
                'Adicionar amigos',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: foregroundColor),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: foregroundColor,
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
        color: _socialSurfaceColor(isDarkMode),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _socialBorderColor(isDarkMode)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 24, color: _socialMutedTextColor(isDarkMode)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 13,
                color: _socialMutedTextColor(isDarkMode),
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
    final mediaUrl = _mediaUrl;
    final challengeName = _challengeName;
    final stats = _stats;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _socialSurfaceColor(isDarkMode),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _socialBorderColor(isDarkMode)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabeçalho
          Row(
            children: [
              _ActivityAvatar(user: activity.user),
              const SizedBox(width: 12),
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
                      _secondaryLine,
                      style: TextStyle(
                        fontSize: 12,
                        color: _socialMutedTextColor(isDarkMode),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: typeInfo.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(typeInfo.icon, color: typeInfo.color, size: 17),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Mensagem da atividade
          Text(
            _message,
            style: TextStyle(
              fontSize: 15,
              height: 1.35,
              fontWeight: FontWeight.w700,
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
          if (challengeName != null) ...[
            const SizedBox(height: 12),
            _ActivityContextPill(
              icon: Icons.emoji_events_rounded,
              label: 'Desafio',
              value: challengeName,
              color: const Color(0xFFFFC107),
            ),
          ],
          if (activity.isPrivate) ...[
            const SizedBox(height: 10),
            _ActivityContextPill(
              icon: Icons.lock_rounded,
              label: 'Privado',
              value: 'Detalhes visíveis só para ${activity.user.name}',
              color: _socialMutedTextColor(isDarkMode),
            ),
          ],
          if (mediaUrl != null) ...[
            const SizedBox(height: 14),
            _ActivityMediaPreview(imageUrl: mediaUrl),
          ] else if (stats.isNotEmpty || _isNutritionActivity) ...[
            const SizedBox(height: 14),
            _ActivitySummaryPanel(
              icon: typeInfo.icon,
              title: _summaryTitle,
              stats: stats,
              color: typeInfo.color,
            ),
          ],
          const SizedBox(height: 14),
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
    final customMessage = _readString(activity.data, ['message', 'text']);
    if (customMessage != null) return customMessage;

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
    final direct = _readString(activity.data, [
      'mealName',
      'activityName',
      'summary',
      'category',
      'mealType',
    ]);
    if (direct != null) return direct;

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

  String get _secondaryLine {
    final username = activity.user.username?.trim();
    final time = _formatTime(activity.createdAt);
    if (username != null && username.isNotEmpty) return '@$username · $time';
    return time;
  }

  bool get _isNutritionActivity {
    final type = activity.type.toUpperCase();
    return type == 'CHECKIN_PROTEIN' ||
        type == 'CHECKIN_GOAL' ||
        type == 'CHECKIN_OVER';
  }

  String get _summaryTitle {
    switch (activity.type.toUpperCase()) {
      case 'CHECKIN_PROTEIN':
        return 'Resumo da refeição';
      case 'CHECKIN_GOAL':
        return 'Resumo do dia';
      case 'CHECKIN_OVER':
        return 'Registro nutricional';
      case 'STREAK_MILESTONE':
        return 'Sequência atualizada';
      case 'FRIEND_STREAK':
        return 'Atividade em dupla';
      case 'CHALLENGE_JOIN':
        return 'Novo desafio';
      default:
        return 'Atividade';
    }
  }

  String? get _challengeName {
    final data = activity.data;
    if (data == null) return null;

    final direct = _readString(data, [
      'challengeName',
      'challengeTitle',
      'challengeLabel',
    ]);
    if (direct != null) return direct;

    final challenge = data['challenge'];
    if (challenge is Map) {
      final nested = challenge['name'] ?? challenge['title'];
      if (nested is String && nested.trim().isNotEmpty) {
        return nested.trim();
      }
    }
    return null;
  }

  String? get _mediaUrl {
    final data = activity.data;
    if (data == null) return null;

    final direct = _readString(data, [
      'imageUrl',
      'image',
      'photo',
      'mealPhoto',
      'foodPhoto',
      'activityPhoto',
      'thumbnail',
      'thumbnailUrl',
      'activityImage',
      'activityImageUrl',
    ]);
    if (direct != null) return direct;

    for (final key in const ['meal', 'food', 'activity', 'media']) {
      final nested = data[key];
      if (nested is Map) {
        final value = nested['imageUrl'] ??
            nested['image'] ??
            nested['photo'] ??
            nested['thumbnailUrl'];
        if (value is String && value.trim().isNotEmpty) {
          return value.trim();
        }
      }
    }
    return null;
  }

  List<_ActivityStat> get _stats {
    final data = activity.data;
    if (data == null || activity.isPrivate) return const [];

    final stats = <_ActivityStat>[];
    final calories = _readNumber(data, ['calories', 'totalCalories']);
    final calorieGoal = _readNumber(data, ['calorieGoal', 'targetCalories']);
    final protein = _readNumber(data, ['protein', 'totalProtein']);
    final proteinGoal = _readNumber(data, ['proteinGoal', 'targetProtein']);
    final days = _readNumber(data, ['days', 'streakCount', 'currentStreak']);
    final points = _readNumber(data, ['points', 'totalPoints']);
    final hitProtein = data['hitProtein'] == true;
    final hitGoal = data['hitGoal'] == true;

    if (calories != null) {
      stats.add(_ActivityStat(
        icon: Icons.local_fire_department_rounded,
        value: '${calories.round()} kcal',
        label: calorieGoal == null ? 'consumidas' : 'de ${calorieGoal.round()}',
      ));
    }
    if (protein != null) {
      stats.add(_ActivityStat(
        icon: Icons.fitness_center_rounded,
        value: '${protein.round()}g',
        label: proteinGoal == null ? 'proteína' : 'de ${proteinGoal.round()}g',
      ));
    }
    if (days != null) {
      stats.add(_ActivityStat(
        icon: Icons.local_fire_department_rounded,
        value: '${days.round()}',
        label: 'dias',
      ));
    }
    if (points != null) {
      stats.add(_ActivityStat(
        icon: Icons.bolt_rounded,
        value: '${points.round()}',
        label: 'pontos',
      ));
    }
    if (stats.isEmpty && hitProtein) {
      stats.add(const _ActivityStat(
        icon: Icons.fitness_center_rounded,
        value: 'Proteína',
        label: 'meta batida',
      ));
    }
    if (stats.length < 3 && hitGoal) {
      stats.add(const _ActivityStat(
        icon: Icons.flag_rounded,
        value: 'Calorias',
        label: 'dentro da meta',
      ));
    }

    return stats.take(3).toList();
  }

  String? _readString(Map<String, dynamic>? data, List<String> keys) {
    if (data == null) return null;
    for (final key in keys) {
      final value = data[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return null;
  }

  double? _readNumber(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];
      if (value is num) return value.toDouble();
      if (value is String) {
        final parsed = double.tryParse(value.replaceAll(',', '.'));
        if (parsed != null) return parsed;
      }
    }
    return null;
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

class _ActivityStat {
  final IconData icon;
  final String value;
  final String label;

  const _ActivityStat({
    required this.icon,
    required this.value,
    required this.label,
  });
}

class _ActivityAvatar extends StatelessWidget {
  final SimpleUser user;

  const _ActivityAvatar({required this.user});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final imageUrl = user.photo?.trim();

    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _socialInputFillColor(isDarkMode),
        border: Border.all(color: _socialBorderColor(isDarkMode)),
      ),
      clipBehavior: Clip.antiAlias,
      child: imageUrl != null && imageUrl.isNotEmpty
          ? Image.network(
              imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _ActivityAvatarFallback(user: user),
            )
          : _ActivityAvatarFallback(user: user),
    );
  }
}

class _ActivityAvatarFallback extends StatelessWidget {
  final SimpleUser user;

  const _ActivityAvatarFallback({required this.user});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final name = user.name.trim();
    final initial = name.isEmpty ? '?' : name.substring(0, 1).toUpperCase();

    return Center(
      child: Text(
        initial,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: isDarkMode ? Colors.white : AppTheme.textPrimaryColor,
        ),
      ),
    );
  }
}

class _ActivityContextPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _ActivityContextPill({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: _socialInputFillColor(isDarkMode),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _socialBorderColor(isDarkMode)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 7),
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isDarkMode ? Colors.white : AppTheme.textPrimaryColor,
            ),
          ),
          Expanded(
            child: Text(
              value,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _socialMutedTextColor(isDarkMode),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityMediaPreview extends StatelessWidget {
  final String imageUrl;

  const _ActivityMediaPreview({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: _socialInputFillColor(isDarkMode),
          ),
          child: Image.network(
            imageUrl,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const _ActivityMediaPlaceholder(),
          ),
        ),
      ),
    );
  }
}

class _ActivityMediaPlaceholder extends StatelessWidget {
  const _ActivityMediaPlaceholder();

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      color: _socialInputFillColor(isDarkMode),
      alignment: Alignment.center,
      child: Icon(
        Icons.image_not_supported_rounded,
        color: _socialMutedTextColor(isDarkMode),
      ),
    );
  }
}

class _ActivitySummaryPanel extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<_ActivityStat> stats;
  final Color color;

  const _ActivitySummaryPanel({
    required this.icon,
    required this.title,
    required this.stats,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _socialInputFillColor(isDarkMode),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _socialBorderColor(isDarkMode)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color:
                        isDarkMode ? Colors.white : AppTheme.textPrimaryColor,
                  ),
                ),
                const SizedBox(height: 8),
                if (stats.isEmpty)
                  Text(
                    'Sem foto adicionada neste registro.',
                    style: TextStyle(
                      fontSize: 12,
                      color: _socialMutedTextColor(isDarkMode),
                    ),
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final stat in stats) _ActivityStatChip(stat: stat),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityStatChip extends StatelessWidget {
  final _ActivityStat stat;

  const _ActivityStatChip({required this.stat});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: _socialSurfaceColor(isDarkMode),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _socialBorderColor(isDarkMode)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            stat.icon,
            size: 14,
            color: _socialMutedTextColor(isDarkMode),
          ),
          const SizedBox(width: 6),
          Text(
            stat.value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: isDarkMode ? Colors.white : AppTheme.textPrimaryColor,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            stat.label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: _socialMutedTextColor(isDarkMode),
            ),
          ),
        ],
      ),
    );
  }
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
    final primaryColor = _socialPrimaryColor(isDarkMode);

    return Row(
      children: emojis.map((emoji) {
        final count = activity.reactionCounts[emoji] ?? 0;
        final reacted = activity.hasReacted(emoji);

        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: GestureDetector(
            onTap: () => onReact(emoji),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: reacted
                    ? primaryColor.withValues(alpha: 0.1)
                    : _socialInputFillColor(isDarkMode),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: reacted
                      ? primaryColor.withValues(alpha: 0.3)
                      : (isDarkMode ? Colors.white12 : Colors.black12),
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
                                ? _socialMutedTextColor(isDarkMode)
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
class _ChallengesContent extends StatefulWidget {
  final bool showPublic;
  final ValueChanged<bool> onShowPublicChanged;

  const _ChallengesContent({
    required this.showPublic,
    required this.onShowPublicChanged,
  });

  @override
  State<_ChallengesContent> createState() => _ChallengesContentState();
}

class _ChallengesContentState extends State<_ChallengesContent> {
  @override
  Widget build(BuildContext context) {
    return Consumer<ChallengesProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading && provider.myChallenges.isEmpty) {
          return const SizedBox(
            height: 240,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 14),
              child: _ChallengeToolbar(
                showPublic: widget.showPublic,
                onChanged: widget.onShowPublicChanged,
                onCodeTap: () => _showJoinCodeDialog(context),
              ),
            ),
            if (widget.showPublic)
              _PublicChallengesList(provider: provider)
            else
              _MyChallengesList(
                provider: provider,
                onCodeTap: () => _showJoinCodeDialog(context),
              ),
          ],
        );
      },
    );
  }

  void _showJoinCodeDialog(BuildContext context) {
    final codeCtrl = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = _socialPrimaryColor(isDark);
    final foreground = AppTheme.onColor(primary);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _socialSurfaceColor(isDark),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
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
              foregroundColor: foreground,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Entrar', style: TextStyle(color: foreground)),
          ),
        ],
      ),
    );
  }
}

class _MyChallengesList extends StatelessWidget {
  final ChallengesProvider provider;
  final VoidCallback onCodeTap;

  const _MyChallengesList({
    required this.provider,
    required this.onCodeTap,
  });

  @override
  Widget build(BuildContext context) {
    if (provider.myChallenges.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        child: Column(
          children: [
            _EmptyChallengesCard(
              onCodeTap: onCodeTap,
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      child: Column(
        children: provider.myChallenges.map((challenge) {
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
        }).toList(),
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
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        child: _InfoCard(
          icon: Icons.emoji_events_rounded,
          message: 'Nenhum desafio público disponível no momento.',
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      child: Column(
        children: provider.publicChallenges.map((challenge) {
          return _ChallengeCard(
            challenge: challenge,
            showJoinButton: true,
            onTap: () {},
            onJoin: () => provider.joinChallenge(challenge.id),
          );
        }).toList(),
      ),
    );
  }
}

class _EmptyChallengesCard extends StatelessWidget {
  final VoidCallback onCodeTap;

  const _EmptyChallengesCard({
    required this.onCodeTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = _socialPrimaryColor(isDarkMode);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
      decoration: BoxDecoration(
        color: _socialSurfaceColor(isDarkMode),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _socialBorderColor(isDarkMode)),
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
              color: _socialMutedTextColor(isDarkMode),
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
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
                backgroundColor: _socialInputFillColor(isDarkMode),
                side: BorderSide(color: _socialBorderColor(isDarkMode)),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18)),
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
    final primary = _socialPrimaryColor(isDark);
    final daysLeft =
        challenge.endDate.difference(DateTime.now()).inDays.clamp(0, 9999);
    final daysColor = daysLeft > 3
        ? const Color(0xFF4CAF50)
        : (daysLeft > 0 ? const Color(0xFFFF9800) : const Color(0xFFE53935));
    final progress = challenge.completionPercent.clamp(0, 100) / 100;
    final textColor = isDark ? Colors.white : AppTheme.textPrimaryColor;
    final mutedColor = _socialMutedTextColor(isDark);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: _socialSurfaceColor(isDark),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _socialBorderColor(isDark)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(_icon, color: primary, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        challenge.name,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          height: 1.15,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        challenge.typeFormatted,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: mutedColor,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: daysColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
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
            if (challenge.description != null &&
                challenge.description!.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                challenge.description!,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: mutedColor,
                ),
              ),
            ],
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _ChallengeInfoChip(
                  icon: Icons.group_rounded,
                  label:
                      '${challenge.participantCount}/${challenge.maxParticipants}',
                  isDark: isDark,
                ),
                _ChallengeInfoChip(
                  icon: Icons.flag_rounded,
                  label: '${challenge.targetDays} dias',
                  isDark: isDark,
                ),
                if (challenge.myParticipation != null)
                  _ChallengeInfoChip(
                    icon: Icons.bolt_rounded,
                    label: '${challenge.myParticipation!.totalPoints} pts',
                    isDark: isDark,
                  ),
              ],
            ),
            if (challenge.progress != null) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        minHeight: 7,
                        value: progress,
                        backgroundColor: _socialInputFillColor(isDark),
                        valueColor: AlwaysStoppedAnimation<Color>(primary),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '${challenge.progress!.completedDays}/${challenge.progress!.targetDays}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: mutedColor,
                    ),
                  ),
                ],
              ),
            ],
            if (showJoinButton && onJoin != null) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onJoin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18)),
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

class _ChallengeInfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isDark;

  const _ChallengeInfoChip({
    required this.icon,
    required this.label,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: _socialInputFillColor(isDark),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _socialBorderColor(isDark)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: _socialMutedTextColor(isDark)),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : AppTheme.textPrimaryColor,
            ),
          ),
        ],
      ),
    );
  }
}

// ==================== WIDGETS DE SUPORTE ====================

class _ChallengeToolbar extends StatelessWidget {
  final bool showPublic;
  final ValueChanged<bool> onChanged;
  final VoidCallback onCodeTap;

  const _ChallengeToolbar({
    required this.showPublic,
    required this.onChanged,
    required this.onCodeTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: _ChallengeScopeTitle(
            showPublic: showPublic,
            onChanged: onChanged,
          ),
        ),
        const SizedBox(width: 10),
        _RoundActionButton(
          icon: Icons.qr_code_rounded,
          tooltip: 'Entrar com código',
          onTap: onCodeTap,
        ),
      ],
    );
  }
}

class _ChallengeScopeTitle extends StatelessWidget {
  final bool showPublic;
  final ValueChanged<bool> onChanged;

  const _ChallengeScopeTitle({
    required this.showPublic,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : AppTheme.textPrimaryColor;
    final mutedColor = _socialMutedTextColor(isDark);
    final title = showPublic ? 'Públicos' : 'Meus desafios';
    final subtitle = showPublic
        ? 'Desafios abertos para participar'
        : 'Criados ou em andamento';
    final icon = showPublic ? Icons.public_rounded : Icons.inventory_2_rounded;

    return PopupMenuButton<bool>(
      tooltip: 'Filtrar desafios',
      initialValue: showPublic,
      onSelected: onChanged,
      color: _socialSurfaceColor(isDark),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      itemBuilder: (context) => [
        PopupMenuItem<bool>(
          value: false,
          child: Row(
            children: [
              Icon(Icons.inventory_2_rounded, size: 18, color: textColor),
              const SizedBox(width: 10),
              Text('Meus desafios', style: TextStyle(color: textColor)),
            ],
          ),
        ),
        PopupMenuItem<bool>(
          value: true,
          child: Row(
            children: [
              Icon(Icons.public_rounded, size: 18, color: textColor),
              const SizedBox(width: 10),
              Text('Públicos', style: TextStyle(color: textColor)),
            ],
          ),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 20, color: mutedColor),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: textColor,
                    height: 1.1,
                  ),
                ),
                const SizedBox(width: 3),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 20,
                  color: mutedColor,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: mutedColor,
                height: 1.15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoundActionButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _RoundActionButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = _socialPrimaryColor(isDark);

    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _socialInputFillColor(isDark),
            shape: BoxShape.circle,
            border: Border.all(
              color: _socialBorderColor(isDark),
            ),
          ),
          child: Icon(icon, size: 20, color: primary),
        ),
      ),
    );
  }
}
