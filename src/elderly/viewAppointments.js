import React, { useState, useEffect } from 'react';
import { 
  Calendar, Clock, User, ChevronLeft, 
  ChevronRight, Search, Plus, Edit, Trash2, Eye, X, MapPin,
  CheckCircle, Circle, Stethoscope
} from 'lucide-react';
import { 
  subscribeToAppointments, 
  getLinkedElderlyId,
  createAppointmentReminder,
  updateAppointmentInfo,
  deleteAppointmentReminder,
  toggleAppointmentCompletion
} from "../controller/appointmentController";
import "./viewAppointment.css";
import Footer from '../footer';
import FloatingAssistant from '../components/floatingassistantChat';

export default function ViewAppointments() {
  const [selectedDate, setSelectedDate] = useState(new Date());
  const [viewMode, setViewMode] = useState('calendar');
  const [searchTerm, setSearchTerm] = useState('');
  const [selectedAppointment, setSelectedAppointment] = useState(null);
  const [appointments, setAppointments] = useState([]);
  const [consultations, setConsultations] = useState([]);
  const [isLoading, setIsLoading] = useState(true);
  const [currentUser, setCurrentUser] = useState(null);
  const [error, setError] = useState(null);
  const [showAppointmentModal, setShowAppointmentModal] = useState(false);
  const [editingAppointment, setEditingAppointment] = useState(null);
  const [formData, setFormData] = useState({
    title: '',
    date: '',
    time: '',
    location: '',
    notes: '',
    isCompleted: false
  });

  // Helper function to truncate text for calendar display
  const truncateText = (text, maxLength) => {
    if (!text) return '';
    if (text.length <= maxLength) return text;
    return text.substring(0, maxLength) + '...';
  };

  // Initialize and fetch appointments and consultations
  useEffect(() => {
    let unsubscribeAppointments = () => {};
    let unsubscribeConsultations = () => {};
    
    const initializeData = async () => {
      try {
        setIsLoading(true);
        setError(null);
        
        const userEmail = localStorage.getItem("loggedInEmail");
        console.log("Current user email:", userEmail);
        setCurrentUser({ email: userEmail });
        
        const elderlyIds = await getLinkedElderlyId({ email: userEmail });
        console.log("Linked elderly IDs:", elderlyIds);
        
        // Use the first elderly ID for appointments (or handle multiple)
        const primaryElderlyId = elderlyIds[0];
        console.log("Using elderly ID for appointments:", primaryElderlyId);
        
        // Subscribe to appointments
        unsubscribeAppointments = subscribeToAppointments(primaryElderlyId, (appts) => {
          console.log("Received appointments from subscription:", appts);
          const normalizedAppts = appts.map(apt => ({
            id: apt.id || '',
            date: apt.date || new Date().toISOString().split('T')[0],
            time: apt.time || '12:00',
            title: apt.title || 'Untitled',
            notes: apt.notes || '',
            status: 'confirmed',
            elderlyId: apt.elderlyId || primaryElderlyId,
            location: apt.location || 'Not specified',
            isCompleted: apt.isCompleted || false,
            type: apt.type || 'general',
            consultationId: apt.consultationId || null
          }));
          console.log("Normalized appointments:", normalizedAppts);
          setAppointments(normalizedAppts);
        });

        // Subscribe to consultations from Firebase
        const { database } = require("../firebaseConfig");
        const { ref, onValue, off } = require("firebase/database");
        
        const consultationsRef = ref(database, 'consultations');
        unsubscribeConsultations = onValue(consultationsRef, (snapshot) => {
          const data = snapshot.val();
          console.log("Raw consultations data:", data);
          
          if (data) {
            const normalizedUserEmail = normalizeEmailForComparison(userEmail);
            const consultationsList = Object.entries(data)
              .map(([id, consultation]) => ({
                id,
                ...consultation,
              }))
              .filter(consultation => {
                const matches = [
                  consultation.elderlyEmail && normalizeEmailForComparison(consultation.elderlyEmail) === normalizedUserEmail,
                  consultation.elderlyId && normalizeEmailForComparison(consultation.elderlyId) === normalizedUserEmail,
                  consultation.patientUid === localStorage.getItem("uid"),
                  consultation.elderlyEmail && consultation.elderlyEmail.toLowerCase().includes(userEmail.toLowerCase()),
                  consultation.elderlyId && consultation.elderlyId.toLowerCase() === userEmail.toLowerCase()
                ];
                return matches.some(match => match === true);
              })
              .map(consultation => ({
                ...consultation,
                displayDate: consultation.appointmentDate || consultation.requestedAt,
                appointmentTime: consultation.appointmentDate ? getTimeFromDate(consultation.appointmentDate) : '12:00'
              }));
            
            console.log("Filtered consultations:", consultationsList);
            setConsultations(consultationsList);
          }
          setIsLoading(false);
        }, (error) => {
          console.error("Error loading consultations:", error);
          setIsLoading(false);
        });
        
      } catch (error) {
        console.error("Error initializing data:", error);
        setError(error.message);
        setIsLoading(false);
      }
    };

    initializeData();
    
    return () => {
      if (unsubscribeAppointments && typeof unsubscribeAppointments === 'function') {
        unsubscribeAppointments();
      }
      if (unsubscribeConsultations && typeof unsubscribeConsultations === 'function') {
        unsubscribeConsultations();
      }
    };
  }, []);

  // Helper function to normalize email for comparison
  const normalizeEmailForComparison = (email) => {
    if (!email) return '';
    return email.toLowerCase().trim().replace(/\./g, '');
  };

  // Helper function to extract time from ISO date string
  const getTimeFromDate = (dateString) => {
    if (!dateString) return '12:00';
    try {
      const date = new Date(dateString);
      return date.toTimeString().split(' ')[0].substring(0, 5);
    } catch (error) {
      console.error('Error parsing date:', error);
      return '12:00';
    }
  };

  // Helper function to get original email from normalized key
  const getOriginalEmail = (normalizedKey, caregiverData) => {
    if (caregiverData && caregiverData.originalEmail) {
      return caregiverData.originalEmail;
    }
    // Try to reverse the normalization
    return normalizedKey
      .replace(/_dot_/g, '.')
      .replace(/_hash_/g, '#')
      .replace(/_dollar_/g, '$')
      .replace(/_slash_/g, '/')
      .replace(/_lbracket_/g, '[')
      .replace(/_rbracket_/g, ']');
  };

  // Combine appointments and consultations for display
  const getAllAppointments = () => {
    const allAppointments = [...appointments];
    
    // Add consultations as appointments
    consultations.forEach(consultation => {
      const consultationDate = consultation.appointmentDate ? 
        new Date(consultation.appointmentDate).toISOString().split('T')[0] : 
        new Date(consultation.requestedAt).toISOString().split('T')[0];
      
      const consultationTime = consultation.appointmentTime || 
        getTimeFromDate(consultation.appointmentDate) || '12:00';
      
      // Extract caregiver information
      const invitedCaregivers = consultation.invitedCaregivers || {};
      const attendedCaregivers = consultation.attendedCaregivers || {};
      
      // Get caregiver information
      const caregiverList = Object.entries(invitedCaregivers).map(([normalizedKey, caregiverData]) => {
        const caregiverEmail = getOriginalEmail(normalizedKey, caregiverData) || caregiverData.caregiverEmail || 'Unknown';
        const caregiverStatus = caregiverData.status || 'invited';
        
        // Check if caregiver attended
        const attended = Object.entries(attendedCaregivers).some(([attendedKey, attendedData]) => {
          const attendedEmail = getOriginalEmail(attendedKey, attendedData) || attendedData.caregiverEmail;
          return attendedEmail === caregiverEmail;
        });
        
        return {
          email: caregiverEmail,
          name: caregiverEmail, // In a real app, you'd fetch the actual name from your database
          status: caregiverStatus,
          attended: attended
        };
      });
      
      // Check if this consultation already exists in appointments
      const existingAppointment = allAppointments.find(apt => 
        apt.consultationId === consultation.id
      );
      
      if (!existingAppointment) {
        allAppointments.push({
          id: `consultation-${consultation.id}`,
          consultationId: consultation.id,
          title: `GP Consultation: ${consultation.reason || 'Medical Consultation'}`,
          date: consultationDate,
          time: consultationTime,
          location: consultation.location || 'Virtual Consultation',
          notes: consultation.notes || '',
          status: consultation.status || 'scheduled',
          elderlyId: consultation.elderlyId,
          isCompleted: consultation.status === 'Completed',
          type: 'consultation',
          isConsultation: true,
          consultationData: consultation,
          caregivers: caregiverList,
          hasCaregivers: caregiverList.length > 0
        });
      }
    });
    
    return allAppointments.sort((a, b) => {
      const dateA = new Date(`${a.date}T${a.time}`);
      const dateB = new Date(`${b.date}T${b.time}`);
      return dateB - dateA;
    });
  };

  // ✅ Helper: Only allow marking as completed after appointment time
  const canMarkAsCompleted = (appointment) => {
    if (!appointment.date || !appointment.time) return false;
    const appointmentDateTime = new Date(`${appointment.date}T${appointment.time}`);
    const now = new Date();
    return now >= appointmentDateTime;
  };

  const formatDate = (date) => {
    return date.toLocaleDateString('en-US', { 
      weekday: 'long', 
      year: 'numeric', 
      month: 'long', 
      day: 'numeric' 
    });
  };

  const getDaysInMonth = (date) => {
    const year = date.getFullYear();
    const month = date.getMonth();
    const firstDay = new Date(year, month, 1);
    const lastDay = new Date(year, month + 1, 0);
    const daysInMonth = lastDay.getDate();
    const startingDayOfWeek = firstDay.getDay();

    const days = [];
    for (let i = 0; i < startingDayOfWeek; i++) days.push(null);
    for (let day = 1; day <= daysInMonth; day++) days.push(new Date(year, month, day));
    return days;
  };

  const navigateMonth = (direction) => {
    const newDate = new Date(selectedDate);
    newDate.setMonth(selectedDate.getMonth() + direction);
    setSelectedDate(newDate);
  };

  const getAppointmentsForDate = (date) => {
    const year = date.getFullYear();
    const month = String(date.getMonth() + 1).padStart(2, '0');
    const day = String(date.getDate()).padStart(2, '0');
    const dateStr = `${year}-${month}-${day}`;
    
    const allAppointments = getAllAppointments();
    
    return allAppointments.filter(apt => {
      if (!apt.date) return false;
      const aptDate = new Date(apt.date);
      const aptYear = aptDate.getFullYear();
      const aptMonth = String(aptDate.getMonth() + 1).padStart(2, '0');
      const aptDay = String(aptDate.getDate()).padStart(2, '0');
      const aptDateStr = `${aptYear}-${aptMonth}-${aptDay}`;
      return aptDateStr === dateStr;
    });
  };

  const getFilteredAppointments = () => {
    const allAppointments = getAllAppointments();
    if (!searchTerm) return allAppointments;
    return allAppointments.filter(apt => {
      const title = apt.title || '';
      return title.toLowerCase().includes(searchTerm.toLowerCase());
    });
  };

  const getStatusColor = (status) => {
    switch (status) {
      case 'confirmed': return 'appointment-status-confirmed';
      case 'scheduled': return 'appointment-status-confirmed';
      case 'pending': return 'appointment-status-pending';
      case 'cancelled': return 'appointment-status-cancelled';
      case 'Cancelled': return 'appointment-status-cancelled';
      case 'Completed': return 'appointment-status-completed';
      default: return 'appointment-status-pending';
    }
  };

  const openCreateAppointmentModal = () => {
    const today = new Date();
    const formattedDate = today.toISOString().split("T")[0];
    const formattedTime = '10:00';
    
    setFormData({
      title: '',
      date: formattedDate,
      time: formattedTime,
      location: '',
      notes: '',
      isCompleted: false
    });
    setEditingAppointment(null);
    setShowAppointmentModal(true);
  };

  const openEditAppointmentModal = (appointment) => {
    // Don't allow editing consultation-based appointments directly
    if (appointment.isConsultation) {
      alert('Consultation appointments cannot be edited here. Please use the Consultation page to modify consultations.');
      return;
    }

    const aptDate = new Date(appointment.date);
    const formattedDate = aptDate.toISOString().split("T")[0];
    
    setFormData({
      title: appointment.title || '',
      date: formattedDate,
      time: appointment.time || '10:00',
      location: appointment.location || '',
      notes: appointment.notes || '',
      isCompleted: appointment.isCompleted || false
    });
    setEditingAppointment(appointment);
    setShowAppointmentModal(true);
  };

  const closeAppointmentModal = () => {
    setShowAppointmentModal(false);
    setEditingAppointment(null);
  };

  const handleFormChange = (e) => {
    const { name, value, type, checked } = e.target;
    setFormData(prev => ({
      ...prev,
      [name]: type === 'checkbox' ? checked : value
    }));
  };

  const handleSaveAppointment = async () => {
    try {
      const elderlyIds = await getLinkedElderlyId(currentUser);
      const primaryElderlyId = elderlyIds[0];
      const formattedDate = new Date(formData.date).toISOString().split("T")[0];
      
      if (editingAppointment) {
        await updateAppointmentInfo(editingAppointment.id, {
          ...editingAppointment,
          title: formData.title,
          date: formattedDate,
          time: formData.time,
          location: formData.location,
          notes: formData.notes,
          isCompleted: formData.isCompleted,
          elderlyId: primaryElderlyId
        });
      } else {
        await createAppointmentReminder(primaryElderlyId, {
          title: formData.title,
          date: formattedDate,
          time: formData.time,
          location: formData.location,
          notes: formData.notes,
          isCompleted: formData.isCompleted,
          elderlyId: primaryElderlyId
        });
      }
      closeAppointmentModal();
    } catch (error) {
      console.error("Error saving appointment:", error);
      setError(error.message);
    }
  };

  const handleDeleteAppointment = async (appointmentId) => {
    try {
      // Don't allow deleting consultation-based appointments
      const appointmentToDelete = getAllAppointments().find(apt => apt.id === appointmentId);
      if (appointmentToDelete && appointmentToDelete.isConsultation) {
        alert('Consultation appointments cannot be deleted here. Please use the Consultation page to manage consultations.');
        return;
      }

      await deleteAppointmentReminder(appointmentId);
      setSelectedAppointment(null);
    } catch (error) {
      console.error("Error deleting appointment:", error);
      setError(error.message);
    }
  };

  // ✅ Toggle completion with restriction
  const handleToggleCompletion = async (appointmentId, currentStatus) => {
    try {
      const allAppointments = getAllAppointments();
      const appointment = allAppointments.find(apt => apt.id === appointmentId);
      if (!appointment) return;

      // Don't allow toggling completion for consultation-based appointments
      if (appointment.isConsultation) {
        alert('Consultation completion status is managed through the Consultation page.');
        return;
      }

      if (!canMarkAsCompleted(appointment)) {
        setError("You can only mark as completed after the appointment time.");
        return;
      }

      await toggleAppointmentCompletion(appointmentId, !currentStatus);

      // Update local state for regular appointments
      setAppointments(prev => prev.map(apt => 
        apt.id === appointmentId 
          ? { ...apt, isCompleted: !currentStatus }
          : apt
      ));

      if (selectedAppointment && selectedAppointment.id === appointmentId) {
        setSelectedAppointment(prev => ({
          ...prev,
          isCompleted: !currentStatus
        }));
      }
    } catch (error) {
      console.error("Error toggling completion status:", error);
      setError(error.message);
    }
  };

  const formatTime = (time) => {
    if (time && time.includes(':')) {
      const [hours, minutes] = time.split(':');
      const hourInt = parseInt(hours);
      const period = hourInt >= 12 ? 'PM' : 'AM';
      const hour12 = hourInt % 12 || 12;
      return `${hour12}:${minutes} ${period}`;
    }
    return time;
  };

  const days = getDaysInMonth(selectedDate);
  const filteredAppointments = getFilteredAppointments();

  if (isLoading) {
    return (
      <div className="appointments-container">
        <div className="appointments-main-card">
          <div className="appointments-loading">
            <p>Loading appointments and consultations...</p>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div>
      <div className="appointments-container">
        {error && (
          <div className="appointments-error-banner">
            Error: {error}
            <button onClick={() => setError(null)}>Dismiss</button>
          </div>
        )}
        
        {/* Appointment Modal */}
        {showAppointmentModal && (
          <div className="appointment-modal-overlay">
            <div className="appointment-modal">
              <div className="appointment-modal-header">
                <h2>{editingAppointment ? 'Edit Appointment' : 'Create New Appointment'}</h2>
                <button className="appointment-modal-close" onClick={closeAppointmentModal}>
                  <X size={20} />
                </button>
              </div>
              
              <div className="appointment-modal-content">
                <div className="appointment-form">
                  <div className="appointment-form-group">
                    <label htmlFor="title">Title</label>
                    <input
                      type="text"
                      id="title"
                      name="title"
                      value={formData.title}
                      onChange={handleFormChange}
                      placeholder="Appointment title"
                    />
                  </div>
                  
                  <div className="appointment-form-group">
                    <label htmlFor="date">Date</label>
                    <input
                      type="date"
                      id="date"
                      name="date"
                      value={formData.date}
                      onChange={handleFormChange}
                    />
                  </div>
                  
                  <div className="appointment-form-group">
                    <label htmlFor="time">Time</label>
                    <input
                      type="time"
                      id="time"
                      name="time"
                      value={formData.time}
                      onChange={handleFormChange}
                    />
                  </div>
                  
                  <div className="appointment-form-group">
                    <label htmlFor="location">Location</label>
                    <input
                      type="text"
                      id="location"
                      name="location"
                      value={formData.location}
                      onChange={handleFormChange}
                      placeholder="Appointment location"
                    />
                  </div>
                  
                  <div className="appointment-form-group">
                    <label htmlFor="notes">Notes</label>
                    <textarea
                      id="notes"
                      name="notes"
                      value={formData.notes}
                      onChange={handleFormChange}
                      placeholder="Additional notes"
                      rows="3"
                    />
                  </div>

                  {/* Completion Checkbox in Modal */}
                  {editingAppointment && (
                    <div className="appointment-form-group appointment-completion-checkbox">
                      <label className="checkbox-label">
                        <input
                          type="checkbox"
                          name="isCompleted"
                          checked={formData.isCompleted}
                          onChange={handleFormChange}
                        />
                        <span className="checkmark"></span>
                        Mark as completed
                      </label>
                    </div>
                  )}
                </div>
              </div>
              
              <div className="appointment-modal-actions">
                <button className="appointment-modal-cancel" onClick={closeAppointmentModal}>
                  Cancel
                </button>
                <button className="appointment-modal-save" onClick={handleSaveAppointment}>
                  {editingAppointment ? 'Update Appointment' : 'Create Appointment'}
                </button>
              </div>
            </div>
          </div>
        )}
        
        <div className="appointments-main-card">
          {/* Header */}
          <div className="appointments-header">
            <div className="appointments-header-content">
              <div>
                <h1 className="appointments-header-title">
                  <Calendar className="appointments-header-icon" />
                  View Appointments & Consultations
                </h1>
                <p className="appointments-header-subtitle">Manage appointments and GP consultations in one place</p>
              </div>
              <div className="appointments-header-actions">
                <button 
                  className="appointments-new-button"
                  onClick={openCreateAppointmentModal}
                >
                  <Plus className="appointments-button-icon" />
                  New Appointment
                </button>
              </div>
            </div>
          </div>

          {/* Controls */}
          <div className="appointments-controls">
            <div className="appointments-controls-content">
              <div className="appointments-view-toggle-container">
                <div className="appointments-view-toggle">
                  <button
                    onClick={() => setViewMode('calendar')}
                    className={`appointments-view-button ${viewMode === 'calendar' ? 'appointments-view-button-active' : ''}`}
                  >
                    Calendar View
                  </button>
                  <button
                    onClick={() => setViewMode('list')}
                    className={`appointments-view-button ${viewMode === 'list' ? 'appointments-view-button-active' : ''}`}
                  >
                    List View
                  </button>
                </div>
              </div>
              
              <div className="appointments-search-container">
                <div className="appointments-search-wrapper">
                  <Search className="appointments-search-icon" />
                  <input
                    type="text"
                    placeholder="Search appointments and consultations..."
                    value={searchTerm}
                    onChange={(e) => setSearchTerm(e.target.value)}
                    className="appointments-search-input"
                  />
                </div>
              </div>
            </div>
          </div>

          <div className="appointments-main-content">
            {/* Main Content */}
            <div className="appointments-content-area">
              {viewMode === 'calendar' ? (
                <div>
                  {/* Calendar Header */}
                  <div className="appointments-calendar-header">
                    <button 
                      onClick={() => navigateMonth(-1)}
                      className="appointments-calendar-nav-button"
                    >
                      <ChevronLeft className="appointments-calendar-nav-icon" />
                    </button>
                    <h2 className="appointments-calendar-month-title">
                      {selectedDate.toLocaleDateString('en-US', { month: 'long', year: 'numeric' })}
                    </h2>
                    <button 
                      onClick={() => navigateMonth(1)}
                      className="appointments-calendar-nav-button"
                    >
                      <ChevronRight className="appointments-calendar-nav-icon" />
                    </button>
                  </div>

                  {/* Calendar Grid */}
                  <div className="appointments-calendar-grid">
                    {['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'].map(day => (
                      <div key={day} className="appointments-calendar-day-header">
                        {day}
                      </div>
                    ))}
                    {days.map((date, index) => {
                      const dayAppointments = date ? getAppointmentsForDate(date) : [];
                      return (
                        <div key={index} className="appointments-calendar-day">
                          {date ? (
                            <div>
                              <div className="appointments-calendar-day-number">
                                {date.getDate()}
                              </div>
                              <div className="appointments-calendar-appointments-list">
                                {dayAppointments.map(apt => (
                                  <div 
                                    key={apt.id}
                                    onClick={() => setSelectedAppointment(apt)}
                                    className={`appointments-calendar-appointment-item ${apt.isCompleted ? 'appointment-completed' : ''} ${apt.isConsultation ? 'consultation-appointment' : ''}`}
                                  >
                                    <div className="appointments-calendar-appointment-header">
                                      {apt.isConsultation && (
                                        <Stethoscope className="consultation-icon" size={10} />
                                      )}
                                      <div 
                                        className={`appointment-completion-toggle ${!canMarkAsCompleted(apt) || apt.isConsultation ? 'disabled' : ''}`}
                                        onClick={(e) => {
                                          e.stopPropagation();
                                          if (canMarkAsCompleted(apt) && !apt.isConsultation) {
                                            handleToggleCompletion(apt.id, apt.isCompleted);
                                          }
                                        }}
                                      >
                                        {apt.isCompleted ? (
                                          <CheckCircle className="appointment-check-icon completed" size={10} />
                                        ) : (
                                          <Circle className="appointment-check-icon" size={10} />
                                        )}
                                      </div>
                                      <div className="appointments-calendar-appointment-time">
                                        {formatTime(apt.time)}
                                      </div>
                                    </div>
                                    <div className="appointments-calendar-appointment-name">
                                      {truncateText(apt.title, apt.isConsultation ? 18 : 22)}
                                    </div>
                                  </div>
                                ))}
                              </div>
                            </div>
                          ) : null}
                        </div>
                      );
                    })}
                  </div>
                </div>
              ) : (
                // List View
                <div className="appointments-list-container">
                  <h2 className="appointments-list-header">
                    All Appointments & Consultations ({filteredAppointments.length})
                  </h2>
                  {filteredAppointments.length === 0 ? (
                    <div className="appointments-empty-state">
                      <Calendar className="appointments-empty-icon" />
                      <h3 className="appointments-empty-title">No appointments found</h3>
                      <p className="appointments-empty-text">Try adjusting your search criteria</p>
                    </div>
                  ) : (
                    <div className="appointments-list">
                      {filteredAppointments.map(apt => (
                        <div key={apt.id} className={`appointments-list-card ${apt.isCompleted ? 'appointment-completed' : ''} ${apt.isConsultation ? 'consultation-card' : ''}`}>
                          <div className="appointments-list-card-content">
                            <div className="appointments-list-card-main">
                              <div className="appointments-list-card-header">
                                <div className="appointments-list-patient-info">
                                  {/* Consultation Icon */}
                                  {apt.isConsultation && (
                                    <Stethoscope className="consultation-icon" size={18} />
                                  )}
                                  {/* Completion Toggle in List */}
                                  <div 
                                    className={`appointment-completion-toggle ${!canMarkAsCompleted(apt) || apt.isConsultation ? 'disabled' : ''}`}
                                    onClick={() => {
                                      if (canMarkAsCompleted(apt) && !apt.isConsultation) {
                                        handleToggleCompletion(apt.id, apt.isCompleted);
                                      }
                                    }}
                                  >
                                    {apt.isCompleted ? (
                                      <CheckCircle className="appointment-check-icon completed" size={18} />
                                    ) : (
                                      <Circle className="appointment-check-icon" size={18} />
                                    )}
                                  </div>
                                  <User className="appointments-list-patient-icon" />
                                  <span className="appointments-list-patient-name">{apt.title}</span>
                                </div>
                                <div className="appointments-list-header-right">
                                  {apt.isConsultation && (
                                    <span className="appointments-consultation-badge">
                                      GP Consultation
                                    </span>
                                  )}
                                  <span className={`appointments-status-badge ${getStatusColor(apt.status)}`}>
                                    {apt.status?.charAt(0)?.toUpperCase() + apt.status?.slice(1) || 'Pending'}
                                  </span>
                                  {apt.isCompleted && (
                                    <span className="appointments-completed-badge">
                                      Completed
                                    </span>
                                  )}
                                </div>
                              </div>
                              
                              <div className="appointments-list-details-grid">
                                <div className="appointments-list-detail-item">
                                  <Calendar className="appointments-list-detail-icon" />
                                  <span>{new Date(apt.date).toLocaleDateString('en-US', { weekday: 'short', month: 'short', day: 'numeric' })}</span>
                                </div>
                                <div className="appointments-list-detail-item">
                                  <Clock className="appointments-list-detail-icon" />
                                  <span>{formatTime(apt.time)}</span>
                                </div>
                                <div className="appointments-list-detail-item">
                                  <MapPin className="appointments-list-detail-icon" />
                                  <span>{apt.location}</span>
                                </div>
                              </div>
                              
                              {apt.notes && (
                                <div className="appointments-list-notes-info">
                                  <span className="appointments-list-notes-label">Notes:</span> {apt.notes}
                                </div>
                              )}

                              {/* Consultation-specific information */}
                              {apt.isConsultation && apt.consultationData && (
                                <div className="appointments-consultation-info">
                                  <div className="appointments-consultation-reason">
                                    <strong>Reason:</strong> {apt.consultationData.reason || 'General consultation'}
                                  </div>
                                  {apt.hasCaregivers && (
                                    <div className="appointments-consultation-caregivers">
                                      <strong>Caregivers:</strong>
                                      <div className="caregivers-list">
                                        {apt.caregivers.map((caregiver, index) => (
                                          <span 
                                            key={index} 
                                            className={`caregiver-tag ${caregiver.attended ? 'attended' : ''} ${caregiver.status || 'invited'}`}
                                            title={caregiver.email}
                                          >
                                            {caregiver.name || caregiver.email}
                                            {caregiver.attended && <span className="attended-badge">✓</span>}
                                            <span className="caregiver-status">({caregiver.status || 'invited'})</span>
                                          </span>
                                        ))}
                                      </div>
                                    </div>
                                  )}
                                </div>
                              )}
                            </div>
                            
                            <div className="appointments-list-actions">
                              <button 
                                onClick={() => setSelectedAppointment(apt)}
                                className="appointments-list-action-button appointments-list-view-button"
                                title="View Details"
                              >
                                <Eye className="appointments-list-action-icon" />
                              </button>
                              {!apt.isConsultation && (
                                <>
                                  <button 
                                    onClick={() => openEditAppointmentModal(apt)}
                                    className="appointments-list-action-button appointments-list-edit-button"
                                    title="Edit"
                                  >
                                    <Edit className="appointments-list-action-icon" />
                                  </button>
                                  <button 
                                    onClick={() => handleDeleteAppointment(apt.id)}
                                    className="appointments-list-action-button appointments-list-delete-button"
                                    title="Cancel"
                                  >
                                    <Trash2 className="appointments-list-action-icon" />
                                  </button>
                                </>
                              )}
                            </div>
                          </div>
                        </div>
                      ))}
                    </div>
                  )}
                </div>
              )}
            </div>

            {/* Sidebar - Appointment Details */}
            {selectedAppointment && (
              <div className="appointments-sidebar">
                <div className="appointments-sidebar-content">
                  <div className="appointments-sidebar-header">
                    <h3 className="appointments-sidebar-title">
                      {selectedAppointment.isConsultation ? 'Consultation Details' : 'Appointment Details'}
                    </h3>
                    <button 
                      onClick={() => setSelectedAppointment(null)}
                      className="appointments-sidebar-close-button"
                    >
                      ✕
                    </button>
                  </div>
                  
                  <div className="appointments-detail-card">
                    <div className="appointments-detail-patient-info">
                      {/* Consultation Icon */}
                      {selectedAppointment.isConsultation && (
                        <Stethoscope className="consultation-icon" size={20} />
                      )}
                      {/* Completion Toggle in Sidebar */}
                      <div 
                        className={`appointment-completion-toggle ${!canMarkAsCompleted(selectedAppointment) || selectedAppointment.isConsultation ? 'disabled' : ''}`}
                        onClick={() => {
                          if (canMarkAsCompleted(selectedAppointment) && !selectedAppointment.isConsultation) {
                            handleToggleCompletion(selectedAppointment.id, selectedAppointment.isCompleted);
                          }
                        }}
                      >
                        {selectedAppointment.isCompleted ? (
                          <CheckCircle className="appointment-check-icon completed" size={20} />
                        ) : (
                          <Circle className="appointment-check-icon" size={20} />
                        )}
                      </div>
                      <User className="appointments-detail-patient-icon" />
                      <span className="appointments-detail-patient-name">{selectedAppointment.title}</span>
                    </div>
                    
                    <div className="appointments-detail-list">
                      <div className="appointments-detail-item">
                        <Calendar className="appointments-detail-icon" />
                        <span>{new Date(selectedAppointment.date).toLocaleDateString('en-US', { 
                          weekday: 'long', 
                          year: 'numeric', 
                          month: 'long', 
                          day: 'numeric' 
                        })}</span>
                      </div>
                      
                      <div className="appointments-detail-item">
                        <Clock className="appointments-detail-icon" />
                        <span>{formatTime(selectedAppointment.time)}</span>
                      </div>
                      
                      <div className="appointments-detail-item">
                        <MapPin className="appointments-detail-icon" />
                        <span>{selectedAppointment.location}</span>
                      </div>
                    </div>
                    
                    <div className="appointments-detail-section">
                      <div className="appointments-detail-field">
                        <span className="appointments-detail-label">Type:</span>
                        <div className="appointments-detail-value">
                          <span className={`appointments-type-badge ${selectedAppointment.isConsultation ? 'consultation-type' : 'appointment-type'}`}>
                            {selectedAppointment.isConsultation ? 'GP Consultation' : 'Appointment'}
                          </span>
                        </div>
                      </div>

                      <div className="appointments-detail-field">
                        <span className="appointments-detail-label">Status:</span>
                        <div className="appointments-detail-value">
                          <span className={`appointments-status-badge ${getStatusColor(selectedAppointment.status)}`}>
                            {selectedAppointment.status?.charAt(0)?.toUpperCase() + selectedAppointment.status?.slice(1) || 'Pending'}
                          </span>
                        </div>
                      </div>

                      {/* Completion Status in Sidebar */}
                      <div className="appointments-detail-field">
                        <span className="appointments-detail-label">Completion:</span>
                        <div className="appointments-detail-value">
                          <span className={`appointments-completion-badge ${selectedAppointment.isCompleted ? 'completed' : 'pending'}`}>
                            {selectedAppointment.isCompleted ? 'Completed' : 'Pending'}
                          </span>
                        </div>
                      </div>
                      
                      {/* Consultation-specific details */}
                      {selectedAppointment.isConsultation && selectedAppointment.consultationData && (
                        <>
                          <div className="appointments-detail-field">
                            <span className="appointments-detail-label">Reason:</span>
                            <div className="appointments-detail-value">
                              {selectedAppointment.consultationData.reason || 'General consultation'}
                            </div>
                          </div>
                          
                          {selectedAppointment.hasCaregivers && (
                            <div className="appointments-detail-field">
                              <span className="appointments-detail-label">Caregivers:</span>
                              <div className="appointments-detail-value">
                                <div className="caregivers-detail-list">
                                  {selectedAppointment.caregivers.map((caregiver, index) => (
                                    <div key={index} className="caregiver-detail-item">
                                      <div className="caregiver-email">{caregiver.email}</div>
                                      <div className="caregiver-status-badge">
                                        <span className={`status-dot ${caregiver.status || 'invited'}`}></span>
                                        {caregiver.status || 'invited'}
                                        {caregiver.attended && (
                                          <span className="attended-indicator"> • Attended</span>
                                        )}
                                      </div>
                                    </div>
                                  ))}
                                </div>
                              </div>
                            </div>
                          )}
                          
                          {selectedAppointment.consultationData.elderlyName && (
                            <div className="appointments-detail-field">
                              <span className="appointments-detail-label">Patient:</span>
                              <div className="appointments-detail-value">
                                {selectedAppointment.consultationData.elderlyName}
                              </div>
                            </div>
                          )}
                        </>
                      )}
                      
                      {selectedAppointment.notes && (
                        <div className="appointments-detail-field">
                          <span className="appointments-detail-label">Notes:</span>
                          <div className="appointments-detail-notes-box">
                            {selectedAppointment.notes}
                          </div>
                        </div>
                      )}
                    </div>
                    
                    <div className="appointments-sidebar-actions">
                      {!selectedAppointment.isConsultation ? (
                        <>
                          <button 
                            onClick={() => {
                              if (canMarkAsCompleted(selectedAppointment)) {
                                handleToggleCompletion(selectedAppointment.id, selectedAppointment.isCompleted);
                              }
                            }}
                            className={`appointments-sidebar-button ${selectedAppointment.isCompleted ? 'appointments-sidebar-secondary-button' : 'appointments-sidebar-primary-button'} ${!canMarkAsCompleted(selectedAppointment) ? 'disabled' : ''}`}
                            disabled={!canMarkAsCompleted(selectedAppointment)}
                          >
                            {selectedAppointment.isCompleted ? 'Mark as Pending' : 'Mark as Completed'}
                          </button>
                          <button 
                            onClick={() => openEditAppointmentModal(selectedAppointment)}
                            className="appointments-sidebar-button appointments-sidebar-outline-button"
                          >
                            Edit Appointment
                          </button>
                          <button 
                            onClick={() => handleDeleteAppointment(selectedAppointment.id)}
                            className="appointments-sidebar-button appointments-sidebar-danger-button"
                          >
                            Cancel Appointment
                          </button>
                        </>
                      ) : (
                        <div className="appointments-consultation-note">
                          <p>Consultation appointments are managed through the Consultation page.</p>
                        </div>
                      )}
                    </div>
                  </div>
                </div>
              </div>
            )}
          </div>
        </div>
      </div>


      {/* Floating AI Assistant */}
      {currentUser?.email && <FloatingAssistant userEmail={currentUser.email} />}

      <Footer />
    </div>
  );
}