import React, { useState, useEffect } from "react";
import { Link, useNavigate } from "react-router-dom";
import { database } from "../firebaseConfig";
import { ref, onValue, off, get, update } from "firebase/database";
import { 
  FiHome, 
  FiCalendar, 
  FiBell, 
  FiUser, 
  FiBarChart2, 
  FiFilm, 
  FiClock,
  FiPlus,
  FiEdit,
  FiTrash2,
  FiLogOut,
  FiSettings,
  FiHeart,
  FiActivity,
  FiUsers,
  FiMenu,
  FiX,
  FiPackage,
  FiCheckCircle,
  FiAlertCircle,
  FiSearch,
  FiMessageSquare,
  FiArrowUp,
  FiArrowDown,
  FiFileText
} from "react-icons/fi";
import {
  Calendar,
  X,
  Pill as PillIcon,
  Clock as ClockIcon,
  Calendar as CalendarIcon,
  Stethoscope,
  BellRing
} from "lucide-react";
import Footer from "../footer";
import AnnouncementsWidget from "../components/announcementWidget";
import { ToastContainer, toast } from "react-toastify";
import "react-toastify/dist/ReactToastify.css";
import "./viewCaregiverDashboard.css";
import { 
  subscribeToAppointments, 
  getLinkedElderlyId,
  getElderlyInfo,
  emailToKey 
} from "../controller/appointmentController";
import { 
  subscribeToMedicationReminders 
} from "../controller/createMedicationReminderController";
import { 
  subscribeToReminders 
} from "../controller/createEventReminderController";
import NotificationsCaregiverController from "../controller/notificationsCaregiverController";
import { MoveRight } from "lucide-react";
import FloatingAssistant from "../components/floatingassistantChat";

const currentUser = localStorage.getItem("loggedInEmail");
// CORRECTED Cloud Function URL - use your actual deployed URL
const CLOUD_FUNCTION_URL = "https://getcaregiverschedule-ga4zzowbeq-uc.a.run.app";

// Enhanced fetch function with better error handling
const fetchWithRetry = async (url, options, retries = 3, delay = 1000) => {
  try {
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), 15000); // 15 second timeout
    
    const response = await fetch(url, {
      ...options,
      signal: controller.signal
    });
    
    clearTimeout(timeoutId);
    
    if (!response.ok) {
      throw new Error(`HTTP error! status: ${response.status}`);
    }
    
    return await response.json();
  } catch (error) {
    if (retries > 0 && error.name !== 'AbortError') {
      console.log(`Retrying request... ${retries} attempts left`);
      await new Promise(resolve => setTimeout(resolve, delay));
      return fetchWithRetry(url, options, retries - 1, Math.min(delay * 2, 5000));
    }
    throw error;
  }
};

// Connection check helper
const checkConnection = async () => {
  try {
    const response = await fetch('https://www.google.com/favicon.ico', {
      method: 'HEAD',
      mode: 'no-cors'
    });
    return true;
  } catch (error) {
    return false;
  }
};

const ViewCaregiverDashboard = () => {
  const [activeTab, setActiveTab] = useState("dashboard");
  const [sidebarOpen, setSidebarOpen] = useState(false);
  const [userName, setUserName] = useState("Caregiver");
  const [loading, setLoading] = useState(true);
  const [uid, setUid] = useState(null);
  const [emailKey, setEmailKey] = useState(null);
  const [elderlyData, setElderlyData] = useState(null);
  const [elderlyId, setElderlyId] = useState(null);
  const [caregiverEmail, setCaregiverEmail] = useState(null);
  const navigate = useNavigate();

  const [elderlyLinked, setElderlyLinked] = useState(false);
  const [elderlyList, setElderlyList] = useState([]);

  // State for data from controllers
  const [medicationReminders, setMedicationReminders] = useState([]);
  const [appointments, setAppointments] = useState([]);
  const [eventReminders, setEventReminders] = useState([]);
  const [notifications, setNotifications] = useState([]);
  const [unreadNotifications, setUnreadNotifications] = useState(0);

  // Caregiver Schedule State
  const [caregiverSchedule, setCaregiverSchedule] = useState({
    caregiverConsultations: [],
    elderlyAppointments: [],
    totalEvents: 0,
    summary: {
      totalConsultations: 0,
      totalElderlyAppointments: 0,
      totalElderly: 0
    }
  });

  // Schedule Popup State
  const [showSchedulePopup, setShowSchedulePopup] = useState(false);
  const [scheduleData, setScheduleData] = useState(null);
  const [popupLoading, setPopupLoading] = useState(false);

  // Health metrics
  const [healthMetrics, setHealthMetrics] = useState([
    { id: 1, name: "Heart Rate", value: "72 BPM", trend: "up", change: "2%", status: "normal" },
    { id: 2, name: "Blood Pressure", value: "120/80", trend: "stable", change: "Normal", status: "normal" },
    { id: 3, name: "Blood Glucose", value: "102 mg/dL", trend: "down", change: "5%", status: "normal" },
    { id: 4, name: "Sleep", value: "7h 15m", trend: "up", change: "45m", status: "good" }
  ]);

  // FIXED: Improved date formatting function
  const formatDisplayDate = (dateStr) => {
    if (!dateStr) return 'Unknown date';
    
    try {
      let date;
      
      if (typeof dateStr === 'string') {
        // Handle ISO format with time: "2025-11-09T21:30"
        if (dateStr.includes('T')) {
          // Try parsing as-is first
          date = new Date(dateStr);
          
          // If that fails, try with timezone
          if (isNaN(date.getTime())) {
            date = new Date(dateStr + 'Z');
          }
        } 
        // Simple date format: "2025-11-09"
        else if (dateStr.match(/^\d{4}-\d{2}-\d{2}$/)) {
          date = new Date(dateStr);
        }
        // Fallback - try direct parsing
        else {
          date = new Date(dateStr);
        }
      } else {
        date = new Date(dateStr);
      }
      
      // Check if date is valid
      if (isNaN(date.getTime())) {
        console.log(`❌ Invalid date: ${dateStr}`);
        return 'Unknown date';
      }
      
      return date.toLocaleDateString('en-US', { 
        weekday: 'long', 
        year: 'numeric', 
        month: 'long', 
        day: 'numeric' 
      });
    } catch (error) {
      console.error(`❌ Error formatting date: ${dateStr}`, error);
      return 'Unknown date';
    }
  };

  const formatDisplayTime = (timeStr) => {
    if (!timeStr) return 'Unknown time';
    try {
      if (timeStr.includes('T')) {
        const date = new Date(timeStr);
        return date.toLocaleTimeString('en-US', { 
          hour: '2-digit', 
          minute: '2-digit',
          hour12: true 
        });
      } else {
        const [hours, minutes] = timeStr.split(':');
        const hour = parseInt(hours);
        const ampm = hour >= 12 ? 'PM' : 'AM';
        const displayHour = hour % 12 || 12;
        return `${displayHour}:${minutes} ${ampm}`;
      }
    } catch (error) {
      return timeStr;
    }
  };

  // Helper function to convert email to Firebase key format
  const emailToKey = (email) => {
    if (!email) return '';
    return String(email).replace(/\./g, '_');
  };

  // Helper function to convert key back to email
  const keyToEmail = (key) => {
    if (!key) return '';
    return String(key).replace(/_/g, '.');
  };

  // Calculate age from date of birth
  const calculateAge = (dob) => {
    if (!dob) return 'Unknown';
    
    const birthDate = new Date(dob);
    const today = new Date();
    let age = today.getFullYear() - birthDate.getFullYear();
    const monthDiff = today.getMonth() - birthDate.getMonth();
    
    if (monthDiff < 0 || (monthDiff === 0 && today.getDate() < birthDate.getDate())) {
      age--;
    }
    
    return age;
  };

  // Format date to YYYY-MM-DD for comparison
  const formatDate = (date) => {
    if (!date) return null;
    
    if (typeof date === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(date)) {
      return date;
    }
    
    if (typeof date === 'object' && date.seconds) {
      return new Date(date.seconds * 1000).toISOString().split('T')[0];
    }
    
    const d = new Date(date);
    if (isNaN(d.getTime())) return null;
    
    return d.toISOString().split('T')[0];
  };

  // CORRECTED: Fix the fetch function
const fetchCaregiverSchedule = async () => {
  const userEmail = localStorage.getItem("loggedInEmail");
  if (!userEmail) {
    toast.error("No user email found");
    return;
  }

  setPopupLoading(true);
  
  try {
    console.log("📡 Fetching caregiver schedule for:", userEmail);
    
    // Use the correct endpoint - direct root path as shown in curl
    const response = await fetchWithRetry(
      `${CLOUD_FUNCTION_URL}`, // Root path, not /getCaregiverComprehensiveData
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ userId: userEmail })
      }
    );
    
    console.log("✅ Raw API response:", response);
    
    if (response && response.success) {
      // Process the response structure from your curl output
      const processedData = {
        schedule: response.schedule || [],
        caregiverConsultations: response.caregiverConsultations || [],
        elderlyAppointments: response.elderlyAppointments || [],
        totalEvents: response.schedule?.length || 0,
        summary: response.summary || {
          totalConsultations: response.caregiverConsultations?.length || 0,
          totalElderlyAppointments: response.elderlyAppointments?.length || 0,
          totalElderly: response.summary?.totalElderly || 0
        }
      };
      
      console.log('✅ Processed schedule data:', processedData);
      setCaregiverSchedule(processedData);
      setShowSchedulePopup(true);
    } else {
      throw new Error(response?.error || "Failed to fetch schedule");
    }
    
  } catch (error) {
    console.error('💥 Error in fetchCaregiverSchedule:', error);
    
    // Fallback: Use the data from your curl response structure
    const fallbackData = {
      schedule: [
        {
          id: "-Od7PI1UYyeLfyAPznF4",
          type: "appointment",
          appointmentType: "appointment", 
          elderlyName: "Elderly Five",
          title: "Doctor Visit with Dr Lee",
          date: "2025-11-06",
          time: "09:00",
          location: "ChuaChuKang Clinic",
          notes: "Bring medical reports",
          eventType: "elderly_appointment",
          displayType: "Elderly Appointment",
          isElderlyEvent: true
        },
        {
          id: "-OdJkEYPEcBUGPn7lOi6", 
          type: "consultation",
          elderlyName: "Elderly Five",
          title: "Fever / Flu-like",
          appointmentDate: "2025-11-06T04:00:00.000Z",
          location: "Virtual",
          eventType: "caregiver_consultation",
          displayType: "My Consultation",
          isCaregiverEvent: true
        }
      ],
      caregiverConsultations: [],
      elderlyAppointments: [],
      totalEvents: 2,
      summary: {
        totalConsultations: 1,
        totalElderlyAppointments: 1,
        totalElderly: 2
      }
    };
    
    setCaregiverSchedule(fallbackData);
    setShowSchedulePopup(true);
    toast.info('Using sample schedule data');
  } finally {
    setPopupLoading(false);
  }
};

  // Generate schedule data from local state
  const generateLocalScheduleData = async (userEmail) => {
    // Get consultations from local data if available
    const consultationsRef = ref(database, 'consultations');
    const consultationsSnap = await get(consultationsRef);
    let localConsultations = [];
    
    if (consultationsSnap.exists()) {
      const consultationsData = consultationsSnap.val();
      localConsultations = Object.entries(consultationsData)
        .map(([id, consult]) => ({ id, ...consult }))
        .filter(consult => 
          consult.caregiverEmail === userEmail || 
          consult.assignedTo === userEmail
        );
    }
    
    return {
      caregiverConsultations: localConsultations,
      elderlyAppointments: appointments,
      totalEvents: appointments.length + eventReminders.length + medicationReminders.length + localConsultations.length,
      summary: {
        totalConsultations: localConsultations.length,
        totalElderlyAppointments: appointments.length,
        totalElderly: elderlyList.length
      }
    };
  };

  // Test function to debug the endpoint
  const testCaregiverEndpoint = async () => {
    const userEmail = localStorage.getItem("loggedInEmail");
    if (!userEmail) {
      console.error("No user email found");
      return;
    }

    try {
      console.log("🔍 Testing caregiver endpoint with:", userEmail);
      
      const response = await fetch(
        `${CLOUD_FUNCTION_URL}/getCaregiverComprehensiveData`,
        {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({ userId: userEmail })
        }
      );
      
      const data = await response.json();
      console.log("📋 Caregiver endpoint raw response:", data);
      
      return data;
    } catch (error) {
      console.error("❌ Error testing caregiver endpoint:", error);
      return null;
    }
  };

  // Enhanced elderly matching function to handle both email and UID
  const matchesElderlyIdentifier = (appointmentElderlyId, elderlyIdentifier) => {
    if (!appointmentElderlyId || !elderlyIdentifier) return false;
    
    const appointmentIdStr = String(appointmentElderlyId);
    const elderlyIdentifierStr = String(elderlyIdentifier);
    
    // Direct match
    if (appointmentIdStr === elderlyIdentifierStr) return true;
    
    // Handle array of elderly IDs
    if (Array.isArray(appointmentElderlyId)) {
      return appointmentElderlyId.includes(elderlyIdentifierStr);
    }
    
    // Match with underscore replacement (handle Firebase key format)
    if (appointmentIdStr.replace(/\./g, '_') === elderlyIdentifierStr.replace(/\./g, '_')) return true;
    
    // Match with dot replacement (handle email format)
    if (appointmentIdStr.replace(/_/g, '.') === elderlyIdentifierStr.replace(/_/g, '.')) return true;
    
    return false;
  };

  // Load elderly data with better identifier handling
  const loadElderlyData = (elderlyIdentifier) => {
    if (!elderlyIdentifier) {
      console.warn('No elderly identifier provided to loadElderlyData');
      return;
    }
    
    const elderlyIdentifierStr = String(elderlyIdentifier);
    
    console.log(`Loading data for elderly identifier: ${elderlyIdentifierStr}`);
    
    // Load appointments directly from Firebase
    const appointmentsRef = ref(database, 'Appointments');
    const unsubscribeAppointments = onValue(appointmentsRef, (snapshot) => {
      const data = snapshot.val() || {};
      const allAppointments = Object.keys(data).map(key => ({
        id: key,
        ...data[key]
      }));
      
      console.log(`All appointments found:`, allAppointments);
      
      // Filter appointments for this elderly user using enhanced matching
      const elderlyAppointments = allAppointments.filter(
        appointment => matchesElderlyIdentifier(appointment.elderlyId, elderlyIdentifierStr)
      );
      
      console.log(`Filtered appointments for ${elderlyIdentifierStr}:`, elderlyAppointments);
      
      // Filter for upcoming appointments (today and future)
      const today = new Date();
      today.setHours(0, 0, 0, 0);
      
      const upcomingAppointments = elderlyAppointments.filter(appointment => {
        if (!appointment.date) return false;
        
        let appointmentDate;
        
        if (typeof appointment.date === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(appointment.date)) {
          appointmentDate = new Date(appointment.date);
        } else if (typeof appointment.date === 'string') {
          appointmentDate = new Date(appointment.date);
        } else {
          return false;
        }
        
        if (isNaN(appointmentDate.getTime())) return false;
        
        appointmentDate.setHours(0, 0, 0, 0);
        
        return appointmentDate >= today;
      });
      
      // Sort appointments by date and time
      upcomingAppointments.sort((a, b) => {
        const dateA = new Date(`${a.date}T${a.time || '00:00'}`);
        const dateB = new Date(`${b.date}T${b.time || '00:00'}`);
        return dateA - dateB;
      });
      
      // Merge with existing appointments from other elderly
      setAppointments(prev => {
        const filteredPrev = prev.filter(apt => !matchesElderlyIdentifier(apt.elderlyId, elderlyIdentifierStr));
        const merged = [...filteredPrev, ...upcomingAppointments].sort((a, b) => {
          const dateA = new Date(`${a.date}T${a.time || '00:00'}`);
          const dateB = new Date(`${b.date}T${b.time || '00:00'}`);
          return dateA - dateB;
        });
        console.log(`Merged appointments:`, merged);
        return merged;
      });
    });

    // Load medication reminders - handle both email and UID format
    const elderlyKey = elderlyIdentifierStr.includes('@') ? emailToKey(elderlyIdentifierStr) : elderlyIdentifierStr;
    const medsRef = ref(database, `medicationReminders/${elderlyKey}`);
    onValue(medsRef, (snapshot) => {
      const data = snapshot.val() || {};
      const medications = Object.keys(data).map(key => ({
        id: key,
        ...data[key],
        status: data[key].status || 'pending',
        elderlyIdentifier: elderlyIdentifierStr // Use identifier instead of email
      }));
      
      console.log(`Medications for ${elderlyIdentifierStr}:`, medications);
      
      // Filter for today's medications
      const today = new Date().toISOString().split('T')[0];
      const todaysMedications = medications.filter(
        med => med.date === today || !med.date
      );
      
      // Merge with existing medications from other elderly
      setMedicationReminders(prev => {
        const filteredPrev = prev.filter(med => med.elderlyIdentifier !== elderlyIdentifierStr);
        const merged = [...filteredPrev, ...todaysMedications].sort((a, b) => {
          const timeA = a.reminderTime || '00:00';
          const timeB = b.reminderTime || '00:00';
          return timeA.localeCompare(timeB);
        });
        console.log(`Merged medications:`, merged);
        return merged;
      });
    });

    // Load event reminders - handle both email and UID format
    const eventsRef = ref(database, `reminders/${elderlyKey}`);
    onValue(eventsRef, (snapshot) => {
      const data = snapshot.val() || {};
      const reminders = Object.keys(data).map(key => ({
        id: key,
        ...data[key],
        elderlyIdentifier: elderlyIdentifierStr // Use identifier instead of email
      }));
      
      console.log(`Event reminders for ${elderlyIdentifierStr}:`, reminders);
      
      // Filter for today's events
      const today = new Date().toISOString().split('T')[0];
      const todaysEvents = reminders.filter(
        reminder => {
          if (!reminder.startTime) return false;
          const reminderDate = formatDate(reminder.startTime);
          return reminderDate === today;
        }
      );
      
      // Merge with existing events from other elderly
      setEventReminders(prev => {
        const filteredPrev = prev.filter(evt => evt.elderlyIdentifier !== elderlyIdentifierStr);
        const merged = [...filteredPrev, ...todaysEvents].sort((a, b) => {
          const timeA = a.startTime || '00:00';
          const timeB = b.startTime || '00:00';
          return timeA.localeCompare(timeB);
        });
        console.log(`Merged event reminders:`, merged);
        return merged;
      });
    });

    // Return cleanup function
    return () => {
      unsubscribeAppointments();
      off(medsRef);
      off(eventsRef);
    };
  };

  // Enhanced function to get elderly data from various identifier types
  const getElderlyDataByIdentifier = async (elderlyIdentifier) => {
    try {
      let elderlyKey;
      let elderlyRef;
      
      // Check if identifier is an email (contains @)
      if (elderlyIdentifier.includes('@')) {
        elderlyKey = emailToKey(elderlyIdentifier);
        elderlyRef = ref(database, `Account/${elderlyKey}`);
      } else {
        // Identifier is likely a UID, search through all accounts
        elderlyRef = ref(database, 'Account');
      }
      
      const snapshot = await get(elderlyRef);
      
      if (!snapshot.exists()) {
        console.warn(`No data found for elderly identifier: ${elderlyIdentifier}`);
        return { 
          idKey: elderlyIdentifier.includes('@') ? elderlyKey : elderlyIdentifier,
          identifier: elderlyIdentifier,
          firstname: "Unknown",
          lastname: "User",
          email: elderlyIdentifier.includes('@') ? elderlyIdentifier : 'Unknown',
          error: true 
        };
      }
      
      let elderlyData;
      
      if (elderlyIdentifier.includes('@')) {
        // Direct lookup by email key
        elderlyData = snapshot.val();
      } else {
        // Search for UID in all accounts
        const allAccounts = snapshot.val();
        elderlyData = Object.values(allAccounts).find(account => 
          account.uid === elderlyIdentifier || account.email === elderlyIdentifier
        );
        
        if (!elderlyData) {
          console.warn(`No account found with UID: ${elderlyIdentifier}`);
          return { 
            idKey: elderlyIdentifier,
            identifier: elderlyIdentifier,
            firstname: "Unknown",
            lastname: "User",
            email: 'Unknown',
            error: true 
          };
        }
      }
      
      return { 
        idKey: elderlyIdentifier.includes('@') ? elderlyKey : elderlyIdentifier,
        ...elderlyData, 
        identifier: elderlyIdentifier,
        email: elderlyData.email || (elderlyIdentifier.includes('@') ? elderlyIdentifier : 'Unknown')
      };
    } catch (error) {
      console.error(`Error fetching data for elderly ${elderlyIdentifier}:`, error);
      return { 
        idKey: elderlyIdentifier.includes('@') ? emailToKey(elderlyIdentifier) : elderlyIdentifier,
        identifier: elderlyIdentifier,
        firstname: "Unknown",
        lastname: "User",
        email: elderlyIdentifier.includes('@') ? elderlyIdentifier : 'Unknown',
        error: true 
      };
    }
  };

  // Enhanced function to check elderly link with support for both elderlyId/elderlyIds and UID
  const checkElderlyLinkFromFirebase = async (email) => {
    try {
      const emailKey = emailToKey(email);
      const userRef = ref(database, `Account/${emailKey}`);
      const snapshot = await get(userRef);

      if (snapshot.exists()) {
        const userData = snapshot.val();
        
        // Handle different field names for elderly connections
        let elderlyIdentifiers = [];
        
        // Check all possible field names
        if (userData.elderlyIds && Array.isArray(userData.elderlyIds)) {
          elderlyIdentifiers = userData.elderlyIds;
        } else if (userData.elderlyId) {
          elderlyIdentifiers = [userData.elderlyId];
        } else if (userData.linkedElderUids && Array.isArray(userData.linkedElderUids)) {
          elderlyIdentifiers = userData.linkedElderUids;
        } else if (userData.linkedElders && Array.isArray(userData.linkedElders)) {
          elderlyIdentifiers = userData.linkedElders;
        } else if (userData.uidOfElder) {
          elderlyIdentifiers = [userData.uidOfElder];
        }

        console.log("Found elderly identifiers:", elderlyIdentifiers);

        if (elderlyIdentifiers.length > 0) {
          const elderlyDataPromises = elderlyIdentifiers.map(async (elderlyIdentifier) => {
            return await getElderlyDataByIdentifier(elderlyIdentifier);
          });

          const elderlyDataArray = await Promise.all(elderlyDataPromises);
          const validElderlyData = elderlyDataArray.filter(elderly => !elderly.error);
          
          console.log("Final elderly list:", validElderlyData);
          setElderlyList(validElderlyData);
          setElderlyLinked(validElderlyData.length > 0);

          // Load appointments and medications for all elderly
          validElderlyData.forEach(elderly => {
            console.log(`Loading data for elderly: ${elderly.identifier}`);
            loadElderlyData(elderly.identifier);
          });

          return true;
        }
      }
      
      console.log("No elderly linked found");
      setElderlyLinked(false);
      setElderlyList([]);
      return false;
    } catch (error) {
      console.error("Failed to check elderly link from Firebase:", error);
      setElderlyLinked(false);
      setElderlyList([]);
      return false;
    }
  };

  // Real-time notifications setup
  useEffect(() => {
    if (!emailKey) return;

    let unsubscribeNotifications = null;
    let unsubscribeCount = null;
    let unsubscribeMonitoring = null;

    unsubscribeNotifications = NotificationsCaregiverController.getCaregiverNotifications(
      emailKey, 
      (notifications) => {
        setNotifications(notifications);
        const unreadCount = notifications.filter(n => !n.read).length;
        setUnreadNotifications(unreadCount);
        
        notifications.forEach(notification => {
          if (!notification.read && notification.timestamp > new Date(Date.now() - 10000)) {
            toast.info(notification.message, {
              position: "bottom-left",
              autoClose: 5000,
              containerId: 'notification'
            });
          }
        });
      }
    );

    unsubscribeCount = NotificationsCaregiverController.getUnreadNotificationCount(
      emailKey,
      (count) => {
        setUnreadNotifications(count);
      }
    );

    if (elderlyLinked && emailKey) {
      unsubscribeMonitoring = NotificationsCaregiverController.initializeCaregiverMonitoring(emailKey);
    }

    return () => {
      if (unsubscribeNotifications) unsubscribeNotifications();
      if (unsubscribeCount) unsubscribeCount();
      if (unsubscribeMonitoring) unsubscribeMonitoring();
    };
  }, [emailKey, elderlyLinked]);

  // Fetch schedule popup data when user clicks the schedule button
  const fetchScheduleData = async () => {
    await fetchCaregiverSchedule();
  };

  // Mark notification as read
  const handleMarkAsRead = async (notificationId) => {
    try {
      await NotificationsCaregiverController.markNotificationAsRead(notificationId);
      toast.success("Notification marked as read");
    } catch (error) {
      console.error("Error marking notification as read:", error);
      toast.error("Failed to mark notification as read");
    }
  };

  // Mark all as read
  const handleMarkAllAsRead = async () => {
    try {
      await NotificationsCaregiverController.markAllNotificationsAsRead(emailKey);
      toast.success("All notifications marked as read");
    } catch (error) {
      console.error("Error marking all notifications as read:", error);
      toast.error("Failed to mark notifications as read");
    }
  };

  // Delete notification
  const handleDeleteNotification = async (notificationId) => {
    try {
      await NotificationsCaregiverController.deleteNotification(notificationId);
      toast.success("Notification deleted");
    } catch (error) {
      console.error("Error deleting notification:", error);
      toast.error("Failed to delete notification");
    }
  };

  // Fetch user info
  useEffect(() => {
    const storedName = localStorage.getItem("userName");
    const storedUid = localStorage.getItem("uid");
    const storedUserType = localStorage.getItem("userType");
    const storedEmail = localStorage.getItem("loggedInEmail");
    
    if (storedName && storedUid && storedUserType && storedEmail) {
      setUserName(storedName);
      setUid(storedUid);
      setCaregiverEmail(storedEmail);
      setEmailKey(emailToKey(storedEmail));
      
      checkElderlyLinkFromFirebase(storedEmail);
      
      setLoading(false);
      return;
    }

    async function fetchUserData() {
      const loggedInEmail = localStorage.getItem("loggedInEmail");
      if (!loggedInEmail) {
        setLoading(false);
        navigate('/caregiver/login');
        return;
      }

      setCaregiverEmail(loggedInEmail);
      const emailKeyValue = emailToKey(loggedInEmail);
      setEmailKey(emailKeyValue);

      try {
        const userRef = ref(database, `Account/${emailKeyValue}`);
        const snapshot = await get(userRef);

        if (snapshot.exists()) {
          const userData = snapshot.val();
          const fullName = userData.lastname
            ? `${userData.firstname} ${userData.lastname}`
            : userData.firstname;

          setUserName(fullName);
          setUid(userData.uid);
          localStorage.setItem("userName", fullName);
          localStorage.setItem("uid", userData.uid);
          localStorage.setItem("userType", userData.userType);
          
          await checkElderlyLinkFromFirebase(loggedInEmail);
        } else {
          setUserName("Caregiver");
        }
      } catch (error) {
        console.error("Failed to fetch user data:", error);
        setUserName("Caregiver");
      } finally {
        setLoading(false);
      }
    }

    fetchUserData();
  }, [navigate]);

  // Update the markAsComplete function to handle multiple elderly
  const markAsComplete = async (id, elderlyIdentifier) => {
    try {
      if (!elderlyIdentifier) return;
      
      const elderlyKey = elderlyIdentifier.includes('@') ? emailToKey(elderlyIdentifier) : elderlyIdentifier;
      
      // Update in Firebase
      const medRef = ref(database, `medicationReminders/${elderlyKey}/${id}`);
      await update(medRef, { 
        status: "completed",
        completedAt: new Date().toISOString()
      });
      
      // Update local state
      setMedicationReminders(meds => 
        meds.map(med => 
          med.id === id ? {...med, status: "completed"} : med
        )
      );
      
      toast.success("Medication marked as completed");
    } catch (error) {
      console.error("Error updating medication:", error);
      toast.error("Failed to update medication status");
    }
  };

  const handleLogout = () => {
    localStorage.removeItem('userName');
    localStorage.removeItem('uid');
    localStorage.removeItem('userType');
    localStorage.removeItem('loggedInEmail');
    localStorage.removeItem('elderlyId');
    navigate('/caregiver/login');
  };

  const handleLinkElderly = () => {
    navigate('/caregiver/linkElderlyPage');
  };

  // Navigate to consultation history page
  const handleConsultationHistory = () => {
    navigate('/caregiver/consultationHistoryPage');
  };

  // Get priority color for notifications
  const getPriorityColor = (priority) => {
    switch (priority) {
      case 'critical': return '#dc3545';
      case 'high': return '#fd7e14';
      case 'medium': return '#ffc107';
      case 'low': return '#28a745';
      default: return '#6c757d';
    }
  };

  // Message count
  const [unreadMessageCount, setUnreadMessageCount] = useState(0);

  useEffect(() => {
    const loggedInEmail = localStorage.getItem('loggedInEmail');
    if (!loggedInEmail) return;

    const formattedEmailKey = loggedInEmail.replace(/\./g, '_');
    
    const unsubscribe = NotificationsCaregiverController.getCaregiverNotifications(
      formattedEmailKey,
      (notifs) => {
        const messageNotifs = notifs.filter(
          n => n.type === 'message' && !n.read
        );
        setUnreadMessageCount(messageNotifs.length);
      }
    );

    return () => unsubscribe();
  }, []);

  // Get elderly name by identifier
  const getElderlyName = (elderlyIdentifier) => {
    const elderly = elderlyList.find(elderly => 
      elderly.identifier === elderlyIdentifier || 
      elderly.email === elderlyIdentifier ||
      elderly.uid === elderlyIdentifier
    );
    return elderly ? `${elderly.firstname} ${elderly.lastname}` : 'Unknown Elderly';
  };

  // Format phone number display
  const formatPhoneNumber = (phoneNum) => {
    if (!phoneNum) return 'Not provided';
    
    const phoneStr = String(phoneNum);
    const cleaned = phoneStr.replace(/\D/g, '');
    
    if (cleaned.length === 8) {
      return `${cleaned.substring(0, 4)} ${cleaned.substring(4)}`;
    } else if (cleaned.length === 10 && cleaned.startsWith('65')) {
      return `+65 ${cleaned.substring(2, 6)} ${cleaned.substring(6)}`;
    } else if (cleaned.length === 11 && cleaned.startsWith('065')) {
      return `+65 ${cleaned.substring(3, 7)} ${cleaned.substring(7)}`;
    } else if (cleaned.length === 12 && cleaned.startsWith('6565')) {
      return `+65 ${cleaned.substring(2, 6)} ${cleaned.substring(6)}`;
    } else {
      return phoneStr;
    }
  };

  const renderElderlyAppointments = (appointmentsByElderly) => {
    return Object.entries(appointmentsByElderly).map(([elderlyName, appointments]) => (
      <div key={elderlyName} style={{ marginBottom: "20px" }}>
        <div style={{ 
          display: "flex", 
          alignItems: "center", 
          gap: "8px", 
          marginBottom: "10px",
          padding: "8px 12px",
          background: "#e3f2fd",
          borderRadius: "8px"
        }}>
          <FiUser size={16} />
          <strong style={{ color: "#1976d2" }}>{elderlyName}</strong>
          <span style={{ 
            fontSize: "0.8em", 
            background: "#1976d2", 
            color: "white", 
            padding: "2px 8px", 
            borderRadius: "12px" 
          }}>
            {appointments.length} appointment{appointments.length !== 1 ? 's' : ''}
          </span>
        </div>
        
        {appointments.map((apt) => (
          <div key={apt.id} style={elderlyAppointmentItemStyle}>
            <div style={elderlyAppointmentHeaderStyle}>
              <h5 style={{ margin: 0, color: "#333", fontSize: "1em" }}>
                {apt.title || apt.reason || 'Appointment'}
              </h5>
              <span style={appointmentTypeBadgeStyle}>
                {apt.appointmentType || apt.type || 'appointment'}
              </span>
            </div>
            
            <div style={elderlyAppointmentGridStyle}>
              <div><span style={{ color: "#666" }}>📅 Date: </span>{formatDisplayDate(apt.date || apt.appointmentDate)}</div>
              {apt.time && (
                <div><span style={{ color: "#666" }}>⏰ Time: </span>{formatDisplayTime(apt.time)}</div>
              )}
              {apt.location && (
                <div><span style={{ color: "#666" }}>📍 Location: </span>{apt.location}</div>
              )}
              {apt.doctor && (
                <div><span style={{ color: "#666" }}>👨‍⚕️ Doctor: </span>{apt.doctor}</div>
              )}
            </div>
            
            {apt.notes && (
              <div style={{ marginTop: "8px", fontSize: "0.85em" }}>
                <span style={{ color: "#666" }}>📝 </span>{apt.notes}
              </div>
            )}
          </div>
        ))}
      </div>
    ));
  };

  // CORRECTED: Enhanced Schedule Popup Component with FIXED date handling
const CaregiverSchedulePopup = () => {
  if (!showSchedulePopup) return null;

  const { schedule, caregiverConsultations, elderlyAppointments, summary } = caregiverSchedule;

  // Use the main schedule array from the API response
  const allEvents = Array.isArray(schedule) ? schedule : [];
  
  console.log("🎯 Rendering popup with events:", allEvents);

  // Separate events by type
  const caregiverEvents = allEvents.filter(event => event.isCaregiverEvent);
  const elderlyEvents = allEvents.filter(event => event.isElderlyEvent);

  return (
    <div style={popupOverlayStyle}>
      <div style={popupContainerStyle}>
        {/* Header */}
        <div style={popupHeaderStyle}>
          <div>
            <h3 style={{ margin: 0, fontSize: "1.3em", fontWeight: 600 }}>
              Your Schedule, {userName}
            </h3>
            <p style={{ margin: "5px 0 0 0", fontSize: "0.9em", opacity: 0.9 }}>
              {caregiverEvents.length} personal events + {elderlyEvents.length} elderly events
            </p>
          </div>
          <button 
            onClick={() => setShowSchedulePopup(false)}
            style={closeButtonStyle}
          >
            <X size={20} />
          </button>
        </div>
        
        <div style={{ padding: "20px" }}>
          {/* Caregiver Personal Events */}
          {caregiverEvents.length > 0 && (
            <ScheduleSection 
              title="👤 Your Personal Schedule"
              count={caregiverEvents.length}
              items={caregiverEvents}
              renderItem={renderCaregiverEvents}
            />
          )}

          {/* Elderly Patient Events */}
          {elderlyEvents.length > 0 && (
            <ScheduleSection 
              title="👵 Elderly Patient Schedule" 
              count={elderlyEvents.length}
              items={elderlyEvents}
              renderItem={renderElderlyEvents}
            />
          )}

          {/* No Events Message */}
          {allEvents.length === 0 && (
            <div style={{ textAlign: "center", padding: "40px 20px", color: "#666" }}>
              <FiCalendar size={48} style={{ marginBottom: "10px", opacity: 0.5 }} />
              <p style={{ margin: "0 0 10px 0" }}>No events scheduled for today.</p>
              <p style={{ fontSize: "0.9em", opacity: 0.7 }}>
                Check back later or schedule new appointments.
              </p>
            </div>
          )}

          {/* Summary */}
          {allEvents.length > 0 && (
            <div style={summaryStyle}>
              <strong>Summary:</strong> {allEvents.length} total events • 
              Your consultations: {summary?.totalConsultations || 0} • 
              Elderly appointments: {summary?.totalElderlyAppointments || 0}
            </div>
          )}

          {/* Close Button */}
          <div style={{ display: "flex", justifyContent: "flex-end", marginTop: "20px" }}>
            <button 
              style={closeBtnStyle}
              onClick={() => setShowSchedulePopup(false)}
            >
              Close
            </button>
          </div>
        </div>
      </div>
    </div>
  );
};

// FIXED: Render caregiver events with proper date handling
const renderCaregiverEvents = (events) => (
  <>
    {events.map((event, index) => (
      <div key={event.id || index} style={caregiverEventItemStyle}>
        <div style={eventHeaderStyle}>
          <h5 style={{ margin: 0, color: "#333", fontSize: "1em" }}>
            {event.title || event.reason || 'Event'}
          </h5>
          <span style={eventTypeBadgeStyle}>
            {event.displayType || event.type || 'Event'}
          </span>
        </div>
        
        <div style={eventGridStyle}>
          <div><span style={{ color: "#666" }}>📅 Date: </span>
            {formatDisplayDate(event.date || event.appointmentDate)}
          </div>
          {/* ADD TIME FOR CONSULTATIONS */}
          {(event.time || event.appointmentDate) && (
            <div><span style={{ color: "#666" }}>⏰ Time: </span>
              {event.time ? formatDisplayTime(event.time) : 
               event.appointmentDate ? formatDisplayTime(event.appointmentDate) : 
               'Time not specified'}
            </div>
          )}
          {event.location && (
            <div><span style={{ color: "#666" }}>📍 Location: </span>{event.location}</div>
          )}
        </div>
        
        {event.notes && (
          <div style={{ marginTop: "8px", fontSize: "0.85em" }}>
            <span style={{ color: "#666" }}>📝 </span>{event.notes}
          </div>
        )}
      </div>
    ))}
  </>
);

// FIXED: Render elderly events with proper date handling for reminders
const renderElderlyEvents = (events) => (
  <>
    {events.map((event, index) => (
      <div key={event.id || index} style={elderlyEventItemStyle}>
        <div style={eventHeaderStyle}>
          <h5 style={{ margin: 0, color: "#333", fontSize: "1em" }}>
            {event.title || event.reason || 'Appointment'}
          </h5>
          <div style={{ display: "flex", alignItems: "center", gap: "8px" }}>
            <span style={elderlyNameBadgeStyle}>
              {event.elderlyName || 'Elderly'}
            </span>
            <span style={eventTypeBadgeStyle}>
              {event.displayType || event.type || 'Appointment'}
            </span>
          </div>
        </div>
        
        <div style={eventGridStyle}>
          {/* FIXED: Handle date for reminder events */}
          <div><span style={{ color: "#666" }}>📅 Date: </span>
            {event.eventType === 'elderly_reminder' && event.startTime 
              ? formatDisplayDate(event.startTime)
              : formatDisplayDate(event.date || event.appointmentDate)
            }
          </div>
          
          {/* FIXED: Handle time for reminder events */}
          {event.eventType === 'elderly_reminder' && event.startTime ? (
            <div><span style={{ color: "#666" }}>⏰ Time: </span>
              {formatDisplayTime(event.startTime)}
            </div>
          ) : event.time ? (
            <div><span style={{ color: "#666" }}>⏰ Time: </span>
              {formatDisplayTime(event.time)}
            </div>
          ) : null}
          
          {event.location && (
            <div><span style={{ color: "#666" }}>📍 Location: </span>{event.location}</div>
          )}
        </div>
        
        {event.notes && (
          <div style={{ marginTop: "8px", fontSize: "0.85em" }}>
            <span style={{ color: "#666" }}>📝 </span>{event.notes}
          </div>
        )}
      </div>
    ))}
  </>
);

  // Helper components
  const ScheduleSection = ({ title, count, items, renderItem }) => (
    <div style={{ marginBottom: "30px" }}>
      <div style={sectionHeaderStyle}>
        <h4 style={{ margin: 0, color: "#333", fontSize: "1.1em" }}>
          {title} ({count})
        </h4>
      </div>
      {renderItem(items)}
    </div>
  );

// Styles
const popupOverlayStyle = {
  position: "fixed",
  top: 0,
  left: 0,
  right: 0,
  bottom: 0,
  background: "rgba(0, 0, 0, 0.7)",
  display: "flex",
  justifyContent: "center",
  alignItems: "center",
  zIndex: 10000
};

const popupContainerStyle = {
  background: "white",
  borderRadius: "16px",
  width: "90%",
  maxWidth: "800px",
  maxHeight: "80vh",
  overflowY: "auto",
  boxShadow: "0 20px 60px rgba(0, 0, 0, 0.3)"
};

const popupHeaderStyle = {
  background: "linear-gradient(135deg, #667eea 0%, #764ba2 100%)",
  color: "white",
  padding: "20px",
  borderRadius: "16px 16px 0 0",
  display: "flex",
  justifyContent: "space-between",
  alignItems: "flex-start"
};

const caregiverEventItemStyle = {
  background: "#e8f5e8",
  borderRadius: "10px",
  padding: "15px",
  marginBottom: "10px",
  borderLeft: "4px solid #4CAF50"
};

const elderlyEventItemStyle = {
  background: "#fff3e0",
  borderRadius: "10px",
  padding: "15px",
  marginBottom: "10px",
  borderLeft: "4px solid #FF9800"
};

const eventHeaderStyle = {
  display: "flex",
  justifyContent: "space-between",
  alignItems: "flex-start",
  marginBottom: "8px",
  flexWrap: "wrap",
  gap: "8px"
};

const eventTypeBadgeStyle = {
  fontSize: "0.7em",
  color: "#666",
  background: "#e9ecef",
  padding: "2px 8px",
  borderRadius: "12px",
  whiteSpace: "nowrap"
};

const elderlyNameBadgeStyle = {
  fontSize: "0.7em",
  color: "#E65100",
  background: "#ffe0b2",
  padding: "2px 8px",
  borderRadius: "12px",
  fontWeight: "bold"
};

const eventGridStyle = {
  display: "grid",
  gridTemplateColumns: "1fr 1fr",
  gap: "8px",
  fontSize: "0.85em"
};

const closeButtonStyle = {
  background: "none",
  border: "none",
  color: "white",
  fontSize: "24px",
  cursor: "pointer",
  padding: 0,
  width: "30px",
  height: "30px",
  display: "flex",
  alignItems: "center",
  justifyContent: "center",
  borderRadius: "50%"
};

const sectionHeaderStyle = {
  display: "flex",
  alignItems: "center",
  gap: "10px",
  marginBottom: "15px",
  paddingBottom: "10px",
  borderBottom: "2px solid #e9ecef"
};

const consultationItemStyle = {
  background: "#f8f9fa",
  borderRadius: "10px",
  padding: "15px",
  marginBottom: "10px",
  borderLeft: "4px solid #17A2B8"
};

const consultationHeaderStyle = {
  display: "flex",
  justifyContent: "space-between",
  alignItems: "flex-start",
  marginBottom: "8px"
};

const statusBadgeStyle = {
  fontSize: "0.8em",
  color: "#666",
  background: "#e9ecef",
  padding: "2px 8px",
  borderRadius: "12px"
};

const consultationGridStyle = {
  display: "grid",
  gridTemplateColumns: "1fr 1fr",
  gap: "10px",
  fontSize: "0.85em"
};

// Add styles for elderly appointments
const elderlyAppointmentItemStyle = {
  background: "#fff3e0",
  borderRadius: "10px",
  padding: "15px",
  marginBottom: "10px",
  borderLeft: "4px solid #FF9800"
};

const elderlyAppointmentHeaderStyle = {
  display: "flex",
  justifyContent: "space-between",
  alignItems: "flex-start",
  marginBottom: "8px"
};

const appointmentTypeBadgeStyle = {
  fontSize: "0.7em",
  color: "#E65100",
  background: "#ffe0b2",
  padding: "2px 8px",
  borderRadius: "12px",
  fontWeight: "bold"
};

const elderlyAppointmentGridStyle = {
  display: "grid",
  gridTemplateColumns: "1fr 1fr",
  gap: "8px",
  fontSize: "0.85em"
};

const summaryStyle = {
  marginTop: "20px",
  padding: "15px",
  background: "#f8f9fa",
  borderRadius: "10px",
  textAlign: "center",
  fontSize: "0.9em",
  color: "#333"
};

const closeBtnStyle = {
  background: "#6c757d",
  color: "white",
  padding: "10px 20px",
  border: "none",
  borderRadius: "20px",
  fontSize: "0.9em",
  fontWeight: 500,
  cursor: "pointer"
};

  if (loading) {
    return (
      <div
        style={{
          minHeight: "100vh",
          display: "flex",
          justifyContent: "center",
          alignItems: "center",
          fontSize: "24px",
          fontFamily: "sans-serif",
          color: "#2F4F4F",
        }}
      >
        Loading dashboard...
      </div>
    );
  }

  return (
    <div className="caregiver-dashboard" style={{width: '100%',marginTop: '-20px'}}>
      {/* Enhanced Schedule Popup */}
      <CaregiverSchedulePopup />

      {/* Main Content */}
      <div className="main-content" style={{maxWidth: '90%'}}>
        {/* Dashboard Content */}
        <main className="dashboard-main">
          <div className="dashboard-content">
            <div className="welcome-banner">
              <div className="welcome-text">
                <h2>Good Morning, {userName}!</h2>
                <p>
                  {elderlyLinked && elderlyList.length > 0 
                    ? `You are managing ${elderlyList.length} elderly user${elderlyList.length > 1 ? 's' : ''}. You have medication reminders.`
                    : "Connect with elderly users to start managing their care."}
                </p>
                
                {elderlyLinked && (
                  <div className="status-badge">
                    <FiActivity />
                    Last synced: {new Date().toLocaleTimeString()}
                  </div>
                )}
              </div>
              
              {/* Schedule Button */}
              <button
                onClick={fetchScheduleData}
                disabled={popupLoading}
                style={{
                  background: popupLoading ? '#F39C12' : '#43a2e2ff',
                  color: "white",
                  border: "none",
                  padding: "12px 20px",
                  borderRadius: "25px",
                  cursor: popupLoading ? "not-allowed" : "pointer",
                  boxShadow: "0 4px 10px rgba(0, 0, 0, 0.2)",
                  transition: "all 0.3s ease",
                  display: "flex",
                  alignItems: "center",
                  gap: "8px",
                  fontSize: "14px",
                  fontWeight: "500",
                  marginLeft: "auto",
                  marginRight: "20px",
                  marginTop: "50px"
                }}
                onMouseEnter={(e) => {
                  if (!popupLoading) {
                    e.target.style.transform = "scale(1.05)";
                    e.target.style.boxShadow = "0 6px 15px rgba(0, 0, 0, 0.3)";
                  }
                }}
                onMouseLeave={(e) => {
                  if (!popupLoading) {
                    e.target.style.transform = "scale(1)";
                    e.target.style.boxShadow = "0 4px 10px rgba(0, 0, 0, 0.2)";
                  }
                }}
                title={popupLoading ? "Loading schedule..." : "View Today's Schedule"}
              >
                {popupLoading ? (
                  <div style={{
                    width: "16px",
                    height: "16px",
                    border: "2px solid transparent",
                    borderTop: "2px solid white",
                    borderRadius: "50%",
                    animation: "spin 1s linear infinite"
                  }} />
                ) : (
                  <>
                    <Calendar size={18} />
                    Today's Schedule
                  </>
                )}
              </button>
            </div>
                
            {/* Link Elderly Card */}
            <div className="link-elderly-card">
              {elderlyLinked && elderlyList.length > 0 ? (
                <div className="elderly-info-grid">
                  <h4>Linked Elderly Information ({elderlyList.length})</h4>
                  <div className="elderly-cards-container">
                    {elderlyList.map((elderly) => (
                      <div key={elderly.idKey} className="elderly-info-card">
                        <div className="elderly-avatar-small">
                          <div className="avatar-initials-small">
                            {elderly.firstname?.charAt(0)}{elderly.lastname?.charAt(0)}
                          </div>
                        </div>
                        <div className="elderly-details">
                          <h5>{elderly.firstname} {elderly.lastname}</h5>
                          <p><strong>Age:</strong> {calculateAge(elderly.dob)} years</p>
                          <p><strong>Phone:</strong> {formatPhoneNumber(elderly.phoneNum)}</p>
                          <p><strong>UID:</strong> {elderly.uid }</p>
                        </div>
                      </div>
                    ))}
                  </div>
                  <br/>
                  <div className="card-actions">
                    <button 
                      onClick={handleLinkElderly} 
                      className="btn btn-outline"
                      style={{backgroundColor: '#579ef4ff', color: 'black', marginLeft: '35%'}}
                    >
                      Manage Elderly Connections
                    </button>

                    <br/>
                    <button 
                      onClick={handleConsultationHistory}
                      className="btn btn-outline"
                      style={{backgroundColor: '#4e78e0ff', color: 'white', marginLeft: '40%'}}
                    >
                      Consultation 
                    </button>
                  </div>
                </div>
              ) : (
                <div className="card-content">
                  <FiUsers size={48} className="link-icon" />
                  <h3>Link Elderly Account</h3>
                  <p>Connect with your elderly users to start managing their care</p>
                  <button
                    onClick={handleLinkElderly}
                    className="btn btn-outline"
                    style={{ backgroundColor: "#579ef4ff", color: "black" }}
                  >
                    Link Elderly
                  </button>
                </div>
              )}
            </div>

            {/* Dashboard Content - Always shown */}
            {uid && <AnnouncementsWidget uid={uid} userType="caregiver" />}
            
            {/* Toast Containers */}
            <ToastContainer position="top-right" autoClose={5000} />
            <ToastContainer
              position="bottom-left"
              autoClose={6000}
              containerId="notification"
              style={{ width: "350px", fontSize: "1rem" }}
            />
            
            <div className="dashboard-grid">
              <div className="column left-column">
                {/* Notifications Panel */}
                <div className="content-card">
                  <div className="card-header">
                    <h3>Recent Notifications</h3>
                    <div className="header-actions">
                      {unreadNotifications > 0 && (
                        <button 
                          onClick={handleMarkAllAsRead}
                          className="btn btn-sm btn-outline"
                        >
                          Mark All Read
                        </button>
                      )}
                      <Link to="/caregiver/receiveNotificationsCaregiver" className="view-all">
                        View All
                      </Link>
                    </div>
                  </div>
                  <div className="notifications-list">
                    {notifications.length > 0 ? (
                      notifications.slice(0, 5).map(notification => (
                        <div 
                          key={notification.id} 
                          className={`notification-item ${notification.read ? 'read' : 'unread'}`}
                        >
                          <div className="notification-indicator">
                            <div 
                              className="priority-dot"
                              style={{ backgroundColor: getPriorityColor(notification.priority) }}
                            ></div>
                          </div>
                          <div className="notification-content">
                            <div className="notification-header">
                              <h4>{notification.title}</h4>
                              <span className="notification-time">
                                {new Date(notification.timestamp).toLocaleTimeString([], {hour: '2-digit', minute:'2-digit'})}
                              </span>
                            </div>
                            <p>{notification.message}</p>
                            {notification.elderlyName && (
                              <div className="notification-source">
                                From: {notification.elderlyName}
                              </div>
                            )}
                          </div>
                          <div className="notification-actions">
                            {!notification.read && (
                              <button 
                                onClick={() => handleMarkAsRead(notification.id)}
                                className="btn btn-sm btn-success"
                                title="Mark as read"
                              >
                                <FiCheckCircle />
                              </button>
                            )}
                            <button 
                              onClick={() => handleDeleteNotification(notification.id)}
                              className="btn btn-sm btn-danger"
                              title="Delete notification"
                              >
                                <FiTrash2 />
                              </button>
                            </div>
                          </div>
                        ))
                      ) : (
                        <p className="no-data-message">No notifications</p>
                      )}
                    </div>
                    {unreadNotifications > 5 && (
                      <div className="card-footer">
                        <Link to="/caregiver/notifications" className="view-all-link">
                          View all {unreadNotifications} unread notifications
                        </Link>
                      </div>
                    )}
                  </div>

                {/* Upcoming Schedule */}
                <div className="content-card">
                  <div className="card-header">
                    <h3>Upcoming Schedule</h3>
                    <Link to="/caregiver/schedule" className="view-all">View All</Link>
                  </div>
                  <div className="schedule-list">
                    {elderlyLinked ? (
                      (appointments.length > 0 || eventReminders.length > 0) ? (
                        <>
                          {appointments.map(appointment => (
                            <div key={appointment.id} className="schedule-item">
                              <div className="date-time">
                                <div className="date">{appointment.date}</div>
                                <div className="time">{appointment.time}</div>
                              </div>
                              <div className="schedule-dot appointment"></div>
                              <div className="schedule-info">
                                <h4>{appointment.title}</h4>
                                <p>{appointment.location || "No location specified"}</p>
                                <div className="elderly-badge">
                                  {getElderlyName(appointment.elderlyId)}
                                </div>
                                {appointment.notes && <p className="notes">{appointment.notes}</p>}
                              </div>
                              <div className="schedule-actions">
                                <button className="btn btn-outline">
                                  <FiArrowUp /> Directions
                                </button>
                              </div>
                            </div>
                          ))}
                          
                          {eventReminders.map(reminder => (
                            <div key={reminder.id} className="schedule-item">
                              <div className="date-time">
                                <div className="date">
                                  {reminder.startTime ? new Date(reminder.startTime).toLocaleDateString() : "All day"}
                                </div>
                                <div className="time">
                                  {reminder.startTime ? new Date(reminder.startTime).toLocaleTimeString([], {hour: '2-digit', minute:'2-digit'}) : "All day"}
                                </div>
                              </div>
                              <div className="schedule-dot task"></div>
                              <div className="schedule-info">
                                <h4>{reminder.title}</h4>
                                <p>{reminder.description || "No description"}</p>
                                <div className="elderly-badge">
                                  {getElderlyName(reminder.elderlyIdentifier)}
                                </div>
                              </div>
                              <div className="schedule-actions">
                                <button className="btn btn-outline">
                                  <FiActivity /> Details
                                </button>
                              </div>
                            </div>
                          ))}
                        </>
                      ) : (
                        <p className="no-data-message">No upcoming appointments</p>
                      )
                    ) : (
                      <p className="no-data-message">
                        Link an elderly account to see their schedule
                      </p>
                    )}
                  </div>
                </div>
              </div>

              <div className="column right-column">
                {/* Health Metrics */}
                <div className="content-card">
                  <div className="card-header">
                    <h3>Health Overview</h3>
                    <Link to="/caregiver/viewReportsCaregiver" className="view-all">Details</Link>
                  </div>
                  <div className="metrics-grid">
                    {elderlyLinked ? (
                      <>
                        {healthMetrics.map(metric => (
                          <div key={metric.id} className="metric-card">
                            <div className="metric-name">{metric.name}</div>
                            <div className="metric-value">{metric.value}</div>
                            <div className={`metric-trend ${metric.trend}`}>
                              {metric.trend === 'up' ? <FiArrowUp /> : metric.trend === 'down' ? <FiArrowDown /> : null}
                              {metric.change}
                            </div>
                          </div>
                        ))}
                        <div className="metric-card elderly-count">
                          <div className="metric-name">Elderly Managed</div>
                          <div className="metric-value">{elderlyList.length}</div>
                          <div className="metric-trend stable">
                            Active
                          </div>
                        </div>
                      </>
                    ) : (
                      <div className="no-elderly-message">
                        <FiUsers size={32} />
                        <p>Link an elderly account to view health metrics</p>
                      </div>
                    )}
                  </div>
                </div>

                {/* Medication Tracker */}
                <div className="content-card">
                  <div className="card-header">
                    <h3>Medication Tracker</h3>
                    <Link to="/caregiver/medicationReminder" className="view-all">View All</Link>
                  </div>
                  <div className="medication-tracker">
                    {elderlyLinked ? (
                      <>
                        <div className="tracker-header">
                          <span>
                            {medicationReminders.filter(m => m.status === "completed").length} of {medicationReminders.length} doses taken today
                          </span>
                          <span className="tracker-percentage">
                            {medicationReminders.length > 0 
                              ? `${Math.round((medicationReminders.filter(m => m.status === "completed").length / medicationReminders.length) * 100)}%`
                              : "0%"
                            }
                          </span>
                        </div>
                        <div className="medication-progress">
                          <div 
                            className="progress-bar" 
                            style={{
                              width: medicationReminders.length > 0 
                                ? `${(medicationReminders.filter(m => m.status === "completed").length / medicationReminders.length) * 100}%`
                                : "0%"
                            }}
                          ></div>
                        </div>
                        {medicationReminders.length > 0 && (
                          <div className="next-dose">
                            <strong>
                              Next: {medicationReminders[0].medicationName} - {medicationReminders[0].reminderTime}
                              <span className="elderly-badge-small">
                                {getElderlyName(medicationReminders[0].elderlyIdentifier)}
                              </span>
                            </strong>
                          </div>
                        )}
                        <div className="medication-list">
                          {medicationReminders.length > 0 ? (
                            medicationReminders.map(med => (
                              <div key={med.id} className="medication-item">
                                <div className="medication-icon">
                                  <FiPackage />
                                </div>
                                <div className="medication-details">
                                  <h4>{med.medicationName}</h4>
                                  <p>{med.dosage}, {med.reminderTime}</p>
                                  <div className="elderly-badge-small">
                                    {getElderlyName(med.elderlyIdentifier)}
                                  </div>
                                </div>
                                {med.status === 'pending' && (
                                  <button 
                                    className="btn btn-sm btn-primary"
                                    onClick={() => markAsComplete(med.id, med.elderlyIdentifier)}
                                  >
                                    <FiCheckCircle />
                                  </button>
                                )}
                                {med.status === 'completed' && (
                                  <span className="status-badge completed">Done</span>
                                )}
                              </div>
                            ))
                          ) : (
                            <p className="no-data-message">No medications scheduled for today</p>
                          )}
                        </div>
                      </>
                    ) : (
                      <div className="no-elderly-message">
                        <FiPackage size={32} />
                        <p>Link an elderly account to track medications</p>
                      </div>
                    )}
                  </div>
                </div>

                {/* Quick Actions */}
                <div className="content-card">
                  <div className="card-header">
                    <h3>Quick Actions</h3>
                  </div>
                  <div className="quick-actions-grid">
                    <Link to="/caregiver/medicationReminder" className="action-btn">
                      <FiPackage />
                      <span>Add Medication</span>
                    </Link>
                    <Link to="/caregiver/appointmentReminder" className="action-btn">
                      <FiCalendar />
                      <span>Schedule Appointment</span>
                    </Link>
                    <Link to="/caregiver/viewReportsCaregiver" className="action-btn">
                      <FiBarChart2 />
                      <span>View Reports</span>
                    </Link>
                    <Link to="/caregiver/generatecustomreport" className="action-btn">
                      <FiBarChart2 />
                      <span>Generate Custom Report</span>
                    </Link>
                    <Link to="/caregiver/notifications" className="action-btn">
                      <FiBell />
                      <span>
                        Notifications 
                        {unreadNotifications > 0 && (
                          <span className="notification-badge">{unreadNotifications}</span>
                        )}
                      </span>
                    </Link>
                    <Link to="/caregiver/settings" className="action-btn">
                      <FiSettings />
                      <span>Settings</span>
                    </Link>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </main>
      </div>
      {/* Floating AI Assistant */}
      {currentUser && <FloatingAssistant userEmail={currentUser} />}
      
      <Footer />
    </div>
  );
};

export default ViewCaregiverDashboard;