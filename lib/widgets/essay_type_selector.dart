import 'package:flutter/material.dart';
import '../models/essay_template_model.dart';

/// Widget para seleção de tipo e template de redação
class EssayTypeSelector extends StatefulWidget {
  final String selectedType;
  final EssayTemplate? selectedTemplate;
  final List<EssayTemplate> availableTemplates;
  final Function(String) onTypeChanged;
  final Function(EssayTemplate?) onTemplateChanged;
  final bool showTemplateDetails;

  const EssayTypeSelector({
    Key? key,
    required this.selectedType,
    this.selectedTemplate,
    required this.availableTemplates,
    required this.onTypeChanged,
    required this.onTemplateChanged,
    this.showTemplateDetails = true,
  }) : super(key: key);

  @override
  _EssayTypeSelectorState createState() => _EssayTypeSelectorState();
}

class _EssayTypeSelectorState extends State<EssayTypeSelector> {
  late String _selectedType;
  EssayTemplate? _selectedTemplate;

  @override
  void initState() {
    super.initState();
    _selectedType = widget.selectedType;
    _selectedTemplate = widget.selectedTemplate;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Seleção de tipo
        _buildTypeSelection(theme, isDarkMode),
        
        const SizedBox(height: 16),
        
        // Seleção de template
        if (widget.availableTemplates.isNotEmpty)
          _buildTemplateSelection(theme, isDarkMode),
        
        // Detalhes do template selecionado
        if (widget.showTemplateDetails && _selectedTemplate != null)
          _buildTemplateDetails(_selectedTemplate!, theme, isDarkMode),
      ],
    );
  }

  Widget _buildTypeSelection(ThemeData theme, bool isDarkMode) {
    final types = ['ENEM', 'Vestibular', 'Concurso', 'Livre'];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tipo de Redação',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        
        // Chips para seleção de tipo
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: types.map((type) {
            final isSelected = type == _selectedType;
            return FilterChip(
              label: Text(type),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  setState(() {
                    _selectedType = type;
                    _selectedTemplate = null; // Reset template quando muda tipo
                  });
                  widget.onTypeChanged(type);
                  widget.onTemplateChanged(null);
                }
              },
              selectedColor: theme.primaryColor.withOpacity(0.2),
              checkmarkColor: theme.primaryColor,
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildTemplateSelection(ThemeData theme, bool isDarkMode) {
    final templatesForType = widget.availableTemplates
        .where((template) => template.type == _selectedType)
        .toList();

    if (templatesForType.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Template',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        
        // Lista de templates
        ...templatesForType.map((template) {
          final isSelected = template.id == _selectedTemplate?.id;
          
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            elevation: isSelected ? 4 : 1,
            color: isSelected 
                ? theme.primaryColor.withOpacity(0.1)
                : null,
            child: ListTile(
              leading: Icon(
                _getIconForTemplate(template),
                color: isSelected ? theme.primaryColor : null,
              ),
              title: Text(
                template.name,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? theme.primaryColor : null,
                ),
              ),
              subtitle: Text(
                template.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: isSelected 
                  ? Icon(Icons.check_circle, color: theme.primaryColor)
                  : null,
              onTap: () {
                setState(() {
                  _selectedTemplate = isSelected ? null : template;
                });
                widget.onTemplateChanged(_selectedTemplate);
              },
            ),
          );
        }).toList(),
        
        // Opção "Sem template"
        Card(
          margin: const EdgeInsets.only(bottom: 8),
          elevation: _selectedTemplate == null ? 4 : 1,
          color: _selectedTemplate == null 
              ? theme.primaryColor.withOpacity(0.1)
              : null,
          child: ListTile(
            leading: Icon(
              Icons.edit,
              color: _selectedTemplate == null ? theme.primaryColor : null,
            ),
            title: Text(
              'Formato Livre',
              style: TextStyle(
                fontWeight: _selectedTemplate == null ? FontWeight.bold : FontWeight.normal,
                color: _selectedTemplate == null ? theme.primaryColor : null,
              ),
            ),
            subtitle: Text('Escreva sem seguir um template específico'),
            trailing: _selectedTemplate == null 
                ? Icon(Icons.check_circle, color: theme.primaryColor)
                : null,
            onTap: () {
              setState(() {
                _selectedTemplate = null;
              });
              widget.onTemplateChanged(null);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTemplateDetails(EssayTemplate template, ThemeData theme, bool isDarkMode) {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey[800] : Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.primaryColor.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabeçalho
          Row(
            children: [
              Icon(
                _getIconForTemplate(template),
                color: theme.primaryColor,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  template.name,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: theme.primaryColor,
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Descrição
          Text(
            template.description,
            style: TextStyle(fontSize: 14),
          ),
          
          const SizedBox(height: 16),
          
          // Informações técnicas
          _buildInfoRow('Tempo estimado', '${template.estimatedTime} minutos'),
          if (template.minWords > 0 || template.maxWords > 0)
            _buildInfoRow(
              'Palavras',
              '${template.minWords} - ${template.maxWords}',
            ),
          
          const SizedBox(height: 16),
          
          // Estrutura
          if (template.structure.isNotEmpty) ...[
            Text(
              'Estrutura Sugerida:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDarkMode ? Colors.grey[700] : Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                template.structure,
                style: TextStyle(
                  fontSize: 13,
                  fontFamily: 'monospace',
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          
          // Diretrizes
          if (template.guidelines.isNotEmpty) ...[
            Text(
              'Diretrizes:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            ...template.guidelines.map((guideline) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      size: 16,
                      color: Colors.green,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        guideline,
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(fontSize: 13),
          ),
        ],
      ),
    );
  }

  IconData _getIconForTemplate(EssayTemplate template) {
    switch (template.type.toUpperCase()) {
      case 'ENEM':
        return Icons.school;
      case 'VESTIBULAR':
        return Icons.assignment;
      case 'CONCURSO':
        return Icons.work;
      default:
        return Icons.edit;
    }
  }
}