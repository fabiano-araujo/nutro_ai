import 'package:flutter/material.dart';

/// Bottom sheet com calendário mensal personalizado.
///
/// - Navegação entre meses com swipe horizontal (e setas).
/// - Dias com refeições registradas recebem um marcador visual (bolinha).
/// - Destaque para o dia selecionado e o dia de hoje.
class MonthCalendarSheet extends StatefulWidget {
  final DateTime selectedDate;
  final bool Function(DateTime date) hasMeals;
  final ValueChanged<DateTime> onDaySelected;

  const MonthCalendarSheet({
    super.key,
    required this.selectedDate,
    required this.hasMeals,
    required this.onDaySelected,
  });

  @override
  State<MonthCalendarSheet> createState() => _MonthCalendarSheetState();
}

class _MonthCalendarSheetState extends State<MonthCalendarSheet> {
  // Usamos um índice grande como "ano base" para permitir navegação bem ampla.
  static const int _kInitialPage = 1200; // ~ano base
  late final PageController _pageController;
  late DateTime _visibleMonth;

  @override
  void initState() {
    super.initState();
    _visibleMonth =
        DateTime(widget.selectedDate.year, widget.selectedDate.month, 1);
    _pageController = PageController(initialPage: _kInitialPage);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  DateTime _monthForPage(int page) {
    final diff = page - _kInitialPage;
    return DateTime(_visibleMonth.year, _visibleMonth.month + diff, 1);
  }

  void _goToOffset(int offset) {
    _pageController.animateToPage(
      (_pageController.page?.round() ?? _kInitialPage) + offset,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDarkMode ? Colors.white : Colors.black87;
    final subtleColor = isDarkMode ? Colors.white60 : Colors.black54;
    final materialLoc = MaterialLocalizations.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDarkMode ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            // Header: < Mês de AAAA >
            StatefulBuilder(
              builder: (context, setHeaderState) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.chevron_left, color: textColor),
                        onPressed: () => _goToOffset(-1),
                        tooltip: 'Mês anterior',
                      ),
                      Expanded(
                        child: Center(
                          child: Text(
                            _capitalize(
                              materialLoc.formatMonthYear(_visibleMonth),
                            ),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: textColor,
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.chevron_right, color: textColor),
                        onPressed: () => _goToOffset(1),
                        tooltip: 'Próximo mês',
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 4),
            // Cabeçalho dos dias da semana (D S T Q Q S S)
            _buildWeekdaysHeader(materialLoc, subtleColor),
            const SizedBox(height: 4),
            SizedBox(
              height: 300,
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (page) {
                  setState(() {
                    _visibleMonth = _monthForPage(page);
                  });
                },
                itemBuilder: (context, page) {
                  final month = _monthForPage(page);
                  return _MonthGrid(
                    month: month,
                    selectedDate: widget.selectedDate,
                    hasMeals: widget.hasMeals,
                    isDarkMode: isDarkMode,
                    onDaySelected: widget.onDaySelected,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeekdaysHeader(
      MaterialLocalizations loc, Color color) {
    final first = loc.firstDayOfWeekIndex; // 0 = domingo
    final labels = <String>[];
    for (int i = 0; i < 7; i++) {
      labels.add(loc.narrowWeekdays[(first + i) % 7]);
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: labels
            .map(
              (l) => Expanded(
                child: Center(
                  child: Text(
                    l,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  static String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

class _MonthGrid extends StatelessWidget {
  final DateTime month;
  final DateTime selectedDate;
  final bool Function(DateTime) hasMeals;
  final bool isDarkMode;
  final ValueChanged<DateTime> onDaySelected;

  const _MonthGrid({
    required this.month,
    required this.selectedDate,
    required this.hasMeals,
    required this.isDarkMode,
    required this.onDaySelected,
  });

  @override
  Widget build(BuildContext context) {
    final loc = MaterialLocalizations.of(context);
    final firstDayIndex = loc.firstDayOfWeekIndex; // 0 = domingo
    final firstOfMonth = DateTime(month.year, month.month, 1);
    // DateTime.weekday: 1=seg..7=dom. Queremos 0=dom..6=sáb.
    final firstWeekday0 = firstOfMonth.weekday % 7;
    // leadingBlanks = quantas células em branco antes do dia 1
    final leadingBlanks = (firstWeekday0 - firstDayIndex + 7) % 7;

    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final totalCells = leadingBlanks + daysInMonth;
    final rows = (totalCells / 7).ceil();
    final cells = rows * 7;

    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    final onAccent = theme.colorScheme.onPrimary;
    final now = DateTime.now();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 7,
          childAspectRatio: 1,
        ),
        itemCount: cells,
        itemBuilder: (context, index) {
          final dayNum = index - leadingBlanks + 1;
          if (dayNum < 1 || dayNum > daysInMonth) {
            return const SizedBox.shrink();
          }
          final date = DateTime(month.year, month.month, dayNum);
          final isSelected = date.year == selectedDate.year &&
              date.month == selectedDate.month &&
              date.day == selectedDate.day;
          final isToday = date.year == now.year &&
              date.month == now.month &&
              date.day == now.day;
          final hasData = hasMeals(date);
          final isFuture = date.isAfter(DateTime(now.year, now.month, now.day));

          Color? bg;
          Color textColor;
          if (isSelected) {
            bg = accent;
            textColor = onAccent;
          } else if (isToday) {
            bg = accent.withValues(alpha: isDarkMode ? 0.25 : 0.15);
            textColor = accent;
          } else {
            bg = null;
            textColor = isFuture
                ? (isDarkMode ? Colors.white30 : Colors.black26)
                : (isDarkMode ? Colors.white : Colors.black87);
          }

          return InkWell(
            onTap: () => onDaySelected(date),
            borderRadius: BorderRadius.circular(100),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: bg,
                      shape: BoxShape.circle,
                      border: isToday && !isSelected
                          ? Border.all(color: accent, width: 1)
                          : null,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '$dayNum',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: textColor,
                      ),
                    ),
                  ),
                  if (hasData)
                    Positioned(
                      bottom: 4,
                      child: Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          color: isSelected ? onAccent : accent,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
