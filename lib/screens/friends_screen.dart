import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/friends_provider.dart';
import '../services/social_service.dart';
import '../theme/app_theme.dart';

class FriendsScreen extends StatefulWidget {
  final bool isEmbedded;

  const FriendsScreen({Key? key, this.isEmbedded = false}) : super(key: key);

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<SearchedUser> _searchResults = [];
  bool _showPendingRequests = false;
  bool _showSentRequests = false;

  @override
  void dispose() {
    _searchController.dispose();
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

    return Consumer<FriendsProvider>(
      builder: (context, friendsProvider, child) {
        return RefreshIndicator(
          onRefresh: friendsProvider.refresh,
          child: CustomScrollView(
            slivers: [
              // Search bar
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Buscar usuarios...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _searchResults = [];
                                });
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: isDarkMode ? Colors.white10 : Colors.grey[100],
                    ),
                    onChanged: _searchUsers,
                  ),
                ),
              ),

              // Search results
              if (_searchResults.isNotEmpty)
                SliverToBoxAdapter(
                  child: _SearchResultsSection(
                    results: _searchResults,
                    onSendRequest: (userId) async {
                      final success = await friendsProvider.sendFriendRequest(userId);
                      if (success) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Pedido enviado!')),
                        );
                        // Re-search to update status
                        _searchUsers(_searchController.text);
                      }
                    },
                  ),
                ),

              // Pending requests toggle
              if (friendsProvider.hasPendingRequests)
                SliverToBoxAdapter(
                  child: _PendingRequestsHeader(
                    count: friendsProvider.receivedRequests.length,
                    isExpanded: _showPendingRequests,
                    onToggle: () => setState(() => _showPendingRequests = !_showPendingRequests),
                  ),
                ),

              // Pending requests list
              if (_showPendingRequests && friendsProvider.receivedRequests.isNotEmpty)
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final request = friendsProvider.receivedRequests[index];
                      return _PendingRequestCard(
                        request: request,
                        onAccept: () => friendsProvider.acceptRequest(request.id),
                        onReject: () => friendsProvider.rejectRequest(request.id),
                      );
                    },
                    childCount: friendsProvider.receivedRequests.length,
                  ),
                ),

              // Sent requests toggle
              if (friendsProvider.hasSentRequests)
                SliverToBoxAdapter(
                  child: _SentRequestsHeader(
                    count: friendsProvider.sentRequests.length,
                    isExpanded: _showSentRequests,
                    onToggle: () => setState(() => _showSentRequests = !_showSentRequests),
                  ),
                ),

              // Sent requests list
              if (_showSentRequests && friendsProvider.sentRequests.isNotEmpty)
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final request = friendsProvider.sentRequests[index];
                      return _SentRequestCard(
                        request: request,
                        onCancel: () async {
                          final success = await friendsProvider.cancelSentRequest(request.id);
                          if (success) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Pedido cancelado')),
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
                    icon: Icons.local_fire_department,
                    iconColor: Colors.deepOrange,
                  ),
                ),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final duo = friendsProvider.duoStreaks[index];
                      return _DuoStreakCard(
                        duoStreak: duo,
                        onCheckIn: () => friendsProvider.duoCheckIn(duo.friendshipId),
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
                  icon: Icons.people,
                  count: friendsProvider.friends.length,
                ),
              ),

              if (friendsProvider.friends.isEmpty)
                SliverToBoxAdapter(
                  child: _EmptyFriendsState(),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final friendData = friendsProvider.friends[index];
                      return _FriendCard(
                        friendData: friendData,
                        onPing: () => _showPingDialog(context, friendData, friendsProvider),
                        onRemove: () => _confirmRemoveFriend(context, friendData, friendsProvider),
                      );
                    },
                    childCount: friendsProvider.friends.length,
                  ),
                ),

              // Bottom padding
              const SliverToBoxAdapter(
                child: SizedBox(height: 80),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showPingDialog(BuildContext context, Friend friendData, FriendsProvider provider) {
    final messageController = TextEditingController();
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDarkMode ? AppTheme.darkCardColor : Colors.white,
        title: Text('Cutucar ${friendData.friend.name}'),
        content: TextField(
          controller: messageController,
          decoration: const InputDecoration(
            hintText: 'Mensagem opcional...',
            border: OutlineInputBorder(),
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
                message: messageController.text.isEmpty ? null : messageController.text,
              );
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(success ? 'Ping enviado!' : 'Erro ao enviar ping'),
                ),
              );
            },
            child: const Text('Enviar'),
          ),
        ],
      ),
    );
  }

  void _confirmRemoveFriend(BuildContext context, Friend friendData, FriendsProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remover amigo'),
        content: Text('Remover ${friendData.friend.name} da sua lista de amigos?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              await provider.removeFriend(friendData.friendshipId);
              Navigator.pop(ctx);
            },
            child: const Text('Remover', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

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

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Row(
        children: [
          Icon(icon, color: iconColor ?? (isDarkMode ? Colors.white70 : Colors.grey[700]), size: 20),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
          if (count != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: isDarkMode ? Colors.white10 : Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                count.toString(),
                style: TextStyle(
                  fontSize: 12,
                  color: isDarkMode ? Colors.white70 : Colors.grey[600],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

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

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isDarkMode ? AppTheme.darkCardColor : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(13),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              'Resultados da busca',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isDarkMode ? Colors.white54 : Colors.grey,
              ),
            ),
          ),
          ...results.map((user) => ListTile(
                leading: CircleAvatar(
                  backgroundColor: Theme.of(context).primaryColor.withAlpha(51),
                  child: Text(
                    user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                    style: TextStyle(color: Theme.of(context).primaryColor),
                  ),
                ),
                title: Text(
                  user.name,
                  style: TextStyle(color: isDarkMode ? Colors.white : Colors.black87),
                ),
                subtitle: user.username != null
                    ? Text(
                        '@${user.username}',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDarkMode ? Colors.white54 : Colors.grey,
                        ),
                      )
                    : null,
                trailing: _buildActionButton(context, user),
              )),
        ],
      ),
    );
  }

  Widget _buildActionButton(BuildContext context, SearchedUser user) {
    // Check friendship status
    if (user.friendshipStatus == 'ACCEPTED') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.green.withAlpha(26),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Text(
          'Amigo',
          style: TextStyle(color: Colors.green, fontSize: 12),
        ),
      );
    }

    if (user.friendshipStatus == 'PENDING') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.orange.withAlpha(26),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Text(
          'Pendente',
          style: TextStyle(color: Colors.orange, fontSize: 12),
        ),
      );
    }

    return ElevatedButton(
      onPressed: () => onSendRequest(user.id),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        minimumSize: const Size(0, 32),
      ),
      child: const Text('Adicionar'),
    );
  }
}

class _PendingRequestsHeader extends StatelessWidget {
  final int count;
  final bool isExpanded;
  final VoidCallback onToggle;

  const _PendingRequestsHeader({
    required this.count,
    required this.isExpanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onToggle,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.orange.withAlpha(26),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange.withAlpha(51)),
        ),
        child: Row(
          children: [
            const Icon(Icons.person_add, color: Colors.orange),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '$count pedido${count > 1 ? 's' : ''} de amizade',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
            ),
            Icon(
              isExpanded ? Icons.expand_less : Icons.expand_more,
              color: Colors.orange,
            ),
          ],
        ),
      ),
    );
  }
}

class _PendingRequestCard extends StatelessWidget {
  final FriendRequest request;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const _PendingRequestCard({
    required this.request,
    required this.onAccept,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      color: isDarkMode ? AppTheme.darkCardColor : Colors.white,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).primaryColor.withAlpha(51),
          child: Text(
            request.user.name.isNotEmpty ? request.user.name[0].toUpperCase() : '?',
            style: TextStyle(color: Theme.of(context).primaryColor),
          ),
        ),
        title: Text(
          request.user.name,
          style: TextStyle(color: isDarkMode ? Colors.white : Colors.black87),
        ),
        subtitle: Text(
          _formatTime(request.createdAt),
          style: TextStyle(
            fontSize: 12,
            color: isDarkMode ? Colors.white54 : Colors.grey,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.close, color: Colors.red),
              onPressed: onReject,
            ),
            IconButton(
              icon: const Icon(Icons.check, color: Colors.green),
              onPressed: onAccept,
            ),
          ],
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

class _SentRequestsHeader extends StatelessWidget {
  final int count;
  final bool isExpanded;
  final VoidCallback onToggle;

  const _SentRequestsHeader({
    required this.count,
    required this.isExpanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onToggle,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.blue.withAlpha(26),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.blue.withAlpha(51)),
        ),
        child: Row(
          children: [
            const Icon(Icons.send, color: Colors.blue),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '$count pedido${count > 1 ? 's' : ''} enviado${count > 1 ? 's' : ''}',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
            ),
            Icon(
              isExpanded ? Icons.expand_less : Icons.expand_more,
              color: Colors.blue,
            ),
          ],
        ),
      ),
    );
  }
}

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

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      color: isDarkMode ? AppTheme.darkCardColor : Colors.white,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.blue.withAlpha(51),
          child: Text(
            request.user.name.isNotEmpty ? request.user.name[0].toUpperCase() : '?',
            style: const TextStyle(color: Colors.blue),
          ),
        ),
        title: Text(
          request.user.name,
          style: TextStyle(color: isDarkMode ? Colors.white : Colors.black87),
        ),
        subtitle: Text(
          'Enviado ${_formatTime(request.createdAt)}',
          style: TextStyle(
            fontSize: 12,
            color: isDarkMode ? Colors.white54 : Colors.grey,
          ),
        ),
        trailing: TextButton.icon(
          onPressed: onCancel,
          icon: const Icon(Icons.close, color: Colors.red, size: 18),
          label: const Text('Cancelar', style: TextStyle(color: Colors.red)),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8),
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

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      color: isDarkMode ? AppTheme.darkCardColor : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Friend avatar
            CircleAvatar(
              backgroundColor: Colors.deepOrange.withAlpha(51),
              child: Text(
                duoStreak.friend.name.isNotEmpty ? duoStreak.friend.name[0].toUpperCase() : '?',
                style: const TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 12),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    duoStreak.friend.name,
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: isDarkMode ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.local_fire_department, color: Colors.deepOrange, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        '$currentStreak dias',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.deepOrange,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Recorde: $bestStreak',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDarkMode ? Colors.white54 : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Check-in status
            Column(
              children: [
                Row(
                  children: [
                    _CheckInIndicator(
                      label: 'Voce',
                      checked: duoStreak.myCheckIn,
                    ),
                    const SizedBox(width: 8),
                    _CheckInIndicator(
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
                      backgroundColor: Colors.deepOrange,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      minimumSize: const Size(0, 28),
                    ),
                    child: const Text('Check-in', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CheckInIndicator extends StatelessWidget {
  final String label;
  final bool checked;

  const _CheckInIndicator({
    required this.label,
    required this.checked,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(
          checked ? Icons.check_circle : Icons.circle_outlined,
          color: checked ? Colors.green : Colors.grey,
          size: 20,
        ),
        Text(
          label.length > 6 ? '${label.substring(0, 6)}.' : label,
          style: TextStyle(
            fontSize: 10,
            color: checked ? Colors.green : Colors.grey,
          ),
        ),
      ],
    );
  }
}

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
    final currentStreak = friendData.friendStreak?.currentStreak ?? 0;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      color: isDarkMode ? AppTheme.darkCardColor : Colors.white,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).primaryColor.withAlpha(51),
          child: Text(
            friendData.friend.name.isNotEmpty ? friendData.friend.name[0].toUpperCase() : '?',
            style: TextStyle(color: Theme.of(context).primaryColor),
          ),
        ),
        title: Text(
          friendData.friend.name,
          style: TextStyle(color: isDarkMode ? Colors.white : Colors.black87),
        ),
        subtitle: currentStreak > 0
            ? Row(
                children: [
                  const Icon(Icons.local_fire_department, color: Colors.deepOrange, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    '$currentStreak dias',
                    style: const TextStyle(fontSize: 12, color: Colors.deepOrange),
                  ),
                ],
              )
            : null,
        trailing: PopupMenuButton<String>(
          icon: Icon(
            Icons.more_vert,
            color: isDarkMode ? Colors.white54 : Colors.grey,
          ),
          onSelected: (value) {
            if (value == 'ping') onPing();
            if (value == 'remove') onRemove();
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'ping',
              child: Row(
                children: [
                  Icon(Icons.notifications_active, size: 20),
                  SizedBox(width: 8),
                  Text('Cutucar'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'remove',
              child: Row(
                children: [
                  Icon(Icons.person_remove, size: 20, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Remover', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyFriendsState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_outline,
            size: 64,
            color: isDarkMode ? Colors.white24 : Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            'Nenhum amigo ainda',
            style: TextStyle(
              fontSize: 16,
              color: isDarkMode ? Colors.white60 : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Use a busca acima para encontrar amigos!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: isDarkMode ? Colors.white38 : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}
