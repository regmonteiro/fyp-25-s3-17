import { ref, get, update, remove } from "firebase/database";
import { database } from "../firebaseConfig";
import { Profile } from "../entity/profileEntity";
import bcrypt from "bcryptjs";
import { getAuth, deleteUser } from "firebase/auth";

function encodeEmail(email) {
  return email.replace(/[.#$/[\]]/g, "_");
}

export class ProfileController {
  constructor(email) {
    this.email = email;
    this.profile = null;
    this.errorMessage = "";
  }

  // Fetch profile from Realtime DB
  async fetchProfile() {
    try {
      const encodedEmail = encodeEmail(this.email);
      const snapshot = await get(ref(database, `Account/${encodedEmail}`));

      if (snapshot.exists()) {
        const data = snapshot.val();
        // Do not expose password
        data.password = "";
        this.profile = new Profile({
          uid: encodedEmail,
          email: this.email,
          ...data,
        });
      } else {
        this.errorMessage = "Profile not found.";
      }
    } catch (error) {
      this.errorMessage = "Failed to load profile.";
      console.error(error);
    }
  }

  // Update profile
  async updateProfile(data) {
    if (!this.profile) return false;
    try {
      this.profile.update(data);

      const encodedEmail = encodeEmail(this.email);
      const updateData = {};

      if (this.profile.firstname) updateData.firstname = this.profile.firstname;
      if (this.profile.lastname) updateData.lastname = this.profile.lastname;
      if (this.profile.dob) updateData.dob = this.profile.dob;
      if (this.profile.phoneNum) updateData.phoneNum = this.profile.phoneNum;
      if (this.profile.password) {
        // Hash password before saving
        const salt = await bcrypt.genSalt(10);
        const hashed = await bcrypt.hash(this.profile.password, salt);
        updateData.password = hashed;
      }

      // Handle elderly IDs for caregivers
      if (this.profile.userType === "caregiver") {
        updateData.elderlyIds = this.profile.getAssignedElderlyIds();
      }

      if (this.profile.status) updateData.status = this.profile.status;
      updateData.lastLoginDate = new Date().toISOString();

      await update(ref(database, `Account/${encodedEmail}`), updateData);
      return true;
    } catch (error) {
      this.errorMessage = "Failed to update profile: " + error.message;
      console.error(error);
      return false;
    }
  }

  // Delete profile from DB and Auth
  async deleteProfile() {
    try {
      const encodedEmail = encodeEmail(this.email);
      await remove(ref(database, `Account/${encodedEmail}`));

      const auth = getAuth();
      const user = auth.currentUser;
      if (user && user.email === this.email) {
        await deleteUser(user);
      }

      return true;
    } catch (error) {
      this.errorMessage = "Failed to delete profile: " + error.message;
      console.error(error);
      return false;
    }
  }

  // Get last 10 login logs
  getLoginLogsArray() {
    if (!this.profile || !this.profile.loginLogs) return [];

    return Object.entries(this.profile.loginLogs)
      .map(([key, log]) => ({
        id: key,
        date: new Date(log.date).toLocaleString(),
      }))
      .sort((a, b) => new Date(b.date) - new Date(a.date))
      .slice(0, 10);
  }

  // Get assigned elderly IDs
  getAssignedElderlyIds() {
    if (!this.profile) return [];
    return this.profile.getAssignedElderlyIds();
  }

  hasAssignedElderly() {
    if (!this.profile) return false;
    return this.profile.hasAssignedElderly();
  }

  // ✅ Fetch elderly names & emails for caregiver’s assigned elders
  async getAssignedElderlyProfiles() {
    if (!this.profile) return [];

    const elderlyIds = this.profile.getAssignedElderlyIds?.() || [];
    if (elderlyIds.length === 0) return [];

    try {
      const elderlyProfiles = [];
      for (const uid of elderlyIds) {
        const snapshot = await get(ref(database, `Account/${uid}`));
        if (snapshot.exists()) {
          const data = snapshot.val();
          elderlyProfiles.push({
            uid,
            firstname: data.firstname || "Unknown",
            lastname: data.lastname || "",
            email: data.email || "",
          });
        }
      }
      return elderlyProfiles;
    } catch (error) {
      console.error("Error fetching elderly profiles:", error);
      return [];
    }
  }
}
