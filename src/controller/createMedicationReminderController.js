import { database, ref, push, get, onValue, remove, set } from "../firebaseConfig";
import { MedicationReminder } from "../entity/createMedicationReminderEntity";

// Create reminder for a specific elderly
export const createMedicationReminder = async (elderlyId, reminderData) => {
  const reminder = new MedicationReminder({
    elderlyId,
    ...reminderData
  });
  
  if (!reminder.isValid()) {
    throw new Error("Invalid medication reminder data");
  }

  const remindersRef = ref(database, `medicationReminders/${elderlyId}`);
  await push(remindersRef, reminder);
};

// Subscribe to medication reminders
export const subscribeToMedicationReminders = (encodedElderlyId, callback) => {
  const remindersRef = ref(database, `medicationReminders/${encodedElderlyId}`);
  return onValue(remindersRef, (snapshot) => {
    const data = snapshot.val();
    const reminders = data ? Object.keys(data).map(key => ({
      id: key,
      ...data[key]
    })) : [];
    
    // Sort by date, time, and completion status (pending first)
    reminders.sort((a, b) => {
      // Show pending medications first
      if (a.isCompleted !== b.isCompleted) {
        return a.isCompleted ? 1 : -1;
      }
      
      const dateA = new Date(`${a.date}T${a.reminderTime}`);
      const dateB = new Date(`${b.date}T${b.reminderTime}`);
      return dateA - dateB;
    });
    
    callback(reminders);
  });
};

// Delete reminder
export const deleteMedicationReminder = async (elderlyId, reminderId) => {
  const reminderRef = ref(database, `medicationReminders/${elderlyId}/${reminderId}`);
  await remove(reminderRef);
};

// Toggle completion status
export const toggleMedicationCompletion = async (elderlyId, reminderId, isCompleted, notes = '') => {
  const reminderRef = ref(database, `medicationReminders/${elderlyId}/${reminderId}`);
  
  // Get existing reminder data
  const snapshot = await get(reminderRef);
  if (!snapshot.exists()) {
    throw new Error("Reminder not found");
  }

  const existingData = snapshot.val();
  const updatedData = {
    ...existingData,
    isCompleted: isCompleted,
    completedAt: isCompleted ? new Date().toISOString() : null,
    intakeTime: isCompleted ? new Date().toISOString() : null,
    notes: isCompleted ? notes : ''
  };

  await set(reminderRef, updatedData);
};

// Update reminder
export const updateMedicationReminder = async (elderlyId, reminderId, updatedData) => {
  const reminderRef = ref(database, `medicationReminders/${elderlyId}/${reminderId}`);
  
  const existingSnapshot = await get(reminderRef);
  const existingData = existingSnapshot.exists() ? existingSnapshot.val() : {};
  
  const updatedReminder = new MedicationReminder({
    ...existingData,
    ...updatedData,
    elderlyId: existingData.elderlyId || elderlyId
  });

  if (!updatedReminder.isValid()) {
    throw new Error("Invalid medication reminder data");
  }

  await set(reminderRef, updatedReminder);
};

// Get all reminders for elderly
export const getMedicationReminders = async (elderlyId) => {
  const remindersRef = ref(database, `medicationReminders/${elderlyId}`);
  const snapshot = await get(remindersRef);
  if (snapshot.exists()) {
    const data = snapshot.val();
    return Object.entries(data)
      .map(([id, value]) => ({
        id,
        ...value,
      }))
      .sort((a, b) => {
        if (a.isCompleted !== b.isCompleted) {
          return a.isCompleted ? 1 : -1;
        }
        const dateA = new Date(`${a.date}T${a.reminderTime}`);
        const dateB = new Date(`${b.date}T${b.reminderTime}`);
        return dateA - dateB;
      });
  }
  return [];
};

// Get reminder by ID
export const getMedicationReminderById = async (elderlyId, reminderId) => {
  const reminderRef = ref(database, `medicationReminders/${elderlyId}/${reminderId}`);
  const snapshot = await get(reminderRef);
  if (snapshot.exists()) {
    return { id: reminderId, ...snapshot.val() };
  }
  return null;
};

// Get today's medications
export const getTodaysMedications = async (elderlyId) => {
  const today = new Date().toISOString().split('T')[0];
  const reminders = await getMedicationReminders(elderlyId);
  return reminders.filter(reminder => reminder.date === today);
};

// Get today's pending medications
export const getTodaysPendingMedications = async (elderlyId) => {
  const today = new Date().toISOString().split('T')[0];
  const reminders = await getMedicationReminders(elderlyId);
  return reminders.filter(reminder => 
    reminder.date === today && !reminder.isCompleted
  );
};

// Get completed medications count for today
export const getTodaysCompletedMedications = async (elderlyId) => {
  const today = new Date().toISOString().split('T')[0];
  const reminders = await getMedicationReminders(elderlyId);
  return reminders.filter(reminder => 
    reminder.date === today && reminder.isCompleted
  ).length;
};

// Get medications by date range
export const getMedicationsByDateRange = async (elderlyId, startDate, endDate) => {
  const reminders = await getMedicationReminders(elderlyId);
  return reminders.filter(reminder => {
    return reminder.date >= startDate && reminder.date <= endDate;
  });
};

// Get all medication reminders across all elderly (for admin purposes)
export const getAllMedicationReminders = async () => {
  const remindersRef = ref(database, 'medicationReminders');
  const snapshot = await get(remindersRef);
  
  if (snapshot.exists()) {
    const data = snapshot.val();
    const allReminders = [];
    
    Object.keys(data).forEach(elderlyId => {
      Object.keys(data[elderlyId]).forEach(reminderId => {
        allReminders.push({
          id: reminderId,
          elderlyId,
          ...data[elderlyId][reminderId]
        });
      });
    });
    
    return allReminders.sort((a, b) => {
      if (a.isCompleted !== b.isCompleted) {
        return a.isCompleted ? 1 : -1;
      }
      const dateA = new Date(`${a.date}T${a.reminderTime}`);
      const dateB = new Date(`${b.date}T${b.reminderTime}`);
      return dateA - dateB;
    });
  }
  
  return [];
};