import 'package:flutter/material.dart';
import 'package:nutro_ai/services/purchase_service.dart';

class SubscriptionPlan {
  final String id;
  final String title;
  final String description;
  final String period;
  final String price;
  final Color color;
  final IconData icon;
  final List<String> features;
  final int savePercentage;
  final bool isMostPopular;

  SubscriptionPlan({
    required this.id,
    required this.title,
    required this.description,
    required this.period,
    required this.price,
    required this.color,
    required this.icon,
    required this.features,
    this.savePercentage = 0,
    this.isMostPopular = false,
  });

  static List<SubscriptionPlan> getPlans() {
    return [
      SubscriptionPlan(
        id: PurchaseService.planoSemanal,
        title: 'Plano Semanal',
        description: 'Para testar sua rotina alimentar com IA',
        period: 'Semanal',
        price: 'R\$ 9,90',
        color: const Color(0xFFFF8A65),
        icon: Icons.lunch_dining_rounded,
        features: [
          'Registro de refeicoes e calorias do dia',
          'Sugestoes de alimentos e porcoes no chat',
          'Resumo nutricional para acompanhar sua rotina',
          'Ajuste basico de metas alimentares',
        ],
        savePercentage: 0,
        isMostPopular: false,
      ),
      SubscriptionPlan(
        id: PurchaseService.planoMensal,
        title: 'Plano Mensal',
        description: 'Seu plano completo para evoluir na alimentacao',
        period: 'Mensal',
        price: 'R\$ 29,90',
        color: const Color(0xFFFFB74D),
        icon: Icons.restaurant_menu_rounded,
        features: [
          'Dieta personalizada com IA',
          'Cardapio diario renovado conforme seu objetivo',
          'Registro ilimitado de refeicoes e calorias',
          'Ajuste de macros e metas nutricionais',
          'Resumo semanal com sua evolucao',
        ],
        savePercentage: 25,
        isMostPopular: true,
      ),
      SubscriptionPlan(
        id: PurchaseService.planoAnual,
        title: 'Plano Anual',
        description: 'Acompanhamento completo para manter consistencia',
        period: 'Anual',
        price: 'R\$ 249,90',
        color: const Color(0xFF66BB6A),
        icon: Icons.emoji_events_rounded,
        features: [
          'Dieta personalizada e cardapios diarios ilimitados',
          'Acompanhamento de peso, metas e progresso',
          'Analises completas de calorias e macros',
          'Sugestoes inteligentes para suas refeicoes',
          'Prioridade nos recursos premium do app',
        ],
        savePercentage: 30,
        isMostPopular: false,
      ),
    ];
  }
}
