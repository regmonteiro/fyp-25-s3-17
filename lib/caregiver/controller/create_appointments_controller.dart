import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

/// Helper to derive the canonical emailKey used under `/reminders/{emailKey}`
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

  // ─── Collection names (match Firestore exactly) ───
  static const String _appointmentsCol = 'Appointments';   // /Appointments
  static const String _remindersCol = 'reminders';         // /reminders
  static const String _notificationsCol = 'notifications'; // /notifications
  static const String _accountCol = 'Account';             // /Account (user profiles)

  // ─────────────────────── Helpers ───────────────────────

  /// Look up user's email from /Account/{uid} and convert to emailKey.
  Future<String?> _emailKeyForUid(String uid) async {
    final snap = await _firestore.collection(_accountCol).doc(uid).get();
    if (!snap.exists) return null;

    final data = snap.data() ?? <String, dynamic>{};

    // Try a few possible email fields you might be using
    final rawEmail = (data['email'] ??
            data['elderEmail'] ??
            data['caregiverEmail'] ??
            '')
        .toString()
        .trim();

    if (rawEmail.isEmpty) return null;
    return emailKeyFrom(rawEmail);
  }

  Future<void> _addReminderForUser({
    required String uid,
    required String eventId,
    required String title,
    required DateTime start,
    required Duration duration,
    required int preNotifyMinutes,
    required String type, // 'appointment' | 'task' | 'reminder'
  }) async {
    final emailKey = await _emailKeyForUid(uid);
    if (emailKey == null) return;

    final ref = _firestore.collection(_remindersCol).doc(emailKey);

    await ref.set({
      eventId: {
        // Shape expected by CaregiverUpcomingRemindersSection.EventReminder
        'title': title,
        'startTime': start.toIso8601String(),
        'duration': duration.inMinutes,

        // Extra metadata (safe to ignore in UI)
        'createdAt': DateTime.now().toIso8601String(),
        'preNotifyMinutes': preNotifyMinutes,
        'type': type,
      }
    }, SetOptions(merge: true));
  }

  Future<void> _removeReminderForUser({
    required String uid,
    required String eventId,
  }) async {
    final emailKey = await _emailKeyForUid(uid);
    if (emailKey == null) return;

    final ref = _firestore.collection(_remindersCol).doc(emailKey);
    await ref.set({
      eventId: FieldValue.delete(),
    }, SetOptions(merge: true));
  }

  Future<void> _notify({
    required List<String> toUids,
    required String title,
    required String message,
    required String type, // 'appointment_create' | 'appointment_update' | 'appointment_delete'
    required Map<String, dynamic> extra,
  }) async {
    final batch = _firestore.batch();
    for (final uid in toUids.toSet()) {
      final nref = _firestore.collection(_notificationsCol).doc();
      batch.set(nref, {
        'toUid': uid,
        'title': title,
        'message': message,
        'type': type,
        'priority': 'low',
        'data': extra,
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
      });
    }
    await batch.commit();
  }

  // ─────────────────────── Create / Update / Delete ───────────────────────

  /// If [appointmentId] is null → create.
  /// Otherwise → update existing /Appointments/{appointmentId}.
  Future<void> createAppointment({
    String? appointmentId,
    required String elderlyId,
    required String caregiverId,
    required String title,
    required String description,
    required DateTime dateTime,
    required String type,
    required bool isAllDay,
    Duration? duration,
  }) async {
    final sanitizedTitle = title.trim();
    if (sanitizedTitle.isEmpty) {
      throw ArgumentError('Title cannot be empty');
    }

    final effectiveDuration = duration ?? const Duration(minutes: 30);
    final durationMinutes = effectiveDuration.inMinutes;

    final dateStr = DateFormat('yyyy-MM-dd').format(dateTime);
    final timeStr = DateFormat('HH:mm').format(dateTime);

    final col = _firestore.collection(_appointmentsCol);
    final docRef = appointmentId == null ? col.doc() : col.doc(appointmentId);

    final payload = <String, dynamic>{
      'id': docRef.id,
      'elderlyId': elderlyId,
      'caregiverId': caregiverId,
      'title': sanitizedTitle,
      'notes': description.trim(),
      'type': type, // 'appointment' | 'task' | 'reminder'
      'isAllDay': isAllDay,
      'durationMinutes': isAllDay ? 1440 : durationMinutes,
      'date': dateStr,
      'time': timeStr,
      'createdBy': 'caregiver',
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (appointmentId == null) {
      payload['createdAt'] = FieldValue.serverTimestamp();
    }

    await docRef.set(payload, SetOptions(merge: true));

    // Reminders + notifications for both elder + caregiver
    const preNotifyMinutes = 30;
    final participants = <String>{elderlyId, caregiverId};

    for (final uid in participants) {
      await _addReminderForUser(
        uid: uid,
        eventId: docRef.id,
        title: sanitizedTitle,
        start: dateTime,
        duration: effectiveDuration,
        preNotifyMinutes: preNotifyMinutes,
        type: type,
      );
    }

    final whenFmt = DateFormat('EEE, MMM d, h:mm a').format(dateTime);
    await _notify(
      toUids: participants.toList(),
      title: 'Appointment ${appointmentId == null ? 'created' : 'updated'}',
      message: '$sanitizedTitle on $whenFmt',
      type: appointmentId == null ? 'appointment_create' : 'appointment_update',
      extra: {
        'appointmentId': docRef.id,
        'elderlyId': elderlyId,
        'caregiverId': caregiverId,
        'type': type,
        'dateTime': dateTime.toIso8601String(),
        'isAllDay': isAllDay,
        'durationMinutes': durationMinutes,
      },
    );
  }

  Future<void> updateAppointment({
    required String appointmentId,
    required String elderlyId,
    required String caregiverId,
    required String title,
    required String description,
    required DateTime dateTime,
    required String type,
    required bool isAllDay,
    Duration? duration,
  }) async {
    await createAppointment(
      appointmentId: appointmentId,
      elderlyId: elderlyId,
      caregiverId: caregiverId,
      title: title,
      description: description,
      dateTime: dateTime,
      type: type,
      isAllDay: isAllDay,
      duration: duration,
    );
  }

  Future<void> deleteAppointment({
    required String appointmentId,
    required String elderlyId,
    required String caregiverId,
  }) async {
    final docRef = _firestore.collection(_appointmentsCol).doc(appointmentId);
    final snap = await docRef.get();
    if (!snap.exists) return;

    final data = snap.data() ?? <String, dynamic>{};
    final title = (data['title'] ?? '').toString();
    final type = (data['type'] ?? 'appointment').toString();
    final dateStr = (data['date'] ?? '').toString();
    final timeStr = (data['time'] ?? '').toString();

    // Delete the appointment doc
    await docRef.delete();

    // Remove reminders for both participants
    final participants = <String>{elderlyId, caregiverId};
    for (final uid in participants) {
      await _removeReminderForUser(uid: uid, eventId: appointmentId);
    }

    // Send delete notification
    final msg = title.isEmpty
        ? 'An appointment was deleted ($type on $dateStr $timeStr).'
        : 'Appointment "$title" on $dateStr $timeStr was deleted.';

    await _notify(
      toUids: participants.toList(),
      title: 'Appointment deleted',
      message: msg,
      type: 'appointment_delete',
      extra: {
        'appointmentId': appointmentId,
        'elderlyId': elderlyId,
        'caregiverId': caregiverId,
        'type': type,
        'date': dateStr,
        'time': timeStr,
      },
    );
  }

  // ─────────────────────── Stream for bottom list ───────────────────────

  /// Stream all appointments ordered by createdAt desc.
  /// (Filter by caregiverId / elderlyId in the UI query if needed.)
  Stream<QuerySnapshot<Map<String, dynamic>>> appointmentsStreamOrdered() {
    return _firestore
        .collection(_appointmentsCol)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }
}
