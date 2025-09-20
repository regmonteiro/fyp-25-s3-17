import 'package:cloud_firestore/cloud_firestore.dart';
class UserProfile {
  final String uid;
  final String? email;
  final String? firstName;
  final String? lastName;
  final String? role;
  final String? uidOfElder;

  UserProfile({
    required this.uid,
    this.email,
    this.firstName,
    this.lastName,
    this.role,
    this.uidOfElder,
  });

  String get displayName {
    if (firstName != null && lastName != null) return '$firstName $lastName';
    if (firstName != null) return firstName!;
    return 'User';
  }

  factory UserProfile.fromMap(Map<String, dynamic> map, String uid) {
    final rawRole = map['role'];
    return UserProfile(
      uid: uid,
      email: map['email'] as String?,
      firstName: map['firstName'] as String?,
      lastName: map['lastName'] as String?,
      role: rawRole is String ? rawRole.trim().toLowerCase() : null,
      uidOfElder: map['uidOfElder'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'firstName': firstName,
      'lastName': lastName,
      'role': role,
      'uidOfElder': uidOfElder,
    };
  }

  factory UserProfile.fromDocumentSnapshot(DocumentSnapshot doc) {
    return UserProfile.fromMap(doc.data() as Map<String, dynamic>, doc.id);
  }
}
