import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/friends_provider.dart';
import '../services/social_service.dart';
import '../theme/app_theme.dart';
import '../widgets/diet_style_message_state.dart';

class FriendsScreen extends StatefulWidget {
  final bool isEmbedded;

  const FriendsScreen({Key? key, this.isEmbedded = false}) : super(key: key);

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  List<SearchedUser> _searchResults = [];
  bool _showPendingRequests = true;
  bool _showSentRequests = false;

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _searchUsers(String query) async {
    if (query.length < 2) {
      setState(() {
        _searchResults = [];
      });
      return;
    }

    final provider = context.read<FriendsProvider>();
    final results = await provider.searchUsers(query);

    setState(() {
      _searchResults = results;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryColor =
        isDarkMode ? AppTheme.primaryColorDarkMode : AppTheme.primaryColor;

    return Consumer<FriendsProvider>(
      builder: (context, friendsProvider, child) {
        final hasAnyData = _searchResults.isNotEmpty ||
            friendsProvider.hasPendingRequests ||
            friendsProvider.hasSentRequests ||
            friendsProvider.duoStreaks.isNotEmpty ||
            friendsProvider.friends.isNotEmpty;
        final showLoadingState = friendsProvider.isLoading && !hasAnyData;
        final showErrorState = friendsProvider.error != null && !hasAnyData;

        final content = RefreshIndicator(
          onRefresh: friendsProvider.refresh,
          color: primaryColor,
          child: CustomScrollView(
            slivers: [
              // Search bar elegante
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDarkMode ? AppTheme.darkCardColor : Colors.white,
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
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      focusNode: _searchFocusNode,
                      decoration: InputDecoration(
                        hintText: 'Buscar usuarios...',
                        hintStyle: TextStyle(
                          color: isDarkMode
                              ? Colors.white.withValues(alpha: 0.35)
                              : AppTheme.textSecondaryColor,
                          fontSize: 14,
                        ),
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          color: primaryColor.withValues(alpha: 0.7),
                        ),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: Icon(Icons.clear_rounded,
                                    size: 20,
                                    color: isDarkMode
                                        ? Colors.white54
                                        : Colors.grey),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {
                                    _searchResults = [];
                                  });
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onChanged: _searchUsers,
                    ),
                  ),
                ),
              ),

              if (showLoadingState)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (showErrorState)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: DietStyleMessageState(
                    title: 'Nao foi possivel carregar seus amigos',
                    message:
                        'Verifique sua conexao e tente novamente para buscar sua rede social.',
                    fallbackIcon: Icons.cloud_off_rounded,
                    primaryActionLabel: 'Tentar novamente',
                    primaryActionIcon: Icons.refresh_rounded,
                    onPrimaryAction: friendsProvider.refresh,
                    topSpacing: 24,
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                  ),
                )
              else ...[
                // Search results
                if (_searchResults.isNotEmpty)
                  SliverToBoxAdapter(
                    child: _SearchResultsSection(
                      results: _searchResults,
                      onSendRequest: (userId) async {
                        final success =
                            await friendsProvider.sendFriendRequest(userId);
                        if (success) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Pedido enviado!')),
                          );
                          _searchUsers(_searchController.text);
                        }
                      },
                    ),
                  ),

                // Pending requests toggle
                if (friendsProvider.hasPendingRequests)
                  SliverToBoxAdapter(
                    child: _CollapsibleSection(
                      icon: Icons.person_add_rounded,
                      iconColor: const Color(0xFFFF9800),
                      title:
                          '${friendsProvider.receivedRequests.length} pedido${friendsProvider.receivedRequests.length > 1 ? 's' : ''} de amizade',
                      isExpanded: _showPendingRequests,
                      onToggle: () => setState(
                          () => _showPendingRequests = !_showPendingRequests),
                      badgeCount: friendsProvider.receivedRequests.length,
                    ),
                  ),

                // Pending requests list
                if (_showPendingRequests &&
                    friendsProvider.receivedRequests.isNotEmpty)
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final request = friendsProvider.receivedRequests[index];
                        return _PendingRequestCard(
                          request: request,
                          onAccept: () async {
                            final success =
                                await friendsProvider.acceptRequest(request.id);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(success
                                      ? 'Pedido aceito! ${request.user.name} agora e seu amigo.'
                                      : 'Erro ao aceitar pedido'),
                                  backgroundColor:
                                      success ? Colors.green : Colors.red,
                                ),
                              );
                            }
                          },
                          onReject: () async {
                            final success =
                                await friendsProvider.rejectRequest(request.id);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(success
                                      ? 'Pedido rejeitado'
                                      : 'Erro ao rejeitar pedido'),
                                ),
                              );
                            }
                          },
                        );
                      },
                      childCount: friendsProvider.receivedRequests.length,
                    ),
                  ),

                // Sent requests toggle
                if (friendsProvider.hasSentRequests)
                  SliverToBoxAdapter(
                    child: _CollapsibleSection(
                      icon: Icons.send_rounded,
                      iconColor: const Color(0xFF2196F3),
                      title:
                          '${friendsProvider.sentRequests.length} pedido${friendsProvider.sentRequests.length > 1 ? 's' : ''} enviado${friendsProvider.sentRequests.length > 1 ? 's' : ''}',
                      isExpanded: _showSentRequests,
                      onToggle: () => setState(
                          () => _showSentRequests = !_showSentRequests),
                    ),
                  ),

                // Sent requests list
                if (_showSentRequests &&
                    friendsProvider.sentRequests.isNotEmpty)
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final request = friendsProvider.sentRequests[index];
                        return _SentRequestCard(
                          request: request,
                          onCancel: () async {
                            final success = await friendsProvider
                                .cancelSentRequest(request.id);
                            if (success) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Pedido cancelado')),
                              );
                            }
                          },
                        );
                      },
                      childCount: friendsProvider.sentRequests.length,
                    ),
                  ),

                // Duo streaks section
                if (friendsProvider.duoStreaks.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: _SectionHeader(
                      title: 'Duo Streaks',
                      icon: Icons.local_fire_department_rounded,
                      iconColor: const Color(0xFFFF5722),
                    ),
                  ),
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final duo = friendsProvider.duoStreaks[index];
                        return _DuoStreakCard(
                          duoStreak: duo,
                          onCheckIn: () =>
                              friendsProvider.duoCheckIn(duo.friendshipId),
                        );
                      },
                      childCount: friendsProvider.duoStreaks.length,
                    ),
                  ),
                ],

                // Friends list
                SliverToBoxAdapter(
                  child: _SectionHeader(
                    title: 'Amigos',
                    icon: Icons.people_rounded,
                    count: friendsProvider.friends.length,
                  ),
                ),

                if (friendsProvider.friends.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _EmptyFriendsState(
                      onSearchTap: () => _searchFocusNode.requestFocus(),
                    ),
                  )
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final friendData = friendsProvider.friends[index];
                        return _FriendCard(
                          friendData: friendData,
                          onPing: () => _showPingDialog(
                              context, friendData, friendsProvider),
                          onRemove: () => _confirmRemoveFriend(
                              context, friendData, friendsProvider),
                        );
                      },
                      childCount: friendsProvider.friends.length,
                    ),
                  ),

                const SliverToBoxAdapter(
                  child: SizedBox(height: 80),
                ),
              ],
            ],
          ),
        );

        if (widget.isEmbedded) return content;

        return Scaffold(
          backgroundColor: isDarkMode
              ? AppTheme.darkBackgroundColor
              : AppTheme.backgroundColor,
          appBar: AppBar(
            backgroundColor: isDarkMode
                ? AppTheme.darkBackgroundColor
                : AppTheme.backgroundColor,
            elevation: 0,
            title: const Text(
              'Amigos',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          body: content,
        );
      },
    );
  }

  void _showPingDialog(
      BuildContext context, Friend friendData, FriendsProvider provider) {
    final messageController = TextEditingController();
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
              child: Icon(Icons.notifications_active_rounded,
                  color: primaryColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
                child: Text('Cutucar ${friendData.friend.name}',
                    overflow: TextOverflow.ellipsis)),
          ],
        ),
        content: TextField(
          controller: messageController,
          decoration: const InputDecoration(
            hintText: 'Mensagem opcional...',
          ),
          maxLength: 100,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final success = await provider.sendPing(
                friendData.friend.id,
                message: messageController.text.isEmpty
                    ? null
                    : messageController.text,
              );
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content:
                      Text(success ? 'Ping enviado!' : 'Erro ao enviar ping'),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Enviar'),
          ),
        ],
      ),
    );
  }

  void _confirmRemoveFriend(
      BuildContext context, Friend friendData, FriendsProvider provider) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

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
                color: Colors.red.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.person_remove_rounded,
                  color: Colors.red, size: 20),
            ),
            const SizedBox(width: 12),
            const Text('Remover amigo'),
          ],
        ),
        content:
            Text('Remover ${friendData.friend.name} da sua lista de amigos?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              await provider.removeFriend(friendData.friendshipId);
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Remover', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

// ==================== SECTION HEADER ====================
class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color? iconColor;
  final int? count;

  const _SectionHeader({
    required this.title,
    required this.icon,
    this.iconColor,
    this.count,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final color = iconColor ??
        (isDarkMode ? Colors.white70 : AppTheme.textSecondaryColor);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: isDarkMode ? Colors.white : AppTheme.textPrimaryColor,
            ),
          ),
          if (count != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: isDarkMode
                    ? Colors.white.withValues(alpha: 0.08)
                    : AppTheme.surfaceColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isDarkMode
                      ? AppTheme.darkBorderColor
                      : AppTheme.dividerColor,
                ),
              ),
              child: Text(
                count.toString(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDarkMode
                      ? Colors.white.withValues(alpha: 0.6)
                      : AppTheme.textSecondaryColor,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ==================== COLLAPSIBLE SECTION ====================
class _CollapsibleSection extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final bool isExpanded;
  final VoidCallback onToggle;
  final int? badgeCount;

  const _CollapsibleSection({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.isExpanded,
    required this.onToggle,
    this.badgeCount,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Card(
        margin: EdgeInsets.zero,
        elevation: 1.5,
        shadowColor: isDarkMode
            ? Colors.black.withValues(alpha: 0.3)
            : Colors.black.withValues(alpha: 0.08),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        color: isDarkMode ? AppTheme.darkCardColor : Colors.white,
        child: InkWell(
          onTap: onToggle,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color:
                          isDarkMode ? Colors.white : AppTheme.textPrimaryColor,
                    ),
                  ),
                ),
                AnimatedRotation(
                  turns: isExpanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.expand_more_rounded,
                    color: iconColor,
                    size: 22,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ==================== SEARCH RESULTS ====================
class _SearchResultsSection extends StatelessWidget {
  final List<SearchedUser> results;
  final Function(int) onSendRequest;

  const _SearchResultsSection({
    required this.results,
    required this.onSendRequest,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Card(
        margin: EdgeInsets.zero,
        elevation: 1.5,
        shadowColor: isDarkMode
            ? Colors.black.withValues(alpha: 0.3)
            : Colors.black.withValues(alpha: 0.08),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        color: isDarkMode ? AppTheme.darkCardColor : Colors.white,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
              child: Row(
                children: [
                  Icon(Icons.search_rounded,
                      size: 14,
                      color: isDarkMode
                          ? Colors.white38
                          : AppTheme.textSecondaryColor),
                  const SizedBox(width: 6),
                  Text(
                    'Resultados da busca',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                      color: isDarkMode
                          ? Colors.white38
                          : AppTheme.textSecondaryColor,
                    ),
                  ),
                ],
              ),
            ),
            ...results.map((user) => _SearchResultTile(
                  user: user,
                  onSendRequest: onSendRequest,
                )),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }
}

class _SearchResultTile extends StatelessWidget {
  final SearchedUser user;
  final Function(int) onSendRequest;

  const _SearchResultTile({
    required this.user,
    required this.onSendRequest,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final pColor =
        isDarkMode ? AppTheme.primaryColorDarkMode : AppTheme.primaryColor;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color:
              isDarkMode ? AppTheme.darkComponentColor : AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: pColor.withValues(alpha: 0.12),
              child: Text(
                user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                style: TextStyle(
                  color: pColor,
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
                    user.name,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color:
                          isDarkMode ? Colors.white : AppTheme.textPrimaryColor,
                    ),
                  ),
                  if (user.username != null)
                    Text(
                      '@${user.username}',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDarkMode
                            ? Colors.white.withValues(alpha: 0.4)
                            : AppTheme.textSecondaryColor,
                      ),
                    ),
                ],
              ),
            ),
            _buildActionButton(context),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(BuildContext context) {
    if (user.friendshipStatus == 'ACCEPTED') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFF4CAF50).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: const Color(0xFF4CAF50).withValues(alpha: 0.25),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_rounded, color: Color(0xFF4CAF50), size: 14),
            const SizedBox(width: 4),
            const Text(
              'Amigo',
              style: TextStyle(
                color: Color(0xFF4CAF50),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    if (user.friendshipStatus == 'PENDING') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFFFF9800).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: const Color(0xFFFF9800).withValues(alpha: 0.25),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.schedule_rounded,
                color: Color(0xFFFF9800), size: 14),
            const SizedBox(width: 4),
            const Text(
              'Pendente',
              style: TextStyle(
                color: Color(0xFFFF9800),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return ElevatedButton.icon(
      onPressed: () => onSendRequest(user.id),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        minimumSize: const Size(0, 32),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        elevation: 0,
      ),
      icon: const Icon(Icons.person_add_rounded, size: 16, color: Colors.white),
      label: const Text('Adicionar',
          style: TextStyle(fontSize: 12, color: Colors.white)),
    );
  }
}

// ==================== PENDING REQUEST CARD ====================
class _PendingRequestCard extends StatefulWidget {
  final FriendRequest request;
  final Future<void> Function() onAccept;
  final Future<void> Function() onReject;

  const _PendingRequestCard({
    required this.request,
    required this.onAccept,
    required this.onReject,
  });

  @override
  State<_PendingRequestCard> createState() => _PendingRequestCardState();
}

class _PendingRequestCardState extends State<_PendingRequestCard> {
  bool _isLoading = false;

  Future<void> _handleAccept() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      await widget.onAccept();
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleReject() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      await widget.onReject();
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Card(
        margin: EdgeInsets.zero,
        elevation: 1.5,
        shadowColor: isDarkMode
            ? Colors.black.withValues(alpha: 0.3)
            : Colors.black.withValues(alpha: 0.08),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        color: isDarkMode ? AppTheme.darkCardColor : Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor:
                    const Color(0xFFFF9800).withValues(alpha: 0.12),
                child: Text(
                  widget.request.user.name.isNotEmpty
                      ? widget.request.user.name[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                    color: Color(0xFFFF9800),
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.request.user.name,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: isDarkMode
                            ? Colors.white
                            : AppTheme.textPrimaryColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatTime(widget.request.createdAt),
                      style: TextStyle(
                        fontSize: 12,
                        color: isDarkMode
                            ? Colors.white.withValues(alpha: 0.4)
                            : AppTheme.textSecondaryColor,
                      ),
                    ),
                  ],
                ),
              ),
              if (_isLoading)
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _ActionCircleButton(
                      icon: Icons.close_rounded,
                      color: Colors.red,
                      onTap: _handleReject,
                    ),
                    const SizedBox(width: 8),
                    _ActionCircleButton(
                      icon: Icons.check_rounded,
                      color: const Color(0xFF4CAF50),
                      onTap: _handleAccept,
                      filled: true,
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inDays > 0) return '${diff.inDays}d atras';
    if (diff.inHours > 0) return '${diff.inHours}h atras';
    return '${diff.inMinutes}min atras';
  }
}

// ==================== ACTION CIRCLE BUTTON ====================
class _ActionCircleButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool filled;

  const _ActionCircleButton({
    required this.icon,
    required this.color,
    required this.onTap,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: filled ? color : color.withValues(alpha: 0.1),
          shape: BoxShape.circle,
          border:
              filled ? null : Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Icon(icon, color: filled ? Colors.white : color, size: 20),
      ),
    );
  }
}

// ==================== SENT REQUEST CARD ====================
class _SentRequestCard extends StatelessWidget {
  final FriendRequest request;
  final VoidCallback onCancel;

  const _SentRequestCard({
    required this.request,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Card(
        margin: EdgeInsets.zero,
        elevation: 1.5,
        shadowColor: isDarkMode
            ? Colors.black.withValues(alpha: 0.3)
            : Colors.black.withValues(alpha: 0.08),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        color: isDarkMode ? AppTheme.darkCardColor : Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor:
                    const Color(0xFF2196F3).withValues(alpha: 0.12),
                child: Text(
                  request.user.name.isNotEmpty
                      ? request.user.name[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                    color: Color(0xFF2196F3),
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.user.name,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: isDarkMode
                            ? Colors.white
                            : AppTheme.textPrimaryColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Enviado ${_formatTime(request.createdAt)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDarkMode
                            ? Colors.white.withValues(alpha: 0.4)
                            : AppTheme.textSecondaryColor,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: onCancel,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(color: Colors.red.withValues(alpha: 0.3)),
                  ),
                ),
                child: const Text('Cancelar',
                    style:
                        TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inDays > 0) return '${diff.inDays}d atras';
    if (diff.inHours > 0) return '${diff.inHours}h atras';
    return '${diff.inMinutes}min atras';
  }
}

// ==================== DUO STREAK CARD ====================
class _DuoStreakCard extends StatelessWidget {
  final DuoStreak duoStreak;
  final VoidCallback onCheckIn;

  const _DuoStreakCard({
    required this.duoStreak,
    required this.onCheckIn,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final currentStreak = duoStreak.friendStreak?.currentStreak ?? 0;
    final bestStreak = duoStreak.friendStreak?.bestStreak ?? 0;
    const streakColor = Color(0xFFFF5722);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Card(
        margin: EdgeInsets.zero,
        elevation: 1.5,
        shadowColor: isDarkMode
            ? Colors.black.withValues(alpha: 0.3)
            : Colors.black.withValues(alpha: 0.08),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        color: isDarkMode ? AppTheme.darkCardColor : Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Avatar com borda de fogo
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: streakColor.withValues(alpha: 0.4),
                    width: 2,
                  ),
                ),
                child: CircleAvatar(
                  radius: 22,
                  backgroundColor: streakColor.withValues(alpha: 0.12),
                  child: Text(
                    duoStreak.friend.name.isNotEmpty
                        ? duoStreak.friend.name[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      color: streakColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      duoStreak.friend.name,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: isDarkMode
                            ? Colors.white
                            : AppTheme.textPrimaryColor,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: streakColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.local_fire_department_rounded,
                                  color: streakColor, size: 14),
                              const SizedBox(width: 3),
                              Text(
                                '$currentStreak dias',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: streakColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Recorde: $bestStreak',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDarkMode
                                ? Colors.white.withValues(alpha: 0.4)
                                : AppTheme.textSecondaryColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Check-in status
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      _CheckInDot(
                        label: 'Voce',
                        checked: duoStreak.myCheckIn,
                      ),
                      const SizedBox(width: 10),
                      _CheckInDot(
                        label: duoStreak.friend.name.split(' ').first,
                        checked: duoStreak.friendCheckIn,
                      ),
                    ],
                  ),
                  if (!duoStreak.myCheckIn) ...[
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: onCheckIn,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: streakColor,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        minimumSize: const Size(0, 30),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        elevation: 0,
                      ),
                      child: const Text('Check-in',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.white)),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CheckInDot extends StatelessWidget {
  final String label;
  final bool checked;

  const _CheckInDot({
    required this.label,
    required this.checked,
  });

  @override
  Widget build(BuildContext context) {
    final color = checked ? const Color(0xFF4CAF50) : Colors.grey;

    return Column(
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: checked ? color.withValues(alpha: 0.15) : Colors.transparent,
            shape: BoxShape.circle,
            border: Border.all(
              color: color.withValues(alpha: checked ? 0.6 : 0.3),
              width: 1.5,
            ),
          ),
          child: checked
              ? const Icon(Icons.check_rounded,
                  color: Color(0xFF4CAF50), size: 14)
              : null,
        ),
        const SizedBox(height: 3),
        Text(
          label.length > 6 ? '${label.substring(0, 6)}.' : label,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w500,
            color: color,
          ),
        ),
      ],
    );
  }
}

// ==================== FRIEND CARD ====================
class _FriendCard extends StatelessWidget {
  final Friend friendData;
  final VoidCallback onPing;
  final VoidCallback onRemove;

  const _FriendCard({
    required this.friendData,
    required this.onPing,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryColor =
        isDarkMode ? AppTheme.primaryColorDarkMode : AppTheme.primaryColor;
    final currentStreak = friendData.friendStreak?.currentStreak ?? 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Card(
        margin: EdgeInsets.zero,
        elevation: 1.5,
        shadowColor: isDarkMode
            ? Colors.black.withValues(alpha: 0.3)
            : Colors.black.withValues(alpha: 0.08),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        color: isDarkMode ? AppTheme.darkCardColor : Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: primaryColor.withValues(alpha: 0.12),
                child: Text(
                  friendData.friend.name.isNotEmpty
                      ? friendData.friend.name[0].toUpperCase()
                      : '?',
                  style: TextStyle(
                    color: primaryColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      friendData.friend.name,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: isDarkMode
                            ? Colors.white
                            : AppTheme.textPrimaryColor,
                      ),
                    ),
                    if (currentStreak > 0) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF5722).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.local_fire_department_rounded,
                                color: Color(0xFFFF5722), size: 13),
                            const SizedBox(width: 3),
                            Text(
                              '$currentStreak dias',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFFFF5722),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: isDarkMode
                        ? Colors.white.withValues(alpha: 0.06)
                        : AppTheme.surfaceColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.more_horiz_rounded,
                    color: isDarkMode
                        ? Colors.white.withValues(alpha: 0.5)
                        : AppTheme.textSecondaryColor,
                    size: 20,
                  ),
                ),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                onSelected: (value) {
                  if (value == 'ping') onPing();
                  if (value == 'remove') onRemove();
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'ping',
                    child: Row(
                      children: [
                        Icon(Icons.notifications_active_rounded,
                            size: 18, color: primaryColor),
                        const SizedBox(width: 10),
                        const Text('Cutucar'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'remove',
                    child: Row(
                      children: [
                        Icon(Icons.person_remove_rounded,
                            size: 18, color: Colors.red),
                        SizedBox(width: 10),
                        Text('Remover', style: TextStyle(color: Colors.red)),
                      ],
                    ),
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

// ==================== EMPTY FRIENDS STATE ====================
class _EmptyFriendsState extends StatelessWidget {
  final VoidCallback onSearchTap;

  const _EmptyFriendsState({
    required this.onSearchTap,
  });

  @override
  Widget build(BuildContext context) {
    return DietStyleMessageState(
      title: 'Nenhum amigo ainda',
      message: 'Use a busca acima para encontrar usuarios e montar sua rede.',
      fallbackIcon: Icons.people_outline_rounded,
      primaryActionLabel: 'Buscar amigos',
      primaryActionIcon: Icons.search_rounded,
      onPrimaryAction: onSearchTap,
      topSpacing: 16,
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
    );
  }
}
