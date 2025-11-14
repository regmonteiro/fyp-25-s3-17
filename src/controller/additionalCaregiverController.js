// ✅ Import Realtime DB functions directly from firebase/database
import { ref, set, get, update, push } from "firebase/database";
import { database, firestore } from "../firebaseConfig";
import { setDoc, doc, updateDoc } from "firebase/firestore";

// Encode email as Firebase key
// Encode email as Firebase key - IMPROVED
function encodeEmail(email) {
  if (!email) return '';
  // Replace all invalid Firebase characters with underscores
  return email.replace(/[.#$/[\]]/g, '_');
}

// Decode email from Firebase key (if needed)
function decodeEmail(encodedEmail) {
  if (!encodedEmail) return '';
  // Convert underscores back to original characters
  // Note: This won't perfectly restore the original email if it contained underscores
  return encodedEmail.replace(/_/g, '.');
}
// Get current elderly user from localStorage
async function getCurrentElderlyUser() {
  try {
    const userEmail = localStorage.getItem("loggedInEmail");
    if (!userEmail) {
      throw new Error("No user logged in");
    }

    const accountsRef = ref(database, 'Account');
    const snapshot = await get(accountsRef);
    
    if (!snapshot.exists()) {
      throw new Error("No accounts found");
    }
    
    const accounts = snapshot.val();
    
    // Search for the elderly user by email
    for (const key in accounts) {
      const account = accounts[key];
      if (account.email === userEmail && account.userType === 'elderly') {
        return {
          ...account,
          databaseKey: key
        };
      }
    }
    
    throw new Error("Elderly user not found");
  } catch (error) {
    console.error("Error getting current elderly user:", error);
    throw error;
  }
}

// Search for caregiver by email
async function searchCaregiverByEmail(email) {
  try {
    const encodedEmail = encodeEmail(email);
    const userRef = ref(database, 'Account/' + encodedEmail);
    const snapshot = await get(userRef);
    
    if (snapshot.exists()) {
      const caregiverData = snapshot.val();
      // Verify this is a caregiver account
      if (caregiverData.userType === 'caregiver') {
        return {
          ...caregiverData,
          databaseKey: encodedEmail
        };
      } else {
        throw new Error("This email belongs to a non-caregiver account");
      }
    } else {
      throw new Error("Caregiver not found with this email");
    }
  } catch (error) {
    console.error("Error searching caregiver:", error);
    throw error;
  }
}

// Get wallet balance for elderly - QUICK FIX
async function getWalletBalance(userEmail) {
  try {
    // Convert email to use comma instead of dot to match your database
    const dbEmail = userEmail.replace(/\./g, ',');
    const walletRef = ref(database, `paymentsubscriptions/${dbEmail}/walletBalance`);
    const snapshot = await get(walletRef);
    
    if (snapshot.exists()) {
      const balance = parseFloat(snapshot.val());
      console.log(`Found wallet balance for ${userEmail} (db format: ${dbEmail}): $${balance}`);
      return balance;
    } else {
      console.log(`No wallet balance found for ${userEmail} (db format: ${dbEmail}), defaulting to 0`);
      return 0;
    }
  } catch (error) {
    console.error("Error getting wallet balance:", error);
    return 0;
  }
}

// Update wallet balance - QUICK FIX
async function updateWalletBalance(userEmail, newBalance) {
  try {
    // Convert email to use comma instead of dot to match your database
    const dbEmail = userEmail.replace(/\./g, ',');
    const walletRef = ref(database, `paymentsubscriptions/${dbEmail}/walletBalance`);
    await set(walletRef, parseFloat(newBalance));
    
    console.log(`Updated wallet balance for ${userEmail} (db format: ${dbEmail}): $${newBalance}`);
    return true;
  } catch (error) {
    console.error("Error updating wallet balance:", error);
    return false;
  }
}

// Create payment record - QUICK FIX
async function createPaymentRecord(userEmail, amount, description, paymentMethod = 'wallet', cardDetails = null) {
  try {
    // Convert email to use comma instead of dot to match your database
    const dbEmail = userEmail.replace(/\./g, ',');
    const paymentHistoryRef = push(ref(database, `paymentsubscriptions/${dbEmail}/paymentHistory`));
    const paymentData = {
      id: paymentHistoryRef.key,
      amount: parseFloat(amount),
      description: description,
      timestamp: new Date().toISOString(),
      type: 'caregiver_fee',
      paymentMethod: paymentMethod,
      status: 'completed'
    };

    if (paymentMethod === 'credit_card' && cardDetails) {
      paymentData.cardLast4 = cardDetails.cardNumber.slice(-4);
      paymentData.cardBrand = 'Visa';
    }

    await set(paymentHistoryRef, paymentData);
    return true;
  } catch (error) {
    console.error("Error creating payment record:", error);
    return false;
  }
}
// Process credit card payment (simulated - integrate with Stripe/PayPal in production)
async function processCreditCardPayment(paymentData) {
  try {
    // Simulate API call to payment processor
    console.log("Processing credit card payment:", {
      amount: paymentData.amount,
      cardLast4: paymentData.cardDetails.cardNumber.slice(-4),
      description: paymentData.description
    });
    
    // Simulate payment processing delay
    await new Promise(resolve => setTimeout(resolve, 2000));
    
    // Simulate successful payment
    return {
      success: true,
      transactionId: 'txn_' + Date.now() + Math.random().toString(36).substr(2, 9),
      message: 'Payment processed successfully'
    };
  } catch (error) {
    console.error("Credit card payment failed:", error);
    return {
      success: false,
      error: 'Payment processing failed. Please check your card details.'
    };
  }
}

// Check if caregiver is already linked to elderly
async function isCaregiverLinked(caregiverUid, elderlyUid) {
  try {
    const accountsRef = ref(database, 'Account');
    const snapshot = await get(accountsRef);
    
    if (!snapshot.exists()) return false;
    
    const accounts = snapshot.val();
    
    for (const key in accounts) {
      const account = accounts[key];
      if (account.uid === caregiverUid && account.userType === 'caregiver') {
        // Check both elderlyId (single) and elderlyIds (array)
        if (account.elderlyId === elderlyUid || 
            (account.elderlyIds && account.elderlyIds.includes(elderlyUid))) {
          return true;
        }
      }
    }
    return false;
  } catch (error) {
    console.error("Error checking caregiver link:", error);
    return false;
  }
}

// Link caregiver to elderly (only update elderlyId/elderlyIds)
async function linkCaregiverToElderly(caregiverData, elderlyUid) {
  try {
    const caregiverRef = ref(database, `Account/${caregiverData.databaseKey}`);
    
    // Update caregiver's elderly assignments
    let updatedElderlyIds = caregiverData.elderlyIds || [];
    if (!updatedElderlyIds.includes(elderlyUid)) {
      updatedElderlyIds.push(elderlyUid);
    }
    
    const updateData = {
      elderlyId: elderlyUid, // Set as primary elderly
      elderlyIds: updatedElderlyIds,
      linkedAt: new Date().toISOString(),
      status: 'Active'
    };
    
    await update(caregiverRef, updateData);
    
    // Also update Firestore
    await updateDoc(doc(firestore, "Account", caregiverData.databaseKey), updateData);
    
    return true;
  } catch (error) {
    console.error("Error linking caregiver:", error);
    throw error;
  }
}

export class AddCaregiverController {
  static async searchCaregiver(caregiverEmail) {
    try {
      const caregiver = await searchCaregiverByEmail(caregiverEmail);
      
      // Get current elderly to check if already linked
      const elderlyUser = await getCurrentElderlyUser();
      const isLinked = await isCaregiverLinked(caregiver.uid, elderlyUser.uid);
      
      return {
        success: true,
        data: {
          ...caregiver,
          isLinked: isLinked
        }
      };
    } catch (error) {
      return {
        success: false,
        error: error.message
      };
    }
  }

  static async addCaregiverWithPayment(caregiverEmail, paymentMethod = 'wallet', cardDetails = null) {
    try {
      // Get current elderly user
      const elderlyUser = await getCurrentElderlyUser();
      const userEmail = elderlyUser.email; // Use email for wallet path

      console.log(`Adding caregiver for elderly: ${userEmail}`);

      // Search for caregiver
      const searchResult = await this.searchCaregiver(caregiverEmail);
      if (!searchResult.success) {
        return searchResult;
      }

      const caregiverData = searchResult.data;

      // Check if already linked
      if (caregiverData.isLinked) {
        return {
          success: false,
          error: "This caregiver is already linked to your account"
        };
      }

      const caregiverFee = 25.00;

      // Handle payment based on method
      if (paymentMethod === 'wallet') {
        // Check wallet balance using email
        const currentBalance = await getWalletBalance(userEmail);
        console.log(`Current wallet balance for ${userEmail}: $${currentBalance}, Fee: $${caregiverFee}`);
        
        if (currentBalance < caregiverFee) {
          return { 
            success: false, 
            error: `Insufficient funds. You need $${caregiverFee} to add a caregiver. Current balance: $${currentBalance.toFixed(2)}` 
          };
        }
      } else if (paymentMethod === 'credit_card') {
        // Process credit card payment
        const paymentResult = await processCreditCardPayment({
          amount: caregiverFee,
          cardDetails: cardDetails,
          description: `Caregiver fee for ${caregiverData.firstname} ${caregiverData.lastname}`
        });
        
        if (!paymentResult.success) {
          return { success: false, error: paymentResult.error };
        }
      }

      // Link caregiver to elderly (only update elderlyId/elderlyIds)
      await linkCaregiverToElderly(caregiverData, elderlyUser.uid);

      // Handle payment deduction
      if (paymentMethod === 'wallet') {
        const currentBalance = await getWalletBalance(userEmail);
        const newBalance = currentBalance - caregiverFee;
        console.log(`Deducting $${caregiverFee} from wallet. Old balance: $${currentBalance}, New balance: $${newBalance}`);
        
        const walletUpdated = await updateWalletBalance(userEmail, newBalance);
        
        if (!walletUpdated) {
          throw new Error("Wallet payment processing failed");
        }
      }

      // Create payment record in paymentsubscriptions
      await createPaymentRecord(
        userEmail, 
        caregiverFee, 
        `Caregiver fee for ${caregiverData.firstname} ${caregiverData.lastname}`,
        paymentMethod,
        cardDetails
      );

      // Get final balance for response
      const finalBalance = paymentMethod === 'wallet' ? await getWalletBalance(userEmail) : null;

      return { 
        success: true, 
        message: `Caregiver ${caregiverData.firstname} ${caregiverData.lastname} added successfully! $${caregiverFee} ${paymentMethod === 'wallet' ? 'deducted from your wallet' : 'charged to your card'}.`,
        newBalance: finalBalance,
        caregiver: caregiverData,
        paymentMethod: paymentMethod
      };

    } catch (error) {
      console.error("Error adding caregiver:", error);
      return {
        success: false,
        error: error.message || "Failed to add caregiver. Please try again."
      };
    }
  }

  static async getElderlyInfo() {
    try {
      const elderlyUser = await getCurrentElderlyUser();
      // Use email instead of UID for wallet balance
      const walletBalance = await getWalletBalance(elderlyUser.email);

      return {
        success: true,
        data: {
          elderly: {
            firstname: elderlyUser.firstname,
            lastname: elderlyUser.lastname,
            email: elderlyUser.email,
            uid: elderlyUser.uid
          },
          walletBalance: walletBalance,
          caregiverFee: 25.00
        }
      };
    } catch (error) {
      return {
        success: false,
        error: error.message
      };
    }
  }

  static async getLinkedCaregivers() {
    try {
      const elderlyUser = await getCurrentElderlyUser();
      const accountsRef = ref(database, 'Account');
      const snapshot = await get(accountsRef);
      
      if (!snapshot.exists()) {
        return { success: true, data: [] };
      }
      
      const accounts = snapshot.val();
      const linkedCaregivers = [];
      
      for (const key in accounts) {
        const account = accounts[key];
        if (account.userType === 'caregiver') {
          // Check if linked to current elderly
          if (account.elderlyId === elderlyUser.uid || 
              (account.elderlyIds && account.elderlyIds.includes(elderlyUser.uid))) {
            linkedCaregivers.push({
              ...account,
              databaseKey: key
            });
          }
        }
      }
      
      return {
        success: true,
        data: linkedCaregivers
      };
    } catch (error) {
      return {
        success: false,
        error: error.message
      };
    }
  }

  static async removeCaregiver(caregiverUid) {
    try {
      const elderlyUser = await getCurrentElderlyUser();
      const elderlyUid = elderlyUser.uid;

      // Find caregiver account
      const accountsRef = ref(database, 'Account');
      const snapshot = await get(accountsRef);
      
      if (!snapshot.exists()) {
        return { success: false, error: "Caregiver not found" };
      }
      
      const accounts = snapshot.val();
      let caregiverKey = null;
      let caregiverData = null;
      
      for (const key in accounts) {
        const account = accounts[key];
        if (account.uid === caregiverUid && account.userType === 'caregiver') {
          caregiverKey = key;
          caregiverData = account;
          break;
        }
      }
      
      if (!caregiverKey) {
        return { success: false, error: "Caregiver not found" };
      }

      // Remove elderly from caregiver's assignments (only update elderlyId/elderlyIds)
      const caregiverRef = ref(database, `Account/${caregiverKey}`);
      let updatedElderlyIds = caregiverData.elderlyIds || [];
      updatedElderlyIds = updatedElderlyIds.filter(id => id !== elderlyUid);
      
      const updateData = {
        elderlyIds: updatedElderlyIds
      };
      
      // If this was the primary elderly, update elderlyId
      if (caregiverData.elderlyId === elderlyUid) {
        updateData.elderlyId = updatedElderlyIds.length > 0 ? updatedElderlyIds[0] : null;
      }
      
      await update(caregiverRef, updateData);

      return {
        success: true,
        message: "Caregiver removed successfully"
      };
    } catch (error) {
      console.error("Error removing caregiver:", error);
      return {
        success: false,
        error: error.message
      };
    }
  }

  // Debug function to check wallet structure
  static async debugWalletStructure() {
    try {
      const elderlyUser = await getCurrentElderlyUser();
      const walletRef = ref(database, `paymentsubscriptions/${elderlyUser.email}/walletBalance`);
      const snapshot = await get(walletRef);
      
      if (snapshot.exists()) {
        const balance = snapshot.val();
        console.log('Wallet structure found:', {
          path: `paymentsubscriptions/${elderlyUser.email}/walletBalance`,
          balance: balance,
          type: typeof balance
        });
        return {
          success: true,
          data: {
            path: `paymentsubscriptions/${elderlyUser.email}/walletBalance`,
            balance: balance
          }
        };
      } else {
        console.log('No wallet found at path:', `paymentsubscriptions/${elderlyUser.email}/walletBalance`);
        return {
          success: false,
          error: "Wallet not found at expected path"
        };
      }
    } catch (error) {
      return {
        success: false,
        error: error.message
      };
    }
  }
}