import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
import '../i18n/app_localizations_extension.dart';
import '../services/ai_service.dart';
// import '../widgets/animated_gradient_background.dart';
// import '../widgets/custom_expandable_panel.dart';
import '../widgets/streaming_response_display.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../i18n/language_controller.dart';
import 'package:provider/provider.dart';
import '../screens/ai_tutor_screen.dart';
import 'dart:convert';

enum ParameterType {
  dropdown,
  toggle,
  slider,
}

class ParameterOption {
  final String id;
  final String translationKey;

  ParameterOption({required this.id, required this.translationKey});
}

class ToolParameter {
  final String id;
  final String translationKey;
  final ParameterType type;
  final List<ParameterOption>? options;
  final double? minValue;
  final double? maxValue;
  final double? defaultValue;
  final bool? defaultToggle;
  final String? defaultDropdown;

  ToolParameter({
    required this.id,
    required this.translationKey,
    required this.type,
    this.options,
    this.minValue,
    this.maxValue,
    this.defaultValue,
    this.defaultToggle,
    this.defaultDropdown,
  });
}

class ToolTab {
  final String id;
  final String translationKey;
  final IconData icon;
  final List<ToolParameter> parameters;
  final String promptTemplate;

  ToolTab({
    required this.id,
    required this.translationKey,
    required this.icon,
    required this.parameters,
    required this.promptTemplate,
  });
}

class ToolConfig {
  final String titleTranslationKey;
  final List<ToolTab> tabs;

  ToolConfig({
    required this.titleTranslationKey,
    required this.tabs,
  });
}

// Classe para armazenar informações do arquivo selecionado
class FileResult {
  final String fileName;
  final String content;

  FileResult(this.fileName, this.content);
}

class GenericAIScreen extends StatefulWidget {
  final ToolConfig config;

  const GenericAIScreen({
    Key? key,
    required this.config,
  }) : super(key: key);

  @override
  _GenericAIScreenState createState() => _GenericAIScreenState();
}

class _GenericAIScreenState extends State<GenericAIScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _textController = TextEditingController();
  final Map<String, dynamic> _paramValues = {};
  bool _isProcessing = false;
  String _responseText = '';
  final int _maxCharacters = 2000;
  String? _selectedImagePath;
  String? _selectedFileName;

  final AIService _aiService = AIService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: widget.config.tabs.length,
      vsync: this,
    );
    _tabController.addListener(_handleTabChange);
    _initializeParameters();
  }

  void _initializeParameters() {
    for (var tab in widget.config.tabs) {
      for (var param in tab.parameters) {
        switch (param.type) {
          case ParameterType.dropdown:
            _paramValues['${tab.id}_${param.id}'] = param.defaultDropdown ??
                (param.options != null && param.options!.isNotEmpty
                    ? param.options![0].id
                    : '');
            break;
          case ParameterType.toggle:
            _paramValues['${tab.id}_${param.id}'] =
                param.defaultToggle ?? false;
            break;
          case ParameterType.slider:
            _paramValues['${tab.id}_${param.id}'] =
                param.defaultValue ?? (param.minValue ?? 0.0);
            break;
        }
      }
    }
  }

  void _handleTabChange() {
    setState(() {
      _responseText = '';
    });
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    _textController.dispose();
    super.dispose();
  }

  ToolTab get _currentTab => widget.config.tabs[_tabController.index];

  Future<void> _processText() async {
    if (_textController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr.translate('enter_text_prompt')),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Theme.of(context).colorScheme.error,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    // Construir o prompt antes de navegar
    final prompt = _buildPrompt();

    // Navegue para a tela AITutorScreen e passe o prompt
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => AITutorScreen(initialPrompt: prompt),
      ),
    );
  }

  String _buildPrompt() {
    String prompt = _currentTab.promptTemplate;
    String userInput = _textController.text.trim();

    // Mapeamento para armazenar os parâmetros avançados selecionados
    Map<String, String> advancedParams = {};

    final paramRegex = RegExp(r'\{([^{}]+)\}');
    prompt = prompt.replaceAllMapped(paramRegex, (match) {
      final paramId = match.group(1)!;
      if (paramId == 'input_text') {
        String textInput = userInput;

        // Adicionar referência à imagem se houver uma selecionada
        if (_selectedImagePath != null) {
          String imageName = _selectedImagePath!.split('/').last;
          textInput += "\n[${context.tr.translate('image')}: $imageName]";
        }

        // Adicionar referência ao arquivo se houver um selecionado
        if (_selectedFileName != null) {
          textInput +=
              "\n[${context.tr.translate('file')}: $_selectedFileName]";
        }

        return textInput;
      } else if (_paramValues.containsKey('${_currentTab.id}_$paramId')) {
        // Capturar parâmetros avançados para enviar como metadados
        final value = _paramValues['${_currentTab.id}_$paramId'];
        String stringValue;
        if (value is bool) {
          stringValue = value ? 'true' : 'false';
        } else {
          stringValue = value.toString();
        }

        // Armazenar o parâmetro traduzido e seu valor
        String paramName = context.tr.translate(paramId) ?? paramId;

        // Para valores de dropdown, traduzir o valor selecionado
        if (value is String) {
          // Procurar o parâmetro na lista de parâmetros da aba atual
          for (var param in _currentTab.parameters) {
            if (param.id == paramId && param.type == ParameterType.dropdown) {
              // Procurar a opção correspondente
              for (var option in param.options ?? []) {
                if (option.id == value) {
                  String translatedValue =
                      context.tr.translate(option.translationKey) ?? value;
                  advancedParams[paramName] = translatedValue;
                  break;
                }
              }
              break;
            }
          }
        } else {
          advancedParams[paramName] = stringValue;
        }

        return stringValue;
      } else {
        // Tentar traduzir a tag que não está associada a um parâmetro
        return context.tr.translate(paramId);
      }
    });

    // Criar um objeto com os dados originais e processados
    Map<String, dynamic> promptData = {
      'userInput': userInput,
      'fullPrompt': prompt,
      'toolName': context.tr.translate(widget.config.titleTranslationKey),
      'toolTab': context.tr.translate(_currentTab.translationKey),
      'advancedParams': advancedParams,
    };

    return jsonEncode(promptData);
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          context.tr.translate(widget.config.titleTranslationKey),
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: colorScheme.primary,
          unselectedLabelColor:
              isDarkMode ? Colors.grey[400] : Colors.grey[600],
          indicatorColor: colorScheme.primary,
          indicatorWeight: 3,
          dividerColor: Colors.transparent,
          tabs: widget.config.tabs.map((tab) {
            return Tab(
              icon: Icon(tab.icon, size: 20),
              text: context.tr.translate(tab.translationKey),
              height: 46,
            );
          }).toList(),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: BouncingScrollPhysics(),
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Campo de entrada de texto
                    _buildTextInput(context),

                    SizedBox(height: 12),

                    // Parâmetros avançados (sempre visíveis)
                    _buildParametersSection(context),

                    SizedBox(height: 16),

                    // Botão de processamento
                    _buildProcessButton(context),

                    // Resposta da IA
                    if (_responseText.isNotEmpty || _isProcessing) ...[
                      SizedBox(height: 24),
                      StreamingResponseDisplay(
                        response: _responseText,
                        isLoading: _isProcessing,
                        titleKey: 'result',
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextInput(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDarkMode ? Color(0xFF1E1D23) : Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              context.tr.translate('input_text'),
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
              ),
              child: TextField(
                controller: _textController,
                decoration: InputDecoration(
                  contentPadding: EdgeInsets.zero,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  hintText: context.tr.translate('type_your_text_here'),
                  hintStyle: TextStyle(
                    color: isDarkMode ? Colors.grey[500] : Colors.grey[400],
                  ),
                  filled: false,
                ),
                style: TextStyle(
                  fontSize: 15,
                ),
                minLines: 4,
                maxLines: 6,
                onChanged: (text) {
                  if (_responseText.isNotEmpty) {
                    setState(() {
                      _responseText = '';
                    });
                  }
                },
              ),
            ),
          ),
          // Exibir a miniatura da imagem se uma imagem for selecionada
          if (_selectedImagePath != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Container(
                    height: 60,
                    width: 60,
                    decoration: BoxDecoration(
                      border: Border.all(color: Theme.of(context).dividerColor),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        File(_selectedImagePath!),
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            Icon(Icons.broken_image, color: Colors.grey),
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedImagePath!.split('/').last,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 4),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedImagePath = null;
                            });
                          },
                          child: Text(
                            context.tr.translate('remove'),
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          // Exibir informações do arquivo de texto se um arquivo for selecionado
          if (_selectedFileName != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Container(
                    height: 60,
                    width: 60,
                    decoration: BoxDecoration(
                      border: Border.all(color: Theme.of(context).dividerColor),
                      borderRadius: BorderRadius.circular(8),
                      color: isDarkMode ? Color(0xFF15141A) : Colors.grey[100],
                    ),
                    child: Center(
                      child: Icon(
                        Icons.description,
                        color: Theme.of(context).colorScheme.primary,
                        size: 32,
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedFileName!,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 4),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedFileName = null;
                            });
                          },
                          child: Text(
                            context.tr.translate('remove'),
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Divider(
              height: 1,
              thickness: 0.5,
              color: Theme.of(context).dividerColor.withOpacity(0.5),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    IconButton.outlined(
                      icon: Icon(Icons.upload_file, size: 18),
                      onPressed: () => _uploadTextFile(context),
                      tooltip: context.tr.translate('upload_file'),
                      style: IconButton.styleFrom(
                        minimumSize: Size(32, 32),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                    SizedBox(width: 8),
                    IconButton.outlined(
                      icon: Icon(Icons.image, size: 18),
                      onPressed: () => _showImageSourceOptions(context),
                      tooltip: context.tr.translate('add_image'),
                      style: IconButton.styleFrom(
                        minimumSize: Size(32, 32),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ),
                Text(
                  '${_textController.text.length} / $_maxCharacters',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showImageSourceOptions(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor:
          isDarkMode ? Color(0xFF1E1D23) : Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: Icon(
                    Icons.camera_alt,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  title: Text(context.tr.translate('camera')),
                  onTap: () {
                    Navigator.pop(context);
                    _getImage(ImageSource.camera);
                  },
                ),
                ListTile(
                  leading: Icon(
                    Icons.photo_library,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  title: Text(context.tr.translate('gallery')),
                  onTap: () {
                    Navigator.pop(context);
                    _getImage(ImageSource.gallery);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _getImage(ImageSource source) async {
    try {
      final ImagePicker _picker = ImagePicker();
      final XFile? image = await _picker.pickImage(source: source);

      if (image != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr.translate('image_selected')),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.green,
          ),
        );

        setState(() {
          _selectedImagePath = image.path;
          _responseText = '';
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr.translate('image_selection_error')),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Future<void> _uploadTextFile(BuildContext context) async {
    try {
      final result = await _pickAndReadTextFile();
      if (result != null && result.content.isNotEmpty) {
        setState(() {
          _textController.text = result.content;
          _selectedFileName = result.fileName;
          _responseText = '';
          _selectedImagePath = null;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr.translate('file_loaded_successfully')),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr.translate('file_upload_error')),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Future<FileResult?> _pickAndReadTextFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['txt', 'md', 'rtf', 'doc', 'docx', 'pdf'],
      );

      if (result != null) {
        File file = File(result.files.single.path!);
        if (file.existsSync()) {
          String content = await file.readAsString();
          if (content.length > _maxCharacters) {
            content = content.substring(0, _maxCharacters);
          }
          return FileResult(result.files.single.name, content);
        }
      }
      return null;
    } catch (e) {
      print('Error reading file: $e');
      return null;
    }
  }

  Widget _buildParametersSection(BuildContext context) {
    // Não exibir opções avançadas se for o Aprimorador de Código
    if (widget.config.titleTranslationKey == 'code_enhancer') {
      return SizedBox.shrink();
    }
    if (_currentTab.parameters.isEmpty) {
      return SizedBox.shrink();
    }

    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: isDarkMode ? Color(0xFF1E1D23) : Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: Theme.of(context).dividerColor,
          width: 0.5,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr.translate('advanced_options'),
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            SizedBox(height: 12),
            ..._currentTab.parameters
                .map((param) => _buildParameter(context, param))
                .toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildParameter(BuildContext context, ToolParameter param) {
    final paramId = '${_currentTab.id}_${param.id}';

    switch (param.type) {
      case ParameterType.dropdown:
        return _buildDropdownParameter(context, param, paramId);
      case ParameterType.toggle:
        return _buildToggleParameter(context, param, paramId);
      case ParameterType.slider:
        return _buildSliderParameter(context, param, paramId);
    }
  }

  Widget _buildDropdownParameter(
      BuildContext context, ToolParameter param, String paramId) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final options = param.options ?? [];

    if (options.isEmpty) return SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr.translate(param.translationKey),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 6),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: isDarkMode
                  ? Color(0xFF15141A)
                  : Theme.of(context).scaffoldBackgroundColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Theme.of(context).dividerColor,
                width: 0.5,
              ),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _paramValues[paramId],
                isExpanded: true,
                icon: Icon(Icons.arrow_drop_down),
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).textTheme.bodyMedium?.color,
                ),
                dropdownColor: Theme.of(context).cardColor,
                items: options.map((option) {
                  return DropdownMenuItem<String>(
                    value: option.id,
                    child: Text(
                      context.tr.translate(option.translationKey),
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _paramValues[paramId] = value;
                      _responseText = '';
                    });
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleParameter(
      BuildContext context, ToolParameter param, String paramId) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            context.tr.translate(param.translationKey),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          Switch(
            value: _paramValues[paramId] ?? false,
            activeColor: Theme.of(context).colorScheme.primary,
            onChanged: (value) {
              setState(() {
                _paramValues[paramId] = value;
                _responseText = '';
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSliderParameter(
      BuildContext context, ToolParameter param, String paramId) {
    final minValue = param.minValue ?? 0.0;
    final maxValue = param.maxValue ?? 100.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                context.tr.translate(param.translationKey),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                _paramValues[paramId].toStringAsFixed(0),
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
          SizedBox(height: 4),
          Slider(
            value: _paramValues[paramId],
            min: minValue,
            max: maxValue,
            divisions: (maxValue - minValue).toInt(),
            activeColor: Theme.of(context).colorScheme.primary,
            onChanged: (value) {
              setState(() {
                _paramValues[paramId] = value;
                _responseText = '';
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildProcessButton(BuildContext context) {
    return ElevatedButton(
      onPressed: _isProcessing ? null : _processText,
      style: ElevatedButton.styleFrom(
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        padding: EdgeInsets.symmetric(vertical: 12),
        elevation: 0,
        minimumSize: Size(double.infinity, 44),
      ),
      child: _isProcessing
          ? Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    color: Theme.of(context).colorScheme.onPrimary,
                    strokeWidth: 2,
                  ),
                ),
                SizedBox(width: 10),
                Text(
                  context.tr.translate('processing'),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            )
          : Text(
              context.tr.translate('process'),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
    );
  }
}
