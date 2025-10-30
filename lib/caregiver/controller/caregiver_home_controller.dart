import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/user_profile.dart';
import '../../linking/mutuallinking.dart';

// ───────────────────────── ViewModel ─────────────────────────
class CaregiverHomeViewModel {
  final List<String> linkedElderlyIds;
  final Map<String, String> elderNames;
  final Map<String, Map<String, dynamic>?> metricsByElder;
  final Map<String, List<Map<String, dynamic>>> upcomingEventsByElder;
  final List<Map<String, dynamic>> announcements;
  final List<Map<String, dynamic>> learningRecs;
  final Map<String, List<Map<String, dynamic>>> todayMedsByElder;
  final Map<String, List<Map<String, dynamic>>> todayScheduleByElder;
  final List<Map<String, dynamic>> notifications;
  final int unreadNotifications;
  

  CaregiverHomeViewModel({
    required this.linkedElderlyIds,
    required this.elderNames,
    required this.metricsByElder,
    required this.upcomingEventsByElder,
    required this.announcements,
    required this.learningRecs,
    required this.todayMedsByElder,
    required this.todayScheduleByElder,
    required this.notifications,
    required this.unreadNotifications,
  });

  factory CaregiverHomeViewModel.empty() => CaregiverHomeViewModel(
        linkedElderlyIds: const [],
        elderNames: const {},
        metricsByElder: const {},
        upcomingEventsByElder: const {},
        announcements: const [],
        learningRecs: const [],
        todayMedsByElder: const {},
        todayScheduleByElder: const {},
        notifications: const [],
        unreadNotifications: 0,
      );
}

// ───────────────────────── Controller ─────────────────────────
class CaregiverHomeController {
  final UserProfile userProfile;
  final _fs = FirebaseFirestore.instance;
  final _links = MutualLinkingService();


  CaregiverHomeController({required this.userProfile});

  String? _activeElder;

  final _vmCtrl = StreamController<CaregiverHomeViewModel>.broadcast();
  Stream<CaregiverHomeViewModel> get view$ => _vmCtrl.stream;

  final List<StreamSubscription> _subs = [];
  CaregiverHomeViewModel? _latestVm;
  CaregiverHomeViewModel? get latestVm => _latestVm;

  void _emit(CaregiverHomeViewModel vm) {
    _latestVm = vm;
    _vmCtrl.add(vm);
  }

  void _emitEmpty() => _emit(CaregiverHomeViewModel.empty());

  // Put this near your other public methods
void setActiveElder(String uid) {
  final v = uid.trim();
  _activeElder = v.isEmpty ? null : v;

  // Optional: if you want an immediate UI refresh using the last VM,
  // re-emit without changing data. Otherwise the next snapshot tick
  // will naturally rebuild with the new _activeElder.
  if (_latestVm != null) {
    _vmCtrl.add(_latestVm!);
  }
}


  // ─── Init ──────────────────────────────────────────────────
  Future<void> init() async {
    for (final s in _subs) {
      await s.cancel();
    }
    _subs.clear();
    _emitEmpty();

    final caregiverRef = await _accountDocRefEither();
    final caregiverUid = caregiverRef.id;

    // Normalize caregiver doc to ensure elderlyIds exists/merged
    await normalizeCaregiverDoc(caregiverUid);

    final caregiver$    = caregiverRef.snapshots();
    final announcements$ = _fs.collection('announcements').orderBy('createdAt', descending: true).limit(25).snapshots();
    final recs$          = _fs.collection('learningRecommendations').orderBy('createdAt', descending: true).limit(25).snapshots();
    // Notifications: use toUid (in your rules)
    final notifs$        = _fs.collection('notifications')
                              .where('toUid', isEqualTo: caregiverUid)
                              .orderBy('timestamp', descending: true)
                              .limit(25)
                              .snapshots();

    DocumentSnapshot<Map<String, dynamic>>? _cgSnap;
    QuerySnapshot<Map<String, dynamic>>? _annSnap;
    QuerySnapshot<Map<String, dynamic>>? _recSnap;
    QuerySnapshot<Map<String, dynamic>>? _notifSnap;

    Future<void> rebuild({
      Map<String, Map<String, dynamic>?>? metricsByElder,
      Map<String, List<Map<String, dynamic>>>? eventsByElder,
      Map<String, List<Map<String, dynamic>>>? medsByElder,
      Map<String, List<Map<String, dynamic>>>? schedByElder,
      Map<String, String>? elderNames,
    }) async {
      final cg = _cgSnap?.data() ?? {};
      final elderIds = _extractLinkedElders(cg);

      _activeElder = (_activeElder != null && elderIds.contains(_activeElder))
          ? _activeElder
          : (elderIds.isNotEmpty ? elderIds.first : null);

      if (elderIds.isEmpty) {
        _emit(CaregiverHomeViewModel(
          linkedElderlyIds: const [],
          elderNames: const {},
          metricsByElder: const {},
          upcomingEventsByElder: const {},
          announcements: _mapDocs(_annSnap),
          learningRecs: _mapDocs(_recSnap),
          todayMedsByElder: const {},
          todayScheduleByElder: const {},
          notifications: _mapDocs(_notifSnap),
          unreadNotifications: _countUnread(_mapDocs(_notifSnap)),
        ));
        return;
      }

      final Map<String, String> names =
          elderNames ?? await _safe<Map<String, String>>(
            _fetchElderNames(elderIds),
            const <String, String>{},
          );

      final Map<String, Map<String, dynamic>?> metrics =
          metricsByElder ?? await _safe<Map<String, Map<String, dynamic>?>>(
            _fetchAllMetrics(elderIds),
            const <String, Map<String, dynamic>?>{},
          );

      final Map<String, List<Map<String, dynamic>>> events =
          eventsByElder ?? await _safe<Map<String, List<Map<String, dynamic>>>>(
            _fetchUpcomingEvents(elderIds),
            const <String, List<Map<String, dynamic>>>{},
          );

      final Map<String, List<Map<String, dynamic>>> meds =
          medsByElder ?? await _safe<Map<String, List<Map<String, dynamic>>>>(
            _fetchTodayMeds(elderIds),
            const <String, List<Map<String, dynamic>>>{},
          );

      final Map<String, List<Map<String, dynamic>>> sched =
          schedByElder ?? await _safe<Map<String, List<Map<String, dynamic>>>>(
            _fetchTodaySchedule(elderIds),
            const <String, List<Map<String, dynamic>>>{},
          );

      final List<Map<String, dynamic>> anns  = _mapDocs(_annSnap);
      final List<Map<String, dynamic>> lrecs = _mapDocs(_recSnap);
      final List<Map<String, dynamic>> ns    = _mapDocs(_notifSnap);
      final int unread = _countUnread(ns);

      _emit(CaregiverHomeViewModel(
        linkedElderlyIds: elderIds,
        elderNames: names,
        metricsByElder: metrics,
        upcomingEventsByElder: events,
        announcements: anns,
        learningRecs: lrecs,
        todayMedsByElder: meds,
        todayScheduleByElder: sched,
        notifications: ns,
        unreadNotifications: unread,
      ));
    }

    _subs.add(caregiver$.listen((s) async {
      _cgSnap = s;
      final elderIds = _extractLinkedElders(s.data() ?? {});
      if (elderIds.isEmpty) {
        await rebuild();
        return;
      }
      final names   = await _safe(_fetchElderNames(elderIds), <String, String>{});
      final metrics = await _safe(_fetchAllMetrics(elderIds), <String, Map<String, dynamic>?>{});
      final events  = await _safe(_fetchUpcomingEvents(elderIds), <String, List<Map<String, dynamic>>>{});
      final meds    = await _safe(_fetchTodayMeds(elderIds), <String, List<Map<String, dynamic>>>{});
      final sched   = await _safe(_fetchTodaySchedule(elderIds), <String, List<Map<String, dynamic>>>{});
      await rebuild(
        elderNames: names,
        metricsByElder: metrics,
        eventsByElder: events,
        medsByElder: meds,
        schedByElder: sched,
      );
    }));

    _subs.add(announcements$.listen((s) { _annSnap = s; rebuild(); }));
    _subs.add(recs$.listen((s) { _recSnap = s; rebuild(); }));
    _subs.add(notifs$.listen((s) { _notifSnap = s; rebuild(); }));
  }

  // ───────────────────────── Helpers ─────────────────────────
  List<Map<String, dynamic>> _mapDocs(QuerySnapshot<Map<String, dynamic>>? s) =>
      (s?.docs ?? const []).map((d) => {'id': d.id, ...d.data()}).toList();

  int _countUnread(List<Map<String, dynamic>> ns) =>
      ns.where((m) => !(m['read'] as bool? ?? false)).length;

  Future<T> _safe<T>(Future<T> fut, T fallback) async {
    try { return await fut; } catch (_) { return fallback; }
  }

  /// Extract links from new fields (with legacy fallback).
  List<String> _extractLinkedElders(Map<String, dynamic> cg) {
    final out = <String>{};
    final many = cg['elderlyIds'];
    if (many is List) {
      for (final e in many) {
        final s = e?.toString().trim();
        if (s != null && s.isNotEmpty) out.add(s);
      }
    }
    final single = (cg['elderlyId'] as String?)?.trim();
    if (single != null && single.isNotEmpty) out.add(single);
    out.removeWhere((e) => e.isEmpty);
    return out.toList();
  }

  bool _looksLikeEmailKey(String id) {
    // e.g. local@domain_tld (domain dots replaced by underscores)
    return id.contains('@') && id.split('@').last.contains('_');
  }

  /// Fetch elder names by resolving email-keyed doc **or** UID doc.
  Future<Map<String, String>> _fetchElderNames(List<String> ids) async {
    final out = <String, String>{};
    for (final id in ids) {
      try {
        DocumentSnapshot<Map<String, dynamic>>? snap;

        // 1) If the id itself is an email-key (most of your DB), read it directly
        if (_looksLikeEmailKey(id)) {
          snap = await _fs.collection('Account').doc(id).get();
        } else {
          // 2) Try direct UID doc
          final direct = await _fs.collection('Account').doc(id).get();
          if (direct.exists) {
            snap = direct;
          } else {
            // 3) Fallback: query by uid field (handles email-keyed docs)
            final qs = await _fs.collection('Account').where('uid', isEqualTo: id).limit(1).get();
            snap = qs.docs.isNotEmpty ? qs.docs.first : null;
          }
        }

        final m = snap?.data() ?? {};
        final safe = (m['safeDisplayName'] ?? m['displayName'])?.toString().trim();
        final first = (m['firstName'] ?? m['firstname'])?.toString().trim() ?? '';
        final last  = (m['lastName']  ?? m['lastname']) ?.toString().trim() ?? '';
        final name = (safe != null && safe.isNotEmpty)
            ? safe
            : [first, last].where((e) => e.isNotEmpty).join(' ').trim();
        out[id] = name.isEmpty ? 'Elder' : name;
      } catch (_) {
        out[id] = 'Elder';
      }
    }
    return out;
  }

  Future<Map<String, Map<String, dynamic>?>> _fetchAllMetrics(List<String> elderlyIds) async {
    final dayKey = DateTime.now().toIso8601String().split('T').first;
    final out = <String, Map<String, dynamic>?>{};
    for (final uid in elderlyIds) {
      Map<String, dynamic>? metrics;
      try {
        final docId = '${uid}_$dayKey';
        final doc = await _fs.collection('metricsDaily').doc(docId).get();
        if (doc.exists) {
          metrics = doc.data();
        } else {
          final q = await _fs.collection('metricsDaily')
              .where('ownerUid', isEqualTo: uid)
              .where('dayKey', isEqualTo: dayKey)
              .limit(1).get();
          if (q.docs.isNotEmpty) metrics = q.docs.first.data();
        }
      } catch (_) { metrics = null; }
      out[uid] = metrics;
    }
    return out;
  }

  Future<Map<String, List<Map<String, dynamic>>>> _fetchUpcomingEvents(List<String> elderlyIds) async {
    final out = <String, List<Map<String, dynamic>>>{};
    final now = DateTime.now();

    for (final uid in elderlyIds) {
      try {
        final byFlat = await _fs.collection('events')
            .where('elderlyId', isEqualTo: uid)
            .where('start', isGreaterThanOrEqualTo: Timestamp.fromDate(now))
            .orderBy('start')
            .limit(10).get();

        if (byFlat.docs.isNotEmpty) {
          out[uid] = byFlat.docs.map((d) => {'id': d.id, ...d.data()}).toList();
          continue;
        }
      } catch (_) { /* ignore */ }

      try {
        final byRem = await _fs.collection('reminders')
            .where('elderlyId', isEqualTo: uid).get();

        final items = byRem.docs.map((d) => {'id': d.id, ...d.data()}).where((m) {
          final ts = m['startTime'];
          DateTime? dt;
          if (ts is Timestamp) dt = ts.toDate();
          if (ts is String) dt = DateTime.tryParse(ts);
          return dt != null && dt.isAfter(now);
        }).toList()
          ..sort((a, b) {
            DateTime? ad, bd;
            final ats = a['startTime'], bts = b['startTime'];
            if (ats is Timestamp) ad = ats.toDate(); else if (ats is String) ad = DateTime.tryParse(ats);
            if (bts is Timestamp) bd = bts.toDate(); else if (bts is String) bd = DateTime.tryParse(bts);
            ad ??= DateTime.fromMillisecondsSinceEpoch(0);
            bd ??= DateTime.fromMillisecondsSinceEpoch(0);
            return ad.compareTo(bd);
          });

        out[uid] = items.take(10).toList();
      } catch (_) {
        out[uid] = const [];
      }
    }
    return out;
  }

  Future<Map<String, List<Map<String, dynamic>>>> _fetchTodayMeds(List<String> elderlyIds) async {
    final out = <String, List<Map<String, dynamic>>>{};
    final today = DateTime.now().toIso8601String().split('T').first;

    for (final uid in elderlyIds) {
      try {
        final q = await _fs.collection('medicationReminders')
            .where('elderlyId', isEqualTo: uid).get();

        final items = q.docs.map((d) => {'id': d.id, 'ref': d.reference, ...d.data()}).where((m) {
          final date = m['date']?.toString();
          return date == null || date == today;
        }).toList()
          ..sort((a, b) => (a['reminderTime'] ?? '00:00')
              .toString().compareTo((b['reminderTime'] ?? '00:00').toString()));

        out[uid] = items;
      } catch (_) { out[uid] = const []; }
    }
    return out;
  }

  Future<Map<String, List<Map<String, dynamic>>>> _fetchTodaySchedule(List<String> elderlyIds) async {
    final out = <String, List<Map<String, dynamic>>>{};
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));

    for (final uid in elderlyIds) {
      final items = <Map<String, dynamic>>[];

      try {
        final t1 = await _fs.collection('tasks')
            .where('elderlyId', isEqualTo: uid)
            .where('dueAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
            .where('dueAt', isLessThan: Timestamp.fromDate(end))
            .get();

        final t2 = await _fs.collection('tasks')
            .where('ownerUid', isEqualTo: uid)
            .where('dueAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
            .where('dueAt', isLessThan: Timestamp.fromDate(end))
            .get();

        final tDocs = (t1.docs.isNotEmpty ? t1.docs : t2.docs);
        for (final d in tDocs) {
          items.add({'id': d.id, 'ref': d.reference, ...d.data()});
        }
      } catch (_) {}

      try {
        final meds = await _fs.collection('medicationReminders')
            .where('elderlyId', isEqualTo: uid).get();

        for (final d in meds.docs) {
          final m = d.data();
          final date = m['date']?.toString();
          if (date == null || date == start.toIso8601String().split('T').first) {
            items.add({
              'id': d.id,
              'ref': d.reference,
              'title': m['medicationName'] ?? 'Medication',
              'dueAt': _timeToday(m['reminderTime']?.toString(), start),
              'kind': 'med',
              'done': (m['status'] ?? 'pending') == 'completed',
            });
          }
        }
      } catch (_) {}

      items.sort((a, b) {
        final ad = (a['dueAt'] as Timestamp?)?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bd = (b['dueAt'] as Timestamp?)?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
        return ad.compareTo(bd);
      });

      out[uid] = items;
    }
    return out;
  }

  Timestamp _timeToday(String? hhmm, DateTime base) {
    if (hhmm == null || !RegExp(r'^\d{2}:\d{2}$').hasMatch(hhmm)) {
      return Timestamp.fromDate(base);
    }
    final parts = hhmm.split(':');
    final dt = DateTime(base.year, base.month, base.day, int.parse(parts[0]), int.parse(parts[1]));
    return Timestamp.fromDate(dt);
  }

  // ─────────── Mutations ───────────
  Future<void> linkElderly(String elderlyId) async {
  final caregiverRef = await _accountDocRefEither();
  await _fs.runTransaction((tx) async {
    final snap = await tx.get(caregiverRef);
    if (!snap.exists) throw StateError('Caregiver account doc missing');
    tx.set(
      caregiverRef,
      {
        'elderlyIds': FieldValue.arrayUnion([elderlyId]),
        'elderlyId' : elderlyId, // optional default/last-selected
      },
      SetOptions(merge: true),
    );
  });
}

Future<void> unlinkElderly(String elderlyId) async {
  final caregiverRef = await _accountDocRefEither();
  await caregiverRef.set(
    {'elderlyIds': FieldValue.arrayRemove([elderlyId])},
    SetOptions(merge: true),
  );
}

  Future<void> markNotificationRead(String id) async {
    await _fs.collection('notifications').doc(id).update({'read': true});
  }

  Future<void> markAllNotificationsRead(List<String> ids) async {
    final batch = _fs.batch();
    for (final id in ids) {
      batch.update(_fs.collection('notifications').doc(id), {'read': true});
    }
    await batch.commit();
  }

  Future<void> toggleTaskDone(DocumentReference ref, bool done) async {
    await ref.update({'done': !done});
  }

  Future<void> markMedDone(DocumentReference ref) async {
    await ref.update({
      'status': 'completed',
      'completedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> normalizeCaregiverDoc(String caregiverId) async {
    final ref = _fs.collection('Account').doc(caregiverId);
    final snap = await ref.get();
    if (!snap.exists) return;
    final data = snap.data()!;

    final merged = <String>{};
    final list = data['elderlyIds'];
    if (list is List) {
      for (final e in list) {
        final s = e?.toString().trim();
        if (s != null && s.isNotEmpty) merged.add(s);
      }
    }
    final single = (data['elderlyId'] as String?)?.trim();
    if (single != null && single.isNotEmpty) merged.add(single);

    await ref.set({
      'elderlyIds': merged.toList(),
      'linkedElderUids': FieldValue.delete(),
      'linkedElders': FieldValue.delete(),
      'uidOfElder': FieldValue.delete(),
    }, SetOptions(merge: true));
  }

  // ─────────── Account doc resolver (EMAIL → UID mirror) ───────────
  Future<DocumentReference<Map<String, dynamic>>> _accountDocRefEither() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) { throw StateError('No signed-in user.'); }

    final db = FirebaseFirestore.instance;
    final uidRef = db.collection('Account').doc(user.uid);

    final email = user.email?.trim().toLowerCase();
    if (email != null && email.isNotEmpty) {
      final emailKey = _legacyIdFromEmail(email);
      final emailRef = db.collection('Account').doc(emailKey);
      final emailSnap = await emailRef.get();
      if (emailSnap.exists) {
        await uidRef.set({
          ...?emailSnap.data(),
          'uid': user.uid,
          'email': email,
          'migratedFrom': emailKey,
          'migratedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        return uidRef;
      }
    }

    final uidSnap = await uidRef.get();
    if (!uidSnap.exists) {
      await uidRef.set({
        'uid': user.uid,
        'email': email ?? '',
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
    return uidRef;
  }

  String _legacyIdFromEmail(String email) {
    final lower = email.trim().toLowerCase();
    final at = lower.indexOf('@');
    if (at < 0) return lower;
    final local = lower.substring(0, at);
    final domain = lower.substring(at + 1).replaceAll('.', '_');
    return '$local@$domain';
  }

  void dispose() {
    for (final s in _subs) { s.cancel(); }
    _vmCtrl.close();
  }
}
