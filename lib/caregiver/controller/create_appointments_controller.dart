import 'package:cloud_firestore/cloud_firestore.dart';

/// Keep this helper exactly the same everywhere you use it.
String emailKeyFrom(String email) {
  final lower = email.trim().toLowerCase();
  final at = lower.indexOf('@');
  if (at < 0) return lower.replaceAll('.', '_');
  final local = lower.substring(0, at);
  final domain = lower.substring(at + 1).replaceAll('.', '_');
  return '$local@$domain';
}

class CreateAppointmentsController {
  final FirebaseFirestore _firestore;

  CreateAppointmentsController({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  static const String _appointmentsCol = 'Appointments';
  static const String _accountByUidCol = 'AccountByUid';
  static const String _remindersCol = 'reminders';
  static const String _notificationsCol = 'notifications';

  // ─────────────────────── Helpers ───────────────────────

  /// Look up emailKey for a given uid from /AccountByUid/{uid},
  /// falling back to Account/{uid}.email → emailKeyFrom(email).
  Future<String?> _emailKeyForUid(String uid) async {
    // 1) Try mirror doc in /AccountByUid
    final byUid = await _firestore.collection(_accountByUidCol).doc(uid).get();
    if (byUid.exists) {
      final ek = (byUid.data()?['emailKey'] as String?)?.trim();
      if (ek != null && ek.isNotEmpty) return ek;
    }

    // 2) Fallback: Account/{uid}.email
    final acc = await _firestore.collection('Account').doc(uid).get();
    if (acc.exists) {
      final email = (acc.data()?['email'] as String?)?.trim();
      if (email != null && email.isNotEmpty) {
        return emailKeyFrom(email);
      }
    }
    return null;
  }

  // ─────────────────────── Create ───────────────────────

  /// Main entry used by CreateAppointmentsPage.
  ///
  /// - Writes a document in /Appointments
  /// - Adds/merges a reminder under /reminders/{elderEmailKey}
  ///   so CaregiverUpcomingRemindersSection can display it.
  /// - (Optional) Adds a notification in /notifications
  Future<void> createAppointment({
    required String elderlyId,
    required String caregiverId,
    required String title,
    String? description,
    required DateTime dateTime,
    required String type,          // 'appointment' | 'task' | 'reminder'
    required bool isAllDay,
    required Duration duration,
  }) async {
    final now = DateTime.now();
    final start = dateTime;
    final durationMinutes =
        isAllDay ? const Duration(hours: 24).inMinutes : duration.inMinutes;

    // Lookup emailKey for the elder so we can write to /reminders/{emailKey}
    final elderEmailKey = await _emailKeyForUid(elderlyId);

    await _firestore.runTransaction((tx) async {
      // 1) Create appointment doc
      final apptRef = _firestore.collection(_appointmentsCol).doc();

      tx.set(apptRef, {
        'id': apptRef.id,
        'elderlyId': elderlyId,
        'caregiverId': caregiverId,
        'title': title,
        'description': description ?? '',
        'type': type,
        'isAllDay': isAllDay,
        'start': Timestamp.fromDate(start),
        'durationMinutes': durationMinutes,
        'status': 'scheduled',
        'createdAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
      });

      // 2) Mirror to /reminders/{elderEmailKey} so the caregiver dashboard can show it
      if (elderEmailKey != null && elderEmailKey.isNotEmpty) {
        final remRef =
            _firestore.collection(_remindersCol).doc(elderEmailKey);

        // We store each reminder as a field keyed by appointmentId
        tx.set(
          remRef,
          {
            apptRef.id: {
              'title': title,
              'startTime': start.toIso8601String(),
              'duration': durationMinutes,
              'createdAt': now.toIso8601String(),
              'type': type,
              'appointmentId': apptRef.id,
              'elderlyId': elderlyId,
              'caregiverId': caregiverId,
              'isAllDay': isAllDay,
            },
          },
          SetOptions(merge: true),
        );
      }

      // 3) Optional: basic notification to elder (and/or caregiver)
      // You can extend this later if you want richer flows.
      final notifRef = _firestore.collection(_notificationsCol).doc();
      tx.set(notifRef, {
        'toUid': elderlyId,
        'fromUid': caregiverId,
        'type': 'Appointments',
        'kind': 'created', // used in _NotificationsSection for badge
        'title': 'New appointment',
        'message': title,
        'appointmentId': apptRef.id,
        'timestamp': Timestamp.fromDate(now),
        'read': false,
        'priority': 'low',
      });
    });
  }

  // ─────────────────────── Update (optional, for later) ───────────────────────

  Future<void> updateAppointment({
    required String appointmentId,
    required String elderlyId,
    required String caregiverId,
    required String title,
    String? description,
    required DateTime dateTime,
    required String type,
    required bool isAllDay,
    required Duration duration,
  }) async {
    final now = DateTime.now();
    final durationMinutes =
        isAllDay ? const Duration(hours: 24).inMinutes : duration.inMinutes;
    final elderEmailKey = await _emailKeyForUid(elderlyId);

    await _firestore.runTransaction((tx) async {
      final apptRef = _firestore.collection(_appointmentsCol).doc(appointmentId);

      tx.update(apptRef, {
        'elderlyId': elderlyId,
        'caregiverId': caregiverId,
        'title': title,
        'description': description ?? '',
        'type': type,
        'isAllDay': isAllDay,
        'start': Timestamp.fromDate(dateTime),
        'durationMinutes': durationMinutes,
        'status': 'scheduled',
        'updatedAt': Timestamp.fromDate(now),
      });

      if (elderEmailKey != null && elderEmailKey.isNotEmpty) {
        final remRef =
            _firestore.collection(_remindersCol).doc(elderEmailKey);
        tx.set(
          remRef,
          {
            appointmentId: {
              'title': title,
              'startTime': dateTime.toIso8601String(),
              'duration': durationMinutes,
              'createdAt': now.toIso8601String(),
              'type': type,
              'appointmentId': appointmentId,
              'elderlyId': elderlyId,
              'caregiverId': caregiverId,
              'isAllDay': isAllDay,
            },
          },
          SetOptions(merge: true),
        );
      }

      final notifRef = _firestore.collection(_notificationsCol).doc();
      tx.set(notifRef, {
        'toUid': elderlyId,
        'fromUid': caregiverId,
        'type': 'Appointments',
        'kind': 'updated',
        'title': 'Appointment updated',
        'message': title,
        'appointmentId': appointmentId,
        'timestamp': Timestamp.fromDate(now),
        'read': false,
        'priority': 'low',
      });
    });
  }

  // ─────────────────────── Delete (optional, for later) ───────────────────────

  Future<void> deleteAppointment({
    required String appointmentId,
    required String elderlyId,
    required String caregiverId,
  }) async {
    final now = DateTime.now();
    final elderEmailKey = await _emailKeyForUid(elderlyId);

    await _firestore.runTransaction((tx) async {
      final apptRef = _firestore.collection(_appointmentsCol).doc(appointmentId);
      tx.delete(apptRef);

      if (elderEmailKey != null && elderEmailKey.isNotEmpty) {
        final remRef =
            _firestore.collection(_remindersCol).doc(elderEmailKey);
        tx.set(
          remRef,
          {
            appointmentId: FieldValue.delete(),
          },
          SetOptions(merge: true),
        );
      }

      final notifRef = _firestore.collection(_notificationsCol).doc();
      tx.set(notifRef, {
        'toUid': elderlyId,
        'fromUid': caregiverId,
        'type': 'Appointments',
        'kind': 'deleted',
        'title': 'Appointment cancelled',
        'message': '',
        'appointmentId': appointmentId,
        'timestamp': Timestamp.fromDate(now),
        'read': false,
        'priority': 'medium',
      });
    });
  }
}
