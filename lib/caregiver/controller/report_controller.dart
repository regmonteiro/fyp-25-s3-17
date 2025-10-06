import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:printing/printing.dart';
import '../boundary/report_page.dart';

class ViewReportsCaregiverController {
  final FirebaseFirestore _fs;
  final FirebaseDatabase _rtdb;

  ViewReportsCaregiverController({
    FirebaseFirestore? firestore,
    FirebaseDatabase? database,
  })  : _fs = firestore ?? FirebaseFirestore.instance,
        _rtdb = database ?? FirebaseDatabase.instance;

  // --- JS util: emailToKey (replace '.' and '@' with '_')
  String _emailToKey(String email) => email.replaceAll(RegExp(r'[.@]'), '_');

  // --- JS util: caregiverData may include elderlyId or elderlyIds[0]. In Flutter we don’t have localStorage,
  // so we try (1) provided param; (2) Firestore users/{caregiverUidOrEmail} doc with fields elderlyId/elderlyIds.
  Future<String?> _resolveElderlyId({
    required String caregiverEmailOrUid,
    String? elderlyIdFromParam,
  }) async {
    if (elderlyIdFromParam != null && elderlyIdFromParam.isNotEmpty) {
      return elderlyIdFromParam;
    }

    // Try users/{caregiverEmailOrUid} then users/byEmail/{email}
    try {
      // primary: users/{caregiverEmailOrUid}
      final doc1 = await _fs.collection('users').doc(caregiverEmailOrUid).get();
      Map<String, dynamic>? data = doc1.data();
      if (data == null) {
        // fallback: usersByEmail/{email}
        final doc2 =
            await _fs.collection('usersByEmail').doc(caregiverEmailOrUid.toLowerCase()).get();
        data = doc2.data();
      }
      if (data != null) {
        final v1 = data['elderlyId']?.toString();
        if (v1 != null && v1.isNotEmpty) return v1;

        final v2 = data['elderlyIds'];
        if (v2 is List && v2.isNotEmpty) return v2.first.toString();
      }
    } catch (_) {
      // swallow and return null; caller will use demo data fallback
    }
    return null;
  }

  /// JS: fetchElderlyData(elderlyId) using RTDB Account/{key}
  Future<({String id, String name, int age, String email})> _fetchElderlyDataRtdb(
      String elderlyEmail) async {
    final key = _emailToKey(elderlyEmail);
    final snap = await _rtdb.ref('Account/$key').get();

    if (!snap.exists || snap.value is! Map) {
      throw Exception('Elderly data not found in database');
    }
    final m = Map<String, dynamic>.from(snap.value as Map);
    final first = (m['firstname'] ?? '').toString();
    final last = (m['lastname'] ?? '').toString();
    final dobStr = (m['dob'] ?? '').toString();

    if (first.isEmpty || last.isEmpty || dobStr.isEmpty) {
      throw Exception('Elderly data is incomplete');
    }

    final dob = DateTime.tryParse(dobStr);
    if (dob == null) {
      throw Exception('Invalid DOB format');
    }
    final now = DateTime.now();
    int age = now.year - dob.year;
    final mdiff = now.month - dob.month;
    if (mdiff < 0 || (mdiff == 0 && now.day < dob.day)) age--;

    return (id: key, name: '$first $last', age: age, email: elderlyEmail);
  }

  // --- JS: generateReportsData()
  List<ReportCardData> _generateReportsData() {
    return [
      ReportCardData(
        id: '1',
        category: 'health',
        title: 'Health Vitals',
        chartType: 'line',
        labels: const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
        values: const [125, 120, 118, 122, 119, 121, 120].map((e) => e.toDouble()).toList(),
        stats: [
          ReportStat(number: '120/80', label: 'Blood Pressure'),
          ReportStat(number: '72', label: 'Heart Rate'),
        ],
      ),
      ReportCardData(
        id: '2',
        category: 'medication',
        title: 'Medication Adherence',
        chartType: 'doughnut',
        labels: const ['Taken', 'Missed', 'Scheduled'],
        values: const [28, 2, 5].map((e) => e.toDouble()).toList(),
        stats: [
          ReportStat(number: '95%', label: 'This Week'),
          ReportStat(number: '2', label: 'Missed Doses'),
        ],
      ),
      ReportCardData(
        id: '3',
        category: 'activity',
        title: 'Daily Activities',
        chartType: 'bar',
        labels: const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
        values: const [2800, 3200, 2950, 4200, 3800, 2100, 3240]
            .map((e) => e.toDouble())
            .toList(),
        stats: [
          ReportStat(number: '3240', label: 'Steps Today'),
          ReportStat(number: '7.5', label: 'Sleep Hours'),
        ],
      ),
      ReportCardData(
        id: '4',
        category: 'emergency',
        title: 'Emergency Alerts',
        chartType: 'line',
        labels: const ['Week 1', 'Week 2', 'Week 3', 'Week 4'],
        values: const [0, 1, 0, 0].map((e) => e.toDouble()).toList(),
        stats: [
          ReportStat(number: '0', label: 'This Week'),
          ReportStat(number: '1', label: 'This Month'),
        ],
      ),
    ];
  }

  // --- JS: generateAlertsData(elderlyName)
  List<AlertItem> _generateAlertsData(String elderlyName) {
    return [
      AlertItem(
        id: '1',
        type: 'warning',
        title: 'Medication Reminder',
        time: '2 hours ago',
        message: '$elderlyName missed afternoon medication.',
      ),
      AlertItem(
        id: '2',
        type: 'info',
        title: 'Activity Update',
        time: '5 hours ago',
        message: '$elderlyName walked 4,200 steps today.',
      ),
      AlertItem(
        id: '3',
        type: 'info',
        title: 'Health Check',
        time: '1 day ago',
        message: 'Blood pressure reading recorded for $elderlyName: 118/76 mmHg.',
      ),
    ];
  }

  /// === Public API (called by your Flutter page) ===
  ///
  /// Mirrors: JS getElderlyReportData(currentUser)
  /// - email: caregiver email (lowercased)
  /// - userType: must be 'caregiver'
  /// - elderlyId (optional): if you already know the elderly email/id
  Future<ElderlyReportData> getElderlyReportData({
    required String email,
    required String userType,
    String? elderlyId,
  }) async {
    if (email.isEmpty) {
      throw Exception('No logged-in user found. Please log in again.');
    }
    if (userType != 'caregiver') {
      throw Exception('Only caregivers can view reports');
    }

    try {
      // Resolve elderlyId (email) similarly to the JS controller's logic chain
      final resolved = await _resolveElderlyId(
        caregiverEmailOrUid: email,
        elderlyIdFromParam: elderlyId,
      );

      if (resolved == null) {
        // Demo fallback (no elderly linked)
        final demoName = 'Demo Elderly';
        return ElderlyReportData(
          name: demoName,
          age: 75,
          reports: _generateReportsData(),
          alerts: _generateAlertsData(demoName),
        );
      }

      final e = await _fetchElderlyDataRtdb(resolved);
      return ElderlyReportData(
        name: e.name,
        age: e.age,
        reports: _generateReportsData(),
        alerts: _generateAlertsData(e.name),
      );
    } catch (err) {
      // Same fallback behavior as JS if elderly data issues
      final msg = err.toString();
      if (msg.contains('Elderly data not found') || msg.contains('incomplete')) {
        final demoName = 'Demo Elderly';
        return ElderlyReportData(
          name: demoName,
          age: 75,
          reports: _generateReportsData(),
          alerts: _generateAlertsData(demoName),
        );
      }
      rethrow;
    }
  }

  /// Mirrors: JS exportReportsAsPDF()
  /// Flutter Note: We can’t “screenshot DOM nodes”; instead we render a simple printable doc.
  /// Replace with a custom pdf widgets layout if you want charts embedded as images.
  Future<void> exportReportsAsPDF({required ElderlyReportData? data}) async {
    await Printing.layoutPdf(onLayout: (format) async {
      final html = '''
        <style>
          h1,h2,h3 { font-family: Arial, sans-serif; }
          .card { border:1px solid #eee; padding:10px; border-radius:8px; margin-bottom:10px; }
          .muted { color:#666; }
        </style>
        <h1 style="text-align:center">Elderly Care Reports</h1>
        <p style="text-align:center" class="muted">
          ${DateTime.now().toIso8601String()}
        </p>
        <h2>${data?.name ?? ''} (Age: ${data?.age ?? ''})</h2>

        <h3>Reports</h3>
        ${data?.reports.map((r) => '''
          <div class="card">
            <b>${r.title}</b> &mdash; <span class="muted">${r.category}</span>
            <div class="muted">Labels: ${r.labels.join(', ')}</div>
            <div class="muted">Values: ${r.values.map((v) => v.toStringAsFixed(0)).join(', ')}</div>
            <ul>
              ${r.stats.map((s) => '<li><b>${s.number}</b> ${s.label}</li>').join()}
            </ul>
          </div>
        ''').join() ?? ''}

        <h3>Recent Alerts &amp; Notifications</h3>
        ${data?.alerts.map((a) => '''
          <div class="card">
            <b>[${a.type}] ${a.title}</b> &nbsp; <span class="muted">${a.time}</span>
            <div>${a.message}</div>
          </div>
        ''').join() ?? ''}
      ''';

      // Convert the HTML to a PDF page
      final bytes = await Printing.convertHtml(format: format, html: html);
      return bytes;
    });
  }
}
