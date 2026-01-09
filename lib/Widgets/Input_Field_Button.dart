import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class InputField extends StatelessWidget {
  final String label;
  final String hintText;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final int? maxLength;
  final List<TextInputFormatter>? inputFormatters;

  const InputField({
    super.key,
    required this.label,
    required this.hintText,
    required this.controller,
    this.keyboardType,
    this.maxLength,
    this.inputFormatters,
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

        // Input field with neomorphic design
        Container(
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
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            maxLength: maxLength,
            inputFormatters: inputFormatters,
            cursorColor: Theme.of(context).colorScheme.inversePrimary, // ← Cursor color
            cursorWidth: 2.0, // ← Cursor thickness (Apple style)
            cursorHeight: 20, // ← Curs
            style: GoogleFonts.dmSerifText( // ← Google Font for user input
              color: Theme.of(context).colorScheme.inversePrimary,
              fontSize: 18,
            ),
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: GoogleFonts.dmSerifText( // ← Google Font for hint text too
                color: Theme.of(context).colorScheme.inversePrimary.withOpacity(0.4),
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              counterText: '',
            ),
          ),
        ),
      ],
    );
  }
}