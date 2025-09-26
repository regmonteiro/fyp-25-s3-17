import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rxdart/rxdart.dart';

class UpcomingEvent {
  final String id;
  final String title;
  final DateTime dateTime;
  final String? location;
  final String? description;
  final String? caregiverId;
  final String elderlyUserId;

  UpcomingEvent({
    required this.id,
    required this.title,
    required this.dateTime,
    required this.elderlyUserId,
    this.location,
    this.description,
    this.caregiverId,
  });

  factory UpcomingEvent.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    final ts = data['dateTime'];
    final dt = ts is Timestamp
        ? ts.toDate()
        : ts is DateTime
            ? ts
            : DateTime.now();
    return UpcomingEvent(
      id: doc.id,
      title: (data['title'] ?? '').toString(),
      dateTime: dt,
      elderlyUserId: (data['elderlyUserId'] ?? '').toString(),
      location: data['location'] as String?,
      description: data['description'] as String?,
      caregiverId: data['caregiverId'] as String?,
    );
  }
}

class ElderlyHomeController {
  final String elderlyUid;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  ElderlyHomeController({required this.elderlyUid});

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
  Stream<List<DocumentSnapshot<Map<String, dynamic>>>> getEventsStream({int limit = 5}) {
    final elderlyEventsStream = _db
        .collection('events')
        .where('elderlyUserId', isEqualTo: elderlyUid)
        .where('dateTime', isGreaterThanOrEqualTo: Timestamp.now())
        .orderBy('dateTime')
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs);

    final caregiverEventsStream = _db
        .collection('users')
        .doc(elderlyUid)
        .snapshots()
        .switchMap((userSnap) {
      final linkedCaregiversRaw = userSnap.data()?['linkedCaregivers'];
      final linkedCaregivers = (linkedCaregiversRaw is List)
          ? linkedCaregiversRaw.map((e) => e.toString()).toList()
          : <String>[];

      final caregiversForQuery = linkedCaregivers.length > 10
          ? linkedCaregivers.sublist(0, 10)
          : linkedCaregivers;

      if (caregiversForQuery.isEmpty) {
        return Stream.value(<DocumentSnapshot<Map<String, dynamic>>>[]);
      }

      return _db
          .collection('events')
          .where('elderlyUserId', isEqualTo: elderlyUid)
          .where('caregiverId', whereIn: caregiversForQuery)
          .where('dateTime', isGreaterThanOrEqualTo: Timestamp.now())
          .orderBy('dateTime')
          .limit(limit)
          .snapshots()
          .map((snap) => snap.docs);
    });

    // 3) combine + sort + truncate to limit
    return Rx.combineLatest2<
        List<DocumentSnapshot<Map<String, dynamic>>>,
        List<DocumentSnapshot<Map<String, dynamic>>>,
        List<DocumentSnapshot<Map<String, dynamic>>>>(
      elderlyEventsStream,
      caregiverEventsStream,
      (elderlyDocs, caregiverDocs) {
        final all = <DocumentSnapshot<Map<String, dynamic>>>[
          ...elderlyDocs,
          ...caregiverDocs,
        ];

        all.sort((a, b) {
          final aDt = a.data()?['dateTime'];
          final bDt = b.data()?['dateTime'];
          final aTs = aDt is Timestamp ? aDt : null;
          final bTs = bDt is Timestamp ? bDt : null;
          if (aTs == null && bTs == null) return 0;
          if (aTs == null) return 1;
          if (bTs == null) return -1;
          return aTs.compareTo(bTs);
        });

        return all.take(limit).toList(growable: false);
      },
    );
  }

  Stream<List<UpcomingEvent>> getUpcomingEventsStream({int limit = 5}) {
    return getEventsStream(limit: limit).map(
      (docs) => docs.map((d) => UpcomingEvent.fromDoc(d)).toList(growable: false),
    );
  }
}
