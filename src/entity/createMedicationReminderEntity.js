export class MedicationReminder {
  constructor({
    elderlyId,
    medicationName,
    reminderTime,
    date,
    repeatCount = 1,
    isCompleted = false,
    completedAt = null,
    dosage = '',
    quantity = 1,
    intakeTime = null,
    notes = '',
    createdAt = new Date().toISOString()
  }) {
    this.elderlyId = elderlyId;
    this.medicationName = medicationName;
    this.reminderTime = reminderTime;
    this.date = date;
    this.repeatCount = repeatCount;
    this.isCompleted = isCompleted;
    this.completedAt = completedAt;
    this.dosage = dosage;
    this.quantity = quantity;
    this.intakeTime = intakeTime;
    this.notes = notes;
    this.createdAt = createdAt;
  }

  isValid() {
    return (
      this.elderlyId &&
      this.medicationName &&
      this.reminderTime &&
      this.date &&
      this.repeatCount > 0
    );
  }

  markAsCompleted(notes = '') {
    this.isCompleted = true;
    this.completedAt = new Date().toISOString();
    this.intakeTime = new Date().toISOString();
    this.notes = notes;
  }

  markAsIncomplete() {
    this.isCompleted = false;
    this.completedAt = null;
    this.intakeTime = null;
    this.notes = '';
  }

  recordIntake(notes = '') {
    this.markAsCompleted(notes);
  }
}