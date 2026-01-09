import 'package:cloud_firestore/cloud_firestore.dart';

class CaregiverService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Search for users by email with optional role filter
  Future<List<Map<String, dynamic>>> searchUsersByEmail({
    required String email,
    required String currentUserId,
    required List<String> existingCaregiverIds,
    String? roleFilter, // NEW: 'caregiver' or 'doctor'
  }) async {
    try {
      if (email.trim().isEmpty) {
        return [];
      }

      print("🔍 Searching for users with email containing: $email");
      if (roleFilter != null) {
        print("🔍 Filtering by role: $roleFilter");
      }

      // Search for users whose email contains the search query
      final querySnapshot = await _firestore
          .collection('users')
          .where('email', isGreaterThanOrEqualTo: email.toLowerCase())
          .where('email', isLessThanOrEqualTo: '${email.toLowerCase()}\uf8ff')
          .limit(10)
          .get();

      List<Map<String, dynamic>> results = [];

      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        final userId = doc.id;
        final userRole = data['role'] as String?;

        // Apply role filter if specified
        if (roleFilter != null && userRole != roleFilter) {
          continue; // Skip users that don't match the role filter
        }

        // Exclude current user and already added caregivers
        if (userId != currentUserId && !existingCaregiverIds.contains(userId)) {
          results.add({
            'uid': userId,
            'name': data['fullName'] ?? data['name'] ?? 'Unknown User',
            'email': data['email'] ?? '',
            'role': userRole ?? 'unknown',
          });
        }
      }

      print("✅ Found ${results.length} matching users");
      return results;
    } catch (e) {
      print("❌ Error searching users: $e");
      return [];
    }
  }

  /// Add a caregiver to the patient group
  Future<void> addCaregiver({
    required String patientGroupID,
    required String caregiverUid,
  }) async {
    try {
      print("➕ Adding caregiver $caregiverUid to group $patientGroupID");

      await _firestore
          .collection('patientGroups')
          .doc(patientGroupID)
          .update({
        'caregivers': FieldValue.arrayUnion([caregiverUid]),
      });

      // Update caregiver's user document with patientGroupID
      await _firestore.collection('users').doc(caregiverUid).update({
        'patientGroupID': patientGroupID,
      });

      print("✅ Caregiver added successfully");
    } catch (e) {
      print("❌ Error adding caregiver: $e");
      rethrow;
    }
  }

  /// Remove a caregiver from the patient group
  Future<void> removeCaregiver({
    required String patientGroupID,
    required String caregiverUid,
  }) async {
    try {
      print("➖ Removing caregiver $caregiverUid from group $patientGroupID");

      await _firestore
          .collection('patientGroups')
          .doc(patientGroupID)
          .update({
        'caregivers': FieldValue.arrayRemove([caregiverUid]),
      });

      // Remove patientGroupID from caregiver's user document
      await _firestore.collection('users').doc(caregiverUid).update({
        'patientGroupID': FieldValue.delete(),
      });

      print("✅ Caregiver removed successfully");
    } catch (e) {
      print("❌ Error removing caregiver: $e");
      rethrow;
    }
  }

  /// Get list of added caregivers with their details
  Future<List<Map<String, dynamic>>> getAddedCaregivers({
    required String patientGroupID,
    required String patientUid,
  }) async {
    try {
      print("📋 Fetching caregivers for group: $patientGroupID");

      // Get patient group document
      final groupDoc = await _firestore
          .collection('patientGroups')
          .doc(patientGroupID)
          .get();

      if (!groupDoc.exists) {
        print("❌ Patient group not found");
        return [];
      }

      final data = groupDoc.data()!;
      List<String> caregiverIds = List<String>.from(data['caregivers'] ?? []);

      // Remove patient's own UID from the list
      caregiverIds = caregiverIds.where((id) => id != patientUid).toList();

      if (caregiverIds.isEmpty) {
        print("ℹ️ No caregivers added yet");
        return [];
      }

      // Fetch user details for each caregiver
      List<Map<String, dynamic>> caregivers = [];

      for (String caregiverId in caregiverIds) {
        final userDoc = await _firestore.collection('users').doc(caregiverId).get();

        if (userDoc.exists) {
          final userData = userDoc.data()!;
          caregivers.add({
            'uid': caregiverId,
            'name': userData['fullName'] ?? userData['name'] ?? 'Unknown User',
            'email': userData['email'] ?? '',
          });
        }
      }

      print("✅ Found ${caregivers.length} caregivers");
      return caregivers;
    } catch (e) {
      print("❌ Error fetching caregivers: $e");
      return [];
    }
  }

  /// Check if a user is a caregiver for a patient group
  Future<bool> isCaregiver({
    required String patientGroupID,
    required String userId,
  }) async {
    try {
      final groupDoc = await _firestore
          .collection('patientGroups')
          .doc(patientGroupID)
          .get();

      if (!groupDoc.exists) return false;

      final data = groupDoc.data()!;
      List<String> caregiverIds = List<String>.from(data['caregivers'] ?? []);

      return caregiverIds.contains(userId);
    } catch (e) {
      print("❌ Error checking caregiver status: $e");
      return false;
    }
  }

  // ============================================
  // DOCTOR FUNCTIONS (NEW)
  // ============================================

  /// Get the added doctor for a patient group
  Future<Map<String, dynamic>?> getAddedDoctor({
    required String patientGroupID,
  }) async {
    try {
      print("📋 Fetching doctor for group: $patientGroupID");

      // Get patient group document
      final groupDoc = await _firestore
          .collection('patientGroups')
          .doc(patientGroupID)
          .get();

      if (!groupDoc.exists) {
        print("❌ Patient group not found");
        return null;
      }

      final data = groupDoc.data()!;
      String? doctorUid = data['doctor_uid'] as String?;

      if (doctorUid == null) {
        print("ℹ️ No doctor added yet");
        return null;
      }

      // Fetch doctor's user details
      final userDoc = await _firestore.collection('users').doc(doctorUid).get();

      if (!userDoc.exists) {
        print("⚠️ Doctor user not found");
        return null;
      }

      final userData = userDoc.data()!;
      final doctor = {
        'uid': doctorUid,
        'name': userData['fullName'] ?? userData['name'] ?? 'Unknown Doctor',
        'email': userData['email'] ?? '',
      };

      print("✅ Found doctor: ${doctor['name']}");
      return doctor;
    } catch (e) {
      print("❌ Error fetching doctor: $e");
      return null;
    }
  }

  /// Add a doctor to the patient group
  Future<void> addDoctor({
    required String patientGroupID,
    required String doctorUid,
  }) async {
    try {
      print("➕ Adding doctor $doctorUid to group $patientGroupID");

      // Check if a doctor already exists
      final groupDoc = await _firestore
          .collection('patientGroups')
          .doc(patientGroupID)
          .get();

      if (groupDoc.exists) {
        final data = groupDoc.data()!;
        final existingDoctorUid = data['doctor_uid'] as String?;

        if (existingDoctorUid != null) {
          print("⚠️ Replacing existing doctor");
          // Remove patientGroupID from old doctor's user document
          // Note: Doctors don't store patientGroupID, so we skip this
        }
      }

      // Update patient group with new doctor
      await _firestore
          .collection('patientGroups')
          .doc(patientGroupID)
          .update({
        'doctor_uid': doctorUid,
      });

      // Note: We do NOT update doctor's user document with patientGroupID
      // Doctors can have multiple patients, so they don't store a single patientGroupID

      print("✅ Doctor added successfully");
    } catch (e) {
      print("❌ Error adding doctor: $e");
      rethrow;
    }
  }

  /// Remove the doctor from the patient group
  Future<void> removeDoctor({
    required String patientGroupID,
  }) async {
    try {
      print("➖ Removing doctor from group $patientGroupID");

      await _firestore
          .collection('patientGroups')
          .doc(patientGroupID)
          .update({
        'doctor_uid': null,
      });

      // Note: We do NOT remove anything from doctor's user document
      // Doctors don't store patientGroupID

      print("✅ Doctor removed successfully");
    } catch (e) {
      print("❌ Error removing doctor: $e");
      rethrow;
    }
  }

  /// Check if a user is the doctor for a patient group
  Future<bool> isDoctor({
    required String patientGroupID,
    required String userId,
  }) async {
    try {
      final groupDoc = await _firestore
          .collection('patientGroups')
          .doc(patientGroupID)
          .get();

      if (!groupDoc.exists) return false;

      final data = groupDoc.data()!;
      String? doctorUid = data['doctor_uid'] as String?;

      return doctorUid == userId;
    } catch (e) {
      print("❌ Error checking doctor status: $e");
      return false;
    }
  }
}