import { ref, push, remove, set, onValue, query, orderByChild, equalTo, get } from "firebase/database";
import { database } from "../firebaseConfig";
import { 
  FriendRequestEntity, 
  FriendsEntity, 
  getUserDisplayName 
} from "../entity/shareExperienceEntity";

// Enhanced normalizeEmail function
const normalizeEmail = (email) => {
  if (!email || typeof email !== 'string') {
    console.warn('Invalid email provided to normalizeEmail:', email);
    return ''; // Return empty string instead of undefined/null
  }
  
  // Trim and convert to lowercase first
  const trimmedEmail = email.trim().toLowerCase();
  
  // Replace dots with underscores for Firebase key compatibility
  return trimmedEmail.replace(/\./g, '_');
};

// Helper function to check assignment with flexible matching
const checkAssignment = (assignedValue, elderlyEmail, elderlyUid, elderlyEmailNormalized) => {
  if (!assignedValue) return false;

  const assignedStr = assignedValue.toString().toLowerCase().trim();
  const elderlyEmailLower = elderlyEmail.toLowerCase();
  
  console.log(`      Comparing: "${assignedStr}" with:`);
  console.log(`        - Email: "${elderlyEmailLower}"`);
  console.log(`        - Normalized: "${elderlyEmailNormalized}"`);
  console.log(`        - UID: "${elderlyUid}"`);

  // Exact email match
  if (assignedStr === elderlyEmailLower) {
    console.log(`      ✅ Exact email match!`);
    return true;
  }
  
  // Normalized email match (Firebase key format)
  if (assignedStr === elderlyEmailNormalized) {
    console.log(`      ✅ Normalized email match!`);
    return true;
  }
  
  // UID match
  if (elderlyUid && assignedStr === elderlyUid) {
    console.log(`      ✅ UID match!`);
    return true;
  }
  
  // Partial match (contains email parts)
  if (assignedStr.includes(elderlyEmailLower.replace('.', '_'))) {
    console.log(`      ✅ Partial email match!`);
    return true;
  }

  // Check if assigned value matches the elderly UID format
  if (elderlyUid && assignedStr === elderlyUid.toLowerCase()) {
    console.log(`      ✅ UID case-insensitive match!`);
    return true;
  }

  // Check if this might be a Firebase UID format (alphanumeric, typically 28 chars)
  if (assignedStr.length === 28 && /^[a-zA-Z0-9]+$/.test(assignedStr)) {
    console.log(`      🔍 This looks like a Firebase UID: ${assignedStr}`);
    // We'll assume it's a match if it's a UID format and we don't have a better way to verify
    if (elderlyUid && assignedStr === elderlyUid) {
      console.log(`      ✅ UID format match!`);
      return true;
    }
  }

  console.log(`      ❌ No match`);
  return false;
};

// Helper function to check if user exists in Firebase Account database
const checkUserExistsInFirebase = async (userEmail) => {
  return new Promise((resolve) => {
    const accountsRef = ref(database, "Account");
    
    // First try exact match
    const normalizedEmail = normalizeEmail(userEmail);
    const userRef = ref(database, `Account/${normalizedEmail}`);
    
    onValue(userRef, (snapshot) => {
      const userData = snapshot.val();
      if (userData) {
        console.log(`✅ User exists in Firebase: ${userEmail}`);
        resolve(true);
      } else {
        // If exact match fails, search through all accounts
        onValue(accountsRef, (snapshot) => {
          const allAccounts = snapshot.val() || {};
          const userExists = Object.values(allAccounts).some(account => {
            if (!account || !account.email) return false;
            
            const accountEmailNormalized = normalizeEmail(account.email);
            return accountEmailNormalized === normalizedEmail || 
                   account.email.toLowerCase() === userEmail.toLowerCase();
          });
          
          if (userExists) {
            console.log(`✅ User found in Firebase accounts: ${userEmail}`);
          } else {
            console.log(`❌ User NOT found in Firebase: ${userEmail}`);
          }
          
          resolve(userExists);
        }, { onlyOnce: true });
      }
    }, { onlyOnce: true });
  });
};

export const ShareExperienceController = {
  // Add a new shared experience - PREVENT ANONYMOUS
  addExperience: (experience) => {
    return new Promise((resolve, reject) => {
      // Validate user before posting
      if (!experience.user || experience.user === "anonymous" || experience.user.trim() === "") {
        reject("Invalid user: Cannot post as anonymous");
        return;
      }
      
      // Validate content
      if (!experience.title || !experience.title.trim() || !experience.description || !experience.description.trim()) {
        reject("Title and description are required");
        return;
      }
      
      // Verify user exists in Firebase before posting
      checkUserExistsInFirebase(experience.user).then(userExists => {
        if (!userExists) {
          reject("User not found in system. Cannot post experience.");
          return;
        }
        
        const sharedRef = ref(database, "SharedExperiences");
        const data = {
          user: experience.user,
          title: experience.title.trim(),
          description: experience.description.trim(),
          sharedAt: experience.sharedAt || new Date().toISOString(),
          likes: experience.likes || 0,
          comments: experience.comments || 0,
        };
        push(sharedRef, data)
          .then(() => resolve())
          .catch((err) => reject(err));
      }).catch(err => {
        reject("Error verifying user: " + err);
      });
    });
  },

  // Update an existing experience
  updateExperience: (experience) => {
    return new Promise((resolve, reject) => {
      if (!experience.id) return reject("Experience ID missing");
      const expRef = ref(database, `SharedExperiences/${experience.id}`);
      set(expRef, {
        user: experience.user,
        title: experience.title,
        description: experience.description,
        sharedAt: experience.sharedAt,
        likes: experience.likes || 0,
        comments: experience.comments || 0,
      })
        .then(() => resolve())
        .catch((err) => reject(err));
    });
  },

  // Delete an experience by ID
  deleteExperience: (id) => {
    return new Promise((resolve, reject) => {
      const expRef = ref(database, `SharedExperiences/${id}`);
      remove(expRef)
        .then(() => resolve())
        .catch((err) => reject(err));
    });
  },

  getUserExperiences: (userKey, callback) => {
  const sharedRef = ref(database, "SharedExperiences");
  
  console.log('🔍 Fetching experiences with simplified filter...');
  
  onValue(sharedRef, (experiencesSnapshot) => {
    const data = experiencesSnapshot.val() || {};
    let experiences = Object.entries(data).map(([id, exp]) => ({ id, ...exp }));
    
    console.log('📝 Raw experiences from Firebase:', experiences.length);
    
    // SIMPLIFIED FILTERING - only basic checks
    const validExperiences = experiences.filter(exp => {
      if (!exp || !exp.user) {
        console.log('❌ Filtering out: Missing user', exp?.id);
        return false;
      }
      
      if (!exp.title || !exp.description) {
        console.log('❌ Filtering out: Missing title/description', exp?.id);
        return false;
      }
      
      // Allow posts even if user not in accounts (for demo/testing)
      console.log('✅ Keeping experience:', exp.title, 'by', exp.user);
      return true;
    });
    
    // Apply user filter if specified
    let filteredExperiences = validExperiences;
    if (userKey) {
      const normalizedUserKey = normalizeEmail(userKey);
      filteredExperiences = validExperiences.filter(exp => 
        exp.user === userKey || normalizeEmail(exp.user) === normalizedUserKey
      );
    }
    
    // Sort by date
    filteredExperiences.sort((a, b) => new Date(b.sharedAt || 0) - new Date(a.sharedAt || 0));
    
    console.log('📊 Final results:', {
      totalRaw: experiences.length,
      valid: validExperiences.length,
      filtered: filteredExperiences.length
    });
    
    if (typeof callback === "function") callback(filteredExperiences);
  });
},

  // Enhanced cleanup: Remove anonymous AND non-existent user posts
  cleanupInvalidPosts: () => {
    return new Promise((resolve, reject) => {
      const sharedRef = ref(database, "SharedExperiences");
      const accountsRef = ref(database, "Account");
      
      console.log('🧹 Starting cleanup of invalid posts...');
      
      // First get all accounts
      onValue(accountsRef, (accountsSnapshot) => {
        const allAccounts = accountsSnapshot.val() || {};
        console.log('📋 Accounts for cleanup verification:', Object.keys(allAccounts).length);
        
        // Then get all experiences
        onValue(sharedRef, (experiencesSnapshot) => {
          const data = experiencesSnapshot.val() || {};
          const deletePromises = [];
          let cleanupStats = {
            anonymous: 0,
            missingUser: 0,
            userNotFound: 0,
            emptyContent: 0,
            total: 0
          };
          
          Object.entries(data).forEach(([id, exp]) => {
            if (!exp) {
              deletePromises.push(remove(ref(database, `SharedExperiences/${id}`)));
              cleanupStats.missingUser++;
              return;
            }
            
            // Check for anonymous or empty user
            if (!exp.user || exp.user === "anonymous" || exp.user.trim() === "") {
              deletePromises.push(remove(ref(database, `SharedExperiences/${id}`)));
              cleanupStats.anonymous++;
              return;
            }
            
            // Check for empty content
            if (!exp.title || !exp.title.trim() || !exp.description || !exp.description.trim()) {
              deletePromises.push(remove(ref(database, `SharedExperiences/${id}`)));
              cleanupStats.emptyContent++;
              return;
            }
            
            // Check if user exists in Firebase accounts
            const normalizedUser = normalizeEmail(exp.user);
            const userExists = allAccounts[normalizedUser] !== undefined;
            
            if (!userExists) {
              deletePromises.push(remove(ref(database, `SharedExperiences/${id}`)));
              cleanupStats.userNotFound++;
              return;
            }
          });
          
          cleanupStats.total = deletePromises.length;
          
          Promise.all(deletePromises)
            .then(() => {
              console.log('✅ Cleanup completed:', cleanupStats);
              resolve(cleanupStats);
            })
            .catch((err) => {
              console.error('❌ Cleanup failed:', err);
              reject(err);
            });
        }, { onlyOnce: true });
      }, { onlyOnce: true });
    });
  },

  // Get all accounts
  getAccounts: () => {
    return new Promise((resolve, reject) => {
      const accountsRef = ref(database, "Account");
      onValue(accountsRef, (snapshot) => {
        const data = snapshot.val() || {};
        resolve(data);
      }, (error) => {
        reject(error);
      });
    });
  },

  // [Rest of your methods remain exactly the same - messaging, notifications, friend requests, etc.]
  // Messaging Methods
  sendMessage: (message) => {
    return new Promise((resolve, reject) => {
      const messagesRef = ref(database, "Messages");
      const data = {
        fromUser: message.fromUser,
        toUser: message.toUser,
        content: message.content,
        timestamp: message.timestamp || new Date().toISOString(),
        read: false
      };
      push(messagesRef, data)
        .then(() => resolve())
        .catch((err) => reject(err));
    });
  },

  // Get messages between two users
  getMessages: (user1, user2, callback) => {
    const messagesRef = ref(database, "Messages");
    onValue(messagesRef, (snapshot) => {
      const data = snapshot.val() || {};
      let allMessages = [];
      
      const includedIds = new Set();
      const normalizedUser1 = normalizeEmail(user1);
      const normalizedUser2 = normalizeEmail(user2);
      
      Object.entries(data).forEach(([id, msg]) => {
        if (includedIds.has(id)) return;
        if (!msg || !msg.fromUser || !msg.toUser) return;
        
        const normalizedFrom = normalizeEmail(msg.fromUser);
        const normalizedTo = normalizeEmail(msg.toUser);
        
        const isConversation = 
          (normalizedFrom === normalizedUser1 && normalizedTo === normalizedUser2) ||
          (normalizedFrom === normalizedUser2 && normalizedTo === normalizedUser1);
        
        if (isConversation) {
          allMessages.push({ id, ...msg });
          includedIds.add(id);
        }
      });
      
      allMessages.sort((a, b) => new Date(a.timestamp || 0) - new Date(b.timestamp || 0));
      
      if (typeof callback === "function") callback(allMessages);
    });
  },

  // Get all conversations for a user
  getUserConversations: (userKey, callback) => {
    const messagesRef = ref(database, "Messages");
    onValue(messagesRef, (snapshot) => {
      const data = snapshot.val() || {};
      let messages = Object.entries(data)
        .map(([id, msg]) => ({ id, ...msg }))
        .filter(msg => msg && msg.fromUser && msg.toUser);
      
      const normalizedUserKey = normalizeEmail(userKey);
      const conversationPartners = new Set();
      const conversations = {};
      
      messages.forEach(msg => {
        const normalizedFrom = normalizeEmail(msg.fromUser);
        const normalizedTo = normalizeEmail(msg.toUser);
        
        const isUserInvolved = 
          normalizedFrom === normalizedUserKey || 
          normalizedTo === normalizedUserKey;
        
        if (isUserInvolved) {
          let partner;
          if (normalizedFrom === normalizedUserKey) {
            partner = msg.toUser;
          } else {
            partner = msg.fromUser;
          }
          
          const normalizedPartner = normalizeEmail(partner);
          conversationPartners.add(normalizedPartner);
          
          if (!conversations[normalizedPartner] || new Date(msg.timestamp || 0) > new Date(conversations[normalizedPartner].timestamp || 0)) {
            conversations[normalizedPartner] = {
              ...msg,
              displayPartner: partner
            };
          }
        }
      });
      
      const conversationList = Array.from(conversationPartners).map(normalizedPartner => ({
        partner: conversations[normalizedPartner].displayPartner,
        lastMessage: conversations[normalizedPartner]
      }));
      
      conversationList.sort((a, b) => new Date(b.lastMessage?.timestamp || 0) - new Date(a.lastMessage?.timestamp || 0));
      
      if (typeof callback === "function") callback(conversationList);
    });
  },

  // Mark messages as read
  markMessagesAsRead: (fromUser, toUser) => {
    const messagesRef = ref(database, "Messages");
    onValue(messagesRef, (snapshot) => {
      const data = snapshot.val() || {};
      
      const normalizedFrom = normalizeEmail(fromUser);
      const normalizedTo = normalizeEmail(toUser);
      
      Object.entries(data).forEach(([id, msg]) => {
        if (!msg || !msg.fromUser || !msg.toUser) return;
        
        const normalizedMsgFrom = normalizeEmail(msg.fromUser);
        const normalizedMsgTo = normalizeEmail(msg.toUser);
        
        const isMatch = 
          (normalizedMsgFrom === normalizedFrom && normalizedMsgTo === normalizedTo) && 
          !msg.read;
        
        if (isMatch) {
          const msgRef = ref(database, `Messages/${id}`);
          set(msgRef, { ...msg, read: true });
        }
      });
    }, { onlyOnce: true });
  },

  // ========== NOTIFICATION METHODS ==========
  sendNotification: (notification) => {
    return new Promise((resolve, reject) => {
      const notificationsRef = ref(database, "Notifications");
      const data = {
        toUser: notification.toUser || '',
        fromUser: notification.fromUser || '',
        type: notification.type || 'general',
        title: notification.title || '',
        message: notification.message || '',
        relatedId: notification.relatedId || null,
        timestamp: notification.timestamp || new Date().toISOString(),
        read: false,
        imageUrl: notification.imageUrl || null
      };
      push(notificationsRef, data)
        .then(() => resolve())
        .catch((err) => reject(err));
    });
  },

  getUserNotifications: (userKey, callback) => {
    const notificationsRef = ref(database, "Notifications");
    onValue(notificationsRef, (snapshot) => {
      const data = snapshot.val() || {};
      let notifications = Object.entries(data)
        .map(([id, notif]) => ({ id, ...notif }))
        .filter(notif => notif && notif.toUser);
      
      const normalizedUserKey = normalizeEmail(userKey);
      notifications = notifications.filter(notif => 
        notif.toUser === userKey || normalizeEmail(notif.toUser) === normalizedUserKey
      );
      
      notifications.sort((a, b) => new Date(b.timestamp || 0) - new Date(a.timestamp || 0));
      
      if (typeof callback === "function") callback(notifications);
    });
  },

  markNotificationAsRead: (notificationId) => {
    return new Promise((resolve, reject) => {
      const notificationRef = ref(database, `Notifications/${notificationId}`);
      onValue(notificationRef, (snapshot) => {
        const notification = snapshot.val();
        if (notification) {
          set(notificationRef, {
            ...notification,
            read: true
          })
          .then(() => resolve())
          .catch((err) => reject(err));
        } else {
          reject("Notification not found");
        }
      }, {
        onlyOnce: true
      });
    });
  },

  markAllNotificationsAsRead: (userKey) => {
    return new Promise((resolve, reject) => {
      const notificationsRef = ref(database, "Notifications");
      onValue(notificationsRef, (snapshot) => {
        const data = snapshot.val() || {};
        const updatePromises = [];
        const normalizedUserKey = normalizeEmail(userKey);
        
        Object.entries(data).forEach(([id, notif]) => {
          if (!notif || !notif.toUser) return;
          
          if ((notif.toUser === userKey || normalizeEmail(notif.toUser) === normalizedUserKey) && !notif.read) {
            const notifRef = ref(database, `Notifications/${id}`);
            updatePromises.push(set(notifRef, { ...notif, read: true }));
          }
        });
        
        Promise.all(updatePromises)
          .then(() => resolve())
          .catch((err) => reject(err));
      }, {
        onlyOnce: true
      });
    });
  },

  deleteNotification: (notificationId) => {
    return new Promise((resolve, reject) => {
      const notificationRef = ref(database, `Notifications/${notificationId}`);
      remove(notificationRef)
        .then(() => resolve())
        .catch((err) => reject(err));
    });
  },

  getUnreadNotificationCount: (userKey, callback) => {
    const notificationsRef = ref(database, "Notifications");
    onValue(notificationsRef, (snapshot) => {
      const data = snapshot.val() || {};
      let notifications = Object.entries(data)
        .map(([id, notif]) => ({ id, ...notif }))
        .filter(notif => notif && notif.toUser);
      
      const normalizedUserKey = normalizeEmail(userKey);
      const unreadCount = notifications.filter(notif => 
        (notif.toUser === userKey || normalizeEmail(notif.toUser) === normalizedUserKey) && !notif.read
      ).length;
      
      if (typeof callback === "function") callback(unreadCount);
    });
  },

  // ================== FRIEND REQUESTS ==================
  sendFriendRequest: async (fromUser, toUser) => {
    return new Promise((resolve, reject) => {
      try {
        const requestId = `friendreq_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
        const friendRequest = new FriendRequestEntity(requestId, fromUser, toUser);

        const friendRequestRef = ref(database, `FriendRequests/${requestId}`);
        set(friendRequestRef, friendRequest)
          .then(() => resolve(requestId))
          .catch((err) => reject(err));
      } catch (error) {
        console.error("Error sending friend request:", error);
        reject(error);
      }
    });
  },

  getFriendRequests: (userEmail, callback) => {
    const friendRequestsRef = ref(database, "FriendRequests");
    onValue(friendRequestsRef, (snapshot) => {
      const data = snapshot.val() || {};
      const normalizedUserEmail = normalizeEmail(userEmail);
      
      const requests = Object.entries(data)
        .map(([id, request]) => ({ id, ...request }))
        .filter(request => request && request.fromUser && request.toUser)
        .filter(
          (request) =>
            (request.toUser === userEmail || normalizeEmail(request.toUser) === normalizedUserEmail) && 
            request.status === "pending" ||
            request.fromUser === userEmail || normalizeEmail(request.fromUser) === normalizedUserEmail
        );

      if (typeof callback === "function") callback(requests);
    });
  },

  respondToFriendRequest: async (requestId, status) => {
    return new Promise(async (resolve, reject) => {
      try {
        const requestRef = ref(database, `FriendRequests/${requestId}/status`);
        await set(requestRef, status);

        if (status === "accepted") {
          const requestDataRef = ref(database, `FriendRequests/${requestId}`);
          onValue(requestDataRef, async (snapshot) => {
            const requestData = snapshot.val();
            if (requestData) {
              const friendId = `friend_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
              const friend = new FriendsEntity(
                friendId,
                requestData.fromUser,
                requestData.toUser
              );

              const friendsRef = ref(database, `Friends/${friendId}`);
              await set(friendsRef, friend);
              resolve(true);
            }
          }, { onlyOnce: true });
        } else {
          resolve(true);
        }
      } catch (error) {
        console.error("Error responding to friend request:", error);
        reject(error);
      }
    });
  },

  getFriends: (userEmail, callback) => {
    const friendsRef = ref(database, "Friends");
    onValue(friendsRef, (snapshot) => {
      const data = snapshot.val() || {};
      const normalizedUserEmail = normalizeEmail(userEmail);
      
      const friends = Object.entries(data)
        .map(([id, friend]) => ({ id, ...friend }))
        .filter(friend => friend && friend.user1 && friend.user2)
        .filter(
          (friend) =>
            friend.user1 === userEmail || normalizeEmail(friend.user1) === normalizedUserEmail ||
            friend.user2 === userEmail || normalizeEmail(friend.user2) === normalizedUserEmail
        );

      if (typeof callback === "function") callback(friends);
    });
  },

  getCaregiversForElderly: (elderlyEmail, accounts, callback) => {
    const caregiversList = [];
    const elderlyEmailNormalized = normalizeEmail(elderlyEmail);
    
    console.log("🎯 Searching for caregivers with:", {
      elderlyEmail,
      elderlyEmailNormalized
    });

    const elderlyAccount = accounts[elderlyEmailNormalized];
    const elderlyUid = elderlyAccount ? elderlyAccount.uid : null;
    
    console.log("Elderly UID:", elderlyUid);

    Object.entries(accounts).forEach(([accountKey, accountData]) => {
      if (accountData.userType === "caregiver") {
        console.log(`\n🔍 Checking caregiver: ${accountData.email}`);
        
        let isAssigned = false;
        let assignmentReason = "";

        if (accountData.elderlyId) {
          console.log(`   Checking elderlyId: ${accountData.elderlyId}`);
          if (checkAssignment(accountData.elderlyId, elderlyEmail, elderlyUid, elderlyEmailNormalized)) {
            isAssigned = true;
            assignmentReason = `Assigned caregiver`;
          }
        }

        if (!isAssigned && accountData.elderlyIds && Array.isArray(accountData.elderlyIds)) {
          console.log(`   Checking elderlyIds:`, accountData.elderlyIds);
          accountData.elderlyIds.forEach(elderlyId => {
            if (checkAssignment(elderlyId, elderlyEmail, elderlyUid, elderlyEmailNormalized)) {
              isAssigned = true;
              assignmentReason = `Assigned caregiver`;
            }
          });
        }

        if (!isAssigned && accountData.linkedElders) {
          console.log(`   Checking linkedElders:`, accountData.linkedElders);
          if (Array.isArray(accountData.linkedElders)) {
            accountData.linkedElders.forEach(linkedElder => {
              if (checkAssignment(linkedElder, elderlyEmail, elderlyUid, elderlyEmailNormalized)) {
                isAssigned = true;
                assignmentReason = `Assigned caregiver`;
              }
            });
          } else if (typeof accountData.linkedElders === 'string') {
            if (checkAssignment(accountData.linkedElders, elderlyEmail, elderlyUid, elderlyEmailNormalized)) {
              isAssigned = true;
              assignmentReason = `Assigned caregiver`;
            }
          }
        }

        if (!isAssigned && accountData.linkedElderUids && Array.isArray(accountData.linkedElderUids)) {
          console.log(`   Checking linkedElderUids:`, accountData.linkedElderUids);
          accountData.linkedElderUids.forEach(linkedElderUid => {
            if (checkAssignment(linkedElderUid, elderlyEmail, elderlyUid, elderlyEmailNormalized)) {
              isAssigned = true;
              assignmentReason = `Assigned caregiver`;
            }
          });
        }

        if (!isAssigned && accountData.uidOfElder) {
          console.log(`   Checking uidOfElder: ${accountData.uidOfElder}`);
          if (checkAssignment(accountData.uidOfElder, elderlyEmail, elderlyUid, elderlyEmailNormalized)) {
            isAssigned = true;
            assignmentReason = `Assigned caregiver`;
          }
        }

        if (isAssigned) {
          const fullName = accountData.lastname 
            ? `${accountData.firstname} ${accountData.lastname}`
            : accountData.firstname;
          
          caregiversList.push({
            name: fullName,
            email: accountData.email,
            phoneNum: accountData.phoneNum || "No phone number",
            firstname: accountData.firstname,
            lastname: accountData.lastname,
            uid: accountData.uid,
            key: accountKey,
            assignmentReason: assignmentReason,
            confirmed: true
          });
          
          console.log(`🎉 FOUND CAREGIVER: ${fullName} - ${assignmentReason}`);
        } else {
          console.log(`❌ No assignment found for ${accountData.email}`);
        }
      }
    });
    
    console.log("📋 FINAL CAREGIVERS LIST:", caregiversList);
    
    if (typeof callback === "function") callback(caregiversList);
  },

  searchUsers: async (query, currentUserEmail, accounts) => {
    return new Promise((resolve) => {
      const normalizedQuery = query.toLowerCase().trim();
      
      console.log('=== DEBUG SEARCH START ===');
      console.log('Search query:', query);
      console.log('Current user email:', currentUserEmail);
      console.log('Accounts object keys:', Object.keys(accounts || {}));
      
      if (!accounts || Object.keys(accounts).length === 0) {
        console.log('ERROR: Accounts object is empty or undefined');
        resolve([]);
        return;
      }

      const currentUserAccount = accounts[normalizeEmail(currentUserEmail)];
      
      if (!currentUserAccount) {
        console.log('ERROR: Current user account not found for:', normalizeEmail(currentUserEmail));
        console.log('Available account keys:', Object.keys(accounts));
        resolve([]);
        return;
      }

      const allElderlyUsers = Object.entries(accounts)
        .filter(([emailKey, account]) => account && account.userType === "elderly")
        .map(([emailKey, account]) => ({
          key: emailKey,
          email: account.email,
          firstName: account.firstname,
          lastName: account.lastname,
          userType: account.userType
        }));
      
      console.log('Elderly users found:', allElderlyUsers);

      const searchResults = Object.entries(accounts)
        .filter(([emailKey, account]) => {
          if (!account) return false;
          
          if (emailKey === normalizeEmail(currentUserEmail)) {
            return false;
          }

          if (account.userType !== "elderly") {
            return false;
          }

          return true;
        })
        .filter(([emailKey, account]) => {
          if (!normalizedQuery) {
            return true;
          }

          const firstName = (account.firstname || "").toLowerCase();
          const lastName = (account.lastname || "").toLowerCase();
          const fullName = `${firstName} ${lastName}`.toLowerCase().trim();
          const email = (account.email || "").toLowerCase();

          const matches = (
            firstName.includes(normalizedQuery) ||
            lastName.includes(normalizedQuery) ||
            fullName.includes(normalizedQuery) ||
            email.includes(normalizedQuery)
          );
          
          return matches;
        })
        .map(([emailKey, account]) => {
          const displayName = `${account.firstname || ''} ${account.lastname || ''}`.trim() || account.email;
          
          return {
            email: account.email,
            key: emailKey,
            name: displayName,
            userType: account.userType,
            firstName: account.firstname,
            lastName: account.lastname
          };
        });

      resolve(searchResults);
    });
  },

  checkFriendshipStatus: async (user1, user2) => {
    return new Promise((resolve) => {
      const friendsRef = ref(database, "Friends");
      onValue(friendsRef, (snapshot) => {
        const data = snapshot.val() || {};
        const normalizedUser1 = normalizeEmail(user1);
        const normalizedUser2 = normalizeEmail(user2);
        
        const isFriend = Object.values(data).some(friend => 
          friend && friend.user1 && friend.user2 && (
            (friend.user1 === user1 || normalizeEmail(friend.user1) === normalizedUser1) && 
            (friend.user2 === user2 || normalizeEmail(friend.user2) === normalizedUser2) ||
            (friend.user1 === user2 || normalizeEmail(friend.user1) === normalizedUser2) && 
            (friend.user2 === user1 || normalizeEmail(friend.user2) === normalizedUser1)
          )
        );
        resolve(isFriend);
      }, { onlyOnce: true });
    });
  },

  checkPendingRequest: async (fromUser, toUser) => {
    return new Promise((resolve) => {
      const friendRequestsRef = ref(database, "FriendRequests");
      onValue(friendRequestsRef, (snapshot) => {
        const data = snapshot.val() || {};
        const normalizedFrom = normalizeEmail(fromUser);
        const normalizedTo = normalizeEmail(toUser);
        
        const hasPending = Object.values(data).some(request => 
          request && request.fromUser && request.toUser &&
          (request.fromUser === fromUser || normalizeEmail(request.fromUser) === normalizedFrom) && 
          (request.toUser === toUser || normalizeEmail(request.toUser) === normalizedTo) && 
          request.status === 'pending'
        );
        resolve(hasPending);
      }, { onlyOnce: true });
    });
  },

  // ===================== COMMENT METHODS =====================
  addComment: (comment) => {
    return new Promise((resolve, reject) => {
      const commentsRef = ref(database, "Comments");
      const data = {
        experienceId: comment.experienceId,
        userId: comment.userId,
        content: comment.content,
        timestamp: comment.timestamp || new Date().toISOString(),
        userName: comment.userName || null,
      };
      push(commentsRef, data)
        .then(() => {
          const expRef = ref(database, `SharedExperiences/${comment.experienceId}`);
          get(expRef).then((snapshot) => {
            const experience = snapshot.val();
            if (experience) {
              const newCommentCount = (experience.comments || 0) + 1;
              set(expRef, {
                ...experience,
                comments: newCommentCount
              }).then(() => resolve())
                .catch((err) => reject(err));
            } else {
              resolve();
            }
          });
        })
        .catch((err) => reject(err));
    });
  },

  getExperienceComments: (experienceId, callback) => {
    const commentsRef = ref(database, "Comments");
    onValue(commentsRef, (snapshot) => {
      const data = snapshot.val() || {};
      const comments = Object.entries(data)
        .map(([id, comment]) => ({ id, ...comment }))
        .filter(comment => comment.experienceId === experienceId)
        .sort((a, b) => new Date(a.timestamp || 0) - new Date(b.timestamp || 0));
      
      if (typeof callback === "function") callback(comments);
    });
  },

  toggleLike: (experienceId, userId, currentLikes, isCurrentlyLiked) => {
    return new Promise((resolve, reject) => {
      const expRef = ref(database, `SharedExperiences/${experienceId}`);
      
      get(expRef).then((snapshot) => {
        const experience = snapshot.val();
        if (!experience) {
          reject("Experience not found");
          return;
        }

        const newLikes = isCurrentlyLiked ? 
          Math.max(0, (experience.likes || 0) - 1) : 
          (experience.likes || 0) + 1;

        set(expRef, {
          ...experience,
          likes: newLikes
        }).then(() => resolve({ newLikes, liked: !isCurrentlyLiked }))
          .catch((err) => reject(err));
      }).catch((err) => reject(err));
    });
  },

  getUserLikeStatus: (experienceId, userId, callback) => {
    const likesRef = ref(database, "Likes");
    onValue(likesRef, (snapshot) => {
      const data = snapshot.val() || {};
      const userLike = Object.values(data).find(
        like => like.experienceId === experienceId && like.userId === userId
      );
      if (typeof callback === "function") callback(!!userLike);
    });
  },
};