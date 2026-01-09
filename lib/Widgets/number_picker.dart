import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class NumberPickerField extends StatelessWidget {
  final String label;
  final int value;
  final int minValue;
  final int maxValue;
  final ValueChanged<int> onChanged;
  final String? helperText;

  const NumberPickerField({
    super.key,
    required this.label,
    required this.value,
    this.minValue = 1,
    this.maxValue = 100,
    required this.onChanged,
    this.helperText,
  });

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
              color: Theme.of(
                context,
              ).colorScheme.inversePrimary.withOpacity(0.8),
            ),
          ),
        ),

        // Number picker container
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
              // Minus button
              _CircleButton(
                icon: Icons.remove,
                onPressed: value > minValue ? () => onChanged(value - 1) : null,
                isDarkMode: isDarkMode,
              ),

              // Current value
              Text(
                value.toString(),
                style: GoogleFonts.dmSerifText(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.inversePrimary,
                ),
              ),

              // Plus button
              _CircleButton(
                icon: Icons.add,
                onPressed: value < maxValue ? () => onChanged(value + 1) : null,
                isDarkMode: isDarkMode,
              ),
            ],
          ),
        ),

        // Helper text (if provided)
        if (helperText != null)
          Padding(
            padding: const EdgeInsets.only(left: 10.0, top: 20.0),
            child: Text(
              helperText!,
              style: GoogleFonts.dmSerifText(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: Theme.of(
                  context,
                ).colorScheme.inversePrimary.withOpacity(0.7),
              ),
            ),
          ),
      ],
    );
  }
}

// Circle button for increment/decrement
class _CircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final bool isDarkMode;

  const _CircleButton({
    required this.icon,
    required this.onPressed,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          shape: BoxShape.circle,
          boxShadow: onPressed != null
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
        child: Icon(
          icon,
          color: onPressed != null
              ? Theme.of(context).colorScheme.inversePrimary
              : Theme.of(context).colorScheme.inversePrimary.withOpacity(0.3),
          size: 20,
        ),
      ),
    );
  }
}
