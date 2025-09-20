import 'package:cloud_firestore/cloud_firestore.dart';

class SettingsController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> saveReminderSettings(String userId, int reminderTimeInMinutes) async {
    try {
      final docRef = _firestore.collection('users').doc(userId).collection('settings').doc('reminders');
      await docRef.set({
        'reminderTimeInMinutes': reminderTimeInMinutes,
      }, SetOptions(merge: true));
    } catch (e) {
      print("Error saving reminder settings: $e");
    }
  }

  Future<Map<String, dynamic>?> getReminderSettings(String userId) async {
    try {
      final docSnapshot = await _firestore.collection('users').doc(userId).collection('settings').doc('reminders').get();
      if (docSnapshot.exists) {
        return docSnapshot.data();
      }
    } catch (e) {
      print("Error getting reminder settings: $e");
    }
    return null;
  }
}