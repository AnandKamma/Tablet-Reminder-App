import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tablet_reminder/Widgets/toggle_switch.dart';
import 'package:tablet_reminder/Widgets/late_window_picker.dart';
import 'package:tablet_reminder/widgets/save_button.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CaregiversScreen extends StatefulWidget {
  const CaregiversScreen({super.key});

  @override
  State<CaregiversScreen> createState() => _CaregiversScreenState();
}

class _CaregiversScreenState extends State<CaregiversScreen> {
  // Toggle for notify caregivers
  bool _notifyCaregivers = false;

  // Late window selection
  String? _lateWindow;

  // Loading state
  bool isSaving = false;

  // Check if form is complete (optional - user can skip this section)
  bool get canSave => !isSaving;

  @override
  void initState() {
    super.initState();
    _loadExistingData();
  }

  // Load existing caregiver settings from SharedPreferences
  Future<void> _loadExistingData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final notifyCaregivers = prefs.getBool('caregiver_notify');
      final lateWindow = prefs.getString('caregiver_lateWindow');

      if (notifyCaregivers != null && mounted) {
        setState(() {
          _notifyCaregivers = notifyCaregivers;
          _lateWindow = lateWindow;
        });
        print("✅ Loaded caregiver settings from SharedPreferences");
      }
    } catch (e) {
      print("❌ Error loading caregiver settings: $e");
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
          'Caregivers',
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
                  // Notify Caregivers Toggle
                  ToggleSwitchField(
                    label: 'Notify Caregivers',
                    value: _notifyCaregivers,
                    onChanged: (value) {
                      setState(() {
                        _notifyCaregivers = value;
                      });
                    },
                  ),

                  // Helper text for notify caregivers
                  Padding(
                    padding: const EdgeInsets.only(left: 10.0, top: 20.0),
                    child: Text(
                      'Your caregivers will get a notification that you have taken your meds',
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

                  const SizedBox(height: 40),

                  // Late Window Picker
                  LateWindowPicker(
                    label: 'Late Window',
                    value: _lateWindow,
                    items: const ['2 Min', '5 Min', '10 Min', '20 Min'],
                    onChanged: (value) {
                      setState(() {
                        _lateWindow = value;
                      });
                    },
                  ),

                  // Helper text for late window
                  Padding(
                    padding: const EdgeInsets.only(left: 10.0, top: 20.0),
                    child: Text(
                      'Caregivers will be notified if you miss your medication past this time window',
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

                  // Save caregiver settings to SharedPreferences
                  await prefs.setBool('caregiver_notify', _notifyCaregivers);
                  if (_lateWindow != null) {
                    await prefs.setString('caregiver_lateWindow', _lateWindow!);
                  } else {
                    await prefs.remove('caregiver_lateWindow');
                  }

                  print('✅ Caregiver settings saved to SharedPreferences!');
                  print('   Notify Caregivers: $_notifyCaregivers');
                  print('   Late Window: $_lateWindow');

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            Icon(Icons.check_circle, color: Colors.white),
                            SizedBox(width: 12),
                            Text(
                              'Caregiver settings saved!',
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
                  print('❌ Error saving caregiver settings: $e');
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