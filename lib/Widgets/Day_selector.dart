import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class DaySelector extends StatelessWidget {
  final List<String> selectedDays;
  final ValueChanged<List<String>> onChanged;

  const DaySelector({
    super.key,
    required this.selectedDays,
    required this.onChanged,
  });

  final List<String> _allDays = const ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'];

  void _toggleDay(String day) {
    final updatedDays = List<String>.from(selectedDays);
    if (updatedDays.contains(day)) {
      updatedDays.remove(day);
    } else {
      updatedDays.add(day);
    }
    onChanged(updatedDays);
  }

  void _toggleAll() {
    if (selectedDays.length == 7) {
      onChanged([]);
    } else {
      onChanged(List<String>.from(_allDays));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label
        Padding(
          padding: const EdgeInsets.only(left: 5.0, bottom: 20.0),
          child: Text(
            'How many times in a week do you take it?',
            style: GoogleFonts.dmSerifText(
              fontSize: 16,
              fontWeight: FontWeight.w400,
              color: Theme.of(context).colorScheme.inversePrimary.withOpacity(0.8),
            ),
          ),
        ),

        // Days grid
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            // Individual day buttons
            ..._allDays.map((day) => _DayChip(
              day: day,
              isSelected: selectedDays.contains(day),
              onTap: () => _toggleDay(day),
              isDarkMode: isDarkMode,
            )),

            // "All" button
            _DayChip(
              day: 'All',
              isSelected: selectedDays.length == 7,
              onTap: _toggleAll,
              isDarkMode: isDarkMode,
              isAllButton: true,
            ),
          ],
        ),
      ],
    );
  }
}

class _DayChip extends StatelessWidget {
  final String day;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isDarkMode;
  final bool isAllButton;

  const _DayChip({
    required this.day,
    required this.isSelected,
    required this.onTap,
    required this.isDarkMode,
    this.isAllButton = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: isAllButton ? 60 : 50,
        height: 50,
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.inversePrimary
              : Theme.of(context).colorScheme.primary,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: isDarkMode ? Colors.black : Colors.grey.shade500,
              offset: const Offset(3, 3),
              blurRadius: 8,
              spreadRadius: 1,
            ),
            BoxShadow(
              color: isDarkMode ? Colors.grey.shade800 : Colors.white,
              offset: const Offset(-3, -3),
              blurRadius: 8,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Center(
          child: Text(
            day,
            style: TextStyle(
              fontSize: isAllButton ? 13 : 14,
              fontWeight: FontWeight.bold,
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.inversePrimary,
            ),
          ),
        ),
      ),
    );
  }
}