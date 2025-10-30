import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../controller/report_controller.dart';
import '../../report_models.dart';
import '../../models/user_profile.dart';

const List<Color> _pieColors = <Color>[
  Color(0xFF4ECDC4), // teal
  Color(0xFFFF6B6B), // red
  Color(0xFFFEC057), // amber
  Color(0xFF45B7D1), // blue
  Color(0xFF96C93D), // green (optional extra)
];

class ViewReportsCaregiverPage extends StatefulWidget {
  final UserProfile? userProfile;
  const ViewReportsCaregiverPage({super.key, required this.userProfile});
  @override
  State<ViewReportsCaregiverPage> createState() => _ViewReportsCaregiverPageState();
}

class _ViewReportsCaregiverPageState extends State<ViewReportsCaregiverPage> {
  late final CaregiverReportsController _controller;
  StreamSubscription<CaregiverReportsVM>? _sub;
  CaregiverReportsVM? _vm;
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _controller = CaregiverReportsController();
    _sub = _controller.streamVm().listen((vm) {
      setState(() => _vm = vm);
    }, onError: (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _switchElder(String uid) async {
    if (_vm == null) return;
    final nextVm = await _controller.switchElder(uid, _vm!.elders);
    if (mounted) setState(() => _vm = nextVm);
  }

  @override
  Widget build(BuildContext context) {
    if (_vm == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final elders = _vm!.elders;
    final bundle = _vm!.bundle;
    final filteredReports =
        bundle.reports.where((r) => _filter == 'all' || r.category == _filter).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => _switchElder(_vm!.activeElderUid),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (elders.length > 1)
                Wrap(
                  spacing: 8,
                  children: elders
                      .map((e) => ChoiceChip(
                            label: Text('${e.displayName}${e.age != null ? ' (${e.age})' : ''}'),
                            selected: e.uid == _vm!.activeElderUid,
                            onSelected: (_) => _switchElder(e.uid),
                          ))
                      .toList(),
                ),
              if (elders.length > 1) const SizedBox(height: 12),

              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        radius: 26,
                        child: Text('👵', style: TextStyle(fontSize: 24)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${bundle.elderly.displayName}${bundle.elderly.age != null ? ' (Age: ${bundle.elderly.age})' : ''}',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Updated ${DateFormat.jm().format(DateTime.now())}',
                              style: TextStyle(color: Colors.grey.shade700),
                            ),
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
                          label: Text('${cat[0].toUpperCase()}${cat.substring(1)} Reports'),
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
                  itemCount: filteredReports.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: cross,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.05,
                  ),
                  itemBuilder: (_, i) => _ReportCard(report: filteredReports[i]),
                );
              }),

              const SizedBox(height: 20),

              Text('Recent Alerts & Notifications',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),

              if (bundle.alerts.isEmpty)
                const Card(
                  child: ListTile(
                    leading: Icon(Icons.notifications_none),
                    title: Text('No recent alerts'),
                    subtitle: Text('We’ll show new items here.'),
                  ),
                )
              else
                Column(children: bundle.alerts.map((a) => _AlertTile(item: a)).toList()),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).pushNamed('/caregiver/generatecustomreport'),
        icon: const Icon(Icons.auto_awesome),
        label: const Text('Generate Custom Report'),
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({required this.report});
  final ReportCardData report;

  @override
  Widget build(BuildContext context) {
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
            Expanded(child: _ChartSwitcher(report: report)),
            const SizedBox(height: 8),
            Row(
              children: report.stats
                  .map(
                    (s) => Expanded(
                      child: Column(
                        children: [
                          Text(s.number,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 2),
                          Text(s.label, style: TextStyle(color: Colors.grey.shade700)),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChartSwitcher extends StatelessWidget {
  const _ChartSwitcher({required this.report});
  final ReportCardData report;

  @override
  Widget build(BuildContext context) {
    if (report.category == 'medication') {
      final values = report.series.first.data.map((e) => (e ?? 0).toDouble()).toList();
      final total = values.fold<double>(0, (a, b) => a + b);
      if (total <= 0) {
        return const Center(child: Text('No data for this period'));
      }
      // ✅ RETURN the pie
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

    if (report.category == 'activity') {
      final bars = report.series.first.data.asMap().entries.map((e) {
        return BarChartGroupData(
          x: e.key,
          barRods: [
            BarChartRodData(
              toY: e.value.toDouble(),
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
          barGroups: bars,
        ),
      );
    }

    final lines = report.series
        .map(
          (s) => LineChartBarData(
            spots: s.data
                .asMap()
                .entries
                .map((e) => FlSpot(e.key.toDouble(), e.value.toDouble()))
                .toList(),
            isCurved: true,
            color: s.color,
            barWidth: 3,
            belowBarData: BarAreaData(show: s.filled, color: s.color.withOpacity(0.2)),
            dotData: const FlDotData(show: false),
          ),
        )
        .toList();

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
            Text(item.timeLabel, style: TextStyle(color: Colors.grey.shade700)),
          ],
        ),
      ),
    );
  }
}
