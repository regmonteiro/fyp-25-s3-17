
// Import the functions you need from the SDKs you need
import { initializeApp } from "firebase/app";
import { getAnalytics } from "firebase/analytics";
import { getFirestore } from "firebase/firestore";
import { getDatabase, ref, push } from "firebase/database";
// TODO: Add SDKs for Firebase products that you want to use
// https://firebase.google.com/docs/web/setup#available-libraries
// For Firebase JS SDK v7.20.0 and later, measurementId is optional
const firebaseConfig = {
  apiKey: "AIzaSyDl_h8LybxEHbRSuuiaiHlivFbQJ5Z0oFU",
  authDomain: "allcarefyp25s322.firebaseapp.com",
  projectId: "allcarefyp25s322",
  storageBucket: "allcarefyp25s322.firebasestorage.app",
  messagingSenderId: "536170693927",
  appId: "1:536170693927:web:802b554b886eb86fa2d502",
  measurementId: "G-1S0LMCM8TY"
};
 
// Initialize Firebase
const app = initializeApp(firebaseConfig);
const analytics = getAnalytics(app);
const database = getDatabase(app);   // Initialize database here
export { database, ref, push };
