import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';

class WeeklyCalendar extends StatefulWidget {
  final Function(DateTime)? onDaySelected;
  final DateTime? selectedDate;

  const WeeklyCalendar({
    Key? key,
    this.onDaySelected,
    this.selectedDate,
  }) : super(key: key);

  @override
  State<WeeklyCalendar> createState() => _WeeklyCalendarState();
}

class _WeeklyCalendarState extends State<WeeklyCalendar> {
  late PageController _pageController;
  late DateTime _selectedDate;
  int _currentWeekIndex = 0;

  // Data de referência (semana 0)
  final DateTime _referenceDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.selectedDate ?? DateTime.now();

    // Calcular o índice da semana inicial
    _currentWeekIndex = _getWeekIndex(_selectedDate);

    // Inicializar o PageController na semana atual
    _pageController = PageController(initialPage: _currentWeekIndex + 1000);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // Calcula o índice da semana baseado em uma data de referência
  int _getWeekIndex(DateTime date) {
    // Ajustar a data para o início da semana (domingo)
    final weekday = date.weekday;
    final daysToSubtract = weekday == 7 ? 0 : weekday;
    final weekStart = date.subtract(Duration(days: daysToSubtract));

    // Ajustar a referência para o início da semana também
    final refWeekday = _referenceDate.weekday;
    final refDaysToSubtract = refWeekday == 7 ? 0 : refWeekday;
    final refWeekStart = _referenceDate.subtract(Duration(days: refDaysToSubtract));

    final difference = weekStart.difference(refWeekStart).inDays;
    return (difference / 7).round();
  }

  // Obtém a data de início da semana para um índice específico
  DateTime _getWeekStartDate(int weekIndex) {
    final daysToAdd = weekIndex * 7;
    final targetDate = _referenceDate.add(Duration(days: daysToAdd));

    // Ajustar para o início da semana (domingo)
    final weekday = targetDate.weekday;
    final daysToSubtract = weekday == 7 ? 0 : weekday;

    return targetDate.subtract(Duration(days: daysToSubtract));
  }

  // Gera a lista de 7 dias para uma semana específica
  List<DateTime> _getDaysInWeek(int weekIndex) {
    final weekStart = _getWeekStartDate(weekIndex);
    return List.generate(7, (index) => weekStart.add(Duration(days: index)));
  }

  String _formatDateTitle() {
    final now = DateTime.now();
    final yesterday = now.subtract(Duration(days: 1));

    if (_isSameDay(_selectedDate, now)) {
      return 'Hoje';
    } else if (_isSameDay(_selectedDate, yesterday)) {
      return 'Ontem';
    } else {
      final formatter = DateFormat('MMM. d, yyyy', 'pt_BR');
      return formatter.format(_selectedDate);
    }
  }

  void _goToToday() {
    final today = DateTime.now();
    final todayWeekIndex = _getWeekIndex(today);

    setState(() {
      _selectedDate = today;
      _currentWeekIndex = todayWeekIndex;
    });

    _pageController.animateToPage(
      todayWeekIndex + 1000,
      duration: Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );

    widget.onDaySelected?.call(today);
  }

  Future<void> _showDatePicker() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      locale: Locale('pt', 'BR'),
    );

    if (picked != null) {
      final pickedWeekIndex = _getWeekIndex(picked);

      setState(() {
        _selectedDate = picked;
        _currentWeekIndex = pickedWeekIndex;
      });

      // Animar para a semana correta
      await _pageController.animateToPage(
        pickedWeekIndex + 1000,
        duration: Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );

      widget.onDaySelected?.call(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDarkMode = brightness == Brightness.dark;
    final isToday = _isSameDay(_selectedDate, DateTime.now());

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // AppBar
        Container(
          height: 56,
          color: isDarkMode ? AppTheme.darkBackgroundColor : AppTheme.backgroundColor,
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              // Botão "Hoje" (só aparece quando não está no dia atual)
              SizedBox(
                width: 80,
                child: !isToday
                    ? Padding(
                        padding: EdgeInsets.only(left: 8),
                        child: InkWell(
                          onTap: _goToToday,
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Theme.of(context).primaryColor.withAlpha(38),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Hoje',
                                  style: TextStyle(
                                    color: Theme.of(context).primaryColor,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                SizedBox(width: 4),
                                Icon(
                                  Icons.arrow_forward_ios,
                                  size: 12,
                                  color: Theme.of(context).primaryColor,
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    : SizedBox.shrink(),
              ),

              // Título centralizado (data selecionada)
              Expanded(
                child: Center(
                  child: InkWell(
                    onTap: _showDatePicker,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Text(
                        _formatDateTitle(),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isDarkMode ? Colors.white : AppTheme.textPrimaryColor,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Espaço vazio à direita para manter centralização
              SizedBox(width: 80),
            ],
          ),
        ),

        // Calendário semanal
        Container(
          height: 75,
          color: isDarkMode ? AppTheme.darkBackgroundColor : AppTheme.backgroundColor,
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _currentWeekIndex = index - 1000;
              });
            },
            itemBuilder: (context, index) {
              final weekIndex = index - 1000; // Offset para permitir navegação em ambas direções
              final daysInWeek = _getDaysInWeek(weekIndex);

              return _buildWeekView(daysInWeek, isDarkMode);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildWeekView(List<DateTime> days, bool isDarkMode) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: days.map((date) => _buildDayItem(date, isDarkMode)).toList(),
    );
  }

  Widget _buildDayItem(DateTime date, bool isDarkMode) {
    final isSelected = _isSameDay(date, _selectedDate);
    final isToday = _isSameDay(date, DateTime.now());
    final dayName = _getDayName(date.weekday);
    final dayNumber = date.day.toString();

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedDate = date;
        });
        widget.onDaySelected?.call(date);
      },
      child: Container(
        width: 50,
        padding: EdgeInsets.symmetric(vertical: 6),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Nome do dia da semana
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected
                    ? Theme.of(context).primaryColor
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                dayName,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: isSelected
                      ? Colors.white
                      : isToday
                          ? Theme.of(context).primaryColor
                          : isDarkMode
                              ? Colors.white70
                              : AppTheme.textSecondaryColor,
                ),
              ),
            ),
            SizedBox(height: 4),
            // Número do dia
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isSelected
                    ? Theme.of(context).primaryColor
                    : isDarkMode
                        ? Colors.white.withAlpha(13)
                        : Colors.black.withAlpha(13),
                shape: BoxShape.circle,
                // Borda para o dia atual
                border: isToday && !isSelected
                    ? Border.all(
                        color: Theme.of(context).primaryColor,
                        width: 2.5,
                      )
                    : null,
              ),
              alignment: Alignment.center,
              child: Text(
                dayNumber,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: isSelected || isToday ? FontWeight.bold : FontWeight.w500,
                  color: isSelected
                      ? Colors.white
                      : isToday
                          ? Theme.of(context).primaryColor
                          : isDarkMode
                              ? Colors.white
                              : AppTheme.textPrimaryColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  String _getDayName(int weekday) {
    switch (weekday) {
      case 1:
        return 'SEG';
      case 2:
        return 'TER';
      case 3:
        return 'QUA';
      case 4:
        return 'QUI';
      case 5:
        return 'SEX';
      case 6:
        return 'SÁB';
      case 7:
        return 'DOM';
      default:
        return '';
    }
  }
}
