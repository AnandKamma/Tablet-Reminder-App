import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_reminder/components/calendar_progress_service.dart';

class MonthCalendarGrid extends StatefulWidget {
  final DateTime monthDate;
  final DateTime? selectedDay;
  final Function(DateTime) onDaySelected;
  final String? selectedMedicationId; // NEW: Filter by medication

  const MonthCalendarGrid({
    Key? key,
    required this.monthDate,
    required this.selectedDay,
    required this.onDaySelected,
    this.selectedMedicationId, // NEW: Optional filter
  }) : super(key: key);

  @override
  State<MonthCalendarGrid> createState() => _MonthCalendarGridState();
}

class _MonthCalendarGridState extends State<MonthCalendarGrid> {
  final CalendarProgressService _progressService = CalendarProgressService();
  Map<String, String> _monthStatus = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMonthStatus();
  }

  @override
  void didUpdateWidget(MonthCalendarGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reload if month OR selected medication changes
    if (oldWidget.monthDate != widget.monthDate ||
        oldWidget.selectedMedicationId != widget.selectedMedicationId) {
      _loadMonthStatus();
    }
  }

  Future<void> _loadMonthStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final patientGroupID = prefs.getString('patientGroupID');

      if (patientGroupID == null) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
        return;
      }

      // Pass selectedMedicationId to filter results
      final status = await _progressService.getMonthStatus(
        patientGroupID: patientGroupID,
        month: widget.monthDate,
        tabletId: widget.selectedMedicationId, // NEW: Filter parameter
      );

      if (mounted) {
        setState(() {
          _monthStatus = status;
          _isLoading = false;
        });
      }

      // Debug log
      if (widget.selectedMedicationId != null) {
        print('✅ Loaded month status for medication: ${widget.selectedMedicationId}');
      } else {
        print('✅ Loaded aggregated month status for all medications');
      }
    } catch (e) {
      print('❌ Error loading month status: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final firstDayOfMonth = DateTime(widget.monthDate.year, widget.monthDate.month, 1);
    final lastDayOfMonth = DateTime(widget.monthDate.year, widget.monthDate.month + 1, 0);
    final firstWeekday = firstDayOfMonth.weekday % 7;
    final daysInMonth = lastDayOfMonth.day;
    final totalCells = ((firstWeekday + daysInMonth) / 7).ceil() * 7;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildMonthHeader(context),
        _buildCalendarGrid(context, firstDayOfMonth, firstWeekday, totalCells),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildMonthHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            DateFormat('MMMM').format(widget.monthDate),
            style: GoogleFonts.dmSerifText(
              color: Theme.of(context).colorScheme.inversePrimary,
              fontSize: 36,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              DateFormat('yyyy').format(widget.monthDate),
              style: GoogleFonts.dmSerifText(
                color: Theme.of(context).colorScheme.inversePrimary.withOpacity(0.5),
                fontSize: 20,
                fontWeight: FontWeight.w300,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarGrid(BuildContext context, DateTime firstDayOfMonth, int firstWeekday, int totalCells) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 7,
          childAspectRatio: 1.0,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
        ),
        itemCount: totalCells,
        itemBuilder: (context, index) {
          final dayOffset = index - firstWeekday;
          final cellDate = firstDayOfMonth.add(Duration(days: dayOffset));
          final isCurrentMonth = cellDate.month == widget.monthDate.month;
          final isToday = _isToday(cellDate);
          final isSelected = _isSelected(cellDate);

          return _buildDayCell(context, cellDate, isCurrentMonth, isToday, isSelected);
        },
      ),
    );
  }

  Widget _buildDayCell(BuildContext context, DateTime date, bool isCurrentMonth, bool isToday, bool isSelected) {
    if (!isCurrentMonth) {
      return const SizedBox.shrink();
    }

    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final dateStr = _formatDate(date);
    final now = DateTime.now();
    final isPastDay = date.isBefore(DateTime(now.year, now.month, now.day));

    // Get status for past days only
    final dayStatus = isPastDay ? _monthStatus[dateStr] : null;

    // Determine colors
    Color? backgroundColor;
    Color textColor = Theme.of(context).colorScheme.inversePrimary;
    bool hasNeomorphism = false;

    if (isToday) {
      // TODAY - Dark grey circle with neomorphism
      backgroundColor = Theme.of(context).colorScheme.inversePrimary;
      textColor = Theme.of(context).colorScheme.primary;
      hasNeomorphism = true;
    } else if (isPastDay && dayStatus != null) {
      // PAST DAYS with status - Colored circles, NO neomorphism
      if (dayStatus == 'complete') {
        backgroundColor = Colors.green; // All taken on time
        textColor = Colors.white;
      } else if (dayStatus == 'late') {
        backgroundColor = Colors.orange; // All taken but some late
        textColor = Colors.white;
      } else if (dayStatus == 'missed') {
        backgroundColor = Colors.red; // At least one missed
        textColor = Colors.white;
      }
    } else if (isSelected) {
      // SELECTED DAY (not today) - Grey highlight with neomorphism
      backgroundColor = Theme.of(context).colorScheme.inversePrimary;
      textColor = Theme.of(context).colorScheme.primary;
      hasNeomorphism = true;
    }

    return GestureDetector(
      onTap: () => widget.onDaySelected(date),
      child: Container(
        decoration: BoxDecoration(
          color: backgroundColor,
          shape: BoxShape.circle,
          // Neomorphism ONLY for today and selected days
          boxShadow: hasNeomorphism
              ? [
            BoxShadow(
              color: isDarkMode ? Colors.black : Colors.grey.shade500,
              offset: const Offset(2, 2),
              blurRadius: 6,
            ),
            BoxShadow(
              color: isDarkMode ? Colors.grey.shade800 : Colors.white,
              offset: const Offset(-2, -2),
              blurRadius: 6,
            ),
          ]
              : null,
        ),
        child: Center(
          child: Text(
            '${date.day}',
            style: GoogleFonts.dmSerifText(
              color: textColor,
              fontSize: 16,
              fontWeight: (isToday || isSelected) ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  bool _isSelected(DateTime date) {
    if (widget.selectedDay == null) return false;
    return date.year == widget.selectedDay!.year &&
        date.month == widget.selectedDay!.month &&
        date.day == widget.selectedDay!.day;
  }

  String _formatDate(DateTime date) {
    final year = date.year;
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}