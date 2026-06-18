import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../models/user_model.dart';
import '../models/subscription_model.dart';
import 'app_integrity_service.dart';
import '../util/app_constants.dart';

class ApiService {
  static const String baseUrl = AppConstants.API_BASE_URL;
  static const String subscriptionBaseUrl = baseUrl;

  static Map<String, dynamic> _decodeResponseMap(http.Response response) {
    final body = response.body.trim();
    if (body.isEmpty) {
      return <String, dynamic>{};
    }

    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {
      // Some gateways return plain text for timeout/proxy failures.
    }

    return <String, dynamic>{
      'message': _fallbackErrorMessage(response.statusCode, body),
    };
  }

  static String _fallbackErrorMessage(int statusCode, String body) {
    final normalizedBody = body.toLowerCase();

    if (statusCode == 504 || normalizedBody.contains('error code: 504')) {
      return 'A geração demorou mais que o esperado. Tente novamente em instantes.';
    }

    if (statusCode == 502 || statusCode == 503) {
      return 'O servidor está temporariamente indisponível. Tente novamente em instantes.';
    }

    if (body.isNotEmpty && body.length <= 160) {
      return body;
    }

    return 'Falha na comunicação com o servidor ($statusCode).';
  }

  // Método para autenticar com Google
  static Future<Map<String, dynamic>> authenticateWithGoogle({
    required String email,
    required String name,
    required String googleId,
    required String picture,
  }) async {
    try {
      final normalizedEmail = email.trim();
      final normalizedName = name.trim();
      final normalizedGoogleId = googleId.trim();
      final normalizedPicture = picture.trim();

      final response = await http.post(
        Uri.parse('$baseUrl/auth/google'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': normalizedEmail,
          'name': normalizedName,
          'googleId': normalizedGoogleId,
          'photo': normalizedPicture,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('Resposta autenticação (sucesso): $data');
        return data;
      } else {
        print(
          'Resposta autenticação (erro ${response.statusCode}): ${response.body}',
        );
        throw Exception('Falha na autenticação: ${response.statusCode}');
      }
    } catch (e) {
      print('Erro na autenticação com Google: $e');
      return {
        'success': false,
        'message': 'Erro ao conectar: ${e.toString()}',
      };
    }
  }

  // Método para autenticar com email e senha
  static Future<Map<String, dynamic>> authenticateWithEmail({
    required String email,
    required String senha,
  }) async {
    try {
      final normalizedEmail = email.trim();
      final normalizedSenha = senha.trim();

      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': normalizedEmail,
          'senha': normalizedSenha,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('Resposta autenticação com email (sucesso): $data');
        return data;
      } else {
        final errorData = jsonDecode(response.body);
        print(
          'Resposta autenticação com email (erro ${response.statusCode}): ${response.body}',
        );
        return {
          'success': false,
          'message': errorData['message'] ?? 'Erro de autenticação',
        };
      }
    } catch (e) {
      print('Erro na autenticação com email: $e');
      return {
        'success': false,
        'message': 'Erro ao conectar: ${e.toString()}',
      };
    }
  }

  // Método para registrar novo usuário com email e senha
  static Future<Map<String, dynamic>> registerWithEmail({
    required String name,
    required String email,
    required String senha,
  }) async {
    try {
      final normalizedName = name.trim();
      final normalizedEmail = email.trim();
      final normalizedSenha = senha.trim();

      final response = await http.post(
        Uri.parse('$baseUrl/auth/registro'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'nome': normalizedName, // API espera 'nome' em português
          'email': normalizedEmail,
          'senha': normalizedSenha,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        print('Resposta registro com email (sucesso): $data');
        return data;
      } else {
        final errorData = jsonDecode(response.body);
        print(
          'Resposta registro com email (erro ${response.statusCode}): ${response.body}',
        );
        return {
          'success': false,
          'message': errorData['message'] ?? 'Erro ao criar conta',
        };
      }
    } catch (e) {
      print('Erro no registro com email: $e');
      return {
        'success': false,
        'message': 'Erro ao conectar: ${e.toString()}',
      };
    }
  }

  // Método para obter informações do usuário atual usando o token
  static Future<User> getUserProfile(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/user/profile'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return User.fromJson(data['user']);
      } else {
        throw Exception('Falha ao obter perfil: ${response.statusCode}');
      }
    } catch (e) {
      // Não devemos retornar dados fixos aqui para evitar problemas de persistência
      print('Erro ao obter perfil: $e');
      print('Falha ao obter perfil do usuário');
      rethrow; // Propagar o erro para ser tratado adequadamente
    }
  }

  // Método para obter dados completos do usuário pelo ID
  static Future<Map<String, dynamic>> getUserData(
      String token, int userId) async {
    try {
      print('[ApiService] Buscando dados do usuário ID: $userId');

      final response = await http.get(
        Uri.parse('$baseUrl/user/$userId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('[ApiService] Dados do usuário obtidos com sucesso');
        return data;
      } else {
        print('[ApiService] Erro ao obter dados: ${response.statusCode}');
        throw Exception(
            'Falha ao obter dados do usuário: ${response.statusCode}');
      }
    } catch (e) {
      print('[ApiService] Erro na requisição de dados do usuário: $e');
      // Para ambiente de desenvolvimento, retornamos dados simulados
      print('[ApiService] Retornando dados simulados para desenvolvimento');

      return {
        "id": userId,
        "name": "João Silva",
        "email": "joao.silva@gmail.com",
        "username": "João Silva",
        "photo": null,
        "subscription": "free",
        "credits": {
          "available": 30,
          "lastReset": DateTime.now().toIso8601String()
        }
      };
    }
  }

  // MÉTODOS DE ASSINATURA

  static Future<Map<String, dynamic>> getSubscriptionConfig({
    required String token,
    required int userId,
  }) async {
    final response = await http.get(
      Uri.parse('$subscriptionBaseUrl/subscription/config/$userId'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Falha ao obter status da assinatura: ${response.statusCode} - ${response.body}',
      );
    }

    final responseData = jsonDecode(response.body) as Map<String, dynamic>;
    if (responseData['success'] != true || responseData['data'] == null) {
      throw Exception(
        responseData['message'] ?? 'Resposta inválida ao obter assinatura',
      );
    }

    return responseData['data'] as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> confirmGooglePlaySubscription({
    required String token,
    required String purchaseToken,
    required String productId,
  }) async {
    final response = await http.post(
      Uri.parse('$subscriptionBaseUrl/subscription/google-play/confirm'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'purchaseToken': purchaseToken,
        'productId': productId,
      }),
    );

    final responseData = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode != 200 || responseData['success'] != true) {
      throw Exception(
        responseData['error'] ??
            responseData['message'] ??
            'Falha ao confirmar assinatura na Google Play',
      );
    }

    return responseData['data'] as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> grantRewardedAdCredits({
    required String token,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/credits/rewarded-ad'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({}),
    );

    final responseData = response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        responseData['success'] != true ||
        responseData['data'] is! Map<String, dynamic>) {
      throw Exception(
        responseData['message'] ??
            responseData['error'] ??
            'Falha ao adicionar créditos do anúncio premiado',
      );
    }

    return responseData['data'] as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> getUserCredits({
    required String token,
    required int userId,
  }) async {
    final response = await http.get(
      Uri.parse('$baseUrl/credits/$userId'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    final responseData = response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        responseData['success'] != true ||
        responseData['data'] is! Map<String, dynamic>) {
      throw Exception(
        responseData['message'] ??
            responseData['error'] ??
            'Falha ao consultar créditos',
      );
    }

    return responseData['data'] as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> generateProfileShapePreview({
    required String token,
    required Uint8List imageBytes,
    String language = 'pt-BR',
  }) async {
    final headers = <String, String>{
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
    headers.addAll(await AppIntegrityService.appCheckHeaders());

    final response = await http
        .post(
          Uri.parse(
              '${AppConstants.DIET_API_BASE_URL}/ai/profile-shape-preview'),
          headers: headers,
          body: jsonEncode({
            'imageBase64': 'data:image/jpeg;base64,${base64Encode(imageBytes)}',
            'language': language,
          }),
        )
        .timeout(const Duration(minutes: 5));

    final responseData = _decodeResponseMap(response);

    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        responseData['success'] != true ||
        responseData['data'] is! Map<String, dynamic>) {
      throw Exception(
        responseData['message'] ??
            responseData['error'] ??
            'Falha ao gerar prévia no shape',
      );
    }

    return responseData['data'] as Map<String, dynamic>;
  }

  static Future<User> updateOwnProfilePhoto({
    required String token,
    required String photo,
  }) async {
    final response = await http.put(
      Uri.parse('$baseUrl/user/profile/photo'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'photo': photo}),
    );

    final responseData = response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body) as Map<String, dynamic>;

    final data = responseData['data'];
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        responseData['success'] != true ||
        data is! Map ||
        data['user'] is! Map) {
      throw Exception(
        responseData['message'] ??
            responseData['error'] ??
            'Falha ao atualizar foto de perfil',
      );
    }

    return User.fromJson(Map<String, dynamic>.from(data['user'] as Map));
  }

  // Criar pagamento de assinatura
  static Future<PaymentData> createSubscriptionPayment({
    required String token,
    required int userId,
    required String planType,
  }) async {
    try {
      print('[API] Criando pagamento para plano: $planType, userId: $userId');

      final response = await http.post(
        Uri.parse('$subscriptionBaseUrl/subscription/payment'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'userId': userId, 'planType': planType}),
      );

      print('[API] Resposta: ${response.statusCode} - ${response.body}');

      // Verifica se o status é 200 (OK) ou 201 (Created)
      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        print('[API] Resposta decodificada: $responseData');

        if (responseData['success'] == true && responseData['data'] != null) {
          // Depurar estrutura de dados
          final data = responseData['data'];
          print('[API] Estrutura de data: ${data.runtimeType}');
          if (data is Map) {
            print('[API] Chaves em data: ${data.keys.toList()}');
            if (data['qr_code'] != null) {
              print('[API] QR code presente no JSON');
              print(
                  '[API] Estrutura de qr_code: ${data['qr_code'].runtimeType}');
              print('[API] Conteúdo de qr_code: ${data['qr_code']}');
            } else {
              print('[API] QR code ausente no JSON');
            }
          }

          // Sucesso - retorna os dados do pagamento real
          final paymentData = PaymentData.fromJson(responseData['data']);
          print('[API] PaymentData criado: ${paymentData.toJson()}');
          print('[API] QR Code presente: ${paymentData.qrCode != null}');
          if (paymentData.qrCode != null) {
            print(
                '[API] Tamanho da imagem QR: ${paymentData.qrCode!.image.length} caracteres');
            print(
                '[API] Tamanho do copia/cola: ${paymentData.qrCode!.copyPaste.length} caracteres');
          }
          return paymentData;
        } else {
          // Falha na resposta da API
          throw Exception(
            responseData['message'] ??
                'Falha ao criar pagamento: Resposta inesperada da API',
          );
        }
      } else {
        // Erro HTTP
        throw Exception(
          'Erro ao criar pagamento: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      // Erro de conexão ou outro erro
      print('Erro fatal ao criar pagamento: $e');
      throw Exception(
          'Não foi possível conectar ao servidor para criar o pagamento: $e');
    }
  }

  // Verificar status do pagamento
  static Future<PaymentData> checkPaymentStatus({
    required String token,
    required String? paymentId,
  }) async {
    if (paymentId == null) {
      throw Exception('ID do pagamento não fornecido');
    }

    try {
      print('[API] Verificando status do pagamento: $paymentId');

      final url = '$subscriptionBaseUrl/subscription/payment/$paymentId';
      print('[API] URL: $url');

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print('[API] Resposta status: ${response.statusCode} - ${response.body}');

      // Verifica se o status é 200 (OK) ou 201 (Created)
      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        print('[API] Resposta decodificada: $responseData');

        if (responseData['success'] == true) {
          // Sucesso - retorna os dados do status do pagamento real
          // A resposta da API tem o formato:
          // { "success": true, "data": { ... }, "message": "..." }
          final data = responseData['data'];
          print('[API] Dados de pagamento: $data');

          if (data != null) {
            final paymentData = PaymentData.fromJson(data);
            print('[API] PaymentStatus criado: ${paymentData.toJson()}');
            print('[API] Status do pagamento: ${paymentData.status}');
            print('[API] QR Code presente: ${paymentData.qrCode != null}');
            if (paymentData.qrCode != null) {
              print(
                  '[API] Tamanho da imagem QR: ${paymentData.qrCode!.image.length} caracteres');
              print(
                  '[API] Tamanho do copia/cola: ${paymentData.qrCode!.copyPaste.length} caracteres');
            }
            return paymentData;
          } else {
            throw Exception('Dados do pagamento ausentes na resposta da API');
          }
        } else {
          // Falha na resposta da API
          throw Exception(
            responseData['message'] ??
                'Falha ao verificar status: Resposta inesperada da API',
          );
        }
      } else {
        // Erro HTTP
        throw Exception(
          'Erro ao verificar status: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      // Erro de conexão ou outro erro
      print('Erro fatal ao verificar status: $e');
      throw Exception(
          'Não foi possível conectar ao servidor para verificar o status: $e');
    }
  }

  // Métodos auxiliares para simulação (REMOVIDOS)
  // static PaymentData _getMockPaymentData(String planType) { ... }
  // static PaymentData _getMockPaymentStatus(String paymentId) { ... }
}
