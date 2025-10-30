import 'package:cloud_firestore/cloud_firestore.dart';

class GeneratedReport {
  final String reportId;
  final int totalDataPoints;
  final ReportSummary summary;
  final List<MetricData> rawData; // The actual metrics data points

  GeneratedReport({
    required this.reportId,
    required this.totalDataPoints,
    required this.summary,
    required this.rawData,
  });

  factory GeneratedReport.fromMap(Map<String, dynamic> map) {
    return GeneratedReport(
      reportId: map['reportId'] as String,
      totalDataPoints: map['totalDataPoints'] as int,
      summary: ReportSummary.fromMap(map['summary'] as Map<String, dynamic>),
      // Map the list of raw data points
      rawData: (map['rawData'] as List)
          .map((item) => MetricData.fromMap(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

class ReportSummary {
  final double avgCompliance;
  final int alertsGenerated;
  final int trendsIdentified;

  ReportSummary({
    required this.avgCompliance,
    required this.alertsGenerated,
    required this.trendsIdentified,
  });

  factory ReportSummary.fromMap(Map<String, dynamic> map) {
    return ReportSummary(
      // Ensure the value is treated as a double if it's not already
      avgCompliance: (map['avgCompliance'] as num).toDouble(),
      alertsGenerated: map['alertsGenerated'] as int,
      trendsIdentified: map['trendsIdentified'] as int,
    );
  }
}

// Example structure for a single metric data point (Raw Data)
class MetricData {
  final Timestamp timestamp;
  final String metricName;
  final num value; // Use num for flexibility (int or double)
  final String patientId;

  MetricData({
    required this.timestamp,
    required this.metricName,
    required this.value,
    required this.patientId,
  });

  factory MetricData.fromMap(Map<String, dynamic> map) {
    return MetricData(
      // Assume the timestamp comes back as a Firestore Timestamp
      timestamp: map['timestamp'] as Timestamp, 
      metricName: map['metricName'] as String,
      value: map['value'] as num,
      patientId: map['patientId'] as String,
    );
  }
}