// src/pages/ViewActivitiesPage.js
import React, { useEffect, useState } from "react";
import { useNavigate } from "react-router-dom";
import activities1 from "../components/images/activities1.webp"; // Hero image
import Footer from "../footer";
import { 
  fetchAllActivities, 
  registerForActivity, 
  getUserRegistrations, 
  cancelRegistration 
} from "../controller/viewActivitiesController";
import FloatingAssistant from "../components/floatingassistantChat";

const currentUser = localStorage.getItem("loggedInEmail");

const styles = {
  page: {
    maxWidth: "1200px",
    margin: "0 auto",
    padding: "32px 16px 64px",
    fontFamily: "'Inter', sans-serif",
  },
  hero: {
    width: "100%",
    height: "60vh",
    objectFit: "cover",
    borderRadius: "12px",
    marginBottom: "32px",
  },
  title: {
    fontSize: "2rem",
    fontWeight: "700",
    marginBottom: "12px",
    textAlign: "center",
  },
  subtitle: {
    fontSize: "1rem",
    color: "#555",
    textAlign: "center",
    marginBottom: "32px",
  },
  // New tab styles
  tabContainer: {
    display: "flex",
    justifyContent: "center",
    marginBottom: "32px",
    borderBottom: "1px solid #ddd",
  },
  tab: {
    padding: "12px 24px",
    fontSize: "1rem",
    fontWeight: "600",
    background: "none",
    border: "none",
    cursor: "pointer",
    borderBottom: "3px solid transparent",
    transition: "all 0.2s ease",
  },
  activeTab: {
    borderBottom: "3px solid #2d6cdf",
    color: "#2d6cdf",
  },
  toolbar: {
    display: "flex",
    flexWrap: "wrap",
    gap: "16px",
    justifyContent: "center",
    marginBottom: "32px",
  },
  searchInput: {
    flex: "1 1 250px",
    padding: "12px 16px",
    borderRadius: "12px",
    border: "1px solid #ddd",
    fontSize: "16px",
    outline: "none",
    transition: "all 0.2s ease",
  },
  select: {
    padding: "12px 16px",
    borderRadius: "12px",
    border: "1px solid #ddd",
    background: "#fff",
    fontSize: "16px",
    cursor: "pointer",
  },
  activitiesList: {
    display: "grid",
    gridTemplateColumns: "repeat(auto-fill, minmax(300px, 1fr))",
    gap: "24px",
  },
  // New registrations list styles
  registrationsList: {
    display: "flex",
    flexDirection: "column",
    gap: "16px",
  },
  registrationCard: {
    display: "flex",
    alignItems: "center",
    padding: "16px",
    borderRadius: "12px",
    background: "#fff",
    boxShadow: "0 2px 8px rgba(0,0,0,0.1)",
    gap: "16px",
  },
  registrationImage: {
    width: "80px",
    height: "80px",
    objectFit: "cover",
    borderRadius: "8px",
  },
  registrationInfo: {
    flex: "1",
  },
  registrationTitle: {
    fontSize: "1.1rem",
    fontWeight: "600",
    marginBottom: "4px",
  },
  registrationDetails: {
    fontSize: "0.9rem",
    color: "#666",
    marginBottom: "4px",
  },
  cancelButton: {
    padding: "8px 16px",
    fontSize: "0.9rem",
    border: "none",
    borderRadius: "8px",
    backgroundColor: "#dc3545",
    color: "#fff",
    fontWeight: "600",
    cursor: "pointer",
    transition: "all 0.2s ease",
  },
  cancelButtonDisabled: {
    padding: "8px 16px",
    fontSize: "0.9rem",
    border: "none",
    borderRadius: "8px",
    backgroundColor: "#6c757d",
    color: "#fff",
    fontWeight: "600",
    cursor: "not-allowed",
  },
  cancelButtonHover: {
    backgroundColor: "#c82333",
  },
  card: {
    display: "flex",
    flexDirection: "column",
    borderRadius: "16px",
    overflow: "hidden",
    background: "#fff",
    boxShadow: "0 4px 16px rgba(0,0,0,0.08)",
    cursor: "pointer",
    transition: "transform 0.3s ease, box-shadow 0.3s ease",
    minHeight: "350px",
  },
  cardHover: {
    transform: "translateY(-4px)",
    boxShadow: "0 12px 24px rgba(0,0,0,0.12)",
  },
  thumbImg: {
    width: "100%",
    height: "180px",
    objectFit: "cover",
    transition: "transform 0.3s ease",
  },
  cardBody: {
    padding: "16px",
    display: "flex",
    flexDirection: "column",
    gap: "9px",
    flex: "1",
  },
  activityTitle: {
    fontSize: "1.2rem",
    fontWeight: "600",
    color: "#222",
    minHeight: "38px",
  },
  activitySummary: {
    fontSize: "0.95rem",
    color: "#555",
    flex: "1",
    minHeight: "30px",
  },
  meta: {
    display: "flex",
    flexWrap: "wrap",
    gap: "8px",
  },
  chip: {
    padding: "6px 12px",
    borderRadius: "999px",
    background: "#f0f4ff",
    color: "#2d6cdf",
    fontSize: "0.75rem",
    fontWeight: "500",
  },
  button: {
    marginTop: "auto",
    padding: "10px 16px",
    fontSize: "0.9rem",
    border: "none",
    borderRadius: "12px",
    backgroundColor: "#2d6cdf",
    color: "#fff",
    fontWeight: "600",
    cursor: "pointer",
    transition: "all 0.2s ease",
    alignSelf: "center",
    width: "90%",
  },
  buttonDisabled: {
    marginTop: "auto",
    padding: "10px 16px",
    fontSize: "0.9rem",
    border: "none",
    borderRadius: "12px",
    backgroundColor: "#6c757d",
    color: "#fff",
    fontWeight: "600",
    cursor: "not-allowed",
    alignSelf: "center",
    width: "90%",
  },
  buttonHover: {
    backgroundColor: "#1b4bb8",
  },
  registerPanel: {
    marginTop: "12px",
    padding: "12px",
    backgroundColor: "#f9f9f9",
    borderRadius: "12px",
    boxShadow: "0 4px 12px rgba(0,0,0,0.05)",
    display: "flex",
    flexDirection: "column",
    gap: "8px",
  },
  input: {
    padding: "8px",
    borderRadius: "8px",
    border: "1px solid #ccc",
    fontSize: "0.9rem",
  },
  emptyState: {
    textAlign: "center",
    padding: "40px",
    color: "#666",
  },
  warningText: {
    color: "#dc3545",
    fontSize: "0.8rem",
    marginTop: "4px",
  },
  pastEventBadge: {
    backgroundColor: "#6c757d",
    color: "white",
    padding: "4px 8px",
    borderRadius: "4px",
    fontSize: "0.7rem",
    fontWeight: "600",
  },
  // Modal styles for activity details
  modalOverlay: {
    position: "fixed",
    top: 0,
    left: 0,
    right: 0,
    bottom: 0,
    backgroundColor: "rgba(0, 0, 0, 0.7)",
    display: "flex",
    justifyContent: "center",
    alignItems: "center",
    zIndex: 1000,
    padding: "20px",
  },
  modalContent: {
    backgroundColor: "white",
    borderRadius: "16px",
    maxWidth: "600px",
    width: "100%",
    maxHeight: "80vh",
    overflowY: "auto",
    boxShadow: "0 20px 40px rgba(0,0,0,0.3)",
  },
  modalHeader: {
    padding: "20px 24px 0",
    display: "flex",
    justifyContent: "space-between",
    alignItems: "flex-start",
  },
  modalTitle: {
    fontSize: "1.5rem",
    fontWeight: "700",
    color: "#222",
    margin: 0,
    flex: 1,
  },
  closeButton: {
    background: "none",
    border: "none",
    fontSize: "1.5rem",
    cursor: "pointer",
    color: "#666",
    padding: "4px 8px",
    borderRadius: "4px",
    transition: "all 0.2s ease",
  },
  modalImage: {
    width: "100%",
    height: "250px",
    objectFit: "cover",
    marginTop: "16px",
  },
  modalBody: {
    padding: "20px 24px",
  },
  modalDescription: {
    fontSize: "1rem",
    lineHeight: "1.6",
    color: "#444",
    marginBottom: "20px",
  },
  modalMeta: {
    display: "flex",
    flexWrap: "wrap",
    gap: "12px",
    marginBottom: "20px",
  },
  modalChip: {
    padding: "8px 16px",
    borderRadius: "999px",
    background: "#f0f4ff",
    color: "#2d6cdf",
    fontSize: "0.85rem",
    fontWeight: "500",
  },
  modalTags: {
    display: "flex",
    flexWrap: "wrap",
    gap: "8px",
    marginBottom: "20px",
  },
  tag: {
    padding: "4px 12px",
    borderRadius: "999px",
    background: "#f8f9fa",
    color: "#495057",
    fontSize: "0.75rem",
    fontWeight: "500",
    border: "1px solid #e9ecef",
  },
  modalActions: {
    display: "flex",
    gap: "12px",
    justifyContent: "flex-end",
  },
  secondaryButton: {
    padding: "10px 20px",
    fontSize: "0.9rem",
    border: "1px solid #2d6cdf",
    borderRadius: "12px",
    backgroundColor: "transparent",
    color: "#2d6cdf",
    fontWeight: "600",
    cursor: "pointer",
    transition: "all 0.2s ease",
  },
};

function ViewActivitiesPage() {
  const navigate = useNavigate();
  const [activeTab, setActiveTab] = useState("activities"); // "activities" or "registrations"
  const [query, setQuery] = useState("");
  const [sortBy, setSortBy] = useState("title");
  const [activities, setActivities] = useState([]);
  const [registrations, setRegistrations] = useState([]);
  const [hoveredCard, setHoveredCard] = useState(null);
  const [registeringId, setRegisteringId] = useState(null);
  const [selectedDate, setSelectedDate] = useState("");
  const [selectedTime, setSelectedTime] = useState("");
  const [loading, setLoading] = useState(false);
  const [selectedActivity, setSelectedActivity] = useState(null); // For modal

  // Helper function to check if a date/time is in the past
  const isPastDateTime = (date, time) => {
    const selectedDateTime = new Date(`${date}T${time}`);
    const now = new Date();
    return selectedDateTime < now;
  };

  // Helper function to check if a registration is for a past event
  const isPastRegistration = (registration) => {
    const eventDateTime = new Date(`${registration.date}T${registration.time}`);
    const now = new Date();
    return eventDateTime < now;
  };

  // Enhanced authentication function
  const getAuthData = () => {
    try {
      const isAuthenticated = localStorage.getItem("isLoggedIn") === "true";
      const userType = localStorage.getItem("userType");
      const userId = localStorage.getItem("userId");
      const userEmail = localStorage.getItem("loggedInEmail");
      
      console.log("🔐 Current Auth Data:", { 
        isAuthenticated, 
        userType, 
        userId, 
        userEmail 
      });
      
      // Use email as primary identifier since userId might be null
      const isValidElderly = isAuthenticated && userType === "elderly" && userEmail;
      
      return {
        isAuthenticated,
        userType,
        userId,
        userEmail,
        isValidElderly
      };
    } catch (error) {
      console.error("Error reading auth data:", error);
      return {
        isAuthenticated: false,
        userType: null,
        userId: null,
        userEmail: null,
        isValidElderly: false
      };
    }
  };

  const authData = getAuthData();
  const { isAuthenticated, userType, userEmail, isValidElderly } = authData;

  useEffect(() => {
    loadActivities();
  }, []);

  useEffect(() => {
    if (activeTab === "registrations" && isValidElderly) {
      loadRegistrations();
    }
  }, [activeTab, isValidElderly]);

  const loadActivities = async () => {
    setLoading(true);
    const result = await fetchAllActivities();
    if (result.success) {
      setActivities(result.data);
    } else {
      console.error(result.error);
    }
    setLoading(false);
  };

  const loadRegistrations = async () => {
    if (!userEmail) return;
    
    setLoading(true);
    console.log("🔄 Loading registrations for:", userEmail);
    const result = await getUserRegistrations(userEmail);
    console.log("📦 Registration result:", result);
    
    if (result.success) {
      setRegistrations(result.data);
    } else {
      console.error("❌ Error loading registrations:", result.error);
    }
    setLoading(false);
  };

  const filtered = activities.filter((a) =>
    a.title?.toLowerCase().includes(query.toLowerCase())
  );
  const sorted = [...filtered].sort((a, b) =>
    (a[sortBy] || "")
      .toString()
      .localeCompare((b[sortBy] || "").toString())
  );

  // Function to handle activity card click
  const handleActivityClick = (activity) => {
    setSelectedActivity(activity);
  };

  // Function to close modal
  const handleCloseModal = () => {
    setSelectedActivity(null);
  };

  const handleRegisterClick = (activity, event) => {
    event?.stopPropagation(); // Prevent triggering the card click
    
    const currentAuth = getAuthData();
    
    console.log("🖱️ Register button clicked with auth:", currentAuth);
    
    if (!currentAuth.isAuthenticated) {
      alert("Please log in to register for activities.");
      navigate("/login");
      return;
    }

    if (currentAuth.userType !== "elderly") {
      alert("Only elderly users can register for activities.");
      return;
    }

    if (!currentAuth.userEmail) {
      alert("User authentication error. Please log in again.");
      navigate("/login");
      return;
    }

    setRegisteringId((prev) => (prev === activity.id ? null : activity.id));
    // Reset date and time when opening registration panel
    setSelectedDate("");
    setSelectedTime("");
  };

  const handleConfirmRegister = async (activity, event) => {
    event?.stopPropagation(); // Prevent triggering the card click
    
    if (!selectedDate || !selectedTime) {
      alert("Please select a date and time.");
      return;
    }

    // Check if selected date/time is in the past
    if (isPastDateTime(selectedDate, selectedTime)) {
      alert("Cannot register for past dates and times. Please select a future date and time.");
      return;
    }

    // Get fresh auth data to ensure it's current
    const currentAuth = getAuthData();
    
    console.log("✅ Confirm registration with auth:", currentAuth);
    
    if (!currentAuth.isValidElderly) {
      alert("Authentication error. Please log in again as an elderly user.");
      navigate("/login");
      return;
    }

    console.log("📝 Registering with data:", {
      activityId: activity.id,
      activityTitle: activity.title,
      userEmail: currentAuth.userEmail,
      selectedDate,
      selectedTime
    });

    // Pass userEmail to controller instead of userId
    const result = await registerForActivity(
      activity.id, 
      currentAuth.userEmail,
      selectedDate, 
      selectedTime
    );
    
    if (result.success) {
      alert(result.message);
      setRegisteringId(null);
      setSelectedDate("");
      setSelectedTime("");
      // Reload registrations if we're on that tab
      if (activeTab === "registrations") {
        loadRegistrations();
      }
    } else {
      alert(result.error);
      if (result.error.includes("log in") || result.error.includes("authenticated")) {
        navigate("/login");
      }
    }
  };

  const handleCancelRegistration = async (registration) => {
    // Check if the registration is for a past event
    if (isPastRegistration(registration)) {
      alert("Cannot cancel registration for past events. This activity has already occurred.");
      return;
    }

    if (!window.confirm(`Are you sure you want to cancel your registration for "${registration.activityTitle}" on ${registration.date} at ${registration.time}?`)) {
      return;
    }

    const result = await cancelRegistration(registration.activityId, registration.registrationId);
    
    if (result.success) {
      alert(result.message);
      // Refresh the registrations list
      loadRegistrations();
    } else {
      alert(result.error);
    }
  };

  // Activity Details Modal Component
  const ActivityDetailsModal = ({ activity, onClose }) => {
    if (!activity) return null;

    return (
      <div style={styles.modalOverlay} onClick={onClose}>
        <div style={styles.modalContent} onClick={(e) => e.stopPropagation()}>
          <div style={styles.modalHeader}>
            <h2 style={styles.modalTitle}>{activity.title}</h2>
            <button 
              style={styles.closeButton}
              onClick={onClose}
              onMouseEnter={(e) => e.target.style.backgroundColor = "#f0f0f0"}
              onMouseLeave={(e) => e.target.style.backgroundColor = "transparent"}
            >
              ×
            </button>
          </div>
          
          {activity.image && (
            <img src={activity.image} alt={activity.title} style={styles.modalImage} />
          )}
          
          <div style={styles.modalBody}>
            <p style={styles.modalDescription}>
              {activity.description || activity.summary || "No description available."}
            </p>
            
            <div style={styles.modalMeta}>
              {activity.category && <span style={styles.modalChip}>{activity.category}</span>}
              {activity.difficulty && <span style={styles.modalChip}>{activity.difficulty}</span>}
              {activity.duration && <span style={styles.modalChip}>{activity.duration}</span>}
            </div>
            
            {activity.tags && activity.tags.length > 0 && (
              <div style={styles.modalTags}>
                {activity.tags.map((tag, index) => (
                  <span key={index} style={styles.tag}>
                    #{tag}
                  </span>
                ))}
              </div>
            )}
            
            <div style={styles.modalActions}>
              <button 
                style={styles.secondaryButton}
                onClick={onClose}
              >
                Close
              </button>
              {isAuthenticated && userType === "elderly" && (
                <button 
                  style={styles.button}
                  onClick={(e) => {
                    onClose();
                    handleRegisterClick(activity, e);
                  }}
                >
                  Register Now
                </button>
              )}
            </div>
          </div>
        </div>
      </div>
    );
  };

  const renderActivitiesTab = () => (
    <>
      <div style={styles.toolbar}>
        <input
          type="search"
          placeholder="Search activities..."
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          style={styles.searchInput}
        />
        <select
          value={sortBy}
          onChange={(e) => setSortBy(e.target.value)}
          style={styles.select}
        >
          <option value="title">Title</option>
          <option value="category">Category</option>
          <option value="difficulty">Difficulty</option>
        </select>
      </div>

      <div style={styles.activitiesList}>
        {sorted.map((activity) => (
          <div
            key={activity.id}
            style={{
              ...styles.card,
              ...(hoveredCard === activity.id ? styles.cardHover : {}),
            }}
            onMouseEnter={() => setHoveredCard(activity.id)}
            onMouseLeave={() => setHoveredCard(null)}
            onClick={() => handleActivityClick(activity)}
          >
            {activity.image && <img src={activity.image} alt="" style={styles.thumbImg} />}
            <div style={styles.cardBody}>
              <h3 style={styles.activityTitle}>{activity.title}</h3>
              <p style={styles.activitySummary}>{activity.summary}</p>
              <div style={styles.meta}>
                {activity.category && <span style={styles.chip}>{activity.category}</span>}
                {activity.difficulty && <span style={styles.chip}>{activity.difficulty}</span>}
                {activity.duration && <span style={styles.chip}>{activity.duration}</span>}
              </div>

              {/* Show register button ONLY for logged-in elderly users */}
              {isAuthenticated && userType === "elderly" && (
                <>
                  <button
                    style={styles.button}
                    onClick={(e) => handleRegisterClick(activity, e)}
                  >
                    {registeringId === activity.id
                      ? "Cancel"
                      : "Register"}
                  </button>

                  {registeringId === activity.id && (
                    <div style={styles.registerPanel} onClick={(e) => e.stopPropagation()}>
                      <label>
                        Select Date:
                        <input
                          type="date"
                          style={styles.input}
                          value={selectedDate}
                          onChange={(e) => setSelectedDate(e.target.value)}
                          min={new Date().toISOString().split('T')[0]} // Set min date to today
                        />
                      </label>
                      <label>
                        Select Time:
                        <input
                          type="time"
                          style={styles.input}
                          value={selectedTime}
                          onChange={(e) => setSelectedTime(e.target.value)}
                        />
                      </label>
                      {/* Show warning if selected date/time is in past */}
                      {selectedDate && selectedTime && isPastDateTime(selectedDate, selectedTime) && (
                        <p style={styles.warningText}>
                          ⚠️ Cannot register for past dates and times
                        </p>
                      )}
                      <button
                        style={
                          selectedDate && selectedTime && !isPastDateTime(selectedDate, selectedTime)
                            ? styles.button
                            : styles.buttonDisabled
                        }
                        onClick={(e) => handleConfirmRegister(activity, e)}
                        disabled={!selectedDate || !selectedTime || isPastDateTime(selectedDate, selectedTime)}
                      >
                        Confirm Registration
                      </button>
                    </div>
                  )}
                </>
              )}

              {/* Show nothing for non-logged-in users and non-elderly users */}
            </div>
          </div>
        ))}
      </div>
    </>
  );

  const renderRegistrationsTab = () => {
    if (!isAuthenticated) {
      return (
        <div style={styles.emptyState}>
          <h3>Please log in to view your registrations</h3>
          <button 
            style={styles.button} 
            onClick={() => navigate("/login")}
          >
            Log In
          </button>
        </div>
      );
    }

    if (userType !== "elderly") {
      return (
        <div style={styles.emptyState}>
          <h3>Only elderly users can register for activities</h3>
        </div>
      );
    }

    // Show loading state
    if (loading) {
      return (
        <div style={styles.emptyState}>
          <h3>Loading your registrations...</h3>
          <p>Please wait while we fetch your activity registrations.</p>
        </div>
      );
    }

    // Check if registrations is an array and has length
    if (!registrations || !Array.isArray(registrations) || registrations.length === 0) {
      return (
        <div style={styles.emptyState}>
          <h3>No registrations found</h3>
          <p>You haven't registered for any activities yet.</p>
          <button 
            style={styles.button} 
            onClick={() => setActiveTab("activities")}
          >
            Browse Activities
          </button>
        </div>
      );
    }

    return (
      <div style={styles.registrationsList}>
        {registrations.map((registration) => {
          const isPast = isPastRegistration(registration);
          return (
            <div key={registration.registrationId} style={styles.registrationCard}>
              {registration.activityImage && (
                <img 
                  src={registration.activityImage} 
                  alt={registration.activityTitle}
                  style={styles.registrationImage}
                  onError={(e) => {
                    e.target.style.display = 'none'; // Hide broken images
                  }}
                />
              )}
              <div style={styles.registrationInfo}>
                <div style={{ display: 'flex', alignItems: 'center', gap: '8px', marginBottom: '4px' }}>
                  <h3 style={styles.registrationTitle}>{registration.activityTitle}</h3>
                  {isPast && <span style={styles.pastEventBadge}>PAST EVENT</span>}
                </div>
                <p style={styles.registrationDetails}>
                  <strong>Date:</strong> {registration.date} | <strong>Time:</strong> {registration.time}
                </p>
                <p style={styles.registrationDetails}>
                  <strong>Registered on:</strong> {registration.timestamp ? new Date(registration.timestamp).toLocaleDateString() : 'Unknown date'}
                </p>
                <p style={styles.registrationDetails}>
                  <strong>Status:</strong> {registration.status || "confirmed"}
                </p>
                {isPast && (
                  <p style={styles.warningText}>
                    This activity has already occurred and cannot be cancelled.
                  </p>
                )}
              </div>
              <button
                style={isPast ? styles.cancelButtonDisabled : styles.cancelButton}
                onClick={() => !isPast && handleCancelRegistration(registration)}
                disabled={isPast}
              >
                {isPast ? "Event Passed" : "Cancel Registration"}
              </button>
            </div>
          );
        })}
      </div>
    );
  };

  return (
    <div style={{marginTop: '-15px'}}>
      <img src={activities1} alt="Activities Hero" style={styles.hero} />
      <div style={styles.page}>
        <h1 style={styles.title}>Activities on AllCare Platform</h1>
        <p style={styles.subtitle}>
          Explore activities designed to engage, educate, and empower elderly users.
        </p>

        {/* Tab Navigation - Only show for logged-in elderly users */}
        {isAuthenticated && userType === "elderly" && (
          <div style={styles.tabContainer}>
            <button
              style={{
                ...styles.tab,
                ...(activeTab === "activities" ? styles.activeTab : {})
              }}
              onClick={() => setActiveTab("activities")}
            >
              Browse Activities
            </button>
            <button
              style={{
                ...styles.tab,
                ...(activeTab === "registrations" ? styles.activeTab : {})
              }}
              onClick={() => setActiveTab("registrations")}
            >
              My Registrations
            </button>
          </div>
        )}

        {/* Floating AI Assistant */}
        {currentUser && <FloatingAssistant userEmail={currentUser} />}

        {/* Tab Content */}
        {/* For non-logged-in users, always show activities without tabs */}
        {!isAuthenticated || userType !== "elderly" ? (
          renderActivitiesTab()
        ) : (
          activeTab === "activities" ? renderActivitiesTab() : renderRegistrationsTab()
        )}
      </div>

      {/* Activity Details Modal */}
      {selectedActivity && (
        <ActivityDetailsModal 
          activity={selectedActivity} 
          onClose={handleCloseModal} 
        />
      )}

      <Footer />
    </div>
  );
}

export default ViewActivitiesPage;