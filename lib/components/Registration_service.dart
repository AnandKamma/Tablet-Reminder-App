import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PatientGroupService {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final FirebaseAuth auth = FirebaseAuth.instance;

  /// ✅ Update User's Patient Group ID in Firestore
  Future<void> updateUserPatientGroupID(String userId, String patientGroupID) async {
    try {
      await firestore.collection('users').doc(userId).update({
        'patientGroupID': patientGroupID,
      });
      print("✅ PatientGroupID updated successfully for user: $userId");
    } catch (error) {
      print("❌ Error updating PatientGroupID: $error");
    }
  }

  /// ✅ NEW: Register User Role (for Caregiver and Doctor)
  Future<void> registerUserRole(String userId, String role) async {
    try {
      // Get user document reference
      DocumentReference userRef = firestore.collection('users').doc(userId);
      DocumentSnapshot userDoc = await userRef.get();

      if (userDoc.exists) {
        // User exists - update role
        await userRef.update({
          'role': role, // 'patient', 'caregiver', or 'doctor'
          'updatedAt': FieldValue.serverTimestamp(),
        });
        print("✅ User role updated to: $role");
      } else {
        // User doesn't exist - create new user document
        final currentUser = auth.currentUser;
        if (currentUser == null) {
          throw Exception("❌ No authenticated user found");
        }

        await userRef.set({
          'email': currentUser.email ?? '',
          'name': currentUser.displayName ?? 'User',
          'role': role,
          'patientGroupID': null, // No patientGroupID for caregiver/doctor initially
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        print("✅ New user created with role: $role");
      }
    } catch (error) {
      print("❌ Error registering user role: $error");
      throw error;
    }
  }

  /// ✅ Patient: Register New Patient Group
  Future<void> registerPatientGroup(
      String userId, String patientGroupID, String deviceID) async {
    try {
      await firestore.runTransaction((transaction) async {
        DocumentReference patientGroupRef = firestore.collection('patientGroups').doc(patientGroupID);
        DocumentSnapshot patientGroupSnapshot = await transaction.get(patientGroupRef);

        if (patientGroupSnapshot.exists) {
          throw Exception("❌ Patient Group ID already exists. Choose a different one.");
        }

        transaction.set(patientGroupRef, {
          'device_id': deviceID,
          'patient_uid': userId,
          'caregivers': [userId], // Patient is first caregiver
          'doctor_uid': null, // NEW: No doctor initially
          'reminder_status': {
            'isActive': false,
            'timestamp': FieldValue.serverTimestamp(),
          },
        });
      });

      // ✅ Update user's Firestore document with patientGroupID and role
      final currentUser = auth.currentUser;
      await firestore.collection('users').doc(userId).set({
        'email': currentUser?.email ?? '',
        'name': currentUser?.displayName ?? 'Patient',
        'role': 'patient', // NEW: Set role as patient
        'patientGroupID': patientGroupID,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // ✅ Store Patient Group ID Locally
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('patientGroupID', patientGroupID);

      print("✅ Patient Group Registered Successfully: $patientGroupID");
    } catch (e) {
      print("❌ Error registering patient group: $e");
      throw e;
    }
  }

  /// ✅ NEW: Get User Role from Firestore
  Future<String?> getUserRole(String userId) async {
    try {
      DocumentSnapshot userDoc = await firestore.collection('users').doc(userId).get();

      if (userDoc.exists) {
        Map<String, dynamic>? userData = userDoc.data() as Map<String, dynamic>?;
        return userData?['role'] as String?;
      }

      return null;
    } catch (e) {
      print("❌ Error getting user role: $e");
      return null;
    }
  }

/// ✅ Caregiver: Join Existing Patient Group (placeholder for future implementation)
}