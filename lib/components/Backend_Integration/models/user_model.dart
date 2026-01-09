class UserModel {
  final String uid;
  final String email;
  final String fullName;
  final String signInMethod;
  final String? patientGroupID;

  UserModel({
    required this.uid,
    required this.email,
    required this.fullName,
    required this.signInMethod,
    this.patientGroupID,
  });

  // Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'fullName': fullName,
      'signInMethod': signInMethod,
      if (patientGroupID != null) 'patientGroupID': patientGroupID,
    };
  }

  // Create from Firestore Map
  factory UserModel.fromMap(Map<String, dynamic> map, String uid) {
    return UserModel(
      uid: uid,
      email: map['email'] ?? '',
      fullName: map['fullName'] ?? '',
      signInMethod: map['signInMethod'] ?? '',
      patientGroupID: map['patientGroupID'],
    );
  }
}