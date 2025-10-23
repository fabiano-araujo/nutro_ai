import 'package:flutter/material.dart';
import '../models/essay_progress_model.dart';
import 'achievement_widgets.dart';

/// Widget para exibir notificações de conquistas desbloqueadas
class AchievementNotificationManager extends StatefulWidget {
  final Widget child;

  const AchievementNotificationManager({
    Key? key,
    required this.child,
  }) : super(key: key);

  @override
  State<AchievementNotificationManager> createState() => _AchievementNotificationManagerState();

  /// Método estático para mostrar notificação de conquista
  static void showAchievementUnlocked(BuildContext context, Achievement achievement) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AchievementUnlockedDialog(
        achievement: achievement,
        onDismiss: () {
          // Opcional: adicionar lógica adicional quando a conquista é dispensada
        },
      ),
    );
  }

  /// Método estático para mostrar múltiplas conquistas
  static void showMultipleAchievements(BuildContext context, List<Achievement> achievements) {
    if (achievements.isEmpty) return;

    // Mostrar uma por vez com delay
    _showAchievementsSequentially(context, achievements, 0);
  }

  static void _showAchievementsSequentially(BuildContext context, List<Achievement> achievements, int index) {
    if (index >= achievements.length) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AchievementUnlockedDialog(
        achievement: achievements[index],
        onDismiss: () {
          // Mostrar próxima conquista após um pequeno delay
          if (index + 1 < achievements.length) {
            Future.delayed(const Duration(milliseconds: 500), () {
              _showAchievementsSequentially(context, achievements, index + 1);
            });
          }
        },
      ),
    );
  }
}

class _AchievementNotificationManagerState extends State<AchievementNotificationManager> {
  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

/// Widget para exibir toast de conquista (alternativa mais sutil)
class AchievementToast extends StatelessWidget {
  final Achievement achievement;
  final VoidCallback? onTap;

  const AchievementToast({
    Key? key,
    required this.achievement,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        margin: const EdgeInsets.all(16.0),
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.emoji_events,
                  color: Colors.amber,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Conquista Desbloqueada!',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.amber,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      achievement.name,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: Colors.grey[400],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Método estático para mostrar toast
  static void show(BuildContext context, Achievement achievement) {
    final overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 16,
        left: 0,
        right: 0,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, -1),
            end: Offset.zero,
          ).animate(
            CurvedAnimation(
              parent: AnimationController(
                duration: const Duration(milliseconds: 300),
                vsync: Scaffold.of(context),
              )..forward(),
              curve: Curves.easeOut,
            ),
          ),
          child: AchievementToast(
            achievement: achievement,
            onTap: () {
              overlayEntry.remove();
              // Opcional: navegar para tela de conquistas
            },
          ),
        ),
      ),
    );

    overlay.insert(overlayEntry);

    // Remover automaticamente após 4 segundos
    Future.delayed(const Duration(seconds: 4), () {
      if (overlayEntry.mounted) {
        overlayEntry.remove();
      }
    });
  }
}

/// Mixin para facilitar o uso de notificações de conquista
mixin AchievementNotificationMixin<T extends StatefulWidget> on State<T> {
  void showAchievementUnlocked(Achievement achievement) {
    AchievementNotificationManager.showAchievementUnlocked(context, achievement);
  }

  void showAchievementToast(Achievement achievement) {
    AchievementToast.show(context, achievement);
  }

  void showMultipleAchievements(List<Achievement> achievements) {
    AchievementNotificationManager.showMultipleAchievements(context, achievements);
  }
}