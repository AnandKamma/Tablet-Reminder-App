import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class TimePickerField extends StatelessWidget {
  final String label;
  final TimeOfDay? selectedTime;
  final ValueChanged<TimeOfDay> onTimeSelected;

  const TimePickerField({
    super.key,
    required this.label,
    required this.selectedTime,
    required this.onTimeSelected,
  });

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: selectedTime ?? TimeOfDay.now(),
      initialEntryMode: TimePickerEntryMode.dialOnly,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            timePickerTheme: TimePickerThemeData(
              backgroundColor: Theme.of(context).colorScheme.primary,
              dialBackgroundColor: Theme.of(context).colorScheme.surface,

              // Fix: Hour/Minute text gets highlighted when selected
              hourMinuteColor: WidgetStateColor.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return Theme.of(context).colorScheme.surface; // ← Grey overlay when selected
                }
                return Theme.of(context).colorScheme.primary;
              }),

              hourMinuteTextColor: Theme.of(context).colorScheme.inversePrimary,
              dayPeriodTextColor: Theme.of(context).colorScheme.inversePrimary,
              dialTextColor: Theme.of(context).colorScheme.inversePrimary,

              helpTextStyle: GoogleFonts.dmSerifText(
                color: Theme.of(context).colorScheme.inversePrimary,
              ),

              // Replace OK/Cancel with icons
              confirmButtonStyle: ButtonStyle(
                foregroundColor: WidgetStateProperty.all(
                  Theme.of(context).colorScheme.inversePrimary,
                ),
                iconColor: WidgetStateProperty.all(
                  Theme.of(context).colorScheme.inversePrimary,
                ),
              ),
              cancelButtonStyle: ButtonStyle(
                foregroundColor: WidgetStateProperty.all(
                  Theme.of(context).colorScheme.inversePrimary,
                ),
                iconColor: WidgetStateProperty.all(
                  Theme.of(context).colorScheme.inversePrimary,
                ),
              ),
            ),

            // Use icons instead of text for buttons
            textButtonTheme: TextButtonThemeData(
              style: ButtonStyle(
                foregroundColor: WidgetStateProperty.all(
                  Theme.of(context).colorScheme.inversePrimary,
                ),
              ),
            ),
          ),
          child: child!,
        );
      },
      // Replace "OK" and "Cancel" with icons
      confirmText: '✓', // Checkmark
      cancelText: '✕',  // X mark
    );

    if (picked != null) {
      onTimeSelected(picked);
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
          padding: const EdgeInsets.only(left: 5.0, bottom: 8.0),
          child: Text(
            label,
            style: GoogleFonts.dmSerifText(
              fontSize: 16,
              fontWeight: FontWeight.w400,
              color: Theme.of(context).colorScheme.inversePrimary.withOpacity(0.8),
            ),
          ),
        ),

        // Time picker button
        GestureDetector(
          onTap: () => _selectTime(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: isDarkMode ? Colors.black : Colors.grey.shade500,
                  offset: const Offset(4, 4),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
                BoxShadow(
                  color: isDarkMode ? Colors.grey.shade800 : Colors.white,
                  offset: const Offset(-4, -4),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Display selected time
                Text(
                  selectedTime != null
                      ? selectedTime!.format(context)
                      : 'Select time',
                  style: GoogleFonts.dmSerifText(
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    color: selectedTime != null
                        ? Theme.of(context).colorScheme.inversePrimary
                        : Theme.of(context).colorScheme.inversePrimary.withOpacity(0.4),
                  ),
                ),

                // Simple checkmark icon (no color, just line)
                Icon(
                  selectedTime != null ? Icons.check : Icons.access_time,
                  color: Theme.of(context).colorScheme.inversePrimary, // ← Same color as text
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}