class MedicationModel {
  final String name;
  final String strength;
  final String frequency; // "Once", "Twice", "Thrice"

  MedicationModel({
    required this.name,
    required this.strength,
    required this.frequency,
  });

  // Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'strength': strength,
      'frequency': frequency,
    };
  }

  // Create from Firestore Map
  factory MedicationModel.fromMap(Map<String, dynamic> map) {
    return MedicationModel(
      name: map['name'] ?? '',
      strength: map['strength'] ?? '',
      frequency: map['frequency'] ?? 'Once',
    );
  }
}