import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../providers/free_chat_provider.dart';
import '../providers/daily_meals_provider.dart';

/// Tela de busca unificada: conversas livres + dias do diário
class UnifiedSearchScreen extends StatefulWidget {
  final void Function(String chatId, String title) onOpenFreeChat;
  final void Function(DateTime date) onOpenDiaryDate;

  const UnifiedSearchScreen({
    super.key,
    required this.onOpenFreeChat,
    required this.onOpenDiaryDate,
  });

  @override
  State<UnifiedSearchScreen> createState() => _UnifiedSearchScreenState();
}

class _UnifiedSearchScreenState extends State<UnifiedSearchScreen> {
  final _queryController = TextEditingController();
  String _query = '';
  List<_DiaryHit> _diaryHits = [];
  bool _loadingDiary = false;

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _searchDiary(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _diaryHits = []);
      return;
    }
    setState(() => _loadingDiary = true);
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith('nutrition_chat_'));
    final q = query.toLowerCase();
    final hits = <_DiaryHit>[];
    for (final key in keys) {
      final raw = prefs.getString(key);
      if (raw == null) continue;
      try {
        final data = jsonDecode(raw);
        final messages = (data['messages'] as List?) ?? [];
        for (final m in messages) {
          final text = (m['message'] as String?)?.toLowerCase() ?? '';
          if (text.contains(q)) {
            // Extrai yyyy-MM-dd do final da key
            final dateStr = key.split('_').last;
            final parts = dateStr.split('-');
            if (parts.length == 3) {
              final date = DateTime(int.parse(parts[0]), int.parse(parts[1]),
                  int.parse(parts[2]));
              hits.add(_DiaryHit(
                  date: date, snippet: m['message'] as String? ?? ''));
              break; // um hit por dia
            }
          }
        }
      } catch (_) {}
    }
    hits.sort((a, b) => b.date.compareTo(a.date));
    if (mounted) {
      setState(() {
        _diaryHits = hits;
        _loadingDiary = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final freeChatProvider = context.watch<FreeChatProvider>();
    final q = _query.trim().toLowerCase();

    final freeHits = q.isEmpty
        ? <FreeChatConversation>[]
        : freeChatProvider.conversations.where((c) {
            if (c.title.toLowerCase().contains(q)) return true;
            for (final m in c.messages) {
              final text = (m['message'] as String?)?.toLowerCase() ?? '';
              if (text.contains(q)) return true;
            }
            return false;
          }).toList();

    return Scaffold(
      backgroundColor:
          isDarkMode ? const Color(0xFF171717) : Colors.white,
      appBar: AppBar(
        backgroundColor:
            isDarkMode ? const Color(0xFF171717) : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back,
              color: isDarkMode ? Colors.white : Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: TextField(
          controller: _queryController,
          autofocus: true,
          style: TextStyle(
              fontSize: 16,
              color: isDarkMode ? Colors.white : Colors.black87),
          decoration: InputDecoration(
            hintText: 'Buscar em conversas e diário...',
            hintStyle: TextStyle(
                color: isDarkMode ? Colors.white38 : Colors.black38),
            border: InputBorder.none,
          ),
          onChanged: (v) {
            setState(() => _query = v);
            _searchDiary(v);
          },
        ),
      ),
      body: q.isEmpty
          ? Center(
              child: Text(
                'Digite para buscar',
                style: TextStyle(
                  color: isDarkMode ? Colors.white38 : Colors.black38,
                ),
              ),
            )
          : ListView(
              children: [
                if (freeHits.isNotEmpty) ...[
                  _sectionHeader('Conversas livres', isDarkMode),
                  ...freeHits.map((c) => ListTile(
                        leading: Icon(Icons.chat_bubble_outline,
                            size: 20,
                            color: isDarkMode
                                ? Colors.white70
                                : Colors.black54),
                        title: Text(c.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 14,
                                color: isDarkMode
                                    ? Colors.white
                                    : Colors.black87)),
                        onTap: () {
                          Navigator.pop(context);
                          widget.onOpenFreeChat(c.id, c.title);
                        },
                      )),
                ],
                if (_loadingDiary)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(
                        child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2))),
                  ),
                if (_diaryHits.isNotEmpty) ...[
                  _sectionHeader('Diário', isDarkMode),
                  ..._diaryHits.map((h) => ListTile(
                        leading: Icon(Icons.calendar_today,
                            size: 20,
                            color: isDarkMode
                                ? Colors.white70
                                : Colors.black54),
                        title: Text(_formatDate(h.date),
                            style: TextStyle(
                                fontSize: 14,
                                color: isDarkMode
                                    ? Colors.white
                                    : Colors.black87)),
                        subtitle: Text(h.snippet,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 12,
                                color: isDarkMode
                                    ? Colors.white54
                                    : Colors.black54)),
                        onTap: () {
                          final mealsProvider =
                              context.read<DailyMealsProvider>();
                          mealsProvider.setSelectedDate(h.date);
                          Navigator.pop(context);
                          widget.onOpenDiaryDate(h.date);
                        },
                      )),
                ],
                if (freeHits.isEmpty && _diaryHits.isEmpty && !_loadingDiary)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Text('Nenhum resultado',
                          style: TextStyle(
                              color: isDarkMode
                                  ? Colors.white38
                                  : Colors.black38)),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _sectionHeader(String text, bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: isDarkMode ? Colors.white54 : Colors.black54,
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final d = DateTime(date.year, date.month, date.day);
    final today = DateTime(now.year, now.month, now.day);
    final diff = today.difference(d).inDays;
    if (diff == 0) return 'Hoje';
    if (diff == 1) return 'Ontem';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}

class _DiaryHit {
  final DateTime date;
  final String snippet;
  _DiaryHit({required this.date, required this.snippet});
}
