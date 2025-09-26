import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

admin.initializeApp();
const db = admin.firestore();

export const linkUsers = functions.https.onCall(async (data, context) => {
  if (!context.auth?.uid) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "You must be logged in."
    );
  }

  const callerUid = context.auth.uid;
  const otherCode = (data?.code ?? "").toString().trim();

  if (!otherCode) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Missing code."
    );
  }

  try {
    const snap = await db
      .collection("users")
      .where("shortCode", "==", otherCode)
      .limit(1)
      .get();

    if (snap.empty) {
      throw new functions.https.HttpsError(
        "not-found",
        "No user with this code found."
      );
    }

    const otherRef = snap.docs[0].ref;
    const otherUid = otherRef.id;

    if (callerUid === otherUid) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "You cannot link yourself."
      );
    }

    const batch = db.batch();
    batch.update(
      db.collection("users").doc(callerUid),
      {
        linkedUsers: admin.firestore.FieldValue.arrayUnion(otherUid),
      }
    );
    batch.update(otherRef, {
      linkedUsers: admin.firestore.FieldValue.arrayUnion(callerUid),
    });

    await batch.commit();

    return {status: "success", message: "Link successful!"};
  } catch (err) {
    console.error("Linking error:", err);
    throw new functions.https.HttpsError(
      "internal",
      "Failed to link user"
    );
  }
});

