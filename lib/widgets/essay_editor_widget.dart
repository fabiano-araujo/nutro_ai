import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import '../models/essay_model.dart';
import '../models/essay_template_model.dart';

/// Widget de editor aprimorado para redações
class EssayEditorWidget extends StatefulWidget {
  final Essay? initialEssay;
  final EssayTemplate? template;
  final Function(Essay) onSave;
  final Function(Essay) onSubmit;
  final Function(String)? onTextChanged;
  final bool autoSave;
  final Duration autoSaveInterval;

  const EssayEditorWidget({
    Key? key,
    this.initialEssay,
    this.template,
    required this.onSave,
    required this.onSubmit,
    this.onTextChanged,
    this.autoSave = true,
    this.autoSaveInterval = const Duration(seconds: 30),
  }) : super(key: key);

  @override
  _EssayEditorWidgetState createState() => _EssayEditorWidgetState();
}

class _EssayEditorWidgetState extends State<EssayEditorWidget> {
  final _titleController = TextEditingController();
  final _textController = TextEditingController();
  final _titleFocusNode = FocusNode();
  final _textFocusNode = FocusNode();
  
  Timer? _autoSaveTimer;
  Timer? _debounceTimer;
  
  int _wordCount = 0;
  int _characterCount = 0;
  int _paragraphCount = 0;
  bool _hasUnsavedChanges = false;
  
  // Configurações do editor
  bool _showWordCount = true;
  bool _showCharacterCount = true;
  bool _showParagraphCount = true;
  bool _enableSpellCheck = true;
  
  @override
  void initState() {
    super.initState();
    _initializeEditor();
    _setupAutoSave();
    _setupTextListeners();
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    _debounceTimer?.cancel();
    _titleController.dispose();
    _textController.dispose();
    _titleFocusNode.dispose();
    _textFocusNode.dispose();
    super.dispose();
  }

  void _initializeEditor() {
    if (widget.initialEssay != null) {
      _titleController.text = widget.initialEssay!.title;
      _textController.text = widget.initialEssay!.text;
      _updateCounts();
    }
  }

  void _setupAutoSave() {
    if (widget.autoSave) {
      _autoSaveTimer = Timer.periodic(widget.autoSaveInterval, (_) {
        if (_hasUnsavedChanges) {
          _saveEssay();
        }
      });
    }
  }

  void _setupTextListeners() {
    _titleController.addListener(_onTextChanged);
    _textController.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    setState(() {
      _hasUnsavedChanges = true;
    });
    
    _updateCounts();
    
    // Debounce para evitar muitas chamadas
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (widget.onTextChanged != null) {
        widget.onTextChanged!(_textController.text);
      }
    });
  }

  void _updateCounts() {
    final text = _textController.text;
    setState(() {
      _wordCount = _countWords(text);
      _characterCount = text.length;
      _paragraphCount = _countParagraphs(text);
    });
  }

  int _countWords(String text) {
    if (text.trim().isEmpty) return 0;
    return text.trim().split(RegExp(r'\s+')).length;
  }

  int _countParagraphs(String text) {
    if (text.trim().isEmpty) return 0;
    return text.split('\n').where((line) => line.trim().isNotEmpty).length;
  }

  void _saveEssay() {
    final essay = _createEssayFromInput();
    widget.onSave(essay);
    setState(() {
      _hasUnsavedChanges = false;
    });
  }

  void _submitEssay() {
    final essay = _createEssayFromInput();
    widget.onSubmit(essay);
    setState(() {
      _hasUnsavedChanges = false;
    });
  }

  Essay _createEssayFromInput() {
    if (widget.initialEssay != null) {
      return widget.initialEssay!.copyWith(
        title: _titleController.text,
        text: _textController.text,
        updatedAt: DateTime.now(),
      );
    } else {
      return Essay(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: _titleController.text,
        text: _textController.text,
        type: widget.template?.type ?? 'Livre',
        date: DateTime.now(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    
    return Column(
      children: [
        // Barra de ferramentas
        _buildToolbar(theme, isDarkMode),
        
        // Editor principal
        Expanded(
          child: _buildEditor(theme, isDarkMode),
        ),
        
        // Barra de status
        _buildStatusBar(theme, isDarkMode),
      ],
    );
  }

  Widget _buildToolbar(ThemeData theme, bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey[850] : Colors.grey[100],
        border: Border(
          bottom: BorderSide(
            color: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
          ),
        ),
      ),
      child: Row(
        children: [
          // Botões de formatação
          _buildToolbarButton(
            icon: Icons.format_bold,
            tooltip: 'Negrito',
            onPressed: () => _insertFormatting('**', '**'),
          ),
          _buildToolbarButton(
            icon: Icons.format_italic,
            tooltip: 'Itálico',
            onPressed: () => _insertFormatting('*', '*'),
          ),
          
          const SizedBox(width: 16),
          
          // Botões de estrutura
          _buildToolbarButton(
            icon: Icons.format_list_bulleted,
            tooltip: 'Lista',
            onPressed: () => _insertText('• '),
          ),
          _buildToolbarButton(
            icon: Icons.format_quote,
            tooltip: 'Citação',
            onPressed: () => _insertText('"'),
          ),
          
          const Spacer(),
          
          // Indicador de auto-save
          if (_hasUnsavedChanges)
            Row(
              children: [
                Icon(
                  Icons.circle,
                  size: 8,
                  color: Colors.orange,
                ),
                const SizedBox(width: 4),
                Text(
                  'Não salvo',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.orange,
                  ),
                ),
              ],
            )
          else
            Row(
              children: [
                Icon(
                  Icons.check_circle,
                  size: 16,
                  color: Colors.green,
                ),
                const SizedBox(width: 4),
                Text(
                  'Salvo',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildToolbarButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        icon: Icon(icon, size: 20),
        onPressed: onPressed,
        padding: const EdgeInsets.all(8),
        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      ),
    );
  }

  Widget _buildEditor(ThemeData theme, bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Campo de título
          TextField(
            controller: _titleController,
            focusNode: _titleFocusNode,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
            decoration: InputDecoration(
              hintText: 'Título da redação...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              filled: true,
              fillColor: isDarkMode ? Colors.grey[800] : Colors.grey[50],
            ),
            textInputAction: TextInputAction.next,
            onSubmitted: (_) => _textFocusNode.requestFocus(),
          ),
          
          const SizedBox(height: 16),
          
          // Template info (se disponível)
          if (widget.template != null)
            _buildTemplateInfo(widget.template!, theme, isDarkMode),
          
          // Campo de texto principal
          Expanded(
            child: TextField(
              controller: _textController,
              focusNode: _textFocusNode,
              maxLines: null,
              expands: true,
              style: TextStyle(
                fontSize: 16,
                height: 1.6,
              ),
              decoration: InputDecoration(
                hintText: 'Escreva sua redação aqui...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: isDarkMode ? Colors.grey[800] : Colors.grey[50],
                contentPadding: const EdgeInsets.all(16),
              ),
              textAlignVertical: TextAlignVertical.top,
              enableSuggestions: _enableSpellCheck,
              autocorrect: _enableSpellCheck,
              keyboardType: TextInputType.multiline,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTemplateInfo(EssayTemplate template, ThemeData theme, bool isDarkMode) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.primaryColor.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 16,
                color: theme.primaryColor,
              ),
              const SizedBox(width: 8),
              Text(
                'Template: ${template.name}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: theme.primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            template.description,
            style: TextStyle(fontSize: 14),
          ),
          if (template.minWords > 0 || template.maxWords > 0)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Palavras recomendadas: ${template.minWords} - ${template.maxWords}',
                style: TextStyle(
                  fontSize: 12,
                  color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusBar(ThemeData theme, bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey[850] : Colors.grey[100],
        border: Border(
          top: BorderSide(
            color: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
          ),
        ),
      ),
      child: Row(
        children: [
          // Contadores
          if (_showWordCount)
            _buildCounter('Palavras', _wordCount, _getWordCountColor()),
          
          if (_showWordCount && (_showCharacterCount || _showParagraphCount))
            _buildDivider(),
          
          if (_showCharacterCount)
            _buildCounter('Caracteres', _characterCount, Colors.grey),
          
          if (_showCharacterCount && _showParagraphCount)
            _buildDivider(),
          
          if (_showParagraphCount)
            _buildCounter('Parágrafos', _paragraphCount, Colors.grey),
          
          const Spacer(),
          
          // Botões de ação
          Row(
            children: [
              TextButton(
                onPressed: _saveEssay,
                child: Text('Salvar'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _canSubmit() ? _submitEssay : null,
                child: Text('Enviar para Correção'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCounter(String label, int count, Color color) {
    return Row(
      children: [
        Text(
          '$count',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      height: 16,
      width: 1,
      color: Colors.grey,
    );
  }

  Color _getWordCountColor() {
    if (widget.template != null) {
      final template = widget.template!;
      if (template.minWords > 0 && _wordCount < template.minWords) {
        return Colors.orange;
      }
      if (template.maxWords > 0 && _wordCount > template.maxWords) {
        return Colors.red;
      }
      if (_wordCount >= template.minWords && _wordCount <= template.maxWords) {
        return Colors.green;
      }
    }
    return Colors.grey;
  }

  bool _canSubmit() {
    return _titleController.text.trim().isNotEmpty &&
           _textController.text.trim().isNotEmpty &&
           _wordCount >= 50; // Mínimo de 50 palavras
  }

  void _insertFormatting(String startTag, String endTag) {
    final text = _textController.text;
    final selection = _textController.selection;
    
    if (selection.isValid) {
      final selectedText = text.substring(selection.start, selection.end);
      final newText = text.replaceRange(
        selection.start,
        selection.end,
        '$startTag$selectedText$endTag',
      );
      
      _textController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(
          offset: selection.start + startTag.length + selectedText.length + endTag.length,
        ),
      );
    }
  }

  void _insertText(String textToInsert) {
    final text = _textController.text;
    final selection = _textController.selection;
    
    final newText = text.replaceRange(
      selection.start,
      selection.end,
      textToInsert,
    );
    
    _textController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(
        offset: selection.start + textToInsert.length,
      ),
    );
  }
}