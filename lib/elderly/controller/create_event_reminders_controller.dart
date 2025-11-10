// lib/.../create_event_reminders_page.dart (or its own file you import)
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class Reminder {
  final String id;
  final String title;
  final String startTimeIso; // ISO string "yyyy-MM-ddTHH:mm" or full ISO-8601
  final int duration;
  final String createdAt;

  Reminder({
    required this.id,
    required this.title,
    required this.startTimeIso,
    required this.duration,
    required this.createdAt,
  });

  DateTime? get start => startTimeIso.isEmpty ? null : DateTime.tryParse(startTimeIso);

  Map<String, dynamic> toMap() => {
    'title': title,
    'startTime': startTimeIso,
    'duration': duration,
    'createdAt': createdAt,
  };

  static Reminder fromMap(String id, Map<String, dynamic> m) => Reminder(
    id: id,
    title: (m['title'] ?? '').toString(),
    startTimeIso: (m['startTime'] ?? '').toString(),
    duration: int.tryParse((m['duration'] ?? 0).toString()) ?? 0,
    createdAt: (m['createdAt'] ?? '').toString(),
  );
}

class ReminderService {
  final _db = FirebaseFirestore.instance;

  String _emailToKey(String email) {
    final lower = email.trim().toLowerCase();
    final at = lower.indexOf('@');
    if (at < 0) return lower.replaceAll('.', '_');
    final local  = lower.substring(0, at);
    final domain = lower.substring(at + 1).replaceAll('.', '_');
    return '$local@$domain'; // keep '@'
  }

  Future<String?> _resolveUserKeyFromAccount() async {
    final fs = FirebaseFirestore.instance;
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) return null;

    // Prefer /AccountByUid mapping (authoritative)
    final snap = await fs.collection('AccountByUid').doc(u.uid).get();
    final key = (snap.data()?['emailKey'] as String?)?.trim();
    if (key != null && key.isNotEmpty) return key;

    // Fallback to auth email → key
    final mail = u.email?.trim().toLowerCase();
    if (mail != null && mail.isNotEmpty) return _emailToKey(mail);

    return null;
  }

  Future<DocumentReference<Map<String, dynamic>>?> _remindersDocRef() async {
    final key = await _resolveUserKeyFromAccount();
    if (key == null) return null;
    return _db.collection('reminders').doc(key);
  }

  Stream<List<Reminder>> subscribeMine() async* {
  final doc = await _remindersDocRef();
  if (doc == null) {
    yield const <Reminder>[];
    return;
  }
  yield* doc.snapshots().map((snap) {
    if (!snap.exists) return <Reminder>[];
    final data = snap.data() ?? {};
    final items = <Reminder>[];
    for (final e in data.entries) {
      final v = e.value;
      if (v is Map<String, dynamic>) {
        items.add(Reminder.fromMap(e.key, v));
      } else if (v is Map) {
        items.add(Reminder.fromMap(e.key, Map<String, dynamic>.from(v)));
      }
    }
    items.sort((a, b) {
      final ax = a.start ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bx = b.start ?? DateTime.fromMillisecondsSinceEpoch(0);
      return ax.compareTo(bx);
    });
    return items;
    });
  }

  Future<void> create({
    required String title,
    required DateTime start,
    required int durationMinutes,
  }) async {
    final doc = await _remindersDocRef();
    if (doc == null) throw Exception('No Account/email key found.');

    final id = _db.collection('_ids').doc().id;
    await doc.set({
      'ownerEmailKey': doc.id,
      if (FirebaseAuth.instance.currentUser?.uid != null)
        'ownerUid': FirebaseAuth.instance.currentUser!.uid,
      id: {
        'title': title.trim(),
        // Use same format as your controller update (or pick full ISO consistently)
        'startTime': DateFormat("yyyy-MM-ddTHH:mm").format(start),
        'duration': durationMinutes,
        'createdAt': DateTime.now().toIso8601String(),
      }
    }, SetOptions(merge: true));
  }

  Future<void> update({
    required String id,
    required Reminder updated,
  }) async {
    final doc = await _remindersDocRef();
    if (doc == null) throw Exception('No Account/email key found.');
    await doc.set({ id: updated.toMap() }, SetOptions(merge: true));
  }

  Future<void> delete(String id) async {
    final doc = await _remindersDocRef();
    if (doc == null) throw Exception('No Account/email key found.');
    try {
      await doc.update({ id: FieldValue.delete() });
    } on FirebaseException catch (e) {
      if (e.code == 'not-found') {
        await doc.set(const <String, dynamic>{}, SetOptions(merge: true));
        return;
      }
      rethrow;
    }
  }
}
