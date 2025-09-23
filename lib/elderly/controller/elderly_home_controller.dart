
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rxdart/rxdart.dart';

class ElderlyHomeController {
  final String elderlyUid;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  ElderlyHomeController({required this.elderlyUid});

  Stream<QuerySnapshot> getAnnouncementsStream() {
    return _db.collection('announcements').orderBy('createdAt', descending: true).limit(5).snapshots();
  }

  Stream<QuerySnapshot> getLearningRecommendationsStream() {
    return _db.collection('learningRecommendations').orderBy('createdAt', descending: true).limit(5).snapshots();
  }

  // Corrected getEventsStream
  Stream<List<DocumentSnapshot>> getEventsStream() {
    // 1. Get the stream for events created by the elderly user
    final elderlyEventsStream = _db.collection('events')
        .where('elderlyUserId', isEqualTo: elderlyUid)
        .where('dateTime', isGreaterThanOrEqualTo: DateTime.now())
        .orderBy('dateTime')
        .limit(5)
        .snapshots()
        .map((snapshot) => snapshot.docs);

    // 2. Get the stream for events created by linked caregivers
    final caregiverEventsStream = _db.collection('users').doc(elderlyUid).snapshots().switchMap((userSnapshot) {
      final linkedCaregivers = userSnapshot.data()?['linkedCaregivers'] as List<dynamic>? ?? [];

      if (linkedCaregivers.isEmpty) {
        return Stream.value(<DocumentSnapshot>[]);
      }

      return _db.collection('events')
          .where('elderlyUserId', isEqualTo: elderlyUid)
          .where('caregiverId', whereIn: linkedCaregivers)
          .where('dateTime', isGreaterThanOrEqualTo: DateTime.now())
          .orderBy('dateTime')
          .limit(5)
          .snapshots()
          .map((snapshot) => snapshot.docs);
    });

    // 3. Combine both streams and sort the results
    return Rx.combineLatest2(elderlyEventsStream, caregiverEventsStream, (List<DocumentSnapshot> elderlyDocs, List<DocumentSnapshot> caregiverDocs) {
      final allDocs = [...elderlyDocs, ...caregiverDocs];
      allDocs.sort((a, b) {
        final dateA = (a.data() as Map<String, dynamic>)['dateTime'] as Timestamp;
        final dateB = (b.data() as Map<String, dynamic>)['dateTime'] as Timestamp;
        return dateA.compareTo(dateB);
      });
      return allDocs;
    });
  }
}