import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ElderlyAccessController {
  final _fs = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  // ───────────────── helpers ─────────────────

  /// Returns Account/{uid} ref. If it doesn’t exist but a legacy email-keyed
  /// doc does (e.g. `brock@hotmail_com`), copies it into Account/{uid}.
  Future<DocumentReference<Map<String, dynamic>>> _accountDocRefEither() async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('No signed-in user.');
    final uid = user.uid;
    final email = (user.email ?? '').trim().toLowerCase();
    final emailKey = email.replaceAll('.', '_');

    final uidRef = _fs.collection('Account').doc(uid);
    final uidSnap = await uidRef.get();
    if (uidSnap.exists) return uidRef;

    final legacyRef = _fs.collection('Account').doc(emailKey);
    final legacySnap = await legacyRef.get();

    if (legacySnap.exists) {
      final data = legacySnap.data()!;
      await uidRef.set({
        ...data,
        'uid': uid,
        'email': email,
        'migratedFrom': emailKey,
        'migratedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      // Optional: await legacyRef.delete();
      return uidRef;
    }

    await uidRef.set({
      'uid': uid,
      'email': email,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    return uidRef;
  }

  Future<String?> _findUidByEmail(String email) async {
    if (email.isEmpty) return null;
    final emailKey = email.toLowerCase().trim().replaceAll('.', '_');
    // 1) exact legacy doc?
    final legacy = await _fs.collection('Account').doc(emailKey).get();
    if (legacy.exists) {
      final uid = (legacy.data()?['uid'] ?? '').toString();
      if (uid.isNotEmpty) return uid;
      // If legacy has no uid, we’ll link by this docId (will be migrated on first use)
      return emailKey;
    }
    // 2) otherwise query by email field (for UID docs)
    final q = await _fs
        .collection('Account')
        .where('email', isEqualTo: email.toLowerCase().trim())
        .limit(1)
        .get();
    if (q.docs.isNotEmpty) return q.docs.first.id;
    return null;
  }

  // ──────────────── public API ────────────────

  /// Stream the caregiver’s linked elderly. Each item is a simple map:
  /// { 'id': elderlyUid, 'elderlyName': ..., 'elderlyEmail': ..., 'elderlyPhone': ..., 'access': {...} }
  Stream<List<Map<String, dynamic>>> linkedElderlyStream() async* {
    final caregiverRef = await _accountDocRefEither();

    // Listen to caregiver doc changes (to pick up elderlyIds / access changes)
    yield* caregiverRef.snapshots().asyncMap((snap) async {
      final cg = snap.data() ?? {};
      // canonical list
      final ids = <String>{
        ...(cg['elderlyIds'] is List
            ? List.from(cg['elderlyIds']).map((e) => e.toString().trim())
            : const <String>[]),
      }.where((e) => e.isNotEmpty).toList();

      if (ids.isEmpty) return <Map<String, dynamic>>[];

      // Access map can be keyed by elderlyId: { "<elderUid>": { ...switches... } }
      final Map<String, dynamic> accessMap =
          (cg['accessByElder'] is Map<String, dynamic>) ? Map<String, dynamic>.from(cg['accessByElder']) : {};

      // Firestore limits whereIn to 10 — chunk queries
      final chunks = <List<String>>[];
      for (var i = 0; i < ids.length; i += 10) {
        chunks.add(ids.sublist(i, i + 10 > ids.length ? ids.length : i + 10));
      }

      final results = <Map<String, dynamic>>[];
      for (final chunk in chunks) {
        final qs = await _fs
            .collection('Account')
            .where(FieldPath.documentId, whereIn: chunk)
            .get();
        for (final d in qs.docs) {
          final m = d.data();
          final safe = (m['safeDisplayName'] ?? m['displayName'])?.toString().trim();
          final first = (m['firstName'] ?? m['firstname'])?.toString().trim() ?? '';
          final last  = (m['lastName']  ?? m['lastname']) ?.toString().trim() ?? '';
          final name = (safe != null && safe.isNotEmpty)
              ? safe
              : [first, last].where((x) => x.isNotEmpty).join(' ').trim();

          results.add({
            'id': d.id,
            'elderlyName': name.isEmpty ? 'Elder' : name,
            'elderlyEmail': (m['email'] ?? '').toString(),
            'elderlyPhone': (m['phoneNum'] ?? m['elderPhone'] ?? '').toString(),
            'access': Map<String, dynamic>.from(accessMap[d.id] ?? {}),
          });
        }
      }
      return results;
    });
  }

  /// Link by explicit elderlyId (preferred) or by elderlyEmail (we’ll find/migrate UID).
  Future<void> linkElderly({String? elderlyId, String? elderlyEmail}) async {
    if ((elderlyId == null || elderlyId.isEmpty) &&
        (elderlyEmail == null || elderlyEmail.isEmpty)) {
      throw ArgumentError('Provide elderlyId or elderlyEmail');
    }
    final caregiverRef = await _accountDocRefEither();
    final caregiverUid = caregiverRef.id;

    final targetUid = elderlyId ?? (await _findUidByEmail(elderlyEmail!.trim()));
    if (targetUid == null) {
      throw StateError('No user found for email ${elderlyEmail!}');
    }

    final elderRef = _fs.collection('Account').doc(targetUid);

    final batch = _fs.batch();
    // caregiver side (canonical)
    batch.set(
      caregiverRef,
      {
        'elderlyIds': FieldValue.arrayUnion([targetUid]),
        'elderlyId': targetUid, // optional default/last-picked
      },
      SetOptions(merge: true),
    );
    // elder side: reverse index (optional but useful)
    batch.set(
      elderRef,
      {
        'linkedCaregiversUids': FieldValue.arrayUnion([caregiverUid]),
      },
      SetOptions(merge: true),
    );
    await batch.commit();
  }

  Future<void> updateAccess(String elderlyId, Map<String, dynamic> access) async {
    final caregiverRef = await _accountDocRefEither();
    await caregiverRef.set({
      'accessByElder': {elderlyId: access},
    }, SetOptions(merge: true));
  }

  Future<void> removeLink(String elderlyId) async {
    final caregiverRef = await _accountDocRefEither();
    final caregiverUid = caregiverRef.id;
    final elderRef = _fs.collection('Account').doc(elderlyId);

    final batch = _fs.batch();
    batch.set(caregiverRef, {
      'elderlyIds': FieldValue.arrayRemove([elderlyId]),
      'accessByElder': {elderlyId: FieldValue.delete()},
      // if your UI uses elderlyId as default, clear when removing
      'elderlyId': FieldValue.delete(),
    }, SetOptions(merge: true));
    batch.set(elderRef, {
      'linkedCaregiversUids': FieldValue.arrayRemove([caregiverUid]),
    }, SetOptions(merge: true));
    await batch.commit();
  }

  /// Pulls fresh display fields from Account/{elderlyId} into the caregiver’s access map (optional).
  Future<void> refreshLinkedElderlyInfo(String elderlyId) async {
    final elder = await _fs.collection('Account').doc(elderlyId).get();
    if (!elder.exists) return;
    final m = elder.data() ?? {};
    final name = (m['safeDisplayName'] ??
        [m['firstName'] ?? m['firstname'], m['lastName'] ?? m['lastname']]
            .where((x) => (x?.toString().trim().isNotEmpty ?? false))
            .join(' ')
            .trim());
    final email = (m['email'] ?? '').toString();
    final phone = (m['phoneNum'] ?? m['elderPhone'] ?? '').toString();

    final caregiverRef = await _accountDocRefEither();
    await caregiverRef.set({
      'displayCacheByElder': {
        elderlyId: {
          'name': name,
          'email': email,
          'phone': phone,
          'updatedAt': FieldValue.serverTimestamp(),
        }
      }
    }, SetOptions(merge: true));
  }
}
