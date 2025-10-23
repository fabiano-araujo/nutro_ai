import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:async';
import '../services/ai_service.dart';
import '../services/storage_service.dart';
import '../models/study_item.dart';
import '../theme/app_theme.dart';
import '../widgets/response_display.dart';
import '../widgets/streaming_response_display.dart';

class DocumentSummaryScreen extends StatefulWidget {
  const DocumentSummaryScreen({Key? key}) : super(key: key);

  @override
  _DocumentSummaryScreenState createState() => _DocumentSummaryScreenState();
}

class _DocumentSummaryScreenState extends State<DocumentSummaryScreen> {
  final AIService _aiService = AIService();
  final StorageService _storageService = StorageService();
  final TextEditingController _textController = TextEditingController();
  String? _currentItemId;

  String _selectedSummaryLength = 'medium';
  String _response = '';
  bool _isLoading = false;
  bool _isError = false;
  String? _fileName;
  StreamSubscription? _aiStreamSubscription;

  final List<Map<String, dynamic>> _summaryLengthOptions = [
    {
      'value': 'short',
      'label': 'Short',
      'icon': Icons.short_text,
      'description': 'Concise 1-2 paragraph summary',
    },
    {
      'value': 'medium',
      'label': 'Medium',
      'icon': Icons.article,
      'description': 'Comprehensive overview with key points',
    },
    {
      'value': 'detailed',
      'label': 'Detailed',
      'icon': Icons.description,
      'description': 'In-depth summary with section breakdowns',
    },
  ];

  @override
  void initState() {
    super.initState();
    _selectedSummaryLength = 'medium';
  }

  @override
  void dispose() {
    _textController.dispose();
    _aiStreamSubscription?.cancel();
    super.dispose();
  }

  Future<void> _pickDocument() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['txt', 'pdf', 'doc', 'docx'],
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;

        // For this demo, we're just going to pretend we extracted the text
        // In a real app, you would use a package to extract text from PDF/DOC
        setState(() {
          _fileName = file.name;
          // Set some placeholder text for demo purposes
          _textController.text =
              'Text content extracted from ${file.name}\n\nLorem ipsum dolor sit amet, consectetur adipiscing elit. Nullam euismod, nisl eget aliquam ultricies, nunc nisl aliquet nunc, quis aliquam nisl nunc quis nisl. Nullam euismod, nisl eget aliquam ultricies, nunc nisl aliquet nunc, quis aliquam nisl nunc quis nisl.';
        });
      }
    } catch (e) {
      _showErrorSnackBar('Error picking file: $e');
    }
  }

  Future<void> _summarizeDocument() async {
    if (_textController.text.isEmpty) {
      _showErrorSnackBar('Please enter text or upload a document to summarize');
      return;
    }

    setState(() {
      _isLoading = true;
      _isError = false;
      _response = ''; // Limpa resposta anterior
    });

    try {
      // Usar a versão de streaming
      _aiStreamSubscription = _aiService
          .summarizeDocumentStream(
        _textController.text,
        summaryLength: _selectedSummaryLength,
      )
          .listen(
        (chunk) {
          if (mounted) {
            setState(() {
              _response += chunk;
            });
          }
        },
        onDone: () async {
          if (mounted) {
            setState(() {
              _isLoading = false;
            });

            // Salvar no histórico
            final studyItem = StudyItem(
              id: _currentItemId,
              title:
                  'Document Summary${_fileName != null ? ': $_fileName' : ''}',
              content: _textController.text,
              response: _response,
              type: 'summary',
            );

            await _storageService.saveToHistory(studyItem);

            // Guardar o ID para a próxima vez
            if (_currentItemId == null) {
              _currentItemId = studyItem.id;
            }
          }
        },
        onError: (error) {
          if (mounted) {
            setState(() {
              _isLoading = false;
              _isError = true;
            });
            _showErrorSnackBar('Error summarizing document: $error');
          }
        },
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
        _isError = true;
      });
      _showErrorSnackBar('Error summarizing document: $e');
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
        title: Text('Document Summarization'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.paste),
            onPressed: () async {
              final data = await Clipboard.getData(Clipboard.kTextPlain);
              if (data != null && data.text != null && data.text!.isNotEmpty) {
                _textController.text = data.text!;
                setState(() {
                  _fileName = null;
                });
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
                _buildUploadSection(isDarkMode),

                SizedBox(height: 24),

                Text(
                  'Document Text',
                  style: AppTheme.headingSmall,
                ),
                SizedBox(height: 8),
                TextField(
                  controller: _textController,
                  decoration: InputDecoration(
                    hintText: 'Enter text to summarize or upload a document...',
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor:
                        isDarkMode ? AppTheme.darkComponentColor : Colors.white,
                  ),
                  maxLines: 10,
                  style: TextStyle(
                    color: isDarkMode
                        ? AppTheme.darkTextColor
                        : AppTheme.textPrimaryColor,
                  ),
                ),

                SizedBox(height: 24),

                Text(
                  'Summary Length',
                  style: AppTheme.headingSmall,
                ),
                SizedBox(height: 8),
                _buildSummaryLengthOptions(isDarkMode),

                SizedBox(height: 24),

                // Summarize button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _textController.text.isNotEmpty && !_isLoading
                        ? _summarizeDocument
                        : null,
                    icon: Icon(Icons.auto_awesome),
                    label: Text('Summarize Document'),
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
                  'Summary',
                  style: AppTheme.headingSmall,
                ),
                SizedBox(height: 8),
                // Usando o novo widget de streaming
                StreamingResponseDisplay(
                  response: _response,
                  isLoading: _isLoading,
                  isError: _isError,
                  titleKey: 'summary_result',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUploadSection(bool isDarkMode) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? AppTheme.darkComponentColor : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDarkMode ? AppTheme.darkBorderColor : Colors.grey[300]!,
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                Icons.upload_file,
                color: AppTheme.primaryColor,
                size: 24,
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Upload Document',
                      style: AppTheme.bodyMedium.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isDarkMode
                            ? AppTheme.darkTextColor
                            : AppTheme.textPrimaryColor,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Supported formats: TXT, PDF, DOC, DOCX',
                      style: AppTheme.captionText.copyWith(
                        color: isDarkMode
                            ? AppTheme.darkTextColor.withOpacity(0.7)
                            : AppTheme.textSecondaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          _fileName != null
              ? Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDarkMode ? Color(0xFF303030) : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isDarkMode
                          ? AppTheme.darkBorderColor
                          : Colors.grey[300]!,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.description,
                        size: 20,
                        color: AppTheme.infoColor,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _fileName!,
                          style: AppTheme.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close, size: 16),
                        onPressed: () {
                          setState(() {
                            _fileName = null;
                            _textController.clear();
                          });
                        },
                        padding: EdgeInsets.zero,
                        constraints: BoxConstraints(),
                      ),
                    ],
                  ),
                )
              : OutlinedButton.icon(
                  onPressed: _pickDocument,
                  icon: Icon(Icons.attach_file),
                  label: Text('Choose File'),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildSummaryLengthOptions(bool isDarkMode) {
    return Row(
      children: _summaryLengthOptions.map((option) {
        final isSelected = _selectedSummaryLength == option['value'];

        return Expanded(
          child: GestureDetector(
            onTap: () {
              setState(() {
                _selectedSummaryLength = option['value'];
              });
            },
            child: AnimatedContainer(
              duration: Duration(milliseconds: 200),
              margin: EdgeInsets.symmetric(horizontal: 4),
              padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.primaryColor.withOpacity(isDarkMode ? 0.3 : 0.1)
                    : isDarkMode
                        ? AppTheme.darkComponentColor
                        : Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected
                      ? AppTheme.primaryColor
                      : isDarkMode
                          ? AppTheme.darkBorderColor
                          : Colors.grey[300]!,
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    option['icon'],
                    color: isSelected
                        ? AppTheme.primaryColor
                        : AppTheme.textSecondaryColor,
                  ),
                  SizedBox(height: 4),
                  Text(
                    option['label'],
                    style: AppTheme.bodySmall.copyWith(
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected
                          ? AppTheme.primaryColor
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
      }).toList(),
    );
  }
}
