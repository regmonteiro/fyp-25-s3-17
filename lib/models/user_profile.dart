class UserProfile {
  final String uid;
  final String name;
  final String role;
  final String? caregiverName; // Nullable for non-elderly users

  UserProfile({
    required this.uid,
    required this.name,
    required this.role,
    this.caregiverName,
  });

  // Factory constructor to create a UserProfile instance from a Firestore document map.
  factory UserProfile.fromMap(Map<String, dynamic> data) {
    return UserProfile(
      uid: data['uid'] as String? ?? '',
      name: data['name'] as String? ?? '',
      role: data['role'] as String? ?? '',
      caregiverName: data['caregiverName'] as String?,
    );
  }
}