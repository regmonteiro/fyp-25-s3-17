// src/controller/viewServicesController.js
import { ref, get } from "firebase/database";
import { database } from "../firebaseConfig";
import { serviceEntity } from "../entity/viewServiceEntity";

export async function fetchAllServices() {
  try {
    const servicesRef = ref(database, "Services");
    const snapshot = await get(servicesRef);

    if (!snapshot.exists()) {
      return { success: false, error: "No services found." };
    }

    let data = snapshot.val();  // Use 'let' here

    console.log("Fetched Services data:", data);

    if (data.Services) {
      data = data.Services;  // Reassign safely
    }

    const servicesArray = Object.entries(data).map(([id, rawService]) => {
      const service = serviceEntity(rawService);
      const validationError = service.validate();
      if (validationError) {
        throw new Error(`Service ${id} validation failed: ${validationError}`);
      }
      return { id, ...service };
    });

    return {
      success: true,
      data: servicesArray,
    };
  } catch (err) {
    console.error("Error fetching services:", err);
    return {
      success: false,
      error: err.message || "Failed to load services.",
    };
  }
}
