// src/controller/announcementController.js
import { database } from '../firebaseConfig';
import { ref, get, push, set, onValue, update } from 'firebase/database';

/**
 * Fetch all announcements
 */
export async function fetchAllAnnouncements() {
  const announcementsRef = ref(database, 'Announcements');
  const snapshot = await get(announcementsRef);
  if (!snapshot.exists()) return [];

  const data = snapshot.val();
  return Object.entries(data)
    .map(([id, value]) => ({ id, ...value }))
    .sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt));
}

/**
 * Fetch announcements for a specific user type
 */
export async function fetchAnnouncementsForUser(userType) {
  try {
    const allAnnouncements = await fetchAllAnnouncements();
    
    // Filter announcements for the user's type or "all users" (with or without space)
    const filtered = allAnnouncements.filter(a => {
      if (!a.userGroups) {
        return false;
      }
      
      // Check for "all users" with or without trailing space
      const isForAllUsers = a.userGroups.some(group => 
        group.trim().toLowerCase() === "all users"
      );
      
      const isForUserType = a.userGroups.includes(userType);
      
      return isForAllUsers || isForUserType;
    });
    
    return filtered;
  } catch (error) {
    console.error("Error in fetchAnnouncementsForUser:", error);
    return [];
  }
}

/**
 * Get count of unread announcements for a user
 */
export async function getUnreadCount(uid, userType) {
  try {
    const announcements = await fetchAnnouncementsForUser(userType);
    const unreadAnnouncements = announcements.filter(a => !a.readBy || !a.readBy[uid]);
    return unreadAnnouncements.length;
  } catch (error) {
    console.error("Error in getUnreadCount:", error);
    return 0;
  }
}

/**
 * Listen to new announcements for a user in real-time
 */
export function listenToNewAnnouncements(userType, callback) {
  if (typeof callback !== 'function') {
    console.error('Callback is not a function');
    return () => {}; // Return empty unsubscribe function
  }
  
  const announcementsRef = ref(database, 'Announcements');
  return onValue(announcementsRef, async (snapshot) => {
    if (!snapshot.exists()) {
      callback([]);
      return;
    }
    
    const data = Object.entries(snapshot.val())
      .map(([id, value]) => ({ id, ...value }));
    
    // Filter for the user's type
    const filteredData = data.filter(a => {
      if (!a.userGroups) return false;
      
      // Check for "all users" with or without trailing space
      const isForAllUsers = a.userGroups.some(group => 
        group.trim().toLowerCase() === "all users"
      );
      
      return isForAllUsers || a.userGroups.includes(userType);
    });
    
    callback(filteredData);
  });
}

/**
 * Mark a specific announcement as read for a user
 */
export async function markAnnouncementRead(uid, announcementId) {
  const announcementRef = ref(database, `Announcements/${announcementId}/readBy/${uid}`);
  await set(announcementRef, true);
}

/**
 * Create a new announcement
 */
export async function createAnnouncement({ title, description, userGroups }) {
  const announcementsRef = ref(database, 'Announcements');
  const newRef = push(announcementsRef);
  const newAnnouncement = {
    title,
    description,
    userGroups,
    createdAt: new Date().toISOString(),
    readBy: {},
  };
  await set(newRef, newAnnouncement);
  return { id: newRef.key, ...newAnnouncement };
}