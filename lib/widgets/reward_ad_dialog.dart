import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../services/ad_manager.dart';
import '../providers/credit_provider.dart';
import 'package:nutro_ai/i18n/app_localizations_extension.dart';

class RewardAdDialog {
  static void show(BuildContext context) {
    // Se estiver na web, apenas mostre mensagem
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr.translate('feature_not_available_web')),
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
                  theme.colorScheme.primary.withOpacity(0.8),
                  theme.colorScheme.secondary.withOpacity(0.9),
                ],
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Ícone animado
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.card_giftcard,
                    size: 50,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),

                // Título
                Text(
                  context.tr.translate('earn_free_credits'),
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
                  context.tr.translate('watch_ad_earn'),
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
                        showRewardedAd(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: theme.colorScheme.primary,
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
                            context.tr.translate('watch_now'),
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
                      child: Text(context.tr.translate('cancel')),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Método para mostrar o anúncio premiado
  static Future<void> showRewardedAd(BuildContext context,
      {int retryAttempt = 0}) async {
    final creditProvider = Provider.of<CreditProvider>(context, listen: false);
    final maxRetryAttempt = 3;

    // Se estiver na web, apenas mostre mensagem
    if (kIsWeb) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr.translate('feature_not_available_web')),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    // Mostrar indicador de carregamento
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.tr.translate('loading_ad')),
        duration: Duration(seconds: 1),
      ),
    );

    try {
      // Variável para verificar se a recompensa já foi processada
      bool rewardProcessed = false;

      // Função para processar a recompensa apenas uma vez
      Future<void> processReward() async {
        // Verificar se a recompensa já foi processada
        if (rewardProcessed) {
          debugPrint(
              'Recompensa já foi processada anteriormente, ignorando...');
          return;
        }

        // Marcar como processada para evitar duplicação
        rewardProcessed = true;

        // Adicionar créditos
        await creditProvider.addRewardedCredits(7);

        // Mostrar mensagem de sucesso
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.tr.translate('earned_credits')),
              backgroundColor: Colors.green,
            ),
          );
        }
      }

      final rewardedAd = await AdManager.loadRewardedAd(
        onUserEarnedReward: (RewardItem reward) async {
          debugPrint(
              'Callback onUserEarnedReward chamado com sucesso: ${reward.amount} ${reward.type}');
          await processReward();
        },
        onAdDismissed: (ad) {
          debugPrint('Anúncio premiado fechado pelo usuário');
        },
        onAdFailedToLoad: (error) {
          debugPrint(
              'Falha ao carregar anúncio premiado: ${error.message}, código: ${error.code}');

          // Tentar novamente automaticamente se não excedeu o limite de tentativas
          if (retryAttempt < maxRetryAttempt - 1 && context.mounted) {
            debugPrint('Tentando carregar o anúncio novamente...');
            Future.delayed(Duration(seconds: 2), () {
              if (context.mounted) {
                showRewardedAd(context, retryAttempt: retryAttempt + 1);
              }
            });
          }
        },
        onAdFailedToShow: (ad, error) {
          debugPrint(
              'Falha ao exibir anúncio premiado: ${error.message}, código: ${error.code}');
        },
      );

      // Verificar se o anúncio foi carregado
      if (rewardedAd != null) {
        debugPrint('Anúncio premiado carregado, tentando exibir...');
        try {
          await rewardedAd.show(
            onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
              debugPrint(
                  'Show - onUserEarnedReward chamado: ${reward.amount} ${reward.type}');
              // Usar o mesmo método para processar a recompensa
              processReward();
            },
          );
          debugPrint('Método show do anúncio premiado executado com sucesso');

          // Verificar após um tempo se a recompensa foi processada, mas com um delay maior
          // para dar tempo aos callbacks normais de funcionarem
          Future.delayed(Duration(seconds: 8), () {
            if (!rewardProcessed && context.mounted) {
              debugPrint(
                  'Nenhum callback de recompensa foi processado após 8 segundos, adicionando créditos manualmente...');
              processReward();
            }
          });

          return; // Anúncio exibido com sucesso, sair do método
        } catch (showError) {
          debugPrint('Erro ao exibir anúncio premiado: $showError');
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                    'Erro ao exibir o anúncio. Tente novamente mais tarde.'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } else {
        // Mostrar erro caso o anúncio não possa ser carregado
        debugPrint('Anúncio premiado retornou null após carregamento');

        // Tentar novamente automaticamente se não excedeu o limite de tentativas
        if (retryAttempt < maxRetryAttempt - 1 && context.mounted) {
          debugPrint('Tentando carregar o anúncio novamente após falha...');
          Future.delayed(Duration(seconds: 2), () {
            if (context.mounted) {
              showRewardedAd(context, retryAttempt: retryAttempt + 1);
            }
          });
          return;
        }

        if (context.mounted) {
          // Mostrar diálogo informando o problema e oferecendo nova tentativa
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: Text(context.tr.translate('ad_failed')),
                content: Text(context.tr.translate('ad_load_error')),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: Text(context.tr.translate('cancel')),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      showRewardedAd(context,
                          retryAttempt: 0); // Reiniciar contagem
                    },
                    child: Text(context.tr.translate('retry')),
                  ),
                ],
              );
            },
          );
        }
      }
    } catch (e) {
      debugPrint('Exceção não tratada ao lidar com anúncio premiado: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro inesperado: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
