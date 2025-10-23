import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../i18n/app_localizations_extension.dart';
import '../models/essay_model.dart';
import '../providers/essay_provider.dart';
import 'package:uuid/uuid.dart';

class NewEssayScreen extends StatefulWidget {
  final bool isEditing;
  final String? essayId;

  const NewEssayScreen({
    Key? key,
    this.isEditing = false,
    this.essayId,
  }) : super(key: key);

  @override
  _NewEssayScreenState createState() => _NewEssayScreenState();
}

class _NewEssayScreenState extends State<NewEssayScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _textController = TextEditingController();
  String _selectedType = 'ENEM';
  bool _isSubmitting = false;
  int _wordCount = 0;

  final List<String> _essayTypes = ['ENEM', 'Vestibular', 'Concurso', 'Outro'];

  @override
  void initState() {
    super.initState();

    if (widget.isEditing && widget.essayId != null) {
      Future.microtask(() {
        final essayProvider =
            Provider.of<EssayProvider>(context, listen: false);
        final essay = essayProvider.getEssayById(widget.essayId!);

        if (essay != null) {
          _titleController.text = essay.title;
          _textController.text = essay.text;
          setState(() {
            _selectedType = essay.type;
            _updateWordCount();
          });
        }
      });
    }

    // Adicionar listener para contar palavras quando o texto mudar
    _textController.addListener(_updateWordCount);
  }

  void _updateWordCount() {
    setState(() {
      _wordCount = _textController.text
          .split(RegExp(r'\s+'))
          .where((s) => s.isNotEmpty)
          .length;
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _textController.dispose();
    super.dispose();
  }

  Future<void> _saveEssay() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isSubmitting = true;
      });

      final essayProvider = Provider.of<EssayProvider>(context, listen: false);

      try {
        if (widget.isEditing && widget.essayId != null) {
          // Update existing essay
          final essay = essayProvider.getEssayById(widget.essayId!);
          if (essay != null) {
            final updatedEssay = essay.copyWith(
              title: _titleController.text,
              text: _textController.text,
              type: _selectedType,
            );

            // Adicionar a versão atualizada
            essayProvider.addEssay(updatedEssay);
          }
        } else {
          // Create new essay
          final newEssay = Essay(
            id: const Uuid().v4(),
            title: _titleController.text,
            text: _textController.text,
            type: _selectedType,
            date: DateTime.now(),
            status: 'Rascunho',
          );

          essayProvider.addEssay(newEssay);
        }

        Navigator.pop(context);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar a redação: $e'),
            backgroundColor: Colors.red,
          ),
        );
      } finally {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _submitForCorrection() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isSubmitting = true;
      });

      final essayProvider = Provider.of<EssayProvider>(context, listen: false);

      try {
        String essayId;

        if (widget.isEditing && widget.essayId != null) {
          essayId = widget.essayId!;
          final essay = essayProvider.getEssayById(essayId);
          if (essay != null) {
            final updatedEssay = essay.copyWith(
              title: _titleController.text,
              text: _textController.text,
              type: _selectedType,
            );

            // Adiciona a versão atualizada
            essayProvider.addEssay(updatedEssay);
          }
        } else {
          // Create new essay
          final newEssay = Essay(
            id: const Uuid().v4(),
            title: _titleController.text,
            text: _textController.text,
            type: _selectedType,
            date: DateTime.now(),
            status: 'Rascunho',
          );

          essayProvider.addEssay(newEssay);
          essayId = newEssay.id;
        }

        // Enviar para correção
        essayProvider.submitForCorrection(essayId);

        Navigator.pop(context);

        // Mostrar mensagem de sucesso
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Redação enviada para correção com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao enviar a redação: $e'),
            backgroundColor: Colors.red,
          ),
        );
      } finally {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallDevice = screenWidth < 360;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Editar Redação' : 'Nova Redação'),
        elevation: 0,
        actions: [
          // Botão adaptado para economizar espaço em telas pequenas
          if (!_isSubmitting)
            TextButton.icon(
              onPressed: _submitForCorrection,
              icon: Icon(Icons.send,
                  color: Colors.white, size: isSmallDevice ? 18 : 24),
              label: Text(
                isSmallDevice ? '' : 'Enviar',
                style: TextStyle(color: Colors.white),
              ),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Escreva sua redação ou copie de um documento existente.',
                      style: TextStyle(
                        fontSize: isSmallDevice ? 14 : 16,
                        color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Tipo de redação
                    Text(
                      'Tipo de Redação',
                      style: TextStyle(
                        fontSize: isSmallDevice ? 14 : 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),

                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isDarkMode
                              ? Colors.grey[700]!
                              : Colors.grey[300]!,
                        ),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedType,
                          isExpanded: true,
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          borderRadius: BorderRadius.circular(8),
                          items: _essayTypes.map((String type) {
                            return DropdownMenuItem<String>(
                              value: type,
                              child: Text(
                                type,
                                style: TextStyle(
                                  fontSize: isSmallDevice ? 14 : 16,
                                ),
                              ),
                            );
                          }).toList(),
                          onChanged: (String? newValue) {
                            if (newValue != null) {
                              setState(() {
                                _selectedType = newValue;
                              });
                            }
                          },
                        ),
                      ),
                    ),

                    if (_selectedType == 'ENEM')
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          'Dissertação-argumentativa no formato exigido pelo ENEM',
                          style: TextStyle(
                            fontSize: isSmallDevice ? 12 : 14,
                            color: isDarkMode
                                ? Colors.grey[400]
                                : Colors.grey[600],
                          ),
                        ),
                      ),

                    const SizedBox(height: 16),

                    // Título
                    Text(
                      'Título',
                      style: TextStyle(
                        fontSize: isSmallDevice ? 14 : 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),

                    TextFormField(
                      controller: _titleController,
                      style: TextStyle(
                        fontSize: isSmallDevice ? 14 : 16,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Adicione um título à sua redação',
                        hintStyle: TextStyle(
                          fontSize: isSmallDevice ? 14 : 16,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        filled: true,
                        fillColor:
                            isDarkMode ? Colors.grey[800] : Colors.grey[100],
                        contentPadding: EdgeInsets.symmetric(
                            horizontal: 16, vertical: isSmallDevice ? 12 : 16),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Por favor, informe um título';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 16),

                    // Texto da redação
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Texto',
                          style: TextStyle(
                            fontSize: isSmallDevice ? 14 : 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        // Contador de palavras movido para o topo
                        Text(
                          '$_wordCount palavras',
                          style: TextStyle(
                            fontSize: isSmallDevice ? 12 : 14,
                            color: isDarkMode
                                ? Colors.grey[400]
                                : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Campo de texto para a redação - com altura fixa para boa experiência mobile
                    Container(
                      height: 200,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isDarkMode
                              ? Colors.grey[700]!
                              : Colors.grey[300]!,
                        ),
                        color: isDarkMode ? Colors.grey[800] : Colors.grey[100],
                      ),
                      child: TextFormField(
                        controller: _textController,
                        maxLines: null,
                        expands: true,
                        style: TextStyle(
                          fontSize: isSmallDevice ? 14 : 16,
                          height: 1.5,
                        ),
                        textAlignVertical: TextAlignVertical.top,
                        decoration: InputDecoration(
                          hintText: 'Digite aqui sua redação...',
                          hintStyle: TextStyle(
                            fontSize: isSmallDevice ? 14 : 16,
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.all(16),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Por favor, escreva sua redação';
                          }
                          return null;
                        },
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Dicas
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDarkMode ? Colors.grey[800] : Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isDarkMode
                              ? Colors.grey[700]!
                              : Colors.grey[300]!,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Dicas:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: isSmallDevice ? 14 : 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.check, size: isSmallDevice ? 14 : 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Redações do ENEM devem ter entre 7 e 30 linhas.',
                                  style: TextStyle(
                                    fontSize: isSmallDevice ? 12 : 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.check, size: isSmallDevice ? 14 : 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Divida seu texto em introdução, desenvolvimento e conclusão.',
                                  style: TextStyle(
                                    fontSize: isSmallDevice ? 12 : 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Bottom bar with action buttons
            BottomAppBar(
              height: isSmallDevice ? 60 : 80,
              child: Padding(
                padding: EdgeInsets.symmetric(
                    horizontal: 16, vertical: isSmallDevice ? 8 : 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      child: Text(
                        'Cancelar',
                        style: TextStyle(
                          fontSize: isSmallDevice ? 14 : 16,
                        ),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: _isSubmitting ? null : _saveEssay,
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(
                            horizontal: isSmallDevice ? 16 : 24,
                            vertical: isSmallDevice ? 8 : 12),
                      ),
                      child: _isSubmitting
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              'Salvar rascunho',
                              style: TextStyle(
                                fontSize: isSmallDevice ? 14 : 16,
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
