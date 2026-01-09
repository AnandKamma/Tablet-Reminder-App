import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tablet_reminder/Widgets/tablet_tile.dart';
import 'package:tablet_reminder/components/Drawer.dart';
import 'package:tablet_reminder/app/routes.dart';
class DoctorDashboard extends StatefulWidget {
  const DoctorDashboard({super.key});

  @override
  State<DoctorDashboard> createState() => _DoctorDashboardState();
}

class _DoctorDashboardState extends State<DoctorDashboard> {
  List<Map<String, dynamic>> myPatients = [];
  bool isLoading = true;
  String? currentDoctorUID;

  @override
  void initState() {
    super.initState();
    _loadMyPatients();
  }

  Future<void> _loadMyPatients() async {
    try {
      print("🔄 LOADING doctor's patients...");

      // Get current doctor's UID
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print("❌ No user logged in");
        if (mounted) {
          setState(() {
            isLoading = false;
          });
        }
        return;
      }

      currentDoctorUID = user.uid;
      print("✅ Doctor UID: $currentDoctorUID");

      // Query all patientGroups where doctor_uid equals current doctor's UID
      final querySnapshot = await FirebaseFirestore.instance
          .collection('patientGroups')
          .where('doctor_uid', isEqualTo: currentDoctorUID)
          .get();

      print("✅ Found ${querySnapshot.docs.length} patient groups");

      List<Map<String, dynamic>> patients = [];

      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        final patientUid = data['patient_uid'] as String?;

        if (patientUid == null) continue;

        // Get patient's name from users collection
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(patientUid)
            .get();

        String patientName = 'Unknown Patient';
        if (userDoc.exists) {
          final userData = userDoc.data();
          patientName = userData?['fullName'] ?? userData?['name'] ?? 'Unknown Patient';
        }

        patients.add({
          'patientGroupID': doc.id,
          'patientUID': patientUid,
          'patientName': patientName,
        });

        print("  Patient: $patientName (Group: ${doc.id})");
      }

      if (mounted) {
        setState(() {
          myPatients = patients;
          isLoading = false;
        });
      }

      print("✅ Loaded ${patients.length} patients");
    } catch (e) {
      print("❌ Error loading patients: $e");
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  void _openPatientView(Map<String, dynamic> patient) {Navigator.pushNamed(
    context,
    Routes.navigation,  // Goes to full navigation with HomePage
    arguments: {
      'patientGroupID': patient['patientGroupID'],
      'isDoctorView': true,
    },
  );
    print("🔄 Opening patient view for: ${patient['patientName']}");

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.white),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Patient view screen coming soon!',
                style: GoogleFonts.dmSerifText(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.blue.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: EdgeInsets.all(16),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      drawer: const MyDrawer(),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // HEADING
          Padding(
            padding: const EdgeInsets.only(left: 25.0),
            child: Text(
              'My Patients',
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

          // NO PATIENTS MESSAGE
          else if (myPatients.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.people_outline,
                      size: 80,
                      color: Theme.of(context).colorScheme.inversePrimary.withOpacity(0.3),
                    ),
                    SizedBox(height: 20),
                    Text(
                      'No patients added yet',
                      style: GoogleFonts.dmSerifText(
                        fontSize: 18,
                        color: Theme.of(context).colorScheme.inversePrimary.withOpacity(0.6),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40.0),
                      child: Text(
                        'Ask your patients to add you as their doctor',
                        style: GoogleFonts.dmSerifText(
                          fontSize: 14,
                          color: Theme.of(context).colorScheme.inversePrimary.withOpacity(0.4),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            )

          // LIST OF PATIENTS
          else
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadMyPatients,
                color: Theme.of(context).colorScheme.inversePrimary,
                child: ListView.builder(
                  padding: const EdgeInsets.only(bottom: 120),
                  itemCount: myPatients.length,
                  itemBuilder: (context, index) {
                    final patient = myPatients[index];
                    return TabletTile(
                      name: patient['patientName'],
                      strength: null,
                      time: null,
                      taken: false,
                      status: 'pending',
                      onTap: () => _openPatientView(patient),
                      onLongPress: () {
                        print("Long pressed: ${patient['patientName']}");
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