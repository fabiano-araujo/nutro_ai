import 'package:flutter/material.dart';
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
    final difference = date.difference(_referenceDate).inDays;
    return (difference / 7).floor();
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

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDarkMode = brightness == Brightness.dark;

    return Container(
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
