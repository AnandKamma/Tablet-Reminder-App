import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tablet_reminder/Widgets/Input_Field_Button.dart';
import 'package:tablet_reminder/Widgets/dropdown_field_button.dart';
import 'package:tablet_reminder/Widgets/save_button.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MedicationScreen extends StatefulWidget {
  const MedicationScreen({super.key});

  @override
  State<MedicationScreen> createState() => _MedicationScreenState();
}

class _MedicationScreenState extends State<MedicationScreen> {
  // Controllers for text fields
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _strengthController = TextEditingController();

  // Dropdown value
  String? _frequency;

  // Track tablet ID and loading state
  bool isLoading = false;

  // Check if form is complete
  bool get canSave =>
      _nameController.text.isNotEmpty &&
          _strengthController.text.isNotEmpty &&
          _frequency != null &&
          !isLoading;

  @override
  void initState() {
    super.initState();
    _loadExistingData();
  }

  Future<void> _loadExistingData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final name = prefs.getString('medication_name');
      final strength = prefs.getString('medication_strength');
      final frequency = prefs.getString('medication_frequency');

      if (name != null && mounted) {
        setState(() {
          _nameController.text = name;
          if (strength != null) _strengthController.text = strength;
          if (frequency != null) _frequency = frequency;
        });
        print("✅ Loaded medication data from SharedPreferences");
      }
    } catch (e) {
      print("❌ Error loading medication data: $e");
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _strengthController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: Text(
          'Medication',
          style: GoogleFonts.dmSerifText(
            fontSize: 30,
            color: Theme.of(context).colorScheme.inversePrimary,
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  // Name of Medication
                  Padding(
                    padding: const EdgeInsets.all(5.0),
                    child: InputField(
                      label: 'Name of the Medication',
                      hintText: 'e.g., Keppra',
                      controller: _nameController,
                      inputFormatters: [
                        // Allow only letters and spaces
                        FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z ]')),
                        // Capitalize first letter
                        TextInputFormatter.withFunction((oldValue, newValue) {
                          if (newValue.text.isEmpty) return newValue;
                          final capitalized = newValue.text[0].toUpperCase() +
                              (newValue.text.length > 1
                                  ? newValue.text.substring(1)
                                  : '');
                          return newValue.copyWith(text: capitalized);
                        }),
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Strength
                  InputField(
                    label: 'Strength of your Medication',
                    hintText: 'e.g., 500mg',
                    controller: _strengthController,
                  ),

                  const SizedBox(height: 40),

                  // Frequency Dropdown
                  DropdownField(
                    label: 'How many times per day do you take it?',
                    value: _frequency,
                    items: const ['Once', 'Twice', 'Thrice'],
                    onChanged: (value) {
                      setState(() {
                        _frequency = value;
                      });
                    },
                  ),
                ],
              ),
            ),
          ),

          // Save Button
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 60.0, horizontal: 30),
            child: isLoading
                ? CircularProgressIndicator(
              color: Theme.of(context).colorScheme.inversePrimary,
            )
                : SaveButton(
              enabled: canSave,
              onTap: () async {
                if (!canSave) return;

                setState(() {
                  isLoading = true;
                });

                try {
                  final prefs = await SharedPreferences.getInstance();

                  // Save medication data to SharedPreferences
                  await prefs.setString('medication_name', _nameController.text.trim());
                  await prefs.setString('medication_strength', _strengthController.text.trim());
                  await prefs.setString('medication_frequency', _frequency!);

                  print('✅ Medication saved to SharedPreferences!');
                  print('   Name: ${_nameController.text.trim()}');
                  print('   Strength: ${_strengthController.text.trim()}');
                  print('   Frequency: $_frequency');

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            Icon(Icons.check_circle, color: Colors.white),
                            SizedBox(width: 12),
                            Text(
                              'Medication saved!',
                              style: GoogleFonts.dmSerifText(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        backgroundColor: Colors.green.shade600,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        margin: EdgeInsets.all(16),
                        duration: Duration(seconds: 2),
                        elevation: 6,
                      ),
                    );
                    Navigator.pop(context, true); // Return true to indicate success
                  }
                } catch (e) {
                  print('❌ Error saving medication: $e');
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            Icon(Icons.error_outline, color: Colors.white),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Error: ${e.toString()}',
                                style: GoogleFonts.dmSerifText(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        backgroundColor: Colors.red.shade600,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        margin: EdgeInsets.all(16),
                        duration: Duration(seconds: 3),
                        elevation: 6,
                      ),
                    );
                  }
                } finally {
                  if (mounted) {
                    setState(() {
                      isLoading = false;
                    });
                  }
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}