import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_reminder/screens/CaregiverManagemntPage.dart';
import 'package:tablet_reminder/Widgets/drawer_tile.dart';
import 'package:tablet_reminder/screens/AddTablet_HomePage.dart';
import 'package:tablet_reminder/Widgets/Navigation_Animations.dart';
import 'package:tablet_reminder/components/Backend_Integration/Firebase_Backend.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tablet_reminder/components/notifications_service.dart';
import 'package:tablet_reminder/components/Backend_Integration/Role_detection.dart';
import 'package:alarm/alarm.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:tablet_reminder/Widgets/3dPill.dart';

class MyDrawer extends StatefulWidget {
  const MyDrawer({super.key});

  @override
  State<MyDrawer> createState() => _MyDrawerState();
}

class _MyDrawerState extends State<MyDrawer> {

  final GlobalKey _tapToEditKey = GlobalKey();
  final GlobalKey _holdToDeleteKey = GlobalKey();
  List<Map<String, dynamic>> tablets = [];
  bool isLoadingTablets = true;
  final UserRoleService _roleService = UserRoleService();
  bool isPatient = true;


  @override
  void initState() {
    super.initState();
    _loadTablets();
    _checkUserRole();
    ShowcaseView.register(
      onComplete: (index, key) {
        print('Showcase completed: $index');
      },
      onDismiss: (key) {
        print('Showcase dismissed');
      },
    );

  }

  @override
  void dispose() {
    ShowcaseView.get().unregister();  // ✅ ADD THIS
    super.dispose();
  }

  Future<void> _checkUserRole() async {
    final patient = await _roleService.isPatient();
    if (mounted) {
      setState(() {
        isPatient = patient;
      });
    }
  }

  Future<void> _loadTablets() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final patientGroupID = prefs.getString('patientGroupID');

      if (patientGroupID == null) {
        print("❌ No patient group found");
        if (mounted) {
          setState(() {
            isLoadingTablets = false;
          });
        }
        return;
      }

      final backend = FirebaseBackend();
      final fetchedTablets = await backend.getAllTabletsWithIds(patientGroupID);

      if (mounted) {
        setState(() {
          tablets = fetchedTablets;
          isLoadingTablets = false;
        });
      }

      print("✅ Loaded ${tablets.length} tablets");
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkAndStartTutorial();
      });
    } catch (e) {
      print("❌ Error loading tablets: $e");
      if (mounted) {
        setState(() {
          isLoadingTablets = false;
        });
      }
    }
  }
  Future<void> _deleteTablet(String tabletId, String tabletName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final patientGroupID = prefs.getString('patientGroupID');

      if (patientGroupID == null) return;

      final backend = FirebaseBackend();

      final tabletData = await backend.getCompleteTablet(
        patientGroupID: patientGroupID,
        tabletId: tabletId,
      );

      if (tabletData != null && tabletData['schedule'] != null) {
        final times = tabletData['schedule']['times'] as List;

        // Cancel notifications
        final notiService = NotiService();
        await notiService.cancelTabletNotifications(tabletId, times.length);

        // Cancel alarms
        for (int i = 0; i < times.length; i++) {
          final alarmId = tabletId.hashCode + i;
          await Alarm.stop(alarmId);
          print('🗑️  Cancelled alarm ID: $alarmId for $tabletName');
        }
      }

      // ✅ DELETE MEDICATION LOGS FOR THIS TABLET
      print('🗑️  Deleting medication logs for $tabletName...');
      final logsSnapshot = await FirebaseFirestore.instance
          .collection('patientGroups')
          .doc(patientGroupID)
          .collection('medicationLogs')
          .where('tabletId', isEqualTo: tabletId)
          .get();

      int logsDeleted = 0;
      List<Future<void>> deleteFutures = [];
      for (var doc in logsSnapshot.docs) {
        deleteFutures.add(doc.reference.delete());
        logsDeleted++;
      }
      await Future.wait(deleteFutures);
      print('✅ Deleted $logsDeleted medication logs for $tabletName');

      // Delete the tablet from Firebase
      await backend.deleteTablet(
        patientGroupID: patientGroupID,
        tabletId: tabletId,
      );

      // Refresh the list
      await _loadTablets();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Text(
                  '$tabletName deleted',
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
      }
    } catch (e) {
      print("❌ Error deleting tablet: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Error deleting tablet',
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
    }
  }

  void _showDeleteDialog(String tabletId, String tabletName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          "Delete Medication",
          style: GoogleFonts.dmSerifText(
            color: Theme.of(context).colorScheme.inversePrimary,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Are you sure you want to delete "$tabletName"?',
          style: GoogleFonts.dmSerifText(
            color: Theme.of(context).colorScheme.inversePrimary,
            fontSize: 16,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              "Cancel",
              style: GoogleFonts.dmSerifText(
                color: Theme.of(context).colorScheme.inversePrimary,
                fontSize: 16,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteTablet(tabletId, tabletName);
            },
            child: Text(
              "Delete",
              style: GoogleFonts.dmSerifText(
                color: Colors.red,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _checkAndStartTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeenDrawerTutorial = prefs.getBool('hasSeenDrawerTutorial') ?? false;

    // Only show if:
    // 1. User hasn't seen it before
    // 2. User is a patient (not caregiver)
    // 3. There's at least one medication
    if (!hasSeenDrawerTutorial && isPatient && tablets.isNotEmpty) {
      // Wait for UI to settle
      await Future.delayed(Duration(milliseconds: 500));

      // Start the showcase
      ShowcaseView.get().startShowCase([
        _tapToEditKey,
        _holdToDeleteKey,
      ]);

      // Mark as seen
      await prefs.setBool('hasSeenDrawerTutorial', true);
      print('✅ Started drawer tutorial');
    }
  }
  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Theme.of(context).colorScheme.surface,
      child: Column(
        children: [
          // Header
          DrawerHeader(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
            ),
            child: Center(
              child: PillStatic3D(
                width: 110,  // Small size for drawer header
                height: 110,
              ),
            ),
          ),
          // Add Tablet tile - Only for patients
          if (isPatient)
            DrawerTile(
              title: "Add Medication",
              leading: const Icon(Icons.add_circle),
              onTap: () async {
                Navigator.pop(context);
                final result = await NavigationUtils.navigateWithFade(
                  context,
                  const AddTabletHomePage(),
                );

                if (result == true) {
                  _loadTablets();
                }
              },
            ),

          // Caregiver Management tile - Only for patients
          if (isPatient)
            DrawerTile(
              title: "Caregiver Management",
              leading: const Icon(Icons.people),
              onTap: () {
                Navigator.pop(context);
                NavigationUtils.navigateWithFade(
                  context,
                  const CaregiverManagementScreen(),
                );
              },
            ),

          if (tablets.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 0.0, top: 30, bottom: 12),
              child: Text(
                "Your Medications",
                style: GoogleFonts.dmSerifText(
                  fontSize: 20,
                  color: Theme.of(context).colorScheme.inversePrimary.withOpacity(0.5),
                ),
              ),
            ),

          // Loading State
          if (isLoadingTablets)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(40.0),
                child: CircularProgressIndicator(
                  color: Theme.of(context).colorScheme.inversePrimary,
                ),
              ),
            )
          // Empty State
          else if (tablets.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(40.0),
                child: Column(
                  children: [
                    Icon(
                      Icons.medication_outlined,
                      size: 64,
                      color: Theme.of(context).colorScheme.inversePrimary.withOpacity(0.3),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "No medications added yet",
                      style: GoogleFonts.dmSerifText(
                        fontSize: 16,
                        color: Theme.of(context).colorScheme.inversePrimary.withOpacity(0.5),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isPatient
                          ? "Tap + to add your first medication"
                          : "No medications to display",
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.inversePrimary.withOpacity(0.4),
                      ),
                    ),
                  ],
                ),
              ),
            )
          // Tablets List
          else
            ...tablets.asMap().entries.map((entry) {
              final index = entry.key;
              final tablet = entry.value;
              final tabletId = tablet['id'] as String;
              final tabletData = tablet['data'] as Map<String, dynamic>;
              final medicationName = tabletData['medication']?['name'] ?? 'Unknown';
              final isDarkMode = Theme.of(context).brightness == Brightness.dark;

              final medicationTile = Padding(
                padding: const EdgeInsets.symmetric(horizontal: 25.0, vertical: 6),
                child: GestureDetector(
                  onTap: isPatient
                      ? () async {
                    HapticFeedback.lightImpact();
                    Navigator.pop(context);

                    final result = await NavigationUtils.navigateWithIOSScale(
                      context,
                      AddTabletHomePage(editTabletId: tabletId),
                    );

                    if (result == true) {
                      _loadTablets();
                    }
                  }
                      : null,
                  onLongPress: isPatient
                      ? () {
                    HapticFeedback.mediumImpact();
                    _showDeleteDialog(tabletId, medicationName);
                  }
                      : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.medication_rounded,
                            color: Theme.of(context).colorScheme.inversePrimary,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            medicationName,
                            style: GoogleFonts.dmSerifText(
                              color: Theme.of(context).colorScheme.inversePrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (isPatient)
                          Icon(
                            Icons.chevron_right,
                            color: Theme.of(context).colorScheme.inversePrimary.withOpacity(0.4),
                            size: 20,
                          ),
                      ],
                    ),
                  ),
                ),
              );

              // ✅ Wrap ONLY the first tile with Showcase
              if (index == 0) {
                return Showcase(
                  key: _tapToEditKey,
                  title: 'Tap to Edit',
                  description: 'Tap on any medication to view or edit its details',
                  tooltipBackgroundColor: Theme.of(context).colorScheme.primary,
                  textColor: Theme.of(context).colorScheme.inversePrimary,
                  targetBorderRadius: BorderRadius.circular(20),
                  tooltipBorderRadius: BorderRadius.circular(20),  // ✅ Rounded tooltip
                  tooltipPadding: const EdgeInsets.all(20),         // ✅ More padding
                  titleTextStyle: GoogleFonts.dmSerifText(          // ✅ Custom title style
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.inversePrimary,
                  ),
                  descTextStyle: TextStyle(                          // ✅ Custom description style
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.inversePrimary.withOpacity(0.8),
                    height: 1,
                  ),
                  child: Showcase(
                    key: _holdToDeleteKey,
                    title: 'Hold to Delete',
                    description: 'Long press on any medication to delete it',
                    tooltipBackgroundColor: Theme.of(context).colorScheme.primary,
                    textColor: Colors.white,
                    targetBorderRadius: BorderRadius.circular(20),
                    tooltipBorderRadius: BorderRadius.circular(20),  // ✅ Rounded tooltip
                    tooltipPadding: const EdgeInsets.all(20),         // ✅ More padding
                    titleTextStyle: GoogleFonts.dmSerifText(          // ✅ Custom title style
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.inversePrimary,
                    ),
                    descTextStyle: TextStyle(                          // ✅ Custom description style
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.inversePrimary.withOpacity(0.8),
                      height: 1,
                    ),
                    child: medicationTile,
                  ),
                );
              }

              return medicationTile;
            }).toList(),


          const SizedBox(height: 10),
          Divider(
            color: Theme.of(context).colorScheme.inversePrimary.withOpacity(0.2),
            indent: 25,
            endIndent: 25,
          ),
        ],
      ),
    );
  }
}