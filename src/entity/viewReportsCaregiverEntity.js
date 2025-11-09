// entity/viewReportsCaregiverEntity.js
export class ElderlyReportEntity {
  constructor(id, name, age, reports, alerts) {
    this.id = id;
    this.name = name;
    this.age = age;
    this.reports = reports;
    this.alerts = alerts;
  }

  static fromJson(json) {
    return new ElderlyReportEntity(
      json.id,
      json.name,
      json.age,
      json.reports || [],
      json.alerts || []
    );
  }
}

export class ReportEntity {
  constructor(id, category, title, icon, iconClass, chartData, stats) {
    this.id = id;
    this.category = category;
    this.title = title;
    this.icon = icon;
    this.iconClass = iconClass;
    this.chartData = chartData;
    this.stats = stats;
  }
}

export class AlertEntity {
  constructor(id, type, title, time, message) {
    this.id = id;
    this.type = type;
    this.title = title;
    this.time = time;
    this.message = message;
  }
}