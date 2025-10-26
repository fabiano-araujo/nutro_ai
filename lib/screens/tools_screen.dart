import 'package:flutter/material.dart';
import '../i18n/app_localizations_extension.dart';
import '../screens/camera_scan_screen.dart';
import '../screens/document_summary_screen.dart';
import '../screens/text_enhancement_screen.dart';
import '../screens/youtube_summary_screen.dart';
import '../screens/code_enhancer_screen.dart';
import '../screens/generic_ai_screen.dart';
import '../screens/essay_history_screen.dart';
import '../screens/nutrition_search_screen.dart';
import '../screens/tools/language_tool_config.dart';
import '../screens/tools/content_generator_tool_config.dart';
import '../screens/tools/summarizer_tool_config.dart';
import '../screens/tools/code_enhancer_tool_config.dart';
import '../screens/tools/essay_helper_tool_config.dart';
import '../screens/tools/learning_assistant_tool_config.dart';
import '../widgets/native_ad_widget.dart';
import '../widgets/reward_ad_dialog.dart';
import 'settings_screen.dart';
import '../widgets/credit_indicator.dart';
import 'main_navigation.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../providers/credit_provider.dart';
import '../services/ad_manager.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../widgets/meal_card.dart';
import '../models/food_model.dart';
import '../models/meal_model.dart';
import '../models/Nutrient.dart';

class ToolsScreen extends StatefulWidget {
  const ToolsScreen({Key? key}) : super(key: key);

  @override
  _ToolsScreenState createState() => _ToolsScreenState();
}

class _ToolsScreenState extends State<ToolsScreen> {
  late Meal _exampleMeal;

  @override
  void initState() {
    super.initState();
    _initializeExampleMeal();
  }

  void _initializeExampleMeal() {
    final foods = <Food>[
      Food(
        name: 'Egg',
        amount: '1 large',
        emoji: '🥚',
        photo: 'https://images.unsplash.com/photo-1587486913049-53fc88980cfc?w=200&h=200&fit=crop',
        brand: 'Organic Farm',
        nutrients: [
          Nutrient(
            idFood: 0,
            servingSize: 50,
            servingUnit: 'g',
            calories: 78,
            protein: 6.3,
            carbohydrate: 0.6,
            fat: 5.3,
            saturatedFat: 1.6,
            monounsaturatedFat: 2.0,
            polyunsaturatedFat: 0.7,
            transFat: 0,
            cholesterol: 186,
            sodium: 62,
            potassium: 69,
            dietaryFiber: 0,
            sugars: 0.6,
            vitaminA: 80,
            vitaminD: 1.1,
            vitaminB6: 0.1,
            vitaminB12: 0.6,
            calcium: 28,
            iron: 0.9,
          ),
        ],
      ),
      Food(
        name: 'Couscous',
        amount: '100g',
        emoji: '🍚',
        photo: 'https://images.unsplash.com/photo-1596040033229-a0b0d1f6e2e3?w=200&h=200&fit=crop',
        brand: 'Mediterranean',
        nutrients: [
          Nutrient(
            idFood: 0,
            servingSize: 100,
            servingUnit: 'g',
            calories: 376,
            protein: 13,
            carbohydrate: 77,
            fat: 1,
            saturatedFat: 0.1,
            monounsaturatedFat: 0.2,
            polyunsaturatedFat: 0.4,
            sodium: 10,
            potassium: 166,
            dietaryFiber: 5,
            sugars: 2,
            calcium: 24,
            iron: 1.1,
            vitaminB6: 0.2,
          ),
        ],
      ),
      Food(
        name: 'Milk',
        amount: '200ml',
        emoji: '🥛',
        photo: 'https://images.unsplash.com/photo-1550583724-b2692b85b150?w=200&h=200&fit=crop',
        brand: 'Dairy Fresh',
        nutrients: [
          Nutrient(
            idFood: 0,
            servingSize: 200,
            servingUnit: 'ml',
            calories: 91,
            protein: 6,
            carbohydrate: 9,
            fat: 3,
            saturatedFat: 1.9,
            monounsaturatedFat: 0.8,
            polyunsaturatedFat: 0.1,
            cholesterol: 12,
            sodium: 95,
            potassium: 280,
            sugars: 9,
            addedSugars: 0,
            calcium: 220,
            iron: 0.1,
            vitaminA: 100,
            vitaminD: 2.5,
            vitaminB6: 0.2,
            vitaminB12: 0.9,
          ),
        ],
      ),
    ];

    _exampleMeal = Meal(
      id: '1',
      type: MealType.breakfast,
      foods: foods,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Builder(
          builder: (context) {
            final authService = Provider.of<AuthService>(context);
            final user = authService.currentUser;
            if (user != null && user.name.isNotEmpty) {
              return Text(context.tr
                      .translate('hello_user')
                      ?.replaceAll('{name}', user.name) ??
                  'Oi, ${user.name}');
            } else {
              return Text(context.tr.translate('hello') ?? 'Oi');
            }
          },
        ),
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Consumer<CreditProvider>(
              builder: (context, creditProvider, child) {
                return CreditIndicator();
              },
            ),
          ),
          IconButton(
            icon: const Icon(Icons.card_giftcard),
            tooltip: 'Assistir anúncio para ganhar créditos',
            onPressed: () {
              _showRewardDialog(context);
            },
          ),
          IconButton(
            icon: const Icon(Icons.restaurant_menu),
            tooltip: 'Pesquisa Nutricional',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NutritionSearchScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Processor card at the top
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: isDarkMode ? Color(0xFF2A2A2A) : Color(0xFFF0F0F0),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(30),
                              child: Image.asset(
                                'assets/images/logo.png',
                                width: 60,
                                height: 60,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    width: 60,
                                    height: 60,
                                    color: Colors.grey,
                                    child: Icon(Icons.school,
                                        size: 40, color: Colors.white),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    context.tr.translate(
                                            'welcome_message_card') ??
                                        'Olá! Sou Nutro AI, seu assistente de nutrição',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: isDarkMode
                                          ? Colors.white
                                          : Colors.black,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    context.tr
                                            .translate('welcome_description') ??
                                        'Assistente inteligente para potencializar seu aprendizado 📚👩‍🎓',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: isDarkMode
                                          ? Colors.white70
                                          : Colors.black54,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              // Mudar para a terceira aba (chat)
                              navigationController.changeTab(
                                  2); // índice da terceira aba (chat)
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context).primaryColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.chat_bubble_outline, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  context.tr.translate('start_conversation') ??
                                      'Iniciar conversa',
                                  style: const TextStyle(fontSize: 16),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Meal Card
                MealCard(
                  meal: _exampleMeal,
                  onEditFood: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Edit food - feature coming soon'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  onMealTypeChanged: (MealType newType) {
                    setState(() {
                      _exampleMeal = _exampleMeal.copyWith(type: newType);
                    });
                  },
                ),

                const SizedBox(height: 24),

                // Título da seção "Ferramentas de IA"
                Text(
                  context.tr.translate('ai_tools') ?? 'Ferramentas de IA',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                ),

                const SizedBox(height: 16),

                // Grade de ferramentas de IA (incluindo Resumo do YouTube)
                LayoutBuilder(
                  builder: (context, constraints) {
                    return Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _buildIAToolCard(
                                context.tr.translate('youtube_summary_short') ??
                                    'Resumo do YouTube',
                                context.tr.translate(
                                        'youtube_summary_short_description') ??
                                    'Obtenha resumos detalhados de vídeos',
                                Icons.play_circle_fill,
                                const Color(0xFFE57575),
                                () => _navigateToTool('youtube_summary'),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildIAToolCard(
                                context.tr.translate(
                                        'learning_assistant_short') ??
                                    'Assistente de aprendizagem',
                                context.tr.translate(
                                        'learning_assistant_short_description') ??
                                    'Perguntar, explicar, criar quiz',
                                Icons.question_mark,
                                const Color(0xFF8C65D3),
                                () => _navigateToTool('ai_tutor'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _buildIAToolCard(
                                context.tr
                                        .translate('content_generator_short') ??
                                    'Gerador de conteúdo',
                                context.tr.translate(
                                        'content_generator_short_description') ??
                                    'Escrever ensaio, poema, blog',
                                Icons.edit,
                                const Color(0xFFD39F65),
                                () => _navigateToTool('content_generator'),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildIAToolCard(
                                context.tr.translate('language_tool') ??
                                    'Idioma',
                                context.tr.translate(
                                        'language_tool_description') ??
                                    'Traduzir, verificar gramática',
                                Icons.description,
                                const Color(0xFF7BC58C),
                                () => _navigateToTool('language'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Anúncio nativo
                        const NativeAdWidget(),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _buildIAToolCard(
                                context.tr.translate('essay_helper_short') ??
                                    'Ajudante de ensaios',
                                context.tr.translate(
                                        'essay_helper_short_description') ??
                                    'Melhorar, parafrasear',
                                Icons.text_snippet,
                                const Color(0xFFD268BE),
                                () => _navigateToTool('text_enhancement'),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildIAToolCard(
                                context.tr.translate('summarizer_short') ??
                                    'Resumidor',
                                context.tr.translate(
                                        'summarizer_short_description') ??
                                    'Texto, livro, obter palavras-chave',
                                Icons.menu_book,
                                const Color(0xFF5B9BD5),
                                () => _navigateToTool('document_summary'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _buildIAToolCard(
                                context.tr.translate('code_enhancer_short') ??
                                    'Aprimorador de código',
                                context.tr.translate(
                                        'code_enhancer_short_description') ??
                                    'Analisar, verificar, otimizar',
                                Icons.code,
                                const Color(0xFF8C8C8C),
                                () => _navigateToTool('code_enhancer'),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Container(),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Card para as ferramentas principais no topo
  Widget _buildMainToolCard(
    String title,
    String description,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    // Ajuste de opacidade condicional dependendo do modo
    final cardOpacity = isDarkMode ? 0.2 : 0.15;
    final borderOpacity = isDarkMode ? 0.3 : 0.2;
    final shadowOpacity = isDarkMode ? 0.1 : 0.05;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 170,
        decoration: BoxDecoration(
          color: color.withOpacity(cardOpacity),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(borderOpacity), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(shadowOpacity),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                icon,
                color: color,
                size: 40,
              ),
              const Spacer(),
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  fontSize: 12,
                  color: isDarkMode ? Colors.grey[400] : Colors.grey[700],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Card para as ferramentas de IA na grade
  Widget _buildIAToolCard(
    String title,
    String description,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    // Ajuste de opacidade condicional dependendo do modo
    final cardOpacity = isDarkMode ? 0.2 : 0.15;
    final borderOpacity = isDarkMode ? 0.3 : 0.2;
    // Detectar tamanho da tela para layout responsivo
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallDevice = screenWidth < 360;

    // Altura adaptativa baseada no tamanho da tela
    final cardHeight = isSmallDevice ? 130.0 : 150.0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: cardHeight,
        decoration: BoxDecoration(
          color: isDarkMode ? Color(0xFF2A2A2A) : Color(0xFFF0F0F0),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(borderOpacity), width: 1),
        ),
        child: Padding(
          padding: EdgeInsets.all(isSmallDevice ? 12.0 : 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: isSmallDevice ? 14 : 16,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              Row(
                children: [
                  Icon(
                    icon,
                    color: color,
                    size: isSmallDevice ? 16 : 18,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      description,
                      style: TextStyle(
                        fontSize: isSmallDevice ? 11 : 12,
                        color: isDarkMode ? Colors.grey[400] : Colors.grey[700],
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
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

  void _navigateToTool(String toolName) {
    switch (toolName) {
      case 'ai_tutor':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => GenericAIScreen(
              config: LearningAssistantToolConfig.getConfig(),
            ),
          ),
        );
        break;
      case 'camera_scan':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => CameraScanScreen()),
        );
        break;
      case 'document_summary':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => GenericAIScreen(
              config: SummarizerToolConfig.getConfig(),
            ),
          ),
        );
        break;
      case 'text_enhancement':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => GenericAIScreen(
              config: EssayHelperToolConfig.getConfig(),
            ),
          ),
        );
        break;
      case 'youtube_summary':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => YoutubeSummaryScreen(),
          ),
        );
        break;
      case 'code_enhancer':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => GenericAIScreen(
              config: CodeEnhancerToolConfig.getConfig(),
            ),
          ),
        );
        break;
      case 'content_generator':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => GenericAIScreen(
              config: ContentGeneratorToolConfig.getConfig(),
            ),
          ),
        );
        break;
      case 'language':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => GenericAIScreen(
              config: LanguageToolConfig.getConfig(),
            ),
          ),
        );
        break;
      case 'essay_correction':
        Navigator.of(context).pushNamed('/essay_history');
        break;
      default:
        _showComingSoonMessage();
        break;
    }
  }

  void _showComingSoonMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.tr.translate('coming_soon'))),
    );
  }

  void _showRewardDialog(BuildContext context) {
    // Na web, apenas mostre mensagem
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Esta funcionalidade não está disponível na versão web.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    RewardAdDialog.show(context);
  }

  void _showWatchAdDialog(BuildContext context) {
    // Na web, apenas mostre mensagem
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Esta funcionalidade não está disponível na versão web.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.0),
          ),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.redAccent.withOpacity(0.8),
                  Colors.orangeAccent.withOpacity(0.9),
                ],
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Ícone de alerta
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.stars,
                    size: 50,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),

                // Título
                Text(
                  'Seus créditos acabaram!',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),

                // Descrição
                Text(
                  'Assista a um anúncio curto e ganhe 7 créditos grátis para continuar usando o aplicativo.',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withOpacity(0.9),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),

                // Botões
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        RewardAdDialog.showRewardedAd(context, retryAttempt: 0);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.orange,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.play_arrow, size: 18),
                          SizedBox(width: 4),
                          Text(
                            'Ganhar créditos',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white.withOpacity(0.8),
                      ),
                      child: Text('Não, obrigado'),
                    ),
                  ],
                ),

                // Opção Premium
                Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).pushNamed('/subscription');
                    },
                    child: Text(
                      'Ou assine o plano Premium',
                      style: TextStyle(
                        color: Colors.white,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showRewardedAd(BuildContext context,
      {int retryAttempt = 0}) async {
    // Na web, este método não será executado diretamente
    // O RewardAdDialog já verifica por kIsWeb internamente
    RewardAdDialog.showRewardedAd(context, retryAttempt: retryAttempt);
  }
}
