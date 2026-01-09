import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserRoleService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Check if current user is the patient (owner) of the patient group
  Future<bool> isPatient() async {
    try {
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      if (currentUserId == null) return false;

      final prefs = await SharedPreferences.getInstance();
      final patientGroupID = prefs.getString('patientGroupID');
      if (patientGroupID == null) return false;

      // Get patient group
      final groupDoc = await _firestore
          .collection('patientGroups')
          .doc(patientGroupID)
          .get();

      if (!groupDoc.exists) return false;

      final patientUid = groupDoc.data()?['patient_uid'] as String?;

      // User is patient if their UID matches the patient_uid
      return currentUserId == patientUid;
    } catch (e) {
      print('❌ Error checking user role: $e');
      return false;
    }
  }

  /// Check if current user is a caregiver (not the patient)
  Future<bool> isCaregiver() async {
    final patient = await isPatient();
    return !patient;
  }

  /// Get user role as string
  Future<String> getUserRole() async {
    final patient = await isPatient();
    return patient ? 'patient' : 'caregiver';
  }
}