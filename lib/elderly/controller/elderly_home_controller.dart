import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rxdart/rxdart.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

// ---------------- Reminders model (field-based)
class EventReminder {
  final String id;        // field name under reminders/{userKey}
  final String title;
  final String startTime; // ISO-8601 string
  final int duration;     // minutes
  final String createdAt; // ISO-8601 string

  EventReminder({
    required this.id,
    required this.title,
    required this.startTime,
    required this.duration,
    required this.createdAt,
  });

  factory EventReminder.fromMap(String id, Map<String, dynamic> m) {
    int _toInt(Object? v) {
      if (v is int) return v;
      if (v is double) return v.toInt();
      return int.tryParse(v?.toString() ?? '') ?? 0;
    }

    return EventReminder(
      id: id,
      title: (m['title'] ?? '').toString(),
      startTime: (m['startTime'] ?? '').toString(),
      duration: _toInt(m['duration']),
      createdAt: (m['createdAt'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toMap() => {
        'title': title,
        'startTime': startTime,
        'duration': duration,
        'createdAt': createdAt,
      };

  bool isValid() =>
      title.trim().isNotEmpty && startTime.trim().isNotEmpty && duration > 0;
}

class ElderlyHomeController {
  final String uid;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  ElderlyHomeController({required this.uid});

  // -----------------------------------------------------------
  // Reminders: direct Firestore access (no service file needed)
  // /reminders/{userKey} where userKey is email with '.' and '@' replaced by '_'
  // Each reminder is stored as a FIELD named by a random id.
  // -----------------------------------------------------------

  String _emailToKey(String email) {
  final lower = email.trim().toLowerCase();
  final at = lower.indexOf('@');
  if (at < 0) return lower.replaceAll('.', '_');
  final local  = lower.substring(0, at);
  final domain = lower.substring(at + 1).replaceAll('.', '_');
  return '$local@$domain'; // e.g. elderly@gmail_com
}

Future<String?> _resolveUserKeyFromAccount() async {
  final fs = FirebaseFirestore.instance;
  final u = FirebaseAuth.instance.currentUser;
  if (u == null) return null;

  // Try /AccountByUid first
  final snap = await fs.collection('AccountByUid').doc(u.uid).get();
  final key = (snap.data()?['emailKey'] as String?)?.trim();
  if (key != null && key.isNotEmpty) return key;

  // Fallback to auth email
  final mail = u.email?.trim().toLowerCase();
  if (mail != null && mail.isNotEmpty) {
    return _emailToKey(mail);
  }

  return null;
}


  Future<DocumentReference<Map<String, dynamic>>?> _remindersDocRef() async {
    final key = await _resolveUserKeyFromAccount();
    if (key == null) return null;
    return _db.collection('reminders').doc(key);
  }

  /// Stream: list reminders sorted by startTime (ISO string)
  Stream<List<EventReminder>> reminders$() {
    return Stream.fromFuture(_remindersDocRef()).switchMap((doc) {
      if (doc == null) return Stream.value(const <EventReminder>[]);
      return doc.snapshots().map((snap) {
        if (!snap.exists) return <EventReminder>[];
        final data = snap.data() ?? {};
        final out = <EventReminder>[];
        for (final e in data.entries) {
          final id = e.key;
          final v = e.value;
          if (v is Map<String, dynamic>) {
            out.add(EventReminder.fromMap(id, v));
          } else if (v is Map) {
            out.add(EventReminder.fromMap(id, Map<String, dynamic>.from(v)));
          }
        }
        out.sort((a, b) {
          final ax = DateTime.tryParse(a.startTime) ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bx = DateTime.tryParse(b.startTime) ?? DateTime.fromMillisecondsSinceEpoch(0);
          return ax.compareTo(bx);
        });
        return out;
      });
    });
  }

  Future<void> createReminder({
    required String title,
    required DateTime start,
    required int durationMinutes,
  }) async {
    final doc = await _remindersDocRef();
    if (doc == null) throw Exception('No Account/email key found.');
    final id = _db.collection('_ids').doc().id;
    final reminder = EventReminder(
      id: id,
      title: title.trim(),
      startTime: start.toIso8601String(),
      duration: durationMinutes,
      createdAt: DateTime.now().toIso8601String(),
    );
    if (!reminder.isValid()) {
      throw Exception('Invalid reminder data');
    }
    await doc.set({id: reminder.toMap()}, SetOptions(merge: true));
  }

  Future<void> updateReminder({
  required String reminderId,
  String? title,
  DateTime? start,
  int? durationMinutes,
}) async {
  final doc = await _remindersDocRef();
  if (doc == null) throw Exception('No Account/email key found.');

  final update = <String, dynamic>{
    if (title != null) 'title': title.trim(),
    if (start != null) 'startTime': DateFormat("yyyy-MM-ddTHH:mm").format(start),
    if (durationMinutes != null) 'duration': durationMinutes is int ? durationMinutes : int.tryParse('$durationMinutes'),
    'createdAt': DateTime.now().toIso8601String(),
  };

  if (update.containsKey('duration')) {
    final d = update['duration'] as int? ?? 0;
    if (d <= 0) throw Exception('Invalid duration');
  }

  await doc.set({ reminderId: update }, SetOptions(merge: true));
}

Future<void> deleteReminder(String reminderId) async {
  final doc = await _remindersDocRef();
  if (doc == null) throw Exception('No Account/email key found.');
  try {
    await doc.update({ reminderId: FieldValue.delete() });
  } on FirebaseException catch (e) {
    if (e.code == 'not-found') {
      // Create the parent doc empty so we can delete the field safely next time.
      await doc.set(const <String, dynamic>{}, SetOptions(merge: true));
      // No field present to delete; treat as already gone.
      return;
    }
    rethrow;
  }
}


  Stream<List<Map<String, dynamic>>> caregiversForElder$(String elderlyId) {
  final db = FirebaseFirestore.instance;

  // A) Reverse lookup (caregiver docs where elderlyIds contains elder uid)
  final reverse$ = db
      .collection('Account')
      .where('elderlyIds', arrayContains: elderlyId)
      .snapshots()
      .map((qs) => qs.docs);

  // B) Forward lookup (elder doc lists linkedCaregivers -> fetch those docs)
  final forward$ = db.collection('Account').doc(elderlyId).snapshots().switchMap((snap) {
    final data = snap.data() ?? {};
    final List<dynamic> linked = (data['linkedCaregivers'] as List?) ?? const [];
    final caregiverIds = linked.whereType<String>().map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

    if (caregiverIds.isEmpty) {
      return Stream.value(<QueryDocumentSnapshot<Map<String, dynamic>>>[]);
    }


    // Firestore whereIn max 10 → chunk
    Iterable<List<String>> chunks(List<String> xs, int size) sync* {
      for (var i = 0; i < xs.length; i += size) {
        yield xs.sublist(i, (i + size > xs.length) ? xs.length : i + size);
      }
    }

    final streams = [
      for (final chunk in chunks(caregiverIds, 10))
        db
          .collection('Account')
          .where(FieldPath.documentId, whereIn: chunk)
          .snapshots()
          .map((s) => s.docs),
    ];

    return streams.isEmpty
        ? Stream.value(<QueryDocumentSnapshot<Map<String, dynamic>>>[])
        : Rx.combineLatestList(streams).map((lists) => lists.expand((x) => x).toList());
  });

  // Merge both, de-dup by doc id, map to display model
  return Rx.combineLatest2(reverse$, forward$, (a, b) {
    final map = <String, Map<String, dynamic>>{};
    for (final d in a.followedBy(b)) {
      final m = d.data();
      final first = (m['firstName'] ?? m['firstname'] ?? '').toString().trim();
      final last  = (m['lastName']  ?? m['lastname']  ?? '').toString().trim();
      final safe  = (m['safeDisplayName'] ?? m['displayName'] ?? '').toString().trim();
      final name  = safe.isNotEmpty ? safe : [first, last].where((x) => x.isNotEmpty).join(' ').trim();

      map[d.id] = {
        'uid': d.id,
        'name': name.isEmpty ? 'Caregiver' : name,
        'email': (m['email'] ?? '').toString(),
        'phone': (m['phoneNum'] ?? m['caregiverPhone'] ?? '').toString(),
        'photoUrl': (m['photoURL'] ?? m['photoUrl'] ?? '').toString(),
        'userType': (m['userType'] ?? '').toString(),
      };
    }
    return map.values.toList();
  });
}



  Stream<String> _elderId$() {
    return _db.collection('Account').doc(uid).snapshots().map((snap) {
      final data = snap.data() ?? {};
      final elderlyId = (data['elderlyId'] as String?)?.trim();
      if (elderlyId != null && elderlyId.isNotEmpty) return elderlyId;

      final elderlyIds = data['elderlyIds'];
      if (elderlyIds is List && elderlyIds.isNotEmpty && elderlyIds.first is String) {
        final first = (elderlyIds.first as String).trim();
        if (first.isNotEmpty) return first;
      }

      return snap.id; // fallback to uid
    }).distinct();
  }

  /// Normalize caregiver links into a list of caregiver uids.
  static List<String> _extractCaregiverUids(Object? raw) {
    final list = (raw as List?) ?? const [];
    return list
        .map<String>((e) {
          if (e is String) return e.trim();
          if (e is Map) {
            final m = Map<String, dynamic>.from(e);
            final id = (m['uid'] as String?)?.trim();
            if (id != null && id.isNotEmpty) return id;
          }
          return '';
        })
        .where((s) => s.isNotEmpty)
        .toList(growable: false);
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> getAnnouncementsStream() {
    return _db
        .collection('announcements')
        .orderBy('createdAt', descending: true)
        .limit(5)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> getLearningRecommendationsStream() {
    return _db
        .collection('learningRecommendations')
        .orderBy('createdAt', descending: true)
        .limit(5)
        .snapshots();
  }

  /// Helper: split a list into chunks of [size]
  static Iterable<List<T>> _chunks<T>(List<T> items, int size) sync* {
    for (var i = 0; i < items.length; i += size) {
      final end = (i + size > items.length) ? items.length : i + size;
      yield items.sublist(i, end);
    }
  }

  /// Query all caregiver-created appointments batches in parallel (`caregiverId IN` chunks of 10).
  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _caregiverEventBatches(
    String elderlyId,
    List<String> caregiverUids,
  ) {
    if (caregiverUids.isEmpty) {
      return Stream.value(const <QueryDocumentSnapshot<Map<String, dynamic>>>[]);
    }

    final streams = _chunks(caregiverUids, 10).map((chunk) {
      return _db
          .collection('Appointments')
          .where('elderlyId', isEqualTo: elderlyId)
          .where('caregiverId', whereIn: chunk)
          .where('start', isGreaterThanOrEqualTo: Timestamp.now())
          .orderBy('start')
          .snapshots()
          .map((s) => s.docs);
    }).toList();

    // Wait for all chunk streams each tick, then flatten
    return Rx.combineLatestList(streams).map(
      (lists) => lists.expand((x) => x).toList(growable: false),
    );
  }

  Stream<List<DocumentSnapshot<Map<String, dynamic>>>> getAppointmentsStream({int limit = 5}) {
    final account$ = _db.collection('Account').doc(uid).snapshots();

    // use _elderId$ (not _elderlyId$), and pass the resolved elderlyId forward
    return Rx.combineLatest2<String, DocumentSnapshot<Map<String, dynamic>>, Map<String, dynamic>>(
      _elderId$(),
      account$,
      (elderlyId, accountSnap) => {'elderlyId': elderlyId, 'accountSnap': accountSnap},
    ).switchMap((ctx) {
      final String elderlyId = ctx['elderlyId'] as String;
      final accountSnap = ctx['accountSnap'] as DocumentSnapshot<Map<String, dynamic>>;

      final linkedCaregivers = _extractCaregiverUids(accountSnap.data()?['linkedCaregivers']);

      // A: elder's own appointments (use elderlyId )
      final a$ = _db
          .collection('Appointments')
          .where('elderlyId', isEqualTo: elderlyId)
          .where('start', isGreaterThanOrEqualTo: Timestamp.now())
          .orderBy('start')
          .snapshots()
          .map((s) => s.docs);

      // B: optional legacy path
      final b$ = _db
          .collection('Appointments')
          .where('uid', isEqualTo: elderlyId)
          .where('start', isGreaterThanOrEqualTo: Timestamp.now())
          .orderBy('start')
          .snapshots()
          .map((s) => s.docs);

      // C: caregiver-created appointments (batched)
      final c$ = _caregiverEventBatches(elderlyId, linkedCaregivers);

      return Rx.combineLatest3(a$, b$, c$, (a, b, c) {
        final map = <String, DocumentSnapshot<Map<String, dynamic>>>{};
        for (final d in a) map[d.id] = d;
        for (final d in b) map[d.id] = d;
        for (final d in c) map[d.id] = d;

        final all = map.values.toList(growable: false);

        all.sort((x, y) {
          final tx = x.data()?['start'] as Timestamp?;
          final ty = y.data()?['start'] as Timestamp?;
          if (tx == null && ty == null) return 0;
          if (tx == null) return 1;
          if (ty == null) return -1;
          return tx.compareTo(ty);
        });

        return all.take(limit).toList(growable: false);
      });
    });
  }

  // DEBUG: one-off probe to verify rules + data
Future<void> debugLogCaregiversForCurrentUser() async {
  final currentUid = FirebaseAuth.instance.currentUser!.uid;
  final result = await FirebaseFirestore.instance
      .collection('Account')
      .where('elderlyIds', arrayContains: currentUid)
      .get();

  print('DEBUG: caregivers for $currentUid = ${result.docs.length}');
  for (var doc in result.docs) {
    // ignore: avoid_print
    print('DEBUG: caregiver -> ${doc.id}');
  }
}
}