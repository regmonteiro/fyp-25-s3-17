import React, { useState, useEffect } from "react";
import { 
  createAppointmentReminder,
  updateAppointmentInfo,
  deleteAppointmentReminder,
  toggleAppointmentCompletion,
  subscribeToAppointments,
  getLinkedElderlyId,
  getElderlyInfo,
  getMultipleElderlyInfo
} from "../controller/appointmentController";
import "./AppointmentReminder.css";

const AppointmentReminder = ({ currentUser }) => {
  const [elderlyList, setElderlyList] = useState([]); // Array of elderly objects
  const [selectedElderlyId, setSelectedElderlyId] = useState(""); // Currently selected elderly identifier
  const [appointments, setAppointments] = useState([]);
  const [title, setTitle] = useState("");
  const [location, setLocation] = useState("");
  const [date, setDate] = useState("");
  const [time, setTime] = useState("");
  const [notes, setNotes] = useState("");
  const [assignedTo, setAssignedTo] = useState("");
  const [error, setError] = useState("");
  const [success, setSuccess] = useState("");
  const [editId, setEditId] = useState(null);
  const [isFormOpen, setIsFormOpen] = useState(false);
  const [deleteConfirm, setDeleteConfirm] = useState(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const loadElderlyData = async () => {
      setLoading(true);
      setError("");
      try {
        // Get array of elderly identifiers (emails or UIDs)
        const elderlyIdentifiers = await getLinkedElderlyId(currentUser);
        
        if (elderlyIdentifiers && elderlyIdentifiers.length > 0) {
          // Get detailed info for all elderly
          const elderlyInfo = await getMultipleElderlyInfo(elderlyIdentifiers);
          setElderlyList(elderlyInfo);
          
          // Set the first elderly as default selection
          if (elderlyInfo.length > 0) {
            const firstElderly = elderlyInfo[0];
            setSelectedElderlyId(firstElderly.identifier || firstElderly.email || firstElderly.uid);
            setAssignedTo(firstElderly.identifier || firstElderly.email || firstElderly.uid);
          }
        } else {
          throw new Error("No elderly linked to this account");
        }
      } catch (err) {
        setError(err.message);
      } finally {
        setLoading(false);
      }
    };
    loadElderlyData();
  }, [currentUser]);

  // Subscribe to appointments when selected elderly changes
  useEffect(() => {
    if (!selectedElderlyId) return;
    
    const unsubscribe = subscribeToAppointments(selectedElderlyId, (appts) => {
      const sorted = appts.sort((a, b) => new Date(`${a.date}T${a.time}`) - new Date(`${b.date}T${b.time}`));
      setAppointments(sorted);
    });
    return () => unsubscribe();
  }, [selectedElderlyId]);

  const resetForm = () => {
    setTitle(""); 
    setLocation(""); 
    setDate(""); 
    setTime(""); 
    setNotes("");
    setAssignedTo(selectedElderlyId); 
    setEditId(null); 
    setError(""); 
    setSuccess("");
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    setError(""); 
    setSuccess("");

    if (!title || !location || !date || !time) {
      setError("Please fill all required fields");
      return;
    }

    try {
      const data = { 
        title, 
        location, 
        date, 
        time, 
        notes, 
        assignedTo: assignedTo || selectedElderlyId,
        elderlyId: selectedElderlyId // Always use the currently selected elderly identifier
      };
      
      if (editId) {
        await updateAppointmentInfo(editId, data);
      } else {
        await createAppointmentReminder(selectedElderlyId, data);
      }

      setSuccess(editId ? "Appointment updated successfully!" : "Appointment created successfully!");
      resetForm();
      setIsFormOpen(false);
    } catch (err) {
      setError(err.message);
    }
  };

  const handleEdit = (appt) => {
    setEditId(appt.id);
    setTitle(appt.title || "");
    setLocation(appt.location || "");
    setDate(appt.date || "");
    setTime(appt.time || "");
    setNotes(appt.notes || "");
    setAssignedTo(appt.assignedTo || selectedElderlyId);
    setIsFormOpen(true); 
    setError(""); 
    setSuccess("");
  };

  const handleDelete = async (id) => {
    try {
      await deleteAppointmentReminder(id);
      setSuccess("Appointment deleted successfully!"); 
      setDeleteConfirm(null);
    } catch (err) {
      setError(err.message);
    }
  };

  const cancelEdit = () => { 
    resetForm(); 
    setIsFormOpen(false); 
  };

  const formatDate = (dateString) => new Date(dateString).toLocaleDateString(undefined, { 
    year: "numeric", 
    month: "long", 
    day: "numeric" 
  });

  // Get display name for elderly
  const getElderlyDisplayName = (elderlyIdentifier) => {
    const elderly = elderlyList.find(e => 
      e.identifier === elderlyIdentifier || 
      e.email === elderlyIdentifier ||
      e.uid === elderlyIdentifier
    );
    return elderly ? `${elderly.firstname} ${elderly.lastname}` : elderlyIdentifier;
  };

  // Get the identifier for display (email or UID)
  const getElderlyIdentifier = (elderly) => {
    return elderly.identifier || elderly.email || elderly.uid;
  };

  // Get the display identifier (shorter version for UI)
  const getDisplayIdentifier = (elderlyIdentifier) => {
    if (elderlyIdentifier.includes('@')) {
      return elderlyIdentifier; // Show full email
    } else {
      return `${elderlyIdentifier.substring(0, 8)}...`; // Shorten UID for display
    }
  };

  if (loading) return <div className="appointment-reminder-container loading">Loading appointments...</div>;

  return (
    <div className="appointment-reminder-container">
      <div className="appointment-header">
        <h2>Appointment Reminders</h2>
        {elderlyList.length > 0 && (
          <button className="btn-primary" onClick={() => { resetForm(); setIsFormOpen(true); }}>
            Create Appointment
          </button>
        )}
      </div>

      {error && <div className="alert alert-error">{error}</div>}
      {success && <div className="alert alert-success">{success}</div>}

      {/* Elderly Selection for Caregivers */}
      {elderlyList.length > 1 && (
        <div className="elderly-selection">
          <label htmlFor="elderly-select">Select Elderly: </label>
          <select
            id="elderly-select"
            value={selectedElderlyId}
            onChange={(e) => {
              setSelectedElderlyId(e.target.value);
              setAssignedTo(e.target.value);
            }}
            className="elderly-select"
          >
            {elderlyList.map((elderly) => {
              const identifier = getElderlyIdentifier(elderly);
              return (
                <option key={identifier} value={identifier}>
                  {elderly.firstname} {elderly.lastname} 
                  
                </option>
              );
            })}
          </select>
        </div>
      )}

      {elderlyList.length === 0 && !loading && (
        <div className="no-elderly-card">
          <div className="no-elderly-content">
            <h3>No Elderly Linked</h3>
            <p>There is no elderly person linked to your account yet. Please link an elderly person to manage appointments.</p>
          </div>
        </div>
      )}

      {/* Appointment Form Modal */}
      {(isFormOpen || editId) && elderlyList.length > 0 && (
        <div className="modal-overlay">
          <div className="appointment-form-container">
            <div className="form-header">
              <h3>{editId ? "Edit Appointment" : "Create New Appointment"}</h3>
              <button className="close-btn" onClick={cancelEdit}>✕</button>
            </div>
            <form onSubmit={handleSubmit} className="appointment-form">
              <div className="input-group">
                <label htmlFor="title">Title *</label>
                <input
                  id="title"
                  type="text"
                  placeholder="Doctor visit, Family gathering, etc."
                  value={title}
                  onChange={(e) => setTitle(e.target.value)}
                  required
                />
              </div>

              <div className="input-group">
                <label htmlFor="location">Location *</label>
                <input
                  id="location"
                  type="text"
                  placeholder="123 Main St, Clinic, Hospital name..."
                  value={location}
                  onChange={(e) => setLocation(e.target.value)}
                  required
                />
              </div>

              <div className="form-row">
                <div className="input-group">
                  <label htmlFor="date">Date *</label>
                  <input
                    id="date"
                    type="date"
                    value={date}
                    onChange={(e) => setDate(e.target.value)}
                    required
                  />
                </div>

                <div className="input-group">
                  <label htmlFor="time">Time *</label>
                  <input
                    id="time"
                    type="time"
                    value={time}
                    onChange={(e) => setTime(e.target.value)}
                    required
                  />
                </div>
              </div>

              {/* Assign To Dropdown - Only show if multiple elderly */}
              {elderlyList.length > 1 && (
                <div className="input-group">
                  <label htmlFor="assignedTo">Assign To</label>
                  <select
                    id="assignedTo"
                    value={assignedTo}
                    onChange={(e) => setAssignedTo(e.target.value)}
                  >
                    {elderlyList.map((elderly) => {
                      const identifier = getElderlyIdentifier(elderly);
                      return (
                        <option key={identifier} value={identifier}>
                          {elderly.firstname} {elderly.lastname}
                          {elderly.uid && ` (${getDisplayIdentifier(identifier)})`}
                        </option>
                      );
                    })}
                  </select>
                </div>
              )}

              <div className="input-group">
                <label htmlFor="notes">Notes (optional)</label>
                <textarea
                  id="notes"
                  placeholder="Additional details..."
                  value={notes}
                  onChange={(e) => setNotes(e.target.value)}
                  rows="3"
                />
              </div>

              <div className="form-buttons">
                <button type="button" onClick={cancelEdit} className="btn-secondary">Cancel</button>
                <button type="submit" className="btn-primary">
                  {editId ? "Update Appointment" : "Create Appointment"}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Appointments List */}
      {elderlyList.length > 0 && appointments.length > 0 ? (
        <div className="appointments-section">
          <h3>
            Upcoming Appointments for {getElderlyDisplayName(selectedElderlyId)}
            {elderlyList.length > 1 && ` (${getDisplayIdentifier(selectedElderlyId)})`}
          </h3>
          <div className="appointments-grid">
            {appointments.map((appt) => (
              <div key={appt.id} className="appointment-card">
                <div className={`appointment-content ${appt.isCompleted ? "completed" : ""}`}>
                  {/* Checkbox top-right */}
                  <div className="checkbox-top-right">
                    <input 
                      type="checkbox"
                      aria-label={`Mark ${appt.title} as completed`}
                      style={{ width: '20px', height: '20px', accentColor: 'blue', cursor: 'pointer' }}
                      checked={!!appt.isCompleted} 
                      onChange={() => {
                        const now = new Date();
                        const apptDateTime = new Date(`${appt.date}T${appt.time}`);
                        if (isNaN(apptDateTime.getTime())) {
                          // If date/time is invalid, allow toggle
                          toggleAppointmentCompletion(appt.id, !appt.isCompleted);
                          return;
                        }
                        if (now < apptDateTime) {
                          alert("You cannot mark this appointment as completed before the scheduled time.");
                          return;
                        }
                        toggleAppointmentCompletion(appt.id, !appt.isCompleted);
                      }}
                    />
                  </div>

                  <h4>{appt.title}</h4>
                  
                  {/* Show assigned elderly if different from selected */}
                  {appt.assignedTo && appt.assignedTo !== selectedElderlyId && (
                    <div className="assigned-to">
                      👤 Assigned to: {getElderlyDisplayName(appt.assignedTo)}
                      {appt.assignedTo.includes('@') ? '' : ` (${getDisplayIdentifier(appt.assignedTo)})`}
                    </div>
                  )}
                  
                  <div className="appointment-details">
                    <div>📍 {appt.location}</div>
                    <div>📅 {formatDate(appt.date)}</div>
                    <div>⏰ {appt.time}</div>
                    {appt.notes && <div>📝 {appt.notes}</div>}
                  </div>
                </div>

                <div className="appointment-actions">
                  <button onClick={() => handleEdit(appt)} className="btn-secondary btn-sm">Update</button>
                  <button onClick={() => setDeleteConfirm(appt.id)} className="btn-danger btn-sm">Delete</button>
                </div>

                {deleteConfirm === appt.id && (
                  <div className="delete-confirmation">
                    <p>Are you sure you want to delete this appointment?</p>
                    <div className="confirmation-buttons">
                      <button onClick={() => setDeleteConfirm(null)} className="btn-secondary">Cancel</button>
                      <button onClick={() => handleDelete(appt.id)} className="btn-danger">Delete</button>
                    </div>
                  </div>
                )}
              </div>
            ))}
          </div>
        </div>
      ) : (
        elderlyList.length > 0 && (
          <div className="no-appointments">
            <div className="no-appointments-content">
              <span className="icon-large">📅</span>
              <h3>No Appointments Scheduled</h3>
              <p>Create your first appointment to get started!</p>
              <button className="btn-primary" onClick={() => { resetForm(); setIsFormOpen(true); }}>
                Create Appointment
              </button>
            </div>
          </div>
        )
      )}
    </div>
  );
};

export default AppointmentReminder;