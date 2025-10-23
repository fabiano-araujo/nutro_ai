import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/essay_template_model.dart';
import '../providers/essay_template_provider.dart';

/// Widget para seleção de temas de redação
class EssayThemeSelector extends StatefulWidget {
  final Function(EssayTheme?) onThemeSelected;
  final EssayTheme? initialTheme;
  final bool showCategories;
  final bool showSearch;
  final bool showTrending;

  const EssayThemeSelector({
    Key? key,
    required this.onThemeSelected,
    this.initialTheme,
    this.showCategories = true,
    this.showSearch = true,
    this.showTrending = true,
  }) : super(key: key);

  @override
  _EssayThemeSelectorState createState() => _EssayThemeSelectorState();
}

class _EssayThemeSelectorState extends State<EssayThemeSelector>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  
  String _selectedCategory = '';
  List<EssayTheme> _filteredThemes = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: widget.showTrending ? 3 : 2, vsync: this);
    _searchController.addListener(_onSearchChanged);
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialThemes();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _loadInitialThemes() {
    final provider = Provider.of<EssayTemplateProvider>(context, listen: false);
    setState(() {
      _filteredThemes = provider.themes;
    });
  }

  void _onSearchChanged() {
    final query = _searchController.text;
    final provider = Provider.of<EssayTemplateProvider>(context, listen: false);
    
    setState(() {
      _isSearching = query.isNotEmpty;
      if (_isSearching) {
        _filteredThemes = provider.searchThemes(query);
      } else {
        _filteredThemes = _selectedCategory.isEmpty
            ? provider.themes
            : provider.getThemesByCategory(_selectedCategory);
      }
    });
  }

  void _onCategorySelected(String category) {
    final provider = Provider.of<EssayTemplateProvider>(context, listen: false);
    
    setState(() {
      _selectedCategory = category;
      _filteredThemes = category.isEmpty
          ? provider.themes
          : provider.getThemesByCategory(category);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<EssayTemplateProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (provider.error != null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                Text(provider.error!),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: provider.refresh,
                  child: Text('Tentar Novamente'),
                ),
              ],
            ),
          );
        }

        return Column(
          children: [
            // Barra de pesquisa
            if (widget.showSearch) _buildSearchBar(),
            
            // Abas
            _buildTabBar(),
            
            // Conteúdo das abas
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Aba "Todos"
                  _buildAllThemesTab(provider),
                  
                  // Aba "Categorias"
                  if (widget.showCategories) _buildCategoriesTab(provider),
                  
                  // Aba "Em Alta"
                  if (widget.showTrending) _buildTrendingTab(provider),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Buscar temas...',
          prefixIcon: Icon(Icons.search),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                  },
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          filled: true,
          fillColor: Theme.of(context).brightness == Brightness.dark
              ? Colors.grey[800]
              : Colors.grey[100],
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    final tabs = <Widget>[
      Tab(text: 'Todos'),
      if (widget.showCategories) Tab(text: 'Categorias'),
      if (widget.showTrending) Tab(text: 'Em Alta'),
    ];

    return TabBar(
      controller: _tabController,
      tabs: tabs,
      labelColor: Theme.of(context).primaryColor,
      unselectedLabelColor: Colors.grey,
      indicatorColor: Theme.of(context).primaryColor,
    );
  }

  Widget _buildAllThemesTab(EssayTemplateProvider provider) {
    final themes = _isSearching ? _filteredThemes : provider.themes;
    
    if (themes.isEmpty) {
      return _buildEmptyState(
        _isSearching ? 'Nenhum tema encontrado' : 'Nenhum tema disponível',
        _isSearching ? Icons.search_off : Icons.article,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: themes.length,
      itemBuilder: (context, index) {
        final theme = themes[index];
        return _buildThemeCard(theme);
      },
    );
  }

  Widget _buildCategoriesTab(EssayTemplateProvider provider) {
    return Column(
      children: [
        // Filtro de categorias
        _buildCategoryFilter(provider),
        
        // Lista de temas filtrados
        Expanded(
          child: _filteredThemes.isEmpty
              ? _buildEmptyState('Nenhum tema nesta categoria', Icons.category)
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _filteredThemes.length,
                  itemBuilder: (context, index) {
                    final theme = _filteredThemes[index];
                    return _buildThemeCard(theme);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildTrendingTab(EssayTemplateProvider provider) {
    final trendingThemes = provider.getTrendingThemes();
    
    if (trendingThemes.isEmpty) {
      return _buildEmptyState('Nenhum tema em alta', Icons.trending_up);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: trendingThemes.length,
      itemBuilder: (context, index) {
        final theme = trendingThemes[index];
        return _buildThemeCard(theme, showTrendingBadge: true);
      },
    );
  }

  Widget _buildCategoryFilter(EssayTemplateProvider provider) {
    final categories = provider.getAvailableCategories();
    
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: categories.length + 1, // +1 para "Todos"
        itemBuilder: (context, index) {
          if (index == 0) {
            return _buildCategoryChip('Todos', '');
          }
          
          final category = categories[index - 1];
          return _buildCategoryChip(category, category);
        },
      ),
    );
  }

  Widget _buildCategoryChip(String label, String value) {
    final isSelected = _selectedCategory == value;
    
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          _onCategorySelected(selected ? value : '');
        },
        selectedColor: Theme.of(context).primaryColor.withOpacity(0.2),
        checkmarkColor: Theme.of(context).primaryColor,
      ),
    );
  }

  Widget _buildThemeCard(EssayTheme theme, {bool showTrendingBadge = false}) {
    final isSelected = widget.initialTheme?.id == theme.id;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isSelected ? 4 : 1,
      color: isSelected 
          ? Theme.of(context).primaryColor.withOpacity(0.1)
          : null,
      child: InkWell(
        onTap: () => widget.onThemeSelected(theme),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cabeçalho
              Row(
                children: [
                  Expanded(
                    child: Text(
                      theme.title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Theme.of(context).primaryColor : null,
                      ),
                    ),
                  ),
                  if (showTrendingBadge)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.trending_up, size: 12, color: Colors.white),
                          const SizedBox(width: 4),
                          Text(
                            'Em Alta',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              
              const SizedBox(height: 8),
              
              // Descrição
              Text(
                theme.description,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              
              const SizedBox(height: 12),
              
              // Metadados
              Row(
                children: [
                  _buildMetadataChip(
                    theme.category,
                    Icons.category,
                    Theme.of(context).primaryColor,
                  ),
                  const SizedBox(width: 8),
                  _buildMetadataChip(
                    theme.difficulty,
                    Icons.bar_chart,
                    _getDifficultyColor(theme.difficulty),
                  ),
                  if (theme.usageCount > 0) ...[
                    const SizedBox(width: 8),
                    _buildMetadataChip(
                      '${theme.usageCount} usos',
                      Icons.people,
                      Colors.grey,
                    ),
                  ],
                ],
              ),
              
              // Keywords
              if (theme.keywords.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: theme.keywords.take(3).map((keyword) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        keyword,
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey[700],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetadataChip(String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Color _getDifficultyColor(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'fácil':
        return Colors.green;
      case 'médio':
        return Colors.orange;
      case 'difícil':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}