import { 
  ref, push, update, remove, onValue, off, get
} from "firebase/database";
import { database } from "../firebaseConfig";

const APPOINTMENTS_COLLECTION = "Appointments";
const ACCOUNTS_COLLECTION = "Account";

// Convert email to Firebase-safe key
export const emailToKey = (email) => {
  return email ? email.replace(/\./g, '_').toLowerCase() : '';
};

// Enhanced function to match elderly identifiers (email or UID)
const matchesElderlyIdentifier = (appointmentElderlyId, elderlyIdentifier) => {
  if (!appointmentElderlyId || !elderlyIdentifier) return false;
  
  const appointmentIdStr = String(appointmentElderlyId);
  const elderlyIdentifierStr = String(elderlyIdentifier);
  
  // Direct match
  if (appointmentIdStr === elderlyIdentifierStr) return true;
  
  // Handle array of elderly IDs
  if (Array.isArray(appointmentElderlyId)) {
    return appointmentElderlyId.some(id => 
      String(id) === elderlyIdentifierStr || 
      String(id).replace(/\./g, '_') === elderlyIdentifierStr.replace(/\./g, '_')
    );
  }
  
  // Match with underscore replacement (handle Firebase key format)
  if (appointmentIdStr.replace(/\./g, '_') === elderlyIdentifierStr.replace(/\./g, '_')) return true;
  
  // Match with dot replacement (handle email format)
  if (appointmentIdStr.replace(/_/g, '.') === elderlyIdentifierStr.replace(/_/g, '.')) return true;
  
  return false;
};

// CRUD operations
export const createAppointmentReminder = async (elderlyId, appointmentData) => {
  if (!elderlyId) throw new Error("Elderly user ID is required");
  const appointmentsRef = ref(database, APPOINTMENTS_COLLECTION);
  const newAppointmentRef = push(appointmentsRef);
  const newAppointment = {
    id: newAppointmentRef.key,
    ...appointmentData, 
    elderlyId,
    isCompleted: appointmentData.isCompleted || false
  };
  await update(newAppointmentRef, newAppointment);
  return newAppointment;
};

export const updateAppointmentInfo = async (appointmentId, updatedData) => {
  if (!appointmentId) throw new Error("Appointment ID is required");
  const appointmentRef = ref(database, `${APPOINTMENTS_COLLECTION}/${appointmentId}`);
  await update(appointmentRef, updatedData);
};

export const toggleAppointmentCompletion = async (appointmentId, isCompleted) => {
  if (!appointmentId) throw new Error("Appointment ID is required");
  const appointmentRef = ref(database, `${APPOINTMENTS_COLLECTION}/${appointmentId}`);
  await update(appointmentRef, { isCompleted });
};

export const deleteAppointmentReminder = async (appointmentId) => {
  if (!appointmentId) throw new Error("Appointment ID is required");
  const appointmentRef = ref(database, `${APPOINTMENTS_COLLECTION}/${appointmentId}`);
  await remove(appointmentRef);
};

// Subscribe to appointments for a given elderlyId - ENHANCED VERSION
export const subscribeToAppointments = (elderlyId, callback) => {
  if (!elderlyId) {
    console.error("No elderlyId provided for subscription");
    return () => {};
  }

  try {
    const appointmentsRef = ref(database, APPOINTMENTS_COLLECTION);
    
    const onDataChange = (snapshot) => {
      const data = snapshot.val() || {};
      console.log("Raw appointments data from Firebase:", data);
      
      const appointments = Object.keys(data)
        .map(key => ({ 
          id: key,
          ...data[key],
          isCompleted: data[key].isCompleted || false
        }))
        .filter(appointment => {
          const appointmentElderlyId = appointment.elderlyId;
          return matchesElderlyIdentifier(appointmentElderlyId, elderlyId);
        });
      
      console.log("Filtered appointments for elderlyId", elderlyId, ":", appointments);
      callback(appointments);
    };

    onValue(appointmentsRef, onDataChange, (error) => {
      console.error("Error in appointments snapshot:", error);
    });

    return () => {
      off(appointmentsRef, 'value', onDataChange);
    };
  } catch (error) {
    console.error("Error setting up appointments subscription:", error);
    return () => {};
  }
};

// Get elderlyId from current user - ENHANCED VERSION
export const getLinkedElderlyId = async (currentUser) => {
  try {
    const email = (localStorage.getItem("loggedInEmail") || currentUser?.email || "").toLowerCase();
    if (!email) throw new Error("No logged-in user found");

    const emailKey = emailToKey(email);
    const userRef = ref(database, `${ACCOUNTS_COLLECTION}/${emailKey}`);
    const snapshot = await get(userRef);
    
    if (!snapshot.exists()) throw new Error("User not found in Accounts collection");

    const userData = snapshot.val();
    let linkedElderly = [];

    console.log("User data found:", userData);

    if (userData.userType === "elderly") {
      // Elderly user - return their own identifier (email or UID)
      linkedElderly = [userData.uid || email];
    } else if (userData.userType === "caregiver") {
      // Caregiver user - check all possible elderly identifier fields
      
      // Check array fields first
      if (userData.elderlyIds && Array.isArray(userData.elderlyIds) && userData.elderlyIds.length > 0) {
        linkedElderly = userData.elderlyIds;
      } else if (userData.linkedElderUids && Array.isArray(userData.linkedElderUids) && userData.linkedElderUids.length > 0) {
        linkedElderly = userData.linkedElderUids;
      } else if (userData.linkedElders && Array.isArray(userData.linkedElders) && userData.linkedElders.length > 0) {
        linkedElderly = userData.linkedElders;
      } 
      // Check single fields
      else if (userData.elderlyId) {
        linkedElderly = [userData.elderlyId];
      } else if (userData.uidOfElder) {
        linkedElderly = [userData.uidOfElder];
      } else {
        throw new Error("No elderly linked to this caregiver account");
      }
    } else {
      throw new Error("Invalid user type");
    }

    if (linkedElderly.length === 0) {
      throw new Error("No elderly linked to this account");
    }

    console.log("Linked elderly identifiers:", linkedElderly);
    
    // Store the first elderly ID as primary for backward compatibility
    localStorage.setItem("linkedElderlyId", linkedElderly[0]);
    
    return linkedElderly;
  } catch (error) {
    console.error("Error getting linked elderly ID:", error);
    throw error;
  }
};

// Get elderly info for a single elderly identifier (email or UID) - ENHANCED VERSION
export const getElderlyInfo = async (elderlyIdentifier) => {
  try {
    if (!elderlyIdentifier) throw new Error("Elderly identifier is required");
    
    let elderlyRef;
    
    // Check if identifier is an email (contains @)
    if (elderlyIdentifier.includes('@')) {
      const elderlyKey = emailToKey(elderlyIdentifier);
      elderlyRef = ref(database, `${ACCOUNTS_COLLECTION}/${elderlyKey}`);
    } else {
      // Identifier is likely a UID, search through all accounts
      elderlyRef = ref(database, ACCOUNTS_COLLECTION);
    }
    
    const snapshot = await get(elderlyRef);
    
    if (!snapshot.exists()) throw new Error("Elderly user not found");
    
    let elderlyData;
    
    if (elderlyIdentifier.includes('@')) {
      // Direct lookup by email key
      elderlyData = snapshot.val();
    } else {
      // Search for UID in all accounts
      const allAccounts = snapshot.val();
      elderlyData = Object.values(allAccounts).find(account => 
        account.uid === elderlyIdentifier || 
        account.email === elderlyIdentifier
      );
      
      if (!elderlyData) {
        throw new Error("Elderly user not found with the provided identifier");
      }
    }
    
    let age = null;
    if (elderlyData.dob) {
      const birthDate = new Date(elderlyData.dob);
      const today = new Date();
      age = today.getFullYear() - birthDate.getFullYear();
      if (today.getMonth() < birthDate.getMonth() || 
          (today.getMonth() === birthDate.getMonth() && today.getDate() < birthDate.getDate())) {
        age--;
      }
    }
    
    return {
      identifier: elderlyIdentifier,
      email: elderlyData.email || '',
      uid: elderlyData.uid || '',
      firstname: elderlyData.firstname || '',
      lastname: elderlyData.lastname || '',
      dob: elderlyData.dob || '',
      phoneNum: elderlyData.phoneNum || '',
      age: age
    };
  } catch (error) {
    console.error("Error getting elderly info:", error);
    throw error;
  }
};

// Get multiple elderly info (for caregivers with multiple elderly) - ENHANCED VERSION
export const getMultipleElderlyInfo = async (elderlyIdentifiers) => {
  try {
    if (!elderlyIdentifiers || !Array.isArray(elderlyIdentifiers) || elderlyIdentifiers.length === 0) {
      throw new Error("Elderly identifiers array is required");
    }

    const elderlyInfoPromises = elderlyIdentifiers.map(elderlyId => getElderlyInfo(elderlyId));
    const elderlyInfoArray = await Promise.all(elderlyInfoPromises);
    
    return elderlyInfoArray;
  } catch (error) {
    console.error("Error getting multiple elderly info:", error);
    throw error;
  }
};

// Helper function to get all possible elderly identifiers from a caregiver account
export const getAllElderlyIdentifiersFromCaregiver = async (caregiverEmail) => {
  try {
    if (!caregiverEmail) throw new Error("Caregiver email is required");
    
    const caregiverKey = emailToKey(caregiverEmail);
    const userRef = ref(database, `${ACCOUNTS_COLLECTION}/${caregiverKey}`);
    const snapshot = await get(userRef);
    
    if (!snapshot.exists()) throw new Error("Caregiver not found");
    
    const userData = snapshot.val();
    let elderlyIdentifiers = [];

    // Check all possible fields for elderly connections
    if (userData.elderlyIds && Array.isArray(userData.elderlyIds)) {
      elderlyIdentifiers = [...elderlyIdentifiers, ...userData.elderlyIds];
    }
    if (userData.linkedElderUids && Array.isArray(userData.linkedElderUids)) {
      elderlyIdentifiers = [...elderlyIdentifiers, ...userData.linkedElderUids];
    }
    if (userData.linkedElders && Array.isArray(userData.linkedElders)) {
      elderlyIdentifiers = [...elderlyIdentifiers, ...userData.linkedElders];
    }
    if (userData.elderlyId && !elderlyIdentifiers.includes(userData.elderlyId)) {
      elderlyIdentifiers.push(userData.elderlyId);
    }
    if (userData.uidOfElder && !elderlyIdentifiers.includes(userData.uidOfElder)) {
      elderlyIdentifiers.push(userData.uidOfElder);
    }

    // Remove duplicates
    return [...new Set(elderlyIdentifiers)];
  } catch (error) {
    console.error("Error getting elderly identifiers from caregiver:", error);
    throw error;
  }
};

// Enhanced function to check if an identifier matches any elderly in a list
export const matchesAnyElderlyIdentifier = (appointmentElderlyId, elderlyIdentifiers) => {
  if (!appointmentElderlyId || !elderlyIdentifiers || !Array.isArray(elderlyIdentifiers)) {
    return false;
  }
  
  return elderlyIdentifiers.some(identifier => 
    matchesElderlyIdentifier(appointmentElderlyId, identifier)
  );
};