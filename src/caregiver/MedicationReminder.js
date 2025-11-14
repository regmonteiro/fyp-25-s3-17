import React, { useState, useEffect } from "react";
import {
  createMedicationReminder,
  subscribeToMedicationReminders,
  deleteMedicationReminder,
  toggleMedicationCompletion,
} from "../controller/createMedicationReminderController";
import {
  getLinkedElderlyId,
  getElderlyInfo,
  getMultipleElderlyInfo,
} from "../controller/appointmentController";
import Footer from "../footer";

// Helper function to encode email for Firebase path
const encodeEmailForFirebase = (email) => {
  return email.replace(/\./g, ',').replace(/@/g, '_at_');
};

// Helper function to decode email from Firebase path
const decodeEmailFromFirebase = (encodedEmail) => {
  return encodedEmail.replace(/,/g, '.').replace(/_at_/g, '@');
};

const styles = {
  container: { 
    maxWidth: "1200px", 
    margin: "-40px auto", 
    padding: "25px", 
    background: "linear-gradient(135deg, #f8fafc 0%, #f1f5f9 100%)", 
    borderRadius: "20px", 
    boxShadow: "0 8px 25px rgba(0,0,0,0.1)", 
    fontFamily: "'Segoe UI', Tahoma, Geneva, Verdana, sans-serif", 
    border: "1px solid #e2e8f0",
    fontSize: "20px",
  },
  heading: { 
    fontSize: "28px", 
    fontWeight: "700", 
    marginBottom: "20px", 
    textAlign: "center",
    color: "#1e293b",
    background: "linear-gradient(135deg, #3b82f6, #1d4ed8)",
    WebkitBackgroundClip: "text",
    WebkitTextFillColor: "transparent",
    backgroundClip: "text"
  },
  form: { 
    display: "flex", 
    flexDirection: "column", 
    gap: "20px",
    background: "white",
    padding: "25px",
    borderRadius: "16px",
    boxShadow: "0 4px 12px rgba(0,0,0,0.08)",
    border: "1px solid #f1f5f9"
  },
  label: { 
    fontWeight: "600", 
    marginBottom: "8px",
    color: "#374151",
    fontSize: "14px",
    display: "block"
  },
  input: { 
    width: "100%", 
    padding: "12px 16px", 
    borderRadius: "10px", 
    border: "2px solid #e5e7eb",
    fontSize: "15px",
    transition: "all 0.3s ease",
    backgroundColor: "#fafafa",
    outline: "none",
    boxSizing: "border-box"
  },
  inputFocus: {
    borderColor: "#3b82f6",
    backgroundColor: "white",
    boxShadow: "0 0 0 3px rgba(59, 130, 246, 0.1)"
  },
  select: { 
    width: "100%", 
    padding: "12px 16px", 
    borderRadius: "10px", 
    border: "2px solid #e5e7eb", 
    background: "#fafafa",
    fontSize: "15px",
    transition: "all 0.3s ease",
    outline: "none",
    cursor: "pointer",
    boxSizing: "border-box"
  },
  selectFocus: {
    borderColor: "#3b82f6",
    backgroundColor: "white",
    boxShadow: "0 0 0 3px rgba(59, 130, 246, 0.1)"
  },
  button: { 
    background: "linear-gradient(135deg, #3b82f6, #1d4ed8)", 
    color: "#fff", 
    padding: "14px 20px", 
    border: "none", 
    borderRadius: "12px", 
    fontWeight: "600", 
    cursor: "pointer", 
    marginTop: "10px",
    fontSize: "16px",
    transition: "all 0.3s ease",
    boxShadow: "0 4px 12px rgba(59, 130, 246, 0.3)"
  },
  buttonHover: {
    transform: "translateY(-2px)",
    boxShadow: "0 6px 20px rgba(59, 130, 246, 0.4)"
  },
  messageError: { 
    color: "#dc2626", 
    fontSize: "14px",
    fontWeight: "500",
    padding: "12px 16px",
    backgroundColor: "#fef2f2",
    border: "1px solid #fecaca",
    borderRadius: "8px",
    margin: "10px 0"
  },
  messageSuccess: { 
    color: "#059669", 
    fontSize: "14px",
    fontWeight: "500",
    padding: "12px 16px",
    backgroundColor: "#f0fdf4",
    border: "1px solid #bbf7d0",
    borderRadius: "8px",
    margin: "10px 0"
  },
  listContainer: { 
    marginTop: "35px", 
    background: "white", 
    borderRadius: "16px", 
    padding: "25px", 
    boxShadow: "0 4px 12px rgba(0,0,0,0.08)",
    border: "1px solid #f1f5f9"
  },
  listHeading: { 
    fontSize: "22px", 
    fontWeight: "700", 
    marginBottom: "15px",
    color: "#1e293b"
  },
  listItem: { 
    display: "flex", 
    justifyContent: "space-between", 
    alignItems: "center", 
    background: "linear-gradient(135deg, #ffffff 0%, #f8fafc 100%)", 
    border: "2px solid #f1f5f9",
    borderRadius: "14px", 
    padding: "18px 20px", 
    marginBottom: "12px",
    transition: "all 0.3s ease",
    boxShadow: "0 2px 8px rgba(0,0,0,0.04)",
    gap: "15px"
  },
  listItemHover: {
    transform: "translateY(-2px)",
    boxShadow: "0 6px 20px rgba(0,0,0,0.08)",
    borderColor: "#e2e8f0"
  },
  completedItem: {
    display: "flex", 
    justifyContent: "space-between", 
    alignItems: "center", 
    background: "linear-gradient(135deg, #f0fdf4 0%, #dcfce7 100%)",
    border: "2px solid #bbf7d0",
    borderLeft: "5px solid #22c55e",
    borderRadius: "14px", 
    padding: "18px 20px", 
    marginBottom: "12px",
    opacity: 0.9,
    transition: "all 0.3s ease",
    boxShadow: "0 2px 8px rgba(34, 197, 94, 0.1)",
    gap: "15px"
  },
  listText: { 
    fontWeight: "600",
    display: "flex",
    alignItems: "center",
    gap: "12px",
    marginBottom: "6px",
    fontSize: "16px",
    color: "#1e293b",
    flexWrap: "wrap"
  },
  listSub: { 
    fontSize: "14px", 
    color: "#64748b",
    lineHeight: "1.5"
  },
  deleteBtn: { 
    color: "#dc2626", 
    fontWeight: "600", 
    cursor: "pointer", 
    border: "none", 
    background: "transparent",
    padding: "10px 16px",
    borderRadius: "8px",
    border: "2px solid #fecaca",
    backgroundColor: "#fef2f2",
    transition: "all 0.3s ease",
    fontSize: "14px",
    whiteSpace: "nowrap"
  },
  deleteBtnHover: {
    backgroundColor: "#dc2626",
    color: "white",
    transform: "scale(1.05)"
  },
  loading: { 
    textAlign: "center", 
    padding: "40px",
    fontSize: "18px",
    color: "#64748b",
    fontWeight: "500"
  },
  completionButton: {
    background: "transparent",
    border: "3px solid #d1d5db",
    borderRadius: "50%",
    width: "32px",
    height: "32px",
    cursor: "pointer",
    display: "flex",
    alignItems: "center",
    justifyContent: "center",
    fontSize: "16px",
    fontWeight: "bold",
    transition: "all 0.3s ease",
    color: "transparent",
    flexShrink: 0
  },
  completionButtonHover: {
    borderColor: "#3b82f6",
    backgroundColor: "#3b82f6",
    color: "white",
    transform: "scale(1.1)"
  },
  completedButton: {
    background: "linear-gradient(135deg, #22c55e, #16a34a)",
    color: "white",
    border: "3px solid #22c55e",
    borderRadius: "50%",
    width: "32px",
    height: "32px",
    cursor: "pointer",
    display: "flex",
    alignItems: "center",
    justifyContent: "center",
    fontSize: "16px",
    fontWeight: "bold",
    transition: "all 0.3s ease",
    boxShadow: "0 4px 12px rgba(34, 197, 94, 0.3)",
    flexShrink: 0
  },
  medicationInfo: {
    flex: 1,
    display: "flex",
    alignItems: "flex-start",
    gap: "15px",
    minWidth: 0
  },
  medicationContent: {
    flex: 1,
    minWidth: 0
  },
  actions: {
    display: "flex",
    alignItems: "center",
    gap: "12px",
    flexShrink: 0
  },
  statusBadge: {
    fontSize: "12px",
    padding: "6px 12px",
    borderRadius: "20px",
    fontWeight: "600",
    textTransform: "uppercase",
    letterSpacing: "0.5px",
    whiteSpace: "nowrap"
  },
  pendingBadge: {
    background: "linear-gradient(135deg, #fef3c7, #f59e0b)",
    color: "#92400e",
    border: "1px solid #fbbf24"
  },
  completedBadge: {
    background: "linear-gradient(135deg, #d1fae5, #10b981)",
    color: "#065f46",
    border: "1px solid #34d399"
  },
  filterContainer: {
    display: "flex",
    gap: "12px",
    marginBottom: "20px",
    flexWrap: "wrap"
  },
  filterButton: {
    padding: "10px 20px",
    border: "none",
    borderRadius: "25px",
    cursor: "pointer",
    fontWeight: "600",
    fontSize: "14px",
    transition: "all 0.3s ease",
    boxShadow: "0 2px 8px rgba(0,0,0,0.1)",
    whiteSpace: "nowrap"
  },
  progressBar: {
    width: "100%",
    height: "12px",
    backgroundColor: "#e2e8f0",
    borderRadius: "10px",
    margin: "15px 0 25px 0",
    overflow: "hidden",
    boxShadow: "inset 0 2px 4px rgba(0,0,0,0.1)"
  },
  progressFill: {
    height: "100%",
    background: "linear-gradient(90deg, #10b981, #22c55e)",
    borderRadius: "10px",
    transition: "width 0.5s ease",
    boxShadow: "0 2px 8px rgba(16, 185, 129, 0.3)"
  },
  notesInput: {
    width: "100%",
    padding: "12px",
    borderRadius: "8px",
    border: "2px solid #e5e7eb",
    fontSize: "14px",
    marginTop: "10px",
    fontFamily: "inherit",
    resize: "vertical",
    minHeight: "80px",
    transition: "all 0.3s ease",
    backgroundColor: "#fafafa",
    boxSizing: "border-box"
  },
  notesInputFocus: {
    borderColor: "#3b82f6",
    backgroundColor: "white",
    boxShadow: "0 0 0 3px rgba(59, 130, 246, 0.1)"
  },
  notesButton: {
    background: "linear-gradient(135deg, #6b7280, #4b5563)",
    color: "white",
    border: "none",
    borderRadius: "8px",
    padding: "8px 16px",
    fontSize: "13px",
    cursor: "pointer",
    marginTop: "8px",
    fontWeight: "500",
    transition: "all 0.3s ease",
    whiteSpace: "nowrap"
  },
  notesButtonHover: {
    transform: "translateY(-1px)",
    boxShadow: "0 4px 12px rgba(107, 114, 128, 0.3)"
  },
  formRow: {
    display: 'flex',
    gap: '15px',
    flexWrap: 'wrap'
  },
  formColumn: {
    flex: 1,
    minWidth: '200px'
  },
  statsContainer: {
    display: 'flex',
    alignItems: 'center',
    gap: '15px',
    flexWrap: 'wrap'
  },
  statsText: {
    fontSize: '14px',
    color: '#64748b',
    fontWeight: '500',
    background: '#f8fafc',
    padding: '8px 16px',
    borderRadius: '20px',
    border: '1px solid #e2e8f0',
    whiteSpace: 'nowrap'
  },
  notesActions: {
    display: 'flex',
    gap: '8px',
    marginTop: '8px',
    flexWrap: 'wrap'
  }
};

const CreateMedicationReminder = () => {
  const [currentUser, setCurrentUser] = useState(null);
  const [elderlyList, setElderlyList] = useState([]);
  const [elderlyId, setElderlyId] = useState("");
  const [encodedElderlyId, setEncodedElderlyId] = useState("");
  const [medicationName, setMedicationName] = useState("");
  const [reminderTime, setReminderTime] = useState("");
  const [date, setDate] = useState(new Date().toISOString().split('T')[0]);
  const [repeatCount, setRepeatCount] = useState(1);
  const [dosage, setDosage] = useState("");
  const [quantity, setQuantity] = useState(1);
  const [error, setError] = useState("");
  const [success, setSuccess] = useState("");
  const [reminders, setReminders] = useState([]);
  const [loading, setLoading] = useState(true);
  const [filter, setFilter] = useState('all');
  const [showNotes, setShowNotes] = useState(null);
  const [notes, setNotes] = useState("");
  const [hoverStates, setHoverStates] = useState({
    button: false,
    deleteButtons: {},
    completionButtons: {},
    listItems: {},
    notesButtons: false,
    cancelNotes: false
  });

  // Handle hover states
  const handleHover = (element, isHovering) => {
    setHoverStates(prev => ({
      ...prev,
      [element]: isHovering
    }));
  };

  const handleElementHover = (element, id, isHovering) => {
    setHoverStates(prev => ({
      ...prev,
      [element]: {
        ...prev[element],
        [id]: isHovering
      }
    }));
  };

  // Get current user from localStorage
  useEffect(() => {
    const loggedInEmail = localStorage.getItem("loggedInEmail");
    const userType = localStorage.getItem("userType");
    
    if (loggedInEmail && userType) {
      setCurrentUser({
        email: loggedInEmail,
        userType: userType
      });
    } else {
      setLoading(false);
    }
  }, []);

  // Fetch linked elderly for caregiver or set self for elderly - UPDATED
  useEffect(() => {
    const fetchElderly = async () => {
      if (!currentUser) {
        setLoading(false);
        return;
      }

      try {
        const linkedElderlyEmails = await getLinkedElderlyId(currentUser);
        
        if (linkedElderlyEmails && linkedElderlyEmails.length > 0) {
          // Get detailed info for all elderly
          const elderlyInfo = await getMultipleElderlyInfo(linkedElderlyEmails);
          setElderlyList(elderlyInfo);
          
          // Set the first elderly as default
          if (elderlyInfo.length > 0) {
            setElderlyId(elderlyInfo[0].email);
            setEncodedElderlyId(encodeEmailForFirebase(elderlyInfo[0].email));
          }
        } else {
          console.warn("No elderly linked to account");
        }
      } catch (err) {
        console.error("Error fetching elderly info:", err);
      } finally {
        setLoading(false);
      }
    };
    
    if (currentUser) {
      fetchElderly();
    }
  }, [currentUser]);

  // Update encodedElderlyId when elderlyId changes
  useEffect(() => {
    if (elderlyId) {
      setEncodedElderlyId(encodeEmailForFirebase(elderlyId));
    }
  }, [elderlyId]);

  // Subscribe to reminders whenever encodedElderlyId changes
  useEffect(() => {
    if (!encodedElderlyId) return;
    const unsubscribe = subscribeToMedicationReminders(encodedElderlyId, setReminders);
    return () => unsubscribe && unsubscribe();
  }, [encodedElderlyId]);

  const handleSubmit = async (e) => {
    e.preventDefault();
    setError(""); 
    setSuccess("");

    if (!elderlyId) { 
      setError("No elderly selected"); 
      return; 
    }
    if (!medicationName || !reminderTime || !date) { 
      setError("Please fill in all fields"); 
      return; 
    }

    try {
      await createMedicationReminder(encodedElderlyId, {
        medicationName,
        reminderTime,
        date,
        repeatCount: parseInt(repeatCount, 10),
        dosage,
        quantity: parseInt(quantity, 10),
      });
      setSuccess("Medication reminder created successfully!");
      setMedicationName(""); 
      setReminderTime(""); 
      setDate(new Date().toISOString().split('T')[0]);
      setRepeatCount(1);
      setDosage("");
      setQuantity(1);
    } catch (err) {
      setError(err.message);
    }
  };

  const handleDelete = async (reminderId) => {
    if (window.confirm("Are you sure you want to delete this medication reminder?")) {
      await deleteMedicationReminder(encodedElderlyId, reminderId);
    }
  };

  const handleToggleCompletion = async (reminderId, currentStatus) => {
    try {
      if (!currentStatus) {
        if (showNotes === reminderId && notes.trim()) {
          await toggleMedicationCompletion(encodedElderlyId, reminderId, true, notes.trim());
          setShowNotes(null);
          setNotes("");
        } else if (showNotes !== reminderId) {
          setShowNotes(reminderId);
          return;
        } else {
          await toggleMedicationCompletion(encodedElderlyId, reminderId, true, "");
          setShowNotes(null);
          setNotes("");
        }
      } else {
        await toggleMedicationCompletion(encodedElderlyId, reminderId, false);
      }
    } catch (err) {
      setError("Failed to update medication status: " + err.message);
    }
  };

  const handleAddNotes = async (reminderId) => {
    if (notes.trim()) {
      await toggleMedicationCompletion(encodedElderlyId, reminderId, true, notes.trim());
      setShowNotes(null);
      setNotes("");
    }
  };

  const cancelNotes = () => {
    setShowNotes(null);
    setNotes("");
  };

  // Filter reminders based on selection
  const filteredReminders = reminders.filter(rem => {
    if (filter === 'pending') return !rem.isCompleted;
    if (filter === 'completed') return rem.isCompleted;
    return true;
  });

  // Calculate completion statistics
  const completedCount = reminders.filter(r => r.isCompleted).length;
  const totalCount = reminders.length;
  const completionPercentage = totalCount > 0 ? (completedCount / totalCount) * 100 : 0;

  // Show loading state while currentUser is being fetched
  if (loading) {
    return <div style={styles.loading}>Loading...</div>;
  }

  // Show message if no user is logged in
  if (!currentUser) {
    return <div style={styles.container}>Please log in to access this feature.</div>;
  }

  return (
    <div style={{marginTop: '60px'}}>
      <div style={styles.container}>
        <h2 style={styles.heading}>Create Medication Reminder</h2>
        <form onSubmit={handleSubmit} style={styles.form}>
          <div>
            <label style={styles.label}>Select Elderly</label>
            <select
              value={elderlyId}
              onChange={(e) => setElderlyId(e.target.value)}
              style={{
                ...styles.select,
                ...(hoverStates.select ? styles.selectFocus : {})
              }}
              onFocus={() => handleHover('select', true)}
              onBlur={() => handleHover('select', false)}
              disabled={currentUser.userType === "elderly"}
            >
              {elderlyList.length === 0 ? (
                <option value="">No elderly available</option>
              ) : (
                elderlyList.map((elderly) => (
                  <option key={elderly.email} value={elderly.email}>
                    {elderly.firstname} {elderly.lastname} 
                  </option>
                ))
              )}
            </select>
          </div>

          <div>
            <label style={styles.label}>Medication Name *</label>
            <input
              type="text"
              value={medicationName}
              onChange={(e) => setMedicationName(e.target.value)}
              style={{
                ...styles.input,
                ...(hoverStates.medicationInput ? styles.inputFocus : {})
              }}
              onFocus={() => handleHover('medicationInput', true)}
              onBlur={() => handleHover('medicationInput', false)}
              placeholder="Enter medication name"
              required
            />
          </div>

          <div style={styles.formRow}>
            <div style={styles.formColumn}>
              <label style={styles.label}>Dosage</label>
              <input
                type="text"
                value={dosage}
                onChange={(e) => setDosage(e.target.value)}
                style={{
                  ...styles.input,
                  ...(hoverStates.dosageInput ? styles.inputFocus : {})
                }}
                onFocus={() => handleHover('dosageInput', true)}
                onBlur={() => handleHover('dosageInput', false)}
                placeholder="e.g., 500mg, 1 tablet"
              />
            </div>
            <div style={styles.formColumn}>
              <label style={styles.label}>Quantity</label>
              <input
                type="number"
                min="1"
                value={quantity}
                onChange={(e) => setQuantity(e.target.value)}
                style={{
                  ...styles.input,
                  ...(hoverStates.quantityInput ? styles.inputFocus : {})
                }}
                onFocus={() => handleHover('quantityInput', true)}
                onBlur={() => handleHover('quantityInput', false)}
              />
            </div>
          </div>

          <div style={styles.formRow}>
            <div style={styles.formColumn}>
              <label style={styles.label}>Date *</label>
              <input
                type="date"
                value={date}
                onChange={(e) => setDate(e.target.value)}
                style={{
                  ...styles.input,
                  ...(hoverStates.dateInput ? styles.inputFocus : {})
                }}
                onFocus={() => handleHover('dateInput', true)}
                onBlur={() => handleHover('dateInput', false)}
                required
              />
            </div>
            <div style={styles.formColumn}>
              <label style={styles.label}>Reminder Time *</label>
              <input
                type="time"
                value={reminderTime}
                onChange={(e) => setReminderTime(e.target.value)}
                style={{
                  ...styles.input,
                  ...(hoverStates.timeInput ? styles.inputFocus : {})
                }}
                onFocus={() => handleHover('timeInput', true)}
                onBlur={() => handleHover('timeInput', false)}
                required
              />
            </div>
          </div>

          <div>
            <label style={styles.label}>Repeat Count *</label>
            <input
              type="number"
              min="1"
              value={repeatCount}
              onChange={(e) => setRepeatCount(e.target.value)}
              style={{
                ...styles.input,
                ...(hoverStates.repeatInput ? styles.inputFocus : {})
              }}
              onFocus={() => handleHover('repeatInput', true)}
              onBlur={() => handleHover('repeatInput', false)}
              required
            />
          </div>

          {error && <p style={styles.messageError}>{error}</p>}
          {success && <p style={styles.messageSuccess}>{success}</p>}

          <button 
            type="submit" 
            style={{
              ...styles.button,
              ...(hoverStates.button ? styles.buttonHover : {})
            }}
            onMouseEnter={() => handleHover('button', true)}
            onMouseLeave={() => handleHover('button', false)}
          >
            Create Reminder
          </button>
        </form>

        <div style={styles.listContainer}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '15px', gap: '15px', flexWrap: 'wrap' }}>
            <h2 style={styles.listHeading}>Medication Reminders</h2>
            {reminders.length > 0 && (
              <div style={styles.statsContainer}>
                <span style={styles.statsText}>
                  {completedCount} of {totalCount} completed
                </span>
                <span style={styles.statsText}>
                  {Math.round(completionPercentage)}% Complete
                </span>
              </div>
            )}
          </div>

          {reminders.length > 0 && (
            <>
              <div style={styles.progressBar}>
                <div 
                  style={{
                    ...styles.progressFill,
                    width: `${completionPercentage}%`
                  }} 
                />
              </div>
              
              <div style={styles.filterContainer}>
                <button
                  onClick={() => setFilter('all')}
                  style={{
                    ...styles.filterButton,
                    background: filter === 'all' ? '#2563eb' : '#f1f5f9',
                    color: filter === 'all' ? 'white' : '#64748b',
                  }}
                >
                  All ({totalCount})
                </button>
                <button
                  onClick={() => setFilter('pending')}
                  style={{
                    ...styles.filterButton,
                    background: filter === 'pending' ? '#f59e0b' : '#f1f5f9',
                    color: filter === 'pending' ? 'white' : '#64748b',
                  }}
                >
                  Pending ({totalCount - completedCount})
                </button>
                <button
                  onClick={() => setFilter('completed')}
                  style={{
                    ...styles.filterButton,
                    background: filter === 'completed' ? '#10b981' : '#f1f5f9',
                    color: filter === 'completed' ? 'white' : '#64748b',
                  }}
                >
                  Completed ({completedCount})
                </button>
              </div>
            </>
          )}

          {filteredReminders.length === 0 ? (
            <p style={{ color: "#777", textAlign: 'center', padding: '40px', fontSize: '16px' }}>
              {reminders.length === 0 ? 'No medication reminders found' : `No ${filter} reminders`}
            </p>
          ) : (
            <ul style={{ listStyle: "none", padding: 0, margin: 0 }}>
              {filteredReminders.map((rem) => (
                <li 
                  key={rem.id} 
                  style={{
                    ...(rem.isCompleted ? styles.completedItem : styles.listItem),
                    ...(hoverStates.listItems[rem.id] ? styles.listItemHover : {})
                  }}
                  onMouseEnter={() => handleElementHover('listItems', rem.id, true)}
                  onMouseLeave={() => handleElementHover('listItems', rem.id, false)}
                >
                  <div style={styles.medicationInfo}>
                    <button
                      onClick={() => handleToggleCompletion(rem.id, rem.isCompleted)}
                      style={{
                        ...(rem.isCompleted ? styles.completedButton : styles.completionButton),
                        ...(hoverStates.completionButtons[rem.id] ? styles.completionButtonHover : {})
                      }}
                      onMouseEnter={() => handleElementHover('completionButtons', rem.id, true)}
                      onMouseLeave={() => handleElementHover('completionButtons', rem.id, false)}
                      title={rem.isCompleted ? "Mark as not taken" : "Mark as taken"}
                    >
                      {rem.isCompleted ? "✓" : ""}
                    </button>
                    <div style={styles.medicationContent}>
                      <div style={styles.listText}>
                        {rem.medicationName}
                        <span style={{
                          ...styles.statusBadge,
                          ...(rem.isCompleted ? styles.completedBadge : styles.pendingBadge)
                        }}>
                          {rem.isCompleted ? "Taken" : "Pending"}
                        </span>
                      </div>
                      <div style={styles.listSub}>
                        <strong>Time:</strong> {rem.date} at {rem.reminderTime} | 
                        <strong> Repeat:</strong> {rem.repeatCount} time{rem.repeatCount > 1 ? 's' : ''}
                        {rem.dosage && ` | Dosage: ${rem.dosage}`}
                        {rem.quantity > 1 && ` | Qty: ${rem.quantity}`}
                      </div>
                      
                      {rem.isCompleted && rem.completedAt && (
                        <div style={styles.listSub}>
                          <strong>Taken at:</strong> {new Date(rem.completedAt).toLocaleTimeString([], {hour: '2-digit', minute:'2-digit'})}
                          {rem.notes && ` | Notes: ${rem.notes}`}
                        </div>
                      )}

                      {showNotes === rem.id && (
                        <div>
                          <textarea
                            value={notes}
                            onChange={(e) => setNotes(e.target.value)}
                            placeholder="Add notes about medication intake (optional)"
                            style={{
                              ...styles.notesInput,
                              ...(hoverStates.notesInput ? styles.notesInputFocus : {})
                            }}
                            onFocus={() => handleHover('notesInput', true)}
                            onBlur={() => handleHover('notesInput', false)}
                            rows="2"
                          />
                          <div style={styles.notesActions}>
                            <button 
                              onClick={() => handleAddNotes(rem.id)}
                              style={{
                                ...styles.notesButton,
                                ...(hoverStates.notesButtons ? styles.notesButtonHover : {})
                              }}
                              onMouseEnter={() => handleHover('notesButtons', true)}
                              onMouseLeave={() => handleHover('notesButtons', false)}
                            >
                              Save with Notes
                            </button>
                            <button 
                              onClick={cancelNotes}
                              style={{ 
                                ...styles.notesButton, 
                                background: 'linear-gradient(135deg, #dc2626, #b91c1c)',
                                ...(hoverStates.cancelNotes ? styles.notesButtonHover : {})
                              }}
                              onMouseEnter={() => handleHover('cancelNotes', true)}
                              onMouseLeave={() => handleHover('cancelNotes', false)}
                            >
                              Cancel
                            </button>
                          </div>
                        </div>
                      )}
                    </div>
                  </div>
                  <div style={styles.actions}>
                    <button 
                      onClick={() => handleDelete(rem.id)} 
                      style={{
                        ...styles.deleteBtn,
                        ...(hoverStates.deleteButtons[rem.id] ? styles.deleteBtnHover : {})
                      }}
                      onMouseEnter={() => handleElementHover('deleteButtons', rem.id, true)}
                      onMouseLeave={() => handleElementHover('deleteButtons', rem.id, false)}
                    >
                      Delete
                    </button>
                  </div>
                </li>
              ))}
            </ul>
          )}
        </div>
      </div>
      <br /><br /><br /><br /><br />
      <Footer />
    </div>
  );
};

export default CreateMedicationReminder;