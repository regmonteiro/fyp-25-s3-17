// src/controller/viewActivitiesController.js
import { ref, get, set, remove, push, update } from "firebase/database";
import { database } from "../firebaseConfig";

// Entity function for activity data validation
export function activityEntity(rawData) {
  const { title, summary, category, difficulty, duration, image, description, requiresAuth, tags } = rawData;

  return {
    title: title?.trim() || "",
    summary: summary?.trim() || "",
    category: category?.trim() || "",
    difficulty: difficulty?.trim() || "",
    duration: duration?.trim() || "",
    image: image || "",
    description: description?.trim() || "",
    requiresAuth: !!requiresAuth,
    tags: tags || [],
  };
}

// Separate validation function
export function validateActivity(activityData) {
  const { title, summary } = activityData;
  
  if (!title || !title.trim()) return "Title is required.";
  if (!summary || !summary.trim()) return "Summary is required.";
  return null;
}

// Fetch all activities
export async function fetchAllActivities() {
  try {
    const activitiesRef = ref(database, "Activities");
    const snapshot = await get(activitiesRef);

    if (!snapshot.exists()) {
      return { success: false, error: "No activities found." };
    }

    let data = snapshot.val();
    console.log("Fetched Activities data:", data);

    // Handle both data structures
    if (data.Activities) {
      data = data.Activities;
    }

    const activitiesArray = Object.entries(data).map(([id, rawActivity]) => {
      const activity = activityEntity(rawActivity);
      const validationError = validateActivity(activity);
      if (validationError) {
        console.warn(`Activity ${id} validation failed: ${validationError}`);
      }
      return { id, ...activity };
    });

    return {
      success: true,
      data: activitiesArray,
    };
  } catch (err) {
    console.error("Error fetching activities:", err);
    return {
      success: false,
      error: err.message || "Failed to load activities.",
    };
  }
}

// Create new activity
export async function createActivity(activityData) {
  try {
    const validationError = validateActivity(activityData);
    
    if (validationError) {
      return { success: false, error: validationError };
    }

    const activity = activityEntity(activityData);
    const activitiesRef = ref(database, "Activities");
    const newActivityRef = push(activitiesRef);
    
    await set(newActivityRef, activity);
    
    return {
      success: true,
      data: { id: newActivityRef.key, ...activity },
      message: "Activity created successfully!"
    };
  } catch (err) {
    console.error("Error creating activity:", err);
    return {
      success: false,
      error: err.message || "Failed to create activity.",
    };
  }
}

// Update existing activity
export async function updateActivity(activityId, activityData) {
  try {
    const validationError = validateActivity(activityData);
    
    if (validationError) {
      return { success: false, error: validationError };
    }

    const activity = activityEntity(activityData);
    const activityRef = ref(database, `Activities/${activityId}`);
    
    await update(activityRef, activity);
    
    return {
      success: true,
      data: { id: activityId, ...activity },
      message: "Activity updated successfully!"
    };
  } catch (err) {
    console.error("Error updating activity:", err);
    return {
      success: false,
      error: err.message || "Failed to update activity.",
    };
  }
}

// Delete activity
export async function deleteActivity(activityId) {
  try {
    const activityRef = ref(database, `Activities/${activityId}`);
    
    await remove(activityRef);
    
    return {
      success: true,
      message: "Activity deleted successfully!"
    };
  } catch (err) {
    console.error("Error deleting activity:", err);
    return {
      success: false,
      error: err.message || "Failed to delete activity.",
    };
  }
}

// Enhanced register function
export async function registerForActivity(activityId, userEmail, selectedDate, selectedTime) {
  try {
    console.log("🚀 Starting registration process:", { 
      activityId, 
      userEmail, 
      selectedDate, 
      selectedTime 
    });

    // Enhanced validation using email
    if (!userEmail || userEmail === "null" || userEmail === "undefined" || userEmail === "") {
      console.error("❌ Invalid userEmail:", userEmail);
      return { success: false, error: "User not authenticated. Please log in again." };
    }

    if (!selectedDate || !selectedTime) {
      return { success: false, error: "Please select a date and time." };
    }

    // Check if activity exists
    const activityRef = ref(database, `Activities/${activityId}`);
    const activitySnapshot = await get(activityRef);
    
    if (!activitySnapshot.exists()) {
      return { success: false, error: "Activity not found." };
    }

    const activityData = activitySnapshot.val();
    console.log("📋 Activity found:", activityData.title);

    // Check if user is already registered for this activity using email
    const existingRegistration = await checkExistingRegistration(activityId, userEmail);
    if (existingRegistration) {
      return { success: false, error: "You are already registered for this activity." };
    }

    const registrationRef = ref(database, `Activities/${activityId}/registrations`);
    
    const registrationData = {
      registeredEmail: userEmail,
      date: selectedDate,
      time: selectedTime,
      timestamp: new Date().toISOString(),
      status: "confirmed",
      activityTitle: activityData.title // Store activity title for easy reference
    };

    console.log("💾 Creating registration:", registrationData);
    
    const newRegistrationRef = await push(registrationRef, registrationData);
    
    console.log("✅ Registration created successfully with ID:", newRegistrationRef.key);
    
    return {
      success: true,
      message: `Successfully registered for "${activityData.title}" on ${selectedDate} at ${selectedTime}.`
    };
  } catch (err) {
    console.error("❌ Error registering for activity:", err);
    return {
      success: false,
      error: err.message || "Failed to register for activity.",
    };
  }
}

// Enhanced checkExistingRegistration function
async function checkExistingRegistration(activityId, userEmail) {
  try {
    const registrationsRef = ref(database, `Activities/${activityId}/registrations`);
    const snapshot = await get(registrationsRef);
    
    if (!snapshot.exists()) {
      console.log("📭 No existing registrations found");
      return false;
    }

    const registrations = snapshot.val();
    console.log("📋 Checking existing registrations:", Object.values(registrations));
    
    // Check both field names for compatibility
    const isAlreadyRegistered = Object.values(registrations).some(reg => 
      reg.registeredEmail === userEmail || reg.userEmail === userEmail
    );
    
    console.log("🔍 User already registered:", isAlreadyRegistered);
    return isAlreadyRegistered;
  } catch (err) {
    console.error("Error checking registration:", err);
    return false;
  }
}

// Fetch user registrations
export async function getUserRegistrations(userEmail) {
  try {
    console.log("🔍 Fetching registrations for user:", userEmail);
    
    const activitiesRef = ref(database, "Activities");
    const snapshot = await get(activitiesRef);

    if (!snapshot.exists()) {
      console.log("📭 No activities found in database");
      return { success: true, data: [] };
    }

    const activitiesData = snapshot.val();
    const userRegistrations = [];

    console.log("📋 Total activities found:", Object.keys(activitiesData).length);

    // Check each activity for user's registrations
    for (const [activityId, activityData] of Object.entries(activitiesData)) {
      console.log(`🔍 Checking activity: ${activityId}`);
      
      // Check if this activity has registrations
      if (activityData.registrations && typeof activityData.registrations === 'object') {
        console.log(`📋 Found registrations object for activity ${activityId}`);
        
        // Convert registrations object to array and filter by user email
        const registrations = Object.entries(activityData.registrations)
          .filter(([regId, regData]) => {
            const emailMatch = regData.registeredEmail === userEmail;
            console.log(`📧 Checking registration ${regId}:`, {
              registeredEmail: regData.registeredEmail,
              targetEmail: userEmail,
              matches: emailMatch
            });
            return emailMatch;
          })
          .map(([regId, regData]) => {
            console.log(`✅ Found matching registration: ${regId}`);
            return {
              registrationId: regId,
              activityId: activityId,
              activityTitle: activityData.title || "Unknown Activity",
              activityImage: activityData.image || "",
              date: regData.date,
              time: regData.time,
              timestamp: regData.timestamp,
              status: regData.status || "confirmed"
            };
          });

        console.log(`✅ Found ${registrations.length} registrations for activity ${activityId}`);
        userRegistrations.push(...registrations);
      } else {
        console.log(`📭 No registrations found for activity ${activityId}`);
      }
    }

    console.log("🎯 Final user registrations count:", userRegistrations.length);
    console.log("📦 Registrations data:", userRegistrations);
    
    return {
      success: true,
      data: userRegistrations
    };
  } catch (err) {
    console.error("❌ Error fetching user registrations:", err);
    return {
      success: false,
      error: err.message || "Failed to load your registrations.",
    };
  }
}

// Cancel registration
export async function cancelRegistration(activityId, registrationId) {
  try {
    const registrationRef = ref(database, `Activities/${activityId}/registrations/${registrationId}`);
    await remove(registrationRef);
    
    return {
      success: true,
      message: "Registration cancelled successfully."
    };
  } catch (err) {
    console.error("Error cancelling registration:", err);
    return {
      success: false,
      error: err.message || "Failed to cancel registration.",
    };
  }
}