// lib/data/data_repository.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';

/// RTDB paths (UID-based)
class RtdbPaths {
  static String userByUid(String uid) => 'usersByUid/$uid';
  static String caregiverLinksForElder(String elderUid) => 'caregiverLinks/$elderUid'; // children: {caregiverUid:true}
}

class DataRepository {
  final FirebaseFirestore _fs;
  final DatabaseReference _rdb;

  DataRepository({
    FirebaseFirestore? firestore,
    DatabaseReference? rtdbRoot,
  })  : _fs = firestore ?? FirebaseFirestore.instance,
        _rdb = rtdbRoot ?? FirebaseDatabase.instance.ref();

  // -------------------- Firestore (source of truth) --------------------

  /// FS: users/{uid} (one-shot)
  Future<Map<String, dynamic>?> getUserFs(String uid) async {
    final snap = await _fs.collection('users').doc(uid).get();
    return snap.data();
  }

  /// FS: users/{uid} (live)
  Stream<Map<String, dynamic>?> watchUserFs(String uid) {
    return _fs.collection('users').doc(uid).snapshots().map((d) => d.data());
  }

  /// FS: update users/{uid} with merge
  Future<void> updateUserFs(String uid, Map<String, dynamic> patch) {
    return _fs.collection('users').doc(uid).set(patch, SetOptions(merge: true));
  }

  // -------------------- Realtime Database (UID-based mirror) --------------------

  /// RTDB: /usersByUid/{uid} (one-shot)
  Future<Map<String, dynamic>?> getUserRtdb(String uid) async {
    final snap = await _rdb.child(RtdbPaths.userByUid(uid)).get();
    final val = snap.value;
    if (val is Map) {
      return Map<String, dynamic>.from(val);
    }
    return null;
    // NOTE: If you still store users under /users/<emailKey>, change path accordingly.
  }

  /// RTDB: /usersByUid/{uid} (live)
  Stream<Map<String, dynamic>?> watchUserRtdb(String uid) {
    return _rdb.child(RtdbPaths.userByUid(uid)).onValue.map((e) {
      final val = e.snapshot.value;
      return (val is Map) ? Map<String, dynamic>.from(val) : null;
    });
  }

  /// Optional: RTDB write (only if your client needs to write RTDB directly)
  Future<void> updateUserRtdb(String uid, Map<String, dynamic> patch) async {
    await _rdb.child(RtdbPaths.userByUid(uid)).update(patch);
  }

  // -------------------- Caregiver ↔ Elder index (in RTDB) --------------------

  /// Get list of caregiver UIDs linked to an elder (from /caregiverLinks/{elderUid})
  Future<List<String>> getCaregiversForElder(String elderUid) async {
    final snap = await _rdb.child(RtdbPaths.caregiverLinksForElder(elderUid)).get();
    if (!snap.exists || snap.value == null) return const [];
    final obj = Map<String, dynamic>.from(snap.value as Map);
    return obj.keys.toList(); // caregiver UIDs
  }

  /// Watch caregivers linked to an elder
  Stream<List<String>> watchCaregiversForElder(String elderUid) {
    return _rdb.child(RtdbPaths.caregiverLinksForElder(elderUid)).onValue.map((e) {
      if (!e.snapshot.exists || e.snapshot.value == null) return <String>[];
      final obj = Map<String, dynamic>.from(e.snapshot.value as Map);
      return obj.keys.toList();
    });
  }

  // -------------------- Convenience: unified getters --------------------

  /// Prefer Firestore; fall back to RTDB if FS doc missing.
  Future<Map<String, dynamic>?> getUser(String uid) async {
    final fs = await getUserFs(uid);
    if (fs != null) return fs;
    return getUserRtdb(uid);
  }

  /// Combine FS + RTDB streams (FS priority). If FS is null, emit RTDB.
  Stream<Map<String, dynamic>?> watchUser(String uid) {
    // Simple approach: just use Firestore. If you truly need fallback,
    // you can merge streams with Rx or do a manual combinator.
    return watchUserFs(uid);
  }
}
