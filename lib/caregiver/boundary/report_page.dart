import 'dart:async';
import 'package:elderly_aiassistant/models/user_profile.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../controller/report_controller.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ElderlyReportData {
  final String name;
  final int age;
  final List<ReportCardData> reports; // cards with chart + stats
  final List<AlertItem> alerts;
  ElderlyReportData({
    required this.name,
    required this.age,
    required this.reports,
    required this.alerts,
  });
}

class ReportCardData {
  final String id;
  final String title;
  /// 'health' | 'medication' | 'activity' | 'emergency'
  final String category;
  /// one of: 'line' | 'bar' | 'doughnut'
  final String chartType;
  /// X labels
  final List<String> labels;
  /// datasets as list of numbers (single-series for simplicity; extend as needed)
  final List<double> values;
  /// stats row under chart
  final List<ReportStat> stats;
  ReportCardData({
    required this.id,
    required this.title,
    required this.category,
    required this.chartType,
    required this.labels,
    required this.values,
    required this.stats,
  });
}

class ReportStat {
  final String label;
  final String number;
  ReportStat({required this.label, required this.number});
}

class AlertItem {
  final String id;
  /// 'critical' | 'warning' | 'info'
  final String type;
  final String title;
  final String message;
  final String time; // e.g. "2h ago"
  AlertItem({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.time,
  });
}

// ----- Page -----
class ViewReportsCaregiverPage extends StatefulWidget {
  final UserProfile userProfile;
  const ViewReportsCaregiverPage({super.key, required this.userProfile});

  @override
  State<ViewReportsCaregiverPage> createState() => _ViewReportsCaregiverPageState();
}

class _ViewReportsCaregiverPageState extends State<ViewReportsCaregiverPage> {
  final _controller = ViewReportsCaregiverController();

  String _filter = 'all';
  ElderlyReportData? _data;
  bool _loading = true;
  String? _error;

  Future<Map<String, String>> _currentUserForController() async {
  final auth = FirebaseAuth.instance;
  final fs = FirebaseFirestore.instance;

  // 1) Ensure logged in
  final user = auth.currentUser;
  if (user == null) {
    throw Exception('No logged-in user. Please log in again.');
  }

  // 2) Start with auth email; may be empty for some providers
  String email = (user.email ?? '').trim();

  // 3) Fetch role (and fallback email) from Firestore: users/{uid}
  final doc = await fs.collection('users').doc(user.uid).get();
  if (!doc.exists) {
    throw Exception('User profile not found in Firestore.');
  }
  final data = doc.data() as Map<String, dynamic>;

  // Normalize role to lowercase (e.g., "caregiver")
  final roleRaw = (data['role'] as String?) ?? '';
  final userType = roleRaw.trim().toLowerCase();
  if (userType.isEmpty) {
    throw Exception('User role is missing in profile.');
  }

  // If auth email missing, fall back to profile email
  if (email.isEmpty) {
    email = ((data['email'] as String?) ?? '').trim();
  }
  if (email.isEmpty) {
    throw Exception('No email associated with this account.');
  }

  return {
    'email': email.toLowerCase(),
    'userType': userType, // expected: 'caregiver'
  };
}

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final user = await _currentUserForController();
      final email = (user['email'] ?? '').toLowerCase();
      final userType = user['userType'];
      if (email.isEmpty || userType != 'caregiver') {
        throw Exception('Only caregivers can view reports. Please log in again.');
      }
      final result = await _controller.getElderlyReportData(
        email: email,
        userType: userType!,
      );
      setState(() {
        _data = result;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  // ---- Export to PDF (simple capture of current screen) ----
  Future<void> _exportPDF() async {
    try {
      await _controller.exportReportsAsPDF(data: _data);
      // If your controller handles PDF generation. Alternatively:
      // await Printing.layoutPdf(onLayout: (format) async => await _buildPdfBytes());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Export started (PDF)')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }
  }

  void _goGenerateCustomReport() {
    // Use your own route name
    Navigator.of(context).pushNamed('/caregiver/generatecustomreport');
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: Text('Loading reports...')),
      );
    }
    if (_error != null) {
      return Scaffold(
        body: Center(
          child: _ErrorBox(
            title: 'Error Loading Reports',
            message: _error!,
            onRetry: _fetch,
            onLogin: () => Navigator.of(context).pushReplacementNamed('/login'),
          ),
        ),
      );
    }

    final data = _data!;
    final todayFmt = DateFormat('MMM d, yyyy • h:mm a').format(DateTime.now());

    final filteredReports = data.reports.where((r) {
      return _filter == 'all' || r.category == _filter;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [Color(0xFF667EEA), Color(0xFF764BA2)]),
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF5F7FA), Color(0xFFC3CFE2)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            _HeaderCard(
              name: data.name,
              age: data.age,
              lastUpdated: todayFmt,
            ),
            const SizedBox(height: 12),
            _FiltersRow(
              active: _filter,
              onChange: (f) => setState(() => _filter = f),
            ),
            const SizedBox(height: 8),
            if (filteredReports.isEmpty)
              const _NoReports()
            else
              _ReportsGrid(reports: filteredReports),
            const SizedBox(height: 16),
            _AlertsSection(alerts: data.alerts),
            const SizedBox(height: 120),
          ],
        ),
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Export button (round)
          FloatingActionButton(
            heroTag: 'export_pdf',
            onPressed: _exportPDF,
            backgroundColor: const Color(0xFF4CAF50),
            child: const Icon(Icons.download),
          ),
          const SizedBox(height: 16),
          // Generate custom report (pill button)
          FloatingActionButton.extended(
            heroTag: 'generate_custom',
            onPressed: _goGenerateCustomReport,
            backgroundColor: const Color(0xFF2196F3),
            icon: const Icon(Icons.auto_awesome),
            label: const Text('Generate Custom Report'),
          ),
        ],
      ),
    );
  }
}

// ---------- UI Pieces ----------

class _HeaderCard extends StatelessWidget {
  final String name;
  final int age;
  final String lastUpdated;
  const _HeaderCard({
    required this.name,
    required this.age,
    required this.lastUpdated,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [Color(0xFF667EEA), Color(0xFF764BA2)]),
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                // ignore: deprecated_member_use
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
          
                // ignore: deprecated_member_use
                border: Border.all(color: Colors.white.withOpacity(0.3)),
              ),
              alignment: Alignment.center,
              child: const Text('👵', style: TextStyle(fontSize: 24)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: DefaultTextStyle(
                style: const TextStyle(color: Colors.white),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$name (Age: $age)',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
                    const SizedBox(height: 4),
                    Text('Last updated: $lastUpdated',
                        style: const TextStyle(color: Colors.white70)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FiltersRow extends StatelessWidget {
  final String active;
  final ValueChanged<String> onChange;
  const _FiltersRow({required this.active, required this.onChange});

  static const cats = ['all', 'health', 'medication', 'activity', 'emergency'];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: [
        for (final c in cats)
          ChoiceChip(
            label: Text('${c[0].toUpperCase()}${c.substring(1)} Reports'),
            selected: active == c,
            onSelected: (_) => onChange(c),
          ),
      ],
    );
  }
}

class _ReportsGrid extends StatelessWidget {
  final List<ReportCardData> reports;
  const _ReportsGrid({required this.reports});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final cross = width >= 1200 ? 2 : width >= 800 ? 2 : 1;
    return GridView.builder(
      itemCount: reports.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: cross,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.1,
      ),
      itemBuilder: (_, i) => _ReportCard(report: reports[i]),
    );
  }
}

class _ReportCard extends StatelessWidget {
  final ReportCardData report;
  const _ReportCard({required this.report});

  Color _iconColor() {
    switch (report.category) {
      case 'health':
        return const Color(0xFFFF6B6B);
      case 'medication':
        return const Color(0xFF4ECDC4);
      case 'activity':
        return const Color(0xFF45B7D1);
      case 'emergency':
        return const Color(0xFFF093FB);
      default:
        return const Color(0xFF667EEA);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = _iconColor();

    return Card(
      elevation: 10,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0x11000000)),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(report.title,
                    style:
                        const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF2C3E50))),
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(8),
                    // ignore: deprecated_member_use
                    gradient: LinearGradient(colors: [accent, accent.withOpacity(0.8)]),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.insert_chart, color: Colors.white, size: 18),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // chart
            SizedBox(
              height: 220,
              child: _ChartView(
                type: report.chartType,
                labels: report.labels,
                values: report.values,
                accent: accent,
              ),
            ),
            const SizedBox(height: 12),
            // stats row
            Row(
              children: [
                for (final s in report.stats)
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.only(right: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F9FA),
                        borderRadius: BorderRadius.circular(10),
                        border: const Border(left: BorderSide(color: Color(0xFF667EEA), width: 3)),
                      ),
                      child: Column(
                        children: [
                          Text(s.number,
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50))),
                          const SizedBox(height: 4),
                          Text(s.label, style: const TextStyle(fontSize: 12, color: Colors.black54)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ChartView extends StatelessWidget {
  final String type; // 'line' | 'bar' | 'doughnut'
  final List<String> labels;
  final List<double> values;
  final Color accent;
  const _ChartView({
    required this.type,
    required this.labels,
    required this.values,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    switch (type) {
      case 'line':
        return LineChart(LineChartData(
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, _) {
                final i = v.toInt();
                return i >= 0 && i < labels.length
                    ? Transform.translate(
                        offset: const Offset(0, 8),
                        child: Text(labels[i], style: const TextStyle(fontSize: 10)))
                    : const SizedBox.shrink();
              }),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: true, reservedSize: 32),
            ),
          ),
          gridData: FlGridData(show: true),
          lineBarsData: [
            LineChartBarData(
              isCurved: true,
              barWidth: 3,
              color: accent,
              dotData: const FlDotData(show: false),
              spots: [
                for (int i = 0; i < values.length; i++) FlSpot(i.toDouble(), values[i]),
              ],
            ),
          ],
        ));
      case 'bar':
        return BarChart(BarChartData(
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, _) {
                final i = v.toInt();
                return i >= 0 && i < labels.length
                    ? Transform.translate(
                        offset: const Offset(0, 8),
                        child: Text(labels[i], style: const TextStyle(fontSize: 10)))
                    : const SizedBox.shrink();
              }),
            ),
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 32)),
          ),
          gridData: FlGridData(show: true),
          barGroups: [
            for (int i = 0; i < values.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [BarChartRodData(toY: values[i], color: accent, borderRadius: BorderRadius.circular(4))],
              ),
          ],
        ));
      case 'doughnut':
      default:
        final total = values.fold<double>(0, (a, b) => a + b);
        final sections = <PieChartSectionData>[];
        for (int i = 0; i < values.length; i++) {
          final v = values[i];
          final color = HSLColor.fromAHSL(1, (i * 50) % 360.0, 0.55, 0.55).toColor();
          sections.add(PieChartSectionData(
            value: v,
            color: color,
            title: total > 0 ? '${((v / total) * 100).toStringAsFixed(0)}%' : '',
            radius: 70,
          ));
        }
        return PieChart(PieChartData(
          sectionsSpace: 2,
          centerSpaceRadius: 50, // donut hole
          sections: sections,
        ));
    }
  }
}

class _AlertsSection extends StatelessWidget {
  final List<AlertItem> alerts;
  const _AlertsSection({required this.alerts});

  Color _border(String type) {
    switch (type) {
      case 'critical':
        return const Color(0xFFE74C3C);
      case 'warning':
        return const Color(0xFFF39C12);
      case 'info':
      default:
        return const Color(0xFF3498DB);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 10),
          child: Text('Recent Alerts & Notifications',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF2C3E50))),
        ),
        for (final a in alerts)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(left: BorderSide(color: _border(a.type), width: 5)),
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 3))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text(a.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text(a.time, style: const TextStyle(fontSize: 12, color: Colors.black54)),
                ]),
                const SizedBox(height: 6),
                Text(a.message),
              ],
            ),
          ),
      ],
    );
  }
}

class _NoReports extends StatelessWidget {
  const _NoReports();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      alignment: Alignment.center,
      child: const Text('No reports found for this filter.', style: TextStyle(color: Colors.black54)),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback onRetry;
  final VoidCallback onLogin;
  const _ErrorBox({
    required this.title,
    required this.message,
    required this.onRetry,
    required this.onLogin,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(message, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(onPressed: onRetry, child: const Text('Try Again')),
                const SizedBox(width: 12),
                OutlinedButton(onPressed: onLogin, child: const Text('Go to Login')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
