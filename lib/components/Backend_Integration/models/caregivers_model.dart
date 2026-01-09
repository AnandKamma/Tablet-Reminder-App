class CaregiverSettingsModel {
  final bool notifyCaregivers; // Notify caregivers when meds are taken
  final String? lateWindow; // "15 Min", "30 Min", "45 Min", "60 Min"

  CaregiverSettingsModel({
    required this.notifyCaregivers,
    this.lateWindow,
  });

  Map<String, dynamic> toMap() {
    return {
      'notifyCaregivers': notifyCaregivers,
      if (lateWindow != null) 'lateWindow': lateWindow,
    };
  }

  factory CaregiverSettingsModel.fromMap(Map<String, dynamic> map) {
    return CaregiverSettingsModel(
      notifyCaregivers: map['notifyCaregivers'] ?? false,
      lateWindow: map['lateWindow'],
    );
  }
}