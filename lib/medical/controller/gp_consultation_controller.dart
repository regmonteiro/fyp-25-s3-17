import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rxdart/rxdart.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../models/user_profile.dart';
import '../modelling/gp_appointment.dart';

class _FS {
  // Collections
  static const users = 'users';
  static const caregiversSub = 'caregivers';
  static const gpSlots = 'gp_slots';
  static const appointments = 'appointments';

  // Common fields
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

  // Users helpers
  static const primaryCaregiverId = 'primaryCaregiverId';

  // GP slot fields
  static const available = 'available';
  static const start = 'start';
  static const end = 'end';
  static const doctorName = 'doctorName';
  static const clinic = 'clinic';
}

class ElderlyGPController {
  final String elderlyUid;
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  ElderlyGPController({required this.elderlyUid})
      : assert(elderlyUid != '', 'elderlyUid must not be empty'),
        _db = FirebaseFirestore.instance,
        _auth = FirebaseAuth.instance;

  Future<User> _requireSignedIn() async {
    final u = _auth.currentUser;
    if (u == null) {
      throw StateError('You must be signed in before starting a consultation.');
    }
    return u;
  }

  CollectionReference<Map<String, dynamic>> _consultsCol(String uid) =>
      _db.collection(_FS.users).doc(uid).collection('consultations');

  /// Create users/{elderlyUid}/consultations/{cid}
  Future<String> startConsultation({
    required String reason,
    String? caregiverUid,
    String? notes,
  }) async {
    final user = await _requireSignedIn();

    final participants = <String>{
      user.uid,
      elderlyUid,
      if (caregiverUid != null && caregiverUid.isNotEmpty) caregiverUid,
    }.toList();

    final nowServer = FieldValue.serverTimestamp();
    final includeCaregiver = caregiverUid != null && caregiverUid.isNotEmpty;

    final docRef = await _consultsCol(elderlyUid).add({
      // identity for queries/rules
      _FS.elderlyUid: elderlyUid,

      // attribution
      _FS.createdBy: user.uid,
      _FS.caregiverUid: caregiverUid,
      _FS.participants: participants,

      // timing
      'requestedAt': nowServer, // history UI uses this
      _FS.startedAt: nowServer,
      _FS.endedAt: null,

      // content
      'symptoms': reason, // history UI reads 'symptoms'
      _FS.reason: reason,
      _FS.notes: notes,
      _FS.channelId: null,

      // status flags
      _FS.status: 'Pending GP Connection',
      'includeCaregiver': includeCaregiver,
    });

    return docRef.id;
  }

  Future<void> endConsultation(String consultationId) async {
    await _consultsCol(elderlyUid).doc(consultationId).update({
      _FS.status: 'ended',
      _FS.endedAt: FieldValue.serverTimestamp(),
    });
  }

  /// Latest in-progress consultation for the elderly
  Stream<QuerySnapshot<Map<String, dynamic>>> activeConsultationsStream() {
    // whereIn cannot be empty; keep a small set of “in progress” labels you use
    const inProgress = ['active', 'Pending GP Connection'];
    return _consultsCol(elderlyUid)
        .where(_FS.status, whereIn: inProgress)
        .orderBy(_FS.startedAt, descending: true)
        .limit(1)
        .snapshots();
  }

  /// Primary caregiver from either:
  ///  A) users/{elderly}.primaryCaregiverId → users/{cgId}
  ///  B) users/{elderly}/caregivers/primary (embedded)
  Stream<UserProfile?> getPrimaryCaregiverStream() {
    final userDoc = _db.collection(_FS.users).doc(elderlyUid);

    final a$ = userDoc.snapshots().asyncExpand((snap) {
      if (!snap.exists) return Stream.value(null);
      final cgId = snap.data()?[_FS.primaryCaregiverId] as String?;
      if (cgId == null || cgId.isEmpty) return Stream.value(null);
      return _db.collection(_FS.users).doc(cgId).snapshots().map((cgSnap) {
        if (!cgSnap.exists) return null;
        return UserProfile.fromMap(cgSnap.data()!, cgSnap.id);
      });
    });

    final b$ = userDoc
        .collection(_FS.caregiversSub)
        .doc('primary')
        .snapshots()
        .map((doc) {
      if (!doc.exists) return null;
      final data = doc.data()!;
      return UserProfile(
        uid: (data['uid'] ?? doc.id).toString(),
        email: data['email'] as String?,
        firstName: data['firstName'] as String?,
        lastName: data['lastName'] as String?,
        role: 'caregiver',
        uidOfElder: elderlyUid,
      );
    });

    return Rx.combineLatest2<UserProfile?, UserProfile?, UserProfile?>(
      a$, b$, (a, b) => a ?? b,
    );
  }

  // ── GP slots & booking ────────────────────────────────────────────────────

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
            }).toList());
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
        _FS.elderlyUid: elderlyUid,
        _FS.start: Timestamp.fromDate(appt.start),
        _FS.end: Timestamp.fromDate(appt.end),
        _FS.doctorName: appt.doctorName,
        _FS.clinic: appt.clinic,
        _FS.status: 'booked',
        _FS.createdAt: FieldValue.serverTimestamp(),
      });
    });
  }
}
