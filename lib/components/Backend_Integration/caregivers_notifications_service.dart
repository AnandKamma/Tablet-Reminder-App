import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

class CaregiverNotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Send notification when patient takes medication
  Future<void> notifyCaregiversMedicationTaken({
    required String patientGroupID,
    required String patientName,
    required String medicationName,
    required DateTime takenAt,
    required bool takenLate,
  }) async {
    try {
      print('📤 Sending "medication taken" notification to caregivers...');

      // Get caregiver FCM tokens
      final tokens = await _getCaregiverTokens(patientGroupID);

      if (tokens.isEmpty) {
        print('⚠️ No caregiver tokens found - skipping notification');
        return;
      }

      // Format time
      final time = _formatTime(takenAt);

      // Create notification
      final title = takenLate ? 'Medication Taken (Late)' : 'Medication Taken';
      final body = '$patientName took $medicationName at $time';

      // Send to all caregivers
      await _sendNotificationToTokens(
        tokens: tokens,
        title: title,
        body: body,
        data: {
          'type': 'medication_taken',
          'medicationName': medicationName,
          'takenAt': takenAt.toIso8601String(),
          'takenLate': takenLate.toString(),
        },
      );

      print('✅ Medication taken notification sent to ${tokens.length} caregivers');
    } catch (e) {
      print('❌ Error sending medication taken notification: $e');
    }
  }

  /// Send notification when patient misses medication
  Future<void> notifyCaregiversMedicationMissed({
    required String patientGroupID,
    required String patientName,
    required String medicationName,
    required String scheduledTime,
  }) async {
    try {
      print('📤 Sending "medication missed" notification to caregivers...');

      // Get caregiver FCM tokens
      final tokens = await _getCaregiverTokens(patientGroupID);

      if (tokens.isEmpty) {
        print('⚠️ No caregiver tokens found - skipping notification');
        return;
      }

      // Create notification
      final title = 'Medication Missed';
      final body = '$patientName missed $medicationName (scheduled for $scheduledTime)';

      // Send to all caregivers
      await _sendNotificationToTokens(
        tokens: tokens,
        title: title,
        body: body,
        data: {
          'type': 'medication_missed',
          'medicationName': medicationName,
          'scheduledTime': scheduledTime,
        },
      );

      print('✅ Medication missed notification sent to ${tokens.length} caregivers');
    } catch (e) {
      print('❌ Error sending medication missed notification: $e');
    }
  }

  /// Get FCM tokens for all caregivers in a patient group
  Future<List<String>> _getCaregiverTokens(String patientGroupID) async {
    try {
      // Get patient group
      final groupDoc = await _firestore
          .collection('patientGroups')
          .doc(patientGroupID)
          .get();

      if (!groupDoc.exists) {
        print('❌ Patient group not found');
        return [];
      }

      final data = groupDoc.data()!;
      final patientUid = data['patient_uid'] as String?;
      final caregiverIds = List<String>.from(data['caregivers'] ?? []);

      // Remove patient's own UID from caregiver list
      final actualCaregivers = caregiverIds.where((id) => id != patientUid).toList();

      if (actualCaregivers.isEmpty) {
        print('ℹ️ No caregivers in this patient group');
        return [];
      }

      // Get FCM tokens for each caregiver
      List<String> tokens = [];

      for (String caregiverId in actualCaregivers) {
        final userDoc = await _firestore.collection('users').doc(caregiverId).get();

        if (userDoc.exists) {
          final userData = userDoc.data()!;
          final token = userData['fcmToken'] as String?;

          if (token != null && token.isNotEmpty) {
            tokens.add(token);
          } else {
            print('⚠️ Caregiver $caregiverId has no FCM token');
          }
        }
      }

      print('✅ Found ${tokens.length} caregiver tokens');
      return tokens;
    } catch (e) {
      print('❌ Error getting caregiver tokens: $e');
      return [];
    }
  }

  /// Send FCM notification to multiple tokens using Cloud Function
  Future<void> _sendNotificationToTokens({
    required List<String> tokens,
    required String title,
    required String body,
    Map<String, String>? data,
  }) async {
    try {
      final functions = FirebaseFunctions.instance;

      final callable = functions.httpsCallable('sendCaregiverNotification');

      final response = await callable.call({
        'tokens': tokens,
        'title': title,
        'body': body,
        'notificationData': data ?? {},
      });

      print('✅ Cloud Function response: ${response.data}');
    } catch (e) {
      print('❌ Error calling Cloud Function: $e');
    }
  }

  /// Format DateTime to readable time string
  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour > 12 ? dateTime.hour - 12 : (dateTime.hour == 0 ? 12 : dateTime.hour);
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = dateTime.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }
}