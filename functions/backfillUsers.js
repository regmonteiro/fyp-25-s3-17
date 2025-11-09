const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json'); // adjust path

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL: "https://elderly-aiassistant-default-rtdb.asia-southeast1.firebasedatabase.app"
});

const db = admin.firestore();
const rtdb = admin.database();

// Convert Firestore Timestamps to ISO strings recursively
function serializeData(obj) {
  if (obj === null || obj === undefined) return obj;
  if (obj.toDate && typeof obj.toDate === "function") return obj.toDate().toISOString();
  if (Array.isArray(obj)) return obj.map(serializeData);
  if (typeof obj === "object") {
    return Object.fromEntries(Object.entries(obj).map(([k, v]) => [k, serializeData(v)]));
  }
  return obj;
}

// Encode Firestore document ID / email for Realtime DB
function encodeKey(key) {
  return key.replace(/[.#$/[\]]/g, "_");
}

// Recursive function to copy Firestore collection or document
async function syncCollection(path = "", parentRtdbRef = rtdb.ref()) {
  const collectionRef = path ? db.collection(path) : db; // top-level
  let collections;

  if (path) {
    collections = [collectionRef];
  } else {
    collections = await db.listCollections(); // top-level collections
  }

  for (const col of collections) {
    const colName = col.id;
    console.log(`Syncing collection: ${colName}`);
    const snapshot = await col.get();

    for (const doc of snapshot.docs) {
      const data = serializeData(doc.data());
      const docKey = encodeKey(doc.id);
      const rtdbDocRef = parentRtdbRef.child(colName).child(docKey);

      await rtdbDocRef.set(data);
      console.log(`  ✅ Synced doc: ${colName}/${docKey}`);

      // Check for subcollections recursively
      const subCollections = await doc.ref.listCollections();
      for (const subCol of subCollections) {
        const subPath = `${col.path}/${doc.id}/${subCol.id}`;
        await syncCollection(subPath, rtdbDocRef);
      }
    }
  }
}

// Start syncing all top-level collections
(async () => {
  try {
    console.log("Starting full Firestore → Realtime DB sync...");
    await syncCollection();
    console.log("🎉 Full database sync complete!");
    process.exit(0);
  } catch (err) {
    console.error("❌ Sync failed:", err);
    process.exit(1);
  }
})();
