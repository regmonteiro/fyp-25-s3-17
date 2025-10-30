import 'package:cloud_firestore/cloud_firestore.dart';

class MutualLinkingService {
  final _db = FirebaseFirestore.instance;

  Future<DocumentReference<Map<String, dynamic>>> _accountRefByUid(String uid) async {
    // Prefer a direct doc keyed by uid; if your collection is email-keyed, query by `uid` field.
    final byId = _db.collection('Account').doc(uid);
    final direct = await byId.get();
    if (direct.exists) return byId;

    final qs = await _db.collection('Account').where('uid', isEqualTo: uid).limit(1).get();
    if (qs.docs.isEmpty) throw StateError('Account doc for uid=$uid not found.');
    return qs.docs.first.reference;
  }

  Future<void> linkCaregiverToElderly({
    required String caregiverUid,
    required String elderlyUid,
  }) async {
    final cgRef = await _accountRefByUid(caregiverUid);
    await _db.runTransaction((tx) async {
      tx.set(
        cgRef,
        {
          'elderlyIds': FieldValue.arrayUnion([elderlyUid]),
          'elderlyId' : elderlyUid, // optional default/last-selected
        },
        SetOptions(merge: true),
      );
    });
  }

  Future<void> unlinkCaregiverFromElderly({
    required String caregiverUid,
    required String elderlyUid,
  }) async {
    final cgRef = await _accountRefByUid(caregiverUid);
    await cgRef.set({'elderlyIds': FieldValue.arrayRemove([elderlyUid])}, SetOptions(merge: true));
  }
}
