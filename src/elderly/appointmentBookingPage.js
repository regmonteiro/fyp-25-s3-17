import React, { useState, useEffect } from 'react';
import { database } from "../firebaseConfig";
import { ref, set, push, onValue, off } from "firebase/database";
import './appointmentBooking.css';

const AppointmentBookingPage = () => {
  const [date, setDate] = useState('');
  const [time, setTime] = useState('');
  const [duration, setDuration] = useState(20);
  const [reason, setReason] = useState('');
  const [selectedReasons, setSelectedReasons] = useState(new Set());
  const [inviteCaregiver, setInviteCaregiver] = useState(false);
  const [submitting, setSubmitting] = useState(false);
  const [userName, setUserName] = useState('');
  const [uid, setUid] = useState('');

  const quickReasons = [
    'Fever / Flu-like',
    'Cough / Sore throat',
    'Headache / Dizziness',
    'Medication refill',
    'Skin rash / irritation',
    'Stomach pain',
    'Follow-up consultation',
  ];

  useEffect(() => {
    const storedName = localStorage.getItem("userName");
    const storedUid = localStorage.getItem("uid");
    
    if (storedName && storedUid) {
      setUserName(storedName);
      setUid(storedUid);
    }

    // Set default date to tomorrow
    const tomorrow = new Date();
    tomorrow.setDate(tomorrow.getDate() + 1);
    setDate(tomorrow.toISOString().split('T')[0]);
    
    // Set default time to 9:00 AM
    setTime('09:00');
  }, []);

  const handleReasonSelect = (reason) => {
    const newSelectedReasons = new Set(selectedReasons);
    if (newSelectedReasons.has(reason)) {
      newSelectedReasons.delete(reason);
    } else {
      newSelectedReasons.add(reason);
    }
    setSelectedReasons(newSelectedReasons);
    
    // Update reason text field
    const reasonsText = Array.from(newSelectedReasons).join(', ');
    setReason(reasonsText);
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    setSubmitting(true);

    try {
      const startDateTime = new Date(`${date}T${time}`);
      
      const consultationData = {
        patientUid: uid,
        patientName: userName,
        requestedAt: new Date().toISOString(),
        appointmentDate: startDateTime.toISOString(),
        duration: duration,
        reason: reason,
        status: 'scheduled',
        includeCaregiver: inviteCaregiver,
        createdAt: new Date().toISOString(),
      };

      // Save to Firebase
      const consultationsRef = ref(database, 'consultations');
      const newConsultationRef = push(consultationsRef);
      await set(newConsultationRef, consultationData);

      alert('Consultation booked successfully!');
      // Reset form
      setReason('');
      setSelectedReasons(new Set());
      setInviteCaregiver(false);
      
    } catch (error) {
      console.error('Error booking consultation:', error);
      alert('Failed to book consultation. Please try again.');
    } finally {
      setSubmitting(false);
    }
  };

  const composeStartDateTime = () => {
    if (!date || !time) return null;
    return new Date(`${date}T${time}`);
  };

  const formatDisplayDate = (dateTime) => {
    return dateTime.toLocaleDateString('en-US', {
      weekday: 'short',
      month: 'short',
      day: 'numeric',
      hour: 'numeric',
      minute: '2-digit',
      hour12: true
    });
  };

  const startDateTime = composeStartDateTime();

  return (
    <div className="appointment-booking-page">
      <div className="page-header">
        <h1>Book GP Consultation</h1>
      </div>

      <form onSubmit={handleSubmit} className="booking-form">
        {/* Header Card */}
        <div className="info-card">
          <div className="info-content">
            <label>Booking for:</label>
            <h3>{userName}</h3>
            <p>
              Pick a time and tell us the main reason. We'll set up a video GP call 
              and remind you and your caregiver.
            </p>
          </div>
        </div>

        {/* Date & Time Selection */}
        <div className="form-row">
          <div className="form-group">
            <label>Date</label>
            <div className="input-with-icon">
              <span className="input-icon">📅</span>
              <input
                type="date"
                value={date}
                onChange={(e) => setDate(e.target.value)}
                min={new Date().toISOString().split('T')[0]}
                required
              />
            </div>
          </div>

          <div className="form-group">
            <label>Time</label>
            <div className="input-with-icon">
              <span className="input-icon">⏰</span>
              <input
                type="time"
                value={time}
                onChange={(e) => setTime(e.target.value)}
                required
              />
            </div>
          </div>
        </div>

        {/* Duration */}
        <div className="form-group">
          <label>Duration</label>
          <select 
            value={duration} 
            onChange={(e) => setDuration(parseInt(e.target.value))}
            className="duration-select"
          >
            <option value={15}>15 minutes</option>
            <option value={20}>20 minutes</option>
            <option value={30}>30 minutes</option>
          </select>
        </div>

        {/* Reasons */}
        <div className="form-group">
          <label>Reasons for appointment</label>
          <div className="reason-chips">
            {quickReasons.map((reasonText) => (
              <button
                key={reasonText}
                type="button"
                className={`reason-chip ${selectedReasons.has(reasonText) ? 'selected' : ''}`}
                onClick={() => handleReasonSelect(reasonText)}
              >
                {reasonText}
              </button>
            ))}
          </div>
          <textarea
            value={reason}
            onChange={(e) => setReason(e.target.value)}
            placeholder="e.g. 'Persistent cough since yesterday', 'Medication refill'..."
            rows={3}
            required
          />
        </div>

        {/* Caregiver Invite */}
        <div className="caregiver-option">
          <label className="checkbox-label">
            <input
              type="checkbox"
              checked={inviteCaregiver}
              onChange={(e) => setInviteCaregiver(e.target.checked)}
            />
            <span>Invite primary caregiver to the consultation</span>
          </label>
          <p className="helper-text">
            They will receive the event reminder and be invited to join the call.
          </p>
        </div>

        {/* Submit Button */}
        <button 
          type="submit" 
          className="submit-button"
          disabled={submitting}
        >
          {submitting ? 'Booking...' : 'Confirm Booking'}
        </button>

        {/* Preview */}
        {startDateTime && (
          <div className="booking-preview">
            <h4>Appointment Preview</h4>
            <p>{formatDisplayDate(startDateTime)}</p>
            <p>Duration: {duration} minutes</p>
            {inviteCaregiver && <p>✅ Caregiver will be invited</p>}
          </div>
        )}
      </form>
    </div>
  );
};

export default AppointmentBookingPage;