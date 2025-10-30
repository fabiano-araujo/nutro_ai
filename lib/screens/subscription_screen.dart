import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:nutro_ai/models/subscription_plan.dart';
import 'package:nutro_ai/services/purchase_service.dart';
import 'package:nutro_ai/theme/app_theme.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:nutro_ai/i18n/app_localizations_extension.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({Key? key}) : super(key: key);

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<SubscriptionPlan> _plans = SubscriptionPlan.getPlans();
  int _selectedPlanIndex =
      1; // Padrão para o plano mensal que geralmente é o mais popular
  bool _isLoading = false;
  bool _hasError = false;
  String _errorMessage = "";
  late PageController _pageController;

  // Lista de benefícios comuns a todos os planos
  late List<String> _commonBenefits;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
        length: _plans.length, vsync: this, initialIndex: _selectedPlanIndex);
    _tabController.addListener(() {
      setState(() {
        _selectedPlanIndex = _tabController.index;
      });
    });
    _pageController = PageController(
      initialPage: _selectedPlanIndex,
      viewportFraction: 0.5,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Verifica se há planos disponíveis
    if (_plans.isEmpty) {
      setState(() {
        _hasError = true;
        _errorMessage = context.tr.translate('error_loading_plans');
      });
    }

    // Inicializa a lista de benefícios comuns com as chaves de tradução
    _commonBenefits = [
      context.tr.translate('no_ads') ?? 'Sem anúncios',
      context.tr.translate('all_premium_features') ??
          'Acesso a todos os recursos premium',
      context.tr.translate('advanced_content_generation') ??
          'Geração de conteúdo avançado',
      context.tr.translate('multiple_languages') ??
          'Suporte a múltiplos idiomas',
      context.tr.translate('export_formats') ?? 'Exportação em vários formatos'
    ];

    // Verifica se os produtos estão disponíveis no PurchaseService
    final purchaseService =
        Provider.of<PurchaseService>(context, listen: false);
    if (!purchaseService.isLoading && purchaseService.products.isEmpty) {
      setState(() {
        _hasError = true;
        // Tratar o caso específico de não encontrar planos
        if (purchaseService.errorMessage
                ?.contains('Não foi possível encontrar os planos') ??
            false) {
          _errorMessage = context.tr.translate('error_loading_plans');
        } else {
          _errorMessage = purchaseService.errorMessage ??
              context.tr.translate('error_loading_plans');
        }
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final purchaseService = Provider.of<PurchaseService>(context);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);

    // Mostra a tela de erro se _hasError for true
    if (_hasError) {
      return _buildErrorScreen(context, isDarkMode, theme);
    }

    // Se não carregou produtos da loja, mostra erro
    if (!purchaseService.isLoading && purchaseService.products.isEmpty) {
      return _buildErrorScreen(context, isDarkMode, theme);
    }

    return Scaffold(
      body: Stack(
        children: [
          // Fundo gradiente adaptado ao tema
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDarkMode
                    ? [
                        AppTheme.darkCardColor,
                        AppTheme.darkBackgroundColor,
                      ]
                    : [
                        Color(0xFFF0F8FF), // Alice Blue - cor clara e suave
                        Color(0xFFE6F0F8), // Azul muito claro
                      ],
              ),
            ),
          ),

          // Efeito de partículas / bolhas
          Positioned.fill(
            child: CustomPaint(
              painter: BubblePainter(isDarkMode: isDarkMode),
            ),
          ),

          // Efeito de blur para o conteúdo principal
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                color:
                    (isDarkMode ? Colors.black : Colors.white).withOpacity(0.1),
              ),
            ),
          ),

          // Conteúdo principal com ScrollView
          SafeArea(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 10),

                  // Título e subtítulo
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            IconButton(
                              icon: Icon(Icons.arrow_back,
                                  color: isDarkMode
                                      ? Colors.white
                                      : Colors.black87),
                              onPressed: () => Navigator.pop(context),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              context.tr.translate('premium_plans'),
                              style: theme.textTheme.titleLarge?.copyWith(
                                color:
                                    isDarkMode ? Colors.white : Colors.black87,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Padding(
                            padding: EdgeInsets.symmetric(horizontal: 10),
                            child: Text(
                              context.tr.translate('unlock_potential'),
                              style: TextStyle(
                                fontSize: 16,
                                color: isDarkMode
                                    ? AppTheme.darkTextColor
                                    : AppTheme.textSecondaryColor,
                              ),
                            )),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),

                  // Cards de planos com visualização parcial do anterior/próximo
                  SizedBox(
                    height:
                        280, // Aumentado para dar mais espaço ao conteúdo do card
                    child: PageView.builder(
                      controller: _pageController,
                      pageSnapping: true,
                      onPageChanged: (index) {
                        setState(() {
                          _selectedPlanIndex = index;
                          _tabController.animateTo(index);
                        });
                      },
                      itemCount: _plans.length,
                      itemBuilder: (context, index) {
                        // Encontre o produto correspondente com segurança
                        ProductDetails? product;
                        try {
                          product = purchaseService.products.firstWhere(
                            (p) => p.id == _plans[index].id,
                          );
                        } catch (e) {
                          product = null;
                        }

                        // Se não encontrou o produto, mostra erro
                        if (product == null) {
                          return Center(
                            child: Text(
                              context.tr.translate('subscription_error'),
                              style: TextStyle(
                                color: isDarkMode ? Colors.white : Colors.black,
                                fontSize: 16,
                              ),
                            ),
                          );
                        }

                        return Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8.0, vertical: 8.0),
                          child: PlanCard(
                            plan: _plans[index],
                            isSelected: index == _selectedPlanIndex,
                            onTap: () {
                              setState(() {
                                _selectedPlanIndex = index;
                                _tabController.animateTo(index);
                              });

                              // Centralizar o item no PageView
                              _pageController.animateToPage(
                                index,
                                duration: Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            },
                            productDetails: product,
                            isDarkMode: isDarkMode,
                          ),
                        );
                      },
                    ),
                  ),

                  // Indicadores de página
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(_plans.length, (index) {
                        final isSelected = index == _selectedPlanIndex;

                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          height: 8,
                          width: isSelected ? 24 : 8,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppTheme.primaryColor
                                : (isDarkMode ? Colors.white : Colors.black)
                                    .withOpacity(0.3),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        );
                      }),
                    ),
                  ),

                  // Card de benefícios comuns
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 16),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDarkMode
                            ? Color(0xFF1E1E2E).withOpacity(0.9)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: AppTheme.primaryColor,
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryColor.withOpacity(0.2),
                            blurRadius: 10,
                            spreadRadius: 0,
                          )
                        ],
                      ),
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.tr.translate('whats_included'),
                            style: TextStyle(
                              color:
                                  isDarkMode ? Colors.white70 : Colors.black54,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ..._commonBenefits.map((benefit) => Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      Icons.check_circle,
                                      color: AppTheme.primaryColor,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        benefit,
                                        style: TextStyle(
                                          color: isDarkMode
                                              ? Colors.white
                                              : Colors.black87,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ))
                        ],
                      ),
                    ),
                  ),

                  // Botão de assinatura
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 16),
                    child: ElevatedButton(
                      onPressed: purchaseService.isLoading || _isLoading
                          ? null
                          : () => _subscribe(context, purchaseService),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 1,
                      ),
                      child: _isLoading
                          ? CircularProgressIndicator(color: Colors.white)
                          : Text(
                              context.tr.translate('subscribe_now'),
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),

                  // Botão de restaurar compras
                  TextButton(
                    onPressed: purchaseService.isLoading || _isLoading
                        ? null
                        : () async {
                            setState(() => _isLoading = true);
                            try {
                              await purchaseService.restorePurchases();
                            } catch (e) {
                              setState(() {
                                _hasError = true;
                                _errorMessage =
                                    context.tr.translate('subscription_error');
                              });
                            } finally {
                              setState(() => _isLoading = false);
                            }
                          },
                    child: Text(
                      context.tr.translate('restore_purchases'),
                      style: TextStyle(
                        color: isDarkMode ? Colors.white70 : Colors.black54,
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Texto de termos e políticas
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    child: Text(
                      context.tr.translate('subscription_terms'),
                      style: TextStyle(
                        fontSize: 12,
                        color: isDarkMode ? Colors.white54 : Colors.black38,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Método para construir a tela de erro
  Widget _buildErrorScreen(
      BuildContext context, bool isDarkMode, ThemeData theme) {
    return Scaffold(
      body: Stack(
        children: [
          // Fundo gradiente adaptado ao tema
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDarkMode
                    ? [
                        AppTheme.darkCardColor,
                        AppTheme.darkBackgroundColor,
                      ]
                    : [
                        Color(0xFFF0F8FF), // Alice Blue - cor clara e suave
                        Color(0xFFE6F0F8), // Azul muito claro
                      ],
              ),
            ),
          ),

          // Efeito de partículas / bolhas suavizado
          Positioned.fill(
            child: CustomPaint(
              painter: BubblePainter(isDarkMode: isDarkMode),
            ),
          ),

          // Efeito de blur
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                color:
                    (isDarkMode ? Colors.black : Colors.white).withOpacity(0.1),
              ),
            ),
          ),

          // Conteúdo da tela de erro
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Ícone de erro
                    Icon(
                      Icons.error_outline,
                      size: 80,
                      color: isDarkMode ? Colors.red[300] : Colors.red[600],
                    ),

                    SizedBox(height: 24),

                    // Título do erro
                    Text(
                      context.tr.translate('oops'),
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: isDarkMode ? Colors.white : Colors.black87,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    SizedBox(height: 16),

                    // Mensagem de erro
                    Text(
                      _errorMessage.isNotEmpty
                          ? _errorMessage
                          : context.tr.translate('error_loading_plans'),
                      style: TextStyle(
                        fontSize: 16,
                        color: isDarkMode ? Colors.white70 : Colors.black54,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    SizedBox(height: 32),

                    // Botão para tentar novamente
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _hasError = false;
                          _errorMessage = "";
                        });

                        // Tenta inicializar novamente
                        final purchaseService = Provider.of<PurchaseService>(
                            context,
                            listen: false);
                        if (purchaseService.products.isEmpty &&
                            !purchaseService.isLoading) {
                          // Se ainda não há produtos, mostra o erro novamente
                          Future.delayed(Duration(seconds: 1), () {
                            if (mounted) {
                              setState(() {
                                if (purchaseService.products.isEmpty) {
                                  _hasError = true;
                                  _errorMessage =
                                      purchaseService.errorMessage ??
                                          context.tr
                                              .translate('subscription_error');
                                }
                              });
                            }
                          });
                        }
                      },
                      icon: Icon(Icons.refresh),
                      label: Text(
                        context.tr.translate('try_again_button'),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        padding:
                            EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),

                    SizedBox(height: 16),

                    // Botão de voltar
                    TextButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.arrow_back),
                      label: Text(
                        context.tr.translate('back'),
                        style: TextStyle(
                          fontSize: 16,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor:
                            isDarkMode ? Colors.white70 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _subscribe(
      BuildContext context, PurchaseService purchaseService) async {
    final selectedPlan = _plans[_selectedPlanIndex];

    // Encontrar o produto correspondente ao plano selecionado com segurança
    ProductDetails? product;
    try {
      product = purchaseService.products.firstWhere(
        (p) => p.id == selectedPlan.id,
      );
    } catch (e) {
      // Se o produto não for encontrado, exibe a tela de erro
      setState(() {
        _hasError = true;
        _errorMessage = context.tr.translate('try_again_later');
      });
      return;
    }

    if (product == null) {
      setState(() {
        _hasError = true;
        _errorMessage = context.tr.translate('try_again_later');
      });
      return;
    }

    setState(() => _isLoading = true);

    try {
      await purchaseService.buySubscription(product);
      // Verificamos a mensagem de erro após a chamada para exibição
      if (purchaseService.errorMessage != null) {
        setState(() {
          _hasError = true;
          _errorMessage = purchaseService.errorMessage!;
        });
      }
    } catch (e) {
      setState(() {
        _hasError = true;
        _errorMessage = "${context.tr.translate('subscription_error')}: $e";
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }
}

class PlanCard extends StatelessWidget {
  final SubscriptionPlan plan;
  final bool isSelected;
  final VoidCallback onTap;
  final ProductDetails? productDetails;
  final bool isDarkMode;

  const PlanCard({
    Key? key,
    required this.plan,
    required this.isSelected,
    required this.onTap,
    required this.isDarkMode,
    this.productDetails,
  }) : super(key: key);

  // Método para suavizar a cor do plano
  Color _getSofterColor(Color color) {
    // Criando uma versão mais suave da cor
    return Color.fromRGBO(
      color.red,
      color.green,
      color.blue,
      0.25, // Reduzindo a opacidade para suavizar
    );
  }

  @override
  Widget build(BuildContext context) {
    final actualPrice = productDetails?.price ?? plan.price;
    final softerColor = _getSofterColor(plan.color);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isDarkMode
              ? Color(0xFF23233A)
              : Color(0xFFF6F7FB), // cor suave fixa para o fundo
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isDarkMode
                ? Color(0xFF444466)
                : Color(0xFFCED6E0), // cinza escuro suave
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              spreadRadius: 0,
            )
          ],
        ),
        child: Column(
          children: [
            // Badge "Mais Popular"
            if (plan.isMostPopular)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: softerColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(22),
                    topRight: Radius.circular(22),
                  ),
                  border: Border(
                    bottom: BorderSide(
                      color: plan.color.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                ),
                child: Text(
                  context.tr.translate('popular'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: plan.color,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Ícone e título
                    Row(
                      children: [
                        Icon(
                          plan.icon,
                          color: plan.color,
                          size: 28,
                        ),
                        const SizedBox(height: 2),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                plan.title,
                                style: TextStyle(
                                  color: isDarkMode
                                      ? Colors.white
                                      : Colors.black87,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 2,
                              ),
                              Text(
                                plan.description,
                                style: TextStyle(
                                  color: isDarkMode
                                      ? Colors.white.withOpacity(0.7)
                                      : Colors.black54,
                                  fontSize: 13,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 4,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const Spacer(),

                    // Preço
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          actualPrice,
                          style: TextStyle(
                            color: isDarkMode ? Colors.white : Colors.black87,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            height: 1,
                          ),
                        ),
                      ],
                    ),

                    // Novo: período abaixo do preço
                    Padding(
                      padding: const EdgeInsets.only(top: 2.0, left: 2.0),
                      child: Text(
                        plan.period.toLowerCase(),
                        style: TextStyle(
                          color: isDarkMode
                              ? Colors.white.withOpacity(0.7)
                              : Colors.black54,
                          fontSize: 16,
                        ),
                      ),
                    ),

                    // Economia
                    if (plan.savePercentage > 0)
                      Container(
                        margin: const EdgeInsets.only(top: 6),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: softerColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          context.tr.translate('save_percentage').replaceAll(
                              '{percentage}', plan.savePercentage.toString()),
                          style: TextStyle(
                            color: plan.color,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
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
    );
  }
}

class BubblePainter extends CustomPainter {
  final bool isDarkMode;

  BubblePainter({required this.isDarkMode});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = (isDarkMode ? Colors.white : Colors.black).withOpacity(0.1)
      ..style = PaintingStyle.fill;

    // Desenhar bolhas decorativas
    canvas.drawCircle(Offset(size.width * 0.1, size.height * 0.1), 50, paint);
    canvas.drawCircle(Offset(size.width * 0.8, size.height * 0.2), 70, paint);
    canvas.drawCircle(Offset(size.width * 0.3, size.height * 0.5), 90, paint);
    canvas.drawCircle(Offset(size.width * 0.7, size.height * 0.7), 60, paint);
    canvas.drawCircle(Offset(size.width * 0.1, size.height * 0.9), 80, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
