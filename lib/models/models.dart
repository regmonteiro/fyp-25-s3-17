import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfile {
  final String uid;
  final String? email;
  final String? firstName;
  final String? lastName;
  final String? userType;
  final String? elderId;

  UserProfile({
    required this.uid,
    this.email,
    this.firstName,
    this.lastName,
    this.userType,
    this.elderId,
  });

  String get displayName {
    if (firstName != null && lastName != null) return '$firstName $lastName';
    if (firstName != null) return firstName!;
    return 'User';
  }

  factory UserProfile.fromMap(Map<String, dynamic> map, String uid) {
    final rawUserType = map['userType'];
    return UserProfile(
      uid: uid,
      email: map['email'] as String?,
      firstName: map['firstName'] as String?,
      lastName: map['lastName'] as String?,
      userType: rawUserType is String ? rawUserType.trim().toLowerCase() : null,
      elderId: map['elderId'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'firstName': firstName,
      'lastName': lastName,
      'userType': userType,
      'elderId': elderId,
    };
  }

  factory UserProfile.fromDocumentSnapshot(DocumentSnapshot doc) {
    return UserProfile.fromMap(doc.data() as Map<String, dynamic>, doc.id);
  }
}

// UI data
class ElderlyInfo {
  final String uid;
  final String? firstName;
  final String? lastName;
  final String? dob;
  final String? phone;

  ElderlyInfo({required this.uid, this.firstName, this.lastName, this.dob, this.phone});

  String get fullName {
    final f = firstName ?? 'Unknown';
    final l = lastName ?? 'User';
    return '$f $l';
  }
}

class Appointment {
  final String id;
  final String title;
  final String date; // YYYY-MM-DD
  final String? time;
  final String? location;
  final String elderId;
  final String? notes;

  Appointment({
    required this.id,
    required this.title,
    required this.date,
    required this.elderId,
    this.time,
    this.location,
    this.notes,
  });
}

class MedicationReminder {
  final String id;
  final String medicationName;
  final String dosage;
  final String elderId;
  final String? reminderTime; // HH:mm
  final String? date;         // YYYY-MM-DD
  String status;              // pending/completed

  MedicationReminder({
    required this.id,
    required this.medicationName,
    required this.dosage,
    required this.elderId,
    this.reminderTime,
    this.date,
    this.status = 'pending',
  });
}

class EventReminder {
  final String id;
  final String title;
  final String elderId;
  final String? description;
  final String? startTime; // ISO

  EventReminder({
    required this.id,
    required this.title,
    required this.elderId,
    this.description,
    this.startTime,
  });
}

class NotificationItem {
  final String id;
  final String title;
  final String message;
  final String priority;
  final int timestamp;
  final bool read;
  final String? elderlyName;

  NotificationItem({
    required this.id,
    required this.title,
    required this.message,
    required this.priority,
    required this.timestamp,
    required this.read,
    this.elderlyName,
  });
}
