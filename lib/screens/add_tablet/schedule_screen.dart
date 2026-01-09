import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tablet_reminder/Widgets/Day_selector.dart';
import 'package:tablet_reminder/Widgets/toggle_switch.dart';
import 'package:tablet_reminder/Widgets/time_picker.dart';
import 'package:tablet_reminder/widgets/save_button.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  // Selected days
  List<String> _selectedDays = [];

  // Frequency (fetched from medication)
  String? _frequency;

  // Time selections based on frequency
  TimeOfDay? _time1;
  TimeOfDay? _time2;
  TimeOfDay? _time3;

  // Toggle switches
  bool _reminderEnabled = false;
  bool _alarmEnabled = false;

  // Loading states
  bool isLoadingData = true;
  bool isSaving = false;


  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // Load medication frequency and existing schedule data
// Load medication frequency and existing schedule data from SharedPreferences
  Future<void> _loadData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Get frequency from SharedPreferences (saved by Medication screen)
      final frequency = prefs.getString('medication_frequency');

      if (frequency == null) {
        print("❌ No medication frequency found");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.white),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Please complete Medication section first',
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
          Navigator.pop(context);
        }
        return;
      }

      // Load existing schedule data from SharedPreferences
      final daysString = prefs.getString('schedule_days');
      final time1String = prefs.getString('schedule_time1');
      final time2String = prefs.getString('schedule_time2');
      final time3String = prefs.getString('schedule_time3');
      final reminderEnabled = prefs.getBool('schedule_reminder') ?? false;
      final alarmEnabled = prefs.getBool('schedule_alarm') ?? false;

      if (mounted) {
        setState(() {
          _frequency = frequency;

          // Load existing schedule if available
          if (daysString != null) {
            _selectedDays = daysString.split(',');
          }
          if (time1String != null) {
            _time1 = _parseTimeString(time1String);
          }
          if (time2String != null) {
            _time2 = _parseTimeString(time2String);
          }
          if (time3String != null) {
            _time3 = _parseTimeString(time3String);
          }
          _reminderEnabled = reminderEnabled;
          _alarmEnabled = alarmEnabled;

          isLoadingData = false;
        });
        print("✅ Loaded frequency from SharedPreferences: $_frequency");
      }
    } catch (e) {
      print("❌ Error loading data: $e");
      if (mounted) {
        setState(() {
          isLoadingData = false;
        });
      }
    }
  }
  // Helper to parse time string "08:00 AM" to TimeOfDay
  TimeOfDay? _parseTimeString(String timeStr) {
    try {
      final parts = timeStr.split(' ');
      final timeParts = parts[0].split(':');
      int hour = int.parse(timeParts[0]);
      final minute = int.parse(timeParts[1]);
      final isPM = parts[1] == 'PM';

      if (isPM && hour != 12) hour += 12;
      if (!isPM && hour == 12) hour = 0;

      return TimeOfDay(hour: hour, minute: minute);
    } catch (e) {
      print("Error parsing time: $e");
      return null;
    }
  }

  // Helper to format TimeOfDay to "08:00 AM"
  String _formatTime(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  // Get number of time pickers based on frequency
  int get _numberOfTimes {
    switch (_frequency) {
      case 'Once':
        return 1;
      case 'Twice':
        return 2;
      case 'Thrice':
        return 3;
      default:
        return 1;
    }
  }

  // Check if form is complete
  bool get canSave {
    if (_selectedDays.isEmpty || isSaving) return false;

    switch (_numberOfTimes) {
      case 1:
        return _time1 != null;
      case 2:
        return _time1 != null && _time2 != null;
      case 3:
        return _time1 != null && _time2 != null && _time3 != null;
      default:
        return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoadingData) {
      return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.transparent,
          title: Text(
            'Schedule',
            style: GoogleFonts.dmSerifText(
              fontSize: 30,
              color: Theme.of(context).colorScheme.inversePrimary,
            ),
          ),
        ),
        body: Center(
          child: CircularProgressIndicator(
            color: Theme.of(context).colorScheme.inversePrimary,
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: Text(
          'Schedule',
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
                  // Day Selector
                  DaySelector(
                    selectedDays: _selectedDays,
                    onChanged: (days) {
                      setState(() {
                        _selectedDays = days;
                      });
                    },
                  ),

                  const SizedBox(height: 40),

                  // Time Pickers (dynamic based on frequency)
                  if (_numberOfTimes >= 1) ...[
                    TimePickerField(
                      label: _numberOfTimes == 1
                          ? 'What time do you take it?'
                          : 'First Dose Time',
                      selectedTime: _time1,
                      onTimeSelected: (time) {
                        setState(() {
                          _time1 = time;
                        });
                      },
                    ),
                    const SizedBox(height: 25),
                  ],

                  if (_numberOfTimes >= 2) ...[
                    TimePickerField(
                      label: 'Second Dose Time',
                      selectedTime: _time2,
                      onTimeSelected: (time) {
                        setState(() {
                          _time2 = time;
                        });
                      },
                    ),
                    const SizedBox(height: 25),
                  ],

                  if (_numberOfTimes >= 3) ...[
                    TimePickerField(
                      label: 'Third Dose Time',
                      selectedTime: _time3,
                      onTimeSelected: (time) {
                        setState(() {
                          _time3 = time;
                        });
                      },
                    ),
                  ],

                  const SizedBox(height: 40),

                  // Reminder Toggle
                  ToggleSwitchField(
                    label: 'Reminder',
                    value: _reminderEnabled,
                    onChanged: (value) {
                      setState(() {
                        _reminderEnabled = value;
                      });
                    },
                  ),

                  const SizedBox(height: 40),

                  // Alarm Toggle
                  ToggleSwitchField(
                    label: 'Alarm',
                    value: _alarmEnabled,
                    onChanged: (value) {
                      setState(() {
                        _alarmEnabled = value;
                      });
                    },
                  ),
                  const SizedBox(height: 40),

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

                          // Save schedule data to SharedPreferences
                          await prefs.setString('schedule_days', _selectedDays.join(','));
                          if (_time1 != null) {
                            await prefs.setString('schedule_time1', _formatTime(_time1!));
                          }
                          if (_time2 != null) {
                            await prefs.setString('schedule_time2', _formatTime(_time2!));
                          }
                          if (_time3 != null) {
                            await prefs.setString('schedule_time3', _formatTime(_time3!));
                          }
                          await prefs.setBool('schedule_reminder', _reminderEnabled);
                          await prefs.setBool('schedule_alarm', _alarmEnabled);

                          print('✅ Schedule saved to SharedPreferences!');
                          print('   Days: $_selectedDays');
                          print('   Time1: ${_time1 != null ? _formatTime(_time1!) : "null"}');
                          print('   Time2: ${_time2 != null ? _formatTime(_time2!) : "null"}');
                          print('   Time3: ${_time3 != null ? _formatTime(_time3!) : "null"}');
                          print('   Reminder: $_reminderEnabled');
                          print('   Alarm: $_alarmEnabled');

                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Row(
                                  children: [
                                    Icon(Icons.check_circle, color: Colors.white),
                                    SizedBox(width: 12),
                                    Text(
                                      'Schedule saved!',
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
                          print('❌ Error saving schedule: $e');
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
            ),
          ),
        ],
      ),
    );
  }
}