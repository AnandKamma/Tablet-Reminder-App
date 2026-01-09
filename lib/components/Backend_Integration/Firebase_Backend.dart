import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_reminder/components/Backend_Integration/models/user_model.dart';
import 'package:tablet_reminder/components/Backend_Integration/models/patient_group_model.dart';
import 'package:tablet_reminder/components/Backend_Integration/models/medication_model.dart';
import 'package:tablet_reminder/components/Backend_Integration/models/schedule_model.dart';
import 'package:tablet_reminder/components/Backend_Integration/models/inventory_model.dart';
import 'package:tablet_reminder/components/Backend_Integration/models/caregivers_model.dart';

class FirebaseBackend {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ========================
  // USER AUTHENTICATION
  // ========================

  /// Create or Update User in Firestore
  Future<void> createOrUpdateUser({
    required String uid,
    required String email,
    required String fullName,
    required String signInMethod,
    String? patientGroupID,
  }) async {
    try {
      UserModel user = UserModel(
        uid: uid,
        email: email,
        fullName: fullName,
        signInMethod: signInMethod,
        patientGroupID: patientGroupID,
      );

      await _firestore
          .collection('users')
          .doc(uid)
          .set(user.toMap(), SetOptions(merge: true));

      print("✅ User created/updated in Firestore: $uid");
    } catch (e) {
      print("❌ Error creating/updating user: $e");
      rethrow;
    }
  }

  /// Get User Data from Firestore
  Future<UserModel?> getUserData(String uid) async {
    try {
      DocumentSnapshot doc = await _firestore.collection('users').doc(uid).get();

      if (doc.exists) {
        return UserModel.fromMap(doc.data() as Map<String, dynamic>, uid);
      }
      return null;
    } catch (e) {
      print("❌ Error fetching user data: $e");
      return null;
    }
  }

  // ========================
  // PATIENT GROUP MANAGEMENT
  // ========================

  /// Register New Patient Group (Patient creates their group)
  Future<void> registerPatientGroup({
    required String userId,
    required String patientGroupID,
    required String deviceID,
  }) async {
    try {
      // Check if patientGroupID already exists
      DocumentSnapshot existingGroup = await _firestore
          .collection('patientGroups')
          .doc(patientGroupID)
          .get();

      if (existingGroup.exists) {
        throw Exception("❌ Patient Group ID already exists. Choose a different one.");
      }

      // Create new patient group
      PatientGroupModel patientGroup = PatientGroupModel(
        patientGroupID: patientGroupID,
        deviceID: deviceID,
        patientUID: userId,
        caregivers: [userId], // Patient is the first caregiver
        reminderStatus: ReminderStatus(isActive: false),
      );

      await _firestore
          .collection('patientGroups')
          .doc(patientGroupID)
          .set(patientGroup.toMap());

      // Update user's patientGroupID in Firestore
      await _firestore.collection('users').doc(userId).update({
        'patientGroupID': patientGroupID,
      });

      // Store in SharedPreferences for local access
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('patientGroupID', patientGroupID);

      print("✅ Patient Group registered successfully: $patientGroupID");
    } catch (e) {
      print("❌ Error registering patient group: $e");
      rethrow;
    }
  }

  /// Get Patient Group Data
  Future<PatientGroupModel?> getPatientGroup(String patientGroupID) async {
    try {
      DocumentSnapshot doc = await _firestore
          .collection('patientGroups')
          .doc(patientGroupID)
          .get();

      if (doc.exists) {
        return PatientGroupModel.fromMap(
          doc.data() as Map<String, dynamic>,
          patientGroupID,
        );
      }
      return null;
    } catch (e) {
      print("❌ Error fetching patient group: $e");
      return null;
    }
  }

  /// Check if Patient Group ID exists
  Future<bool> doesPatientGroupExist(String patientGroupID) async {
    try {
      DocumentSnapshot doc = await _firestore
          .collection('patientGroups')
          .doc(patientGroupID)
          .get();

      return doc.exists;
    } catch (e) {
      print("❌ Error checking patient group existence: $e");
      return false;
    }
  }

  /// Create a new tablet (draft) with only userId and patientGroupID
  /// Create a new tablet (draft) inside patientGroup's tablets sub-collection
  Future<String> createTabletDraft({
    required String patientGroupID,
  }) async {
    try {
      DocumentReference docRef = await _firestore
          .collection('patientGroups')
          .doc(patientGroupID)
          .collection('tablets')
          .add({
        'createdAt': FieldValue.serverTimestamp(),
      });

      print("✅ Tablet draft created with ID: ${docRef.id}");
      return docRef.id;
    } catch (e) {
      print("❌ Error creating tablet draft: $e");
      rethrow;
    }
  }

  /// Save Medication section
  Future<void> saveMedication({
    required String patientGroupID,
    required String tabletId,
    required MedicationModel medication,
  }) async {
    try {
      await _firestore
          .collection('patientGroups')
          .doc(patientGroupID)
          .collection('tablets')
          .doc(tabletId)
          .update({
        'medication': medication.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print("✅ Medication saved for tablet: $tabletId");
    } catch (e) {
      print("❌ Error saving medication: $e");
      rethrow;
    }
  }

  /// Get medication data for a tablet
  Future<MedicationModel?> getMedication({
    required String patientGroupID,
    required String tabletId,
  }) async {
    try {
      DocumentSnapshot doc = await _firestore
          .collection('patientGroups')
          .doc(patientGroupID)
          .collection('tablets')
          .doc(tabletId)
          .get();

      if (doc.exists) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        if (data.containsKey('medication')) {
          return MedicationModel.fromMap(data['medication']);
        }
      }
      return null;
    } catch (e) {
      print("❌ Error fetching medication: $e");
      return null;
    }
  }

  /// Get all tablets for a patient group
  Future<List<Map<String, dynamic>>> getAllTablets(String patientGroupID) async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('patientGroups')
          .doc(patientGroupID)
          .collection('tablets')
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => {
        'id': doc.id,
        'data': doc.data() as Map<String, dynamic>,
      })
          .toList();
    } catch (e) {
      print("❌ Error fetching tablets: $e");
      return [];
    }
  }


  // Save Schedule Section
  Future<void> saveSchedule({
    required String patientGroupID,
    required String tabletId,
    required ScheduleModel schedule,
  }) async {
    try {
      await _firestore
          .collection('patientGroups')
          .doc(patientGroupID)
          .collection('tablets')
          .doc(tabletId)
          .update({
        'schedule': schedule.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print("✅ Schedule saved for tablet: $tabletId");
    } catch (e) {
      print("❌ Error saving schedule: $e");
      rethrow;
    }
  }

  /// Get schedule data for a tablet
  Future<ScheduleModel?> getSchedule({
    required String patientGroupID,
    required String tabletId,
  }) async {
    try {
      DocumentSnapshot doc = await _firestore
          .collection('patientGroups')
          .doc(patientGroupID)
          .collection('tablets')
          .doc(tabletId)
          .get();

      if (doc.exists) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        if (data.containsKey('schedule')) {
          return ScheduleModel.fromMap(data['schedule']);
        }
      }
      return null;
    } catch (e) {
      print("❌ Error fetching schedule: $e");
      return null;
    }
  }

  /// Save complete tablet with all sections at once (from SharedPreferences)
  Future<String> saveCompleteTablet({
    required String patientGroupID,
    required MedicationModel medication,
    required ScheduleModel schedule,
    InventoryModel? inventory,
    CaregiverSettingsModel? caregiverSettings,
  }) async {
    try {
      print('🔍 DEBUG - saveCompleteTablet called with:');
      print('   medication: ${medication.toMap()}');
      print('   schedule: ${schedule.toMap()}');
      print('   inventory: ${inventory?.toMap()}');
      print('   caregiverSettings: ${caregiverSettings?.toMap()}'); // ADD THIS

      // Create new tablet document with all data at once
      DocumentReference docRef = await _firestore
          .collection('patientGroups')
          .doc(patientGroupID)
          .collection('tablets')
          .add({
        'medication': medication.toMap(),
        'schedule': schedule.toMap(),
        if (inventory != null) 'inventory': inventory.toMap(),
        if (caregiverSettings != null) 'caregiverSettings': caregiverSettings.toMap(), // MAKE SURE THIS LINE EXISTS
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print("✅ Complete tablet saved with ID: ${docRef.id}");
      return docRef.id;
    } catch (e) {
      print("❌ Error saving complete tablet: $e");
      rethrow;
    }
  }

  /// Get all tablets for a patient group
  Future<List<Map<String, dynamic>>> getAllTabletsWithIds(String patientGroupID) async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('patientGroups')
          .doc(patientGroupID)
          .collection('tablets')
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => {
        'id': doc.id,
        'data': doc.data() as Map<String, dynamic>,
      })
          .toList();
    } catch (e) {
      print("❌ Error fetching tablets: $e");
      return [];
    }
  }

  /// Get a single complete tablet with all sections
  Future<Map<String, dynamic>?> getCompleteTablet({
    required String patientGroupID,
    required String tabletId,
  }) async {
    try {
      DocumentSnapshot doc = await _firestore
          .collection('patientGroups')
          .doc(patientGroupID)
          .collection('tablets')
          .doc(tabletId)
          .get();

      if (doc.exists) {
        return doc.data() as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      print("❌ Error fetching complete tablet: $e");
      return null;
    }
  }

  /// Update existing tablet (used when editing)
  Future<void> updateCompleteTablet({
    required String patientGroupID,
    required String tabletId,
    required MedicationModel medication,
    required ScheduleModel schedule,
    InventoryModel? inventory,
    CaregiverSettingsModel? caregiverSettings,
  }) async {
    try {
      Map<String, dynamic> updateData = {
        'medication': medication.toMap(),
        'schedule': schedule.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (inventory != null) {
        updateData['inventory'] = inventory.toMap();
      } else {
        updateData['inventory'] = FieldValue.delete();
      }

      if (caregiverSettings != null) {
        updateData['caregiverSettings'] = caregiverSettings.toMap();
      } else {
        updateData['caregiverSettings'] = FieldValue.delete();
      }

      await _firestore
          .collection('patientGroups')
          .doc(patientGroupID)
          .collection('tablets')
          .doc(tabletId)
          .update(updateData);

      print("✅ Tablet updated successfully: $tabletId");
    } catch (e) {
      print("❌ Error updating tablet: $e");
      rethrow;
    }
  }

  /// Delete a tablet
  Future<void> deleteTablet({
    required String patientGroupID,
    required String tabletId,
  }) async {
    try {
      await _firestore
          .collection('patientGroups')
          .doc(patientGroupID)
          .collection('tablets')
          .doc(tabletId)
          .delete();
      print("✅ Tablet deleted: $tabletId");
    } catch (e) {
      print("❌ Error deleting tablet: $e");
      rethrow;
    }
  }

}