// firebase.js
import { initializeApp } from "firebase/app";
import { getAnalytics } from "firebase/analytics";
import { getDatabase, ref, push } from "firebase/database";
import { getStorage } from "firebase/storage";
import { getAuth } from "firebase/auth";
import { getFirestore } from "firebase/firestore";
import { getStorage, ref as storageRef, uploadBytes, getDownloadURL } from "firebase/storage";

// Your Firebase configuration
const firebaseConfig = {
  apiKey: "AIzaSyDst5g_tOob8aTDeKejRNVEY-JXQUB6hy0",
  authDomain: "elderly-aiassistant.firebaseapp.com",
  projectId: "elderly-aiassistant",
  storageBucket: "elderly-aiassistant.appspot.com",
  messagingSenderId: "598007516552",
  appId: "1:598007516552:web:6d1e98e2d21686d187fe3d",
  measurementId: "G-54B83PF5YV"
};

// Initialize Firebase
const app = initializeApp(firebaseConfig);
const analytics = getAnalytics(app);
const database = getDatabase(app);
const storage = getStorage(app);
const auth = getAuth(app);
const firestore = getFirestore(app);

export { database, ref, push, storage, auth, firestore };
