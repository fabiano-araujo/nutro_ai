import 'package:flutter/material.dart';
import 'dart:async';
import '../i18n/app_localizations_extension.dart';
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
  bool _didInitializeEditor = false;

  // Configurações do editor
  bool _showWordCount = true;
  bool _showCharacterCount = true;
  bool _showParagraphCount = true;
  bool _enableSpellCheck = true;

  @override
  void initState() {
    super.initState();
    _setupAutoSave();
    _setupTextListeners();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didInitializeEditor) {
      _didInitializeEditor = true;
      _initializeEditor();
    }
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
      _titleController.text = _localizedStoredText(widget.initialEssay!.title);
      _textController.text = _localizedStoredText(widget.initialEssay!.text);
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
            tooltip: context.tr.translate('essay_format_bold'),
            onPressed: () => _insertFormatting('**', '**'),
          ),
          _buildToolbarButton(
            icon: Icons.format_italic,
            tooltip: context.tr.translate('essay_format_italic'),
            onPressed: () => _insertFormatting('*', '*'),
          ),

          const SizedBox(width: 16),

          // Botões de estrutura
          _buildToolbarButton(
            icon: Icons.format_list_bulleted,
            tooltip: context.tr.translate('essay_format_list'),
            onPressed: () => _insertText('• '),
          ),
          _buildToolbarButton(
            icon: Icons.format_quote,
            tooltip: context.tr.translate('essay_format_quote'),
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
                  context.tr.translate('essay_unsaved_status'),
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
                  context.tr.translate('essay_saved_status'),
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
              hintText: context.tr.translate('essay_editor_title_hint'),
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
                hintText: context.tr.translate('essay_editor_text_hint'),
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

  Widget _buildTemplateInfo(
      EssayTemplate template, ThemeData theme, bool isDarkMode) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.primaryColor.withValues(alpha: 0.3),
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
                _translateWithValues(
                  'essay_template_name',
                  {'name': _localizedStoredText(template.name)},
                ),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: theme.primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _localizedStoredText(template.description),
            style: TextStyle(fontSize: 14),
          ),
          if (template.minWords > 0 || template.maxWords > 0)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _translateWithValues(
                  'essay_recommended_word_range',
                  {
                    'min': template.minWords.toString(),
                    'max': template.maxWords.toString(),
                  },
                ),
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
            _buildCounter(
              context.tr.translate(
                _wordCount == 1
                    ? 'essay_word_label_one'
                    : 'essay_word_label_other',
              ),
              _wordCount,
              _getWordCountColor(),
            ),

          if (_showWordCount && (_showCharacterCount || _showParagraphCount))
            _buildDivider(),

          if (_showCharacterCount)
            _buildCounter(
              context.tr.translate(
                _characterCount == 1
                    ? 'essay_character_label_one'
                    : 'essay_character_label_other',
              ),
              _characterCount,
              Colors.grey,
            ),

          if (_showCharacterCount && _showParagraphCount) _buildDivider(),

          if (_showParagraphCount)
            _buildCounter(
              context.tr.translate(
                _paragraphCount == 1
                    ? 'essay_paragraph_label_one'
                    : 'essay_paragraph_label_other',
              ),
              _paragraphCount,
              Colors.grey,
            ),

          const Spacer(),

          // Botões de ação
          Row(
            children: [
              TextButton(
                onPressed: _saveEssay,
                child: Text(context.tr.translate('essay_save_action')),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _canSubmit() ? _submitEssay : null,
                child: Text(
                  context.tr.translate('essay_submit_for_correction_action'),
                ),
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
          offset: selection.start +
              startTag.length +
              selectedText.length +
              endTag.length,
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

  String _localizedStoredText(String value) {
    const prefix = 'i18n:';
    return value.startsWith(prefix)
        ? context.tr.translate(value.substring(prefix.length))
        : value;
  }

  String _translateWithValues(String key, Map<String, String> values) {
    var result = context.tr.translate(key);
    for (final entry in values.entries) {
      result = result.replaceAll('{${entry.key}}', entry.value);
    }
    return result;
  }
}
