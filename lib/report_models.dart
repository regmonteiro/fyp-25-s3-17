import 'package:flutter/material.dart';

class ElderlySummary {
  final String uid;
  final String displayName;
  final int? age;
  ElderlySummary({required this.uid, required this.displayName, required this.age});
}

class ReportStat {
  final String number;
  final String label;
  ReportStat(this.number, this.label);
}

class ChartSeries {
  final String label;
  final List<num> data;
  final Color color;
  final bool filled;
  ChartSeries({
    required this.label,
    required this.data,
    required this.color,
    this.filled = false,
  });
}

class ReportCardData {
  final int id;
  final String category; // 'health' | 'medication' | 'activity' | 'emergency'
  final String title;
  final String icon; // emoji
  final List<String> labels; // x-axis labels
  final List<ChartSeries> series;
  final List<ReportStat> stats;
  ReportCardData({
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
  final String type; // 'critical' | 'warning' | 'info'
  final String title;
  final String timeLabel;
  final String message;
  AlertItem({
    required this.id,
    required this.type,
    required this.title,
    required this.timeLabel,
    required this.message,
  });
}

class ReportBundle {
  final ElderlySummary elderly;
  final List<ReportCardData> reports;
  final List<AlertItem> alerts;
  ReportBundle({
    required this.elderly,
    required this.reports,
    required this.alerts,
  });
}

class CaregiverReportsVM {
  final List<ElderlySummary> elders;
  final String activeElderUid;
  final ReportBundle bundle;
  CaregiverReportsVM({
    required this.elders,
    required this.activeElderUid,
    required this.bundle,
  });
}
