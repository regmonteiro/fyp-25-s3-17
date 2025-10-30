// gp_profile_controller.dart
import 'dart:io' show File;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

class CgProfileController {
  final FirebaseAuth _auth;
  final FirebaseFirestore _db;
  final FirebaseStorage _storage;

  CgProfileController({
    FirebaseAuth? auth,
    FirebaseFirestore? db,
    FirebaseStorage? storage,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _db = db ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance;

  // ───────────────────────── helpers ─────────────────────────

  String? _currentEmailLower() => _auth.currentUser?.email?.trim().toLowerCase();

  /// Build legacy email-keyed doc id: local@domain_tld (dots -> underscores)
  String _legacyAccountDocIdFor(String lowerEmail) {
    final at = lowerEmail.indexOf('@');
    if (at < 0) return lowerEmail; // fallback
    final local = lowerEmail.substring(0, at);
    final domain = lowerEmail.substring(at + 1).replaceAll('.', '_');
    return '$local@$domain';
  }

  /// Always return a reference to Account/{uid}, migrating any legacy email-keyed doc if present.
  Future<DocumentReference<Map<String, dynamic>>> _accountDocRef() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('No signed-in user.');
    }

    final uidDoc = _db.collection('Account').doc(user.uid);
    final uidSnap = await uidDoc.get();
    if (uidSnap.exists) return uidDoc;

    // Legacy migration: try to find email-keyed doc (e.g. "himay@gmail_com")
    final lower = _currentEmailLower();
    if (lower == null) return uidDoc;
    final legacyId = _legacyAccountDocIdFor(lower);
    if (legacyId == user.uid) return uidDoc;

    final legacyDoc = _db.collection('Account').doc(legacyId);
    final legacySnap = await legacyDoc.get();
    if (!legacySnap.exists) return uidDoc;

    // Migrate data into Account/{uid}
    final data = legacySnap.data()!;
    data['uid'] = user.uid;
    data['email'] ??= user.email ?? '';
    await uidDoc.set(data, SetOptions(merge: true));
    await legacyDoc.delete();

    return uidDoc;
  }

  // Firestore whereIn supports up to 10 items
  List<List<T>> _chunk<T>(List<T> xs, int size) {
    final out = <List<T>>[];
    for (var i = 0; i < xs.length; i += size) {
      out.add(xs.sublist(i, i + size > xs.length ? xs.length : i + size));
    }
    return out;
  }

  // ───────────────────────── public API ─────────────────────────

  /// One-shot fetch of the signed-in GP's Account document (returns null if not found).
  Future<Map<String, dynamic>?> fetchProfile() async {
    final ref = await _accountDocRef();
    final snap = await ref.get();
    if (!snap.exists) return null;

    final data = snap.data();
    if (data != null && data['uid'] == null && _auth.currentUser?.uid != null) {
      data['uid'] = _auth.currentUser!.uid;
    }
    return data;
  }

  /// Live stream of the GP's Account document.
  Stream<Map<String, dynamic>?> watchProfile() async* {
    final ref = await _accountDocRef();
    yield* ref.snapshots().map((s) {
      final data = s.data();
      if (data == null) return null;
      if (data['uid'] == null && _auth.currentUser?.uid != null) {
        data['uid'] = _auth.currentUser!.uid;
      }
      return data;
    });
  }

  /// Partial update. Any null value is interpreted as a field delete.
  Future<void> updateProfile(Map<String, dynamic> update) async {
    final ref = await _accountDocRef();

    final clean = <String, dynamic>{};
    update.forEach((k, v) {
      clean[k] = (v == null) ? FieldValue.delete() : v;
    });

    await ref.set(clean, SetOptions(merge: true));
  }

  /// Uploads a profile picture and returns its download URL.
  /// Storage path: profilePictures/{uid}.jpg
  /// (Make sure your Storage rules allow the owner to write this path.)
  Future<String> uploadProfilePicture(File file) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw StateError('No signed-in user.');

    final ref = _storage.ref().child('profilePictures/$uid.jpg');
    final task = await ref.putFile(file, SettableMetadata(contentType: 'image/jpeg'));
    return task.ref.getDownloadURL();
  }

  /// Fetch elderly profiles by **UIDs**, filtered to `userType == 'elderly'`.
  /// - Preserves input order
  /// - whereIn chunked (≤10)
  Future<List<Map<String, dynamic>>> fetchElderlyProfilesByIds(List<String> ids) async {
  // sanitize & preserve order
  final seen = <String>{};
  final ordered = <String>[];
  for (final raw in ids) {
    final id = raw.trim();
    if (id.isNotEmpty && seen.add(id)) ordered.add(id);
  }
  if (ordered.isEmpty) return const [];

  // Fetch by doc id directly (chunked for concurrency)
  final chunks = _chunk(ordered, 10);
  final futures = <Future<List<DocumentSnapshot<Map<String, dynamic>>>>>[];

  for (final chunk in chunks) {
    futures.add(Future.wait(
      chunk.map((id) => _db.collection('Account').doc(id).get()),
    ));
  }

  final snapsBatches = await Future.wait(futures);
  final byId = <String, Map<String, dynamic>>{};

  for (final batch in snapsBatches) {
    for (final snap in batch) {
      if (!snap.exists) continue;
      final data = snap.data()!;
      final id = snap.id;
      byId[id] = {
        ...data,
        'uid': data['uid'] ?? id, // convenience for UI
        '_docId': id,
      };
    }
  }

  // Rebuild result preserving input order
  final result = <Map<String, dynamic>>[];
  for (final id in ordered) {
    final m = byId[id];
    if (m != null) result.add(m);
  }
  return result;
}

}
