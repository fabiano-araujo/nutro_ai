import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../image_upload.dart';
import '../services/ai_service.dart';
import '../services/storage_service.dart';
import '../models/study_item.dart';
import '../theme/app_theme.dart';
import '../i18n/app_localizations_extension.dart';
import '../widgets/message_notifier.dart';
import '../utils/message_formatter.dart';
import '../utils/code_detector.dart';
import '../providers/credit_provider.dart';
import '../widgets/credit_indicator.dart';
import '../i18n/language_controller.dart';
import '../widgets/state_animation.dart';

class DocumentScanScreen extends StatefulWidget {
  final bool showScanOptions;
  final Uint8List? initialImage;
  final String? initialScanMode;

  const DocumentScanScreen({
    Key? key,
    this.showScanOptions = false,
    this.initialImage,
    this.initialScanMode,
  }) : super(key: key);

  @override
  _DocumentScanScreenState createState() => _DocumentScanScreenState();
}

class _DocumentScanScreenState extends State<DocumentScanScreen> {
  String _selectedScanMode = 'general'; // 'translate', 'general', 'math'
  final AIService _aiService = AIService();
  final StorageService _storageService = StorageService();
  final TextEditingController _questionController = TextEditingController();

  Uint8List? _imageBytes;
  String? _response;
  bool _isLoading = false;
  bool _isError = false;
  StreamSubscription? _aiStreamSubscription;
  MessageNotifier? _messageNotifier;

  @override
  void initState() {
    super.initState();

    // Initialize with provided image and scan mode if available
    if (widget.initialImage != null) {
      _imageBytes = widget.initialImage;
    }

    if (widget.initialScanMode != null) {
      _selectedScanMode = widget.initialScanMode!;

      // Use addPostFrameCallback para garantir que as traduções estejam disponíveis
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Update prompt based on scan mode
        if (_selectedScanMode == 'translate') {
          _questionController.text =
              context.tr.translate('translate_to_local') ??
                  'Traduza para o idioma local';
        } else if (_selectedScanMode == 'math') {
          _questionController.text =
              context.tr.translate('solve_math_problem') ??
                  'Resolva este problema de matemática com todos os passos';
        }
      });
    }
  }

  @override
  void dispose() {
    _questionController.dispose();
    _aiStreamSubscription?.cancel();
    super.dispose();
  }

  Future<void> _captureImage() async {
    try {
      final imageBytes = await ImageUploadHelper.captureImage();
      if (imageBytes != null) {
        setState(() {
          _imageBytes = imageBytes;
          _response = null;
        });
      }
    } catch (e) {
      _showErrorSnackBar(
          '${context.tr.translate('failed_to_capture_image')}: $e');
    }
  }

  Future<void> _pickImage() async {
    try {
      final imageBytes = await ImageUploadHelper.pickImageFromGallery();
      if (imageBytes != null) {
        setState(() {
          _imageBytes = imageBytes;
          _response = null;
        });
      }
    } catch (e) {
      _showErrorSnackBar('${context.tr.translate('failed_to_pick_image')}: $e');
    }
  }

  Future<void> _processImage() async {
    if (_imageBytes == null) {
      _showErrorSnackBar(context.tr.translate('please_select_image_first') ??
          'Por favor, capture ou selecione uma imagem primeiro');
      return;
    }

    // Verificar se há créditos suficientes antes de processar o arquivo
    final creditProvider = Provider.of<CreditProvider>(context, listen: false);
    final hasSufficientCredits =
        await creditProvider.consumeFileAnalysisCredit();

    if (!hasSufficientCredits) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Sem créditos suficientes para análise de arquivo. A análise de arquivo custa 4 créditos.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Obter o controlador de idioma
    final languageController =
        Provider.of<LanguageController>(context, listen: false);
    final languageCode = _aiService.getCurrentLanguageCode(languageController);

    // Criar um notificador para atualizar a resposta em tempo real
    _messageNotifier = MessageNotifier();
    _messageNotifier!.setStreaming(true); // Garantir que está em modo streaming

    setState(() {
      _isLoading = true;
      _isError = false;
      _response = null;
    });

    try {
      final String userLocale = Localizations.localeOf(context).toString();
      String promptPrefix = '';

      // Adicionar instrução de idioma ao prompt
      if (userLocale.startsWith('pt')) {
        promptPrefix = 'Responda em português brasileiro: ';
      } else if (userLocale.startsWith('es')) {
        promptPrefix = 'Responda en español: ';
      } else if (userLocale.startsWith('fr')) {
        promptPrefix = 'Répondez en français: ';
      } else if (userLocale.startsWith('de')) {
        promptPrefix = 'Antworten Sie auf Deutsch: ';
      } else if (userLocale.startsWith('it')) {
        promptPrefix = 'Risponda in italiano: ';
      } else {
        promptPrefix = 'Answer in English: ';
      }

      final prompt = _questionController.text.isEmpty
          ? '$promptPrefix${context.tr.translate('solve_and_explain_detailed') ?? 'Por favor, resolva este problema e forneça uma explicação detalhada da solução.'}'
          : '$promptPrefix${_questionController.text}';

      print(
          '🚀 DocumentScanScreen - Iniciando processamento de imagem com streaming');

      // Variáveis para controlar acumulação
      int receivedChunks = 0;
      String acumuladoAtual = '';

      // Usar stream para obter a resposta progressivamente
      _aiStreamSubscription = _aiService
          .processImageStream(_imageBytes!, prompt, languageCode: languageCode)
          .listen(
        (chunk) {
          receivedChunks++;
          acumuladoAtual += chunk;

          // Log a cada 5 chunks para não sobrecarregar o console
          if (receivedChunks % 5 == 0 || chunk.contains('\n')) {
            print(
                '📨 DocumentScanScreen - Chunk #$receivedChunks recebido: "${chunk}"');
          }

          // Atualizar o notificador, que atualizará a UI automaticamente
          _messageNotifier!.updateMessage(acumuladoAtual);
        },
        onDone: () async {
          print(
              '✅ DocumentScanScreen - Streaming concluído, total de $receivedChunks chunks');

          if (mounted && _messageNotifier != null) {
            final responseContent = _messageNotifier!.message;
            print(
                '📊 DocumentScanScreen - Resposta final: ${responseContent.length} caracteres');

            // Marcar que não está mais em streaming
            _messageNotifier!.setStreaming(false);

            setState(() {
              _isLoading = false;
              _response = responseContent;
            });

            // Salva no histórico quando a resposta estiver completa
            final studyItem = StudyItem(
              title: context.tr.translate('scanned_question') ??
                  'Pergunta Digitalizada',
              content: _questionController.text.isEmpty
                  ? context.tr.translate('image_scan') ??
                      'Digitalização de imagem'
                  : _questionController.text,
              response: responseContent,
              type: 'scan',
            );

            await _storageService.saveToHistory(studyItem);
          }
        },
        onError: (error) {
          print('❌ DocumentScanScreen - Erro durante streaming: $error');

          if (mounted && _messageNotifier != null) {
            _messageNotifier!.setError(true,
                'Desculpe, tive um problema ao processar sua imagem. Pode tentar novamente?\n\nErro: ${error.toString().replaceAll("Exception: ", "")}');

            setState(() {
              _isLoading = false;
              _isError = true;
            });
          }
        },
      );
    } catch (e) {
      print('❌ DocumentScanScreen - Exceção ao processar imagem: $e');

      if (_messageNotifier != null) {
        _messageNotifier!
            .setError(true, 'Ocorreu um erro inesperado: ${e.toString()}');
      }

      setState(() {
        _isLoading = false;
        _isError = true;
      });

      _showErrorSnackBar(
          '${context.tr.translate('error_processing_image') ?? 'Erro ao processar imagem'}: $e');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppTheme.errorColor),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDarkMode ? AppTheme.darkBackgroundColor : AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor:
            isDarkMode ? AppTheme.darkBackgroundColor : Colors.white,
        title: Text(widget.showScanOptions
            ? context.tr.translate('scan') ?? 'Digitalizar'
            : context.tr.translate('scan_and_solve') ??
                'Digitalizar e Resolver'),
        centerTitle: false,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: CreditIndicator(),
          ),
        ],
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          physics: BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Scan options if enabled
                if (widget.showScanOptions) _buildScanOptions(isDarkMode),

                // Image preview or upload section
                _buildImageSection(isDarkMode),

                SizedBox(height: 16),

                // Additional prompt field
                TextField(
                  controller: _questionController,
                  decoration: InputDecoration(
                    labelText:
                        context.tr.translate('additional_instructions') ??
                            'Instruções adicionais (opcional)',
                    hintText: context.tr.translate('prompt_hint') ??
                        'Ex: "Resolva este problema" ou "Explique este conceito"',
                    prefixIcon: Icon(Icons.lightbulb_outline),
                    fillColor:
                        isDarkMode ? AppTheme.darkComponentColor : Colors.white,
                  ),
                  maxLines: 2,
                  style: TextStyle(
                    color: isDarkMode
                        ? AppTheme.darkTextColor
                        : AppTheme.textPrimaryColor,
                  ),
                ),

                SizedBox(height: 24),

                // Process button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _imageBytes != null && !_isLoading
                        ? _processImage
                        : null,
                    icon: Icon(Icons.auto_awesome),
                    label: Text(context.tr.translate('get_solution') ??
                        'Obter Solução'),
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),

                SizedBox(height: 24),

                // Response section
                Text(
                  context.tr.translate('solution') ?? 'Solução',
                  style: AppTheme.headingSmall,
                ),
                SizedBox(height: 8),
                _buildMessageBubble(isDarkMode, _response),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildScanOptions(bool isDarkMode) {
    final List<Map<String, dynamic>> scanOptions = [
      {
        'value': 'translate',
        'label': context.tr.translate('translate') ?? 'Traduzir',
        'icon': Icons.translate,
        'color': Color(0xFF21AAFF),
        'description': context.tr.translate('translate_description') ??
            'Traduza textos de qualquer idioma',
      },
      {
        'value': 'general',
        'label': context.tr.translate('general') ?? 'Geral',
        'icon': Icons.auto_awesome,
        'color': AppTheme.primaryColor,
        'description': context.tr.translate('general_description') ??
            'Digitalize e receba explicações detalhadas',
      },
      {
        'value': 'math',
        'label': context.tr.translate('math') ?? 'Matemática',
        'icon': Icons.functions,
        'color': Color(0xFFFF7A50),
        'description': context.tr.translate('math_description') ??
            'Resolva problemas matemáticos com passos',
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr.translate('scan_mode') ?? 'Modo de Digitalização',
          style: AppTheme.headingSmall,
        ),
        SizedBox(height: 12),
        Container(
          height: 120,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: scanOptions.length,
            itemBuilder: (context, index) {
              final option = scanOptions[index];
              final isSelected = _selectedScanMode == option['value'];

              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedScanMode = option['value'];
                  });

                  // Use addPostFrameCallback para garantir que as traduções estejam disponíveis
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    // Update placeholder text based on scan mode
                    if (_selectedScanMode == 'translate') {
                      _questionController.text =
                          context.tr.translate('translate_to_local') ??
                              'Traduza para o idioma local';
                    } else if (_selectedScanMode == 'math') {
                      _questionController.text = context.tr
                              .translate('solve_math_problem') ??
                          'Resolva este problema de matemática com todos os passos';
                    } else {
                      _questionController.text = '';
                    }
                  });
                },
                child: Container(
                  width: 130,
                  margin: EdgeInsets.only(right: 12, bottom: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? option['color'].withOpacity(isDarkMode ? 0.3 : 0.1)
                        : isDarkMode
                            ? AppTheme.darkComponentColor
                            : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? option['color']
                          : isDarkMode
                              ? AppTheme.darkBorderColor
                              : Colors.grey[300]!,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  padding: EdgeInsets.all(12),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: option['color']
                              .withOpacity(isDarkMode ? 0.2 : 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          option['icon'],
                          color: option['color'],
                          size: 24,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        option['label'],
                        style: AppTheme.bodyMedium.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isSelected
                              ? option['color']
                              : isDarkMode
                                  ? AppTheme.darkTextColor
                                  : AppTheme.textPrimaryColor,
                        ),
                      ),
                      SizedBox(height: 4),
                      Expanded(
                        child: Text(
                          option['description'],
                          style: AppTheme.captionText.copyWith(
                            color: isDarkMode
                                ? AppTheme.darkTextColor.withOpacity(0.7)
                                : AppTheme.textSecondaryColor,
                            fontSize: 10,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        SizedBox(height: 16),
      ],
    );
  }

  Widget _buildImageSection(bool isDarkMode) {
    return Container(
      width: double.infinity,
      height: 250,
      decoration: BoxDecoration(
        color: isDarkMode ? AppTheme.darkComponentColor : Colors.grey[100],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDarkMode ? AppTheme.darkBorderColor : Colors.grey[300]!,
          width: 1,
        ),
      ),
      child: _imageBytes != null
          ? Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: Image.memory(
                    _imageBytes!,
                    fit: BoxFit.contain,
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: Icon(Icons.close, color: Colors.white),
                      onPressed: () {
                        setState(() {
                          _imageBytes = null;
                          _response = null;
                        });
                      },
                    ),
                  ),
                ),
              ],
            )
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.camera_alt_outlined,
                  size: 48,
                  color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                ),
                SizedBox(height: 16),
                Text(
                  context.tr.translate('capture_or_select_image') ??
                      'Capture ou selecione uma imagem',
                  style: AppTheme.bodyMedium.copyWith(
                    color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
                SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _captureImage,
                      icon: Icon(Icons.camera_alt),
                      label: Text(context.tr.translate('camera') ?? 'Câmera'),
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    SizedBox(width: 16),
                    OutlinedButton.icon(
                      onPressed: _pickImage,
                      icon: Icon(Icons.image),
                      label: Text(context.tr.translate('gallery') ?? 'Galeria'),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  Widget _buildMessageBubble(bool isDarkMode, String? response) {
    // Se não tiver resposta ou estiver carregando, mostrar indicador de carregamento
    if (_isLoading && _messageNotifier != null) {
      return _buildStreamingResponse(isDarkMode);
    }

    if (_isLoading) {
      return _buildLoadingState(isDarkMode);
    }

    if (_isError) {
      return _buildErrorState(isDarkMode);
    }

    if (response == null || response.isEmpty) {
      return _buildEmptyState(isDarkMode);
    }

    // Para resposta já finalizada, mostrar versão estática
    return _buildMessage(
        message: response,
        isDarkMode: isDarkMode,
        isError: false,
        isStreaming: false);
  }

  // Método separado para construir a mensagem, tanto para streaming quanto para resposta finalizada
  Widget _buildMessage({
    required String message,
    required bool isDarkMode,
    required bool isError,
    required bool isStreaming,
  }) {
    // Verificar se contém código HTML
    bool containsHtml = CodeDetector.isHtmlCode(message);

    return Container(
      decoration: BoxDecoration(
        color: isDarkMode ? AppTheme.darkComponentColor : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDarkMode ? Colors.grey[800]! : Colors.grey[300]!,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: Offset(0, 2),
          ),
        ],
      ),
      margin: EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.school,
                  color: AppTheme.primaryColor,
                  size: 16,
                ),
              ),
              SizedBox(width: 8),
              Text(
                'IA Assistant',
                style: AppTheme.bodyMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isDarkMode
                      ? AppTheme.darkTextColor
                      : AppTheme.textPrimaryColor,
                ),
              ),
              if (isStreaming) ...[
                SizedBox(width: 8),
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppTheme.primaryColor,
                    ),
                  ),
                ),
              ],
            ],
          ),
          SizedBox(height: 12),
          if (isError)
            Text(
              message,
              style: AppTheme.bodyMedium.copyWith(
                color: AppTheme.errorColor,
              ),
            )
          else if (message.isNotEmpty)
            _buildFormattedText(
              message,
              style: AppTheme.bodyMedium.copyWith(
                color: isDarkMode
                    ? AppTheme.darkTextColor
                    : AppTheme.textPrimaryColor,
              ),
              isDarkMode: isDarkMode,
            )
          else if (isStreaming)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: _buildTypingIndicator(),
            ),
          if (!isError && !isStreaming && message.isNotEmpty) ...[
            SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: Icon(Icons.copy_outlined, size: 16),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: message));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content:
                            Text('Texto copiado para a área de transferência'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  },
                  tooltip: 'Copiar resposta',
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints(),
                  color: isDarkMode
                      ? AppTheme.darkTextColor.withOpacity(0.7)
                      : AppTheme.textSecondaryColor,
                ),
                if (containsHtml) ...[
                  SizedBox(width: 16),
                  IconButton(
                    icon: Icon(Icons.html, size: 16),
                    onPressed: () {
                      // Adicionar visualização de HTML se necessário
                    },
                    tooltip: 'Visualizar HTML',
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(),
                    color: AppTheme.primaryColor,
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStreamingResponse(bool isDarkMode) {
    // Use ChangeNotifierProvider para atualizar automaticamente a interface quando a mensagem mudar
    return ChangeNotifierProvider.value(
      value: _messageNotifier!,
      child: Consumer<MessageNotifier>(
        builder: (context, notifier, _) {
          final texto = notifier.message;
          final isStreaming = notifier.isStreaming;
          final isError = notifier.isError;

          // Usar o mesmo método de construção das mensagens finalizadas
          return _buildMessage(
            message: texto,
            isDarkMode: isDarkMode,
            isError: isError,
            isStreaming: isStreaming,
          );
        },
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Row(
      children: List.generate(
        3,
        (index) => Container(
          margin: EdgeInsets.symmetric(horizontal: 2),
          height: 6,
          width: 6,
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withOpacity(0.5),
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState(bool isDarkMode) {
    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDarkMode ? AppTheme.darkComponentColor : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDarkMode ? Colors.grey[800]! : Colors.grey[300]!,
          width: 1,
        ),
      ),
      child: Column(
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
          ),
          SizedBox(height: 16),
          Text(
            'Processando sua solicitação...',
            style: AppTheme.bodyMedium.copyWith(
              color: isDarkMode
                  ? AppTheme.darkTextColor
                  : AppTheme.textPrimaryColor,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(bool isDarkMode) {
    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDarkMode ? Color(0xFF2A2020) : Color(0xFFFEEDED),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          StateAnimation(
            fallbackIcon: Icons.error_outline,
            size: 120,
            accentColor: AppTheme.errorColor,
          ),
          SizedBox(height: 16),
          Text(
            'Ocorreu um erro ao processar a imagem',
            style: AppTheme.bodyMedium.copyWith(
              fontWeight: FontWeight.bold,
              color: isDarkMode
                  ? AppTheme.darkTextColor
                  : AppTheme.textPrimaryColor,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 8),
          Text(
            'Por favor, tente novamente',
            style: AppTheme.bodySmall.copyWith(
              color: isDarkMode
                  ? AppTheme.darkTextColor.withOpacity(0.7)
                  : AppTheme.textSecondaryColor,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDarkMode) {
    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDarkMode ? AppTheme.darkComponentColor : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDarkMode ? Colors.grey[800]! : Colors.grey[300]!,
          width: 1,
        ),
      ),
      child: Column(
        children: [
          StateAnimation(
            fallbackIcon: Icons.info_outline,
            size: 120,
            accentColor: AppTheme.warningColor,
          ),
          SizedBox(height: 16),
          Text(
            'Selecione uma imagem e clique em "Obter Solução"',
            style: AppTheme.bodyMedium.copyWith(
              color: isDarkMode
                  ? AppTheme.darkTextColor
                  : AppTheme.textPrimaryColor,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // Método para formatar texto, usando o MessageFormatter
  Widget _buildFormattedText(String text,
      {required TextStyle style, required bool isDarkMode}) {
    return MessageFormatter.buildFormattedText(
      text,
      style: style,
      isDarkMode: isDarkMode,
    );
  }
}
