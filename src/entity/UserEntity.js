// backend/UserEntity.js

// A simple UserEntity class for clarity (optional)

class UserEntity {
  constructor(data) {
    this.firstname = data.firstname || '';
    this.lastname = data.lastname || '';
    this.email = data.email || '';
    this.userType = data.userType || 'unknown';
    this.phoneNum = data.phoneNum || '';
    this.dob = data.dob || '';
    this.createdAt = data.createdAt || '';
    this.lastLoginDate = data.lastLoginDate || '';
    this.status = data.status || 'Active'; // Active or Deactivated
  }
}

module.exports = UserEntity;
