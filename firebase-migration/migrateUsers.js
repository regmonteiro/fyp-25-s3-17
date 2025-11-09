const admin = require("firebase-admin");
const serviceAccount = require("./serviceAccountKey.json");

// Initialize Firebase Admin
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL: "https://elderly-aiassistant-default-rtdb.asia-southeast1.firebasedatabase.app"
});

const db = admin.database();

// Fetch users from Realtime Database
async function fetchUsers() {
  const snapshot = await db.ref("Account").once("value");
  return snapshot.val();
}

// Migrate users to Firebase Authentication
async function migrateUsers() {
  const users = await fetchUsers();

  for (const key in users) {
    const user = users[key];

    try {
      // Create user in Firebase Auth
      const firebaseUser = await admin.auth().createUser({
        email: user.email,
        password: user.password, // use actual password
        displayName: `${user.firstname} ${user.lastname}`
      });

      console.log(`✅ Created user: ${user.email} (UID: ${firebaseUser.uid})`);

      // Set custom claims for userType
      if (user.userType) {
        await admin.auth().setCustomUserClaims(firebaseUser.uid, {
          userType: user.userType
        });
        console.log(`🔹 Set userType: ${user.userType} for ${user.email}`);
      }

      // Store Firebase UID in Realtime Database
      await db.ref(`Account/${key}`).update({ uid: firebaseUser.uid });

    } catch (err) {
      console.error(`❌ Error creating ${user.email}:`, err);
    }
  }

  console.log("✅ Migration complete!");
}

// Run the migration
migrateUsers();
