import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/meal_types_provider.dart';
import '../theme/app_theme.dart';

class ManageMealTypesScreen extends StatefulWidget {
  const ManageMealTypesScreen({Key? key}) : super(key: key);

  @override
  State<ManageMealTypesScreen> createState() => _ManageMealTypesScreenState();
}

class _ManageMealTypesScreenState extends State<ManageMealTypesScreen> {
  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDarkMode
        ? AppTheme.darkBackgroundColor
        : AppTheme.backgroundColor;
    final textColor = isDarkMode
        ? AppTheme.darkTextColor
        : AppTheme.textPrimaryColor;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Gerenciar Refeições',
          style: AppTheme.headingLarge.copyWith(
            color: textColor,
            fontSize: 20,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: textColor),
            tooltip: 'Restaurar Padrão',
            onPressed: _showResetDialog,
          ),
        ],
      ),
      body: Consumer<MealTypesProvider>(
        builder: (context, provider, child) {
          if (provider.mealTypes.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.restaurant_menu,
                    size: 64,
                    color: textColor.withValues(alpha: 0.3),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Nenhuma refeição cadastrada',
                    style: TextStyle(
                      fontSize: 16,
                      color: textColor.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              Expanded(
                child: ReorderableListView.builder(
                  padding: EdgeInsets.all(16),
                  itemCount: provider.mealTypes.length,
                  onReorder: (oldIndex, newIndex) {
                    provider.reorderMealTypes(oldIndex, newIndex);
                  },
                  itemBuilder: (context, index) {
                    final mealType = provider.mealTypes[index];
                    return _MealTypeCard(
                      key: ValueKey(mealType.id),
                      index: index,
                      mealType: mealType,
                      isDarkMode: isDarkMode,
                      onEdit: () => _showEditDialog(mealType),
                      onDelete: () => _showDeleteDialog(mealType),
                    );
                  },
                ),
              ),
              // Save changes button
              Padding(
                padding: EdgeInsets.all(16),
                child: SafeArea(
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        _saveMealChanges();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.save, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Salvar Mudanças',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: Padding(
        padding: EdgeInsets.only(bottom: 80), // Space above the save button
        child: FloatingActionButton(
          backgroundColor: AppTheme.primaryColor,
          onPressed: _showAddDialog,
          child: Icon(Icons.add, color: Colors.white),
        ),
      ),
    );
  }

  void _showAddDialog() {
    final nameController = TextEditingController();
    String selectedEmoji = '🍽️';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text('Adicionar Refeição'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: 'Nome da Refeição',
                    border: OutlineInputBorder(),
                  ),
                  autofocus: true,
                ),
                SizedBox(height: 16),
                Row(
                  children: [
                    Text('Emoji: '),
                    SizedBox(width: 12),
                    GestureDetector(
                      onTap: () {
                        _showEmojiPicker(context, (emoji) {
                          setState(() {
                            selectedEmoji = emoji;
                          });
                        });
                      },
                      child: Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          selectedEmoji,
                          style: TextStyle(fontSize: 32),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (nameController.text.isNotEmpty) {
                    Provider.of<MealTypesProvider>(context, listen: false)
                        .addMealType(nameController.text, selectedEmoji);
                    Navigator.pop(context);
                  }
                },
                child: Text('Adicionar'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showEditDialog(MealTypeConfig mealType) {
    final nameController = TextEditingController(text: mealType.name);
    String selectedEmoji = mealType.emoji;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text('Editar Refeição'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: 'Nome da Refeição',
                    border: OutlineInputBorder(),
                  ),
                  autofocus: true,
                ),
                SizedBox(height: 16),
                Row(
                  children: [
                    Text('Emoji: '),
                    SizedBox(width: 12),
                    GestureDetector(
                      onTap: () {
                        _showEmojiPicker(context, (emoji) {
                          setState(() {
                            selectedEmoji = emoji;
                          });
                        });
                      },
                      child: Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          selectedEmoji,
                          style: TextStyle(fontSize: 32),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (nameController.text.isNotEmpty) {
                    Provider.of<MealTypesProvider>(context, listen: false)
                        .updateMealType(
                      mealType.id,
                      name: nameController.text,
                      emoji: selectedEmoji,
                    );
                    Navigator.pop(context);
                  }
                },
                child: Text('Salvar'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showDeleteDialog(MealTypeConfig mealType) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Excluir Refeição'),
        content: Text(
          'Tem certeza que deseja excluir "${mealType.name}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            onPressed: () {
              Provider.of<MealTypesProvider>(context, listen: false)
                  .deleteMealType(mealType.id);
              Navigator.pop(context);
            },
            child: Text('Excluir'),
          ),
        ],
      ),
    );
  }

  void _saveMealChanges() {
    // The changes are automatically saved in the provider via SharedPreferences
    // Show a confirmation snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 12),
            Text('Mudanças salvas com sucesso!'),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        margin: EdgeInsets.all(16),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _showResetDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Restaurar Padrão'),
        content: Text(
          'Deseja restaurar as refeições padrão? Isso irá remover todas as suas personalizações.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Provider.of<MealTypesProvider>(context, listen: false)
                  .resetToDefaults();
              Navigator.pop(context);
            },
            child: Text('Restaurar'),
          ),
        ],
      ),
    );
  }

  void _showEmojiPicker(BuildContext context, Function(String) onEmojiSelected) {
    final emojis = [
      '🍳', '🥐', '🥞', '🧇', '🥓', '🥖', '🥨',
      '🍞', '🥯', '🧀', '🥗', '🥙', '🌮', '🌯',
      '🥪', '🍕', '🍔', '🍟', '🌭', '🍿', '🥘',
      '🍝', '🍜', '🍲', '🍱', '🍛', '🍙', '🍚',
      '🍘', '🥟', '🍢', '🍣', '🍤', '🥠', '🍡',
      '🥧', '🍰', '🎂', '🍮', '🍭', '🍬', '🍫',
      '🍿', '🍩', '🍪', '🌰', '🥜', '🍯', '🥛',
      '🍼', '☕', '🍵', '🧃', '🥤', '🍶', '🍺',
      '🍻', '🥂', '🍷', '🥃', '🍸', '🍹', '🍾',
      '🧊', '🥄', '🍴', '🥢', '🍽️', '🥗', '🥙',
    ];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Selecione um Emoji'),
        content: Container(
          width: double.maxFinite,
          height: 300,
          child: GridView.builder(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 6,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
            ),
            itemCount: emojis.length,
            itemBuilder: (context, index) {
              return GestureDetector(
                onTap: () {
                  onEmojiSelected(emojis[index]);
                  Navigator.pop(context);
                },
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      emojis[index],
                      style: TextStyle(fontSize: 28),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Fechar'),
          ),
        ],
      ),
    );
  }
}

class _MealTypeCard extends StatelessWidget {
  final int index;
  final MealTypeConfig mealType;
  final bool isDarkMode;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _MealTypeCard({
    Key? key,
    required this.index,
    required this.mealType,
    required this.isDarkMode,
    required this.onEdit,
    required this.onDelete,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final cardColor = isDarkMode ? AppTheme.darkCardColor : AppTheme.cardColor;
    final textColor = isDarkMode
        ? AppTheme.darkTextColor
        : AppTheme.textPrimaryColor;

    return Card(
      margin: EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      color: cardColor,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          children: [
            // Drag handle
            ReorderableDragStartListener(
              index: index,
              child: Icon(
                Icons.drag_handle,
                color: textColor.withValues(alpha: 0.4),
              ),
            ),
            SizedBox(width: 12),

            // Emoji
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isDarkMode
                    ? Color(0xFF2E2E2E)
                    : Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  mealType.emoji,
                  style: TextStyle(fontSize: 24),
                ),
              ),
            ),
            SizedBox(width: 12),

            // Name
            Expanded(
              child: Text(
                mealType.name,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
            ),

            // Edit button
            IconButton(
              icon: Icon(Icons.edit, color: AppTheme.primaryColor),
              onPressed: onEdit,
            ),

            // Delete button
            IconButton(
              icon: Icon(Icons.delete, color: textColor.withValues(alpha: 0.6)),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}
