class SubscriptionPlan {
  final String type;
  final String name;
  final double price;
  final String description;
  final int durationDays;

  const SubscriptionPlan({
    required this.type,
    required this.name,
    required this.price,
    required this.description,
    required this.durationDays,
  });

  String get formattedPrice => 'R\$ ${price.toStringAsFixed(2)}';

  static List<SubscriptionPlan> get availablePlans => [
        const SubscriptionPlan(
          type: 'semanal',
          name: 'Semanal',
          price: 29.90,
          description: '7 dias de acesso premium',
          durationDays: 7,
        ),
        const SubscriptionPlan(
          type: 'mensal',
          name: 'Mensal',
          price: 99.90,
          description: '30 dias de acesso premium',
          durationDays: 30,
        ),
        const SubscriptionPlan(
          type: 'anual',
          name: 'Anual',
          price: 999.00,
          description: '365 dias de acesso premium',
          durationDays: 365,
        ),
      ];

  static SubscriptionPlan getByType(String? type) {
    if (type == null) {
      return const SubscriptionPlan(
        type: 'free',
        name: 'Gratuito',
        price: 0,
        description: 'Acesso gratuito limitado',
        durationDays: 0,
      );
    }

    return availablePlans.firstWhere(
      (plan) => plan.type == type,
      orElse: () => const SubscriptionPlan(
        type: 'free',
        name: 'Gratuito',
        price: 0,
        description: 'Acesso gratuito limitado',
        durationDays: 0,
      ),
    );
  }
}

class PaymentData {
  final String? subscriptionId;
  final String? paymentId;
  final String status;
  final double value;
  final String planType;
  final DateTime? createdAt;
  final DateTime? expiresAt;
  final int? expiresIn;
  final QrCodeData? qrCode;
  final SubscriptionPlan plan;

  PaymentData({
    this.subscriptionId,
    this.paymentId,
    required this.status,
    required this.value,
    required this.planType,
    this.createdAt,
    this.expiresAt,
    this.expiresIn,
    this.qrCode,
  }) : plan = SubscriptionPlan.getByType(planType);

  factory PaymentData.fromJson(Map<String, dynamic> json) {
    print('[PaymentData] Criando a partir de JSON: ${json.keys.toList()}');

    // Verificar campos importantes
    final String? subscriptionId = json['subscriptionId']?.toString() ??
        json['subscription_id']?.toString();
    final String? paymentId = json['paymentId']?.toString() ??
        json['payment_id']?.toString() ??
        json['id']?.toString();

    // Status pode vir em maiúsculas ou minúsculas
    String status = 'pending';
    if (json['status'] != null) {
      status = json['status'].toString().toLowerCase();
      print(
          '[PaymentData] Status original: ${json['status']}, normalizado: $status');
    }

    // Valor pode vir em diferentes formatos
    double value = 0.0;
    if (json['value'] != null) {
      if (json['value'] is num) {
        value = (json['value'] as num).toDouble();
      } else if (json['value'] is String) {
        try {
          value = double.parse(json['value']);
        } catch (e) {
          print('[PaymentData] Erro ao converter valor: $e');
        }
      }
    }

    // Tipo do plano pode vir com diferentes nomes de campo
    final String planType =
        json['planType']?.toString() ?? json['plan_type']?.toString() ?? 'free';

    // Data de expiração pode vir como expirationDate
    DateTime? expiresAt;
    if (json['expires_at'] != null) {
      try {
        expiresAt = DateTime.parse(json['expires_at']);
      } catch (e) {
        print('[PaymentData] Erro ao converter expires_at: $e');
      }
    } else if (json['expirationDate'] != null) {
      try {
        expiresAt = DateTime.parse(json['expirationDate']);
        print(
            '[PaymentData] Usando expirationDate como expires_at: $expiresAt');
      } catch (e) {
        print('[PaymentData] Erro ao converter expirationDate: $e');
      }
    }

    // Data de criação
    DateTime? createdAt;
    if (json['created_at'] != null) {
      try {
        createdAt = DateTime.parse(json['created_at']);
      } catch (e) {
        print('[PaymentData] Erro ao converter created_at: $e');
      }
    }

    // Tempo de expiração em segundos
    int? expiresIn;
    if (json['expires_in'] != null) {
      if (json['expires_in'] is int) {
        expiresIn = json['expires_in'];
      } else if (json['expires_in'] is String) {
        try {
          expiresIn = int.parse(json['expires_in']);
        } catch (e) {
          print('[PaymentData] Erro ao converter expires_in: $e');
        }
      }
    } else if (json['remainingDays'] != null) {
      // Converter dias para segundos (aproximado)
      try {
        final remainingDays = json['remainingDays'] is int
            ? json['remainingDays']
            : int.parse(json['remainingDays'].toString());
        expiresIn = remainingDays * 24 * 60 * 60; // dias para segundos
        print(
            '[PaymentData] Convertendo remainingDays para expiresIn: $expiresIn segundos');
      } catch (e) {
        print('[PaymentData] Erro ao converter remainingDays: $e');
      }
    }

    // Verificar se a assinatura está ativa
    if (json['active'] == true || json['isPremium'] == true) {
      status = 'active';
      print(
          '[PaymentData] Ajustando status para "active" com base em active/isPremium');
    }

    // QR Code pode vir em diferentes formatos
    QrCodeData? qrCode;
    if (json['qr_code'] != null) {
      print('[PaymentData] QR Code presente no JSON: ${json['qr_code']}');
      try {
        qrCode = QrCodeData.fromJson(json['qr_code']);
      } catch (e) {
        print('[PaymentData] Erro ao criar QrCodeData: $e');
      }
    } else if (json['qrCode'] != null) {
      // Nome alternativo
      print(
          '[PaymentData] QrCode (camelCase) presente no JSON: ${json['qrCode']}');
      try {
        qrCode = QrCodeData.fromJson(json['qrCode']);
      } catch (e) {
        print('[PaymentData] Erro ao criar QrCodeData (camelCase): $e');
      }
    } else {
      print('[PaymentData] QR Code não encontrado no JSON');
    }

    print(
        '[PaymentData] Valores finais: subscriptionId=$subscriptionId, paymentId=$paymentId, status=$status, planType=$planType, expiresAt=$expiresAt, expiresIn=$expiresIn');

    return PaymentData(
      subscriptionId: subscriptionId,
      paymentId: paymentId,
      status: status,
      value: value,
      planType: planType,
      createdAt: createdAt,
      expiresAt: expiresAt,
      expiresIn: expiresIn,
      qrCode: qrCode,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'subscription_id': subscriptionId,
      'payment_id': paymentId,
      'status': status,
      'value': value,
      'plan_type': planType,
      'created_at': createdAt?.toIso8601String(),
      'expires_at': expiresAt?.toIso8601String(),
      'expires_in': expiresIn,
      'qr_code': qrCode?.toJson(),
    };
  }

  bool get isPending => status.toLowerCase() == 'pending';
  bool get isActive => status.toLowerCase() == 'active';
}

class QrCodeData {
  final String image;
  final String copyPaste;

  QrCodeData({required this.image, required this.copyPaste});

  factory QrCodeData.fromJson(dynamic json) {
    // Verifica se json é null antes de acessar seus campos
    if (json == null) {
      print('[QrCodeData] JSON nulo, criando objeto vazio');
      return QrCodeData(image: '', copyPaste: '');
    }

    String imageValue = '';
    String copyPasteValue = '';

    // Se json é um Map (objeto), extrair os campos
    if (json is Map) {
      print('[QrCodeData] JSON é um Map com chaves: ${json.keys.toList()}');

      // Tentar diferentes nomes de campos para a imagem
      if (json['image'] != null) {
        imageValue = json['image'].toString();
      } else if (json['qr_image'] != null) {
        imageValue = json['qr_image'].toString();
      } else if (json['qrImage'] != null) {
        imageValue = json['qrImage'].toString();
      }

      // Tentar diferentes nomes de campos para o código copia e cola
      if (json['copy_paste'] != null) {
        copyPasteValue = json['copy_paste'].toString();
      } else if (json['copyPaste'] != null) {
        copyPasteValue = json['copyPaste'].toString();
      } else if (json['pix_copia_cola'] != null) {
        copyPasteValue = json['pix_copia_cola'].toString();
      } else if (json['pixCopiaCola'] != null) {
        copyPasteValue = json['pixCopiaCola'].toString();
      } else if (json['code'] != null) {
        copyPasteValue = json['code'].toString();
      }
    }
    // Se json é uma string, considerar como a imagem
    else if (json is String) {
      print('[QrCodeData] JSON é uma String, considerando como a imagem');
      imageValue = json;
    }

    print(
        '[QrCodeData] Criando com imagem (${imageValue.length} caracteres) e copyPaste (${copyPasteValue.length} caracteres)');

    return QrCodeData(
      image: imageValue,
      copyPaste: copyPasteValue,
    );
  }

  Map<String, dynamic> toJson() {
    return {'image': image, 'copy_paste': copyPaste};
  }

  bool get isValid => image.isNotEmpty && copyPaste.isNotEmpty;
}
