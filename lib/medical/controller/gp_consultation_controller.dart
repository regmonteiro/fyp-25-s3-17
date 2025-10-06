import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rxdart/rxdart.dart'; // ← for Rx.combineLatest2
import '../../models/user_profile.dart';
import '../modelling/gp_appointment.dart';

class _FS {
  static const users = 'users';
  static const caregiversSub = 'caregivers';
  static const gpSlots = 'gp_slots';
  static const appointments = 'appointments';

  static const primaryCaregiverId = 'primaryCaregiverId';

  static const available = 'available';
  static const start = 'start';
  static const end = 'end';
  static const doctorName = 'doctorName';
  static const clinic = 'clinic';

  static const elderlyUid = 'elderlyUid';
  static const createdAt = 'createdAt';
  static const status = 'status';
}

class ElderlyGPController {
  final String elderlyUid;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  ElderlyGPController({required this.elderlyUid});

  /// Start a live consultation record (caregiverUid optional)
  Future<String> startConsultation({
    String? caregiverUid,
    String? reason,
    String? notes,
  }) async {
    final doc = await _db.collection('consultations').add({
      'elderlyUid': elderlyUid,
      'caregiverUid': caregiverUid, // may be null
      'status': 'active',
      'startedAt': FieldValue.serverTimestamp(),
      'endedAt': null,
      'reason': reason,
      'notes': notes,
      'channelId': null,
    });
    return doc.id;
  }

  Future<void> endConsultation(String consultationId) async {
    await _db.collection('consultations').doc(consultationId).update({
      'status': 'ended',
      'endedAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> activeConsultationsStream() {
    return _db
        .collection('consultations')
        .where('elderlyUid', isEqualTo: elderlyUid)
        .where('status', isEqualTo: 'active')
        .orderBy('startedAt', descending: true)
        .limit(1)
        .snapshots();
  }

  /// PRIMARY CAREGIVER as UserProfile
  /// A) users/{elderly}.primaryCaregiverId → users/{cgId}
  /// B) users/{elderly}/caregivers/primary (expects fields like firstName/lastName/email)
  Stream<UserProfile?> getPrimaryCaregiverStream() {
    final userDoc = _db.collection(_FS.users).doc(elderlyUid);

    // A) pointer field on user
    final a$ = userDoc.snapshots().asyncExpand((userSnap) {
      if (!userSnap.exists) return Stream<UserProfile?>.value(null);
      final cgId = userSnap.data()?[_FS.primaryCaregiverId] as String?;
      if (cgId == null || cgId.isEmpty) return Stream<UserProfile?>.value(null);
      return _db.collection(_FS.users).doc(cgId).snapshots().map((cgSnap) {
        if (!cgSnap.exists) return null;
        return UserProfile.fromMap(cgSnap.data()!, cgSnap.id);
      });
    });

    // B) embedded sub-doc
    final b$ = userDoc.collection(_FS.caregiversSub).doc('primary').snapshots().map((doc) {
      if (!doc.exists) return null;
      final data = doc.data()!;
      // Build a lightweight UserProfile
      return UserProfile(
        uid: (data['uid'] ?? doc.id).toString(),
        email: data['email'] as String?,
        firstName: data['firstName'] as String?,
        lastName: data['lastName'] as String?,
        role: 'caregiver',
        uidOfElder: elderlyUid,
      );
    });

    // Prefer A, else B
    return Rx.combineLatest2<UserProfile?, UserProfile?, UserProfile?>(
      a$,
      b$,
      (a, b) => a ?? b,
    );
  }

  // ----- slots & booking (unchanged) -----
  Stream<List<GPAppointment>> getUpcomingSlots() {
    final now = DateTime.now();
    return _db
        .collection(_FS.gpSlots)
        .where(_FS.available, isEqualTo: true)
        .where(_FS.start, isGreaterThanOrEqualTo: now)
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
