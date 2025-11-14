import { ref, push, set, onValue, remove, get, query, orderByChild, equalTo } from "firebase/database";
import { database } from "../firebaseConfig";
import { getUserDisplayName } from "../entity/shareExperienceEntity";
import NotificationsCaregiverController from "./notificationsCaregiverController";

const normalizeEmail = (email) => email.replace(/\./g, "_");

// Enhanced function to fetch elderly data using identifier (email or UID)
const fetchElderlyData = async (elderlyIdentifier) => {
  try {
    let elderlyRef;
    
    // Check if identifier is an email (contains @)
    if (elderlyIdentifier.includes('@')) {
      const key = normalizeEmail(elderlyIdentifier);
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
      id: elderlyIdentifier.includes('@') ? normalizeEmail(elderlyIdentifier) : elderlyIdentifier,
      identifier: elderlyIdentifier,
      name: `${elderly.firstname || ''} ${elderly.lastname || ''}`.trim() || 'Unknown Elderly',
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
    'elderlyIds',        
    
    'elderlyId',         
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

export const CaregiverMessagingController = {
  // Get all accounts from database
  getAccounts: () => {
    return new Promise((resolve, reject) => {
      const accountsRef = ref(database, "Account");
      onValue(
        accountsRef,
        (snapshot) => {
          const accounts = snapshot.val() || {};
          console.log("📋 All accounts loaded:", Object.keys(accounts).length);
          resolve(accounts);
        },
        (error) => reject(error),
        { onlyOnce: true }
      );
    });
  },

  // Get elderly users assigned to a caregiver - handles both email and UID identifiers
  getElderlyForCaregiver: async (caregiverEmail, accounts, callback) => {
    try {
      const caregiverKey = normalizeEmail(caregiverEmail);
      const caregiverAccount = accounts[caregiverKey];

      if (!caregiverAccount) {
        console.warn('Caregiver account not found:', caregiverEmail);
        if (typeof callback === "function") callback([]);
        return;
      }

      // Get all elderly identifiers from caregiver data
      const elderlyIdentifiers = getAllElderlyIdentifiersFromCaregiver(caregiverAccount);
      
      console.log('Processing elderly identifiers for caregiver:', elderlyIdentifiers);

      const elderlyList = [];

      // Fetch data for each elderly identifier
      for (const elderlyIdentifier of elderlyIdentifiers) {
        try {
          const elderlyData = await fetchElderlyData(elderlyIdentifier);
          
          elderlyList.push({
            email: elderlyData.email,
            uid: elderlyData.uid,
            key: elderlyData.uid || normalizeEmail(elderlyData.email),
            name: elderlyData.name,
            userType: 'elderly',
            firstname: elderlyData.name.split(' ')[0] || '',
            lastname: elderlyData.name.split(' ').slice(1).join(' ') || '',
          });
        } catch (error) {
          console.error(`Error fetching data for elderly ${elderlyIdentifier}:`, error);
          // Continue with next elderly even if one fails
        }
      }

      console.log('Final elderly list for caregiver:', elderlyList);
      
      if (typeof callback === "function") callback(elderlyList);
    } catch (error) {
      console.error('Error in getElderlyForCaregiver:', error);
      if (typeof callback === "function") callback([]);
    }
  },

  extractMessageText: (content) => {
    if (!content) return "";
    if (typeof content === "string") {
      try {
        const parsed = JSON.parse(content);
        return parsed.content || content;
      } catch (e) {
        return content;
      }
    }
    if (typeof content === "object") return content.content || JSON.stringify(content);
    return String(content);
  },

  // Send a message and create notification
  sendMessage: async (message, accounts) => {
    try {
      const messagesRef = ref(database, "Messages");
      const messageData = {
        fromUser: normalizeEmail(message.fromUser),
        toUser: normalizeEmail(message.toUser),
        content: JSON.stringify({
          content: message.content,
          attachments: message.attachments || [],
        }),
        timestamp: message.timestamp || new Date().toISOString(),
        read: false,
      };

      const newMessageRef = await push(messagesRef, messageData);

      // Create notification for the recipient
      await CaregiverMessagingController.createMessageNotification(
        {
          ...messageData,
          id: newMessageRef.key,
          content: message.content,
        },
        accounts
      );

      return newMessageRef;
    } catch (error) {
      console.error("Error sending message:", error);
      throw error;
    }
  },

  // Create message notification - FIXED VERSION
createMessageNotification: async (message, accounts) => {
  try {
    const senderName = CaregiverMessagingController.getSenderName(message.fromUser, accounts);
    const notificationContent =
      message.content.length > 50 ? `${message.content.substring(0, 50)}...` : message.content;

    const notification = {
      title: "New Message",
      message: `${senderName}: ${notificationContent}`,
      type: "message",
      priority: "medium",
      timestamp: new Date().toISOString(),
      read: false,
      source: "messaging",
      senderEmail: message.fromUser,
      recipientEmail: message.toUser,
      messageId: message.id,
      elderlyName: senderName,
    };

    // Get recipient email in Firebase format
    const recipientKey = message.toUser; // Already normalized

    // Use the correct function from NotificationsCaregiverController
    await NotificationsCaregiverController.sendNotification(notification);

    console.log("📢 Message notification created for:", recipientKey);
  } catch (error) {
    console.error("Error creating message notification:", error);
  }
},

  // Get sender name from accounts
  getSenderName: (email, accounts) => {
    try {
      const senderKey = normalizeEmail(email);
      const senderAccount = accounts[senderKey];

      if (senderAccount) {
        return (
          getUserDisplayName(email, accounts) ||
          `${senderAccount.firstname || ""} ${senderAccount.lastname || ""}`.trim() ||
          "Unknown User"
        );
      }

      // If not found in accounts, try to find by searching all accounts for UID
      const allAccounts = Object.values(accounts);
      const accountByUid = allAccounts.find(account => account.uid === email);
      if (accountByUid) {
        return `${accountByUid.firstname || ""} ${accountByUid.lastname || ""}`.trim() || "Unknown User";
      }

      return "Unknown User";
    } catch (error) {
      console.error('Error getting sender name:', error);
      return "Unknown User";
    }
  },

  // Get messages between caregiver and elderly with notification creation
  getMessages: (caregiverEmail, elderlyEmail, callback, accounts) => {
    const messagesRef = ref(database, "Messages");
    const normalizedCaregiver = normalizeEmail(caregiverEmail);
    const normalizedElderly = normalizeEmail(elderlyEmail);

    const unsubscribe = onValue(messagesRef, (snapshot) => {
      const data = snapshot.val() || {};
      const messages = Object.entries(data)
        .map(([id, msg]) => ({
          id,
          ...msg,
          content: CaregiverMessagingController.extractMessageText(msg.content),
        }))
        .filter(
          (msg) =>
            (normalizeEmail(msg.fromUser) === normalizedCaregiver &&
              normalizeEmail(msg.toUser) === normalizedElderly) ||
            (normalizeEmail(msg.fromUser) === normalizedElderly &&
              normalizeEmail(msg.toUser) === normalizedCaregiver)
        )
        .sort((a, b) => new Date(a.timestamp) - new Date(b.timestamp));

      // Create notifications for unread messages from elderly
      messages.forEach((msg) => {
        if (!msg.read && normalizeEmail(msg.fromUser) === normalizedElderly) {
          CaregiverMessagingController.createMessageNotification(
            {
              ...msg,
              content: CaregiverMessagingController.extractMessageText(msg.content),
            },
            accounts
          );
        }
      });

      if (typeof callback === "function") callback(messages);
    });

    return unsubscribe;
  },

  markMessagesAsRead: (fromUser, toUser) => {
    return new Promise((resolve, reject) => {
      const messagesRef = ref(database, "Messages");
      const normalizedFrom = normalizeEmail(fromUser);
      const normalizedTo = normalizeEmail(toUser);

      onValue(
        messagesRef,
        (snapshot) => {
          const data = snapshot.val() || {};
          const updates = [];

          Object.entries(data).forEach(([id, msg]) => {
            if (
              normalizeEmail(msg.fromUser) === normalizedFrom &&
              normalizeEmail(msg.toUser) === normalizedTo &&
              !msg.read
            ) {
              updates.push(set(ref(database, `Messages/${id}`), { ...msg, read: true }));
            }
          });

          if (updates.length > 0) {
            Promise.all(updates).then(resolve).catch(reject);
          } else {
            resolve();
          }
        },
        { onlyOnce: true }
      );
    });
  },

  deleteMessage: (messageId) => remove(ref(database, `Messages/${messageId}`)),

  // Verify access for both email and UID identifiers
  verifyCaregiverAccess: (caregiverEmail, elderlyEmail, accounts) => {
    try {
      const caregiverKey = normalizeEmail(caregiverEmail);
      const caregiverAccount = accounts[caregiverKey];
      
      if (!caregiverAccount) {
        console.warn('Caregiver account not found:', caregiverEmail);
        return false;
      }

      // Get all elderly identifiers from caregiver
      const elderlyIdentifiers = getAllElderlyIdentifiersFromCaregiver(caregiverAccount);
      
      // Check if the elderly email/UID is in the caregiver's list
      const hasAccess = elderlyIdentifiers.some(identifier => {
        // Direct match
        if (identifier === elderlyEmail) return true;
        
        // If elderlyEmail is an email, check if it matches any identifier's email
        if (elderlyEmail.includes('@')) {
          const elderlyAccount = accounts[normalizeEmail(elderlyEmail)];
          if (elderlyAccount && elderlyAccount.uid === identifier) return true;
        }
        
        // If elderlyEmail is a UID, check if it matches any identifier
        if (!elderlyEmail.includes('@')) {
          const elderlyAccount = Object.values(accounts).find(acc => acc.uid === elderlyEmail);
          if (elderlyAccount && identifier === elderlyAccount.email) return true;
          if (elderlyAccount && identifier === elderlyAccount.uid) return true;
        }
        
        return false;
      });

      console.log(`Access verification for ${caregiverEmail} -> ${elderlyEmail}:`, hasAccess);
      return hasAccess;
    } catch (error) {
      console.error('Error verifying caregiver access:', error);
      return false;
    }
  },

  // Helper function to get elderly user by UID
  getElderlyByUid: async (uid) => {
    try {
      const accountsRef = ref(database, 'Account');
      const queryRef = query(accountsRef, orderByChild('uid'), equalTo(uid));
      const snapshot = await get(queryRef);
      
      if (snapshot.exists()) {
        const elderlyData = snapshot.val();
        const elderlyKey = Object.keys(elderlyData)[0];
        return elderlyData[elderlyKey];
      }
      return null;
    } catch (error) {
      console.error('Error getting elderly by UID:', error);
      return null;
    }
  }
};