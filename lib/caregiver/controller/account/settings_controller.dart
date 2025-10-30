import 'package:cloud_firestore/cloud_firestore.dart';

class SettingsController {
  final _db = FirebaseFirestore.instance;

  Future<Map<String, dynamic>?> getReminderSettings(String uid) async {
    final doc = await _db.collection('Settings').doc(uid).get();
    return doc.data();
  }

  Future<void> saveReminderSettings(String uid, int minutes) {
    return _db.collection('Setings').doc(uid).set(
      {'reminderTimeInMinutes': minutes},
      SetOptions(merge: true),
    );
  }

  Future<double> getFontScale(String uid) async {
    final doc = await _db.collection('Settings').doc(uid).get();
    final data = doc.data();
    if (data == null) return 1.0;
    final v = data['fontScale'];
    if (v is num) return v.toDouble().clamp(0.8, 1.6);
    return 1.0;
  }

  Future<void> saveFontScale(String uid, double scale) {
    return _db.collection('Settings').doc(uid).set(
      {'fontScale': scale},
      SetOptions(merge: true),
    );
  }
}
