import React, { useState } from 'react';
import './doctorsAppointmentPage.css';

const DoctorsAppointmentPage = ({ userName, userType }) => {
  const [consultationType, setConsultationType] = useState('video');
  const [isConsultationActive, setIsConsultationActive] = useState(false);
  const [symptoms, setSymptoms] = useState('');
  const [medications, setMedications] = useState('');
  const [duration, setDuration] = useState('');

  const startConsultation = () => {
    if (!symptoms.trim()) {
      alert('Please describe your symptoms before starting the consultation.');
      return;
    }
    setIsConsultationActive(true);
    alert(`Starting ${consultationType} consultation with doctor...`);
  };

  const endConsultation = () => {
    setIsConsultationActive(false);
    setSymptoms('');
    setMedications('');
    setDuration('');
    alert('Consultation ended');
  };

  // Generate profile image based on user's name
  const getProfileImage = () => {
    const colors = [
      '#4A90E2', '#5AA9E6', '#7EC8E3', '#87CEEB', '#B0E2FF'
    ];
    const color = colors[userName.length % colors.length];
    const initials = userName
      .split(' ')
      .map(word => word[0])
      .join('')
      .toUpperCase()
      .slice(0, 2);

    return (
      <div 
        className="profile-image-placeholder"
        style={{ backgroundColor: color }}
      >
        {initials}
      </div>
    );
  };

  return (
    <div className="doctors-appointment-page">
      <div className="page-header">
        <h2>Doctor's Appointment</h2>
        <div className="user-welcome">
          {getProfileImage()}
          <div className="welcome-text">
            <span>Welcome back,</span>
            <strong>{userName}</strong>
          </div>
        </div>
      </div>

      {!isConsultationActive ? (
        <div className="consultation-setup">
          <div className="setup-header">
            <h3>Start a New Consultation</h3>
            <p>Choose your preferred consultation type and provide some basic information</p>
          </div>
          
          <div className="consultation-type">
            <h4>Select Consultation Type</h4>
            <div className="consultation-options">
              <label className="consultation-option">
                <input 
                  type="radio" 
                  value="video" 
                  checked={consultationType === 'video'}
                  onChange={() => setConsultationType('video')}
                />
                <div className="option-content">
                  <span className="option-icon">📹</span>
                  <div className="option-details">
                    <span className="option-title">Video Consultation</span>
                    <span className="option-description">Face-to-face video call with doctor</span>
                  </div>
                </div>
              </label>
              
              <label className="consultation-option">
                <input 
                  type="radio" 
                  value="audio" 
                  checked={consultationType === 'audio'}
                  onChange={() => setConsultationType('audio')}
                />
                <div className="option-content">
                  <span className="option-icon">📞</span>
                  <div className="option-details">
                    <span className="option-title">Audio Consultation</span>
                    <span className="option-description">Voice call with doctor</span>
                  </div>
                </div>
              </label>
            </div>
          </div>
          
          <div className="triage-form">
            <h4>Pre-Consultation Information</h4>
            <div className="form-grid">
              <div className="form-group">
                <label>Symptoms *</label>
                <textarea 
                  value={symptoms}
                  onChange={(e) => setSymptoms(e.target.value)}
                  placeholder="Describe your symptoms in detail..."
                  rows="4"
                  required
                />
              </div>
              
              <div className="form-group">
                <label>Current Medications</label>
                <textarea 
                  value={medications}
                  onChange={(e) => setMedications(e.target.value)}
                  placeholder="List any medications you're currently taking..."
                  rows="3"
                />
              </div>
              
              <div className="form-group">
                <label>Duration of Symptoms</label>
                <input 
                  type="text" 
                  value={duration}
                  onChange={(e) => setDuration(e.target.value)}
                  placeholder="How long have you had these symptoms?" 
                />
              </div>
            </div>
          </div>
          
          <div className="consultation-actions">
            <button 
              className="start-consultation-btn" 
              onClick={startConsultation}
              disabled={!symptoms.trim()}
            >
              Start Consultation
            </button>
            <button className="emergency-btn">
              🚨 Emergency Assistance
            </button>
          </div>
        </div>
      ) : (
        <div className="consultation-active">
          <div className="consultation-header">
            <div className="consultation-info">
              <h3>Ongoing {consultationType === 'video' ? 'Video' : 'Audio'} Consultation</h3>
              <p>Connected with Dr. Smith - General Practitioner</p>
            </div>
            <button className="end-consultation-btn" onClick={endConsultation}>
              End Consultation
            </button>
          </div>
          
          <div className="consultation-interface" style={{marginLeft: "20%"}}>
            {consultationType === 'video' ? (
              <div className="video-container">
                <div className="video-grid">
                  <div className="video-feed doctor-feed">
                    <div className="video-placeholder">
                      <div className="doctor-avatar">👨‍⚕️</div>
                      <p>Dr. Smith</p>
                      <span>Connected</span>
                    </div>
                  </div>
                  <div className="video-feed user-feed">
                    <div className="video-placeholder">
                      <div className="user-avatar">{getProfileImage()}</div>
                      <p>You</p>
                      <span>Connected</span>
                    </div>
                  </div>
                </div>
              </div>
            ) : (
              <div className="audio-container">
                <div className="audio-interface">
                  <div className="audio-avatar">
                    <div className="doctor-avatar-large">👨‍⚕️</div>
                    <p>Dr. Smith</p>
                    <span>On call...</span>
                  </div>
                  <div className="call-timer">
                    <span>00:05:32</span>
                  </div>
                </div>
              </div>
            )}
            
            <div className="consultation-controls" style={{backgroundColor: 'lightblue'}}>
              <button className="control-btn mute-btn" style={{width: "25%", height: "80px"}}>
                <span className="control-icon">🎤</span>
                Mute
              </button>
              {consultationType === 'video' && (
                <button className="control-btn video-btn" style={{width: "25%", height: "80px"}}>
                  <span className="control-icon">📹</span>
                  Video Off
                </button>
              )}
              <button className="control-btn share-btn" style={{width: "25%", height: "80px"}}>
                <span className="control-icon">📤</span>
                Share
              </button>
              <button className="control-btn chat-btn" style={{width: "25%", height: "80px"}}>
                <span className="control-icon">💬</span>
                Chat
              </button>
            </div>

            <div className="consultation-sidebar">
              <div className="sidebar-section">
                <h5>Patient Information</h5>
                <div className="patient-info">
                  <p><strong>Name:</strong> {userName}</p>
                  <p><strong>Symptoms:</strong> {symptoms}</p>
                  {medications && <p><strong>Medications:</strong> {medications}</p>}
                  {duration && <p><strong>Duration:</strong> {duration}</p>}
                </div>
              </div>
              
              <div className="sidebar-section">
                <h5>Chat</h5>
                <div className="chat-container">
                  <div className="chat-messages">
                    <div className="message doctor-message">
                      <p>Hello! How can I help you today?</p>
                    </div>
                  </div>
                  <div className="chat-input">
                    <input type="text" placeholder="Type your message..." />
                    <button>Send</button>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default DoctorsAppointmentPage;