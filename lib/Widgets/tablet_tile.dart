import 'package:flutter/material.dart';

class TabletTile extends StatelessWidget {
  final String name;
  final String? strength;
  final String? time;
  final bool taken;
  final String status; // ADD THIS: "taken_on_time", "taken_late", "missed", "pending"
  final void Function()? onTap;
  final void Function()? onLongPress;

  const TabletTile({
    super.key,
    required this.name,
    this.strength,
    this.time,
    required this.taken,
    required this.status, // ADD THIS
    required this.onTap,
    required this.onLongPress,
  });

  // Helper to get color based on status
  Color _getTextColor(BuildContext context) {
    switch (status) {
      case 'taken_on_time':
        return Colors.green; // Green for taken on time
      case 'taken_late':
        return Colors.orange; // Yellow/Orange for taken late
      case 'missed':
        return Colors.red; // Red for missed
      default:
        return Theme.of(context).colorScheme.inversePrimary; // Default
    }
  }

  // Helper to determine if strikethrough should show
  bool get _shouldStrikethrough {
    return status == 'taken_on_time' || status == 'taken_late';
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = _getTextColor(context);

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: isDarkMode ? Colors.black : Colors.grey.shade500,
              offset: const Offset(5, 5),
              blurRadius: 15,
              spreadRadius: 5,
            ),
            BoxShadow(
              color: isDarkMode ? Colors.grey.shade800 : Colors.white,
              offset: const Offset(-4, -4),
              blurRadius: 15,
              spreadRadius: 1,
            ),
          ],
        ),
        margin: const EdgeInsets.only(top: 10, left: 25, right: 25, bottom: 10),
        child: ListTile(
          title: Text(
            name,
            style: TextStyle(
              color: textColor,
              decoration: _shouldStrikethrough ? TextDecoration.lineThrough : null,
              decorationColor: textColor,
              decorationThickness: 2,
            ),
          ),
          subtitle: strength != null || time != null
              ? Text(
            '${strength ?? ""} ${time != null ? "• $time" : ""}',
            style: TextStyle(
              color: textColor.withOpacity(0.7),
              decoration: _shouldStrikethrough ? TextDecoration.lineThrough : null,
              decorationColor: textColor,
            ),
          )
              : null,
        ),
      ),
    );
  }
}