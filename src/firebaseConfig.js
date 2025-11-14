// Import the functions you need from the SDKs you need
import { initializeApp } from "firebase/app";
import { getAnalytics } from "firebase/analytics";
import { getFirestore} from "firebase/firestore";
import { getDatabase, ref, push, get, onValue, remove, update, set } from "firebase/database";
import { getAuth } from "firebase/auth";


// TODO: Add SDKs for Firebase products that you want to use
// https://firebase.google.com/docs/web/setup#available-libraries
// Your web app's Firebase configuration
// For Firebase JS SDK v7.20.0 and later, measurementId is optional
const firebaseConfig = {
  apiKey: "AIzaSyDst5g_tOob8aTDeKejRNVEY-JXQUB6hy0",
  authDomain: "elderly-aiassistant.firebaseapp.com",
  projectId: "elderly-aiassistant",
  storageBucket: "elderly-aiassistant.appspot.com",
  messagingSenderId: "598007516552",
  appId: "1:598007516552:web:6d1e98e2d21686d187fe3d",
  measurementId: "G-54B83PF5YV",
  databaseURL: "https://elderly-aiassistant-default-rtdb.asia-southeast1.firebasedatabase.app"
};
// Initialize Firebase
const app = initializeApp(firebaseConfig);
const analytics = getAnalytics(app);
const database = getDatabase(app);   // Initialize database here
const firestore = getFirestore(app);
export { database, ref, push, get, onValue, remove,update, set };
export { firestore};
export const auth = getAuth(app);

