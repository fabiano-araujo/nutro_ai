import 'package:flutter/material.dart';
import '../models/essay_correction_model.dart';

class EssayComparisonWidget extends StatefulWidget {
  final String originalText;
  final List<EssaySuggestion> suggestions;
  final bool showSideBySide;

  const EssayComparisonWidget({
    Key? key,
    required this.originalText,
    required this.suggestions,
    this.showSideBySide = true,
  }) : super(key: key);

  @override
  State<EssayComparisonWidget> createState() => _EssayComparisonWidgetState();
}

class _EssayComparisonWidgetState extends State<EssayComparisonWidget>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _getTextWithSuggestions() {
    String modifiedText = widget.originalText;
    List<EssaySuggestion> sortedSuggestions = List.from(widget.suggestions);
    
    // Sort suggestions by position (descending) to avoid position shifts
    sortedSuggestions.sort((a, b) => b.startPosition.compareTo(a.startPosition));
    
    for (EssaySuggestion suggestion in sortedSuggestions) {
      if (suggestion.startPosition < modifiedText.length && 
          suggestion.endPosition <= modifiedText.length) {
        modifiedText = modifiedText.replaceRange(
          suggestion.startPosition,
          suggestion.endPosition,
          suggestion.suggestedText,
        );
      }
    }
    
    return modifiedText;
  }

  List<TextSpan> _buildHighlightedText(String text, bool isOriginal) {
    List<TextSpan> spans = [];
    int currentIndex = 0;
    
    // Sort suggestions by start position
    List<EssaySuggestion> sortedSuggestions = List.from(widget.suggestions);
    sortedSuggestions.sort((a, b) => a.startPosition.compareTo(b.startPosition));
    
    for (int i = 0; i < sortedSuggestions.length; i++) {
      EssaySuggestion suggestion = sortedSuggestions[i];
      
      if (suggestion.startPosition > currentIndex) {
        // Add normal text before suggestion
        spans.add(TextSpan(
          text: text.substring(currentIndex, suggestion.startPosition),
          style: const TextStyle(fontSize: 14, height: 1.5),
        ));
      }
      
      if (suggestion.startPosition < text.length && 
          suggestion.endPosition <= text.length) {
        // Add highlighted suggestion
        Color highlightColor = _getSuggestionColor(suggestion.priority);
        String highlightedText = isOriginal 
            ? suggestion.originalText 
            : suggestion.suggestedText;
            
        spans.add(TextSpan(
          text: highlightedText,
          style: TextStyle(
            fontSize: 14,
            height: 1.5,
            backgroundColor: highlightColor.withValues(alpha: 0.3),
            color: highlightColor.withValues(alpha: 0.8),
            fontWeight: FontWeight.w500,
          ),
          recognizer: null, // Could add tap recognizer for suggestion details
        ));
        
        currentIndex = suggestion.endPosition;
      }
    }
    
    // Add remaining text
    if (currentIndex < text.length) {
      spans.add(TextSpan(
        text: text.substring(currentIndex),
        style: const TextStyle(fontSize: 14, height: 1.5),
      ));
    }
    
    return spans;
  }

  Color _getSuggestionColor(SuggestionPriority priority) {
    switch (priority) {
      case SuggestionPriority.critical:
        return Colors.red;
      case SuggestionPriority.high:
        return Colors.orange;
      case SuggestionPriority.medium:
        return Colors.blue;
      case SuggestionPriority.low:
        return Colors.green;
    }
  }

  IconData _getSuggestionIcon(String type) {
    switch (type) {
      case 'grammar':
        return Icons.spellcheck;
      case 'style':
        return Icons.brush;
      case 'structure':
        return Icons.account_tree;
      case 'content':
        return Icons.article;
      default:
        return Icons.edit;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallDevice = screenWidth < 600;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with suggestion count
        Row(
          children: [
            Icon(Icons.compare_arrows, color: theme.primaryColor),
            const SizedBox(width: 8),
            Text(
              'Comparação com Sugestões',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: theme.primaryColor,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: theme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${widget.suggestions.length} sugestões',
                style: TextStyle(
                  color: theme.primaryColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 16),
        
        // Tab bar for switching between views
        Container(
          decoration: BoxDecoration(
            color: isDarkMode ? Colors.grey[800] : Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: TabBar(
            controller: _tabController,
            indicator: BoxDecoration(
              color: theme.primaryColor,
              borderRadius: BorderRadius.circular(8),
            ),
            labelColor: Colors.white,
            unselectedLabelColor: isDarkMode ? Colors.grey[400] : Colors.grey[600],
            tabs: const [
              Tab(text: 'Texto Original'),
              Tab(text: 'Com Sugestões'),
            ],
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Content area
        if (isSmallDevice || !widget.showSideBySide) ...[
          // Single view for small devices
          SizedBox(
            height: 400,
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildTextView(widget.originalText, true, isDarkMode),
                _buildTextView(_getTextWithSuggestions(), false, isDarkMode),
              ],
            ),
          ),
        ] else ...[
          // Side by side view for larger screens
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Texto Original',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: theme.primaryColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 400,
                      child: _buildTextView(widget.originalText, true, isDarkMode),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Com Sugestões Aplicadas',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: theme.primaryColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 400,
                      child: _buildTextView(_getTextWithSuggestions(), false, isDarkMode),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
        
        const SizedBox(height: 24),
        
        // Suggestions list
        if (widget.suggestions.isNotEmpty) ...[
          Text(
            'Lista de Sugestões',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: theme.primaryColor,
            ),
          ),
          const SizedBox(height: 12),
          ...widget.suggestions.asMap().entries.map((entry) {
            int index = entry.key;
            EssaySuggestion suggestion = entry.value;
            return _buildSuggestionCard(suggestion, index, isDarkMode);
          }).toList(),
        ],
      ],
    );
  }

  Widget _buildTextView(String text, bool isOriginal, bool isDarkMode) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey[800] : Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDarkMode ? Colors.grey[700]! : Colors.grey[200]!,
        ),
      ),
      child: SingleChildScrollView(
        child: RichText(
          text: TextSpan(
            children: widget.suggestions.isNotEmpty 
                ? _buildHighlightedText(text, isOriginal)
                : [TextSpan(
                    text: text,
                    style: const TextStyle(fontSize: 14, height: 1.5),
                  )],
            style: TextStyle(
              color: isDarkMode ? Colors.white : Colors.black,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSuggestionCard(EssaySuggestion suggestion, int index, bool isDarkMode) {
    Color priorityColor = _getSuggestionColor(suggestion.priority);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        leading: Icon(
          _getSuggestionIcon(suggestion.type),
          color: priorityColor,
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                '${suggestion.type.toUpperCase()}: ${suggestion.originalText}',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: priorityColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                suggestion.priority.toString().split('.').last.toUpperCase(),
                style: TextStyle(
                  color: priorityColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Original vs Suggested
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Original:',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.red.withValues(alpha: 0.7),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              suggestion.originalText,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Sugerido:',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.green.withValues(alpha: 0.7),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              suggestion.suggestedText,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 12),
                
                // Explanation
                if (suggestion.explanation.isNotEmpty) ...[
                  Text(
                    'Explicação:',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    suggestion.explanation,
                    style: const TextStyle(fontSize: 13),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}