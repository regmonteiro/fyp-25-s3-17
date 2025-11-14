// createEventReminderEntity.js

export class EventReminder {
  constructor({ title, startTime, duration, createdAt }) {
    this.title = title.trim();
    this.startTime = startTime; // string, ISO or datetime-local format
    this.duration = Number(duration); // in minutes
    this.createdAt = createdAt || new Date().toISOString();
  }

  isValid() {
    if (!this.title) return false;
    if (!this.startTime) return false;
    if (!this.duration || isNaN(this.duration) || this.duration <= 0) return false;
    return true;
  }
}