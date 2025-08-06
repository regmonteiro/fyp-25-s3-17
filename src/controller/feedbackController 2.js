// src/controller/feedbackController.js
import { ref, get } from "firebase/database";
import { database } from "../firebaseConfig";
import { Feedback } from "../entity/feedbackEntity";

export async function fetchAllFeedbacks() {
  try {
    const feedbackRef = ref(database, "feedbacks");
    const snapshot = await get(feedbackRef);
    if (!snapshot.exists()) return [];

    const data = snapshot.val();
    // Map feedback objects with ID
    const feedbackList = Object.entries(data).map(([id, fb]) =>
      new Feedback({ id, ...fb })
    );

    // Sort descending by date (latest first)
    feedbackList.sort((a, b) => b.date - a.date);

    return feedbackList;
  } catch (error) {
    console.error("Error fetching feedbacks:", error);
    throw new Error("Unable to load feedback");
  }
}
