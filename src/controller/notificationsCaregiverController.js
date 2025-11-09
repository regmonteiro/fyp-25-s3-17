import { 
  ref, 
  push, 
  remove, 
  set, 
  onValue, 
  off,
  update, 
  get, 
  query, 
  orderByChild, 
  equalTo 
} from "firebase/database";
import { database } from "../firebaseConfig";

// Format user ID for Firebase key (replace . with _)
const formatUserId = (userId) => {
  return userId ? userId.replace(/\./g, '_') : '';
};

// Enhanced function to fetch elderly data using identifier (email or UID)
const fetchElderlyData = async (elderlyIdentifier) => {
  try {
    let elderlyRef;
    
    // Check if identifier is an email (contains @)
    if (elderlyIdentifier.includes('@')) {
      const key = formatUserId(elderlyIdentifier);
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
      id: elderlyIdentifier.includes('@') ? formatUserId(elderlyIdentifier) : elderlyIdentifier,
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
    'elderlyIds',        // Array of emails/UIDs
    'linkedElderUids',   // Array of UIDs
    'linkedElders',      // Array of UIDs
    'elderlyId',         // Single email/UID
    'uidOfElder',        // Single UID
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

// Active monitoring intervals storage
const activeMonitors = new Map();

// Get notifications for a user with real-time updates
const fetchNotificationsForUser = async (userId) => {
  try {
    const notificationsRef = ref(database, `Notifications`);
    const snapshot = await get(notificationsRef);
    
    if (!snapshot.exists()) {
      return [];
    }
    
    const notificationsData = snapshot.val();
    const userNotifications = Object.entries(notificationsData)
      .map(([id, data]) => ({
        id,
        ...data,
        timestamp: data.timestamp ? new Date(data.timestamp) :
                  data.createdAt ? new Date(data.createdAt) : new Date()
      }))
      .filter(notif => notif.toUser === userId)
      .sort((a, b) => b.timestamp - a.timestamp);
    
    return userNotifications;
  } catch (error) {
    console.error("Error fetching notifications:", error);
    return [];
  }
};

// Real-time listener for notifications
const getCaregiverNotifications = (userId, callback) => {
  const notificationsRef = ref(database, "Notifications");
  
  const handleData = (snapshot) => {
    if (!snapshot.exists()) {
      callback([]);
      return;
    }
    
    const notificationsData = snapshot.val();
    const notificationsArray = Object.entries(notificationsData)
      .map(([id, data]) => ({
        id,
        ...data,
        timestamp: data.timestamp ? new Date(data.timestamp) : 
                  data.createdAt ? new Date(data.createdAt) : new Date()
      }))
      .filter(notif => notif.toUser === userId)
      .sort((a, b) => b.timestamp - a.timestamp);
    
    callback(notificationsArray);
  };
  
  onValue(notificationsRef, handleData);
  
  // Return cleanup function (not a Promise)
  return () => {
    off(notificationsRef, 'value', handleData);
  };
};

// Real-time unread count listener
const getUnreadNotificationCount = (userId, callback) => {
  const notificationsRef = ref(database, "Notifications");
  
  const handleData = (snapshot) => {
    if (!snapshot.exists()) {
      callback(0);
      return;
    }
    
    const notificationsData = snapshot.val();
    const unreadCount = Object.values(notificationsData)
      .filter(notif => notif.toUser === userId && !notif.read)
      .length;
    
    callback(unreadCount);
  };
  
  onValue(notificationsRef, handleData);
  
  // Return cleanup function (not a Promise)
  return () => {
    off(notificationsRef, 'value', handleData);
  };
};

// Mark notification as read
const markNotificationAsRead = async (notificationId) => {
  try {
    const notificationRef = ref(database, `Notifications/${notificationId}`);
    await update(notificationRef, {
      read: true,
      readAt: new Date().toISOString()
    });
  } catch (error) {
    console.error("Error marking notification as read:", error);
    throw error;
  }
};

// Mark all notifications as read
const markAllNotificationsAsRead = async (userId) => {
  try {
    const notificationsRef = ref(database, `Notifications`);
    const snapshot = await get(notificationsRef);
    
    if (!snapshot.exists()) {
      return;
    }
    
    const updates = {};
    Object.entries(snapshot.val()).forEach(([id, notif]) => {
      if (notif.toUser === userId && !notif.read) {
        updates[`${id}/read`] = true;
        updates[`${id}/readAt`] = new Date().toISOString();
      }
    });
    
    if (Object.keys(updates).length > 0) {
      await update(notificationsRef, updates);
    }
  } catch (error) {
    console.error("Error marking all notifications as read:", error);
    throw error;
  }
};

// Delete a notification
const deleteNotification = async (notificationId) => {
  try {
    const notificationRef = ref(database, `Notifications/${notificationId}`);
    await set(notificationRef, null);
  } catch (error) {
    console.error("Error deleting notification:", error);
    throw error;
  }
};

// Create a new notification for caregiver
const sendNotification = async (notification) => {
  try {
    const notificationsRef = ref(database, `Notifications`);
    const newNotificationRef = push(notificationsRef);
    
    const notificationData = {
      id: newNotificationRef.key,
      ...notification,
      read: false,
      createdAt: new Date().toISOString(),
      timestamp: new Date().toISOString()
    };
    
    await set(newNotificationRef, notificationData);
    
    // Trigger browser notification if supported
    if ('Notification' in window && Notification.permission === 'granted') {
      new Notification(notification.title, {
        body: notification.message,
        icon: '/favicon.ico',
        tag: notification.id
      });
    }
    
    return notificationData;
  } catch (error) {
    console.error("Error creating notification:", error);
    throw error;
  }
};

// Request browser notification permission
const requestNotificationPermission = async () => {
  if ('Notification' in window) {
    const permission = await Notification.requestPermission();
    return permission === 'granted';
  }
  return false;
};

// Helper function to get elderly name from Account data
const getElderlyName = async (elderlyId) => {
  try {
    const elderlyData = await fetchElderlyData(elderlyId);
    return elderlyData.name;
  } catch (error) {
    console.error("Error getting elderly name:", error);
    return elderlyId.replace(/_/g, '.');
  }
};

// ===== ENHANCED MONITORING SYSTEM =====

// Monitor medication reminders with multiple alerts
const setupMedicationMonitoring = (elderlyId, caregiverId) => {
  const formattedElderlyId = formatUserId(elderlyId);
  const remindersRef = ref(database, `medicationReminders/${formattedElderlyId}`);
  
  const checkMedicationTimes = async (reminders) => {
    if (!reminders) return;
    
    const now = new Date();
    const currentTime = now.getHours() * 60 + now.getMinutes();
    
    for (const [reminderId, reminder] of Object.entries(reminders)) {
      if (reminder.reminderTime && reminder.date) {
        const [hours, minutes] = reminder.reminderTime.split(':').map(Number);
        const reminderTimeInMinutes = hours * 60 + minutes;
        
        const reminderDate = new Date(reminder.date);
        const today = new Date();
        const isToday = reminderDate.toDateString() === today.toDateString();
        
        if (!isToday) continue;
        
        const timeDiff = currentTime - reminderTimeInMinutes;
        
        if (timeDiff >= -30 && timeDiff < -29 && !reminder.notified30MinBefore) {
          await sendMedicationNotification(
            caregiverId, 
            elderlyId, 
            { ...reminder, id: reminderId },
            '30_min_before'
          );
          
          await update(ref(database, `medicationReminders/${formattedElderlyId}/${reminderId}`), {
            notified30MinBefore: true
          });
        }
        
        if (timeDiff >= 0 && timeDiff < 1 && !reminder.notifiedAtTime) {
          await sendMedicationNotification(
            caregiverId, 
            elderlyId, 
            { ...reminder, id: reminderId },
            'at_time'
          );
          
          await update(ref(database, `medicationReminders/${formattedElderlyId}/${reminderId}`), {
            notifiedAtTime: true
          });
        }
        
        if (timeDiff > 15 && timeDiff < 1440 && !reminder.notifiedMissed) {
          await sendMissedMedicationNotification(
            caregiverId, 
            elderlyId, 
            { ...reminder, id: reminderId },
            timeDiff
          );
          
          await update(ref(database, `medicationReminders/${formattedElderlyId}/${reminderId}`), {
            notifiedMissed: true
          });
        }
      }
    }
  };
  
  // Set up real-time listener
  const unsubscribe = onValue(remindersRef, (snapshot) => {
    if (snapshot.exists()) {
      const reminders = snapshot.val();
      checkMedicationTimes(reminders);
    }
  });
  
  // Set up interval for precise timing
  const intervalId = setInterval(() => {
    get(remindersRef).then(snapshot => {
      if (snapshot.exists()) {
        checkMedicationTimes(snapshot.val());
      }
    });
  }, 60000);
  
  // Return cleanup function (not a Promise)
  return () => {
    unsubscribe();
    clearInterval(intervalId);
  };
};

// Monitor appointments with multiple alerts
const setupAppointmentMonitoring = (elderlyId, caregiverId) => {
  const appointmentsRef = ref(database, 'Appointments');
  
  const checkAppointmentTimes = async (appointments) => {
    if (!appointments) return;
    
    const now = new Date();
    const currentTime = now.getTime();
    
    for (const [appointmentId, appointment] of Object.entries(appointments)) {
      const isElderlyAppointment = 
        appointment.elderlyId === elderlyId || 
        appointment.elderlyEmail === elderlyId;
      
      if (isElderlyAppointment && appointment.date && appointment.time) {
        const appointmentDateTime = new Date(`${appointment.date}T${appointment.time}`);
        const timeDiff = appointmentDateTime.getTime() - currentTime;
        const timeDiffMinutes = timeDiff / (1000 * 60);
        
        if (timeDiffMinutes > 29 && timeDiffMinutes <= 30 && !appointment.notified30MinBefore) {
          await sendAppointmentNotification(
            caregiverId,
            elderlyId,
            { ...appointment, id: appointmentId },
            '30_min_before'
          );
          
          await update(ref(database, `Appointments/${appointmentId}`), {
            notified30MinBefore: true
          });
        }
        
        if (timeDiffMinutes >= -1 && timeDiffMinutes <= 1 && !appointment.notifiedAtTime) {
          await sendAppointmentNotification(
            caregiverId,
            elderlyId,
            { ...appointment, id: appointmentId },
            'at_time'
          );
          
          await update(ref(database, `Appointments/${appointmentId}`), {
            notifiedAtTime: true
          });
        }
        
        if (timeDiffMinutes < -15 && timeDiffMinutes > -1440 && !appointment.notifiedMissed) {
          await sendAppointmentNotification(
            caregiverId,
            elderlyId,
            { ...appointment, id: appointmentId },
            'missed'
          );
          
          await update(ref(database, `Appointments/${appointmentId}`), {
            notifiedMissed: true
          });
        }
      }
    }
  };
  
  const unsubscribe = onValue(appointmentsRef, (snapshot) => {
    if (snapshot.exists()) {
      const appointments = snapshot.val();
      checkAppointmentTimes(appointments);
    }
  });
  
  const intervalId = setInterval(() => {
    get(appointmentsRef).then(snapshot => {
      if (snapshot.exists()) {
        checkAppointmentTimes(snapshot.val());
      }
    });
  }, 60000);
  
  // Return cleanup function (not a Promise)
  return () => {
    unsubscribe();
    clearInterval(intervalId);
  };
};

// Enhanced medication notification with different types
const sendMedicationNotification = async (caregiverId, elderlyId, medicationData, notificationType) => {
  const elderlyName = await getElderlyName(elderlyId);
  
  let title, message, priority, alarm = false;
  
  switch (notificationType) {
    case '30_min_before':
      title = 'Medication Reminder Soon';
      message = `${elderlyName} has medication scheduled in 30 minutes: ${medicationData.medicationName}`;
      priority = 'medium';
      break;
      
    case 'at_time':
      title = 'Medication Time!';
      message = `${elderlyName} needs to take ${medicationData.medicationName} now`;
      priority = 'high';
      alarm = true;
      break;
      
    default:
      title = 'Medication Reminder';
      message = `${elderlyName} needs to take ${medicationData.medicationName}`;
      priority = 'medium';
  }
  
  return sendNotification({
    toUser: caregiverId,
    title,
    message,
    type: 'medication',
    priority,
    alarm,
    elderlyId: elderlyId,
    elderlyName: elderlyName,
    details: {
      medicationName: medicationData.medicationName,
      dosage: medicationData.dosage,
      scheduledTime: medicationData.reminderTime,
      medicationId: medicationData.id,
      notificationType: notificationType
    }
  });
};

// Enhanced missed medication notification
const sendMissedMedicationNotification = async (caregiverId, elderlyId, medicationData, minutesLate) => {
  const elderlyName = await getElderlyName(elderlyId);
  const priority = minutesLate > 60 ? 'critical' : 'high';
  
  return sendNotification({
    toUser: caregiverId,
    title: 'Medication Missed',
    message: `${elderlyName} missed ${medicationData.medicationName} (${Math.floor(minutesLate)} minutes late)`,
    type: 'medication_missed',
    priority: priority,
    alarm: minutesLate <= 30,
    elderlyId: elderlyId,
    elderlyName: elderlyName,
    details: {
      medicationName: medicationData.medicationName,
      dosage: medicationData.dosage,
      scheduledTime: medicationData.reminderTime,
      minutesLate: Math.floor(minutesLate),
      medicationId: medicationData.id
    }
  });
};

// Appointment notification function
const sendAppointmentNotification = async (caregiverId, elderlyId, appointmentData, notificationType) => {
  const elderlyName = await getElderlyName(elderlyId);
  
  let title, message, priority, alarm = false;
  
  switch (notificationType) {
    case '30_min_before':
      title = 'Appointment Reminder Soon';
      message = `${elderlyName} has an appointment in 30 minutes: ${appointmentData.title}`;
      priority = 'medium';
      break;
      
    case 'at_time':
      title = 'Appointment Time!';
      message = `${elderlyName} has an appointment now: ${appointmentData.title}`;
      priority = 'high';
      alarm = true;
      break;
      
    case 'missed':
      title = 'Appointment Missed';
      message = `${elderlyName} missed their appointment: ${appointmentData.title}`;
      priority = 'critical';
      alarm = true;
      break;
      
    default:
      title = 'Appointment Reminder';
      message = `${elderlyName} has an appointment: ${appointmentData.title}`;
      priority = 'medium';
  }
  
  return sendNotification({
    toUser: caregiverId,
    title,
    message,
    type: 'appointment',
    priority,
    alarm,
    elderlyId: elderlyId,
    elderlyName: elderlyName,
    details: {
      appointmentTitle: appointmentData.title,
      scheduledTime: `${appointmentData.date} ${appointmentData.time}`,
      location: appointmentData.location,
      notes: appointmentData.notes,
      appointmentId: appointmentData.id,
      notificationType: notificationType
    }
  });
};

// Reset notification flags for new day
const resetDailyNotificationFlags = async () => {
  try {
    // Reset medication reminders
    const medicationRef = ref(database, 'medicationReminders');
    const medicationSnapshot = await get(medicationRef);
    
    if (medicationSnapshot.exists()) {
      const updates = {};
      Object.entries(medicationSnapshot.val()).forEach(([elderlyId, reminders]) => {
        Object.keys(reminders).forEach(reminderId => {
          updates[`${elderlyId}/${reminderId}/notified30MinBefore`] = false;
          updates[`${elderlyId}/${reminderId}/notifiedAtTime`] = false;
          updates[`${elderlyId}/${reminderId}/notifiedMissed`] = false;
        });
      });
      
      if (Object.keys(updates).length > 0) {
        await update(medicationRef, updates);
      }
    }
    
    // Reset appointments
    const appointmentsRef = ref(database, 'Appointments');
    const appointmentsSnapshot = await get(appointmentsRef);
    
    if (appointmentsSnapshot.exists()) {
      const updates = {};
      Object.entries(appointmentsSnapshot.val()).forEach(([appointmentId, appointment]) => {
        updates[`${appointmentId}/notified30MinBefore`] = false;
        updates[`${appointmentId}/notifiedAtTime`] = false;
        updates[`${appointmentId}/notifiedMissed`] = false;
      });
      
      if (Object.keys(updates).length > 0) {
        await update(appointmentsRef, updates);
      }
    }
    
    console.log('Daily notification flags reset successfully');
  } catch (error) {
    console.error('Error resetting daily notification flags:', error);
  }
};

// Initialize all monitoring for a caregiver - FIXED VERSION
const initializeCaregiverMonitoring = (caregiverId) => {
  // Clean up existing monitors
  if (activeMonitors.has(caregiverId)) {
    const cleanup = activeMonitors.get(caregiverId);
    if (typeof cleanup === 'function') {
      cleanup();
    }
    activeMonitors.delete(caregiverId);
  }
  
  try {
    // Get caregiver account data
    const formattedCaregiverId = formatUserId(caregiverId);
    const caregiverRef = ref(database, `Account/${formattedCaregiverId}`);
    
    const unsubscribeCaregiver = onValue(caregiverRef, async (snapshot) => {
      if (!snapshot.exists()) {
        return;
      }
      
      const caregiverData = snapshot.val();
      const elderlyIdentifiers = getAllElderlyIdentifiersFromCaregiver(caregiverData);
      
      console.log(`Setting up monitoring for ${elderlyIdentifiers.length} elderly users`);
      
      const cleanupFunctions = [];
      
      for (const elderlyIdentifier of elderlyIdentifiers) {
        try {
          const elderlyData = await fetchElderlyData(elderlyIdentifier);
          const elderlyUid = elderlyData.uid || elderlyData.id;
          
          // Setup monitoring for each type of event
          const medicationUnsubscribe = setupMedicationMonitoring(elderlyUid, caregiverId);
          const appointmentUnsubscribe = setupAppointmentMonitoring(elderlyUid, caregiverId);
          
          cleanupFunctions.push(medicationUnsubscribe);
          cleanupFunctions.push(appointmentUnsubscribe);
          
          console.log(`Monitoring setup for elderly: ${elderlyData.name}`);
        } catch (error) {
          console.error(`Error setting up monitoring for elderly ${elderlyIdentifier}:`, error);
        }
      }
      
      // Store cleanup function
      const cleanup = () => {
        unsubscribeCaregiver();
        cleanupFunctions.forEach(cleanupFn => {
          if (typeof cleanupFn === 'function') {
            cleanupFn();
          }
        });
      };
      
      activeMonitors.set(caregiverId, cleanup);
    });
    
    // Return cleanup function for this specific initialization
    return () => {
      unsubscribeCaregiver();
      if (activeMonitors.has(caregiverId)) {
        const cleanup = activeMonitors.get(caregiverId);
        if (typeof cleanup === 'function') {
          cleanup();
        }
        activeMonitors.delete(caregiverId);
      }
    };
    
  } catch (error) {
    console.error("Error initializing caregiver monitoring:", error);
    // Return a no-op function if initialization fails
    return () => {};
  }
};

// Stop monitoring for a caregiver
const stopCaregiverMonitoring = (caregiverId) => {
  if (activeMonitors.has(caregiverId)) {
    const cleanup = activeMonitors.get(caregiverId);
    if (typeof cleanup === 'function') {
      cleanup();
    }
    activeMonitors.delete(caregiverId);
    console.log(`Stopped monitoring for caregiver: ${caregiverId}`);
  }
};

// Play alarm sound
const playAlarmSound = () => {
  const audio = new Audio('/sounds/alarm.mp3');
  audio.play().catch(e => console.log('Audio play failed:', e));
};

// Export as object with all methods
const NotificationsCaregiverController = {
  // Core notification methods
  fetchNotificationsForUser,
  getCaregiverNotifications,
  getUnreadNotificationCount,
  markNotificationAsRead,
  markAllNotificationsAsRead,
  deleteNotification,
  sendNotification,
  requestNotificationPermission,
  
  // Specific notification types
  sendMedicationNotification,
  sendMissedMedicationNotification,
  sendAppointmentNotification,
  
  // Monitoring functions
  setupMedicationMonitoring,
  setupAppointmentMonitoring,
  initializeCaregiverMonitoring,
  stopCaregiverMonitoring,
  resetDailyNotificationFlags,
  
  // Helper functions
  getElderlyName,
  formatUserId,
  playAlarmSound,
  
  // New helper functions for UID handling
  fetchElderlyData,
  getAllElderlyIdentifiersFromCaregiver
};

export default NotificationsCaregiverController;

// Setup daily reset at midnight
setInterval(() => {
  const now = new Date();
  if (now.getHours() === 0 && now.getMinutes() === 0) {
    resetDailyNotificationFlags();
  }
}, 60000);

// Initial reset
resetDailyNotificationFlags();