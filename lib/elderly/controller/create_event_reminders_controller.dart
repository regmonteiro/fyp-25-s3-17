import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Model
class EventReminder {
  final String id;            // Firestore field name (random id)
  final String title;
  final String startTime;     // ISO-8601 String e.g. "2025-10-21T13:34"
  final int duration;         // minutes
  final String createdAt;     // ISO-8601 String

  EventReminder({
    required this.id,
    required this.title,
    required this.startTime,
    required this.duration,
    required this.createdAt,
  });

  factory EventReminder.fromMap(String id, Map<String, dynamic> m) {
    return EventReminder(
      id: id,
      title: (m['title'] ?? '').toString(),
      startTime: (m['startTime'] ?? '').toString(),
      duration: _toInt(m['duration']),
      createdAt: (m['createdAt'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toMap() => {
        'title': title,
        'startTime': startTime,
        'duration': duration,
        'createdAt': createdAt,
      };

  bool isValid() =>
      title.trim().isNotEmpty &&
      startTime.trim().isNotEmpty &&
      duration > 0;
}

int _toInt(Object? v) {
  if (v is int) return v;
  if (v is double) return v.toInt();
  return int.tryParse(v?.toString() ?? '') ?? 0;
}

/// Firestore boundary/service
class RemindersService {
  final FirebaseFirestore _fs;
  RemindersService({FirebaseFirestore? firestore})
      : _fs = firestore ?? FirebaseFirestore.instance;

  /// Transform an email into the canonical Firestore key used by your doc id.
  /// Matches your screenshot: replace both '.' and '@' with '_'.
  String emailToKey(String emailOrKey) {
    if (!emailOrKey.contains('@')) return emailOrKey;
    return emailOrKey.trim().replaceAll('.', '_').replaceAll('@', '_');
  }

  DocumentReference<Map<String, dynamic>> _docRef(String userKey) =>
      _fs.collection('reminders').doc(userKey);

  /// Create: generate an id and store as a FIELD on reminders/{userKey}
  Future<void> createReminder(String userKey, {
    required String title,
    required String startTime, // "yyyy-MM-ddTHH:mm" (or any ISO string)
    required int durationMinutes,
  }) async {
    final id = _fs.collection('_ids').doc().id; // cheap random id
    final reminder = EventReminder(
      id: id,
      title: title.trim(),
      startTime: startTime.trim(),
      duration: durationMinutes,
      createdAt: DateTime.now().toIso8601String(),
    );
    if (!reminder.isValid()) {
      throw Exception('Invalid reminder data');
    }
    await _docRef(userKey).set({ id: reminder.toMap() }, SetOptions(merge: true));
  }

  /// Subscribe to reminders/{userKey} and emit a sorted list (by startTime).
  Stream<List<EventReminder>> subscribeToReminders(String userKey) {
    return _docRef(userKey).snapshots().map((snap) {
      if (!snap.exists) return <EventReminder>[];
      final data = snap.data() ?? {};
      final list = <EventReminder>[];
      for (final entry in data.entries) {
        final key = entry.key;
        final val = entry.value;
        if (val is Map<String, dynamic>) {
          list.add(EventReminder.fromMap(key, val));
        } else if (val is Map) {
          list.add(EventReminder.fromMap(key, Map<String, dynamic>.from(val)));
        }
      }
      list.sort((a, b) =>
          DateTime.tryParse(a.startTime)?.compareTo(DateTime.tryParse(b.startTime) ?? DateTime(0)) ?? 0);
      return list;
    });
  }

  /// Delete a single reminder field: set it to FieldValue.delete()
  Future<void> deleteReminder(String userKey, String reminderId) async {
    await _docRef(userKey).update({ reminderId: FieldValue.delete() });
  }

  /// Update a reminder field in-place.
  Future<void> updateReminder(String userKey, String reminderId, {
    String? title,
    String? startTime,
    int? durationMinutes,
  }) async {
    final update = <String, dynamic>{};
    if (title != null) update['title'] = title.trim();
    if (startTime != null) update['startTime'] = startTime.trim();
    if (durationMinutes != null) update['duration'] = durationMinutes;
    update['createdAt'] = DateTime.now().toIso8601String();

    // Validate minimally (title/startTime may be unchanged; server will merge)
    if (update.containsKey('duration') && (durationMinutes ?? 0) <= 0) {
      throw Exception('Invalid duration');
    }
    await _docRef(userKey).set({ reminderId: update }, SetOptions(merge: true));
  }

  /// One-off fetch; returns a sorted list.
  Future<List<EventReminder>> getReminders(String userKey) async {
    final snap = await _docRef(userKey).get();
    if (!snap.exists) return <EventReminder>[];
    final data = snap.data() ?? {};
    final list = <EventReminder>[];
    for (final e in data.entries) {
      final id = e.key;
      final v = e.value;
      if (v is Map<String, dynamic>) {
        list.add(EventReminder.fromMap(id, v));
      } else if (v is Map) {
        list.add(EventReminder.fromMap(id, Map<String, dynamic>.from(v)));
      }
    }
    list.sort((a, b) =>
        DateTime.tryParse(a.startTime)?.compareTo(DateTime.tryParse(b.startTime) ?? DateTime(0)) ?? 0);
    return list;
  }

  /// Fetch single reminder by id (field).
  Future<EventReminder?> getReminderById(String userKey, String reminderId) async {
    final snap = await _docRef(userKey).get();
    if (!snap.exists) return null;
    final data = snap.data() ?? {};
    final v = data[reminderId];
    if (v is Map<String, dynamic>) {
      return EventReminder.fromMap(reminderId, v);
    }
    if (v is Map) {
      return EventReminder.fromMap(reminderId, Map<String, dynamic>.from(v));
    }
    return null;
  }
}
