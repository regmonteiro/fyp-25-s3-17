import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../controller/view_reports_caregiver_controller.dart';

class CustomReportsGeneratorPage extends StatefulWidget {
  final String caregiverEmail;
  const CustomReportsGeneratorPage({super.key, required this.caregiverEmail});

  @override
  State<CustomReportsGeneratorPage> createState() => _CustomReportsGeneratorPageState();
}

class _CustomReportsGeneratorPageState extends State<CustomReportsGeneratorPage> {
  final _ctrl = const ViewReportsCaregiverController();

  String _selectedReportType = '';
  String _selectedChartType = 'line';
  DateTime? _start;
  DateTime? _end;
  final _selectedMetrics = <String>[];
  final _selectedPatientIds = <String>[];

  bool _loadingPatients = true;
  List<ElderlySummary> _patients = [];
  Map<String, dynamic>? _previewData;
  Map<String, dynamic>? _generatedReport; // mock structure

  @override
  void initState() {
    super.initState();
    _loadPatients();
  }

  Future<void> _loadPatients() async {
    setState(() => _loadingPatients = true);
    final list = await _ctrl.fetchLinkedElderlies(widget.caregiverEmail);
    setState(() {
      _patients = list;
      _loadingPatients = false;
    });
  }

  Future<void> _pickDate(bool isStart) async {
    final init = isStart ? (_start ?? DateTime.now().subtract(const Duration(days: 7))) : (_end ?? DateTime.now());
    final res = await showDatePicker(
      context: context,
      initialDate: init,
      firstDate: DateTime(2018),
      lastDate: DateTime(2100),
    );
    if (res != null) {
      setState(() {
        if (isStart) {
          _start = res;
        } else {
          _end = res;
        }
      });
    }
  }

  // simple daily-random preview (mimic web)
  void _generatePreview() {
    if (_selectedReportType.isEmpty || _start == null || _end == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select report type and date range')),
      );
      return;
    }
    if (_selectedPatientIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one elderly')),
      );
      return;
    }
    // build tiny preview from first selected patient using the controller’s random bundle
    final first = _patients.firstWhere((p) => _selectedPatientIds.contains(p.id));
    final bundle = _ctrl.generateDailyRandomBundle(first);

    final preview = <String, dynamic>{
      'bloodPressure': bundle.reports.firstWhere((r) => r.category == 'health').stats.first.number,
      'heartRate': bundle.reports.firstWhere((r) => r.category == 'health').stats.last.number,
      'medAdherence': bundle.reports.firstWhere((r) => r.category == 'medication').stats.first.number,
      'dataPoints': 200 + first.name.length, // cute touch
      'bundle': bundle,
    };

    setState(() => _previewData = preview);
  }

  Future<void> _generateReport() async {
    if (_previewData == null) return;
    setState(() => _generatedReport = {
      'reportId': 'RPT-${DateTime.now().millisecondsSinceEpoch}',
      'generatedAt': DateTime.now().toIso8601String(),
      'dateRange': {
        'start': _start?.toIso8601String().split('T').first,
        'end': _end?.toIso8601String().split('T').first,
      },
      'reportType': _selectedReportType,
      'metrics': _selectedMetrics.toList(),
      'patients': _selectedPatientIds.toList(),
      'previewData': _previewData,
      'summary': {
        'avgCompliance': 82,
        'alertsGenerated': 4,
        'trendsIdentified': 5,
        'recommendations': 8,
      }
    });
  }

  Future<void> _downloadReport() async {
    if (_generatedReport == null) return;
    // Render a PDF using the existing export from controller for the first patient bundle
    final bundle = _previewData?['bundle'] as ElderlyReportBundle?;
    if (bundle != null) {
      await _ctrl.exportReportsAsPdf(bundle);
    }
  }

  Widget _chartPreview() {
    if (_previewData == null) return const SizedBox.shrink();
    final bundle = _previewData!['bundle'] as ElderlyReportBundle;
    // create a small line/bar/pie from bundle depending on _selectedChartType
    switch (_selectedChartType) {
      case 'bar':
        final r = bundle.reports.firstWhere((e) => e.category == 'activity');
        final groups = r.series.first.data.asMap().entries.map((e) {
          return BarChartGroupData(
            x: e.key,
            barRods: [BarChartRodData(toY: e.value.toDouble(), width: 12)],
          );
        }).toList();
        return SizedBox(
          height: 220,
          child: BarChart(BarChartData(
            barGroups: groups,
            titlesData: FlTitlesData(show: true),
            gridData: FlGridData(show: true),
          )),
        );

      case 'pie':
        final r = bundle.reports.firstWhere((e) => e.category == 'medication');
        final vals = r.series.first.data.map((e) => e.toDouble()).toList();
        final total = vals.fold<double>(0, (a, b) => a + b);
        if (total <= 0) return const Text('No data');
        return SizedBox(
          height: 220,
          child: PieChart(PieChartData(
            sections: [
              for (var i = 0; i < vals.length; i++)
                PieChartSectionData(
                  value: vals[i],
                  title: '${((vals[i] / total) * 100).round()}%',
                  radius: 50,
                ),
            ],
          )),
        );

      case 'line':
      default:
        final r = bundle.reports.firstWhere((e) => e.category == 'health');
        final lines = r.series.map((s) {
          final spots = s.data
              .asMap()
              .entries
              .map((e) => FlSpot(e.key.toDouble(), e.value.toDouble()))
              .toList();
          return LineChartBarData(
            spots: spots,
            isCurved: true,
            color: s.color,
            barWidth: 3,
            dotData: const FlDotData(show: false),
          );
        }).toList();
        return SizedBox(
          height: 220,
          child: LineChart(LineChartData(
            lineBarsData: lines,
            titlesData: FlTitlesData(show: true),
            gridData: FlGridData(show: true),
          )),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateText = (_start != null && _end != null)
        ? '${_start!.toIso8601String().split('T').first} → ${_end!.toIso8601String().split('T').first}'
        : 'Pick a range';
    final metricDefs = const [
      ['blood-pressure', 'Blood Pressure'],
      ['heart-rate', 'Heart Rate'],
      ['temperature', 'Temperature'],
      ['blood-sugar', 'Blood Sugar'],
      ['weight', 'Weight'],
      ['sleep-quality', 'Sleep Quality'],
      ['mood', 'Mood'],
      ['pain-level', 'Pain Level'],
      ['medication-adherence', 'Medication Adherence'],
      ['exercise', 'Physical Activity'],
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Generate Custom Reports')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SizedBox(height: 8),
          Text('Report Type', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              'health-logs','medication','activity','appointments','comprehensive'
            ].map((id) {
              final name = {
                'health-logs':'Health Logs Report',
                'medication':'Medication Adherence',
                'activity':'Daily Activities',
                'appointments':'Appointments & Care',
                'comprehensive':'Comprehensive Report',
              }[id]!;
              return ChoiceChip(
                label: Text(name),
                selected: _selectedReportType == id,
                onSelected: (_) => setState(() => _selectedReportType = id),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          Text('Date Range', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Row(
            children: [
              OutlinedButton(
                onPressed: () => _pickDate(true),
                child: Text(_start == null ? 'Start' : _start!.toIso8601String().split('T').first),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () => _pickDate(false),
                child: Text(_end == null ? 'End' : _end!.toIso8601String().split('T').first),
              ),
              const SizedBox(width: 12),
              Text(dateText),
            ],
          ),
          const SizedBox(height: 16),
          Text('Elderly', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (_loadingPatients)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_patients.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text('No elderly found.'),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: -8,
              children: _patients.map((p) {
                final sel = _selectedPatientIds.contains(p.id);
                return FilterChip(
                  label: Text('${p.name} (${p.age ?? 'N/A'})'),
                  selected: sel,
                  onSelected: (_) {
                    setState(() {
                      if (sel) {
                        _selectedPatientIds.remove(p.id);
                      } else {
                        _selectedPatientIds.add(p.id);
                      }
                    });
                  },
                );
              }).toList(),
            ),
          const SizedBox(height: 16),
          Text('Health Metrics', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: metricDefs.map((m) {
              final sel = _selectedMetrics.contains(m[0]);
              return FilterChip(
                label: Text(m[1]),
                selected: sel,
                onSelected: (_) {
                  setState(() {
                    if (sel) {
                      _selectedMetrics.remove(m[0]);
                    } else {
                      _selectedMetrics.add(m[0]);
                    }
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          Text('Chart Type', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: ['line','bar','pie'].map((t) {
              return ChoiceChip(
                label: Text(t.toUpperCase()),
                selected: _selectedChartType == t,
                onSelected: (_) => setState(() => _selectedChartType = t),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: _generatePreview,
                icon: const Icon(Icons.remove_red_eye),
                label: const Text('Generate Preview'),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _previewData == null ? null : _generateReport,
                icon: const Icon(Icons.description),
                label: const Text('Generate Report'),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _generatedReport == null ? null : _downloadReport,
                icon: const Icon(Icons.download),
                label: const Text('Download PDF'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_previewData != null) ...[
            const Divider(height: 32),
            Text('Report Preview', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            _chartPreview(),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: DefaultTextStyle(
                  style: const TextStyle(fontSize: 14, color: Colors.black87),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _kv('Blood Pressure Avg', _previewData!['bloodPressure'] ?? '—'),
                      _kv('Heart Rate Avg', _previewData!['heartRate'] ?? '—'),
                      _kv('Med Adherence', _previewData!['medAdherence'] ?? '—'),
                      _kv('Data Points', '${_previewData!['dataPoints'] ?? '—'}'),
                    ],
                  ),
                ),
              ),
            ),
          ],
          if (_generatedReport != null) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: DefaultTextStyle(
                  style: const TextStyle(fontSize: 14, color: Colors.black87),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Report Generated', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      _kv('Report ID', _generatedReport!['reportId']),
                      _kv('Generated At', _generatedReport!['generatedAt']),
                      _kv('Compliance Avg', '${_generatedReport!['summary']['avgCompliance']}%'),
                      _kv('Alerts', '${_generatedReport!['summary']['alertsGenerated']}'),
                      _kv('Trends', '${_generatedReport!['summary']['trendsIdentified']}'),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ]),
      ),
    );
  }

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [Text('$k:'), Text(v, style: const TextStyle(fontWeight: FontWeight.w600))],
        ),
      );
}
