import 'package:cloud_firestore/cloud_firestore.dart';

/// One parser to handle Firestore Timestamp, RTDB ms epoch, or ISO-8601 string.
DateTime? parseAnyDate(dynamic v) {
  if (v == null) return null;
  if (v is Timestamp) return v.toDate();                      // Firestore
  if (v is int) return DateTime.fromMillisecondsSinceEpoch(v); // Realtime DB (ms)
  if (v is String) return DateTime.tryParse(v);                // ISO string
  return null;
}

class UserProfile {
  final String uid;
  final String? email;
  final String? displayName;
  final String? firstName;
  final String? lastName;
  final String? userType;
  final String? elderlyId;

  /// Store as DateTime in the model regardless of backend type.
  final DateTime? dob;
  final DateTime? createdAt;

  final List<String>? linkedElders;
  final List<String>? linkedCaregivers;

  UserProfile({
    required this.uid,
    this.email,
    this.firstName,
    this.displayName,
    this.lastName,
    this.userType,
    this.elderlyId,
    this.dob,
    this.createdAt,
    this.linkedElders,
    this.linkedCaregivers,
  });

  String get safeDisplayName {
    if ((displayName ?? '').isNotEmpty) return displayName!;
    if ((firstName ?? '').isNotEmpty && (lastName ?? '').isNotEmpty) {
      return '$firstName $lastName';
    }
    if ((firstName ?? '').isNotEmpty) return firstName!;
    return 'User';
  }

  /// Build from a generic Map (works for Firestore & RTDB payloads).
  factory UserProfile.fromMap(Map<String, dynamic> map, String uid) {
    final rawUserType = map['userType'];
    return UserProfile(
      uid: uid,
      email: map['email'] as String?,
      displayName: (map['displayName'] as String?)?.trim(),
      firstName: (map['firstName'] as String?)?.trim(),
      lastName: (map['lastName'] as String?)?.trim(),
      userType: rawUserType is String ? rawUserType.trim().toLowerCase() : null,
      elderlyId: map['elderlyId'] as String?,
      dob: parseAnyDate(map['dob'] ?? map['dobMs']),
      createdAt: parseAnyDate(map['createdAt'] ?? map['createdAtMs']),
      linkedElders:
          (map['linkedElders'] as List?)?.map((e) => e.toString()).toList(),
      linkedCaregivers:
          (map['linkedCaregivers'] as List?)?.map((e) => e.toString()).toList(),
    );
  }

  /// Build specifically from a Firestore doc snapshot.
  factory UserProfile.fromDocumentSnapshot(
      DocumentSnapshot<Map<String, dynamic>> snap) {
    final m = snap.data() ?? <String, dynamic>{};
    return UserProfile(
      uid: snap.id,
      email: m['email'] as String?,
      displayName: (m['displayName'] as String?)?.trim(),
      firstName: (m['firstName'] as String?)?.trim(),
      lastName: (m['lastName'] as String?)?.trim(),
      userType: (m['userType'] as String?)?.trim().toLowerCase(),
      elderlyId: m['elderlyId'] as String?,
      dob: parseAnyDate(m['dob'] ?? m['dobMs']),
      createdAt: parseAnyDate(m['createdAt'] ?? m['createdAtMs']),
      linkedElders:
          (m['linkedElders'] as List?)?.map((e) => e.toString()).toList(),
      linkedCaregivers:
          (m['linkedCaregivers'] as List?)?.map((e) => e.toString()).toList(),
    );
  }

  /// Optional: a neutral in-memory map (not for direct Firestore/RTDB writes).
  Map<String, dynamic> toModelMap() => {
        'uid': uid,
        'email': email,
        'displayName': displayName,
        'firstName': firstName,
        'lastName': lastName,
        'userType': userType,
        'elderlyId': elderlyId,
        'dob': dob,               // Keep as DateTime in memory
        'createdAt': createdAt,   // Keep as DateTime in memory
        'linkedElders': linkedElders,
        'linkedCaregivers': linkedCaregivers,
      }..removeWhere((k, v) => v == null);

  /// For Firestore writes (DateTime → Timestamp).
  Map<String, dynamic> toFirestoreMap() => {
        'uid': uid,
        'email': email,
        'displayName': displayName,
        'firstName': firstName,
        'lastName': lastName,
        'userType': userType,
        'elderlyId': elderlyId,
        if (dob != null) 'dob': Timestamp.fromDate(dob!),
        if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
        'linkedElders': linkedElders,
        'linkedCaregivers': linkedCaregivers,
      }..removeWhere((k, v) => v == null);

  /// For Realtime Database writes (DateTime → ms epoch ints).
  Map<String, dynamic> toRealtimeMap() => {
        'uid': uid,
        'email': email,
        'displayName': displayName,
        'firstName': firstName,
        'lastName': lastName,
        'userType': userType,
        'elderlyId': elderlyId,
        if (dob != null) 'dobMs': dob!.millisecondsSinceEpoch,
        if (createdAt != null) 'createdAtMs': createdAt!.millisecondsSinceEpoch,
        'linkedElders': linkedElders,
        'linkedCaregivers': linkedCaregivers,
      }..removeWhere((k, v) => v == null);
}
