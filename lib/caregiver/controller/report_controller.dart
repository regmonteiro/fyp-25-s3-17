import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import '../../report_models.dart';

class CaregiverReportsController {
  CaregiverReportsController({FirebaseFirestore? db, FirebaseAuth? auth})
      : _db = db ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  Stream<CaregiverReportsVM> streamVm() async* {
    final caregiverUid = _auth.currentUser?.uid;
    if (caregiverUid == null) throw Exception('Not authenticated');

    // ALWAYS read from Account/{uid}
    final caregiverDoc$ = _db.collection('Account').doc(caregiverUid).snapshots();

    await for (final cgSnap in caregiverDoc$) {
      final cg = cgSnap.data() ?? {};
      final elderIds = _extractLinkedElders(cg);
      if (elderIds.isEmpty) {
        yield CaregiverReportsVM(
          elders: const [],
          activeElderUid: '',
          bundle: ReportBundle(
            elderly: ElderlySummary(uid: '', displayName: 'No Elder Linked', age: null),
            reports: const [],
            alerts: const [],
          ),
        );
        continue;
      }

      // FIX: use the right variable name
      final activeElderUid = elderIds.first;

      final elders = await _fetchEldersSummaries(elderIds);
      final bundle = await _buildBundleForElder(activeElderUid);

      yield CaregiverReportsVM(elders: elders, activeElderUid: activeElderUid, bundle: bundle);
    }
  }

  Future<CaregiverReportsVM> switchElder(String elderUid, List<ElderlySummary> elders) async {
    final bundle = await _buildBundleForElder(elderUid);
    return CaregiverReportsVM(elders: elders, activeElderUid: elderUid, bundle: bundle);
  }

  // ─────────── data building ───────────

  Future<ReportBundle> _buildBundleForElder(String elderlyUid) async {
    final elderly = await _fetchElderSummary(elderlyUid);
    final last7 = _lastNDaysLabels(7);
    final dayKeys = _lastNDaysKeys(7);

    // metricsDaily : ownerUid == elderlyUid AND dayKey IN [..<=10]
    final metrics = await _db
        .collection('metricsDaily')
        .where('ownerUid', isEqualTo: elderlyUid)
        .where('dayKey', whereIn: dayKeys)
        .get();

    final byDay = {for (final d in metrics.docs) (d.data()['dayKey'] as String? ?? ''): d.data()};

    final systolic = <num>[];
    final diastolic = <num>[];
    final steps = <num>[];
    final sleepHrs = <double>[];
    for (final k in dayKeys) {
      final m = byDay[k] ?? {};
      systolic.add((m['systolic'] ?? m['bpSystolic'] ?? 0) as num);
      diastolic.add((m['diastolic'] ?? m['bpDiastolic'] ?? 0) as num);
      steps.add((m['steps'] ?? 0) as num);
      final sm = (m['sleepMinutes'] ?? 0) as num;
      sleepHrs.add(sm.toDouble() / 60.0);
    }

    // medicationReminders : use elderlyId (your app uses this elsewhere)
    final medsSnap = await _db
        .collection('medicationReminders')
        .where('elderlyId', isEqualTo: elderlyUid)
        .get();

    int taken = 0, missed = 0, scheduled = 0;
    final today = DateTime.now();
    final cutoff = DateTime(today.year, today.month, today.day).subtract(const Duration(days: 7));

    for (final d in medsSnap.docs) {
      final m = d.data();
      final dateStr = (m['date'] ?? '').toString();
      DateTime? dt = DateTime.tryParse(dateStr);
      if (dt == null) {
        final rt = m['reminderAt'] ?? m['reminderTime'];
        if (rt is Timestamp) dt = rt.toDate();
      }
      if (dt == null || dt.isBefore(cutoff)) continue;

      final status = (m['status'] ?? 'pending').toString();
      if (status == 'completed') taken++;
      else if (status == 'missed') missed++;
      else scheduled++;
    }

    // notifications : pick one scheme and be consistent
    // A) by elderlyId (build index on elderlyId + timestamp)
    final notifs = await _db
        .collection('notifications')
        .where('elderlyId', isEqualTo: elderlyUid)
        .orderBy('timestamp', descending: true)
        .limit(15)
        .get();

    // (If your rules use recipient model, switch to .where('toUid', isEqualTo: caregiverUid).)

    final alerts = notifs.docs.map((d) {
      final m = d.data();
      final ts = (m['timestamp'] as Timestamp?)?.toDate();
      final rel = _relativeTime(ts);
      final typeRaw = (m['type'] ?? 'info').toString();
      final type = typeRaw.contains('critical')
          ? 'critical'
          : (typeRaw.contains('warn') ? 'warning' : 'info');
      return AlertItem(
        id: d.id,
        type: type,
        title: (m['title'] ?? 'Notification').toString(),
        timeLabel: rel,
        message: (m['message'] ?? '').toString(),
      );
    }).toList();

    final reports = <ReportCardData>[
      ReportCardData(
        id: 1,
        category: 'health',
        title: 'Health Vitals',
        icon: '💗',
        labels: last7,
        series: [
          ChartSeries(label: 'Systolic', data: systolic, color: const Color(0xFFFF6B6B)),
          ChartSeries(label: 'Diastolic', data: diastolic, color: const Color(0xFF4ECDC4), filled: true),
        ],
        stats: [
          ReportStat(_bpString(systolic, diastolic), 'Blood Pressure (last)'),
          ReportStat(_lastNonZero(sleepHrs).toStringAsFixed(1), 'Sleep (h)'),
        ],
      ),
      ReportCardData(
        id: 2,
        category: 'medication',
        title: 'Medication Adherence (7d)',
        icon: '💊',
        labels: const ['Taken', 'Missed', 'Scheduled'],
        series: [
          ChartSeries(label: 'Adherence', data: [taken, missed, scheduled], color: const Color(0xFF4ECDC4)),
        ],
        stats: [
          ReportStat(_percent(taken, taken + missed + scheduled), 'Success'),
          ReportStat(missed.toString(), 'Missed'),
        ],
      ),
      ReportCardData(
        id: 3,
        category: 'activity',
        title: 'Daily Steps',
        icon: '🚶',
        labels: last7,
        series: [ChartSeries(label: 'Steps', data: steps, color: const Color(0xFF45B7D1))],
        stats: [
          ReportStat(_avg(steps).round().toString(), 'Avg Steps'),
          ReportStat(_lastNonZero(steps.map((e) => e.toDouble()).toList()).round().toString(), 'Today'),
        ],
      ),
      ReportCardData(
        id: 4,
        category: 'emergency',
        title: 'Alerts (Last 4w)',
        icon: '🚨',
        labels: _lastNWeeksLabels(4),
        series: [
          ChartSeries(
            label: 'Alerts',
            data: _alertsByWeek(notifs.docs),
            color: const Color(0xFFF093FB),
            filled: true,
          ),
        ],
        stats: [
          ReportStat(_alertsThisWeek(notifs.docs).toString(), 'This Week'),
          ReportStat(notifs.docs.length.toString(), 'Recent'),
        ],
      ),
    ];

    return ReportBundle(elderly: elderly, reports: reports, alerts: alerts);
  }

  // ─────────── helpers ───────────

  // Align with your caregiver Account schema (new + legacy fields)
  List<String> _extractLinkedElders(Map<String, dynamic> cg) {
    final set = <String>{};

    // current fields
    final many = (cg['elderlyIds'] as List?)?.map((e) => e.toString()).toList() ?? const [];
    final single = (cg['elderlyId'] as String?)?.trim();

    // legacy variants your codebase still references in places
    final legacyA = (cg['linkedElderlyIds'] as List?)?.map((e) => e.toString()).toList() ?? const [];
    final legacyB = (cg['linkedElders'] as List?)?.map((e) => e.toString()).toList() ?? const [];
    final legacyC = (cg['linkedEldersUids'] as List?)?.map((e) => e.toString()).toList() ?? const [];
    final legacySingle = (cg['uidOfElder'] as String?)?.trim();

    set.addAll(many);
    set.addAll(legacyA);
    set.addAll(legacyB);
    set.addAll(legacyC);
    if (single != null && single.isNotEmpty) set.add(single);
    if (legacySingle != null && legacySingle.isNotEmpty) set.add(legacySingle);

    set.removeWhere((e) => e.isEmpty);
    return set.toList();
  }

  Future<List<ElderlySummary>> _fetchEldersSummaries(List<String> elderIds) async {
    final out = <ElderlySummary>[];
    for (final id in elderIds) {
      out.add(await _fetchElderSummary(id));
    }
    return out;
  }

  // READ FROM Account/{uid} and use your known name fields
  Future<ElderlySummary> _fetchElderSummary(String elderlyUid) async {
    final doc = await _db.collection('Account').doc(elderlyUid).get();
    final m = doc.data() ?? {};
    final dn = (m['displayName'] ?? '').toString().trim();
    final first = (m['firstname'] ?? '').toString().trim();
    final last = (m['lastname'] ?? '').toString().trim();
    final name = dn.isNotEmpty ? dn : [first, last].where((s) => s.isNotEmpty).join(' ').trim();

    int? age;
    final dobStr = (m['dob'] ?? '').toString(); // you store dob as 'yyyy-MM-dd'
    if (dobStr.isNotEmpty) {
      final dob = DateTime.tryParse(dobStr);
      if (dob != null) {
        final now = DateTime.now();
        age = now.year - dob.year - ((now.month < dob.month || (now.month == dob.month && now.day < dob.day)) ? 1 : 0);
      }
    }
    return ElderlySummary(uid: elderlyUid, displayName: name.isEmpty ? 'elderly' : name, age: age);
  }

  // … (rest unchanged)
}


  List<String> _lastNDaysLabels(int n) {
    final now = DateTime.now();
    final fmt = DateFormat('EEE');
    return List.generate(n, (i) => fmt.format(now.subtract(Duration(days: (n - 1 - i)))));
  }

  List<String> _lastNDaysKeys(int n) {
    final now = DateTime.now();
    final fmt = DateFormat('yyyy-MM-dd');
    return List.generate(n, (i) => fmt.format(now.subtract(Duration(days: (n - 1 - i)))));
  }

  List<String> _lastNWeeksLabels(int n) {
    final now = DateTime.now();
    final fmt = DateFormat("'W'w");
    return List.generate(n, (i) => fmt.format(now.subtract(Duration(days: 7 * (n - 1 - i)))));
  }

  List<num> _alertsByWeek(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    final now = DateTime.now();
    final starts = List.generate(4, (i) {
      final start = DateTime(now.year, now.month, now.day).subtract(Duration(days: 7 * (3 - i)));
      return DateTime(start.year, start.month, start.day);
    });
    final counts = List.filled(4, 0);
    for (final d in docs) {
      final ts = (d.data()['timestamp'] as Timestamp?)?.toDate();
      if (ts == null) continue;
      for (var i = 0; i < 4; i++) {
        final start = starts[i];
        final end = start.add(const Duration(days: 7));
        if (!ts.isBefore(start) && ts.isBefore(end)) {
          counts[i] += 1;
          break;
        }
      }
    }
    return counts;
  }

  int _alertsThisWeek(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
    final end = start.add(const Duration(days: 7));
    var c = 0;
    for (final d in docs) {
      final ts = (d.data()['timestamp'] as Timestamp?)?.toDate();
      if (ts == null) continue;
      if (!ts.isBefore(start) && ts.isBefore(end)) c++;
    }
    return c;
  }

  String _relativeTime(DateTime? ts) {
    if (ts == null) return '—';
    final diff = DateTime.now().difference(ts);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} h ago';
    return '${diff.inDays} d ago';
  }

  String _bpString(List<num> sys, List<num> dia) {
    final s = sys.isNotEmpty ? sys.last : 0;
    final d = dia.isNotEmpty ? dia.last : 0;
    if ((s == 0) && (d == 0)) return '—';
    return '${s.toInt()}/${d.toInt()}';
  }

  String _percent(int a, int total) {
    if (total <= 0) return '—';
    return '${((a / total) * 100).round()}%';
  }

  double _lastNonZero(List<double> xs) {
    for (var i = xs.length - 1; i >= 0; i--) {
      if (xs[i] > 0) return xs[i];
    }
    return 0;
  }

  double _avg(List<num> xs) {
    if (xs.isEmpty) return 0;
    final s = xs.fold<num>(0, (a, b) => a + b);
    return s / xs.length;
  }
