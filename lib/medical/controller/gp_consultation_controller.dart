import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rxdart/rxdart.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../models/user_profile.dart';
import '../modelling/gp_appointment.dart';

/// Firestore field/collection keys
class _FS {
  // Collections
  static const account = 'Account';
  static const caregiversSub = 'caregivers';
  static const gpSlots = 'gp_slots';
  static const appointments = 'appointments';

  // Common fields
  static const uid = 'uid';
  static const userType = 'userType';
  static const elderlyUid = 'elderlyUid';
  static const createdAt = 'createdAt';
  static const status = 'status';

  // Consultation fields
  static const createdBy = 'createdBy';
  static const caregiverUid = 'caregiverUid';
  static const startedAt = 'startedAt';
  static const endedAt = 'endedAt';
  static const reason = 'reason';
  static const notes = 'notes';
  static const channelId = 'channelId';
  static const participants = 'participants';

  // Account helpers
  static const primaryCaregiverId = 'primaryCaregiverId';
  static const linkedCaregiverUids = 'linkedCaregiverUids';
  static const elderlyIds = 'elderlyIds';           // on caregiver docs

  // GP slot fields
  static const available = 'available';
  static const start = 'start';
  static const end = 'end';
  static const doctorName = 'doctorName';
  static const clinic = 'clinic';
}

class ElderlyGPController {
  final String elderlyId; // REAL Firebase UID of the elderly
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  ElderlyGPController({required this.elderlyId})
      : assert(elderlyId.isNotEmpty, 'elderlyId must not be empty'),
        _db = FirebaseFirestore.instance,
        _auth = FirebaseAuth.instance;

  // ───────────────────────────────────────────────────────────────────────────
  // Auth helper
  Future<User> _requireSignedIn() async {
    final u = _auth.currentUser;
    if (u == null) {
      throw StateError('You must be signed in before starting a consultation.');
    }
    return u;
  }

  Future<void> ensureCaregiverLink(String caregiverUid) async {
    if (caregiverUid.trim().isEmpty) return;

    // locate caregiver Account doc by REAL uid
    final cgQ = await _db
        .collection(_FS.account)
        .where(_FS.uid, isEqualTo: caregiverUid)
        .limit(1)
        .get();
    if (cgQ.docs.isEmpty) {
      throw StateError('Caregiver account not found for uid=$caregiverUid');
    }
    final cgRef = cgQ.docs.first.reference;
    final cgData = cgQ.docs.first.data();
    if ((cgData[_FS.userType] ?? '') != 'caregiver') {
      throw StateError('Account for uid=$caregiverUid is not a caregiver.');
    }

    // locate elderly Account doc by REAL uid
    final elderQ = await _db
        .collection(_FS.account)
        .where(_FS.uid, isEqualTo: elderlyId)
        .limit(1)
        .get();
    if (elderQ.docs.isEmpty) {
      throw StateError('Elderly account not found for uid=$elderlyId');
    }
    final elderRef = elderQ.docs.first.reference;

    // write both directions atomically
    final batch = _db.batch();
    batch.set(
      cgRef,
      {
        _FS.elderlyIds: FieldValue.arrayUnion([elderlyId]),
      },
      SetOptions(merge: true),
    );
    batch.set(
      elderRef,
      {
        _FS.linkedCaregiverUids: FieldValue.arrayUnion([caregiverUid]),
      },
      SetOptions(merge: true),
    );
    await batch.commit();
  }

  /// Optional: unlink if you need it
  Future<void> unlinkCaregiver(String caregiverUid) async {
    if (caregiverUid.trim().isEmpty) return;

    final cgRef = _db.collection(_FS.account).doc(caregiverUid);
final cgSnap = await cgRef.get();
if (!cgSnap.exists) {
  throw StateError(' Caregiver account not found for uid=$caregiverUid');
}


    final elderQ = await _db
        .collection(_FS.account)
        .where(_FS.uid, isEqualTo: elderlyId)
        .limit(1)
        .get();
    if (elderQ.docs.isEmpty) return;
    final elderRef = elderQ.docs.first.reference;

    final batch = _db.batch();
    batch.set(
      cgRef,
      {_FS.elderlyIds: FieldValue.arrayRemove([elderlyId])},
      SetOptions(merge: true),
    );
    batch.set(
      elderRef,
      {_FS.linkedCaregiverUids: FieldValue.arrayRemove([caregiverUid])},
      SetOptions(merge: true),
    );
    await batch.commit();
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Consultations

  /// /Account/{elderlyAccountDoc}/consultations
  CollectionReference<Map<String, dynamic>> _consultsCol(String uid) =>
      _db.collection(_FS.account).doc(uid).collection('consultations');

  /// Start a consultation for this elderly.
  /// If [caregiverUid] is provided, we ensure the link exists first.
  Future<String> startConsultation({
    required String reason,
    String? caregiverUid,
    String? notes,
  }) async {
    final user = await _requireSignedIn();

    if (caregiverUid != null && caregiverUid.isNotEmpty) {
      await ensureCaregiverLink(caregiverUid);
    }

    final participants = <String>{
      user.uid,
      elderlyId,
      if (caregiverUid != null && caregiverUid.isNotEmpty) caregiverUid,
    }.toList();

    final nowServer = FieldValue.serverTimestamp();
    final includeCaregiver = caregiverUid != null && caregiverUid.isNotEmpty;

    // Find the elderly's Account doc (email-keyed or otherwise) by REAL uid
    final elderQ = await _db
        .collection(_FS.account)
        .where(_FS.uid, isEqualTo: elderlyId)
        .limit(1)
        .get();
    if (elderQ.docs.isEmpty) {
      throw StateError('Elderly Account doc not found for uid=$elderlyId');
    }
    final elderDocRef = elderQ.docs.first.reference;

    final docRef = await elderDocRef.collection('consultations').add({
      _FS.elderlyUid: elderlyId,
      _FS.createdBy: user.uid,
      _FS.caregiverUid: caregiverUid,
      _FS.participants: participants,

      // timing
      'requestedAt': nowServer,
      _FS.startedAt: nowServer,
      _FS.endedAt: null,

      // content
      'symptoms': reason,
      _FS.reason: reason,
      _FS.notes: notes,
      _FS.channelId: null,

      // status
      _FS.status: 'Pending GP Connection',
      'includeCaregiver': includeCaregiver,
      _FS.createdAt: nowServer,
    });

    return docRef.id;
  }

  Future<void> endConsultation(String consultationId) async {
    final elderQ = await _db
        .collection(_FS.account)
        .where(_FS.uid, isEqualTo: elderlyId)
        .limit(1)
        .get();
    if (elderQ.docs.isEmpty) return;
    final ref = elderQ.docs.first.reference.collection('consultations').doc(consultationId);

    await ref.update({
      _FS.status: 'ended',
      _FS.endedAt: FieldValue.serverTimestamp(),
    });
  }

  /// Latest in-progress consultation(s) for the elderly
  Stream<QuerySnapshot<Map<String, dynamic>>> activeConsultationsStream() {
    const inProgress = ['active', 'Pending GP Connection'];

    return _db
        .collection(_FS.account)
        .where(_FS.uid, isEqualTo: elderlyId)
        .limit(1)
        .snapshots()
        .switchMap((s) {
          if (s.docs.isEmpty) {
            return const Stream<QuerySnapshot<Map<String, dynamic>>>.empty();
          }
          final ref = s.docs.first.reference.collection('consultations');
          return ref
              .where(_FS.status, whereIn: inProgress)
              .orderBy(_FS.startedAt, descending: true)
              .limit(1)
              .snapshots();
        });
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Account lookups

  /// Stream the elderly Account as UserProfile (by REAL uid)
  Stream<UserProfile?> elderlyAccountStream() {
    return _db
        .collection(_FS.account)
        .where(_FS.uid, isEqualTo: elderlyId)
        .limit(1)
        .snapshots()
        .map((s) {
          if (s.docs.isEmpty) return null;
          final d = s.docs.first.data();
          return UserProfile.fromMap(d, (d[_FS.uid] ?? elderlyId).toString());
        });
  }

  /// Caregivers for this elderly (supports both directions)
  ///
  /// A) Reverse lookup (current schema): caregiver docs with `elderlyIds` containing elderlyId
  /// B) Forward lookup (optional): elder doc with `linkedCaregiverUids`, then fetch those caregiver docs by `uid`
  Stream<List<UserProfile>> caregiversForElderlyStream() {
    final caregiversBase =
        _db.collection(_FS.account).where(_FS.userType, isEqualTo: 'caregiver');

    // A) reverse lookup
    final byReverse$ =
        caregiversBase.where(_FS.elderlyIds, arrayContains: elderlyId).snapshots();

    // B) forward lookup
    final byForward$ = _db
    .collection(_FS.account)
    .where(_FS.uid, isEqualTo: elderlyId)
    .limit(1)
    .snapshots()
    .asyncExpand((s) {
      if (s.docs.isEmpty) {
        // ⬇️ put the generic on Stream<...>, and return the right empty value
        return Stream<List<QuerySnapshot<Map<String, dynamic>>>>.value(
          const <QuerySnapshot<Map<String, dynamic>>>[],
        );
      }

      final linked = List<String>.from(
        (s.docs.first.data()[_FS.linkedCaregiverUids] as List?) ?? const [],
      );
      if (linked.isEmpty) {
        return Stream<List<QuerySnapshot<Map<String, dynamic>>>>.value(
          const <QuerySnapshot<Map<String, dynamic>>>[],
        );
      }

      Iterable<List<String>> chunks(List<String> xs, int n) sync* {
        for (var i = 0; i < xs.length; i += n) {
          yield xs.sublist(i, (i + n > xs.length) ? xs.length : i + n);
        }
      }

      final base = _db.collection(_FS.account).where(_FS.userType, isEqualTo: 'caregiver');
      final streams = [
        for (final c in chunks(linked, 10))
          base.where(_FS.uid, whereIn: c).snapshots(),
      ];

      // Rx.combineLatestList returns Stream<List<QuerySnapshot<...>>>
      return Rx.combineLatestList(streams);
    });


    return Rx.combineLatest2<QuerySnapshot<Map<String, dynamic>>,
        List<QuerySnapshot<Map<String, dynamic>>>, List<UserProfile>>(
      byReverse$,
      byForward$,
      (rev, fwdList) {
        final rows = <Map<String, dynamic>>[];

        for (final d in rev.docs) rows.add(d.data());
        for (final qs in fwdList) {
          for (final d in qs.docs) rows.add(d.data());
        }

        // de-dup by REAL uid
        final byUid = <String, Map<String, dynamic>>{};
        for (final m in rows) {
          final id = (m[_FS.uid] ?? '').toString();
          if (id.isEmpty) continue;
          byUid[id] = m;
        }

        return byUid.values.map((m) {
          return UserProfile(
            uid: (m[_FS.uid] ?? '').toString(),
            email: m['email'] as String?,
            firstName: (m['firstname'] ?? m['firstName']) as String?,
            lastName: (m['lastname'] ?? m['lastName']) as String?,
            userType: 'caregiver',
          );
        }).toList(growable: false);
      },
    );
  }

  /// Primary caregiver from either:
  ///  A) Account/{elderly}.primaryCaregiverId → Account/{cgId}
  ///  B) Account/{elderly}/caregivers/primary (embedded)
  Stream<UserProfile?> getPrimaryCaregiverStream() {
    final elderDoc$ = _db
        .collection(_FS.account)
        .where(_FS.uid, isEqualTo: elderlyId)
        .limit(1)
        .snapshots();

    final a$ = elderDoc$.asyncExpand((s) {
      if (s.docs.isEmpty) return Stream<UserProfile?>.value(null);
      final snap = s.docs.first;
      final cgId = snap.data()[_FS.primaryCaregiverId] as String?;
      if (cgId == null || cgId.isEmpty) return Stream<UserProfile?>.value(null);
      return _db
          .collection(_FS.account)
          .where(_FS.uid, isEqualTo: cgId)
          .limit(1)
          .snapshots()
          .map((q) {
        if (q.docs.isEmpty) return null;
        final m = q.docs.first.data();
        return UserProfile.fromMap(m, (m[_FS.uid] ?? cgId).toString());
      });
    });

    final b$ = elderDoc$.asyncExpand((s) {
      if (s.docs.isEmpty) return Stream<UserProfile?>.value(null);
      final ref = s.docs.first.reference;
      return ref.collection(_FS.caregiversSub).doc('primary').snapshots().map((doc) {
        if (!doc.exists) return null;
        final data = doc.data()!;
        return UserProfile(
          uid: (data['uid'] ?? doc.id).toString(),
          email: data['email'] as String?,
          firstName: data['firstName'] as String?,
          lastName: data['lastName'] as String?,
          userType: 'caregiver',
          elderlyId: elderlyId,
        );
      });
    });

    return Rx.combineLatest2<UserProfile?, UserProfile?, UserProfile?>(a$, b$, (a, b) => a ?? b);
  }

  // ───────────────────────────────────────────────────────────────────────────
  // GP slots & booking

  Stream<List<GPAppointment>> getUpcomingSlots() {
    final now = DateTime.now();
    return _db
        .collection(_FS.gpSlots)
        .where(_FS.available, isEqualTo: true)
        .where(_FS.start, isGreaterThanOrEqualTo: Timestamp.fromDate(now))
        .orderBy(_FS.start)
        .limit(20)
        .snapshots()
        .map((snap) => snap.docs.map((d) {
              final data = d.data();
              final tsStart = data[_FS.start] as Timestamp;
              final tsEnd = data[_FS.end] as Timestamp;
              return GPAppointment(
                start: tsStart.toDate(),
                end: tsEnd.toDate(),
                doctorName: (data[_FS.doctorName] ?? 'Doctor') as String,
                clinic: (data[_FS.clinic] ?? 'Clinic') as String,
              );
            }).toList(growable: false));
  }

  Future<void> bookAppointment(GPAppointment appt) async {
    final q = await _db
        .collection(_FS.gpSlots)
        .where(_FS.start, isEqualTo: Timestamp.fromDate(appt.start))
        .where(_FS.end, isEqualTo: Timestamp.fromDate(appt.end))
        .where(_FS.doctorName, isEqualTo: appt.doctorName)
        .where(_FS.clinic, isEqualTo: appt.clinic)
        .limit(1)
        .get();

    if (q.docs.isEmpty) throw StateError('Slot not found or already taken.');
    final slotRef = q.docs.first.reference;

    await _db.runTransaction((tx) async {
      final slotSnap = await tx.get(slotRef);
      if (!slotSnap.exists) throw StateError('Slot removed.');
      final available = slotSnap.data()?[_FS.available] == true;
      if (!available) throw StateError('Slot already booked.');

      tx.update(slotRef, {_FS.available: false});

      final apptRef = _db.collection(_FS.appointments).doc();
      tx.set(apptRef, {
        _FS.elderlyUid: elderlyId,
        _FS.start: Timestamp.fromDate(appt.start),
        _FS.end: Timestamp.fromDate(appt.end),
        _FS.doctorName: appt.doctorName,
        _FS.clinic: appt.clinic,
        _FS.status: 'booked',
        _FS.createdAt: FieldValue.serverTimestamp(),
      });
    });
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Debug helpers

  /// One-off probe to verify reverse lookup works under your rules.
  Future<List<String>> debugCaregiverIdsForElderly() async {
    final result = await _db
        .collection(_FS.account)
        .where(_FS.userType, isEqualTo: 'caregiver')
        .where(_FS.elderlyIds, arrayContains: elderlyId)
        .get();

    return result.docs
        .map((d) => (d.data()[_FS.uid] ?? '').toString())
        .where((s) => s.isNotEmpty)
        .toList(growable: false);
  }
}
