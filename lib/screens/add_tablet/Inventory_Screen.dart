import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tablet_reminder/Widgets/number_picker.dart';
import 'package:tablet_reminder/Widgets/toggle_switch.dart';
import 'package:tablet_reminder/widgets/save_button.dart';
import 'package:shared_preferences/shared_preferences.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  // How many meds filled in device
  int _medsInDevice = 18;

  // Refill reminder toggle
  bool _refillReminderEnabled = false;

  // Refill threshold (only shown if reminder enabled)
  int _refillThreshold = 5;

  // Loading state
  bool isSaving = false;

  // Check if form is complete (optional section)
  bool get canSave => !isSaving;

  @override
  void initState() {
    super.initState();
    _loadExistingData();
  }

  // Load existing inventory data from SharedPreferences
  Future<void> _loadExistingData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final medsInDevice = prefs.getInt('inventory_medsInDevice');
      final refillEnabled = prefs.getBool('inventory_refillEnabled');
      final refillThreshold = prefs.getInt('inventory_refillThreshold');

      if (medsInDevice != null && mounted) {
        setState(() {
          _medsInDevice = medsInDevice;
          _refillReminderEnabled = refillEnabled ?? false;
          _refillThreshold = refillThreshold ?? 5;
        });
        print("✅ Loaded inventory data from SharedPreferences");
      }
    } catch (e) {
      print("❌ Error loading inventory data: $e");
    }
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
          'Inventory',
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // How many meds in device
                  NumberPickerField(
                    label: 'How many meds do you fill in the device at a time?',
                    value: _medsInDevice,
                    minValue: 1,
                    maxValue: 100,
                    onChanged: (value) {
                      setState(() {
                        _medsInDevice = value;
                      });
                    },
                  ),

                  const SizedBox(height: 40),

                  // Refill Reminder Toggle
                  ToggleSwitchField(
                    label: 'Refill Reminder',
                    value: _refillReminderEnabled,
                    onChanged: (value) {
                      setState(() {
                        _refillReminderEnabled = value;
                      });
                    },
                  ),

                  // Helper text for refill reminder
                  Padding(
                    padding: const EdgeInsets.only(left: 10.0, top: 20.0),
                    child: Text(
                      'By enabling, you will receive reminders to refill your device with medications',
                      style: GoogleFonts.dmSerifText(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: Theme.of(context)
                            .colorScheme
                            .inversePrimary
                            .withOpacity(0.7),
                      ),
                    ),
                  ),

                  // Refill Threshold (only show if reminder enabled)
                  if (_refillReminderEnabled) ...[
                    const SizedBox(height: 20),
                    NumberPickerField(
                      label: 'Refill Threshold',
                      value: _refillThreshold,
                      minValue: 1,
                      maxValue: _medsInDevice - 1,
                      onChanged: (value) {
                        setState(() {
                          _refillThreshold = value;
                        });
                      },
                      helperText:
                      'If your meds in the device are below this number, you will get a reminder',
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Save Button
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 30),
            child: isSaving
                ? CircularProgressIndicator(
              color: Theme.of(context).colorScheme.inversePrimary,
            )
                : SaveButton(
              enabled: canSave,
              onTap: () async {
                if (!canSave) return;

                setState(() {
                  isSaving = true;
                });

                try {
                  final prefs = await SharedPreferences.getInstance();

                  // Save inventory data to SharedPreferences
                  await prefs.setInt('inventory_medsInDevice', _medsInDevice);
                  await prefs.setBool('inventory_refillEnabled', _refillReminderEnabled);
                  if (_refillReminderEnabled) {
                    await prefs.setInt('inventory_refillThreshold', _refillThreshold);
                  } else {
                    await prefs.remove('inventory_refillThreshold');
                  }

                  print('✅ Inventory saved to SharedPreferences!');
                  print('   Meds in Device: $_medsInDevice');
                  print('   Refill Reminder: $_refillReminderEnabled');
                  if (_refillReminderEnabled) {
                    print('   Refill Threshold: $_refillThreshold');
                  }

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            Icon(Icons.check_circle, color: Colors.white),
                            SizedBox(width: 12),
                            Text(
                              'Inventory saved!',
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
                    Navigator.pop(context, true);
                  }
                } catch (e) {
                  print('❌ Error saving inventory: $e');
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
                      isSaving = false;
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