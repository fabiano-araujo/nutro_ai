import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'package:intl/intl.dart';
import 'dart:convert';

import '../services/storage_service.dart';
import '../services/event_service.dart';
import '../models/study_item.dart';
import '../theme/app_theme.dart';
import '../i18n/app_localizations_extension.dart';
import '../widgets/credit_indicator.dart';
import 'settings_screen.dart';
import 'ai_tutor_screen.dart';
import 'document_summary_screen.dart';
import 'text_enhancement_screen.dart';
import 'code_enhancer_screen.dart';
import 'document_scan_screen.dart';
import 'camera_scan_screen.dart';

class HistoryWidget extends StatefulWidget {
  const HistoryWidget({Key? key}) : super(key: key);

  @override
  _HistoryWidgetState createState() => _HistoryWidgetState();
}

class _HistoryWidgetState extends State<HistoryWidget>
    with SingleTickerProviderStateMixin {
  final StorageService _storageService = StorageService();
  final EventService _eventService = EventService();
  late TabController _tabController;
  late StreamSubscription _historySubscription;

  List<StudyItem> _history = [];
  List<StudyItem> _favorites = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();

    // Inscrever-se para atualizações do histórico
    _historySubscription = _eventService.historyStream.listen((_) {
      // Recarregar dados quando o histórico for atualizado
      _loadData();
    });
  }

  @override
  void dispose() {
    _historySubscription.cancel();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final history = await _storageService.getHistory();
      // DEBUG: Printar informações detalhadas se o primeiro item mudou
      if (history.isNotEmpty &&
          (_history.isEmpty || history[0].id != _history[0].id)) {
        final item = history[0];
        bool isTool = false;
        String toolType = '';
        String initialPrompt = item.content;
        List<dynamic> allMessages = [];
        try {
          if (item.content.startsWith('{') && item.content.endsWith('}')) {
            final Map<String, dynamic> toolData = json.decode(item.content);
            isTool = (toolData.containsKey('toolName') ||
                    toolData.containsKey('sourceType')) &&
                (toolData.containsKey('fullPrompt') ||
                    toolData.containsKey('conversationHistory'));
            toolType = toolData['sourceType']?.toString() ??
                toolData['toolName']?.toString() ??
                '';
            initialPrompt = item.content;
            if (toolData.containsKey('conversationHistory') &&
                toolData['conversationHistory'] is Map &&
                toolData['conversationHistory'].containsKey('messages')) {
              allMessages = toolData['conversationHistory']['messages'];
            }
          }
        } catch (e) {
          // Ignorar erros de parsing
        }
        print("#########################################");
        print(history[0].toJson().toString());
        print("#########################################");

        print('\n================ NOVO ITEM NO HISTÓRICO ================');
        print('É ferramenta? ${isTool ? 'SIM' : 'NÃO'}');
        print('Tipo: ${isTool ? toolType : item.type}');
        print('InitialPrompt (JSON):');
        print(initialPrompt);
        print('Mensagens:');
        if (allMessages.isNotEmpty) {
          for (int i = 0; i < allMessages.length; i++) {
            final msg = allMessages[i];
            final isUser = msg['isUser'] == true;
            final texto = msg['message'] ?? '';
            print(
                '  ${i + 1}. ${isUser ? '👤 Usuário' : '🤖 IA'}: ${texto.length > 80 ? texto.substring(0, 80) + '...' : texto}');
          }
        } else {
          print('  (Sem mensagens extras no conversationHistory)');
        }
        print('========================================================\n');
      }
      final favorites = await _storageService.getFavorites();

      setState(() {
        _history = history;
        _favorites = favorites;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading history data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _addToFavorites(StudyItem item) async {
    try {
      await _storageService.saveToFavorites(item);
      _loadData(); // Reload data to update both lists
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr.translate('added_to_favorites'))),
      );
    } catch (e) {
      print('Error adding to favorites: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(context.tr.translate('error_adding_to_favorites')),
            backgroundColor: AppTheme.errorColor),
      );
    }
  }

  Future<void> _removeFromFavorites(String itemId) async {
    try {
      await _storageService.removeFromFavorites(itemId);
      _loadData(); // Reload data to update both lists
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr.translate('removed_from_favorites'))),
      );
    } catch (e) {
      print('Error removing from favorites: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text(context.tr.translate('error_removing_from_favorites')),
            backgroundColor: AppTheme.errorColor),
      );
    }
  }

  // Método para remover um item do histórico
  Future<void> _removeFromHistory(String itemId) async {
    try {
      await _storageService.removeFromHistory(itemId);
      _loadData(); // Recarregar dados para atualizar ambas as listas
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr.translate('removed_from_history'))),
      );
    } catch (e) {
      print('Error removing from history: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(context.tr.translate('error_removing_from_history')),
            backgroundColor: AppTheme.errorColor),
      );
    }
  }

  // Exibir diálogo de confirmação para deletar um item
  void _showDeleteConfirmationDialog(StudyItem item, bool isHistoryList) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: colorScheme.surfaceContainerHigh,
          title: Text(context.tr.translate('delete_item')),
          content: Text(context.tr.translate(isHistoryList
              ? 'delete_history_confirmation'
              : 'delete_favorite_confirmation')),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(context.tr.translate('cancel')),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                if (isHistoryList) {
                  _removeFromHistory(item.id);
                } else {
                  _removeFromFavorites(item.id);
                }
              },
              child: Text(
                context.tr.translate('delete'),
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      children: [
        // TabBar sem AppBar
        Container(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: colorScheme.outlineVariant.withOpacity(0.3),
                width: 0.5,
              ),
            ),
          ),
          child: TabBar(
            controller: _tabController,
            tabs: [
              Tab(text: context.tr.translate('history_tab')),
              Tab(text: context.tr.translate('favorites_tab')),
            ],
            indicatorColor: theme.colorScheme.primary,
            labelColor: theme.colorScheme.primary,
            unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
            indicatorWeight: 3,
            labelStyle: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            unselectedLabelStyle: theme.textTheme.labelLarge,
            dividerColor: colorScheme.outlineVariant.withOpacity(0.3),
            indicatorSize: TabBarIndicatorSize.label,
          ),
        ),

        // Conteúdo das Tabs
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              // History Tab
              _isLoading
                  ? _buildLoadingIndicator()
                  : _history.isEmpty
                      ? _buildEmptyState(
                          context.tr.translate('no_history_found'),
                          context.tr.translate('use_app_to_see_history'))
                      : _buildItemList(_history, isHistoryList: true),

              // Favorites Tab
              _isLoading
                  ? _buildLoadingIndicator()
                  : _favorites.isEmpty
                      ? _buildEmptyState(
                          context.tr.translate('no_favorites_found'),
                          context.tr.translate('add_items_to_favorites'))
                      : _buildItemList(_favorites, isHistoryList: false),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingIndicator() {
    return Center(
      child: CircularProgressIndicator(),
    );
  }

  Widget _buildEmptyState(String title, String message) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.history_edu_outlined,
            size: 64,
            color: colorScheme.onSurfaceVariant.withOpacity(0.5),
          ),
          SizedBox(height: 20),
          Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              color: colorScheme.onSurface,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 10),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemList(List<StudyItem> items, {required bool isHistoryList}) {
    final grouped = <String, List<StudyItem>>{};
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Group items by date
    for (var item in items) {
      final date = DateFormat('dd/MM/yyyy').format(item.timestamp);
      if (!grouped.containsKey(date)) {
        grouped[date] = [];
      }
      grouped[date]!.add(item);
    }

    // Sort dates in descending order
    final sortedDates = grouped.keys.toList()
      ..sort((a, b) {
        final dateA = DateFormat('dd/MM/yyyy').parse(a);
        final dateB = DateFormat('dd/MM/yyyy').parse(b);
        return dateB.compareTo(dateA);
      });

    return ListView.builder(
      padding: EdgeInsets.symmetric(vertical: 8),
      itemCount: sortedDates.length,
      itemBuilder: (context, index) {
        final date = sortedDates[index];
        final dateItems = grouped[date]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                _formatDate(date),
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
            ),
            ...dateItems.map((item) {
              // Envolver todos os itens com Dismissible (histórico e favoritos)
              return Dismissible(
                key: Key(item.id),
                background: Container(
                  color: Colors.red,
                  alignment: Alignment.centerRight,
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Icon(
                        Icons.delete,
                        color: Colors.white,
                      ),
                      SizedBox(width: 8),
                      Text(
                        context.tr.translate('delete'),
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                direction: DismissDirection.endToStart,
                confirmDismiss: (direction) async {
                  // Confirmar antes de excluir
                  return await showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return AlertDialog(
                        title: Text(context.tr.translate('confirm_delete')),
                        content: Text(
                          isHistoryList
                              ? context.tr
                                  .translate('delete_history_confirmation')
                              : context.tr
                                  .translate('delete_favorite_confirmation'),
                        ),
                        actions: <Widget>[
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            child: Text(context.tr.translate('cancel')),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            child: Text(
                              context.tr.translate('delete'),
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
                onDismissed: (direction) async {
                  // Excluir do histórico ou dos favoritos
                  if (isHistoryList) {
                    await _removeFromHistory(item.id);
                  } else {
                    await _removeFromFavorites(item.id);
                  }
                },
                child: _buildHistoryItem(item, isHistoryList),
              );
            }).toList(),
          ],
        );
      },
    );
  }

  Widget _buildHistoryItem(StudyItem item, bool isHistoryList) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    IconData iconData;
    Color iconColor;
    String typeLabel = '';

    // Definir ícone, cor e rótulo com base no tipo
    switch (item.type) {
      case 'scan':
        iconData = Icons.document_scanner_outlined;
        iconColor = colorScheme.primary;
        typeLabel = 'Scanner';
        break;
      case 'enhancement':
        iconData = Icons.edit_note_outlined;
        iconColor = colorScheme.secondary;
        typeLabel = 'Texto';
        break;
      case 'summary':
        iconData = Icons.description_outlined;
        iconColor = colorScheme.tertiary;
        typeLabel = 'Resumo';
        break;
      case 'tutor':
        iconData = Icons.school_outlined;
        iconColor = colorScheme.primaryContainer;
        typeLabel = 'Tutor';
        break;
      case 'conversation':
        iconData = Icons.chat_bubble_outline;
        iconColor = colorScheme.secondaryContainer;
        typeLabel = 'Chat';
        break;
      case 'youtube':
        iconData = Icons.play_circle_outline;
        iconColor = Colors.red;
        typeLabel = 'YouTube';
        break;
      case 'code':
        iconData = Icons.code;
        iconColor = colorScheme.tertiary;
        typeLabel = 'Código';
        break;
      case 'camera':
        iconData = Icons.camera_alt_outlined;
        iconColor = colorScheme.primary;
        typeLabel = 'Câmera';
        break;
      default:
        iconData = Icons.lightbulb_outline;
        iconColor = colorScheme.onSurfaceVariant;
        typeLabel = 'Outro';
    }

    // Check if this item is in favorites
    final isFavorite = _favorites.any((favItem) => favItem.id == item.id);

    // Determinar o subtítulo
    String subtitleText = '';
    bool isToolItem = false;
    if (item.content.startsWith('{') && item.content.endsWith('}')) {
      try {
        final Map<String, dynamic> toolData = json.decode(item.content);
        if (toolData.containsKey('userInput')) {
          subtitleText = toolData['userInput'] as String? ?? '';
          isToolItem = true; // Indica que o content é um JSON de ferramenta
        }
      } catch (e) {
        // Não é um JSON válido, ou não tem userInput, tratar como conteúdo normal
      }
    }

    if (!isToolItem) {
      // Se não for um JSON de ferramenta ou não tiver userInput, usar o content limpo
      subtitleText = item.content
          .replaceAll("###USER_MESSAGE###", "")
          .replaceAll("###USer_MESSAGE###", "")
          .replaceAll("###USer_message###", "")
          .replaceAll("###User_Message###", "")
          .replaceAll("###user_message###", "");
    }

    // Para garantir que o subtítulo não esteja vazio, especialmente se o userInput da ferramenta estiver vazio
    if (subtitleText.isEmpty && isToolItem) {
      subtitleText = context.tr.translate(
          'tool_interaction_no_input'); // Ex: "Interação com ferramenta"
    } else if (subtitleText.isEmpty && !isToolItem) {
      subtitleText =
          context.tr.translate('empty_content'); // Ex: "Conteúdo vazio"
    }

    return Card(
      elevation: 1,
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: colorScheme.surfaceContainerHighest,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          // Navegar diretamente para AITutorScreen independente do tipo
          if (item.type == 'tutor' || item.type == 'conversation') {
            // Para tutor e conversation, usar o ID da conversa
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AITutorScreen(
                  conversationId: item.id,
                ),
              ),
            );
          } else {
            // Para outros tipos, verificar se item.content é o JSON da ferramenta
            String? jsonDataFromHistory = item.content;
            Map<String, dynamic>? toolDataMap;
            bool isToolJsonValid = false;

            if (jsonDataFromHistory.startsWith('{') &&
                jsonDataFromHistory.endsWith('}')) {
              try {
                toolDataMap = json.decode(jsonDataFromHistory);
                // Validação mais flexível para ferramentas:
                // 1. Tem toolName OU sourceType
                // 2. Tem fullPrompt OU conversationHistory
                if (toolDataMap != null &&
                    (toolDataMap.containsKey('toolName') ||
                        toolDataMap.containsKey('sourceType')) &&
                    (toolDataMap.containsKey('fullPrompt') ||
                        toolDataMap.containsKey('conversationHistory'))) {
                  isToolJsonValid = true;
                  print('HistoryScreen: JSON de ferramenta válido detectado');
                }
              } catch (e) {
                print(
                    "HistoryScreen: Erro ao decodificar item.content como JSON: $e");
              }
            }

            if (isToolJsonValid) {
              // Adicionar logs para depurar o toolDataMap
              print('\n');
              print(
                  '🔍 ==================== HISTÓRICO - ITEM CLICADO ====================');
              print('🔍 Tipo: ${item.type}');
              print('🔍 Título: ${item.title}');
              print('🔍 ID do item: ${item.id}');

              // MODIFICADO: Extrair conversationId do toolDataMap
              String? conversationIdFromToolData;
              if (toolDataMap != null &&
                  toolDataMap.containsKey('conversationId') &&
                  toolDataMap['conversationId'] != null &&
                  toolDataMap['conversationId'].toString().isNotEmpty) {
                conversationIdFromToolData =
                    toolDataMap['conversationId'].toString();
                print(
                    '📱 HistoryScreen: Encontrado conversationId no toolData: $conversationIdFromToolData');
              }

              // Verificar se existe histórico de conversa no toolData
              bool hasConversationHistory = toolDataMap != null &&
                  toolDataMap.containsKey('conversationHistory') &&
                  toolDataMap['conversationHistory'] != null;

              if (hasConversationHistory) {
                print('📝 Histórico de conversa encontrado no toolData:');
                if (toolDataMap!['conversationHistory'] is Map &&
                    toolDataMap['conversationHistory']
                        .containsKey('messages')) {
                  List<dynamic>? messagesList =
                      toolDataMap['conversationHistory']['messages'] as List?;
                  int numMessages = messagesList?.length ?? 0;
                  print('📝 Número de mensagens no histórico: $numMessages');

                  // Exibir detalhes das primeiras 3 mensagens
                  if (messagesList != null && messagesList.isNotEmpty) {
                    int messagesToShow =
                        messagesList.length > 3 ? 3 : messagesList.length;
                    print('📝 Primeiras $messagesToShow mensagens:');
                    for (int i = 0; i < messagesToShow; i++) {
                      var msg = messagesList[i];
                      bool isUser = msg['isUser'] ?? false;
                      String mensagem = msg['message'] ?? '';
                      if (mensagem.length > 50) {
                        mensagem = mensagem.substring(0, 50) + '...';
                      }
                      print('   ${i + 1}. ${isUser ? '👤' : '🤖'} $mensagem');
                    }
                  }
                }
              } else {
                print('⚠️ Nenhum histórico de conversa encontrado no toolData');
              }

              // Garantir que o toolData está atualizado no jsonDataFromHistory
              if (hasConversationHistory) {
                jsonDataFromHistory = json.encode(toolDataMap);
                print(
                    '🔄 JSON da ferramenta atualizado com histórico de conversas');
              }

              print(
                  '🔍 ================================================================\n');

              // CORRIGIDO: Sempre passar o JSON da ferramenta para initialPrompt
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AITutorScreen(
                    conversationId:
                        conversationIdFromToolData, // Usar o conversationId se disponível
                    initialPrompt:
                        jsonDataFromHistory, // SEMPRE passar o JSON da ferramenta atualizado
                    initialToolResponse: item
                        .response, // Passar a resposta original (pode ser ignorada se conversationId carregar tudo)
                  ),
                ),
              );
            } else {
              // Fallback: Se item.content não for o JSON esperado (itens antigos ou erro)
              // construir toolData como antes.
              final cleanContentForFallback = item.content
                  .replaceAll("###USER_MESSAGE###", "")
                  .replaceAll("###USer_MESSAGE###", "")
                  .replaceAll("###USer_message###", "")
                  .replaceAll("###User_Message###", "")
                  .replaceAll("###user_message###", "");

              final Map<String, dynamic> fallbackToolData = {
                'toolName': _getToolNameFromType(item.type),
                'toolTab': _getToolTabFromType(item.type),
                'sourceType': item.type,
                'userInput': item.title,
                'fullPrompt':
                    cleanContentForFallback, // Usa o content limpo como prompt
              };

              if (item.type == 'youtube') {
                fallbackToolData['hasTranscript'] = true;
                fallbackToolData['transcript'] = item.response;
              }

              final String fallbackJsonData = json.encode(fallbackToolData);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AITutorScreen(
                    initialPrompt: fallbackJsonData,
                  ),
                ),
              );
            }
          }
        },
        onLongPress: () {
          // Mostrar menu de opções ao fazer um clique longo (para histórico e favoritos)
          _showDeleteConfirmationDialog(item, isHistoryList);
        },
        child: ListTile(
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          leading: Container(
            height: double.infinity,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircleAvatar(
                  backgroundColor: iconColor.withOpacity(0.1),
                  child: Icon(
                    iconData,
                    color: iconColor,
                    size: 22,
                  ),
                ),
              ],
            ),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  item.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 4),
              Text(
                subtitleText,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
          trailing: Container(
            height: double.infinity,
            width: 60,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Hora acima do ícone de favorito
                Text(
                  DateFormat('HH:mm').format(item.timestamp),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant.withOpacity(0.7),
                  ),
                ),
                SizedBox(height: 2),
                // Ícone de favorito com tamanho reduzido
                InkWell(
                  onTap: () {
                    if (isFavorite) {
                      _removeFromFavorites(item.id);
                    } else {
                      _addToFavorites(item);
                    }
                  },
                  child: Icon(
                    isFavorite ? Icons.star : Icons.star_border,
                    color:
                        isFavorite ? colorScheme.primary : colorScheme.outline,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
          isThreeLine: true,
        ),
      ),
    );
  }

  void _showItemDetails(StudyItem item) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Determinar o tipo de ferramenta para exibir o botão correto
    String actionButtonText;
    IconData actionIcon;
    String typeLabel;
    Color typeColor;

    // Limpar conteúdo de todos os marcadores possíveis
    final cleanContent = item.content
        .replaceAll("###USER_MESSAGE###", "")
        .replaceAll("###USer_MESSAGE###", "")
        .replaceAll("###USer_message###", "")
        .replaceAll("###User_Message###", "")
        .replaceAll("###user_message###", "");

    switch (item.type) {
      case 'tutor':
        actionButtonText = 'Continuar conversa';
        actionIcon = Icons.school_outlined;
        typeLabel = 'Tutor IA';
        typeColor = colorScheme.primaryContainer;
        break;
      case 'conversation':
        actionButtonText = 'Continuar conversa';
        actionIcon = Icons.chat_bubble_outline;
        typeLabel = 'Chat IA';
        typeColor = colorScheme.secondaryContainer;
        break;
      case 'summary':
        actionButtonText = 'Abrir resumidor';
        actionIcon = Icons.description_outlined;
        typeLabel = 'Resumo de documento';
        typeColor = colorScheme.tertiary;
        break;
      case 'youtube':
        actionButtonText = 'Abrir YouTube';
        actionIcon = Icons.play_circle_outline;
        typeLabel = 'Resumo de YouTube';
        typeColor = Colors.red;
        break;
      case 'enhancement':
        actionButtonText = 'Abrir melhorador';
        actionIcon = Icons.edit_note_outlined;
        typeLabel = 'Melhoria de texto';
        typeColor = colorScheme.secondary;
        break;
      case 'code':
        actionButtonText = 'Abrir editor de código';
        actionIcon = Icons.code;
        typeLabel = 'Assistente de código';
        typeColor = colorScheme.tertiary;
        break;
      case 'scan':
        actionButtonText = 'Abrir scanner';
        actionIcon = Icons.document_scanner_outlined;
        typeLabel = 'Scanner de documento';
        typeColor = colorScheme.primary;
        break;
      case 'camera':
        actionButtonText = 'Abrir câmera';
        actionIcon = Icons.camera_alt_outlined;
        typeLabel = 'Scanner por câmera';
        typeColor = colorScheme.primary;
        break;
      default:
        actionButtonText = 'Abrir ferramenta';
        actionIcon = Icons.open_in_new;
        typeLabel = 'Outro';
        typeColor = colorScheme.onSurfaceVariant;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          child: Column(
            children: [
              // Handle
              Container(
                margin: EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: colorScheme.onSurfaceVariant.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              // Header
              Padding(
                padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Row(
                  children: [
                    Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: typeColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: typeColor.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            actionIcon,
                            size: 16,
                            color: typeColor,
                          ),
                          SizedBox(width: 6),
                          Text(
                            typeLabel,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: typeColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Spacer(),
                    IconButton(
                      icon: Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    item.title,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              Divider(
                  height: 1,
                  color: colorScheme.outlineVariant.withOpacity(0.5)),
              // Content
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr.translate('question_content'),
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding:
                            EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainer,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: colorScheme.outlineVariant.withOpacity(0.3),
                          ),
                        ),
                        child: SelectableText(
                          cleanContent,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      SizedBox(height: 24),
                      Text(
                        context.tr.translate('response'),
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding:
                            EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainer,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: colorScheme.outlineVariant.withOpacity(0.3),
                          ),
                        ),
                        child: SelectableText(
                          item.response,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),

                      // Botão para abrir a ferramenta correspondente
                      SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          icon: Icon(actionIcon),
                          label: Text(actionButtonText),
                          onPressed: () {
                            // Fechar o modal e navegar para a ferramenta
                            Navigator.pop(context);

                            // Sempre navegar para AITutorScreen
                            if (item.type == 'tutor' ||
                                item.type == 'conversation') {
                              // Para tutor e conversation, usar o ID da conversa
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => AITutorScreen(
                                    conversationId: item.id,
                                  ),
                                ),
                              );
                            } else {
                              // Para outros tipos, verificar se item.content é o JSON da ferramenta
                              String? jsonDataFromHistory = item.content;
                              Map<String, dynamic>? toolDataMap;
                              bool isToolJsonValid = false;

                              if (jsonDataFromHistory.startsWith('{') &&
                                  jsonDataFromHistory.endsWith('}')) {
                                try {
                                  toolDataMap =
                                      json.decode(jsonDataFromHistory);
                                  // Validação mais flexível para ferramentas:
                                  // 1. Tem toolName OU sourceType
                                  // 2. Tem fullPrompt OU conversationHistory
                                  if (toolDataMap != null &&
                                      (toolDataMap.containsKey('toolName') ||
                                          toolDataMap
                                              .containsKey('sourceType')) &&
                                      (toolDataMap.containsKey('fullPrompt') ||
                                          toolDataMap.containsKey(
                                              'conversationHistory'))) {
                                    isToolJsonValid = true;
                                    print(
                                        'HistoryScreen Details: JSON de ferramenta válido detectado');
                                  }
                                } catch (e) {
                                  print(
                                      "HistoryScreen Details: Erro ao decodificar item.content como JSON: $e");
                                }
                              }

                              if (isToolJsonValid) {
                                // Adicionar logs para depurar o toolDataMap
                                print(
                                    '🔍 HistoryScreen: Analisando toolDataMap: ${toolDataMap?.keys}');

                                // MODIFICADO: Extrair conversationId do toolDataMap
                                String? conversationIdFromToolData;
                                if (toolDataMap != null &&
                                    toolDataMap.containsKey('conversationId') &&
                                    toolDataMap['conversationId'] != null &&
                                    toolDataMap['conversationId']
                                        .toString()
                                        .isNotEmpty) {
                                  conversationIdFromToolData =
                                      toolDataMap['conversationId'].toString();
                                  print(
                                      '📱 HistoryScreen: Encontrado conversationId no toolData: $conversationIdFromToolData');
                                }

                                // Verificar se existe histórico de conversa no toolData
                                bool hasConversationHistory = toolDataMap !=
                                        null &&
                                    toolDataMap
                                        .containsKey('conversationHistory') &&
                                    toolDataMap['conversationHistory'] != null;

                                if (hasConversationHistory) {
                                  print(
                                      '📝 HistoryScreen: Encontrado conversationHistory no toolData');
                                  if (toolDataMap!['conversationHistory']
                                          is Map &&
                                      toolDataMap['conversationHistory']
                                          .containsKey('messages')) {
                                    int numMessages =
                                        (toolDataMap['conversationHistory']
                                                    ['messages'] as List?)
                                                ?.length ??
                                            0;
                                    print(
                                        '📝 HistoryScreen: Número de mensagens no conversationHistory: $numMessages');
                                  }
                                }

                                // Garantir que o toolData está atualizado no jsonDataFromHistory
                                if (hasConversationHistory) {
                                  jsonDataFromHistory =
                                      json.encode(toolDataMap);
                                  print(
                                      '🔄 HistoryScreen: JSON da ferramenta atualizado com conversationHistory');
                                }

                                // CORRIGIDO: Sempre passar o JSON da ferramenta para initialPrompt
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => AITutorScreen(
                                      conversationId:
                                          conversationIdFromToolData, // Usar o conversationId se disponível
                                      initialPrompt:
                                          jsonDataFromHistory, // SEMPRE passar o JSON da ferramenta atualizado
                                      initialToolResponse: item
                                          .response, // Passar a resposta original (pode ser ignorada se conversationId carregar tudo)
                                    ),
                                  ),
                                );
                              } else {
                                // Fallback: Se item.content não for o JSON esperado
                                final cleanContentForFallback = item.content
                                    .replaceAll("###USER_MESSAGE###", "")
                                    .replaceAll("###USer_MESSAGE###", "")
                                    .replaceAll("###USer_message###", "")
                                    .replaceAll("###User_Message###", "")
                                    .replaceAll("###user_message###", "");

                                final Map<String, dynamic> fallbackToolData = {
                                  'toolName': _getToolNameFromType(item.type),
                                  'toolTab': _getToolTabFromType(item.type),
                                  'sourceType': item.type,
                                  'userInput': item.title,
                                  'fullPrompt': cleanContentForFallback,
                                };

                                if (item.type == 'youtube') {
                                  fallbackToolData['hasTranscript'] = true;
                                  fallbackToolData['transcript'] =
                                      item.response;
                                }

                                final String fallbackJsonData =
                                    json.encode(fallbackToolData);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => AITutorScreen(
                                      initialPrompt: fallbackJsonData,
                                    ),
                                  ),
                                );
                              }
                            }
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: typeColor,
                            foregroundColor: typeColor.computeLuminance() > 0.5
                                ? Colors.black
                                : Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(String date) {
    final DateTime parsedDate = DateFormat('dd/MM/yyyy').parse(date);
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime yesterday = today.subtract(Duration(days: 1));

    if (parsedDate == today) {
      return context.tr.translate('today');
    } else if (parsedDate == yesterday) {
      return context.tr.translate('yesterday');
    } else {
      return date;
    }
  }

  // Método auxiliar para obter o nome da ferramenta
  String _getToolNameFromType(String type) {
    switch (type) {
      case 'summary':
        return 'Document Summary';
      case 'youtube':
        return 'YouTube Summary';
      case 'enhancement':
        return 'Text Enhancement';
      case 'code':
        return 'Code Assistant';
      case 'scan':
        return 'Document Scan';
      case 'camera':
        return 'Camera Scan';
      default:
        return 'Tool';
    }
  }

  // Método auxiliar para obter a aba da ferramenta
  String _getToolTabFromType(String type) {
    switch (type) {
      case 'summary':
        return 'Resumo';
      case 'youtube':
        return 'Análise de Vídeo';
      case 'enhancement':
        return 'Melhoria de Texto';
      case 'code':
        return 'Código';
      case 'scan':
        return 'Digitalização';
      case 'camera':
        return 'Câmera';
      default:
        return '';
    }
  }
}
