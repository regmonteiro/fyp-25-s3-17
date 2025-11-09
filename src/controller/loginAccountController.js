import { getAuth, signInWithEmailAndPassword, createUserWithEmailAndPassword } from "firebase/auth";
import { ref, get, set, push, update } from "firebase/database";
import { collection, query, where, getDocs } from "firebase/firestore";
import { database, firestore } from "../firebaseConfig";
import bcrypt from "bcryptjs";

const auth = getAuth();

function encodeEmail(email) {
  return email.replace(/[.#$/[\]]/g, "_");
}

export async function loginAccount(accountEntity) {
  const encodedEmail = encodeEmail(accountEntity.email);
  const rtdbRef = ref(database, `Account/${encodedEmail}`);
  const usersRef = ref(database, "users"); // Fixed: Reference to users root

  try {
    // --- Firebase Auth login ---
    const userCredential = await signInWithEmailAndPassword(auth, accountEntity.email, accountEntity.password);
    const user = userCredential.user;

    // --- Realtime Database check ---
    let snapshot = await get(rtdbRef);
    let userData;
    if (!snapshot.exists()) {
      // Create minimal RTDB entry
      userData = {
        uid: user.uid,
        email: accountEntity.email,
        firstName: accountEntity.firstName || "",
        lastName: accountEntity.lastName || "",
        userType: "unknown",
        status: "active",
        createdAt: new Date().toISOString(),
      };
      await set(rtdbRef, userData);
    } else {
      userData = snapshot.val();
      if (!userData.uid) await update(rtdbRef, { uid: user.uid });
      if (!userData.userType) {
        userData.userType = "unknown";
        await update(rtdbRef, { userType: "unknown" });
      }
    }

    if (userData.status?.toLowerCase() === "deactivated") {
      return { success: false, error: "Account deactivated", user: userData };
    }

    const now = new Date().toISOString();
    await push(ref(database, `Account/${encodedEmail}/loginLogs`), { date: now });
    await update(rtdbRef, { lastLoginDate: now });

    // Store session info
    localStorage.setItem("isLoggedIn", "true");
    localStorage.setItem("uid", userData.uid);
    localStorage.setItem("userEmail", userData.email);
    localStorage.setItem("firstName", userData.firstName || userData.firstname || "");
    localStorage.setItem("lastName", userData.lastName || userData.lastname || "");
    localStorage.setItem("lastLoginDate", now);
    localStorage.setItem("userType", userData.userType || userData.role || "unknown");

    return {
      success: true,
      user: {
        uid: userData.uid,
        email: userData.email,
        name: `${userData.firstName || userData.firstname || ''} ${userData.lastName || userData.lastname || ''}`.trim() || 'User',
        firstName: userData.firstName || userData.firstname,
        lastName: userData.lastName || userData.lastname,
        userType: userData.userType || userData.role || "unknown",
        status: userData.status,
        lastLoginDate: now,
      },
    };
  } catch (authError) {
    console.log("Firebase Auth failed, checking RTDB and Firestore...", authError);

    // --- Realtime Database Account fallback ---
    try {
      const snapshot = await get(rtdbRef);
      if (snapshot.exists()) {
        const userData = snapshot.val();
        if (!userData.password) return { success: false, error: "No password set for this account" };

        const passwordMatch = await bcrypt.compare(accountEntity.password, userData.password);
        if (!passwordMatch) return { success: false, error: "Invalid password" };
        if (userData.status?.toLowerCase() === "deactivated") return { success: false, error: "Account deactivated", user: userData };

        // Create Firebase Auth account if missing
        if (!userData.uid) {
          try {
            const firebaseUser = await createUserWithEmailAndPassword(auth, accountEntity.email, accountEntity.password);
            await update(rtdbRef, { uid: firebaseUser.user.uid });
            userData.uid = firebaseUser.user.uid;
          } catch (_) {
            console.log("Firebase Auth account exists or creation failed, continuing...");
          }
        }

        const now = new Date().toISOString();
        await push(ref(database, `Account/${encodedEmail}/loginLogs`), { date: now });
        await update(rtdbRef, { lastLoginDate: now });

        localStorage.setItem("isLoggedIn", "true");
        localStorage.setItem("uid", userData.uid);
        localStorage.setItem("userEmail", userData.email);
        localStorage.setItem("firstName", userData.firstName || userData.firstname || "");
        localStorage.setItem("lastName", userData.lastName || userData.lastname || "");
        localStorage.setItem("lastLoginDate", now);
        localStorage.setItem("userType", userData.userType || userData.role || "unknown");

        return {
          success: true,
          user: {
            uid: userData.uid,
            email: userData.email,
            name: `${userData.firstName || userData.firstname || ''} ${userData.lastName || userData.lastname || ''}`.trim() || 'User',
            firstName: userData.firstName || userData.firstname,
            lastName: userData.lastName || userData.lastname,
            userType: userData.userType || userData.role || "unknown",
            status: userData.status,
            lastLoginDate: now,
          },
        };
      }
    } catch (rtdbError) {
      console.error("RTDB Account check failed:", rtdbError);
    }

    // --- Users node fallback inside Realtime Database ---
try {
  const usersNodeRef = ref(database, "users");
  const usersSnapshot = await get(usersNodeRef);

  if (usersSnapshot.exists()) {
    const usersData = usersSnapshot.val();

    let userMatch = null;
    let userKey = null;

    // Search user by email
    for (const [key, data] of Object.entries(usersData)) {
      if (data.email?.toLowerCase() === accountEntity.email.toLowerCase()) {
        userMatch = data;
        userKey = key;
        break;
      }
    }

    if (userMatch) {
      if (!userMatch.password) return { success: false, error: "No password set for this account" };

      const match = await bcrypt.compare(accountEntity.password, userMatch.password);
      if (!match) return { success: false, error: "Invalid password" };

      if (userMatch.status?.toLowerCase() === "deactivated") {
        return { success: false, error: "Account deactivated", user: userMatch };
      }

      const now = new Date().toISOString();

      await push(ref(database, `users/${userKey}/loginLogs`), { date: now });
      await update(ref(database, `users/${userKey}`), { lastLoginDate: now });

      localStorage.setItem("isLoggedIn", "true");
      localStorage.setItem("uid", userMatch.uid || userKey);
      localStorage.setItem("userEmail", userMatch.email);
      localStorage.setItem("firstName", userMatch.firstName || userMatch.firstname || "");
      localStorage.setItem("lastName", userMatch.lastName || userMatch.lastname || "");
      localStorage.setItem("lastLoginDate", now);
      localStorage.setItem("userType", userMatch.userType || userMatch.role || "unknown");

      return {
        success: true,
        user: {
          uid: userMatch.uid || userKey,
          email: userMatch.email,
          name: `${userMatch.firstName || userMatch.firstname || ''} ${userMatch.lastName || userMatch.lastname || ''}`.trim() || 'User',
          firstName: userMatch.firstName || userMatch.firstname,
          lastName: userMatch.lastName || userMatch.lastname,
          userType: userMatch.userType || userMatch.role || "unknown",
          status: userMatch.status,
          lastLoginDate: now,
        },
      };
    }
  }
} catch (usersError) {
  console.error("Users node check failed:", usersError);
}

    // --- Firestore fallback ---
    try {
      const usersRef = collection(firestore, "users");
      const q = query(usersRef, where("email", "==", accountEntity.email));
      const querySnapshot = await getDocs(q);

      if (!querySnapshot.empty) {
        const doc = querySnapshot.docs[0];
        const fsUser = doc.data();

        if (!fsUser.password) return { success: false, error: "No password set for this account" };

        const passwordMatch = await bcrypt.compare(accountEntity.password, fsUser.password);
        if (!passwordMatch) return { success: false, error: "Invalid password" };
        if (fsUser.status?.toLowerCase() === "deactivated") return { success: false, error: "Account deactivated", user: fsUser };

        localStorage.setItem("isLoggedIn", "true");
        localStorage.setItem("uid", fsUser.uid || doc.id);
        localStorage.setItem("userEmail", fsUser.email);
        localStorage.setItem("firstName", fsUser.firstName || fsUser.firstname || "");
        localStorage.setItem("lastName", fsUser.lastName || fsUser.lastname || "");
        localStorage.setItem("lastLoginDate", new Date().toISOString());
        localStorage.setItem("userType", fsUser.userType || fsUser.role || "unknown");

        return {
          success: true,
          user: {
            uid: fsUser.uid || doc.id,
            email: fsUser.email,
            name: `${fsUser.firstName || fsUser.firstname || ''} ${fsUser.lastName || fsUser.lastname || ''}`.trim() || 'User',
            firstName: fsUser.firstName || fsUser.firstname,
            lastName: fsUser.lastName || fsUser.lastname,
            userType: fsUser.userType || fsUser.role || "unknown",
            status: fsUser.status,
            lastLoginDate: new Date().toISOString(),
          },
        };
      }
    } catch (firestoreError) {
      console.error("Firestore check failed:", firestoreError);
    }

    return { success: false, error: "Authentication failed. Please check your credentials." };
  }
}

/**
 * Update password
 */
export async function updatePassword(email, newPassword) {
  try {
    if (!email || !newPassword) return { success: false, error: "Email and password are required" };
    if (newPassword.length < 6) return { success: false, error: "Password must be at least 6 characters" };

    const encodedEmail = encodeEmail(email);
    const userRef = ref(database, `Account/${encodedEmail}`);
    const snapshot = await get(userRef);
    if (!snapshot.exists()) return { success: false, error: "Account not found." };

    const userData = snapshot.val();
    if (userData.status?.toLowerCase() === "deactivated") {
      return { success: false, error: "Your account is deactivated. Please contact the admin team at allCareITsupport@gmail.com" };
    }

    const hashedPassword = await bcrypt.hash(newPassword, 10);
    await update(userRef, { password: hashedPassword, lastPasswordUpdate: new Date().toISOString() });

    return { success: true };
  } catch (err) {
    console.error("🔥 Password update error:", err);
    return { success: false, error: "Failed to update password. Please try again." };
  }
}