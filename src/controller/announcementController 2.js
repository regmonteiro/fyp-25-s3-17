// src/controller/announcementController.js
import { database } from '../firebaseConfig';
import { ref, get, push, set } from 'firebase/database';

export async function fetchAllAnnouncements() {
  const announcementsRef = ref(database, 'Announcements');
  const snapshot = await get(announcementsRef);
  if (!snapshot.exists()) return [];

  const data = snapshot.val();
  return Object.entries(data).map(([id, value]) => ({
    id,
    ...value,
  })).sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt));
}

export async function createAnnouncement({ title, description, userGroups }) {
  const announcementsRef = ref(database, 'Announcements');
  const newRef = push(announcementsRef);
  const newAnnouncement = {
    title,
    description,
    userGroups,
    createdAt: new Date().toISOString(),
  };
  await set(newRef, newAnnouncement);
  return { id: newRef.key, ...newAnnouncement };
}
