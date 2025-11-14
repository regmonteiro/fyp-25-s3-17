import { 
  ref, push, update, remove, onValue, off, 
  get, set, query, orderByChild, equalTo 
} from "firebase/database";
import { database } from "../firebaseConfig";
import { careRoutineTemplateEntity } from "../entity/careRoutineTemplateEntity";

const CARE_ROUTINE_TEMPLATES_COLLECTION = "careRoutineTemplateEntity";
const ASSIGNED_ROUTINES_COLLECTION = "AssignedRoutines";
const ACCOUNTS_COLLECTION = "Account";

// Convert email to Firebase-safe key
export const emailToKey = (email) => {
  return email ? email.replace(/\./g, '_').toLowerCase() : '';
};

// Get current user email
export const getCurrentUserEmail = () => {
  return (localStorage.getItem("loggedInEmail") || "").toLowerCase();
};

// Get current user type
export const getCurrentUserType = async () => {
  const email = getCurrentUserEmail();
  if (!email) throw new Error("No logged-in user found");

  const emailKey = emailToKey(email);
  const userRef = ref(database, `${ACCOUNTS_COLLECTION}/${emailKey}`);
  const snapshot = await get(userRef);
  
  if (!snapshot.exists()) throw new Error("User not found in Accounts collection");
  
  const userData = snapshot.val();
  return userData.userType || 'elderly'; // Default to elderly if not specified
};

// Enhanced function to fetch elderly data using identifier (email or UID)
const fetchElderlyData = async (elderlyIdentifier) => {
  try {
    let elderlyRef;
    
    // Check if identifier is an email (contains @)
    if (elderlyIdentifier.includes('@')) {
      const key = emailToKey(elderlyIdentifier);
      elderlyRef = ref(database, `Account/${key}`);
    } else {
      // Identifier is likely a UID, search through all accounts
      elderlyRef = ref(database, 'Account');
    }
    
    const snapshot = await get(elderlyRef);
    
    if (!snapshot.exists()) {
      console.error(`Elderly not found in Firebase with identifier: ${elderlyIdentifier}`);
      throw new Error('Elderly data not found in database');
    }

    let elderly;
    
    if (elderlyIdentifier.includes('@')) {
      // Direct lookup by email key
      elderly = snapshot.val();
    } else {
      // Search for UID in all accounts
      const allAccounts = snapshot.val();
      elderly = Object.values(allAccounts).find(account => 
        account.uid === elderlyIdentifier || 
        account.email === elderlyIdentifier
      );
      
      if (!elderly) {
        throw new Error('Elderly user not found with the provided identifier');
      }
    }
    
    const dob = new Date(elderly.dob);
    const today = new Date();
    let age = today.getFullYear() - dob.getFullYear();
    const monthDiff = today.getMonth() - dob.getMonth();
    if (monthDiff < 0 || (monthDiff === 0 && today.getDate() < dob.getDate())) age--;

    return {
      id: elderlyIdentifier.includes('@') ? emailToKey(elderlyIdentifier) : elderlyIdentifier,
      identifier: elderlyIdentifier,
      name: `${elderly.firstname || ''} ${elderly.lastname || ''}`.trim() || 'Unknown Elderly',
      age: age || 'Unknown',
      email: elderly.email || elderlyIdentifier,
      uid: elderly.uid || elderlyIdentifier,
    };
  } catch (error) {
    console.error('Error fetching elderly data:', error);
    throw new Error(`Failed to fetch elderly data: ${error.message}`);
  }
};

// Get all elderly identifiers from caregiver's data (supports multiple field names)
const getAllElderlyIdentifiersFromCaregiver = (caregiverData) => {
  const elderlyIdentifiers = [];
  
  // Check all possible field names for elderly connections
  const possibleFields = [
    'elderlyIds',        // Array of emails/UIDs
    'elderlyId',         // Single email/UID
  ];
  
  possibleFields.forEach(field => {
    if (caregiverData[field]) {
      if (Array.isArray(caregiverData[field])) {
        // Handle array fields
        caregiverData[field].forEach(id => {
          if (id && !elderlyIdentifiers.includes(id)) {
            elderlyIdentifiers.push(id);
          }
        });
      } else if (typeof caregiverData[field] === 'string' && caregiverData[field].trim()) {
        // Handle single string fields
        if (!elderlyIdentifiers.includes(caregiverData[field])) {
          elderlyIdentifiers.push(caregiverData[field]);
        }
      }
    }
  });
  
  console.log('Found elderly identifiers:', elderlyIdentifiers);
  return elderlyIdentifiers;
};

// Fetch caregiver data from database
const fetchCaregiverData = async (caregiverEmail) => {
  try {
    const key = emailToKey(caregiverEmail);
    const snapshot = await get(ref(database, `Account/${key}`));
    
    if (!snapshot.exists()) {
      throw new Error('Caregiver data not found in database');
    }
    
    return snapshot.val();
  } catch (error) {
    console.error('Error fetching caregiver data:', error);
    throw new Error(`Failed to fetch caregiver data: ${error.message}`);
  }
};

// Get linked elderly ID for caregiver or self for elderly
export const getLinkedElderlyId = async () => {
  const email = getCurrentUserEmail();
  if (!email) throw new Error("No logged-in user found");

  const emailKey = emailToKey(email);
  const userRef = ref(database, `${ACCOUNTS_COLLECTION}/${emailKey}`);
  const snapshot = await get(userRef);
  
  if (!snapshot.exists()) throw new Error("User not found in Accounts collection");

  const userData = snapshot.val();
  
  if (userData.userType === "elderly") {
    // Elderly users use their own UID
    return userData.uid || emailKey;
  } else if (userData.userType === "caregiver") {
    // Get all elderly identifiers and use the first one
    const elderlyIdentifiers = getAllElderlyIdentifiersFromCaregiver(userData);
    
    if (elderlyIdentifiers.length > 0) {
      return elderlyIdentifiers[0];
    } else {
      throw new Error("No elderly linked to this caregiver account");
    }
  } else {
    throw new Error("User type not supported for routine management");
  }
};

// Get all elderly users linked to a caregiver, or self for elderly
export const getLinkedElderlyUsers = async () => {
  const email = getCurrentUserEmail();
  if (!email) throw new Error("No logged-in user found");

  const emailKey = emailToKey(email);
  const userRef = ref(database, `${ACCOUNTS_COLLECTION}/${emailKey}`);
  const snapshot = await get(userRef);
  
  if (!snapshot.exists()) throw new Error("User not found in Accounts collection");

  const userData = snapshot.val();
  const linkedUsers = [];

  if (userData.userType === "caregiver") {
    // Get all elderly identifiers from caregiver data
    const elderlyIdentifiers = getAllElderlyIdentifiersFromCaregiver(userData);
    
    console.log('Processing elderly identifiers:', elderlyIdentifiers);
    
    // Fetch data for each elderly identifier
    for (const elderlyIdentifier of elderlyIdentifiers) {
      try {
        const elderlyData = await fetchElderlyData(elderlyIdentifier);
        linkedUsers.push({
          id: elderlyData.uid || elderlyData.id,
          uid: elderlyData.uid,
          email: elderlyData.email,
          name: elderlyData.name,
          age: elderlyData.age,
          relationship: "Linked Elderly"
        });
      } catch (error) {
        console.error(`Error fetching data for elderly ${elderlyIdentifier}:`, error);
        // Continue with next elderly even if one fails
      }
    }
  } else if (userData.userType === "elderly") {
    // If current user is elderly, they can create routines for themselves
    linkedUsers.push({
      id: userData.uid || emailKey,
      uid: userData.uid,
      email: email,
      name: `${userData.firstname || ''} ${userData.lastname || ''}`.trim() || email,
      age: calculateAge(userData.dob),
      relationship: "Self"
    });
  }

  console.log('Final linked users:', linkedUsers);
  return linkedUsers;
};

// Calculate age from date of birth
const calculateAge = (dob) => {
  if (!dob) return 'Unknown';
  
  try {
    const birthDate = new Date(dob);
    const today = new Date();
    let age = today.getFullYear() - birthDate.getFullYear();
    const monthDiff = today.getMonth() - birthDate.getMonth();
    
    if (monthDiff < 0 || (monthDiff === 0 && today.getDate() < birthDate.getDate())) {
      age--;
    }
    
    return age;
  } catch (error) {
    return 'Unknown';
  }
};

// CRUD operations for care routine templates
export const createCareRoutineTemplate = async (templateData) => {
  const email = getCurrentUserEmail();
  if (!email) throw new Error("No logged-in user found");

  const templateEntity = new careRoutineTemplateEntity({
    ...templateData,
    createdBy: email
  });

  const validationErrors = templateEntity.validate();
  if (validationErrors.length > 0) {
    throw new Error(validationErrors.join(', '));
  }

  const templatesRef = ref(database, CARE_ROUTINE_TEMPLATES_COLLECTION);
  const newTemplateRef = push(templatesRef);
  templateEntity.id = newTemplateRef.key;
  
  await set(newTemplateRef, templateEntity.toFirebase());
  return templateEntity;
};

export const updateCareRoutineTemplate = async (templateId, updatedData) => {
  if (!templateId) throw new Error("Template ID is required");

  const templateRef = ref(database, `${CARE_ROUTINE_TEMPLATES_COLLECTION}/${templateId}`);
  const snapshot = await get(templateRef);
  
  if (!snapshot.exists()) throw new Error("Template not found");

  const existingData = snapshot.val();
  const updatedTemplate = new careRoutineTemplateEntity({
    ...existingData,
    ...updatedData,
    id: templateId,
    lastUpdatedAt: new Date().toISOString()
  });

  const validationErrors = updatedTemplate.validate();
  if (validationErrors.length > 0) {
    throw new Error(validationErrors.join(', '));
  }

  await update(templateRef, updatedTemplate.toFirebase());
  return updatedTemplate;
};

export const deleteCareRoutineTemplate = async (templateId) => {
  if (!templateId) throw new Error("Template ID is required");
  
  // Check if template exists
  const templateRef = ref(database, `${CARE_ROUTINE_TEMPLATES_COLLECTION}/${templateId}`);
  const snapshot = await get(templateRef);
  
  if (!snapshot.exists()) {
    throw new Error("Template not found");
  }

  // Check if template is assigned to any elderly users
  const assignedRef = ref(database, ASSIGNED_ROUTINES_COLLECTION);
  const assignedSnapshot = await get(assignedRef);
  
  if (assignedSnapshot.exists()) {
    const assignedData = assignedSnapshot.val();
    
    // Check all elderly users for assignments of this template
    for (const elderlyId in assignedData) {
      if (assignedData[elderlyId] && assignedData[elderlyId][templateId]) {
        throw new Error("Cannot delete template that is currently assigned. Please unassign it first.");
      }
    }
  }

  await remove(templateRef);
  return true;
};

// Get templates created by current user
export const getUserCareRoutineTemplates = async () => {
  const email = getCurrentUserEmail();
  if (!email) return [];

  const templatesRef = ref(database, CARE_ROUTINE_TEMPLATES_COLLECTION);
  const snapshot = await get(templatesRef);
  
  if (!snapshot.exists()) return [];
  
  const data = snapshot.val();
  return Object.keys(data)
    .map(key => careRoutineTemplateEntity.fromFirebase(key, data[key]))
    .filter(template => template.createdBy === email);
};

// Subscribe to templates created by current user
export const subscribeToUserTemplates = (callback) => {
  const email = getCurrentUserEmail();
  if (!email) return () => {};

  const templatesRef = ref(database, CARE_ROUTINE_TEMPLATES_COLLECTION);

  const unsubscribe = onValue(templatesRef, (snapshot) => {
    const data = snapshot.val() || {};
    const templates = Object.keys(data)
      .map(key => careRoutineTemplateEntity.fromFirebase(key, data[key]))
      .filter(template => template.createdBy === email);
    callback(templates);
  }, (error) => {
    console.error("Error in templates snapshot:", error);
  });

  return () => off(templatesRef, "value", unsubscribe);
};

// Assign routine to elderly user
export const assignRoutineToElderly = async (elderlyUid, templateId, startDate = new Date().toISOString()) => {
  if (!elderlyUid) throw new Error("Elderly user UID is required");
  if (!templateId) throw new Error("Template ID is required");

  // Get template details
  const templateRef = ref(database, `${CARE_ROUTINE_TEMPLATES_COLLECTION}/${templateId}`);
  const templateSnapshot = await get(templateRef);
  
  if (!templateSnapshot.exists()) throw new Error("Template not found");
  
  const templateData = templateSnapshot.val();
  
  // Create assignment record
  const assignmentRef = ref(database, `${ASSIGNED_ROUTINES_COLLECTION}/${elderlyUid}/${templateId}`);
  const assignmentData = {
    templateId,
    elderlyId: elderlyUid,
    assignedBy: getCurrentUserEmail(),
    assignedAt: new Date().toISOString(),
    startDate,
    isActive: true,
    templateData: templateData
  };
  
  await set(assignmentRef, assignmentData);
  return assignmentData;
};

// Get assigned routines for elderly user
export const getAssignedRoutines = async (elderlyUid) => {
  if (!elderlyUid) throw new Error("Elderly user UID is required");

  const assignedRef = ref(database, `${ASSIGNED_ROUTINES_COLLECTION}/${elderlyUid}`);
  const snapshot = await get(assignedRef);
  
  if (!snapshot.exists()) return [];
  
  const data = snapshot.val();
  return Object.keys(data).map(key => ({ 
    id: key, 
    ...data[key] 
  }));
};

// Subscribe to assigned routines for elderly user
export const subscribeToAssignedRoutines = (elderlyUid, callback) => {
  if (!elderlyUid) return () => {};

  const assignedRef = ref(database, `${ASSIGNED_ROUTINES_COLLECTION}/${elderlyUid}`);

  const unsubscribe = onValue(assignedRef, (snapshot) => {
    const data = snapshot.val() || {};
    const routines = Object.keys(data).map(key => ({ 
      id: key, 
      ...data[key] 
    }));
    callback(routines);
  }, (error) => {
    console.error("Error in assigned routines snapshot:", error);
  });

  return () => off(assignedRef, "value", unsubscribe);
};

// Remove assigned routine (Unassign functionality)
export const removeAssignedRoutine = async (elderlyUid, templateId) => {
  if (!elderlyUid) throw new Error("Elderly user UID is required");
  if (!templateId) throw new Error("Template ID is required");

  const assignedRef = ref(database, `${ASSIGNED_ROUTINES_COLLECTION}/${elderlyUid}/${templateId}`);
  
  // Check if assignment exists
  const snapshot = await get(assignedRef);
  if (!snapshot.exists()) {
    throw new Error("This routine is not assigned to the specified user");
  }
  
  await remove(assignedRef);
  return true;
};

// Check if template is assigned to any elderly users
export const isTemplateAssigned = async (templateId) => {
  if (!templateId) return false;

  const assignedRef = ref(database, ASSIGNED_ROUTINES_COLLECTION);
  const snapshot = await get(assignedRef);
  
  if (!snapshot.exists()) return false;
  
  const data = snapshot.val();
  
  // Check all elderly users for assignments of this template
  for (const elderlyId in data) {
    if (data[elderlyId] && data[elderlyId][templateId]) {
      return true;
    }
  }
  
  return false;
};

// Get all assigned routines across all linked elderly users
export const getAllAssignedRoutines = async (elderlyIds = []) => {
  const allAssigned = [];
  
  for (const elderlyId of elderlyIds) {
    try {
      const assigned = await getAssignedRoutines(elderlyId);
      allAssigned.push(...assigned.map(item => ({
        ...item,
        elderlyId
      })));
    } catch (error) {
      console.error(`Error getting assigned routines for ${elderlyId}:`, error);
    }
  }
  
  return allAssigned;
};