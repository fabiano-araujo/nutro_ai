import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../i18n/app_localizations_extension.dart';
import '../models/essay_model.dart';
import '../providers/essay_provider.dart';
import '../screens/new_essay_screen.dart';

class EssayHistoryScreen extends StatefulWidget {
  const EssayHistoryScreen({Key? key}) : super(key: key);

  @override
  _EssayHistoryScreenState createState() => _EssayHistoryScreenState();
}

class _EssayHistoryScreenState extends State<EssayHistoryScreen> {
  @override
  void initState() {
    super.initState();
    // Inicializar com dados de exemplo
    Future.microtask(() {
      final essayProvider = Provider.of<EssayProvider>(context, listen: false);
      essayProvider.initWithSamples();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallDevice = screenWidth < 360;

    return Scaffold(
      appBar: AppBar(
        title: Text('Histórico de Redações'),
        elevation: 0,
      ),
      body: Consumer<EssayProvider>(
        builder: (context, essayProvider, child) {
          final essays = essayProvider.essays;
          final averageScore = essayProvider.calculateAverageScore();
          final totalEssays = essays.length;

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Acompanhe suas redações e seu progresso',
                  style: TextStyle(
                    fontSize: 16,
                    color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 20),

                // Estatísticas cards row - Layout adaptado a telas pequenas
                LayoutBuilder(
                  builder: (context, constraints) {
                    if (isSmallDevice) {
                      // Layout para telas muito pequenas - cards em coluna
                      return Column(
                        children: [
                          _buildStatCard(
                            context,
                            totalEssays.toString(),
                            'Total de Redações',
                            Colors.blue,
                            isDarkMode,
                          ),
                          const SizedBox(height: 12),
                          _buildStatCard(
                            context,
                            averageScore.toString(),
                            'Média de Pontuação',
                            Colors.green,
                            isDarkMode,
                          ),
                          const SizedBox(height: 12),
                          _buildStatCard(
                            context,
                            '+30 pontos',
                            'Evolução no último mês',
                            Colors.purple,
                            isDarkMode,
                            icon: Icons.trending_up,
                          ),
                        ],
                      );
                    } else {
                      // Layout padrão para telas normais
                      return Row(
                        children: [
                          Expanded(
                            child: _buildStatCard(
                              context,
                              totalEssays.toString(),
                              'Total de Redações',
                              Colors.blue,
                              isDarkMode,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildStatCard(
                              context,
                              averageScore.toString(),
                              'Média de Pontuação',
                              Colors.green,
                              isDarkMode,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildStatCard(
                              context,
                              '+30 pontos',
                              'Evolução no último mês',
                              Colors.purple,
                              isDarkMode,
                              icon: Icons.trending_up,
                            ),
                          ),
                        ],
                      );
                    }
                  },
                ),

                const SizedBox(height: 24),

                // Título da lista personalizado para telas menores
                isSmallDevice
                    ? _buildCompactTableHeader(isDarkMode)
                    : _buildFullTableHeader(isDarkMode),

                Divider(),

                // Lista de redações
                Expanded(
                  child: ListView.builder(
                    itemCount: essays.length,
                    itemBuilder: (context, index) {
                      final essay = essays[index];
                      return isSmallDevice
                          ? _buildCompactEssayItem(context, essay)
                          : _buildEssayItem(context, essay);
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => NewEssayScreen()),
          );
        },
        child: Icon(Icons.add),
        tooltip: 'Nova Redação',
      ),
    );
  }

  Widget _buildCompactTableHeader(bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              'Título',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'Info',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
              ),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(width: 20), // Espaço para o ícone de ação
        ],
      ),
    );
  }

  Widget _buildFullTableHeader(bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              'Título',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              'Tipo',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              'Data',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              'Status',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              'Pontuação',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
              ),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(width: 20), // Espaço para o ícone de ação
        ],
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    String value,
    String label,
    Color color,
    bool isDarkMode, {
    IconData? icon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDarkMode ? Color(0xFF2A2A2A) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, color: color, size: 20),
                SizedBox(width: 6),
              ],
              Flexible(
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildCompactEssayItem(BuildContext context, Essay essay) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final dateFormat = DateFormat('dd/MM/yyyy');

    // Definir cores para os diferentes status
    Color statusColor;
    switch (essay.status) {
      case 'Corrigido':
        statusColor = Colors.green;
        break;
      case 'Em Análise':
        statusColor = Colors.orange;
        break;
      default:
        statusColor = Colors.grey;
        break;
    }

    return InkWell(
      onTap: () {
        _handleEssayTap(context, essay);
      },
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isDarkMode ? Colors.grey[800]! : Colors.grey[300]!,
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          children: [
            // Ícone de documento
            Icon(
              Icons.description_outlined,
              color: isDarkMode ? Colors.grey[400] : Colors.grey[500],
              size: 20,
            ),
            SizedBox(width: 8),

            // Título
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    essay.title,
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: isDarkMode ? Colors.white : Colors.black87,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                  Text(
                    essay.type,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDarkMode ? Colors.grey[400] : Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ),

            // Informações compactas (status e pontuação)
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      essay.status,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    essay.status == 'Corrigido' ? '${essay.score}pts' : '-',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: essay.status == 'Corrigido'
                          ? Theme.of(context).primaryColor
                          : Colors.grey,
                    ),
                  ),
                ],
              ),
            ),

            // Ícone de ação
            Icon(
              Icons.chevron_right,
              color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEssayItem(BuildContext context, Essay essay) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final dateFormat = DateFormat('dd/MM/yyyy');

    // Definir cores para os diferentes status
    Color statusColor;
    switch (essay.status) {
      case 'Corrigido':
        statusColor = Colors.green;
        break;
      case 'Em Análise':
        statusColor = Colors.orange;
        break;
      default:
        statusColor = Colors.grey;
        break;
    }

    return InkWell(
      onTap: () {
        _handleEssayTap(context, essay);
      },
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isDarkMode ? Colors.grey[800]! : Colors.grey[300]!,
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          children: [
            // Ícone de documento
            Icon(
              Icons.description_outlined,
              color: isDarkMode ? Colors.grey[400] : Colors.grey[500],
              size: 20,
            ),
            SizedBox(width: 8),

            // Título
            Expanded(
              flex: 3,
              child: Text(
                essay.title,
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),

            // Tipo
            Expanded(
              flex: 1,
              child: Text(
                essay.type,
                style: TextStyle(
                  color: isDarkMode ? Colors.grey[400] : Colors.grey[700],
                ),
              ),
            ),

            // Data
            Expanded(
              flex: 1,
              child: Text(
                dateFormat.format(essay.date),
                style: TextStyle(
                  color: isDarkMode ? Colors.grey[400] : Colors.grey[700],
                ),
              ),
            ),

            // Status
            Expanded(
              flex: 1,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  essay.status,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),

            // Pontuação
            Expanded(
              flex: 1,
              child: Text(
                essay.status == 'Corrigido' ? essay.score.toString() : '-',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: essay.status == 'Corrigido'
                      ? Theme.of(context).primaryColor
                      : Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
            ),

            // Ícone de ação
            Icon(
              Icons.chevron_right,
              color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
            ),
          ],
        ),
      ),
    );
  }

  void _handleEssayTap(BuildContext context, Essay essay) {
    Provider.of<EssayProvider>(context, listen: false).setCurrentEssay(essay);

    if (essay.status == 'Corrigido') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Funcionalidade de visualização de correção em desenvolvimento.'),
          backgroundColor: Colors.blue,
        ),
      );
    } else if (essay.status == 'Rascunho') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => NewEssayScreen(
            isEditing: true,
            essayId: essay.id,
          ),
        ),
      );
    } else {
      // Mostrar mensagem que está em análise
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('Esta redação está em análise e será corrigida em breve.'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }
}
