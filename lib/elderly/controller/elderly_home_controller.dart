import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rxdart/rxdart.dart';


class UpcomingEvent {
  final String id;
  final String title;
  final DateTime start;
  final DateTime end;
  UpcomingEvent({required this.id, required this.title, required this.start, required this.end});

  factory UpcomingEvent.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    final tsStart = d['start'] as Timestamp?;
    final tsEnd   = d['end'] as Timestamp?;
    return UpcomingEvent(
      id: doc.id,
      title: (d['title'] as String?) ?? 'Untitled',
      start: tsStart?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0),
      end:   tsEnd?.toDate()   ?? DateTime.fromMillisecondsSinceEpoch(0),
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
    // 1) Stream of events created by the elderly user (or general events targeted at them)
    final elderlyEventsStream = _db
  .collection('events')
  .where('elderlyUserId', isEqualTo: elderlyUid)
  .where('start', isGreaterThanOrEqualTo: Timestamp.now())
  .orderBy('start')
  .snapshots()
  .map((snap) => snap.docs);

final caregiverEventsStream = _db
  .collection('users')
  .doc(elderlyUid)
  .snapshots()
  .switchMap((userSnap) {
    final linked = (userSnap.data()?['linkedCaregivers'] as List?)?.map((e) => e.toString()).toList() ?? <String>[];
    final caregiversForQuery = linked.length > 10 ? linked.sublist(0, 10) : linked;
    if (caregiversForQuery.isEmpty) {
      return Stream.value(<QueryDocumentSnapshot<Map<String, dynamic>>>[]);
    }
    return _db.collection('events')
      .where('elderlyUserId', isEqualTo: elderlyUid)
      .where('caregiverId', whereIn: caregiversForQuery)
      .where('start', isGreaterThanOrEqualTo: Timestamp.now())
      .orderBy('start')
      .snapshots()
      .map((snap) => snap.docs);
  });

    // 3) combine + deduplicate + sort + truncate to limit
    return Rx.combineLatest2<
        List<DocumentSnapshot<Map<String, dynamic>>>,
        List<DocumentSnapshot<Map<String, dynamic>>>,
        List<DocumentSnapshot<Map<String, dynamic>>>>(
      elderlyEventsStream,
      caregiverEventsStream,
      (elderlyDocs, caregiverDocs) {
        // FIX: Use a Map to deduplicate documents based on their unique ID
        final allDocsMap = <String, DocumentSnapshot<Map<String, dynamic>>>{
          for (var doc in elderlyDocs) doc.id: doc,
          for (var doc in caregiverDocs) doc.id: doc,
        };
        final all = allDocsMap.values.toList();

        // Sort the combined, deduplicated list by date
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

        // Apply the limit after sorting
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
