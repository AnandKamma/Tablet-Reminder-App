import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_reminder/Widgets/tablet_tile.dart';
import 'package:tablet_reminder/components/Drawer.dart';
import 'package:tablet_reminder/components/Backend_Integration/medication_tracking_service.dart';
import 'package:tablet_reminder/components/Backend_Integration/Role_detection.dart';
import 'package:tablet_reminder/screens/DoctorDashBoard.dart';
import 'package:tablet_reminder/Widgets/Navigation_Animations.dart';


class HomePage extends StatefulWidget {
  final String? patientGroupID;
  final bool isDoctorView;

  const HomePage({
    super.key,
    this.patientGroupID,
    this.isDoctorView = false,
  });



  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final MedicationTrackingService _trackingService = MedicationTrackingService();
  final UserRoleService _roleService = UserRoleService();

  List<Map<String, dynamic>> todaysMedications = [];
  bool isLoading = true;
  bool isPatient = true;
  String? patientGroupID;


  @override
  void initState() {
    super.initState();
    _loadTodaysMedications();
    _checkUserRole();

  }

  @override
  void dispose() {
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
  Future<void> _loadTodaysMedications() async {
    try {
      print("🔄 LOADING medications...");
      // Use passed patientGroupID if available (doctor view)
      // Otherwise load from SharedPreferences (patient/caregiver view)
      String? groupID = widget.patientGroupID;

      if (groupID == null) {
        final prefs = await SharedPreferences.getInstance();
        groupID = prefs.getString('patientGroupID');
      }

      patientGroupID = groupID;

      if (patientGroupID == null) {
        print("❌ No patient group found");
        if (mounted) {
          setState(() {
            isLoading = false;
          });
        }
        return;
      }

      final meds = await _trackingService.getTodaysMedications(patientGroupID!);

      if (mounted) {
        setState(() {
          todaysMedications = meds;
          isLoading = false;
        });
      }

      print("✅ Loaded ${meds.length} medications for today");

      // Check for missed medications (past late window)
      print("🔍 Checking for missed medications...");
      for (var med in meds) {
        print("  Checking: ${med['name']} - Taken: ${med['taken']}, Late Window: ${med['lateWindow']}");

        if (!med['taken'] && med['lateWindow'] != null) {
          await _trackingService.scheduleMissedMedicationCheck(
            patientGroupID: patientGroupID!,
            tabletId: med['tabletId'],
            medicationName: med['name'],
            scheduledTime: med['scheduledTime'],
            lateWindowMinutes: med['lateWindow'],
            caregiverSettings: med['caregiverSettings'],
          );
        }
      }
      print("✅ Finished checking for missed medications");
    } catch (e) {
      print("❌ Error loading today's medications: $e");
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }
  Future<void> _toggleTaken(int index) async {
    if (patientGroupID == null) return;
    // Block doctors from marking medications
    if (widget.isDoctorView) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.block, color: Colors.white),
              SizedBox(width: 12),
              Text(
                'Doctors cannot mark medications',
                style: GoogleFonts.dmSerifText(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
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
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    // Block caregivers from marking medications
    if (!isPatient) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.block, color: Colors.white),
              SizedBox(width: 12),
              Text(
                'Only the patient can mark medications',
                style: GoogleFonts.dmSerifText(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
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
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final med = todaysMedications[index];

    // If already taken, don't allow untaking
    if (med['taken']) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.white),
              SizedBox(width: 12),
              Text(
                'Already marked as taken',
                style: GoogleFonts.dmSerifText(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          backgroundColor: Colors.orange.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: EdgeInsets.all(16),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    try {
      final result = await _trackingService.markDoseAsTaken(
        patientGroupID: patientGroupID!,
        tabletId: med['tabletId'],
        scheduledTime: med['scheduledTime'],
        medicationName: med['name'],
        caregiverSettings: med['caregiverSettings'],
        lateWindowMinutes: med['lateWindow'],
      );

      if (result['success']) {
        // Reload medications to update UI
        await _loadTodaysMedications();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 12),
                  Text(
                    result['takenLate']
                        ? 'Marked as taken (late)'
                        : 'Medication taken!',
                    style: GoogleFonts.dmSerifText(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              backgroundColor: result['takenLate']
                  ? Colors.orange.shade600
                  : Colors.green.shade600,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              margin: EdgeInsets.all(16),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      print("❌ Error marking medication: $e");
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
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: widget.isDoctorView
            ? IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: Theme.of(context).colorScheme.inversePrimary,
          ),
          onPressed: () async{
            Navigator.pop(context);
            await NavigationUtils.navigateWithFade(
              context,
              const DoctorDashboard(),
            );

          },
        )
            : null, // null means show default drawer icon
      ),
      drawer: const MyDrawer(),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // HEADING
          Padding(
            padding: const EdgeInsets.only(left: 25.0),
            child: Text(
              'Medications',
              style: GoogleFonts.dmSerifText(
                fontSize: 48,
                color: Theme.of(context).colorScheme.inversePrimary,
              ),
            ),
          ),

          // LOADING INDICATOR
          if (isLoading)
            Expanded(
              child: Center(
                child: CircularProgressIndicator(
                  color: Theme.of(context).colorScheme.inversePrimary,
                ),
              ),
            )

          // NO MEDICATIONS MESSAGE
          else if (todaysMedications.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.medication_outlined,
                      size: 80,
                      color: Theme.of(context).colorScheme.inversePrimary.withOpacity(0.3),
                    ),
                    SizedBox(height: 20),
                    Text(
                      'No medications scheduled for today',
                      style: GoogleFonts.dmSerifText(
                        fontSize: 18,
                        color: Theme.of(context).colorScheme.inversePrimary.withOpacity(0.6),
                      ),
                      textAlign: TextAlign.center,
                    ),

                  ],
                ),
              ),
            )

          // LIST OF MEDICATIONS
          else
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadTodaysMedications,
                color: Theme.of(context).colorScheme.inversePrimary,
                child: ListView.builder(
                  padding: const EdgeInsets.only(bottom: 120),
                  itemCount: todaysMedications.length,
                  itemBuilder: (context, index) {
                    final med = todaysMedications[index];
                    return TabletTile(
                      name: med['name'],
                      strength: med['strength'],
                      time: med['scheduledTime'],
                      taken: med['taken'],
                      status: med['status'] ?? 'pending', // ADD THIS
                      onTap: () => _toggleTaken(index),
                      onLongPress: () {
                        // TODO: Navigate to tablet details/edit page
                        print("Long pressed: ${med['name']}");
                      },
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}