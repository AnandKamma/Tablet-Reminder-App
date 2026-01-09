import 'package:cloud_firestore/cloud_firestore.dart';

class PatientGroupModel {
  final String patientGroupID;
  final String deviceID;
  final String patientUID;
  final List<String> caregivers;
  final ReminderStatus reminderStatus;

  PatientGroupModel({
    required this.patientGroupID,
    required this.deviceID,
    required this.patientUID,
    required this.caregivers,
    required this.reminderStatus,
  });

  // Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'device_id': deviceID,
      'patient_uid': patientUID,
      'caregivers': caregivers,
      'reminder_status': reminderStatus.toMap(),
    };
  }

  // Create from Firestore Map
  factory PatientGroupModel.fromMap(Map<String, dynamic> map, String patientGroupID) {
    return PatientGroupModel(
      patientGroupID: patientGroupID,
      deviceID: map['device_id'] ?? '',
      patientUID: map['patient_uid'] ?? '',
      caregivers: List<String>.from(map['caregivers'] ?? []),
      reminderStatus: ReminderStatus.fromMap(map['reminder_status'] ?? {}),
    );
  }
}

class ReminderStatus {
  final bool isActive;
  final Timestamp? timestamp;

  ReminderStatus({
    required this.isActive,
    this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'isActive': isActive,
      'timestamp': timestamp ?? FieldValue.serverTimestamp(),
    };
  }

  factory ReminderStatus.fromMap(Map<String, dynamic> map) {
    return ReminderStatus(
      isActive: map['isActive'] ?? false,
      timestamp: map['timestamp'] as Timestamp?,
    );
  }
}