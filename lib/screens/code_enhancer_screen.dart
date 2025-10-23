import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../services/ai_service.dart';
import '../services/storage_service.dart';
import '../models/study_item.dart';
import '../theme/app_theme.dart';
import '../widgets/response_display.dart';

class CodeEnhancerScreen extends StatefulWidget {
  const CodeEnhancerScreen({Key? key}) : super(key: key);

  @override
  _CodeEnhancerScreenState createState() => _CodeEnhancerScreenState();
}

class _CodeEnhancerScreenState extends State<CodeEnhancerScreen> {
  final AIService _aiService = AIService();
  final StorageService _storageService = StorageService();
  final TextEditingController _codeController = TextEditingController();

  String _selectedAction = 'analyze';
  String? _response;
  bool _isLoading = false;
  bool _isError = false;
  bool _showImageOptions = false;
  int _maxCharacters = 1500;

  final List<Map<String, dynamic>> _actionOptions = [
    {
      'value': 'analyze',
      'label': 'Analisar',
      'icon': Icons.analytics,
      'color': Color(0xFF4A6FFF),
    },
    {
      'value': 'check',
      'label': 'Verificar',
      'icon': Icons.fact_check,
      'color': Color(0xFF2DC96B),
    },
    {
      'value': 'optimize',
      'label': 'Otimizar',
      'icon': Icons.speed,
      'color': Color(0xFFFF7A50),
    },
  ];

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _enhanceCode() async {
    final code = _codeController.text;

    if (code.isEmpty) {
      _showErrorSnackBar('Por favor, insira algum código para processar');
      return;
    }

    setState(() {
      _isLoading = true;
      _isError = false;
    });

    try {
      String requestType;
      switch (_selectedAction) {
        case 'analyze':
          requestType = 'explain';
          break;
        case 'check':
          requestType = 'debug';
          break;
        case 'optimize':
          requestType = 'optimize';
          break;
        default:
          requestType = 'explain';
      }

      // Assume a linguagem como "auto" ou a mais comum, como o usuário solicitou remover a escolha
      final result = await _aiService.getCodeHelp(
        code,
        'auto', // Linguagem automática
        requestType,
      );

      // Save to history
      final studyItem = StudyItem(
        title: 'Código ${_getActionLabel(_selectedAction)}',
        content: _codeController.text,
        response: result,
        type: 'code_enhancement',
      );

      await _storageService.saveToHistory(studyItem);

      setState(() {
        _response = result;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _isError = true;
      });
      _showErrorSnackBar('Erro ao processar o código: $e');
    }
  }

  String _getActionLabel(String value) {
    final option = _actionOptions.firstWhere(
      (option) => option['value'] == value,
      orElse: () => {'label': 'Desconhecido'},
    );
    return option['label'] as String;
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppTheme.errorColor),
    );
  }

  void _toggleImageOptions() {
    setState(() {
      _showImageOptions = !_showImageOptions;
    });
  }

  // Método real para capturar uma foto e extrair código
  Future<void> _captureImage() async {
    Navigator.of(context).pop(); // Fecha o modal

    try {
      final ImagePicker picker = ImagePicker();
      final XFile? photo = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1800,
        maxHeight: 1800,
        imageQuality: 90,
      );

      if (photo != null) {
        setState(() {
          _isLoading = true; // Mostrar indicador de carregamento
        });

        await _processImageForText(photo);
      }
    } catch (e) {
      _showErrorSnackBar('Erro ao capturar imagem: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Método real para escolher da galeria
  Future<void> _pickFromGallery() async {
    Navigator.of(context).pop(); // Fecha o modal

    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1800,
        maxHeight: 1800,
        imageQuality: 90,
      );

      if (image != null) {
        setState(() {
          _isLoading = true; // Mostrar indicador de carregamento
        });

        await _processImageForText(image);
      }
    } catch (e) {
      _showErrorSnackBar('Erro ao selecionar imagem: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Método para processar a imagem e extrair texto
  Future<void> _processImageForText(XFile imageFile) async {
    try {
      // Carregar a imagem do arquivo
      final File file = File(imageFile.path);
      final InputImage inputImage = InputImage.fromFile(file);

      // Inicializar o reconhecedor de texto
      final TextRecognizer textRecognizer = TextRecognizer();

      // Processar a imagem para extrair texto
      final RecognizedText recognizedText = await textRecognizer.processImage(
        inputImage,
      );

      // Liberar recursos
      await textRecognizer.close();

      // Extrair o texto reconhecido
      String extractedText = recognizedText.text;

      // Limitar o texto extraído ao número máximo de caracteres se necessário
      if (extractedText.length > _maxCharacters) {
        extractedText = extractedText.substring(0, _maxCharacters);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'O texto foi truncado devido ao limite de caracteres',
            ),
          ),
        );
      }

      // Atualizar o campo de texto com o texto extraído
      setState(() {
        _codeController.text = extractedText;
      });

      // Mostrar mensagem de sucesso
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Texto extraído com sucesso')));
    } catch (e) {
      _showErrorSnackBar('Erro ao processar imagem: $e');
    }
  }

  void _showImageOptionsModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black,
      builder: (context) {
        return Container(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 8.0,
                ),
                child: Text(
                  'Digitalizar foto',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              SizedBox(height: 8),
              InkWell(
                onTap: () => _captureImage(),
                child: Container(
                  margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  padding: EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey[900],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.camera_alt, color: Colors.white),
                      SizedBox(width: 8),
                      Text(
                        'Tirar uma foto',
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),
              InkWell(
                onTap: () => _pickFromGallery(),
                child: Container(
                  margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  padding: EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey[900],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.photo_library, color: Colors.white),
                      SizedBox(width: 8),
                      Text(
                        'Biblioteca de fotos',
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Função para limpar a resposta e permitir uma nova tentativa
  void _resetResponse() {
    setState(() {
      _response = null;
      _isError = false;
    });
  }

  // Função para limpar tudo e começar com um novo código
  void _resetEverything() {
    setState(() {
      _response = null;
      _isError = false;
      _codeController.clear();
    });
  }

  // Função para copiar a resposta para a área de transferência
  void _copyResponseToClipboard() {
    if (_response != null && _response!.isNotEmpty) {
      Clipboard.setData(ClipboardData(text: _response!));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Resultado copiado para a área de transferência'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: Text('Aprimorador de código'), centerTitle: true),
      body: Column(
        children: [
          // Ações no topo (Analisar, Verificar, Otimizar)
          Container(
            padding: EdgeInsets.symmetric(vertical: 8),
            color: theme.scaffoldBackgroundColor,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children:
                  _actionOptions.map((option) {
                    final bool isSelected = _selectedAction == option['value'];
                    return Expanded(
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            _selectedAction = option['value'] as String;
                          });
                        },
                        child: Container(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color:
                                    isSelected
                                        ? option['color'] as Color
                                        : Colors.transparent,
                                width: 2.0,
                              ),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                option['icon'] as IconData,
                                color:
                                    isSelected
                                        ? option['color'] as Color
                                        : Colors.grey,
                                size: 20,
                              ),
                              SizedBox(width: 8),
                              Text(
                                option['label'] as String,
                                style: TextStyle(
                                  color:
                                      isSelected
                                          ? option['color'] as Color
                                          : Colors.grey,
                                  fontWeight:
                                      isSelected
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
            ),
          ),

          // Corpo principal com campo de texto e botão
          Expanded(
            child: GestureDetector(
              onTap: () => FocusScope.of(context).unfocus(),
              child: Container(
                color: theme.scaffoldBackgroundColor,
                child: Stack(
                  children: [
                    // Area de texto e botão
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          // Campo de texto para código
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color:
                                    isDarkMode
                                        ? Colors.black
                                        : Colors.grey[100],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Stack(
                                children: [
                                  // Ícone de câmera como fundo
                                  Center(
                                    child: Icon(
                                      Icons.camera_alt,
                                      size: 120,
                                      color: Colors.grey.withOpacity(0.1),
                                    ),
                                  ),
                                  // Botão invisível sobre o ícone da câmera
                                  Center(
                                    child: GestureDetector(
                                      onTap: () => _showImageOptionsModal(),
                                      child: Container(
                                        width: 150,
                                        height: 150,
                                        color: Colors.transparent,
                                      ),
                                    ),
                                  ),
                                  // Campo de texto com padding para os botões
                                  Container(
                                    constraints: BoxConstraints(
                                      maxHeight:
                                          MediaQuery.of(context).size.height *
                                          0.5,
                                      minHeight:
                                          MediaQuery.of(context).size.height *
                                          0.35,
                                    ),
                                    padding: EdgeInsets.only(
                                      bottom: 46,
                                    ), // Espaço para os botões
                                    child: TextField(
                                      controller: _codeController,
                                      decoration: InputDecoration(
                                        hintText: 'Codificar:',
                                        hintStyle: TextStyle(
                                          color: Colors.grey,
                                        ),
                                        border: InputBorder.none,
                                        contentPadding: EdgeInsets.all(16),
                                      ),
                                      style: TextStyle(
                                        fontFamily: 'monospace',
                                        color:
                                            isDarkMode
                                                ? Colors.white
                                                : Colors.black87,
                                      ),
                                      maxLines: null,
                                      expands: true,
                                      keyboardType: TextInputType.multiline,
                                      onChanged: (text) {
                                        setState(() {
                                          // Atualizar contador
                                        });
                                      },
                                    ),
                                  ),
                                  // Barra inferior dentro do campo de texto
                                  Positioned(
                                    left: 0,
                                    right: 0,
                                    bottom: 0,
                                    child: Container(
                                      height: 46,
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 12,
                                      ),
                                      decoration: BoxDecoration(
                                        color:
                                            isDarkMode
                                                ? Colors.black
                                                : Colors.grey[200],
                                        borderRadius: BorderRadius.only(
                                          bottomLeft: Radius.circular(12),
                                          bottomRight: Radius.circular(12),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          IconButton(
                                            icon: Icon(
                                              Icons.camera_alt,
                                              color: Colors.grey,
                                            ),
                                            onPressed:
                                                () => _showImageOptionsModal(),
                                            tooltip: 'Digitalizar foto',
                                            padding: EdgeInsets.zero,
                                            constraints: BoxConstraints(),
                                          ),
                                          Text(
                                            '${_codeController.text.length}/$_maxCharacters',
                                            style: TextStyle(
                                              color: Colors.grey,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          SizedBox(height: 16),

                          // Botão processar/gerar
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _enhanceCode,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Color(0xFF5E60CE),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child:
                                  _isLoading
                                      ? SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                Colors.white,
                                              ),
                                        ),
                                      )
                                      : Text(
                                        'Gerar',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Exibir resultado se houver
                    if (_response != null || _isError)
                      Container(
                        color: theme.scaffoldBackgroundColor.withOpacity(0.9),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Center(
                                child: SingleChildScrollView(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    children: [
                                      if (!_isError)
                                        Align(
                                          alignment: Alignment.topRight,
                                          child: IconButton(
                                            icon: Icon(
                                              Icons.copy,
                                              color: Colors.grey,
                                            ),
                                            onPressed: _copyResponseToClipboard,
                                            tooltip: 'Copiar resultado',
                                          ),
                                        ),
                                      ResponseDisplay(
                                        response:
                                            _response ??
                                            'Erro ao processar o código',
                                        isError: _isError,
                                        isCode: true,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 1,
                                    child: ElevatedButton(
                                      onPressed: _resetResponse,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.grey[800],
                                        padding: EdgeInsets.symmetric(
                                          vertical: 16,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                      ),
                                      child: Text(
                                        'Tentar novamente',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Expanded(
                                    flex: 1,
                                    child: ElevatedButton(
                                      onPressed: _resetEverything,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Color(0xFF5E60CE),
                                        padding: EdgeInsets.symmetric(
                                          vertical: 16,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                      ),
                                      child: Text(
                                        'Novo código',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
