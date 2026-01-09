import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SaveButton extends StatelessWidget {
  final bool enabled;
  final VoidCallback onTap;

  const SaveButton({
    super.key,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        height: 60, // Lesser height than tiles
        width: double.infinity, // Full width
        decoration: BoxDecoration(
          color: enabled
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.primary.withOpacity(0.5),
          borderRadius: BorderRadius.circular(30), // More curved borders
          boxShadow: enabled
              ? [
            // Bottom-right shadow (darker)
            BoxShadow(
              color: isDarkMode ? Colors.black : Colors.grey.shade500,
              offset: const Offset(5, 5),
              blurRadius: 15,
              spreadRadius: 5,
            ),
            // Top-left shadow (lighter)
            BoxShadow(
              color: isDarkMode ? Colors.grey.shade800 : Colors.white,
              offset: const Offset(-4, -4),
              blurRadius: 15,
              spreadRadius: 1,
            ),
          ]
              : null,
        ),
        child: Center(
          child: Text(
            enabled ? 'Save' : 'Complete required sections',
            style: GoogleFonts.dmSerifText(
              fontSize: 16,
              color: enabled
                  ? Theme.of(context).colorScheme.inversePrimary
                  : Theme.of(context).colorScheme.inversePrimary.withOpacity(0.4),
            ),
          ),
        ),
      ),
    );
  }
}