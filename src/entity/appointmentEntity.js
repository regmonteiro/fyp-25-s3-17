// appointmentEntity.js
export class AppointmentEntity {
  constructor({ id = null, title, location, date, time, elderlyId, notes = "" }) {
    this.id = id;
    this.title = title;
    this.location = location;
    this.date = date;
    this.time = time;
    this.elderlyId = elderlyId;
    this.notes = notes;
  }
}
