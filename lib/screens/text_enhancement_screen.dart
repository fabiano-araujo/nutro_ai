import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/ai_service.dart';
import '../services/storage_service.dart';
import '../models/study_item.dart';
import '../theme/app_theme.dart';
import '../widgets/response_display.dart';

class TextEnhancementScreen extends StatefulWidget {
  const TextEnhancementScreen({Key? key}) : super(key: key);

  @override
  _TextEnhancementScreenState createState() => _TextEnhancementScreenState();
}

class _TextEnhancementScreenState extends State<TextEnhancementScreen> {
  final AIService _aiService = AIService();
  final StorageService _storageService = StorageService();
  final TextEditingController _textController = TextEditingController();

  String _selectedEnhancement = 'paraphrase';
  int? _targetWordCount;
  String? _response;
  bool _isLoading = false;
  bool _isError = false;

  final List<Map<String, dynamic>> _enhancementOptions = [
    {
      'value': 'paraphrase',
      'label': 'Paraphrase',
      'icon': Icons.autorenew,
      'description': 'Rewrite the text while keeping the original meaning',
      'color': Color(0xFF4A6FFF),
    },
    {
      'value': 'simplify',
      'label': 'Simplify',
      'icon': Icons.new_releases,
      'description': 'Make the text easier to understand',
      'color': Color(0xFF2DC96B),
    },
    {
      'value': 'expand',
      'label': 'Expand',
      'icon': Icons.add_circle_outline,
      'description': 'Add more details and explanations',
      'color': Color(0xFFFF7A50),
    },
    {
      'value': 'academicTone',
      'label': 'Academic Tone',
      'icon': Icons.school,
      'description': 'Transform into formal academic language',
      'color': Color(0xFF5E60CE),
    },
  ];

  final List<Map<String, dynamic>> _wordCountOptions = [
    {'label': 'Original Length', 'value': null},
    {'label': 'Short (~100 words)', 'value': 100},
    {'label': 'Medium (~250 words)', 'value': 250},
    {'label': 'Long (~500 words)', 'value': 500},
  ];

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _enhanceText() async {
    if (_textController.text.isEmpty) {
      _showErrorSnackBar('Please enter some text to enhance');
      return;
    }

    setState(() {
      _isLoading = true;
      _isError = false;
    });

    try {
      final result = await _aiService.enhanceText(
        _textController.text,
        _selectedEnhancement,
        targetWordCount: _targetWordCount,
      );

      // Save to history
      final studyItem = StudyItem(
        title:
            'Text Enhancement: ${_getEnhancementLabel(_selectedEnhancement)}',
        content: _textController.text,
        response: result,
        type: 'enhancement',
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
      _showErrorSnackBar('Error enhancing text: $e');
    }
  }

  String _getEnhancementLabel(String value) {
    final option = _enhancementOptions.firstWhere(
      (option) => option['value'] == value,
      orElse: () => {'label': 'Unknown'},
    );
    return option['label'] as String;
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
        title: Text('Essay Enhancement'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.paste),
            onPressed: () async {
              final data = await Clipboard.getData(Clipboard.kTextPlain);
              if (data != null && data.text != null && data.text!.isNotEmpty) {
                _textController.text = data.text!;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Text pasted from clipboard')),
                );
              }
            },
            tooltip: 'Paste from clipboard',
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
                Text(
                  'Your Text',
                  style: AppTheme.headingSmall,
                ),
                SizedBox(height: 8),
                TextField(
                  controller: _textController,
                  decoration: InputDecoration(
                    hintText: 'Enter your text here to enhance...',
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor:
                        isDarkMode ? AppTheme.darkComponentColor : Colors.white,
                  ),
                  maxLines: 8,
                  textCapitalization: TextCapitalization.sentences,
                  style: TextStyle(
                    color: isDarkMode
                        ? AppTheme.darkTextColor
                        : AppTheme.textPrimaryColor,
                  ),
                ),

                SizedBox(height: 24),

                Text(
                  'Enhancement Type',
                  style: AppTheme.headingSmall,
                ),
                SizedBox(height: 8),
                _buildEnhancementOptions(isDarkMode),

                SizedBox(height: 16),

                Text(
                  'Target Length',
                  style: AppTheme.headingSmall,
                ),
                SizedBox(height: 8),
                _buildWordCountOptions(isDarkMode),

                SizedBox(height: 24),

                // Enhance button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _textController.text.isNotEmpty && !_isLoading
                        ? _enhanceText
                        : null,
                    icon: Icon(Icons.auto_awesome),
                    label: Text('Enhance Text'),
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
                  'Enhanced Result',
                  style: AppTheme.headingSmall,
                ),
                SizedBox(height: 8),
                ResponseDisplay(
                  response: _response,
                  isLoading: _isLoading,
                  isError: _isError,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEnhancementOptions(bool isDarkMode) {
    return Container(
      height: 140,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _enhancementOptions.length,
        itemBuilder: (context, index) {
          final option = _enhancementOptions[index];
          final isSelected = _selectedEnhancement == option['value'];

          return AnimatedContainer(
            duration: Duration(milliseconds: 200),
            margin: EdgeInsets.only(right: 12),
            width: 140,
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
            child: InkWell(
              onTap: () {
                setState(() {
                  _selectedEnhancement = option['value'];
                });
              },
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color:
                            option['color'].withOpacity(isDarkMode ? 0.2 : 0.1),
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
                    Text(
                      option['description'],
                      style: AppTheme.captionText.copyWith(
                        color: isDarkMode
                            ? AppTheme.darkTextColor.withOpacity(0.7)
                            : AppTheme.textSecondaryColor,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildWordCountOptions(bool isDarkMode) {
    return Wrap(
      spacing: 8.0,
      runSpacing: 8.0,
      children: _wordCountOptions.map((option) {
        final isSelected = _targetWordCount == option['value'];

        return ChoiceChip(
          label: Text(option['label']),
          selected: isSelected,
          onSelected: (selected) {
            setState(() {
              _targetWordCount = selected ? option['value'] : null;
            });
          },
          backgroundColor:
              isDarkMode ? AppTheme.darkComponentColor : Colors.grey[100],
          selectedColor:
              AppTheme.primaryColor.withOpacity(isDarkMode ? 0.3 : 0.2),
          labelStyle: TextStyle(
            color: isSelected
                ? AppTheme.primaryColor
                : isDarkMode
                    ? AppTheme.darkTextColor
                    : AppTheme.textPrimaryColor,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(
              color: isSelected ? AppTheme.primaryColor : Colors.transparent,
              width: 1.5,
            ),
          ),
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        );
      }).toList(),
    );
  }
}
