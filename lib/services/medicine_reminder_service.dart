import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

String emailKeyFrom(String email) {
  final lower = email.trim().toLowerCase();
  final at = lower.indexOf('@');
  if (at < 0) return lower.replaceAll('.', '_');
  final local = lower.substring(0, at);
  final domain = lower.substring(at + 1).replaceAll('.', '_');
  return '$local@$domain';
}

class MedicationReminder {
  final String id;
  final String medicationName;
  final String date;           // "yyyy-MM-dd"
  final String reminderTime;   // "HH:mm"
  final int repeatCount;
  final String? dosage;        // e.g., "500mg"
  final int quantity;          // default 1
  final bool isCompleted;
  final String createdAt;      // ISO string
  final String? completedAt;   // ISO string or null
  final String? notes;         // optional notes when marking as complete

  MedicationReminder({
    required this.id,
    required this.medicationName,
    required this.date,
    required this.reminderTime,
    required this.repeatCount,
    required this.quantity,
    required this.isCompleted,
    required this.createdAt,
    this.dosage,
    this.completedAt,
    this.notes,
  });

  Map<String, dynamic> toMap() => {
        'medicationName': medicationName,
        'date': date,
        'reminderTime': reminderTime,
        'repeatCount': repeatCount,
        'dosage': dosage,
        'quantity': quantity,
        'isCompleted': isCompleted,
        'createdAt': createdAt,
        'completedAt': completedAt,
        'notes': notes,
      };

  static MedicationReminder fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    return MedicationReminder(
      id: d.id,
      medicationName: (m['medicationName'] ?? '').toString(),
      date: (m['date'] ?? '').toString(),
      reminderTime: (m['reminderTime'] ?? '').toString(),
      repeatCount: int.tryParse('${m['repeatCount'] ?? 1}') ?? 1,
      dosage: (m['dosage'] as String?)?.toString(),
      quantity: int.tryParse('${m['quantity'] ?? 1}') ?? 1,
      isCompleted: (m['isCompleted'] as bool?) ?? false,
      createdAt: (m['createdAt'] ?? '').toString(),
      completedAt: (m['completedAt'] as String?)?.toString(),
      notes: (m['notes'] as String?)?.toString(),
    );
  }
}

class MedicineRemindersService {
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  MedicineRemindersService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  /// Current user's emailKey (caregiver or elderly)
  Future<String> _currentEmailKey() async {
    final u = _auth.currentUser;
    if (u == null || (u.email ?? '').isEmpty) {
      throw Exception('Not signed in / missing email');
    }
    return emailKeyFrom(u.email!);
  }

  /// Root path: /medicineReminders/{emailKey}/{elderlyId}/...
  CollectionReference<Map<String, dynamic>> _col(String emailKey, String elderlyId) {
    return _db
        .collection('medicationReminders')
        .doc(emailKey)
        .collection(elderlyId);
  }

  /// Subscribe to reminders (sorted client-side by date + time).
  Stream<List<MedicationReminder>> subscribe({
    required String elderlyId,
  }) async* {
    final emailKey = await _currentEmailKey();
    yield* _col(emailKey, elderlyId)
        .orderBy('createdAt', descending: true) // stable default
        .snapshots()
        .map((snap) => snap.docs.map(MedicationReminder.fromDoc).toList())
        .map((list) {
      list.sort((a, b) {
        // Combine date+time for ordering pending first by date/time; completed items keep position by createdAt fallback
        final aKey = '${a.date} ${a.reminderTime}';
        final bKey = '${b.date} ${b.reminderTime}';
        return aKey.compareTo(bKey);
      });
      return list;
    });
  }

  /// Create reminder
  Future<void> create({
    required String elderlyId,
    required String medicationName,
    required String date,         // yyyy-MM-dd
    required String reminderTime, // HH:mm
    required int repeatCount,
    String? dosage,
    required int quantity,
  }) async {
    final emailKey = await _currentEmailKey();
    await _col(emailKey, elderlyId).add({
      'medicationName': medicationName.trim(),
      'date': date,
      'reminderTime': reminderTime,
      'repeatCount': repeatCount,
      'dosage': (dosage ?? '').trim().isEmpty ? null : dosage!.trim(),
      'quantity': quantity,
      'isCompleted': false,
      'createdAt': DateTime.now().toIso8601String(),
      'completedAt': null,
      'notes': null,
    });
  }

  /// Delete reminder
  Future<void> delete({
    required String elderlyId,
    required String reminderId,
  }) async {
    final emailKey = await _currentEmailKey();
    await _col(emailKey, elderlyId).doc(reminderId).delete();
  }

  /// Toggle completion (optionally with notes)
  Future<void> toggleCompletion({
    required String elderlyId,
    required String reminderId,
    required bool markComplete,
    String? notes,
  }) async {
    final emailKey = await _currentEmailKey();
    final ref = _col(emailKey, elderlyId).doc(reminderId);
    if (markComplete) {
      await ref.update({
        'isCompleted': true,
        'completedAt': DateTime.now().toIso8601String(),
        'notes': (notes ?? '').trim().isEmpty ? null : notes!.trim(),
      });
    } else {
      await ref.update({
        'isCompleted': false,
        'completedAt': null,
        'notes': null,
      });
    }
  }

  /// Utility: fetch caregiver's linked elderly uid list (from Account doc)
  /// We resolve caregiver's emailKey, load Account[emailKey], and read 'elderlyIds' array.
  Future<List<String>> caregiverElderlyIds() async {
    final emailKey = await _currentEmailKey();
    final snap = await _db.collection('Account').doc(emailKey).get();
    final data = snap.data() ?? {};

    final List<String> out = [];

    // 1) If there's an array field `elderlyIds`, use that
    final rawList = data['elderlyIds'];
    if (rawList is List && rawList.isNotEmpty) {
      for (final e in rawList) {
        final v = e?.toString().trim();
        if (v != null && v.isNotEmpty) out.add(v);
      }
    }

    // 2) Also support single `elderlyId` field
    final single = (data['elderlyId'] ?? '').toString().trim();
    if (single.isNotEmpty && !out.contains(single)) {
      out.add(single);
    }

    return out;
  }

  Future<List<Map<String, String>>> elderlyBasicInfo(List<String> uids) async {
    final List<Map<String, String>> out = [];

    for (final raw in uids) {
      final uid = raw.trim();
      if (uid.isEmpty) continue;

      try {
        DocumentSnapshot<Map<String, dynamic>>? acct;
        String? resolvedUid = uid;

        // 1) Try mapping via AccountByUid/{uid}
        final byUid =
            await _db.collection('AccountByUid').doc(uid).get();
        final ek = (byUid.data()?['emailKey'] as String?)?.trim();

        if (ek != null && ek.isNotEmpty) {
          // 2) Fetch Account using emailKey
          acct = await _db.collection('Account').doc(ek).get();
        } else {
          // 3) Fallback: search Account where uid == this uid
          final q = await _db
              .collection('Account')
              .where('uid', isEqualTo: uid)
              .limit(1)
              .get();
          if (q.docs.isNotEmpty) {
            acct = q.docs.first;
            resolvedUid = (acct.data()?['uid'] ?? uid).toString();
          }
        }

        if (acct == null || !acct.exists) {
          continue;
        }

        final m = acct.data() ?? {};
        final first = (m['firstname'] ?? '').toString().trim();
        final last  = (m['lastname']  ?? '').toString().trim();
        final email = (m['email']     ?? '').toString().trim();

        out.add({
          'uid'      : resolvedUid,
          'firstname': first,
          'lastname' : last,
          'email'    : email,
        });
      } catch (e) {
        continue;
      }
    }

    return out;
  }

}
