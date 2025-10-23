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
        description: 'Ideal para experimentar os recursos premium',
        period: 'Semanal',
        price: 'R\$ 9,90',
        color: Colors.blue,
        icon: Icons.rocket_launch,
        features: [
          'Sem anúncios',
          '100 mensagens diárias',
          '20 uploads de imagem por dia',
          '10 análises de vídeo do YouTube',
          '5 análises de arquivos por dia',
        ],
        savePercentage: 0,
        isMostPopular: false,
      ),
      SubscriptionPlan(
        id: PurchaseService.planoMensal,
        title: 'Plano Mensal',
        description: 'Nossa opção mais popular',
        period: 'Mensal',
        price: 'R\$ 29,90',
        color: Colors.purple,
        icon: Icons.star,
        features: [
          'Sem anúncios',
          'Mensagens ilimitadas',
          '50 uploads de imagem por dia',
          '30 análises de vídeo do YouTube',
          '15 análises de arquivos por dia',
        ],
        savePercentage: 25,
        isMostPopular: true,
      ),
      SubscriptionPlan(
        id: PurchaseService.planoAnual,
        title: 'Plano Anual',
        description: 'Melhor custo-benefício',
        period: 'Anual',
        price: 'R\$ 249,90',
        color: Colors.amber,
        icon: Icons.diamond,
        features: [
          'Sem anúncios',
          'Mensagens ilimitadas',
          'Uploads de imagem ilimitados',
          'Análises de vídeo do YouTube ilimitadas',
          'Análises de arquivos ilimitadas',
          'Suporte prioritário',
        ],
        savePercentage: 30,
        isMostPopular: false,
      ),
    ];
  }
}
