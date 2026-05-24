import 'package:flutter/material.dart';
import 'nutrition_assistant_screen.dart';

/// Tela dedicada à conversa livre, sem bottom navbar.
/// Abre como rota push por cima da MainNavigation.
class FreeChatScreen extends StatelessWidget {
  final String? freeChatId;
  final String? initialPrompt;
  final String? toolType;
  final bool forceNewConversation;

  const FreeChatScreen({
    super.key,
    this.freeChatId,
    this.initialPrompt,
    this.toolType,
    this.forceNewConversation = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: NutritionAssistantScreen(
        isFreeChat: true,
        freeChatId: freeChatId,
        initialPrompt: initialPrompt,
        toolType: toolType,
        forceNewFreeChat: forceNewConversation,
        onOpenDrawer: () => Navigator.of(context).pop(),
      ),
    );
  }
}
