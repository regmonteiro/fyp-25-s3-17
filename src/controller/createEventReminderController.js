import { database, ref, push, get, onValue, remove, set } from "../firebaseConfig";
import { EventReminder } from "../entity/createEventReminderEntity";

export const createReminder = async (userKey, reminderData) => {
  const reminder = new EventReminder(reminderData);
  if (!reminder.isValid()) {
    throw new Error("Invalid reminder data");
  }

  const remindersRef = ref(database, `reminders/${userKey}`);
  await push(remindersRef, reminder);
};

export const subscribeToReminders = (userKey, callback) => {
  const remindersRef = ref(database, `reminders/${userKey}`);

  const unsubscribe = onValue(remindersRef, (snapshot) => {
    const data = snapshot.val();
    if (data) {
      const reminders = Object.entries(data).map(([id, value]) => ({
        id,
        ...value,
      }));
      reminders.sort((a, b) => new Date(a.startTime) - new Date(b.startTime));
      callback(reminders);
    } else {
      callback([]);
    }
  });

  return unsubscribe;
};

export const deleteReminder = async (userKey, reminderId) => {
  const reminderRef = ref(database, `reminders/${userKey}/${reminderId}`);
  await remove(reminderRef);
};

export const updateReminder = async (userKey, reminderId, updatedData) => {
  const reminderRef = ref(database, `reminders/${userKey}/${reminderId}`);
  const updatedReminder = new EventReminder({
    ...updatedData,
    createdAt: new Date().toISOString(),
  });

  if (!updatedReminder.isValid()) {
    throw new Error("Invalid reminder data");
  }

  // Use set here instead of push to update existing node
  await set(reminderRef, updatedReminder);
};

export const getReminders = async (userKey) => {
  const remindersRef = ref(database, `reminders/${userKey}`);
  const snapshot = await get(remindersRef);
  if (snapshot.exists()) {
    const data = snapshot.val();
    return Object.entries(data)
      .map(([id, value]) => ({
        id,
        ...value,
      }))
      .sort((a, b) => new Date(a.startTime) - new Date(b.startTime));
  }
  return [];
};

export const getReminderById = async (userKey, reminderId) => {
  const reminderRef = ref(database, `reminders/${userKey}/${reminderId}`);
  const snapshot = await get(reminderRef);
  if (snapshot.exists()) {
    return { id: reminderId, ...snapshot.val() };
  }
  return null;
};
