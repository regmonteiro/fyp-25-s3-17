import { ref, set, get } from "firebase/database";
import { database } from "../firebaseConfig";

// Encode email as Firebase key
function encodeEmail(email) {
  return email.replace(/[.#$/[\]]/g, '_');
}

export async function createAccount(accountEntity) {
  const error = accountEntity.validate();
  if (error) return { success: false, error };

  try {
    // If caregiver, verify elderly email exists
    if (accountEntity.userType === 'caregiver') {
      const elderlyEncodedEmail = encodeEmail(accountEntity.elderlyId);
      const elderlyRef = ref(database, 'Account/' + elderlyEncodedEmail);
      const elderlySnapshot = await get(elderlyRef);
      if (!elderlySnapshot.exists()) {
        return { success: false, error: "Elderly email not found in the system." };
      }
    }

    const encodedEmail = encodeEmail(accountEntity.email);
    const userRef = ref(database, 'Account/' + encodedEmail);

    // Check if account already exists
    const snapshot = await get(userRef);
    if (snapshot.exists()) {
      return { success: false, error: "This email is already registered." };
    }

    // Save account with all info including userType and elderlyId
    await set(userRef, {
      firstname: accountEntity.firstname,
      lastname: accountEntity.lastname,
      email: accountEntity.email,
      dob: accountEntity.dob,
      phoneNum: accountEntity.phoneNum,
      password: accountEntity.password, // Note: hash passwords in production!
      userType: accountEntity.userType,
      elderlyId: accountEntity.elderlyId || null,
      createdAt: new Date().toISOString(),
    });

    return { success: true };
  } catch (err) {
    console.error("Error saving to Firebase:", err);
    return { success: false, error: "Failed to create account. Please try again." };
  }
}
