import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tablet_reminder/Widgets/Add_tablet_tile.dart';
import 'package:tablet_reminder/Widgets/save_button.dart';
import 'package:tablet_reminder/Widgets/Navigation_Animations.dart';
import 'package:tablet_reminder/screens/add_tablet/Caregivers_screen.dart';
import 'package:tablet_reminder/screens/add_tablet/Inventory_Screen.dart';
import 'package:tablet_reminder/screens/add_tablet/Medication_Page.dart';
import 'package:tablet_reminder/screens/add_tablet/schedule_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_reminder/components/Backend_Integration/Firebase_Backend.dart';
import 'package:tablet_reminder/components/Backend_Integration/models/medication_model.dart';
import 'package:tablet_reminder/components/Backend_Integration/models/schedule_model.dart';
import 'package:tablet_reminder/components/Backend_Integration/models/inventory_model.dart';
import 'package:tablet_reminder/components/Backend_Integration/models/caregivers_model.dart';
import 'package:tablet_reminder/components/notifications_service.dart';
import 'package:tablet_reminder/components/Backend_Integration/Role_detection.dart';
import 'package:alarm/alarm.dart';

class AddTabletHomePage extends StatefulWidget {

  final String? editTabletId; // Add this parameter

  const AddTabletHomePage({super.key,this.editTabletId});

  @override
  State<AddTabletHomePage> createState() => _AddTabletHomePageState();
}

class _AddTabletHomePageState extends State<AddTabletHomePage> {
  // Track completion status
  bool medicationDone = false;
  bool scheduleDone = false;
  bool isSaving = false;
  bool isLoadingTablet = false;
  bool get canSave => medicationDone && scheduleDone;
  bool get isEditMode => widget.editTabletId != null;
  bool useAlarmInsteadOfNotification = false;


  @override
  void initState() {
    super.initState();
    if (isEditMode) {
      _loadExistingTablet();
    } else {
      _clearCurrentTablet();
    }
    _checkCompletion();
  }

  // Load existing tablet data for editing
  Future<void> _loadExistingTablet() async {
    setState(() {
      isLoadingTablet = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final patientGroupID = prefs.getString('patientGroupID');

      if (patientGroupID == null || widget.editTabletId == null) {
        print("❌ Missing patientGroupID or tabletId");
        return;
      }

      final backend = FirebaseBackend();
      final tabletData = await backend.getCompleteTablet(
        patientGroupID: patientGroupID,
        tabletId: widget.editTabletId!,
      );

      if (tabletData != null) {
        // Store tablet ID for updating
        await prefs.setString('editingTabletId', widget.editTabletId!);

        // Load Medication data
        if (tabletData['medication'] != null) {
          final med = tabletData['medication'];
          await prefs.setString('medication_name', med['name'] ?? '');
          await prefs.setString('medication_strength', med['strength'] ?? '');
          await prefs.setString(
            'medication_frequency',
            med['frequency'] ?? 'Once',
          );
        }

        // Load Schedule data
        if (tabletData['schedule'] != null) {
          final sched = tabletData['schedule'];
          await prefs.setString(
            'schedule_days',
            (sched['daysOfWeek'] as List).join(','),
          );

          final times = sched['times'] as List;
          if (times.isNotEmpty)
            await prefs.setString('schedule_time1', times[0]);
          if (times.length > 1)
            await prefs.setString('schedule_time2', times[1]);
          if (times.length > 2)
            await prefs.setString('schedule_time3', times[2]);

          await prefs.setBool(
            'schedule_reminder',
            sched['reminderEnabled'] ?? false,
          );
          await prefs.setBool('schedule_alarm', sched['alarmEnabled'] ?? false);
        }

        // Load Inventory data (optional)
        if (tabletData['inventory'] != null) {
          final inv = tabletData['inventory'];
          await prefs.setInt(
            'inventory_medsInDevice',
            inv['pillsPerRefill'] ?? 18,
          );
          await prefs.setBool(
            'inventory_refillEnabled',
            inv['refillReminderEnabled'] ?? false,
          );
          if (inv['refillReminderQuantity'] != null) {
            await prefs.setInt(
              'inventory_refillThreshold',
              inv['refillReminderQuantity'],
            );
          }
        }

        // Load Caregiver settings (optional)
        if (tabletData['caregiverSettings'] != null) {
          final cg = tabletData['caregiverSettings'];
          await prefs.setBool(
            'caregiver_notify',
            cg['notifyCaregivers'] ?? false,
          );
          if (cg['lateWindow'] != null) {
            await prefs.setString('caregiver_lateWindow', cg['lateWindow']);
          }
        }

        print("✅ Loaded existing tablet data for editing");
      }
    } catch (e) {
      print("❌ Error loading tablet for editing: $e");
    } finally {
      setState(() {
        isLoadingTablet = false;
      });
    }
  }

  // Add this new function
  Future<void> _clearCurrentTablet() async {
    final prefs = await SharedPreferences.getInstance();
    // Clear all tablet-related data
    await prefs.remove('medication_name');
    await prefs.remove('medication_strength');
    await prefs.remove('medication_frequency');
    await prefs.remove('schedule_days');
    await prefs.remove('schedule_time1');
    await prefs.remove('schedule_time2');
    await prefs.remove('schedule_time3');
    await prefs.remove('schedule_reminder');
    await prefs.remove('schedule_alarm');
    await prefs.remove('inventory_medsInDevice');
    await prefs.remove('inventory_refillEnabled');
    await prefs.remove('inventory_refillThreshold');
    await prefs.remove('caregiver_notify');
    await prefs.remove('caregiver_lateWindow');
    print("🔄 Cleared all tablet data - Starting fresh");
  }

  Future<void> _checkCompletion() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      medicationDone =
          prefs.getString('medication_name') != null &&
          prefs.getString('medication_strength') != null &&
          prefs.getString('medication_frequency') != null;

      scheduleDone =
          prefs.getString('schedule_days') != null &&
          prefs.getString('schedule_time1') != null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,

      appBar: AppBar(elevation: 0, backgroundColor: Colors.transparent),

      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 30.0),
            child: Text(
              isEditMode ? 'Edit Medication' : 'Add Medication',
              style: GoogleFonts.dmSerifText(
                fontSize: 48,
                color: Theme.of(context).colorScheme.inversePrimary,
              ),
            ),
          ),

          // Instruction text
          Padding(
            padding: const EdgeInsets.only(left: 30.0, top: 20, bottom: 20),
            child: Text(
              'Complete the sections below',
              style: GoogleFonts.dmSerifText(
                fontSize: 14,
                color: Theme.of(
                  context,
                ).colorScheme.inversePrimary.withOpacity(0.6),
              ),
            ),
          ),

          // MEDICATION TILE (Full Width)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30.0),
            child: Row(
              children: [
                // SCHEDULE TILE (Left)
                Expanded(
                  child: SectionTile(
                    icon: Icons.local_hospital,
                    isRequired: true,
                    isDone: false,
                    isFullWidth: false,
                    onTap: () async {
                      await NavigationUtils.navigateWithIOSScale(
                        context,
                        const MedicationScreen(),
                      );
                      await _checkCompletion(); // Always check after returning
                    },
                  ),
                ),

                const SizedBox(width: 30), // Space between tiles
                // CAREGIVERS TILE (Right)
                Expanded(
                  child: SectionTile(
                    icon: Icons.alarm,
                    isRequired: true,
                    isDone: false,
                    isFullWidth: false,
                    onTap: () async {
                      await NavigationUtils.navigateWithIOSScale(
                        context,
                        const ScheduleScreen(),
                      );
                      await _checkCompletion(); // Always check after returning
                    },
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 40),

          // SCHEDULE & CAREGIVERS ROW (Half Width Each)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30.0),
            child: Row(
              children: [
                // SCHEDULE TILE (Left)
                Expanded(
                  child: SectionTile(
                    icon: Icons.inventory,
                    isRequired: false,
                    isDone: false,
                    isFullWidth: false,
                    onTap: () {
                      // TODO: Navigate to schedule form
                      NavigationUtils.navigateWithIOSScale(
                        context,
                        const InventoryScreen(),
                      );
                    },
                  ),
                ),

                const SizedBox(width: 30), // Space between tiles
                // CAREGIVERS TILE (Right)
                Expanded(
                  child: SectionTile(
                    icon: Icons.people,
                    isRequired: false,
                    isDone: false,
                    isFullWidth: false,
                    onTap: () {
                      // TODO: Navigate to caregivers form
                      NavigationUtils.navigateWithIOSScale(
                        context,
                        const CaregiversScreen(),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 50),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30.0),
            child: isSaving
                ? Center(
                    child: CircularProgressIndicator(
                      color: Theme.of(context).colorScheme.inversePrimary,
                    ),
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
                        final patientGroupID = prefs.getString(
                          'patientGroupID',
                        );
                        final editingTabletId = prefs.getString(
                          'editingTabletId',
                        );

                        if (patientGroupID == null) {
                          throw Exception("No patient group found");
                        }

                        // Read all data from SharedPreferences
                        final medication = MedicationModel(
                          name: prefs.getString('medication_name')!,
                          strength: prefs.getString('medication_strength')!,
                          frequency: prefs.getString('medication_frequency')!,
                        );

                        List<String> times = [];
                        final time1 = prefs.getString('schedule_time1');
                        final time2 = prefs.getString('schedule_time2');
                        final time3 = prefs.getString('schedule_time3');
                        if (time1 != null) times.add(time1);
                        if (time2 != null) times.add(time2);
                        if (time3 != null) times.add(time3);

                        final schedule = ScheduleModel(
                          daysOfWeek: prefs
                              .getString('schedule_days')!
                              .split(','),
                          times: times,
                          reminderEnabled:
                              prefs.getBool('schedule_reminder') ?? false,
                          alarmEnabled:
                              prefs.getBool('schedule_alarm') ?? false,
                        );

                        InventoryModel? inventory;
                        final medsInDevice = prefs.getInt(
                          'inventory_medsInDevice',
                        );
                        if (medsInDevice != null) {
                          inventory = InventoryModel(
                            pillsPerRefill: medsInDevice,
                            refillReminderEnabled:
                                prefs.getBool('inventory_refillEnabled') ??
                                false,
                            refillReminderQuantity: prefs.getInt(
                              'inventory_refillThreshold',
                            ),
                          );
                        }

                        CaregiverSettingsModel? caregiverSettings;
                        if (prefs.containsKey('caregiver_notify')) {
                          caregiverSettings = CaregiverSettingsModel(
                            notifyCaregivers:
                                prefs.getBool('caregiver_notify') ?? false,
                            lateWindow: prefs.getString('caregiver_lateWindow'),
                          );
                        }

                        final backend = FirebaseBackend();

                        String finalTabletId;

                        if (isEditMode && editingTabletId != null) {
                          // UPDATE existing tablet
                          await backend.updateCompleteTablet(
                            patientGroupID: patientGroupID,
                            tabletId: editingTabletId,
                            medication: medication,
                            schedule: schedule,
                            inventory: inventory,
                            caregiverSettings: caregiverSettings,
                          );
                          finalTabletId = editingTabletId;
                          print('✅ Tablet updated in Firebase! ID: $editingTabletId');

                          // Cancel old notifications before scheduling new ones
                          final notiService = NotiService();
                          await notiService.cancelTabletNotifications(editingTabletId, schedule.times.length);
                        } else {
                          // CREATE new tablet
                          finalTabletId = await backend.saveCompleteTablet(
                            patientGroupID: patientGroupID,
                            medication: medication,
                            schedule: schedule,
                            inventory: inventory,
                            caregiverSettings: caregiverSettings,
                          );
                          print('✅ New tablet saved to Firebase! ID: $finalTabletId');
                        }

                        // Schedule alarms OR notifications if reminder is enabled
                        if (schedule.reminderEnabled) {
                          final roleService = UserRoleService();
                          final isPatient = await roleService.isPatient();

                          if (isPatient) {
                            // ALWAYS schedule notifications first
                            final notiService = NotiService();
                            await notiService.scheduleTabletNotifications(
                              tabletId: finalTabletId,
                              medicationName: medication.name,
                              daysOfWeek: schedule.daysOfWeek,
                              times: schedule.times,
                            );
                            print('✅ Notifications scheduled for ${medication.name}');

                            // ALSO schedule alarms if enabled
                            if (schedule.alarmEnabled) {
                              await _scheduleAlarms(
                                tabletId: finalTabletId,
                                medicationName: medication.name,
                                daysOfWeek: schedule.daysOfWeek,
                                times: schedule.times,
                              );
                              print('🚨 Alarms ALSO scheduled for ${medication.name}');
                            }
                          } else {
                            print('⚠️ Skipping reminders - user is a caregiver (view-only)');
                          }
                        }
                        await _clearCurrentTablet();

                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Row(
                                children: [
                                  Icon(Icons.check_circle, color: Colors.white),
                                  SizedBox(width: 12),
                                  Text(
                                    isEditMode
                                        ? 'Tablet updated successfully!'
                                        : 'Tablet saved successfully!',
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
                          Navigator.pop(
                            context,
                            true,
                          ); // Return true to refresh list
                        }
                      } catch (e) {
                        print('❌ Error saving/updating tablet: $e');
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Row(
                                children: [
                                  Icon(
                                    Icons.error_outline,
                                    color: Colors.white,
                                  ),
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

  Future<void> _scheduleAlarms({
    required String tabletId,
    required String medicationName,
    required List<String> daysOfWeek,
    required List<String> times,
  }) async {
    for (int i = 0; i < times.length; i++) {
      final timeStr = times[i];
      final parsedTime = _parseTime(timeStr);

      if (parsedTime == null) continue;

      // Calculate next occurrence of this time
      final now = DateTime.now();
      DateTime scheduledDateTime = DateTime(
        now.year,
        now.month,
        now.day,
        parsedTime['hour']!,
        parsedTime['minute']!,
      );

      // If time has passed today, schedule for tomorrow
      if (scheduledDateTime.isBefore(now)) {
        scheduledDateTime = scheduledDateTime.add(const Duration(days: 1));
      }

      // Create unique alarm ID
      final alarmId = tabletId.hashCode + i;

      final alarmSettings = AlarmSettings(
        id: alarmId,
        dateTime: scheduledDateTime,
        assetAudioPath: 'assets/sounds/philippines-eas-alarm-427006.mp3',
        loopAudio: true,
        vibrate: true,
        volumeSettings:
        VolumeSettings.fixed(
      volume: 1,
          volumeEnforced:false
      ),
        warningNotificationOnKill: true,
        androidFullScreenIntent: true,

        notificationSettings: NotificationSettings(
          title: 'Medication Reminder',
          body: 'Time to take $medicationName',
          stopButton: 'Stop',
        ),
      );

      await Alarm.set(alarmSettings: alarmSettings);
      print('🚨 Alarm set for $medicationName at $timeStr (ID: $alarmId)');
    }


  }
  // Helper to parse time string "8:00 AM" to hour/minute
  Map<String, int>? _parseTime(String timeStr) {
    try {
      final parts = timeStr.split(' ');
      final timeParts = parts[0].split(':');
      int hour = int.parse(timeParts[0]);
      final minute = int.parse(timeParts[1]);
      final isPM = parts[1] == 'PM';

      if (isPM && hour != 12) hour += 12;
      if (!isPM && hour == 12) hour = 0;

      return {'hour': hour, 'minute': minute};
    } catch (e) {
      print('❌ Error parsing time: $timeStr - $e');
      return null;
    }
  }




}
