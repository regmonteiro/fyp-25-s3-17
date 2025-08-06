// src/entity/feedbackEntity.js
export class Feedback {
  constructor({ id, userId, userEmail, comment, rating, date }) {
    this.id = id;  // feedback key in Firebase
    this.userId = userId || '';
    this.userEmail = userEmail || '';
    this.comment = comment || '';
    this.rating = rating || 0;  // number rating 1-5
    this.date = date ? new Date(date) : new Date();
  }
}
