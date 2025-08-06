// src/entity/reportEntity.js

export class ReportEntity {
  constructor(id, email, userType, loginCount, lastActiveDate) {
    this.id = id;
    this.email = email;
    this.userType = userType;
    this.loginCount = loginCount;
    this.lastActiveDate = lastActiveDate;
  }
}
