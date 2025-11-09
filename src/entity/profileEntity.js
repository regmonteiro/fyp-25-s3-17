export class Profile {
  constructor({ 
    uid, 
    email, 
    firstname, 
    lastname, 
    dob, 
    phoneNum, 
    userType, 
    password,
    createdAt,
    lastLoginDate,
    loginLogs,
    elderlyId,
    elderlyIds,
    status
  }) {
    this.uid = uid || "";
    this.email = email || "";
    this.firstname = firstname || "";
    this.lastname = lastname || "";
    this.dob = dob || "";
    this.phoneNum = phoneNum || "";
    this.userType = userType || "";
    this.password = password || "";
    this.createdAt = createdAt || "";
    this.lastLoginDate = lastLoginDate || "";
    this.loginLogs = loginLogs || {};
    
    // Handle both elderlyId (singular) and elderlyIds (plural)
    this.elderlyId = elderlyId || "";
    this.elderlyIds = elderlyIds || [];
    this.status = status || "";

    // Ensure elderlyIds is always an array and merge elderlyId if it exists
    this.normalizeElderlyIds();
  }

  // Normalize elderly IDs to always use elderlyIds array
  normalizeElderlyIds() {
    if (!Array.isArray(this.elderlyIds)) {
      this.elderlyIds = [];
    }
    
    // If elderlyId exists and is not already in elderlyIds, add it
    if (this.elderlyId && this.elderlyId.trim() !== "" && !this.elderlyIds.includes(this.elderlyId)) {
      this.elderlyIds.push(this.elderlyId);
    }
  }

  update(data) {
    // Only allow updating certain fields (email and userType are read-only)
    if (data.firstname !== undefined) this.firstname = data.firstname;
    if (data.lastname !== undefined) this.lastname = data.lastname;
    if (data.dob !== undefined) this.dob = data.dob;
    if (data.phoneNum !== undefined) this.phoneNum = data.phoneNum;
    if (data.password !== undefined) this.password = data.password;
    if (data.elderlyId !== undefined) this.elderlyId = data.elderlyId;
    if (data.elderlyIds !== undefined) this.elderlyIds = data.elderlyIds;
    if (data.status !== undefined) this.status = data.status;

    // Re-normalize after update
    this.normalizeElderlyIds();
  }

  getFullName() {
    return `${this.firstname} ${this.lastname}`.trim();
  }

  getFormattedCreatedDate() {
    if (!this.createdAt) return "";
    return new Date(this.createdAt).toLocaleDateString();
  }

  getFormattedLastLogin() {
    if (!this.lastLoginDate) return "";
    return new Date(this.lastLoginDate).toLocaleString();
  }

  // Get all assigned elderly IDs (primary method to use)
  getAssignedElderlyIds() {
    return this.elderlyIds || [];
  }

  // Check if caregiver has any assigned elderly
  hasAssignedElderly() {
    return this.getAssignedElderlyIds().length > 0;
  }
}