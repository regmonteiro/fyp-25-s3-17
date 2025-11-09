import React, { useEffect, useState } from "react";
import { database } from "../firebaseConfig";
import { ref, get, onValue } from "firebase/database";
import { Link } from "react-router-dom";
import {
  Calendar,
  ClipboardList,
  Heart,
  Phone,
  MapPin,
  Clock,
  Star,
  ChevronRight,
  Settings,
  Bell,
  User,
  FileText,
  Pill,
  Users,
  MessageSquare,
  ThumbsUp,
  Share,
  Mail,
  UserCheck,
  CalendarDays,
  BellRing,
  Settings2,
  X,
  Pill as PillIcon,
  Clock as ClockIcon,
  Calendar as CalendarIcon,
  Stethoscope,
  CheckCircle,
  AlertCircle
} from "lucide-react";
import Footer from "../footer";
import AnnouncementsWidget from "../components/announcementWidget";
import { ToastContainer, toast } from "react-toastify";
import "react-toastify/dist/ReactToastify.css";
import FloatingAssistant from "../components/floatingassistantChat";

// Helper function to normalize email for Firebase keys
const normalizeEmailForFirebase = (email) => {
  if (!email) return '';
  return email
    .toLowerCase()
    .trim()
    .replace(/\./g, '_dot_')
    .replace(/#/g, '_hash_')
    .replace(/\$/g, '_dollar_')
    .replace(/\//g, '_slash_')
    .replace(/\[/g, '_lbracket_')
    .replace(/\]/g, '_rbracket_');
};

const currentUser = localStorage.getItem("loggedInEmail");

// Cloud Function URL
const CLOUD_FUNCTION_URL = "https://getloginschedulepopup-ga4zzowbeq-uc.a.run.app";

// Retry configuration
const RETRY_CONFIG = {
  maxRetries: 3,
  initialDelay: 1000,
  maxDelay: 5000
};

// Improved fetch function with retry logic
const fetchWithRetry = async (url, options, retries = RETRY_CONFIG.maxRetries, delay = RETRY_CONFIG.initialDelay) => {
  try {
    const response = await fetch(url, options);
    
    if (!response.ok) {
      throw new Error(`HTTP error! status: ${response.status}`);
    }
    
    return await response.json();
  } catch (error) {
    if (retries > 0) {
      console.log(`Retrying request... ${retries} attempts left`);
      await new Promise(resolve => setTimeout(resolve, delay));
      return fetchWithRetry(url, options, retries - 1, Math.min(delay * 2, RETRY_CONFIG.maxDelay));
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

export default function ViewElderlyDashboard() {
  const [userName, setUserName] = useState("User");
  const [loading, setLoading] = useState(true);
  const [reminders, setReminders] = useState([]);
  const [appointments, setAppointments] = useState([]);
  const [allAppointments, setAllAppointments] = useState([]);
  const [uid, setUid] = useState(null);
  const [userType, setUserType] = useState(null);
  const [emailKey, setEmailKey] = useState(null);
  const [caregivers, setCaregivers] = useState([]);
  const [accounts, setAccounts] = useState({});
  const [debugInfo, setDebugInfo] = useState("");
  
  // Schedule Popup State
  const [showSchedulePopup, setShowSchedulePopup] = useState(false);
  const [scheduleData, setScheduleData] = useState(null);
  const [popupLoading, setPopupLoading] = useState(false);

  // Elderly-friendly color palette
  const colorPalette = {
    backgrounds: {
      light: "#F7F9F9",
      lightBlue: "#E8F4F8",
      lightGreen: "#F0F8F0",
      lightCream: "#FFF8E1",
      lightGray: "#F5F5F5"
    },
    foregrounds: {
      darkGray: "#567a9dff",
      slate: "#34495E",
      gunmetal: "#283747",
      navy: "#154360",
      forest: "#186A3B"
    },
    accents: {
      primary: "#43a2e2ff",
      secondary: "#038b3bff",
      success: "#028b3bff",
      warning: "#F39C12",
      info: "#17A2B8",
      danger: "#f79e94ff"
    }
  };

  // Fetch schedule popup data when user clicks the schedule button
  const fetchScheduleData = async () => {
    const userEmail = localStorage.getItem("loggedInEmail");
    if (!userEmail) {
      toast.error("No user email found");
      return;
    }

    // Check connection first
    const isConnected = await checkConnection();
    if (!isConnected) {
      toast.error("No internet connection. Please check your network.");
      return;
    }

    setPopupLoading(true);
    try {
      const data = await fetchWithRetry(
        `${CLOUD_FUNCTION_URL}/getLoginSchedulePopup`,
        {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({ userId: userEmail })
        }
      );
      
      console.log('Schedule popup response:', data);
      
      if (data.success) {
        if (data.showPopup && data.popupData) {
          setScheduleData(data.popupData);
          setShowSchedulePopup(true);
        } else {
          toast.info("No events scheduled for today", {
            position: "top-right",
            autoClose: 3000,
          });
        }
      } else {
        throw new Error(data.error || "Failed to load schedule data");
      }
    } catch (error) {
      console.error('Error fetching schedule data:', error);
      
      let errorMessage = 'Failed to load schedule data';
      if (error.message.includes('timeout')) {
        errorMessage = 'Request timed out. Please try again.';
      } else if (error.message.includes('network')) {
        errorMessage = 'Network error. Please check your connection.';
      } else if (error.message.includes('Failed to fetch')) {
        errorMessage = 'Cannot connect to server. Please try again later.';
      }
      
      toast.error(errorMessage);
    } finally {
      setPopupLoading(false);
    }
  };

  // Fetch user info
  useEffect(() => {
    const storedName = localStorage.getItem("userName");
    const storedUid = localStorage.getItem("uid");
    const storedUserType = localStorage.getItem("userType");
    
    if (storedName && storedUid && storedUserType) {
      setUserName(storedName);
      setUid(storedUid);
      setUserType(storedUserType);
      
      const loggedInEmail = localStorage.getItem("loggedInEmail");
      if (loggedInEmail) {
        setEmailKey(normalizeEmailForFirebase(loggedInEmail));
      }
      
      setLoading(false);
      return;
    }

    async function fetchUserData() {
      const loggedInEmail = localStorage.getItem("loggedInEmail");
      if (!loggedInEmail) {
        setLoading(false);
        return;
      }

      const emailKey = normalizeEmailForFirebase(loggedInEmail);
      setEmailKey(emailKey);

      try {
        const userRef = ref(database, `Account/${emailKey}`);
        const snapshot = await get(userRef);

        if (snapshot.exists()) {
          const userData = snapshot.val();
          const fullName = userData.lastname
            ? `${userData.firstname} ${userData.lastname}`
            : userData.firstname;

          setUserName(fullName);
          setUid(userData.uid);
          setUserType(userData.userType);
          localStorage.setItem("userName", fullName);
          localStorage.setItem("uid", userData.uid);
          localStorage.setItem("userType", userData.userType);
        } else {
          setUserName("User");
        }
      } catch (error) {
        console.error("Failed to fetch user data:", error);
        setUserName("User");
      } finally {
        setLoading(false);
      }
    }

    fetchUserData();
  }, []);

  // Fetch all accounts for caregiver lookup
  useEffect(() => {
    const fetchAccounts = async () => {
      try {
        const accountsRef = ref(database, "Account");
        const snapshot = await get(accountsRef);
        if (snapshot.exists()) {
          const accountsData = snapshot.val();
          setAccounts(accountsData);
        }
      } catch (error) {
        console.error("Failed to fetch accounts:", error);
      }
    };

    fetchAccounts();
  }, []);

  // Fetch caregivers for the current elderly user
  useEffect(() => {
    if (userType === "elderly" && emailKey && Object.keys(accounts).length > 0) {
      const userEmail = localStorage.getItem("loggedInEmail");
      const userUid = localStorage.getItem("uid");
      if (userEmail && userUid) {
        getCaregiversForElderly(userEmail, userUid, accounts);
      }
    }
  }, [userType, emailKey, accounts]);

  // UPDATED CAREGIVER FINDING FUNCTION - Only shows confirmed matches
  const getCaregiversForElderly = (elderlyEmail, elderlyUid, accountsData) => {
    const caregiversList = [];
    const elderlyEmailNormalized = normalizeEmailForFirebase(elderlyEmail);

    Object.entries(accountsData).forEach(([accountKey, accountData]) => {
      if (accountData.userType === "caregiver") {
        let isAssigned = false;
        let assignmentReason = "";

        // Check elderlyId (single assignment)
        if (accountData.elderlyId && checkAssignment(accountData.elderlyId, elderlyEmail, elderlyUid, elderlyEmailNormalized)) {
          isAssigned = true;
          assignmentReason = `Assigned caregiver`;
        }

        // Check elderlyIds (array assignment)
        if (!isAssigned && accountData.elderlyIds && Array.isArray(accountData.elderlyIds)) {
          accountData.elderlyIds.forEach(elderlyId => {
            if (checkAssignment(elderlyId, elderlyEmail, elderlyUid, elderlyEmailNormalized)) {
              isAssigned = true;
              assignmentReason = `Assigned caregiver`;
            }
          });
        }

        // Check linkedElders (alternative field name)
        if (!isAssigned && accountData.linkedElders) {
          if (Array.isArray(accountData.linkedElders)) {
            accountData.linkedElders.forEach(linkedElder => {
              if (checkAssignment(linkedElder, elderlyEmail, elderlyUid, elderlyEmailNormalized)) {
                isAssigned = true;
                assignmentReason = `Assigned caregiver`;
              }
            });
          } else if (typeof accountData.linkedElders === 'string') {
            if (checkAssignment(accountData.linkedElders, elderlyEmail, elderlyUid, elderlyEmailNormalized)) {
              isAssigned = true;
              assignmentReason = `Assigned caregiver`;
            }
          }
        }

        // Check linkedElderUids (another alternative field)
        if (!isAssigned && accountData.linkedElderUids && Array.isArray(accountData.linkedElderUids)) {
          accountData.linkedElderUids.forEach(linkedElderUid => {
            if (checkAssignment(linkedElderUid, elderlyEmail, elderlyUid, elderlyEmailNormalized)) {
              isAssigned = true;
              assignmentReason = `Assigned caregiver`;
            }
          });
        }

        // Check uidOfElder field
        if (!isAssigned && accountData.uidOfElder && checkAssignment(accountData.uidOfElder, elderlyEmail, elderlyUid, elderlyEmailNormalized)) {
          isAssigned = true;
          assignmentReason = `Assigned caregiver`;
        }

        // If assigned, add to caregivers list
        if (isAssigned) {
          const fullName = accountData.lastname 
            ? `${accountData.firstname} ${accountData.lastname}`
            : accountData.firstname;
          
          caregiversList.push({
            name: fullName,
            email: accountData.email,
            phoneNum: accountData.phoneNum || "No phone number",
            firstname: accountData.firstname,
            lastname: accountData.lastname,
            uid: accountData.uid,
            key: accountKey,
            assignmentReason: assignmentReason,
            confirmed: true
          });
        }
      }
    });
    
    setCaregivers(caregiversList);
  };

  // Helper function to check assignment
  const checkAssignment = (assignedValue, elderlyEmail, elderlyUid, elderlyEmailNormalized) => {
    if (!assignedValue) return false;

    const assignedStr = assignedValue.toString().toLowerCase().trim();
    const elderlyEmailLower = elderlyEmail.toLowerCase();

    // Exact email match
    if (assignedStr === elderlyEmailLower) return true;
    
    // Normalized email match (Firebase key format)
    if (assignedStr === elderlyEmailNormalized) return true;
    
    // UID match
    if (assignedStr === elderlyUid) return true;
    
    // Partial match (contains email parts)
    if (assignedStr.includes(elderlyEmailLower.replace('.', '_'))) return true;

    // Check if assigned value matches the elderly UID format
    if (elderlyUid && assignedStr === elderlyUid.toLowerCase()) return true;

    return false;
  };

  // Fetch reminders
  useEffect(() => {
    async function fetchReminders() {
      if (!emailKey) return;

      try {
        const remindersRef = ref(database, `reminders/${emailKey}`);
        const snapshot = await get(remindersRef);
        if (snapshot.exists()) {
          const data = snapshot.val();
          const remindersArray = Object.entries(data).map(([id, reminder]) => ({
            id,
            ...reminder,
          }));
          setReminders(remindersArray);
        } else {
          setReminders([]);
        }
      } catch (error) {
        console.error("Failed to fetch reminders:", error);
        setReminders([]);
      }
    }

    fetchReminders();
  }, [emailKey]);

  // Fetch appointments for elderly
  useEffect(() => {
    async function fetchAppointments() {
      if (userType !== "elderly" || !emailKey) return;
      
      try {
        const appointmentsRef = ref(database, 'appointments');
        const snapshot = await get(appointmentsRef);
        
        if (snapshot.exists()) {
          const data = snapshot.val();
          const appointmentsArray = Object.entries(data).map(([id, appointment]) => ({
            id,
            ...appointment,
          }));
          
          const userAppointments = appointmentsArray.filter(
            appointment => appointment.elderlyId === emailKey
          );
          
          setAllAppointments(userAppointments);
          
          const today = new Date().toISOString().split('T')[0];
          const todaysAppointments = userAppointments.filter(
            appointment => appointment.date === today
          );
          
          setAppointments(todaysAppointments);
        } else {
          setAllAppointments([]);
          setAppointments([]);
        }
      } catch (error) {
        console.error("Failed to fetch appointments:", error);
        setAllAppointments([]);
        setAppointments([]);
      }
    }

    if (userType === "elderly" && emailKey) {
      fetchAppointments();
    }
  }, [userType, emailKey]);

  // Real-time announcement listener
  useEffect(() => {
    if (!uid) return;

    const announcementsRef = ref(database, `announcements/${uid}`);
    const unsubscribe = onValue(announcementsRef, (snapshot) => {
      if (snapshot.exists()) {
        const announcements = snapshot.val();
        Object.entries(announcements).forEach(([id, announcement]) => {
          if (!announcement.read) {
            toast.info(`📢 New: ${announcement.title}`, {
              position: "top-right",
              autoClose: 5000,
            });
          }
        });
      }
    });

    return () => unsubscribe();
  }, [uid]);

  // Handle calling caregiver
  const handleCallCaregiver = (caregiver) => {
    if (caregiver.phoneNum && caregiver.phoneNum !== "No phone number") {
      toast.info(`Calling ${caregiver.name} at ${caregiver.phoneNum}...`, {
        position: "top-right",
        autoClose: 3000,
      });
    } else {
      toast.warning(`No phone number available for ${caregiver.name}`, {
        position: "top-right",
        autoClose: 3000,
      });
    }
  };

  // Handle email caregiver
  const handleEmailCaregiver = (caregiver) => {
    if (caregiver.email) {
      toast.info(`Opening email to ${caregiver.email}...`, {
        position: "top-right",
        autoClose: 3000,
      });
    }
  };

  // Handle check-in
  const handleCheckIn = () => {
    toast.success("Check-in completed successfully!", {
      position: "top-right",
      autoClose: 3000,
    });
  };

  // Schedule Popup Component
  const SchedulePopup = () => {
    if (!showSchedulePopup || !scheduleData) return null;

    const getEventTypeIcon = (type) => {
      switch (type) {
        case 'medication': return <PillIcon size={16} />;
        case 'appointment': return <CalendarIcon size={16} />;
        case 'consultation': return <Stethoscope size={16} />;
        case 'reminder': return <BellRing size={16} />;
        case 'assigned_routine': return <ClockIcon size={16} />;
        default: return <CalendarIcon size={16} />;
      }
    };

    const getEventTypeColor = (type) => {
      switch (type) {
        case 'medication': return colorPalette.accents.danger;
        case 'appointment': return colorPalette.accents.primary;
        case 'consultation': return colorPalette.accents.info;
        case 'reminder': return colorPalette.accents.warning;
        case 'assigned_routine': return colorPalette.accents.success;
        default: return colorPalette.foregrounds.slate;
      }
    };

    return (
      <div style={{
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
      }}>
        <div style={{
          background: "white",
          borderRadius: "16px",
          width: "90%",
          maxWidth: "800px",
          maxHeight: "80vh",
          overflowY: "auto",
          boxShadow: "0 20px 60px rgba(0, 0, 0, 0.3)"
        }}>
          <div style={{
            background: "linear-gradient(135deg, #667eea 0%, #764ba2 100%)",
            color: "white",
            padding: "20px",
            borderRadius: "16px 16px 0 0",
            display: "flex",
            justifyContent: "space-between",
            alignItems: "flex-start"
          }}>
            <div>
              <h3 style={{ margin: 0, fontSize: "1.3em", fontWeight: 600 }}>
                {scheduleData.title}
              </h3>
              <p style={{ margin: "5px 0 0 0", fontSize: "0.9em", opacity: 0.9 }}>
                {scheduleData.subtitle}
              </p>
            </div>
            <button 
              style={{
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
              }}
              onClick={() => setShowSchedulePopup(false)}
              onMouseEnter={(e) => {
                e.target.style.background = "rgba(255, 255, 255, 0.2)";
              }}
              onMouseLeave={(e) => {
                e.target.style.background = "none";
              }}
            >
              <X size={20} />
            </button>
          </div>
          
          <div style={{ padding: "20px" }}>
            {/* Greeting */}
            <div style={{ textAlign: "center", marginBottom: "20px" }}>
              <span style={{
                display: "block",
                fontSize: "1.1em",
                fontWeight: 600,
                color: "#333",
                marginBottom: "5px"
              }}>
                {scheduleData.greeting}
              </span>
              <span style={{
                display: "block",
                fontSize: "0.9em",
                color: "#666"
              }}>
                {scheduleData.date}
              </span>
            </div>

            {/* Summary Cards */}
            <div style={{
              display: "grid",
              gridTemplateColumns: "repeat(3, 1fr)",
              gap: "10px",
              marginBottom: "20px"
            }}>
              <div style={{
                background: "#f8f9fa",
                borderRadius: "10px",
                padding: "15px",
                textAlign: "center",
                borderLeft: "4px solid #667eea"
              }}>
                <div style={{
                  fontSize: "1.5em",
                  fontWeight: "bold",
                  color: "#333",
                  display: "block"
                }}>
                  {scheduleData.summary.totalEvents}
                </div>
                <div style={{
                  fontSize: "0.8em",
                  color: "#666",
                  marginTop: "5px"
                }}>
                  Total Events
                </div>
              </div>
              <div style={{
                background: "#f8f9fa",
                borderRadius: "10px",
                padding: "15px",
                textAlign: "center",
                borderLeft: "4px solid #e74c3c"
              }}>
                <div style={{
                  fontSize: "1.5em",
                  fontWeight: "bold",
                  color: "#333",
                  display: "block"
                }}>
                  {scheduleData.summary.pendingMeds}
                </div>
                <div style={{
                  fontSize: "0.8em",
                  color: "#666",
                  marginTop: "5px"
                }}>
                  Medications Due
                </div>
              </div>
              <div style={{
                background: "#f8f9fa",
                borderRadius: "10px",
                padding: "15px",
                textAlign: "center",
                borderLeft: "4px solid #2ecc71"
              }}>
                <div style={{
                  fontSize: "1.5em",
                  fontWeight: "bold",
                  color: "#333",
                  display: "block"
                }}>
                  {scheduleData.summary.appointments}
                </div>
                <div style={{
                  fontSize: "0.8em",
                  color: "#666",
                  marginTop: "5px"
                }}>
                  Appointments
                </div>
              </div>
            </div>

            {/* Next Event Highlight */}
            {scheduleData.highlights.nextEvent && (
              <div style={{ marginBottom: "20px" }}>
                <h4 style={{ margin: "0 0 10px 0", color: "#333", fontSize: "1em" }}>
                  ⏰ Next Up:
                </h4>
                <div style={{
                  background: "#f8f9fa",
                  borderRadius: "10px",
                  padding: "15px",
                  display: "flex",
                  alignItems: "center",
                  gap: "10px",
                  borderLeft: `4px solid ${getEventTypeColor(scheduleData.highlights.nextEvent.type)}`
                }}>
                  <span style={{ display: "flex", alignItems: "center" }}>
                    {getEventTypeIcon(scheduleData.highlights.nextEvent.type)}
                  </span>
                  <div style={{ flex: 1 }}>
                    <span style={{
                      display: "block",
                      fontWeight: 600,
                      color: "#333",
                      marginBottom: "2px"
                    }}>
                      {scheduleData.highlights.nextEvent.title}
                    </span>
                    <span style={{
                      display: "block",
                      fontSize: "0.8em",
                      color: "#666"
                    }}>
                      {scheduleData.highlights.nextEvent.time}
                    </span>
                  </div>
                </div>
              </div>
            )}

            {/* Timeline */}
            {scheduleData.timeline.length > 0 && (
              <div style={{ marginBottom: "20px" }}>
                <h4 style={{ margin: "0 0 15px 0", color: "#333", fontSize: "1em" }}>
                  Today's Schedule:
                </h4>
                <div style={{ display: "flex", flexDirection: "column", gap: "10px" }}>
                  {scheduleData.timeline.map((event, index) => (
                    <div 
                      key={event.id} 
                      style={{
                        display: "flex",
                        alignItems: "center",
                        gap: "12px",
                        padding: "12px",
                        background: event.isUpcoming ? '#fff' : '#f8f9fa',
                        borderRadius: "10px",
                        border: event.isUpcoming ? '1px solid #e9ecef' : 'none'
                      }}
                    >
                      <div 
                        style={{
                          width: "32px",
                          height: "32px",
                          borderRadius: "8px",
                          display: "flex",
                          alignItems: "center",
                          justifyContent: "center",
                          color: "white",
                          backgroundColor: getEventTypeColor(event.type)
                        }}
                      >
                        {getEventTypeIcon(event.type)}
                      </div>
                      <div style={{ flex: 1 }}>
                        <div style={{
                          display: "flex",
                          justifyContent: "space-between",
                          alignItems: "flex-start",
                          marginBottom: "4px"
                        }}>
                          <span style={{
                            fontWeight: 500,
                            color: "#333",
                            fontSize: "0.9em"
                          }}>
                            {event.title}
                          </span>
                          <span style={{
                            fontSize: "0.8em",
                            color: "#666",
                            whiteSpace: "nowrap"
                          }}>
                            {event.time}
                          </span>
                        </div>
                        <div style={{ display: "flex" }}>
                          <span 
                            style={{
                              padding: "2px 8px",
                              borderRadius: "12px",
                              fontSize: "0.7em",
                              fontWeight: 500,
                              background: event.status.includes('Pending') ? '#fff3cd' : '#d1edff',
                              color: event.status.includes('Pending') ? '#856404' : '#0c5460'
                            }}
                          >
                            {event.status}
                          </span>
                        </div>
                      </div>
                    </div>
                  ))}
                </div>
              </div>
            )}

            {/* Quick Actions */}
            <div style={{
              display: "flex",
              gap: "10px",
              justifyContent: "flex-end"
            }}>
              
              <button 
                style={{
                  background: "#6c757d",
                  color: "white",
                  padding: "10px 20px",
                  border: "none",
                  borderRadius: "20px",
                  fontSize: "0.9em",
                  fontWeight: 500,
                  cursor: "pointer"
                }}
                onClick={() => setShowSchedulePopup(false)}
                onMouseEnter={(e) => {
                  e.target.style.background = "#5a6268";
                }}
                onMouseLeave={(e) => {
                  e.target.style.background = "#6c757d";
                }}
              >
                Dismiss
              </button>
            </div>
          </div>
        </div>
      </div>
    );
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
          fontFamily: 'sans-serif',
          color: "#2F4F4F",
        }}
      >
        Loading dashboard...
      </div>
    );
  }

  // Main navigation cards
  const mainCards = [
    {
      title: "Doctor's consultation appointment",
      icon: Calendar,
      color: colorPalette.accents.primary,
      link: "/elderly/medicationAndDoctorPage",
      description: allAppointments.length > 0 
        ? `${allAppointments.length} appointment${allAppointments.length !== 1 ? 's' : ''} scheduled` 
        : "No appointments"
    },
    {
      title: "History and health records",
      icon: FileText,
      color: colorPalette.accents.secondary,
      link: "/elderly/medicationAndDoctorPage",
      description: "View medical history and records"
    },
    {
      title: "Medication Products",
      icon: Pill,
      color: colorPalette.accents.success,
      link: "/elderly/medicationAndDoctorPage",
      description: "Medication management and resources"
    },
  ];

  // Secondary cards
  const secondaryCards = [
    {
      title: "Call caregiver backup",
      icon: Phone,
      color: colorPalette.accents.warning,
      action: "Call Now",
      onClick: () => caregivers.length > 0 && handleCallCaregiver(caregivers[0]),
      description: caregivers.length > 0 
        ? `Call ${caregivers[0]?.name}` 
        : "No caregivers available"
    },
    {
      title: "Check in backup",
      icon: Users,
      color: colorPalette.accents.info,
      action: "Check In",
      onClick: handleCheckIn,
      description: "Update your status and location"
    }
  ];

  // Community cards
  const communityCards = [
    {
      title: "Connect with the community",
      icon: Users,
      color: colorPalette.accents.primary,
      action: "Chat Now",
      link: "/elderly/shareExperience?openMessaging=true",
      description: "Message friends and caregivers directly"
    },
    {
      title: "View Appointments",
      icon: CalendarDays,
      color: colorPalette.accents.danger,
      action: "View All",
      link: "/elderly/viewAppointments",
      description: "Manage your appointments and schedule"
    },
    {
      title: "Create Event Reminder",
      icon: BellRing,
      color: colorPalette.accents.info,
      action: "Create",
      link: "/elderly/createEventReminder",
      description: "Set reminders for important events"
    },
    {
      title: "Update Preferences",
      icon: Settings2,
      color: colorPalette.accents.success,
      action: "Update",
      link: "/elderly/updatePersonalPreference",
      description: "Customize your personal preferences"
    },
    {
      title: "Shared posts with community",
      icon: Share,
      color: colorPalette.accents.secondary,
      action: "View Posts",
      link: "/elderly/shareExperience",
      description: "Read and share experiences"
    },
    {
      title: "Learning recommendations",
      icon: ClipboardList,
      color: colorPalette.accents.warning,
      action: "Explore",
      link: "/elderly/viewLearningResources",
      description: "Educational resources and guides"
    },
    {
      title: "Shared feedback on platform",
      icon: ThumbsUp,
      color: colorPalette.foregrounds.navy,
      action: "View Feedback",
      link: "/elderly/shareExperience",
      description: "See what others are saying"
    }
  ];

  // Card Component
  const Card = ({ card, isLink = true }) => {
    const cardContent = (
      <>
        <div
          style={{
            display: "flex",
            alignItems: "center",
            gap: "15px",
            marginBottom: "10px"
          }}
        >
          <card.icon size={28} color="white" />
          <h3
            style={{
              margin: 0,
              fontSize: "18px",
              fontWeight: "600",
              color: "white"
            }}
          >
            {card.title}
          </h3>
        </div>
        {card.description && (
          <p style={{ 
            margin: "0 0 15px 0", 
            fontSize: "14px", 
            opacity: 0.9,
            lineHeight: "1.4",
            color: "white"
          }}>
            {card.description}
          </p>
        )}
        <div
          style={{
            position: "absolute",
            bottom: "15px",
            right: "15px",
            display: "flex",
            alignItems: "center",
            gap: "5px",
            fontSize: "14px",
            opacity: 0.9,
            color: "white"
          }}
        >
          {card.action || "Access"} <ChevronRight size={16} />
        </div>
      </>
    );

    const cardStyle = {
      background: card.color,
      borderRadius: "15px",
      padding: "25px",
      color: "white",
      boxShadow: "0 4px 15px rgba(0, 0, 0, 0.1)",
      transition: "transform 0.3s ease, box-shadow 0.3s ease",
      cursor: "pointer",
      position: "relative",
      overflow: "hidden",
      height: "100%",
      minHeight: "140px"
    };

    if (isLink && card.link) {
      return (
        <Link 
          to={card.link} 
          style={{ textDecoration: 'none', display: 'block', height: '100%' }}
        >
          <div
            style={cardStyle}
            onMouseEnter={(e) => {
              e.currentTarget.style.transform = "translateY(-5px)";
              e.currentTarget.style.boxShadow = "0 8px 25px rgba(0, 0, 0, 0.15)";
            }}
            onMouseLeave={(e) => {
              e.currentTarget.style.transform = "translateY(0)";
              e.currentTarget.style.boxShadow = "0 4px 15px rgba(0, 0, 0, 0.1)";
            }}
          >
            {cardContent}
          </div>
        </Link>
      );
    } else {
      return (
        <div
          style={cardStyle}
          onClick={card.onClick}
          onMouseEnter={(e) => {
            e.currentTarget.style.transform = "translateY(-5px)";
            e.currentTarget.style.boxShadow = "0 8px 25px rgba(0, 0, 0, 0.15)";
          }}
          onMouseLeave={(e) => {
            e.currentTarget.style.transform = "translateY(0)";
            e.currentTarget.style.boxShadow = "0 4px 15px rgba(0, 0, 0, 0.1)";
          }}
        >
          {cardContent}
        </div>
      );
    }
  };

  const SecondaryCard = ({ card }) => {
    return (
      <div
        style={{
          background: "white",
          borderRadius: "15px",
          padding: "25px",
          boxShadow: "0 4px 6px rgba(0, 0, 0, 0.1)",
          border: "2px solid #e9ecef",
          transition: "all 0.3s ease",
          cursor: "pointer",
          height: "100%",
          minHeight: "140px"
        }}
        onClick={card.onClick}
        onMouseEnter={(e) => {
          e.currentTarget.style.transform = "translateY(-3px)";
          e.currentTarget.style.borderColor = card.color;
        }}
        onMouseLeave={(e) => {
          e.currentTarget.style.transform = "translateY(0)";
          e.currentTarget.style.borderColor = "#e9ecef";
        }}
      >
        <div
          style={{
            display: "flex",
            alignItems: "center",
            gap: "15px",
            marginBottom: "10px"
          }}
        >
          <card.icon size={24} color={card.color} />
          <h3
            style={{
              margin: 0,
              fontSize: "16px",
              fontWeight: "600",
              color: colorPalette.foregrounds.darkGray
            }}
          >
            {card.title}
          </h3>
        </div>
        {card.description && (
          <p style={{ 
            margin: "0 0 15px 0", 
            fontSize: "14px", 
            color: colorPalette.foregrounds.slate,
            lineHeight: "1.4"
          }}>
            {card.description}
          </p>
        )}
        <div
          style={{
            display: "flex",
            justifyContent: "flex-end"
          }}
        >
          <span
            style={{
              background: card.color,
              color: "white",
              padding: "8px 15px",
              borderRadius: "20px",
              fontSize: "14px",
              fontWeight: "500"
            }}
          >
            {card.action}
          </span>
        </div>
      </div>
    );
  };

  // Updated Caregiver Card Component
  const CaregiverCard = ({ caregiver, index }) => {
    const caregiverColors = [
      colorPalette.accents.primary,
      colorPalette.accents.secondary,
      colorPalette.accents.info,
      colorPalette.foregrounds.navy
    ];

    const colorIndex = index % caregiverColors.length;
    const cardColor = caregiverColors[colorIndex];

    return (
      <div
        style={{
          background: cardColor,
          borderRadius: "15px",
          padding: "25px",
          boxShadow: "0 4px 15px rgba(0, 0, 0, 0.08)",
          transition: "all 0.3s ease",
          height: "100%",
          minHeight: "200px",
          border: "1px solid rgba(255, 255, 255, 0.3)",
          position: "relative"
        }}
        onMouseEnter={(e) => {
          e.currentTarget.style.transform = "translateY(-5px)";
          e.currentTarget.style.boxShadow = "0 8px 25px rgba(0, 0, 0, 0.12)";
        }}
        onMouseLeave={(e) => {
          e.currentTarget.style.transform = "translateY(0)";
          e.currentTarget.style.boxShadow = "0 4px 15px rgba(0, 0, 0, 0.08)";
        }}
      >
        {/* Confirmation badge */}
        {!caregiver.confirmed && (
          <div
            style={{
              position: "absolute",
              top: "15px",
              right: "15px",
              background: "rgba(255, 255, 255, 0.9)",
              color: colorPalette.accents.warning,
              padding: "4px 8px",
              borderRadius: "10px",
              fontSize: "10px",
              fontWeight: "bold"
            }}
          >
            Needs Verification
          </div>
        )}

        <div
          style={{
            display: "flex",
            alignItems: "center",
            gap: "15px",
            marginBottom: "20px"
          }}
        >
          <div
            style={{
              width: "50px",
              height: "50px",
              borderRadius: "50%",
              background: "rgba(255, 255, 255, 0.3)",
              display: "flex",
              alignItems: "center",
              justifyContent: "center",
              border: "2px solid rgba(255, 255, 255, 0.5)"
            }}
          >
            <UserCheck size={24} color="white" />
          </div>
          <div>
            <h3
              style={{
                margin: 0,
                fontSize: "18px",
                fontWeight: "600",
                color: "white"
              }}
            >
              {caregiver.name}
            </h3>
            <p style={{ 
              margin: "5px 0 0 0", 
              fontSize: "14px", 
              color: "rgba(255, 255, 255, 0.9)",
              fontWeight: "500"
            }}>
              Caregiver {index + 1}
            </p>
            <p style={{ 
              margin: "2px 0 0 0", 
              fontSize: "12px", 
              color: "rgba(255, 255, 255, 0.7)",
            }}>
              {caregiver.assignmentReason}
            </p>
          </div>
        </div>

        <div
          style={{
            display: "flex",
            flexDirection: "column",
            gap: "12px",
            marginBottom: "20px"
          }}
        >
          <div style={{ display: "flex", alignItems: "center", gap: "10px" }}>
            <Phone size={16} color="white" />
            <span style={{ fontSize: "14px", color: "white" }}>
              {caregiver.phoneNum}
            </span>
          </div>
        </div>
          
        <div
          style={{
            display: "flex",
            gap: "10px",
            justifyContent: "flex-end"
          }}
        >
          <button
            onClick={() => handleEmailCaregiver(caregiver)}
            style={{
              background: "rgba(255, 255, 255, 0.9)",
              color: cardColor,
              border: "none",
              padding: "8px 15px",
              borderRadius: "20px",
              fontSize: "12px",
              fontWeight: "600",
              cursor: "pointer",
              transition: "all 0.3s ease",
              display: "flex",
              alignItems: "center",
              gap: "5px"
            }}
            onMouseEnter={(e) => {
              e.target.style.background = "rgba(255, 255, 255, 1)";
              e.target.style.transform = "scale(1.05)";
            }}
            onMouseLeave={(e) => {
              e.target.style.background = "rgba(255, 255, 255, 0.9)";
              e.target.style.transform = "scale(1)";
            }}
          >
            <Mail size={14} />
            Email
          </button>

          <Link 
            to={`/elderly/shareExperience?openMessaging=true`}
            style={{ textDecoration: 'none' }}
          >
            <button
              style={{
                background: "rgba(255, 255, 255, 0.9)",
                color: cardColor,
                border: "none",
                padding: "8px 15px",
                borderRadius: "20px",
                fontSize: "12px",
                fontWeight: "600",
                cursor: "pointer",
                transition: "all 0.3s ease",
                display: "flex",
                alignItems: "center",
                gap: "5px"
              }}
              onMouseEnter={(e) => {
                e.target.style.background = "rgba(255, 255, 255, 1)";
                e.target.style.transform = "scale(1.05)";
              }}
              onMouseLeave={(e) => {
                e.target.style.background = "rgba(255, 255, 255, 0.9)";
                e.target.style.transform = "scale(1)";
              }}
            >
              <MessageSquare size={14} />
              Message
            </button>
          </Link>
        </div>
      </div>
    );
  };

  return (
    <div
      style={{
        minHeight: "100vh",
        background: colorPalette.backgrounds.light,
        fontFamily: '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif',
        color: colorPalette.foregrounds.darkGray,
        padding: "20px"
      }}
    >
      {/* Add CSS styles for animations */}
      <style>
        {`
          @keyframes spin {
            0% { transform: rotate(0deg); }
            100% { transform: rotate(360deg); }
          }
          @keyframes pulse {
            0% { transform: scale(1); opacity: 1; }
            50% { transform: scale(1.1); opacity: 0.7; }
            100% { transform: scale(1); opacity: 1; }
          }
        `}
      </style>

      {/* Schedule Popup */}
      <SchedulePopup />

      {/* Header Section */}
      <div
        style={{
          maxWidth: "1200px",
          margin: "0 auto 30px",
          padding: "20px",
          background: "white",
          borderRadius: "15px",
          boxShadow: "0 4px 6px rgba(0, 0, 0, 0.1)",
          textAlign: "center",
          position: "relative"
        }}
      >
        {/* Schedule Button */}
<button
  onClick={fetchScheduleData}
  disabled={popupLoading}
  style={{
    position: "absolute",
    top: "20px",
    right: "20px",
    background: popupLoading ? colorPalette.accents.warning : colorPalette.accents.primary,
    color: "white",
    border: "none",
    padding: "10px 15px",
    borderRadius: "25px", // Changed from 50% to make it pill-shaped
    display: "flex",
    alignItems: "center",
    justifyContent: "center",
    gap: "8px", // Space between icon and text
    cursor: popupLoading ? "not-allowed" : "pointer",
    boxShadow: "0 4px 10px rgba(0, 0, 0, 0.2)",
    transition: "all 0.3s ease",
    fontSize: "14px", // Changed from 0 to show text
    fontWeight: "500",
    minWidth: "160px", // Ensure consistent width
    height: "50px"
  }}
  onMouseEnter={(e) => {
    if (!popupLoading) {
      e.target.style.transform = "scale(1.1)";
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
      width: "20px",
      height: "20px",
      border: "2px solid transparent",
      borderTop: "2px solid white",
      borderRadius: "50%",
      animation: "spin 1s linear infinite"
    }} />
  ) : (
    <>
      <Calendar size={20} />
      Today's Schedule
    </>
  )}
</button>

        <h1
          style={{
            fontSize: "28px",
            fontWeight: "bold",
            color: colorPalette.foregrounds.darkGray,
            margin: "0 0 10px 0"
          }}
        >
          Welcome back, {userName}
        </h1>
        <p style={{ color: colorPalette.foregrounds.slate, margin: 0 }}>
          Your personalized care dashboard
        </p>

        {caregivers.length > 0 && (
          <div style={{ marginTop: "10px" }}>
            <span style={{ 
              fontSize: "14px", 
              color: colorPalette.accents.success,
              fontWeight: "500"
            }}>
              ✓ {caregivers.length} caregiver{caregivers.length !== 1 ? 's' : ''} assigned
            </span>
          </div>
        )}
      </div>

      {/* Caregivers Section */}
      {caregivers.length > 0 ? (
        <div
          style={{
            maxWidth: "1200px",
            margin: "0 auto 30px"
          }}
        >
          <h2
            style={{
              fontSize: "20px",
              fontWeight: "600",
              color: colorPalette.foregrounds.darkGray,
              marginBottom: "20px",
              paddingLeft: "10px",
              display: "flex",
              alignItems: "center",
              gap: "10px"
            }}
          >
            <UserCheck size={24} color={colorPalette.accents.primary} />
            Your Caregivers
          </h2>
          <div
            style={{
              display: "grid",
              gridTemplateColumns: "repeat(auto-fit, minmax(320px, 1fr))",
              gap: "20px"
            }}
          >
            {caregivers.map((caregiver, index) => (
              <CaregiverCard 
                key={caregiver.email} 
                caregiver={caregiver} 
                index={index} 
              />
            ))}
          </div>
        </div>
      ) : (
        <div
          style={{
            maxWidth: "1200px",
            margin: "0 auto 30px",
            padding: "20px",
            background: "#fff3cd",
            borderRadius: "10px",
            border: "1px solid #ffeaa7"
          }}
        >
          <h3 style={{ color: "#856404", margin: "0 0 10px 0" }}>
            No Caregivers Found
          </h3>
          <p style={{ color: "#856404", margin: 0, fontSize: "14px" }}>
            You are not currently assigned to any caregivers. Please contact your administrator to get assigned to a caregiver.
          </p>
        </div>
      )}

      <br/>

      {/* Announcements Widget */}
      {uid && <AnnouncementsWidget uid={uid} userType="elderly" />}
      <ToastContainer position="top-right" autoClose={5000} />

      {/* Main Navigation Cards */}
      <div
        style={{
          maxWidth: "1200px",
          margin: "0 auto 30px",
        }}
      >
        <h2
          style={{
            fontSize: "20px",
            fontWeight: "600",
            color: colorPalette.foregrounds.darkGray,
            marginBottom: "20px",
            paddingLeft: "10px"
          }}
        >
          Quick Access
        </h2>
        <div
          style={{
            display: "grid",
            gridTemplateColumns: "repeat(auto-fit, minmax(280px, 1fr))",
            gap: "20px"
          }}
        >
          {mainCards.map((card, i) => (
            <Card key={card.title} card={card} isLink={true} />
          ))}
        </div>
      </div>

      {/* Secondary Actions */}
      <div
        style={{
          maxWidth: "1200px",
          margin: "0 auto 30px"
        }}
      >
        <h2
          style={{
            fontSize: "20px",
            fontWeight: "600",
            color: colorPalette.foregrounds.darkGray,
            marginBottom: "20px",
            paddingLeft: "10px",
            marginTop: "60px"
          }}
        >
          Quick Actions
        </h2>
        <div
          style={{
            display: "grid",
            gridTemplateColumns: "repeat(auto-fit, minmax(250px, 1fr))",
            gap: "30px"
          }}
        >
          {secondaryCards.map((card, i) => (
            <SecondaryCard key={card.title} card={card} />
          ))}<br/>
        </div>
      </div>

      {/* Community & Learning Section */}
      <div
        style={{
          maxWidth: "1200px",
          margin: "0 auto 30px"
        }}
      >
        <h2
          style={{
            fontSize: "20px",
            fontWeight: "600",
            color: colorPalette.foregrounds.darkGray,
            marginTop: "70px",
            marginBottom: "20px",
            paddingLeft: "10px"
          }}
        >
          Community & Learning
        </h2>
        <div
          style={{
            display: "grid",
            gridTemplateColumns: "repeat(auto-fit, minmax(280px, 1fr))",
            gap: "25px",
            rowGap: "80px"
          }}
        >
          {communityCards.map((card, i) => (
            <Card key={card.title} card={card} isLink={true} />
          ))}
        </div>
      </div>
     
      <br/><br/>

      {/* Floating AI Assistant */}
      {currentUser && <FloatingAssistant userEmail={currentUser} />}

      <Footer />
    </div>
  );
}