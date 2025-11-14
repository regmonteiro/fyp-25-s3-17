// migrateAll.js
import { database, firestore } from "./firebaseConfig";
import { ref as rtdbRef, get, onValue } from "firebase/database";
import { doc, setDoc } from "firebase/firestore";

// Migrate all top-level nodes (collections) from RTDB to Firestore
export async function migrateRTDBtoFirestore() {
  try {
    const snapshot = await get(rtdbRef(database, "/")); // root of your RTDB
    const allData = snapshot.val();

    if (!allData) {
      console.log("No data found in Realtime Database!");
      return;
    }

    for (const collectionName in allData) {
      const collectionData = allData[collectionName];

      // Each top-level key becomes a Firestore collection
      for (const docId in collectionData) {
        await setDoc(doc(firestore, collectionName, docId), collectionData[docId]);
      }
      console.log(`Collection '${collectionName}' migrated successfully!`);
    }

    console.log("All collections migrated successfully!");
  } catch (error) {
    console.error("Error migrating data:", error);
  }
}

// Real-time sync for all top-level nodes
export function syncRTDBtoFirestore() {
  onValue(rtdbRef(database, "/"), async (snapshot) => {
    const allData = snapshot.val();
    if (!allData) return;

    for (const collectionName in allData) {
      const collectionData = allData[collectionName];

      for (const docId in collectionData) {
        await setDoc(doc(firestore, collectionName, docId), collectionData[docId]);
      }
    }

    console.log("Realtime sync of all collections completed!");
  });
}
