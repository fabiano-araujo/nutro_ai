import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'ai_tutor_screen.dart';
import 'profile_screen.dart';
import 'login_screen.dart';
import 'diet_type_selection_screen.dart';
import '../services/rate_app_service.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../i18n/app_localizations_extension.dart';
import '../providers/free_chat_provider.dart';

// Controlador global para gerenciar a navegação entre abas
class NavigationController {
  static final NavigationController _instance =
      NavigationController._internal();

  factory NavigationController() {
    return _instance;
  }

  NavigationController._internal();

  Function(int)? tabChangeCallback;

  void changeTab(int index) {
    if (tabChangeCallback != null) {
      tabChangeCallback!(index);
    }
  }
}

final navigationController = NavigationController();

// Wrapper para a tela de perfil que decide qual tela mostrar
class ProfileTabWrapper extends StatelessWidget {
  const ProfileTabWrapper({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthService>(
      builder: (context, authService, child) {
        return authService.isAuthenticated
            ? const ProfileScreen()
            : const LoginScreen();
      },
    );
  }
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({Key? key}) : super(key: key);

  @override
  _MainNavigationState createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Chave para reiniciar o AITutorScreen
  Key _aiTutorKey = UniqueKey();

  // Modo atual: 'diary' para diário (com JSON/calendário), 'free_chat' para conversa livre
  String _currentMode = 'diary';

  // ID da conversa livre atual (null = nova conversa)
  String? _currentFreeChatId;

  @override
  void initState() {
    super.initState();

    // Verificar se deve mostrar o diálogo de avaliação
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Aguardar um pouco para que o app seja carregado completamente
      Future.delayed(Duration(seconds: 2), () {
        RateAppService.promptForRating(context);
      });
    });
  }

  void _openDrawer() {
    _scaffoldKey.currentState?.openDrawer();
  }

  void _navigateToProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ProfileTabWrapper(),
      ),
    );
  }

  void _startNewFreeChat() {
    Navigator.pop(context); // Fechar drawer
    setState(() {
      _currentMode = 'free_chat';
      _currentFreeChatId = null;
      _aiTutorKey = UniqueKey(); // Forçar recriação do widget
    });
  }

  void _switchToDiary() {
    Navigator.pop(context); // Fechar drawer
    setState(() {
      _currentMode = 'diary';
      _currentFreeChatId = null;
      _aiTutorKey = UniqueKey(); // Forçar recriação do widget
    });
  }

  void _switchToMyDiet() {
    Navigator.pop(context); // Fechar drawer
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const DietTypeSelectionScreen(),
      ),
    );
  }

  void _openFreeChat(String chatId, String title) {
    Navigator.pop(context); // Fechar drawer
    setState(() {
      _currentMode = 'free_chat';
      _currentFreeChatId = chatId;
      _aiTutorKey = UniqueKey(); // Forçar recriação do widget
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      key: _scaffoldKey,
      drawer: _buildDrawer(isDarkMode),
      body: AITutorScreen(
        key: _aiTutorKey,
        isFreeChat: _currentMode == 'free_chat',
        freeChatId: _currentFreeChatId,
        onOpenDrawer: _openDrawer,
        onNavigateToProfile: _navigateToProfile,
      ),
    );
  }

  Widget _buildDrawer(bool isDarkMode) {
    return Drawer(
      backgroundColor: isDarkMode ? AppTheme.darkBackgroundColor : Colors.white,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header do Drawer
            Container(
              padding: EdgeInsets.all(20),
              child: Row(
                children: [
                  Icon(
                    Icons.restaurant_menu,
                    color: Theme.of(context).primaryColor,
                    size: 32,
                  ),
                  SizedBox(width: 12),
                  Text(
                    'Nutro IA',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : AppTheme.textPrimaryColor,
                    ),
                  ),
                ],
              ),
            ),

            Divider(height: 1),

            // Nova conversa (primeira opção)
            ListTile(
              leading: Icon(
                Icons.add_comment_outlined,
                color: isDarkMode ? Colors.white70 : AppTheme.textSecondaryColor,
              ),
              title: Text(
                context.tr.translate('new_conversation'),
                style: TextStyle(
                  color: isDarkMode ? Colors.white : AppTheme.textPrimaryColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
              onTap: _startNewFreeChat,
            ),

            // Diário (tela de chat com calendário)
            ListTile(
              leading: Icon(
                Icons.calendar_today,
                color: _currentMode == 'diary'
                    ? Theme.of(context).primaryColor
                    : isDarkMode ? Colors.white70 : AppTheme.textSecondaryColor,
              ),
              title: Text(
                context.tr.translate('diary'),
                style: TextStyle(
                  color: _currentMode == 'diary'
                      ? Theme.of(context).primaryColor
                      : isDarkMode ? Colors.white : AppTheme.textPrimaryColor,
                  fontWeight: _currentMode == 'diary' ? FontWeight.bold : FontWeight.w500,
                ),
              ),
              selected: _currentMode == 'diary',
              selectedTileColor: Theme.of(context).primaryColor.withOpacity(0.1),
              onTap: _switchToDiary,
            ),

            // Minha Dieta (abre tela de seleção de tipo de dieta)
            ListTile(
              leading: Icon(
                Icons.restaurant_menu,
                color: isDarkMode ? Colors.white70 : AppTheme.textSecondaryColor,
              ),
              title: Text(
                context.tr.translate('my_diet'),
                style: TextStyle(
                  color: isDarkMode ? Colors.white : AppTheme.textPrimaryColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
              onTap: _switchToMyDiet,
            ),

            SizedBox(height: 16),

            // Subtítulo Conversas
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                context.tr.translate('conversations'),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDarkMode ? Colors.white54 : AppTheme.textSecondaryColor,
                  letterSpacing: 0.5,
                ),
              ),
            ),

            // Lista de conversas livres
            Expanded(
              child: Consumer<FreeChatProvider>(
                builder: (context, freeChatProvider, child) {
                  final conversations = freeChatProvider.conversations;

                  if (conversations.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Text(
                          context.tr.translate('no_conversations'),
                          style: TextStyle(
                            color: isDarkMode ? Colors.white38 : Colors.grey,
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: conversations.length,
                    itemBuilder: (context, index) {
                      final chat = conversations[index];
                      final isSelected = _currentMode == 'free_chat' &&
                                        _currentFreeChatId == chat.id;

                      return ListTile(
                        leading: Icon(
                          Icons.chat_bubble_outline,
                          size: 20,
                          color: isSelected
                              ? Theme.of(context).primaryColor
                              : isDarkMode ? Colors.white54 : Colors.grey,
                        ),
                        title: Text(
                          chat.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            color: isSelected
                                ? Theme.of(context).primaryColor
                                : isDarkMode ? Colors.white : AppTheme.textPrimaryColor,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                        subtitle: Text(
                          _formatDate(chat.lastUpdated),
                          style: TextStyle(
                            fontSize: 12,
                            color: isDarkMode ? Colors.white38 : Colors.grey,
                          ),
                        ),
                        selected: isSelected,
                        selectedTileColor: Theme.of(context).primaryColor.withOpacity(0.1),
                        onTap: () => _openFreeChat(chat.id, chat.title),
                        trailing: IconButton(
                          icon: Icon(
                            Icons.delete_outline,
                            size: 18,
                            color: isDarkMode ? Colors.white38 : Colors.grey,
                          ),
                          onPressed: () {
                            _showDeleteConfirmation(chat.id, chat.title, freeChatProvider);
                          },
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return context.tr.translate('today');
    } else if (difference.inDays == 1) {
      return context.tr.translate('yesterday');
    } else if (difference.inDays < 7) {
      return '${difference.inDays} ${context.tr.translate('days_ago')}';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  void _showDeleteConfirmation(String chatId, String title, FreeChatProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr.translate('delete_conversation')),
        content: Text(context.tr.translate('delete_conversation_confirm').replaceAll('{title}', title)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.tr.translate('cancel')),
          ),
          TextButton(
            onPressed: () {
              provider.deleteConversation(chatId);
              Navigator.pop(context);

              // Se estava vendo essa conversa, voltar para dieta
              if (_currentFreeChatId == chatId) {
                setState(() {
                  _currentMode = 'diet';
                  _currentFreeChatId = null;
                  _aiTutorKey = UniqueKey();
                });
              }
            },
            child: Text(
              context.tr.translate('delete'),
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}
