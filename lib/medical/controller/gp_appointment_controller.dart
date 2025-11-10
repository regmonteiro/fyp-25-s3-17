import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class BookingResult {
  final bool ok;
  final String message;
  BookingResult(this.ok, this.message);
}

class _FS {
  static const String account = 'Account';
  static const String events = 'events';
  static const String config = 'config';

  // added for caregiver + reminders + notifications
  static const String accountByUid = 'AccountByUid';
  static const String notifications = 'notifications';
  static const String reminders = 'reminders';

  static const String userType = 'userType';      // 'elderly' | 'caregiver' | 'admin'
  static const String elderlyIds = 'elderlyIds';  // array on caregiver docs
}

Uri _joinCallDeepLink({
  required String eventId,
  required String elderlyId,
}) {
  // Example scheme: allcare://videoCall?eventId=...&elderlyId=...
  return Uri(
    scheme: 'allcare',
    host: 'videoCall',
    queryParameters: {
      'eventId': eventId,
      'elderlyId': elderlyId,
    },
  );
}

extension _DocData on DocumentSnapshot<Map<String, dynamic>> {
  Map<String, dynamic> get safe => data() ?? const <String, dynamic>{};
}

extension _MapX on Map<String, dynamic> {
  String s(String k) => (this[k] ?? '').toString();
  List<String> sList(String k) =>
      (this[k] is List) ? List.from(this[k]).map((e) => e.toString()).toList() : const <String>[];
}

class GpAppointmentController {
  final FirebaseFirestore _db;
  final bool mirrorToCaregivers;

  GpAppointmentController({
    FirebaseFirestore? db,
    this.mirrorToCaregivers = true,
  }) : _db = db ?? FirebaseFirestore.instance;

  // ───────────────────────── Account helpers (uid-first) ─────────────────────────

  Future<DocumentReference<Map<String, dynamic>>> _accountDocRefByUid(String uid) async {
    final uidRef = _db.collection(_FS.account).doc(uid);
    final uidSnap = await uidRef.get();
    if (uidSnap.exists) return uidRef;

    final q = await _db.collection(_FS.account).where('uid', isEqualTo: uid).limit(1).get();
    if (q.docs.isNotEmpty) return q.docs.first.reference;

    return uidRef; // fallback (caller may create later)
  }

  Future<(DocumentReference<Map<String, dynamic>>, Map<String, dynamic>)>
      _accountDocAndDataByUid(String uid) async {
    final ref = await _accountDocRefByUid(uid);
    final snap = await ref.get();
    return (ref, snap.data() ?? <String, dynamic>{});
  }

  // ───────────────────────── Caregiver linkage / userType ─────────────────────────

  Future<String?> userTypeOf(String uid) async {
    final (ref, data) = await _accountDocAndDataByUid(uid);
    final t = (data[_FS.userType] ?? '').toString().trim();
    return t.isEmpty ? null : t;
  }

  Future<List<String>> fetchEldersForCaregiver(String caregiverUid) async {
    final (ref, data) = await _accountDocAndDataByUid(caregiverUid);
    final list = data.sList(_FS.elderlyIds);
    return list.map((e) => e.trim()).where((e) => e.isNotEmpty).toSet().toList()..sort();
  }

  Future<void> ensureCaregiverLink({
    required String elderUid,
    required String caregiverUid,
  }) async {
    if (elderUid.trim().isEmpty || caregiverUid.trim().isEmpty) return;

    final cgRef = _db.collection(_FS.account).doc(caregiverUid);
    final cgSnap = await cgRef.get();
    if (!cgSnap.exists) {
      throw StateError('Caregiver account not found for uid=$caregiverUid');
    }

    await cgRef.set(
      {'elderlyIds': FieldValue.arrayUnion([elderUid])},
      SetOptions(merge: true),
    );
  }

  Future<List<String>> fetchLinkedCaregivers(String elderUid) async {
    final q = await _db
        .collection(_FS.account)
        .where(_FS.elderlyIds, arrayContains: elderUid)
        .get();

    return q.docs
        .map((d) => (d.data()['uid'] as String? ?? '').trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  Future<Map<String, String>?> fetchPrimaryCaregiver(String elderUid) async {
    final uids = await fetchLinkedCaregivers(elderUid);
    if (uids.isEmpty) return null;

    final (ref, data) = await _accountDocAndDataByUid(uids.first);
    String? display = (data['displayName'] as String?)?.trim();
    final first = (data['firstName'] as String?)?.trim() ?? (data['firstname'] as String?)?.trim();
    final last  = (data['lastName']  as String?)?.trim() ?? (data['lastname']  as String?)?.trim();

    display = (display != null && display.isNotEmpty)
        ? display
        : [first, last].where((e) => (e ?? '').isNotEmpty).join(' ').trim();

    return {
      'uid': ref.id,
      'name': (display == null || display.isEmpty) ? 'Caregiver' : display,
    };
  }

  // ─────────────────────────── Reminders + Notifications ─────────────────────────

  Future<String?> _emailKeyForUid(String uid) async {
    final snap = await _db.collection(_FS.accountByUid).doc(uid).get();
    final k = (snap.data()?['emailKey'] ?? '').toString().trim();
    return k.isEmpty ? null : k;
  }

  Future<void> _addReminderForUser({
    required String uid,
    required String eventId,
    required String title,
    required DateTime start,
    required Duration duration,
    required int preNotifyMinutes,
    required String joinUrl,
  }) async {
    final emailKey = await _emailKeyForUid(uid);
    if (emailKey == null) return;

    final ref = _db.collection(_FS.reminders).doc(emailKey);
    final payload = {
      eventId: {
        'title': title,
        'startTime': start.toIso8601String(),
        'duration': duration.inMinutes,
        'preNotifyMinutes': preNotifyMinutes,
        'joinUrl': joinUrl,
        'type': 'gp_consult',
      }
    };
    await ref.set(payload, SetOptions(merge: true));
  }

  Future<void> _notify({
    required List<String> toUids,
    required String title,
    required String message,
    required Map<String, dynamic> extra,
  }) async {
    final batch = _db.batch();
    for (final to in toUids.toSet()) {
      final nref = _db.collection(_FS.notifications).doc();
      batch.set(nref, {
        'toUid': to,
        'title': title,
        'message': message,
        'type': 'gp_invite',
        'priority': 'medium',
        'data': extra,
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
      });
    }
    await batch.commit();
  }

  // ─────────────────────────── Booking (events + subcollections) ─────────────────

  Future<BookingResult> bookFutureGpCall({
    required String elderlyId,      // elder uid
    required String elderlyName,
    required DateTime start,
    required Duration duration,
    required String reason,
    bool invitePrimaryCaregiver = false,
  }) async {
    if (reason.trim().isEmpty) {
      return BookingResult(false, 'Please provide a reason for the appointment.');
    }

    try {
      final elderRef = await _accountDocRefByUid(elderlyId);

      // linked caregivers snapshot
      final caregivers = await fetchLinkedCaregivers(elderlyId);
      final invitedCg = invitePrimaryCaregiver && caregivers.isNotEmpty ? caregivers.first : null;

      final end = start.add(duration);

      // (1) Flat events doc
      final eventRef = _db.collection(_FS.events).doc();

      final joinUri = _joinCallDeepLink(eventId: eventRef.id, elderlyId: elderlyId);
      final joinUrl = joinUri.toString();

      final eventPayload = {
        'title': 'GP Consultation (Online)',
        'description': reason,
        'type': 'gp_consultation_booking',
        'elderlyId': elderlyId,
        'elderlyName': elderlyName,
        'caregiverId': invitedCg,
        'linkedCaregivers': caregivers,
        'start': Timestamp.fromDate(start),
        'end': Timestamp.fromDate(end),
        'isAllDay': false,
        'status': 'scheduled',
        'joinUrl': joinUrl,

        'createdAt': FieldValue.serverTimestamp(),
      };

      // (2) Elder subcollection appointment
      final elderApptRef = elderRef.collection('appointments').doc();
      final elderAppt = {
        'title': 'GP Consultation (Online)',
        'description': reason,
        'type': 'gp_consultation_booking',
        'dateTime': Timestamp.fromDate(start),
        'endDateTime': Timestamp.fromDate(end),
        'isAllDay': false,
        'status': 'scheduled',
        'mirrorEventId': eventRef.id,
        'elderUid': elderlyId,
        'joinUrl': joinUrl,
        'createdAt': FieldValue.serverTimestamp(),
      };

      final batch = _db.batch();
      batch.set(eventRef, eventPayload);
      batch.set(elderApptRef, elderAppt);

      // (3) Mirror to caregivers (optional)
      if (mirrorToCaregivers && caregivers.isNotEmpty) {
        for (final cgUid in caregivers) {
          final cgRef = await _accountDocRefByUid(cgUid);
          final cgApptRef = cgRef.collection('appointments').doc();
          batch.set(cgApptRef, {
            'title': 'Elder: $elderlyName — GP Consultation',
            'description': reason,
            'type': 'elder_gp_consult',
            'dateTime': Timestamp.fromDate(start),
            'endDateTime': Timestamp.fromDate(end),
            'isAllDay': false,
            'status': 'scheduled',
            'elderUid': elderlyId,
            'mirrorEventId': eventRef.id,
            'joinUrl': joinUrl,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      }

      // (4) Commit calendar writes
      await batch.commit();

      // (5) Event reminders for everyone (elder + all caregivers)
      const preNotifyMinutes = 15; // adjust if you want a different lead time
      final participants = <String>{elderlyId, ...caregivers};
      for (final uid in participants) {
        await _addReminderForUser(
          uid: uid,
          eventId: eventRef.id,
          title: 'GP Consultation (Online)',
          start: start,
          duration: duration,
          preNotifyMinutes: preNotifyMinutes,
          joinUrl: joinUrl,
        );
      }

      // (6) Notifications
      await _notify(
        toUids: participants.toList(),
        title: 'GP Consultation booked',
        message: 'Your consultation is scheduled on ${DateFormat('EEE, MMM d, h:mm a').format(start)}.',
        extra: {
          'eventId': eventRef.id,
          'elderlyId': elderlyId,
          'elderlyName': elderlyName,
          'start': start.toIso8601String(),
          'durationMin': duration.inMinutes,
          'joinUrl': joinUrl,
        },
      );

      return BookingResult(true, 'Appointment booked and synced to calendar & reminders.');
    } on FirebaseException catch (e) {
      return BookingResult(false, e.message ?? e.code);
    } catch (e) {
      return BookingResult(false, e.toString());
    }
  }

  Stream<List<String>> quickReasonsStream() {
    return _db.collection(_FS.config).doc('quickReasons').snapshots().map((snap) {
      final data = snap.data();
      final raw = data?['reasons'];
      if (raw is List) {
        return raw.map((e) => e.toString()).toList();
      }
      return const <String>[];
    });
  }
}
