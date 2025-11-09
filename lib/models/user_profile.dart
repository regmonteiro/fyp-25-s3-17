import 'package:cloud_firestore/cloud_firestore.dart';

/// Helper to parse any date type safely.
DateTime? parseAnyDate(dynamic v) {
  if (v == null) return null;
  if (v is Timestamp) return v.toDate();                      // Firestore Timestamp
  if (v is int) return DateTime.fromMillisecondsSinceEpoch(v); // RTDB ms epoch
  if (v is String) return DateTime.tryParse(v);                // ISO string
  return null;
}

class UserProfile {
  // ------------------ Core Identity ------------------
  final String uid;
  final String? email;
  final String? displayName;
  final String? firstname;
  final String? lastname;
  final String? userType;
  final String? phoneNum;

  final String? elderlyId;


  final List<String>? elderlyIds;


  final DateTime? dob;
  final DateTime? createdAt;


  UserProfile({
    required this.uid,
    this.email,
    this.displayName,
    this.firstname,
    this.lastname,
    this.userType,
    this.phoneNum,
    this.elderlyId,
    this.elderlyIds,
    this.dob,
    this.createdAt,
  });

  // ------------------ Computed Properties ------------------
  String get safeDisplayName {
    if ((displayName ?? '').isNotEmpty) return displayName!;
    if ((firstname ?? '').isNotEmpty && (lastname ?? '').isNotEmpty) {
      return '$firstname $lastname';
    }
    if ((firstname ?? '').isNotEmpty) return firstname!;
    return 'User';
  }

  // ------------------ Factory Builders ------------------
  factory UserProfile.fromMap(Map<String, dynamic> map, String uid) {
    return UserProfile(
      uid: uid,
      email: map['email'] as String?,
      displayName: (map['displayName'] ?? '').toString().trim(),
      firstname: (map['firstname'] ?? map['firstname'] ?? '').toString().trim(),
      lastname: (map['lastname'] ?? map['lastname'] ?? '').toString().trim(),
      userType: (map['userType'] as String?)?.trim().toLowerCase(),
      phoneNum: (map['phoneNum'] ?? map['phone'] ?? '').toString().trim(),
      elderlyId: map['elderlyId'] as String?,
      elderlyIds: (map['elderlyIds'] as List?)?.map((e) => e.toString()).toList(),
      dob: parseAnyDate(map['dob']),
      createdAt: parseAnyDate(map['createdAt']),
    );
  }

  factory UserProfile.fromDocumentSnapshot(DocumentSnapshot<Map<String, dynamic>> snap) {
    final data = snap.data() ?? <String, dynamic>{};
    return UserProfile.fromMap(data, snap.id);
  }

  // ------------------ Serialization ------------------
  Map<String, dynamic> toFirestoreMap() => {
        'uid': uid,
        'email': email,
        'displayName': displayName,
        'firstname': firstname,
        'lastname': lastname,
        'userType': userType,
        'phoneNum': phoneNum,
        'elderlyId': elderlyId,
        'elderlyIds': elderlyIds,
        if (dob != null) 'dob': Timestamp.fromDate(dob!),
        if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
      }..removeWhere((k, v) => v == null);

  Map<String, dynamic> toRealtimeMap() => {
        'uid': uid,
        'email': email,
        'displayName': displayName,
        'firstname': firstname,
        'lastname': lastname,
        'userType': userType,
        'phoneNum': phoneNum,
        'elderlyId': elderlyId,
        'elderlyIds': elderlyIds,
        if (dob != null) 'dobMs': dob!.millisecondsSinceEpoch,
        if (createdAt != null) 'createdAtMs': createdAt!.millisecondsSinceEpoch,
      }..removeWhere((k, v) => v == null);

  Map<String, dynamic> toModelMap() => {
        'uid': uid,
        'email': email,
        'displayName': displayName,
        'firstname': firstname,
        'lastname': lastname,
        'userType': userType,
        'phoneNum': phoneNum,
        'elderlyId': elderlyId,
        'elderlyIds': elderlyIds,
        'dob': dob,
        'createdAt': createdAt,
      }..removeWhere((k, v) => v == null);
}
