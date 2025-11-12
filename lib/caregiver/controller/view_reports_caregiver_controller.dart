import 'dart:math';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart' as p;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ───────── Models (simple, UI-friendly) ─────────

class ElderlySummary {
  final String id;
  final String identifier; // email or uid
  final String name;
  final int? age;
  final String email;
  final String uid;

  const ElderlySummary({
    required this.id,
    required this.identifier,
    required this.name,
    required this.age,
    required this.email,
    required this.uid,
  });
}

class ReportStat {
  final String number;
  final String label;
  const ReportStat(this.number, this.label);
}

class ChartSeries {
  final String label;
  final List<num> data;
  final Color color;
  final bool filled;
  const ChartSeries({
    required this.label,
    required this.data,
    required this.color,
    this.filled = false,
  });
}

class ReportCardData {
  final String id;
  final String category; // health | medication | activity | emergency
  final String title;
  final String icon; // emoji for simplicity
  final List<String> labels;
  final List<ChartSeries> series;
  final List<ReportStat> stats;

  const ReportCardData({
    required this.id,
    required this.category,
    required this.title,
    required this.icon,
    required this.labels,
    required this.series,
    required this.stats,
  });
}

class AlertItem {
  final String id;
  final String type; // info | warning | critical
  final String title;
  final String time; // human-friendly string ("2 hours ago")
  final String message;

  const AlertItem({
    required this.id,
    required this.type,
    required this.title,
    required this.time,
    required this.message,
  });
}

class ElderlyReportBundle {
  final ElderlySummary elderly;
  final List<ReportCardData> reports;
  final List<AlertItem> alerts;
  const ElderlyReportBundle({
    required this.elderly,
    required this.reports,
    required this.alerts,
  });
}

// ───────── Controller ─────────

class ViewReportsCaregiverController {
  const ViewReportsCaregiverController();

  // Email <-> key helpers (mirror your web code idea)
  String emailKeyFrom(String email) {
    final lower = email.trim().toLowerCase();
    final at = lower.indexOf('@');
    if (at < 0) return lower.replaceAll('.', '_');
    final local = lower.substring(0, at);
    final domain = lower.substring(at + 1).replaceAll('.', '_');
    return '$local@$domain';
  }

  // Daily seed identical idea to web
  int _getDailySeed() {
    final now = DateTime.now();
    // Pad month/day to keep the seed stable (e.g., 20250102)
    final mm = now.month.toString().padLeft(2, '0');
    final dd = now.day.toString().padLeft(2, '0');
    return int.parse('${now.year}$mm$dd');
  }

  double _seededRandom(int seed) {
    final x = sin(seed) * 10000.0;
    return x - x.floorToDouble();
  }

  int _seededRandomInt(int seed, int min, int max) {
    final r = _seededRandom(seed);
    return (r * (max - min + 1)).floor() + min;
  }

  int? _calculateAge(dynamic dobField) {
    if (dobField == null) return null;
    DateTime? dob;
    if (dobField is String) {
      dob = DateTime.tryParse(dobField);
    } else if (dobField is Timestamp) {
      dob = dobField.toDate();
    }
    if (dob == null) return null;
    final now = DateTime.now();
    var age = now.year - dob.year;
    final beforeBirthday =
        (now.month < dob.month) || (now.month == dob.month && now.day < dob.day);
    if (beforeBirthday) age--;
    return age;
  }

  /// Generate the **daily** random reports/alerts for an elderly – Flutter side
  ElderlyReportBundle generateDailyRandomBundle(ElderlySummary elderly) {
    final seed =
        _getDailySeed() + (elderly.identifier.isNotEmpty ? elderly.identifier.codeUnitAt(0) : 0);

    final systolic = _seededRandomInt(seed + 1, 110, 130);
    final diastolic = _seededRandomInt(seed + 2, 70, 85);
    final heartRate = _seededRandomInt(seed + 3, 60, 80);
    final medAdherence = _seededRandomInt(seed + 4, 80, 100);
    final missed = _seededRandomInt(seed + 5, 0, 3);
    final steps = _seededRandomInt(seed + 6, 2000, 5000);
    final sleepH =
        (_seededRandomInt(seed + 7, 6, 9) + _seededRandom(seed + 8)).toStringAsFixed(1);
    final alertsWeek = _seededRandomInt(seed + 9, 0, 2);
    final alertsMonth = _seededRandomInt(seed + 10, 0, 3);

    final reports = <ReportCardData>[
      ReportCardData(
        id: 'health-vitals',
        category: 'health',
        title: 'Health Vitals',
        icon: '💗',
        labels: const ['BP', 'HR'],
        series: [
          ChartSeries(
            label: 'Vitals',
            data: [systolic, heartRate],
            color: const Color(0xFFFF6B6B),
          )
        ],
        stats: [
          ReportStat('$systolic/$diastolic', 'Blood Pressure'),
          ReportStat('$heartRate', 'Heart Rate'),
        ],
      ),
      ReportCardData(
        id: 'medication-adherence',
        category: 'medication',
        title: 'Medication Adherence',
        icon: '💊',
        labels: const ['Adherence', 'Missed'],
        series: [
          ChartSeries(
            label: 'Adherence',
            data: [medAdherence, missed],
            color: const Color(0xFF36A2EB),
          ),
        ],
        stats: [
          ReportStat('$medAdherence%', 'Adherence'),
          ReportStat('$missed', 'Missed Doses'),
        ],
      ),
      ReportCardData(
        id: 'daily-activities',
        category: 'activity',
        title: 'Daily Activities',
        icon: '🚶',
        labels: const ['Steps', 'Sleep (h)'],
        series: [
          ChartSeries(
            label: 'Activity',
            data: [steps, double.tryParse(sleepH) ?? 0],
            color: const Color(0xFF45B7D1),
          ),
        ],
        stats: [
          ReportStat(NumberFormat.decimalPattern().format(steps), 'Steps Today'),
          ReportStat(sleepH, 'Sleep Hours'),
        ],
      ),
      ReportCardData(
        id: 'emergency-alerts',
        category: 'emergency',
        title: 'Emergency Alerts',
        icon: '🚨',
        labels: const ['This Week', 'This Month'],
        series: [
          ChartSeries(
            label: 'Alerts',
            data: [alertsWeek, alertsMonth],
            color: const Color(0xFFF093FB),
            filled: true,
          ),
        ],
        stats: [
          ReportStat('$alertsWeek', 'This Week'),
          ReportStat('$alertsMonth', 'This Month'),
        ],
      ),
    ];

    final alerts = <AlertItem>[
      AlertItem(
        id: 'med-reminder',
        type: 'warning',
        title: 'Medication Reminder',
        time: '2 hours ago',
        message: '${elderly.name} missed afternoon medication.',
      ),
      AlertItem(
        id: 'activity-update',
        type: 'info',
        title: 'Activity Update',
        time: '5 hours ago',
        message:
            '${elderly.name} walked ${NumberFormat.decimalPattern().format(steps)} steps today.',
      ),
      AlertItem(
        id: 'health-check',
        type: 'info',
        title: 'Health Check',
        time: '1 day ago',
        message: 'Blood pressure reading: $systolic/$diastolic mmHg.',
      ),
    ];

    return ElderlyReportBundle(elderly: elderly, reports: reports, alerts: alerts);
  }

  /// Fetch only the elderly linked to this caregiver (from Account/{caregiverKey}.elderlyIds)
  Future<List<ElderlySummary>> fetchLinkedElderlies(String caregiverEmail) async {
    try {
      final db = FirebaseFirestore.instance;
      final caregiverKey = emailKeyFrom(caregiverEmail);
      final caregiverDoc = await db.collection('Account').doc(caregiverKey).get();

      if (!caregiverDoc.exists) throw Exception('Caregiver not found');

      final data = caregiverDoc.data() ?? {};
      final linkedIds = List<String>.from(data['elderlyIds'] ?? []);

      if (linkedIds.isEmpty) {
        throw Exception('No elderly linked to this caregiver.');
      }

      // Fetch each elderly account by ID or email key
      final results = await Future.wait(linkedIds.map((id) async {
        // If it's an email, convert to key; otherwise assume it's a key/UID docId
        final docId = id.contains('@') ? emailKeyFrom(id) : id.toLowerCase();
        final doc = await db.collection('Account').doc(docId).get();
        if (!doc.exists) return null;

        final d = doc.data()!;
        final name = [
          (d['firstname'] ?? '').toString().trim(),
          (d['lastname'] ?? '').toString().trim()
        ].where((s) => s.isNotEmpty).join(' ');
        final display = name.isNotEmpty ? name : (d['displayName'] ?? 'elderly').toString();

        return ElderlySummary(
          id: doc.id,
          identifier: d['email']?.toString().trim().isNotEmpty == true
              ? d['email'].toString()
              : (d['uid']?.toString() ?? doc.id),
          name: display,
          age: _calculateAge(d['dob']),
          email: (d['email'] ?? '').toString(),
          uid: (d['uid'] ?? '').toString(),
        );
      }));

      return results.whereType<ElderlySummary>().toList();
    } catch (e) {
      // ignore: avoid_print
      print('Error fetching linked elderly: $e');
      rethrow;
    }
  }

  Future<void> exportReportsAsPdf(ElderlyReportBundle bundle) async {
    final doc = pw.Document();
    final dateStr = DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now());

    doc.addPage(
      pw.MultiPage(
        build: (ctx) => [
          pw.Header(
            level: 0,
            child: pw.Text(
              'Elderly Care Reports',
              style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.Paragraph(
            text:
                '${bundle.elderly.name} (Age: ${bundle.elderly.age ?? 'N/A'})\nID: ${bundle.elderly.identifier}\nGenerated: $dateStr',
          ),
          pw.SizedBox(height: 12),
          pw.Text('Reports',
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          ...bundle.reports.map(
            (r) => pw.Container(
              padding: const pw.EdgeInsets.all(8),
              margin: const pw.EdgeInsets.only(bottom: 8),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(
                  width: 0.5,
                  color: p.PdfColor.fromInt(0xFFCCCCCC), // ⬅️ use p.PdfColor
                ),
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    '${r.icon} ${r.title}',
                    style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text('Labels: ${r.labels.join(', ')}'),
                  pw.SizedBox(height: 4),
                  pw.Wrap(
                    spacing: 10,
                    children: r.series
                        .map(
                          (s) => pw.Text(
                            '${s.label}: [${s.data.map((e) => e.toString()).join(', ')}]',
                          ),
                        )
                        .toList(),
                  ),
                  pw.SizedBox(height: 6),
                  pw.Wrap(
                    spacing: 14,
                    children:
                        r.stats.map((s) => pw.Text('${s.number} — ${s.label}')).toList(),
                  ),
                ],
              ),
            ),
          ),
          if (bundle.alerts.isNotEmpty) ...[
            pw.SizedBox(height: 12),
            pw.Text(
              'Recent Alerts & Notifications',
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 6),
            ...bundle.alerts.map(
              (a) => pw.Container(
                padding: const pw.EdgeInsets.all(8),
                margin: const pw.EdgeInsets.only(bottom: 6),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(
                    width: 0.5,
                    color: p.PdfColor.fromInt(0xFFEEEEEE), // ⬅️ use p.PdfColor
                  ),
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      '${a.title}  (${a.time})',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                    pw.SizedBox(height: 3),
                    pw.Text(a.message),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => doc.save(),
    );
  }
}
