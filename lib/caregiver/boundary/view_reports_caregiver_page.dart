import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../controller/view_reports_caregiver_controller.dart';
import '../../assistant_chat.dart';
import 'package:firebase_auth/firebase_auth.dart';

const _pieColors = <Color>[
  Color(0xFF4ECDC4),
  Color(0xFFFF6B6B),
  Color(0xFFFEC057),
  Color(0xFF45B7D1),
  Color(0xFF96C93D),
];

class ViewReportsCaregiverPage extends StatefulWidget {
  final String caregiverEmail; // mimic localStorage user
  const ViewReportsCaregiverPage({super.key, required this.caregiverEmail});

  @override
  State<ViewReportsCaregiverPage> createState() => _ViewReportsCaregiverPageState();
}

class _ViewReportsCaregiverPageState extends State<ViewReportsCaregiverPage> {
  final _controller = const ViewReportsCaregiverController();
  StreamSubscription? _sub;
  bool _loading = true;
  String? _error;

  List<ElderlyReportBundle> _bundles = [];
  ElderlyReportBundle? _active;
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      setState(() { _loading = true; _error = null; });
      final elderlies = await _controller.fetchLinkedElderlies(widget.caregiverEmail);
      if (elderlies.isEmpty) {
        setState(() {
          _bundles = [];
          _active = null;
          _error = 'No elderly assigned to your account.';
          _loading = false;
        });
        return;
      }
      final bundles = elderlies
          .map((e) => _controller.generateDailyRandomBundle(e))
          .toList();
      setState(() {
        _bundles = bundles;
        _active = bundles.first;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _switchActive(ElderlyReportBundle b) async {
    setState(() => _active = b);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('⚠️', style: TextStyle(fontSize: 48)),
                const SizedBox(height: 12),
                const Text('Error Loading Reports',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(_error!, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                ElevatedButton(onPressed: _bootstrap, child: const Text('Try Again')),
              ],
            ),
          ),
        ),
      );
    }
    final active = _active!;
    final reports = active.reports
        .where((r) => _filter == 'all' || r.category == _filter)
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Reports')),
      body: RefreshIndicator(
        onRefresh: () async => _bootstrap(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_bundles.length > 1)
                Wrap(
                  spacing: 8,
                  children: _bundles.map((b) {
                    final sel = identical(b, active);
                    return ChoiceChip(
                      label: Text('${b.elderly.name}${b.elderly.age != null ? ' (${b.elderly.age})' : ''}'),
                      selected: sel,
                      onSelected: (_) => _switchActive(b),
                    );
                  }).toList(),
                ),
              if (_bundles.length > 1) const SizedBox(height: 12),
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const CircleAvatar(radius: 26, child: Text('👵', style: TextStyle(fontSize: 24))),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${active.elderly.name}${active.elderly.age != null ? ' (Age: ${active.elderly.age})' : ''}',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 4),
                            Text('Updated ${DateFormat.jm().format(DateTime.now())}',
                                style: TextStyle(color: Colors.grey.shade700)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: -8,
                children: ['all', 'health', 'medication', 'activity', 'emergency']
                    .map((cat) => ChoiceChip(
                          label: Text(cat == 'all'
                              ? 'All Reports'
                              : '${cat[0].toUpperCase()}${cat.substring(1)} Reports'),
                          selected: _filter == cat,
                          onSelected: (_) => setState(() => _filter = cat),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 16),
              LayoutBuilder(builder: (context, c) {
                final wide = c.maxWidth >= 900;
                final medium = c.maxWidth >= 600;
                final cross = wide ? 3 : (medium ? 2 : 1);
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: reports.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: cross,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.05,
                  ),
                  itemBuilder: (_, i) => _ReportCard(report: reports[i]),
                );
              }),
              const SizedBox(height: 20),
              Text('Recent Alerts & Notifications',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              if (active.alerts.isEmpty)
                const Card(
                  child: ListTile(
                    leading: Icon(Icons.notifications_none),
                    title: Text('No recent alerts'),
                    subtitle: Text('We’ll show new items here.'),
                  ),
                )
              else
                Column(
                  children: active.alerts.map((a) => _AlertTile(item: a)).toList(),
                ),
            ],
          ),
        ),
      ),
      floatingActionButton: Column(
  mainAxisSize: MainAxisSize.min,
  crossAxisAlignment: CrossAxisAlignment.end,
  children: [
    // ─── AI Assistant FAB ───
    FloatingActionButton(
      heroTag: 'assistant_reports_fab', // unique hero tag
      backgroundColor: Colors.deepPurple,
      onPressed: () {
        final email =
            FirebaseAuth.instance.currentUser?.email ?? 'guest@allcare.ai';
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AssistantChat(userEmail: email),
          ),
        );
      },
      child: const Icon(Icons.chat_bubble_outline, color: Colors.white),
    ),

    const SizedBox(height: 12),

    // ─── Existing Export PDF FAB ───
    FloatingActionButton.extended(
      heroTag: 'caregiverReportsFab',
      onPressed: () async => _controller.exportReportsAsPdf(active),
      icon: const Icon(Icons.picture_as_pdf),
      label: const Text('Export PDF'),
    ),
  ],
),
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({required this.report});
  final ReportCardData report;

  @override
  Widget build(BuildContext context) {
    Widget chart;
    switch (report.category) {
      case 'medication':
        chart = _Pie(values: report.series.first.data.map((e) => e.toDouble()).toList());
        break;
      case 'activity':
        chart = _Bars(labels: report.labels, values: report.series.first.data);
        break;
      case 'health':
      case 'emergency':
      default:
        chart = _Lines(report: report);
    }

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(report.title,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                ),
                Text(report.icon, style: const TextStyle(fontSize: 22)),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(child: chart),
            const SizedBox(height: 8),
            Row(
              children: report.stats
                  .map((s) => Expanded(
                        child: Column(
                          children: [
                            Text(s.number,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 16)),
                            const SizedBox(height: 2),
                            Text(s.label, style: TextStyle(color: Colors.grey.shade700)),
                          ],
                        ),
                      ))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _Pie extends StatelessWidget {
  const _Pie({required this.values});
  final List<double> values;

  @override
  Widget build(BuildContext context) {
    final total = values.fold<double>(0, (a, b) => a + b);
    if (total <= 0) return const Center(child: Text('No data for this period'));
    return PieChart(
      PieChartData(
        sectionsSpace: 2,
        centerSpaceRadius: 40,
        sections: [
          for (var i = 0; i < values.length; i++)
            PieChartSectionData(
              value: values[i],
              title: '${((values[i] / total) * 100).round()}%',
              titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              radius: 60,
              color: _pieColors[i % _pieColors.length],
            ),
        ],
      ),
    );
  }
}

class _Bars extends StatelessWidget {
  const _Bars({required this.labels, required this.values});
  final List<String> labels;
  final List<num> values;

  @override
  Widget build(BuildContext context) {
    final groups = values.asMap().entries.map((e) {
      return BarChartGroupData(
        x: e.key,
        barRods: [
          BarChartRodData(
            toY: (e.value).toDouble(),
            width: 12,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      );
    }).toList();

    return BarChart(
      BarChartData(
        gridData: FlGridData(show: true),
        titlesData: FlTitlesData(
          leftTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 36)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (v, _) {
                final i = v.toInt();
                if (i < 0 || i >= labels.length) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(labels[i], style: const TextStyle(fontSize: 10)),
                );
              },
            ),
          ),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        barGroups: groups,
      ),
    );
  }
}

class _Lines extends StatelessWidget {
  const _Lines({required this.report});
  final ReportCardData report;

  @override
  Widget build(BuildContext context) {
    final lines = report.series.map((s) {
      final spots = s.data
          .asMap()
          .entries
          .map((e) => FlSpot(e.key.toDouble(), (e.value).toDouble()))
          .toList(growable: false);

      return LineChartBarData(
        spots: spots,
        isCurved: true,
        color: s.color,
        barWidth: 3,
        belowBarData: BarAreaData(show: s.filled, color: s.color.withOpacity(0.2)),
        dotData: const FlDotData(show: false),
      );
    }).toList();
    return LineChart(
      LineChartData(
        gridData: FlGridData(show: true),
        titlesData: FlTitlesData(
          leftTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 36)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (v, _) {
                final i = v.toInt();
                if (i < 0 || i >= report.labels.length) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(report.labels[i], style: const TextStyle(fontSize: 10)),
                );
              },
            ),
          ),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        lineBarsData: lines,
      ),
    );
  }
}

class _AlertTile extends StatelessWidget {
  const _AlertTile({required this.item});
  final AlertItem item;

  @override
  Widget build(BuildContext context) {
    final color = item.type == 'critical'
        ? Colors.red.shade100
        : item.type == 'warning'
            ? Colors.orange.shade100
            : Colors.blue.shade50;
    final icon = item.type == 'critical'
        ? Icons.error
        : item.type == 'warning'
            ? Icons.warning_amber
            : Icons.info;
    return Card(
      color: color,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Icon(icon, color: Colors.black54),
        title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item.message),
            const SizedBox(height: 6),
            Text(item.time, style: TextStyle(color: Colors.grey.shade700)),
          ],
        ),
      ),
    );
  }
}
