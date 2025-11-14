// src/controller/linkElderlyController.js
import { ref, get, update, query, orderByChild, equalTo } from "firebase/database";
import { database } from "../firebaseConfig";

// 🔑 Encode email to use as Firebase key
function encodeEmail(email) {
  return email.replace(/[.#$/[\]]/g, "_");
}

// 🧮 Helper: Calculate age from DOB
export function calculateAge(dob) {
  if (!dob) return null;
  const birthDate = new Date(dob);
  const today = new Date();
  let age = today.getFullYear() - birthDate.getFullYear();
  const monthDiff = today.getMonth() - birthDate.getMonth();

  if (monthDiff < 0 || (monthDiff === 0 && today.getDate() < birthDate.getDate())) {
    age--;
  }
  return age;
}

// Enhanced function to fetch elderly data using identifier (email or UID)
const fetchElderlyData = async (elderlyIdentifier) => {
  try {
    let elderlyRef;
    
    // Check if identifier is an email (contains @)
    if (elderlyIdentifier.includes('@')) {
      const key = encodeEmail(elderlyIdentifier);
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
    
    return {
      id: elderlyIdentifier.includes('@') ? encodeEmail(elderlyIdentifier) : elderlyIdentifier,
      identifier: elderlyIdentifier,
      name: `${elderly.firstname || ''} ${elderly.lastname || ''}`.trim() || 'Unknown Elderly',
      email: elderly.email || elderlyIdentifier,
      uid: elderly.uid || elderlyIdentifier,
      firstname: elderly.firstname,
      lastname: elderly.lastname,
      dob: elderly.dob,
      gender: elderly.gender,
      userType: elderly.userType
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

// 🔍 Search elderly by name or email (and mark if they already have THIS SPECIFIC caregiver)
export async function searchElderly(query, currentCaregiverEmail = null) {
  try {
    const accountsRef = ref(database, "Account");
    const snapshot = await get(accountsRef);

    if (!snapshot.exists()) return [];

    const accounts = snapshot.val();
    const results = [];

    // Search through all accounts for elderly users matching the query
    for (const [accountKey, account] of Object.entries(accounts)) {
      if (account.userType !== "elderly") continue;

      const fullName = `${account.firstname || ''} ${account.lastname || ''}`.toLowerCase();
      const matchesName = fullName.includes(query.toLowerCase());
      const matchesEmail = account.email?.toLowerCase().includes(query.toLowerCase());
      
      // Also check if query matches UID
      const matchesUid = account.uid?.toLowerCase().includes(query.toLowerCase());

      if (matchesName || matchesEmail || matchesUid) {
        // Check if this elderly is already linked to the CURRENT caregiver
        const isLinkedToCurrentCaregiver = currentCaregiverEmail 
          ? await checkIfElderlyIsLinkedToCurrentCaregiver(account, currentCaregiverEmail, accounts)
          : false;
        
        results.push({
          ...account,
          key: accountKey,
          hasCaregiver: isLinkedToCurrentCaregiver, // Now only true if linked to current caregiver
          // Ensure we have all required fields
          firstname: account.firstname || '',
          lastname: account.lastname || '',
          email: account.email || '',
          uid: account.uid || accountKey,
          dob: account.dob,
          gender: account.gender
        });
      }
    }

    return results;
  } catch (err) {
    console.error("Error searching elderly:", err);
    throw err;
  }
}

// Check if elderly is already linked to the CURRENT caregiver specifically
async function checkIfElderlyIsLinkedToCurrentCaregiver(elderly, currentCaregiverEmail, accounts) {
  try {
    const elderlyEmail = elderly.email;
    const elderlyUid = elderly.uid;
    const currentCaregiverKey = encodeEmail(currentCaregiverEmail);
    
    // Get the current caregiver's data
    const currentCaregiver = accounts[currentCaregiverKey];
    
    if (!currentCaregiver) {
      console.log('Current caregiver not found in accounts');
      return false;
    }

    // Get all elderly identifiers from the CURRENT caregiver
    const elderlyIdentifiers = getAllElderlyIdentifiersFromCaregiver(currentCaregiver);
    
    console.log(`Checking if elderly ${elderlyEmail} (UID: ${elderlyUid}) is linked to caregiver ${currentCaregiverEmail}`);
    console.log('Caregiver elderly identifiers:', elderlyIdentifiers);

    // Check if this elderly is in the CURRENT caregiver's list
    const isLinked = elderlyIdentifiers.some(identifier => {
      // Direct match by email or UID
      if (identifier === elderlyEmail || identifier === elderlyUid) {
        console.log(`Direct match found: ${identifier}`);
        return true;
      }
      
      // If identifier is a UID, check if it matches elderly UID
      if (!identifier.includes('@') && identifier === elderlyUid) {
        console.log(`UID match found: ${identifier} === ${elderlyUid}`);
        return true;
      }
      
      // If identifier is an email, check if it matches elderly email
      if (identifier.includes('@') && identifier === elderlyEmail) {
        console.log(`Email match found: ${identifier} === ${elderlyEmail}`);
        return true;
      }
      
      return false;
    });

    console.log(`Is elderly linked to current caregiver: ${isLinked}`);
    return isLinked;
  } catch (error) {
    console.error('Error checking if elderly is linked to current caregiver:', error);
    return false;
  }
}

// 🔗 Link caregiver to elderly (supports both email and UID)
export async function linkCaregiverToElderly(caregiverEmail, elderlyIdentifier) {
  try {
    const caregiverKey = encodeEmail(caregiverEmail);
    const caregiverRef = ref(database, "Account/" + caregiverKey);
    const snapshot = await get(caregiverRef);

    if (!snapshot.exists()) {
      throw new Error("Caregiver not found.");
    }

    const caregiver = snapshot.val();
    
    // Get elderly data to ensure they exist and get their UID
    const elderlyData = await fetchElderlyData(elderlyIdentifier);
    
    if (!elderlyData) {
      throw new Error("Elderly user not found.");
    }

    // Use UID for linking (more reliable than email)
    const elderlyUid = elderlyData.uid;
    
    if (!elderlyUid) {
      throw new Error("Elderly user does not have a valid UID.");
    }

    // Get current elderly identifiers
    let elderlyIds = caregiver.elderlyIds || [];
    let linkedElderUids = caregiver.linkedElderUids || [];
    let linkedElders = caregiver.linkedElders || [];

    // Normalize to arrays
    if (!Array.isArray(elderlyIds)) {
      elderlyIds = [elderlyIds].filter(Boolean);
    }
    if (!Array.isArray(linkedElderUids)) {
      linkedElderUids = [linkedElderUids].filter(Boolean);
    }
    if (!Array.isArray(linkedElders)) {
      linkedElders = [linkedElders].filter(Boolean);
    }

    // Check if already linked to THIS caregiver
    const alreadyLinked = 
      elderlyIds.includes(elderlyUid) || 
      elderlyIds.includes(elderlyData.email) ||
      linkedElderUids.includes(elderlyUid) ||
      linkedElders.includes(elderlyUid);

    if (alreadyLinked) {
      throw new Error("This elderly is already linked to your account.");
    }

    // Update all relevant fields
    const updates = {};
    
    // Add to elderlyIds (use UID)
    if (!elderlyIds.includes(elderlyUid)) {
      updates.elderlyIds = [...elderlyIds, elderlyUid];
    }
    
    // Add to linkedElderUids
    if (!linkedElderUids.includes(elderlyUid)) {
      updates.linkedElderUids = [...linkedElderUids, elderlyUid];
    }
    
    // Add to linkedElders
    if (!linkedElders.includes(elderlyUid)) {
      updates.linkedElders = [...linkedElders, elderlyUid];
    }

    // Also set elderlyId if it's empty (single elderly case)
    if (!caregiver.elderlyId) {
      updates.elderlyId = elderlyUid;
    }

    // Also set uidOfElder if it's empty
    if (!caregiver.uidOfElder) {
      updates.uidOfElder = elderlyUid;
    }

    await update(caregiverRef, updates);

    console.log(`Successfully linked caregiver ${caregiverEmail} to elderly ${elderlyData.name} (UID: ${elderlyUid})`);
    return true;
  } catch (err) {
    console.error("Error linking caregiver to elderly:", err);
    throw err;
  }
}

// Get all linked elderly for a caregiver
export async function getLinkedElderlyForCaregiver(caregiverEmail) {
  try {
    const caregiverKey = encodeEmail(caregiverEmail);
    const caregiverRef = ref(database, "Account/" + caregiverKey);
    const snapshot = await get(caregiverRef);

    if (!snapshot.exists()) {
      return [];
    }

    const caregiver = snapshot.val();
    const elderlyIdentifiers = getAllElderlyIdentifiersFromCaregiver(caregiver);
    const linkedElderly = [];

    // Fetch data for each elderly identifier
    for (const elderlyIdentifier of elderlyIdentifiers) {
      try {
        const elderlyData = await fetchElderlyData(elderlyIdentifier);
        if (elderlyData) {
          linkedElderly.push(elderlyData);
        }
      } catch (error) {
        console.error(`Error fetching elderly data for ${elderlyIdentifier}:`, error);
      }
    }

    return linkedElderly;
  } catch (err) {
    console.error("Error getting linked elderly:", err);
    throw err;
  }
}

// Unlink caregiver from elderly
export async function unlinkCaregiverFromElderly(caregiverEmail, elderlyUid) {
  try {
    const caregiverKey = encodeEmail(caregiverEmail);
    const caregiverRef = ref(database, "Account/" + caregiverKey);
    const snapshot = await get(caregiverRef);

    if (!snapshot.exists()) {
      throw new Error("Caregiver not found.");
    }

    const caregiver = snapshot.val();
    
    // Get all current identifiers
    let elderlyIds = caregiver.elderlyIds || [];
    let linkedElderUids = caregiver.linkedElderUids || [];
    let linkedElders = caregiver.linkedElders || [];

    // Normalize to arrays
    if (!Array.isArray(elderlyIds)) {
      elderlyIds = [elderlyIds].filter(Boolean);
    }
    if (!Array.isArray(linkedElderUids)) {
      linkedElderUids = [linkedElderUids].filter(Boolean);
    }
    if (!Array.isArray(linkedElders)) {
      linkedElders = [linkedElders].filter(Boolean);
    }

    // Remove the elderly UID from all arrays
    const updates = {};
    updates.elderlyIds = elderlyIds.filter(id => id !== elderlyUid);
    updates.linkedElderUids = linkedElderUids.filter(id => id !== elderlyUid);
    updates.linkedElders = linkedElders.filter(id => id !== elderlyUid);

    // If elderlyId matches, clear it
    if (caregiver.elderlyId === elderlyUid) {
      updates.elderlyId = '';
    }

    // If uidOfElder matches, clear it
    if (caregiver.uidOfElder === elderlyUid) {
      updates.uidOfElder = '';
    }

    await update(caregiverRef, updates);

    console.log(`Successfully unlinked caregiver ${caregiverEmail} from elderly UID: ${elderlyUid}`);
    return true;
  } catch (err) {
    console.error("Error unlinking caregiver from elderly:", err);
    throw err;
  }
}