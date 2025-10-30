import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rxdart/rxdart.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UpcomingEvent {
  final String id;
  final String title;
  final DateTime start;
  final DateTime end;

  UpcomingEvent({
    required this.id,
    required this.title,
    required this.start,
    required this.end,
  });

  factory UpcomingEvent.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    final tsStart = d['start'] as Timestamp?;
    final tsEnd = d['end'] as Timestamp?;
    return UpcomingEvent(
      id: doc.id,
      title: (d['title'] as String?) ?? 'Untitled',
      start: tsStart?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0),
      end: tsEnd?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

class ElderlyHomeController {
  final String uid;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  ElderlyHomeController({required this.uid});

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

  /// Query all caregiver-created event batches in parallel (`caregiverId IN` chunks of 10).
  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _caregiverEventBatches(
    String elderlyId,
    List<String> caregiverUids,
  ) {
    if (caregiverUids.isEmpty) {
      return Stream.value(const <QueryDocumentSnapshot<Map<String, dynamic>>>[]);
    }

    final streams = _chunks(caregiverUids, 10).map((chunk) {
      return _db
          .collection('events')
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

  Stream<List<DocumentSnapshot<Map<String, dynamic>>>> getEventsStream({int limit = 5}) {
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

      // A: elder's own events (use elderlyId )
      final a$ = _db
          .collection('events')
          .where('elderlyId', isEqualTo: elderlyId)
          .where('start', isGreaterThanOrEqualTo: Timestamp.now())
          .orderBy('start')
          .snapshots()
          .map((s) => s.docs);

      // B: optional legacy path
      final b$ = _db
          .collection('events')
          .where('uid', isEqualTo: elderlyId)
          .where('start', isGreaterThanOrEqualTo: Timestamp.now())
          .orderBy('start')
          .snapshots()
          .map((s) => s.docs);

      // C: caregiver-created events (batched)
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

  // These print to your Flutter/Xcode console
  // (Look for lines starting with "DEBUG:")
  // ignore: avoid_print
  print('DEBUG: caregivers for $currentUid = ${result.docs.length}');
  for (var doc in result.docs) {
    // ignore: avoid_print
    print('DEBUG: caregiver -> ${doc.id}');
  }
}


  Stream<List<UpcomingEvent>> getUpcomingEventsStream({int limit = 5}) {
    return getEventsStream(limit: limit)
        .map((docs) => docs.map((d) => UpcomingEvent.fromDoc(d)).toList(growable: false));
  }
}