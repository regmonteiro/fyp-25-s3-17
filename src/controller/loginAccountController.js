import { ref, get, update, push } from "firebase/database";
import { database } from "../firebaseConfig";

function encodeEmail(email) {
  return email.replace(/[.#$/[\]]/g, '_');
}

export async function loginAccount(accountEntity) {
  const error = accountEntity.validate();
  if (error) return { success: false, error };

  try {
    const encodedEmail = encodeEmail(accountEntity.email);
    const userRef = ref(database, 'Account/' + encodedEmail);
    const snapshot = await get(userRef);

    if (!snapshot.exists()) {
      return { success: false, error: "No account found with this email." };
    }

    const userData = snapshot.val();

    if (userData.password !== accountEntity.password) {
      return { success: false, error: "Incorrect password." };
    }

    const now = new Date().toISOString();

    // ✅ Push a new login log using push() not update()
    const logRef = ref(database, `Account/${encodedEmail}/loginLogs`);
    await push(logRef, { date: now });

    // ✅ Update lastLoginDate
    await update(userRef, { lastLoginDate: now });

    // ✅ Save session to localStorage
    localStorage.setItem("isLoggedIn", "true");
    localStorage.setItem("userEmail", userData.email);
    localStorage.setItem("userType", userData.userType);
    localStorage.setItem("lastLoginDate", now);

    return {
      success: true,
      user: {
        ...userData,
        lastLoginDate: now,
      },
    };
  } catch (err) {
    console.error("Login error:", err);
    return { success: false, error: "Login failed. Try again." };
  }
}
