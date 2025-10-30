import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

class ProfileController {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // -------------------- helpers --------------------

  String? _currentEmailLower() {
    final email = _auth.currentUser?.email;
    return email?.trim().toLowerCase();
  }

  /// Your Account docs are keyed like `user@domain_tld` (dots in domain -> `_`)
  String _accountDocIdFor(String lowerEmail) {
    final at = lowerEmail.indexOf('@');
    if (at < 0) return lowerEmail; // fallback
    final local = lowerEmail.substring(0, at);
    final domain = lowerEmail.substring(at + 1).replaceAll('.', '_');
    return '$local@$domain';
  }

  Future<DocumentReference<Map<String, dynamic>>> _accountDocRef() async {
    final emailLower = _currentEmailLower();
    if (emailLower == null) {
      throw StateError('No signed-in user.');
    }
    final docId = _accountDocIdFor(emailLower);
    return _db.collection('Account').doc(docId);
  }

  // Firestore whereIn supports up to 10 items
  List<List<T>> _chunk<T>(List<T> list, int size) {
    final chunks = <List<T>>[];
    for (var i = 0; i < list.length; i += size) {
      chunks.add(list.sublist(i, i + size > list.length ? list.length : i + size));
    }
    return chunks;
  }

  // -------------------- public API --------------------

  /// One-shot fetch of the signed-in user's Account doc.
  Future<Map<String, dynamic>?> fetchProfile() async {
    final ref = await _accountDocRef();
    final snap = await ref.get();
    if (!snap.exists) return null;

    final data = snap.data();
    // Ensure uid present even if doc is email-keyed
    if (data != null && data['uid'] == null && _auth.currentUser?.uid != null) {
      data['uid'] = _auth.currentUser!.uid;
    }
    return data;
  }

  /// Optional: live updates if you want the page to auto-refresh.
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

  /// Partial update. Null values delete the field.
  Future<void> updateProfile(Map<String, dynamic> update) async {
    final ref = await _accountDocRef();

    final clean = <String, dynamic>{};
    update.forEach((k, v) {
      if (v == null) {
        clean[k] = FieldValue.delete();
      } else {
        clean[k] = v;
      }
    });

    await ref.set(clean, SetOptions(merge: true));
  }

  /// Upload profile picture to Storage and return the download URL.
  /// Path: profilePictures/{uid}.jpg
  Future<String> uploadProfilePicture(File file) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw StateError('No signed-in user.');

    final ref = _storage.ref().child('profilePictures/$uid.jpg');
    await ref.putFile(file, SettableMetadata(contentType: 'image/jpeg'));
    return await ref.getDownloadURL();
  }

  /// Fetch elderly profiles by **UIDs only**.
  /// - Filters to userType == 'elderly'
  /// - Chunks whereIn queries (≤10)
  /// - Preserves input order
  Future<List<Map<String, dynamic>>> fetchElderlyProfilesByIds(
    List<String> uids,
  ) async {
    // sanitize & dedupe while keeping order
    final seen = <String>{};
    final ordered = <String>[];
    for (final raw in uids) {
      final id = raw.trim();
      if (id.isEmpty) continue;
      if (seen.add(id)) ordered.add(id);
    }
    if (ordered.isEmpty) return const [];

    final futures = _chunk(ordered, 10).map((chunk) {
      return _db
          .collection('Account')
          .where('uid', whereIn: chunk)
          .get();
    }).toList();

    final snaps = await Future.wait(futures);

    final byUid = <String, Map<String, dynamic>>{};
    for (final qs in snaps) {
      for (final doc in qs.docs) {
        final data = doc.data();
        if ((data['userType'] as String?)?.toLowerCase() == 'elderly') {
          final uid = (data['uid'] ?? '').toString();
          if (uid.isNotEmpty) {
            byUid[uid] = data
              ..putIfAbsent('uid', () => uid)
              ..putIfAbsent('_docId', () => doc.id); // optional for debugging
          }
        }
      }
    }

    // Preserve input order
    final result = <Map<String, dynamic>>[];
    for (final id in ordered) {
      final m = byUid[id];
      if (m != null) result.add(m);
    }
    return result;
  }
}
