import 'package:flutter/material.dart';

class SectionTile extends StatelessWidget {
  final IconData icon;
  final bool isRequired;
  final bool isDone;
  final bool isFullWidth;
  final VoidCallback onTap;

  const SectionTile({
    super.key,
    required this.icon,
    required this.isRequired,
    required this.isDone,
    this.isFullWidth = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: isFullWidth ? 180 : 140,
        padding: EdgeInsets.all(isFullWidth ? 20 : 16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
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
          ],
        ),
        child: Stack(
          children: [
            // Required badge (top-right corner)
            if (isRequired)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: Theme.of(context)
                          .colorScheme
                          .inversePrimary
                          .withOpacity(0.2),
                    ),
                  ),
                  child: Text(
                    'Required',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.redAccent.withOpacity(0.7),
                    ),
                  ),
                ),
              ),

            // Centered Icon
            Center(
              child: Icon(
                icon,
                color: isDone
                    ? Colors.green
                    : Theme.of(context).colorScheme.inversePrimary,
                size: isFullWidth ? 64 : 48,
              ),
            ),
          ],
        ),
      ),
    );
  }
}