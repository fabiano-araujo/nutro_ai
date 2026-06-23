import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../services/ad_manager.dart';
import '../services/auth_service.dart';
import '../providers/credit_provider.dart';
import 'package:nutro_ai/i18n/app_localizations_extension.dart';

class RewardAdDialog {
  static void show(BuildContext context, {VoidCallback? onRewardEarned}) {
    final parentContext = context;
    const rewardAccentColor = Color(0xFFF6A11A);

    showDialog(
      context: parentContext,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24.0),
          ),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 22),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.22),
                  blurRadius: 28,
                  offset: const Offset(0, 14),
                ),
              ],
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFF0524D),
                  Color(0xFFF7A82E),
                ],
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 86,
                  height: 86,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.stars_rounded,
                        size: 34,
                        color: Color(0xFFE65A51),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  context.tr.translate('earn_free_credits'),
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 14),
                Text(
                  context.tr.translate('watch_ad_earn'),
                  style: TextStyle(
                    fontSize: 17,
                    height: 1.45,
                    color: Colors.white.withValues(alpha: 0.92),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        showRewardedAd(
                          parentContext,
                          onRewardEarned: onRewardEarned,
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: rewardAccentColor,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.play_arrow, size: 18),
                          const SizedBox(width: 5),
                          Text(
                            context.tr.translate('watch_now'),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white.withValues(alpha: 0.8),
                      ),
                      child: Text(
                        context.tr.translate('cancel'),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        Navigator.of(parentContext).pushNamed('/subscription');
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 4),
                      ),
                      child: Text(
                        context.tr.translate('subscribe_premium'),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          decoration: TextDecoration.underline,
                          decorationColor: Colors.white,
                        ),
                      ),
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
  static Future<void> showRewardedAd(
    BuildContext context, {
    int retryAttempt = 0,
    VoidCallback? onRewardEarned,
    bool grantCredits = true,
  }) async {
    final CreditProvider? creditProvider = grantCredits
        ? Provider.of<CreditProvider>(context, listen: false)
        : null;
    final AuthService? authService =
        grantCredits ? Provider.of<AuthService>(context, listen: false) : null;
    final token =
        grantCredits && authService != null && authService.isAuthenticated
            ? authService.token
            : null;
    final maxRetryAttempt = 3;

    if (kIsWeb) {
      await _grantRewardedCreditsForWeb(context, creditProvider, token,
          onRewardEarned: onRewardEarned, grantCredits: grantCredits);
      return;
    }

    // Mostrar indicador de carregamento
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr.translate('loading_ad')),
          duration: Duration(seconds: 1),
        ),
      );
    }

    try {
      bool rewardProcessed = false;
      bool rewardProcessing = false;

      Future<void> processReward() async {
        if (rewardProcessed || rewardProcessing) {
          debugPrint(
              'Recompensa já foi processada anteriormente, ignorando...');
          return;
        }

        rewardProcessing = true;

        try {
          if (grantCredits) {
            await creditProvider!.addRewardedCredits(7, token: token);
          }
          rewardProcessed = true;
          onRewardEarned?.call();

          if (grantCredits && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(context.tr.translate('earned_credits')),
                backgroundColor: Colors.green,
              ),
            );
          }
        } catch (e) {
          debugPrint('Erro ao processar recompensa do anúncio premiado: $e');
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(context.tr.translate(grantCredits
                    ? 'reward_credit_sync_error'
                    : 'ad_load_error')),
                backgroundColor: Colors.red,
              ),
            );
          }
        } finally {
          rewardProcessing = false;
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
                showRewardedAd(context,
                    retryAttempt: retryAttempt + 1,
                    onRewardEarned: onRewardEarned,
                    grantCredits: grantCredits);
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
              showRewardedAd(context,
                  retryAttempt: retryAttempt + 1,
                  onRewardEarned: onRewardEarned,
                  grantCredits: grantCredits);
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
                          retryAttempt: 0,
                          onRewardEarned: onRewardEarned,
                          grantCredits: grantCredits); // Reiniciar contagem
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

  static Future<void> _grantRewardedCreditsForWeb(
    BuildContext context,
    CreditProvider? creditProvider,
    String? token, {
    VoidCallback? onRewardEarned,
    bool grantCredits = true,
  }) async {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr.translate('loading_ad')),
          duration: Duration(seconds: 1),
        ),
      );
    }

    try {
      if (grantCredits) {
        await creditProvider!.addRewardedCredits(7, token: token);
      }
      onRewardEarned?.call();

      if (grantCredits && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr.translate('earned_credits')),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Erro ao adicionar créditos simulados no web: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr.translate('reward_credit_sync_error')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
