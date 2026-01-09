import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CalendarAppBar extends StatelessWidget {
  final VoidCallback onShare;
  final List<Map<String, String>> medications;
  final String? selectedMedicationId;
  final ValueChanged<String?> onMedicationChanged;
  final bool isLoading;

  const CalendarAppBar({
    Key? key,
    required this.onShare,
    required this.medications,
    required this.selectedMedicationId,
    required this.onMedicationChanged,
    this.isLoading = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Medication Dropdown
              Expanded(
                child: _buildMedicationDropdown(context),
              ),

              // Share button
              IconButton(
                icon: Icon(
                  Icons.ios_share,
                  color: Theme.of(context).colorScheme.inversePrimary,
                ),
                onPressed: onShare,
              ),
            ],
          ),
        ),
        _buildWeekDaysRow(context),
      ],
    );
  }

  Widget _buildMedicationDropdown(BuildContext context) {
    if (isLoading) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Theme.of(context).colorScheme.inversePrimary,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Loading...',
              style: GoogleFonts.dmSerifText(
                fontSize: 16,
                color: Theme.of(context).colorScheme.inversePrimary,
              ),
            ),
          ],
        ),
      );
    }

    // Get current selection display name
    String displayName = 'All Medications';
    if (selectedMedicationId != null) {
      final selectedMed = medications.firstWhere(
            (med) => med['id'] == selectedMedicationId,
        orElse: () => {'name': 'Unknown', 'strength': ''},
      );
      displayName = '${selectedMed['name']} ${selectedMed['strength']}'.trim();
    }

    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () => _showMedicationPicker(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
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
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                displayName,
                style: GoogleFonts.dmSerifText(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.inversePrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(
              Icons.arrow_drop_down,
              color: Theme.of(context).colorScheme.inversePrimary,
            ),
          ],
        ),
      ),
    );
  }

  void _showMedicationPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.inversePrimary.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Title
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Select Medication',
                  style: GoogleFonts.dmSerifText(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.inversePrimary,
                  ),
                ),
              ),

              // "All Medications" option
              _buildMedicationOption(
                context: context,
                id: null,
                name: 'All Medications',
                strength: '',
                isSelected: selectedMedicationId == null,
              ),

              const Divider(height: 1),

              // Individual medications
              ...medications.map((med) => _buildMedicationOption(
                context: context,
                id: med['id']!,
                name: med['name']!,
                strength: med['strength']!,
                isSelected: selectedMedicationId == med['id'],
              )),

              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMedicationOption({
    required BuildContext context,
    required String? id,
    required String name,
    required String strength,
    required bool isSelected,
  }) {
    return ListTile(
      onTap: () {
        onMedicationChanged(id);
        Navigator.pop(context);
      },
      leading: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.inversePrimary
                : Theme.of(context).colorScheme.inversePrimary.withOpacity(0.3),
            width: 2,
          ),
          color: isSelected
              ? Theme.of(context).colorScheme.inversePrimary
              : Colors.transparent,
        ),
        child: isSelected
            ? Icon(
          Icons.check,
          size: 16,
          color: Theme.of(context).colorScheme.primary,
        )
            : null,
      ),
      title: Text(
        name,
        style: GoogleFonts.dmSerifText(
          fontSize: 16,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          color: Theme.of(context).colorScheme.inversePrimary,
        ),
      ),
      subtitle: strength.isNotEmpty
          ? Text(
        strength,
        style: GoogleFonts.dmSerifText(
          fontSize: 14,
          color: Theme.of(context).colorScheme.inversePrimary.withOpacity(0.6),
        ),
      )
          : null,
    );
  }

  Widget _buildWeekDaysRow(BuildContext context) {
    const days = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: days.map((day) {
          return Expanded(
            child: Center(
              child: Text(
                day,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.inversePrimary.withOpacity(0.6),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}