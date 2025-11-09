const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json'); // path to your key

// Initialize Firebase Admin
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL: "https://elderly-aiassistant-default-rtdb.asia-southeast1.firebasedatabase.app"
});

const rtdb = admin.database();
const firestore = admin.firestore();

// Ignore undefined properties automatically
firestore.settings({ ignoreUndefinedProperties: true });

// Serialize data: remove undefined, handle dates and nested objects
function serializeData(obj) {
  if (obj === null || obj === undefined) return null;
  
  // Firestore Timestamp conversion
  if (obj.toDate && typeof obj.toDate === 'function') {
    return obj.toDate().toISOString();
  }

  // Array: recursively serialize and remove undefined entries
  if (Array.isArray(obj)) {
    return obj.map(serializeData).filter(v => v !== undefined);
  }

  // Object: recursively serialize and remove undefined fields
  if (typeof obj === 'object') {
    return Object.fromEntries(
      Object.entries(obj)
        .map(([k, v]) => [k, serializeData(v)])
        .filter(([_, v]) => v !== undefined) // remove undefined fields
    );
  }

  // Primitive values
  return obj;
}

// Main sync function
async function syncRTDBtoFirestore() {
  try {
    const rootSnapshot = await rtdb.ref('/').once('value');
    const allNodes = rootSnapshot.val();

    if (!allNodes) {
      console.log('No data found in RTDB.');
      return;
    }

    for (const [nodeName, nodeData] of Object.entries(allNodes)) {
      if (!nodeData) continue; // skip empty nodes

      const collectionRef = firestore.collection(nodeName);
      console.log(`Syncing node: ${nodeName}`);

      for (const [docId, data] of Object.entries(nodeData)) {
        const cleanData = serializeData(data);
        await collectionRef.doc(docId).set(cleanData);
        console.log(`  ✅ Mirrored ${nodeName}/${docId}`);
      }
    }

    console.log('🎉 Backfill of all nodes complete!');
    process.exit(0);
  } catch (error) {
    console.error('❌ Error during backfill:', error);
    process.exit(1);
  }
}

// Run the sync
syncRTDBtoFirestore();
