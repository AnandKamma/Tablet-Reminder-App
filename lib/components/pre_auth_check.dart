import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_reminder/app/routes.dart';

class AuthCheck extends StatefulWidget {
  const AuthCheck({Key? key}) : super(key: key);

  @override
  State<AuthCheck> createState() => _AuthCheckState();
}

class _AuthCheckState extends State<AuthCheck> {
  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    // Wait for Firebase to initialize
    await Future.delayed(const Duration(milliseconds: 500));

    // Step 1: Check if user is logged in (Firebase Auth)
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      // No user logged in → Go to Login
      print('⚠️ No user logged in');
      if (mounted) {
        Navigator.of(context).pushReplacementNamed(Routes.loginpage);
      }
      return;
    }

    // User is logged in
    print('✅ User logged in: ${user.uid}');

    // Step 2: Check if user exists in Firestore users collection
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (!userDoc.exists) {
      // User is authenticated but doesn't exist in Firestore
      // This is an orphaned auth user - sign them out
      print('❌ User ${user.uid} not found in Firestore. Signing out.');
      await FirebaseAuth.instance.signOut();
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      if (mounted) {
        Navigator.of(context).pushReplacementNamed(Routes.loginpage);
      }
      return;
    }

    print('✅ User exists in Firestore');

    // Step 3: Get user role
    final userData = userDoc.data() as Map<String, dynamic>;
    final role = userData['role'] as String?;

    print('🔍 User role: $role');

    // Step 4: Route based on role
    if (role == 'doctor') {
      // Doctor → Go directly to Doctor Dashboard
      print('✅ Doctor detected. Routing to Doctor Dashboard.');
      if (mounted) {
        Navigator.of(context).pushReplacementNamed(Routes.doctorDashboard);
      }
      return;
    }

    // For Patient and Caregiver, check patientGroupID
    final prefs = await SharedPreferences.getInstance();
    final patientGroupID = prefs.getString('patientGroupID');

    if (patientGroupID == null || patientGroupID.isEmpty) {
      // No patientGroupID → Go to Registration
      print('⚠️ User not registered (no patientGroupID)');
      if (mounted) {
        Navigator.of(context).pushReplacementNamed(Routes.patientpage);
      }
      return;
    }

    print('✅ User has patientGroupID: $patientGroupID');

    // Step 5: Verify patientGroup exists in Firestore
    final groupDoc = await FirebaseFirestore.instance
        .collection('patientGroups')
        .doc(patientGroupID)
        .get();

    if (!groupDoc.exists) {
      // PatientGroup doesn't exist → Clear data and re-register
      print('❌ PatientGroup "$patientGroupID" not found. Clearing data.');
      await prefs.remove('patientGroupID');
      if (mounted) {
        Navigator.of(context).pushReplacementNamed(Routes.patientpage);
      }
      return;
    }

    // Step 6: Verify user is actually part of this patientGroup
    final groupData = groupDoc.data() as Map<String, dynamic>;
    final patientUid = groupData['patient_uid'] as String?;
    final caregivers = List<String>.from(groupData['caregivers'] ?? []);

    final isPatient = patientUid == user.uid;
    final isCaregiver = caregivers.contains(user.uid);

    if (!isPatient && !isCaregiver) {
      // User is not part of this group anymore
      print('❌ User not part of patientGroup "$patientGroupID". Clearing data.');
      await prefs.remove('patientGroupID');
      if (mounted) {
        Navigator.of(context).pushReplacementNamed(Routes.patientpage);
      }
      return;
    }

    // All checks passed → Go to Homepage
    print('✅ All checks passed. Going to HomePage.');
    if (mounted) {
      Navigator.of(context).pushReplacementNamed(Routes.navigation);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show loading screen while checking
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Center(
        child: CircularProgressIndicator(
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}