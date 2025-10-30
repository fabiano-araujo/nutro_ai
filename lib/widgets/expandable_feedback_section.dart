import 'package:flutter/material.dart';
import '../models/essay_correction_model.dart';

class ExpandableFeedbackSection extends StatefulWidget {
  final DetailedFeedback feedback;
  final bool initiallyExpanded;

  const ExpandableFeedbackSection({
    Key? key,
    required this.feedback,
    this.initiallyExpanded = false,
  }) : super(key: key);

  @override
  State<ExpandableFeedbackSection> createState() => _ExpandableFeedbackSectionState();
}

class _ExpandableFeedbackSectionState extends State<ExpandableFeedbackSection>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _expandAnimation;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _expandAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );

    if (_isExpanded) {
      _animationController.value = 1.0;
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  Color _getScoreColor(int score) {
    if (score >= 180) return Colors.green;
    if (score >= 160) return Colors.blue;
    if (score >= 140) return Colors.amber;
    if (score >= 120) return Colors.orange;
    return Colors.red;
  }

  IconData _getCommentIcon(String type) {
    switch (type) {
      case 'positive':
        return Icons.check_circle;
      case 'negative':
        return Icons.error;
      default:
        return Icons.info;
    }
  }

  Color _getCommentColor(String type) {
    switch (type) {
      case 'positive':
        return Colors.green;
      case 'negative':
        return Colors.red;
      default:
        return Colors.blue;
    }
  }

  IconData _getTipIcon(String category) {
    switch (category) {
      case 'grammar':
        return Icons.spellcheck;
      case 'style':
        return Icons.brush;
      case 'structure':
        return Icons.account_tree;
      case 'content':
        return Icons.article;
      default:
        return Icons.lightbulb;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final scoreColor = _getScoreColor(widget.feedback.score);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      child: Column(
        children: [
          // Header with competency name, score, and expand button
          InkWell(
            onTap: _toggleExpanded,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Competency icon and name
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: scoreColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Icon(
                            Icons.assessment,
                            color: scoreColor,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.feedback.competency,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                widget.feedback.summary,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Score display
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: scoreColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      '${widget.feedback.score}/200',
                      style: TextStyle(
                        color: scoreColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  
                  const SizedBox(width: 8),
                  
                  // Expand/collapse icon
                  AnimatedRotation(
                    turns: _isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 300),
                    child: Icon(
                      Icons.keyboard_arrow_down,
                      color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Expandable content
          SizeTransition(
            sizeFactor: _expandAnimation,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(height: 1),
                  const SizedBox(height: 16),
                  
                  // Detailed summary
                  if (widget.feedback.summary.isNotEmpty) ...[
                    Text(
                      'Análise Detalhada',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: theme.primaryColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDarkMode ? Colors.grey[800] : Colors.grey[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        widget.feedback.summary,
                        style: const TextStyle(fontSize: 14, height: 1.4),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  
                  // Comments section
                  if (widget.feedback.comments.isNotEmpty) ...[
                    Text(
                      'Comentários Específicos',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: theme.primaryColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...widget.feedback.comments.map((comment) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            _getCommentIcon(comment.type),
                            size: 16,
                            color: _getCommentColor(comment.type),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              comment.text,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    )).toList(),
                    const SizedBox(height: 16),
                  ],
                  
                  // Tips section
                  if (widget.feedback.tips.isNotEmpty) ...[
                    Text(
                      'Dicas de Melhoria',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: theme.primaryColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...widget.feedback.tips.map((tip) => Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(8),
                        border: Border(
                          left: BorderSide(
                            width: 3,
                            color: Colors.blue.withValues(alpha: 0.3),
                          ),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            _getTipIcon(tip.category),
                            size: 16,
                            color: Colors.blue,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  tip.title,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (tip.description.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    tip.description,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          // Priority indicator
                          if (tip.priority <= 2)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: tip.priority == 1 ? Colors.red : Colors.orange,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                tip.priority == 1 ? 'Alta' : 'Média',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                        ],
                      ),
                    )).toList(),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}