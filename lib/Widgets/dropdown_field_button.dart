import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class DropdownField extends StatelessWidget {
  final String label;
  final String? value;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  const DropdownField({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label
        Padding(
          padding: const EdgeInsets.only(left: 10.0, bottom: 20.0),
          child: Text(
            label,
            style: GoogleFonts.dmSerifText(
              fontSize: 16,
              fontWeight: FontWeight.w400,
              color: Theme.of(context).colorScheme.inversePrimary.withOpacity(0.8),
            ),
          ),
        ),

        // Dropdown with neomorphic design
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              // Bottom-right shadow (darker)
              BoxShadow(
                color: isDarkMode ? Colors.black : Colors.grey.shade500,
                offset: const Offset(4, 4),
                blurRadius: 10,
                spreadRadius: 1,
              ),
              // Top-left shadow (lighter)
              BoxShadow(
                color: isDarkMode ? Colors.grey.shade800 : Colors.white,
                offset: const Offset(-4, -4),
                blurRadius: 10,
                spreadRadius: 1,
              ),
            ],
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              hint: Text(
                'Select an option',
                style: GoogleFonts.dmSerifText(
                  color: Theme.of(context).colorScheme.inversePrimary.withOpacity(0.4),
                ),
              ),
              borderRadius: BorderRadius.circular(30), // ← Rounded dropdown menu
              dropdownColor: Theme.of(context).colorScheme.primary,
              style: GoogleFonts.dmSerifText(
                color: Theme.of(context).colorScheme.inversePrimary,
                fontSize: 16,
              ),
              icon: Icon(
                Icons.arrow_drop_down,
                color: Theme.of(context).colorScheme.inversePrimary,
              ),
              items: items.map((String item) {
                return DropdownMenuItem<String>(
                  value: item,
                  child: Text(item),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}