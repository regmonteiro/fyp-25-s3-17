// src/controller/safetyController.js
import { database } from '../firebaseConfig';
import { ref, get, set, push, update } from 'firebase/database';

const SAFETY_PATH = 'SafetyMeasures';

export async function fetchSafetyMeasures() {
  const snapshot = await get(ref(database, SAFETY_PATH));
  if (!snapshot.exists()) return [];

  const data = snapshot.val();
  return Object.entries(data).map(([id, item]) => ({ id, ...item }));
}

export async function saveSafetyMeasure({ title, description, parameters, createdBy }) {
  const now = new Date().toISOString();
  const newData = {
    title,
    description,
    parameters,
    createdBy,
    createdAt: now,
    lastUpdatedAt: now,
  };

  const newRef = push(ref(database, SAFETY_PATH));
  await set(newRef, newData);

  return { id: newRef.key, ...newData };
}
