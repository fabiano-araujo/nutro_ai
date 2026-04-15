import 'package:flutter/material.dart';
import 'nutrition_assistant_screen.dart';

/// Tela dedicada à conversa livre, sem bottom navbar.
/// Abre como rota push por cima da MainNavigation.
class FreeChatScreen extends StatelessWidget {
  final String? freeChatId;

  const FreeChatScreen({super.key, this.freeChatId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: NutritionAssistantScreen(
        isFreeChat: true,
        freeChatId: freeChatId,
        onOpenDrawer: () => Navigator.of(context).pop(),
      ),
    );
  }
}
