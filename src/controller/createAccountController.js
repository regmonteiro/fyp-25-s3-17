// ✅ Import Realtime DB functions directly from firebase/database
import { ref, set, get } from "firebase/database";

// ✅ Import your firebase instances (DO NOT import ref here)
import { database, firestore } from "../firebaseConfig";

// ✅ Import Firestore write functions directly from firebase/firestore
import { setDoc, doc } from "firebase/firestore";

import bcrypt from "bcryptjs";


// Encode email as Firebase key
function encodeEmail(email) {
  return email.replace(/[.#$/[\]]/g, '_');
}

// Generate UID for new users
function generateUID() {
  return 'user_' + Date.now() + '_' + Math.random().toString(36).substr(2, 9);
}

// Calculate age from date of birth
function calculateAge(dob) {
  const birthDate = new Date(dob);
  const today = new Date();
  let age = today.getFullYear() - birthDate.getFullYear();
  const monthDiff = today.getMonth() - birthDate.getMonth();
  
  if (monthDiff < 0 || (monthDiff === 0 && today.getDate() < birthDate.getDate())) {
    age--;
  }
  
  return age;
}

// Calculate subscription end date based on plan
function calculateSubscriptionEndDate(plan) {
  const today = new Date();
  const endDate = new Date();
  
  switch(plan) {
    case 0: // Free trial (14 days)
      endDate.setDate(today.getDate() + 14);
      break;
    case 1: // Monthly plan
      endDate.setMonth(today.getMonth() + 1);
      break;
    case 2: // Quarterly plan
      endDate.setMonth(today.getMonth() + 3);
      break;
    case 3: // Yearly plan
      endDate.setFullYear(today.getFullYear() + 1);
      break;
    default:
      endDate.setDate(today.getDate() + 14); // Default to 14-day trial
  }
  
  return endDate.toISOString().split('T')[0]; // Return as YYYY-MM-DD
}

// Generate subscription ID
function generateSubscriptionId() {
  return 'sub_' + Date.now();
}

// Find an elderly user without a caregiver
async function findElderlyWithoutCaregiver() {
  try {
    const accountsRef = ref(database, 'Account');
    const snapshot = await get(accountsRef);
    
    if (!snapshot.exists()) {
      return null;
    }
    
    const accounts = snapshot.val();
    const elderlyWithoutCaregivers = [];
    const caregiversMap = new Map(); // Track which elderly have caregivers
    
    // First, find all caregivers and map their elderly assignments
    Object.keys(accounts).forEach(key => {
      const account = accounts[key];
      if (account.userType === 'caregiver' && account.elderlyId) {
        caregiversMap.set(account.elderlyId, true);
      }
    });
    
    // Then, find elderly users without caregivers
    Object.keys(accounts).forEach(key => {
      const account = accounts[key];
      if (account.userType === 'elderly' && account.uid && !caregiversMap.has(account.uid)) {
        elderlyWithoutCaregivers.push({
          uid: account.uid,
          email: account.email,
          firstname: account.firstname,
          lastname: account.lastname,
          dob: account.dob
        });
      }
    });
    
    // Return a random elderly user from the list
    if (elderlyWithoutCaregivers.length > 0) {
      const randomIndex = Math.floor(Math.random() * elderlyWithoutCaregivers.length);
      return elderlyWithoutCaregivers[randomIndex];
    }
    
    return null;
  } catch (error) {
    console.error("Error finding elderly without caregiver:", error);
    return null;
  }
}

export async function createAccount(accountEntity) {
  const error = accountEntity.validate();
  if (error) return { success: false, error };

  try {
    // Verify user is at least 18 years old for all account types
    const age = calculateAge(accountEntity.dob);
    if (age < 18) {
      return { success: false, error: "You must be at least 18 years old to create an account." };
    }

    // If user is elderly, verify they are 60 years or older
    if (accountEntity.userType === 'elderly') {
      if (age < 60) {
        return { success: false, error: "Elderly users must be 60 years or older." };
      }
    }

    const encodedEmail = encodeEmail(accountEntity.email);
    const userRef = ref(database, 'Account/' + encodedEmail);

    // Check if account already exists
    const snapshot = await get(userRef);
    if (snapshot.exists()) {
      return { success: false, error: "This email is already registered." };
    }

    // Generate UID for the new user
    const uid = generateUID();
    
    let elderlyUid = accountEntity.elderlyId;
    let assignedElderlyInfo = null;

    // If caregiver and no elderlyId provided, find one automatically
    if (accountEntity.userType === 'caregiver' && (!elderlyUid || !elderlyUid.trim())) {
      const availableElderly = await findElderlyWithoutCaregiver();
      
      if (!availableElderly) {
        return { 
          success: false, 
          error: "No elderly users available for assignment at the moment. Please try again later or contact admin." 
        };
      }
      
      elderlyUid = availableElderly.uid;
      assignedElderlyInfo = availableElderly;
    }

    // If caregiver with provided elderlyUid, verify it exists and is valid
    if (accountEntity.userType === 'caregiver' && elderlyUid) {
      let elderlyFound = false;
      let elderlyData = null;
      
      // Search through all accounts to find the elderly by UID
      const allAccountsRef = ref(database, 'Account');
      const allAccountsSnapshot = await get(allAccountsRef);
      
      if (allAccountsSnapshot.exists()) {
        const allAccounts = allAccountsSnapshot.val();
        for (const key in allAccounts) {
          const account = allAccounts[key];
          if (account.uid === elderlyUid) {
            elderlyData = account;
            elderlyFound = true;
            break;
          }
        }
      }
      
      if (!elderlyFound) {
        return { success: false, error: "Elderly user not found in the system." };
      }
      
      // Verify the referenced account is actually an elderly account
      if (elderlyData.userType !== 'elderly') {
        return { success: false, error: "The referenced account is not registered as an elderly user." };
      }
      
      // Verify the elderly is actually 60+ years old
      const elderlyAge = calculateAge(elderlyData.dob);
      if (elderlyAge < 60) {
        return { success: false, error: "The referenced elderly user must be 60 years or older." };
      }

      // Check if this elderly already has a caregiver
      for (const key in allAccountsSnapshot.val()) {
        const account = allAccountsSnapshot.val()[key];
        if (account.userType === 'caregiver' && account.elderlyId === elderlyUid) {
          return { 
            success: false, 
            error: "This elderly user already has a caregiver assigned." 
          };
        }
      }
    }

    // Hash the password before saving
    const hashedPassword = await bcrypt.hash(accountEntity.password, 10);

    // Prepare account data
    const accountData = {
      firstname: accountEntity.firstname,
      lastname: accountEntity.lastname,
      email: accountEntity.email,
      dob: accountEntity.dob,
      phoneNum: accountEntity.phoneNum,
      password: hashedPassword, 
      userType: accountEntity.userType,
      uid: uid, // Add UID to account data
      elderlyId: accountEntity.userType === 'caregiver' ? elderlyUid : null,
      createdAt: new Date().toISOString(),
      subscriptionPlan: accountEntity.subscriptionPlan !== undefined ? accountEntity.subscriptionPlan : null,
    };

    // Save account with hashed password
    await set(userRef, accountData); // Realtime Database
    await setDoc(doc(firestore, "Account", encodedEmail), accountData); // Firestore

    // If user selected a subscription plan, create subscription entry
    if (accountEntity.subscriptionPlan !== null && accountEntity.subscriptionPlan !== undefined) {
      const subscriptionId = generateSubscriptionId();
      const subscriptionRef = ref(database, `paymentsubscriptions/${accountEntity.email.replace(/\./g, ',')}`);
      
      let subscriptionData = {
        id: subscriptionId,
        active: true,
        autoPayment: accountEntity.autoPayment || false,
        paymentFailed: false,
        nextPaymentDate: calculateSubscriptionEndDate(accountEntity.subscriptionPlan),
        subscriptionPlan: accountEntity.subscriptionPlan,
        startDate: new Date().toISOString().split('T')[0]
      };
      
      // For free trial, set payment details to empty or "N/A"
      if (accountEntity.subscriptionPlan === 0) {
        subscriptionData = {
          ...subscriptionData,
          paymentMethod: 'trial',
          cardName: 'N/A',
          cardNumber: 'N/A',
          expiryDate: 'N/A',
          cvv: 'N/A'
        };
      } else {
        // For paid plans, use the provided payment details
        subscriptionData = {
          ...subscriptionData,
          paymentMethod: accountEntity.paymentDetails?.method || '',
          cardName: accountEntity.paymentDetails?.cardName || '',
          cardNumber: accountEntity.paymentDetails?.cardNumber || '',
          expiryDate: accountEntity.paymentDetails?.expiry || '',
          cvv: accountEntity.paymentDetails?.cvv || ''
        };
      }
      
      await set(subscriptionRef, subscriptionData);
    }

    return { 
      success: true, 
      message: accountEntity.userType === 'caregiver' && assignedElderlyInfo 
        ? `Account created successfully! You have been automatically assigned to care for ${assignedElderlyInfo.firstname} ${assignedElderlyInfo.lastname}.` 
        : "Account successfully created!" 
    };
  } catch (err) {
    console.error("Error saving to Firebase:", err);
    return { success: false, error: "Failed to create account. Please try again." };
  }
}