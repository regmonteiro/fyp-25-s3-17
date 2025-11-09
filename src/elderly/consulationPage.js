import React, { useEffect, useState } from "react";
import { database } from "../firebaseConfig";
import { ref, onValue, off, set, push, update, get } from "firebase/database";
import './consultationPage.css';

const ConsultationHistoryPage = () => {
  const [consultations, setConsultations] = useState([]);
  const [loading, setLoading] = useState(true);
  const [userName, setUserName] = useState("User");
  const [uid, setUid] = useState("");
  const [userEmail, setUserEmail] = useState("");
  const [caregivers, setCaregivers] = useState([]);
  const [showInviteModal, setShowInviteModal] = useState(false);
  const [selectedCaregivers, setSelectedCaregivers] = useState([]);
  const [inviteLoading, setInviteLoading] = useState(false);
  const [currentConsultationId, setCurrentConsultationId] = useState("");
  const [inviteStep, setInviteStep] = useState(1);
  const [showConfirmationModal, setShowConfirmationModal] = useState(false);
  const [showCallModal, setShowCallModal] = useState(false);
  const [showCallInitiationModal, setShowCallInitiationModal] = useState(false);
  const [selectedConsultation, setSelectedConsultation] = useState(null);
  const [callType, setCallType] = useState('video');
  const [showCreateConsultationModal, setShowCreateConsultationModal] = useState(false);
  const [newConsultationData, setNewConsultationData] = useState({
    reason: '',
    date: '',
    time: '',
    location: 'Virtual Consultation',
    notes: ''
  });
  
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

  // Enhanced email normalization for comparison
  const normalizeEmailForComparison = (email) => {
    if (!email) return '';
    return email.toLowerCase().trim().replace(/\./g, '');
  };

  // Helper function to check caregiver assignment
  const checkAssignment = (assignmentValue, elderlyEmail, elderlyUid, elderlyEmailNormalized) => {
    if (!assignmentValue) return false;
    
    const assignmentNormalized = assignmentValue.toLowerCase().trim().replace(/\./g, '');
    
    // Check if assignment matches elderly email (normalized)
    if (assignmentNormalized === elderlyEmailNormalized) {
      return true;
    }
    
    // Check if assignment matches elderly UID
    if (elderlyUid && assignmentValue === elderlyUid) {
      return true;
    }
    
    // Check if assignment contains elderly email (partial match)
    if (assignmentValue.toLowerCase().includes(elderlyEmail.toLowerCase())) {
      return true;
    }
    
    return false;
  };

  // Get caregivers for elderly using the improved logic
  const getCaregiversForElderly = (elderlyEmail, accounts) => {
    const caregiversList = [];
    if (!accounts || !elderlyEmail) return caregiversList;
    
    const elderlyEmailNormalized = normalizeEmailForComparison(elderlyEmail);
    
    console.log("🎯 Searching for caregivers with:", {
      elderlyEmail,
      elderlyEmailNormalized
    });

    // Get elderly UID from accounts if available
    const elderlyAccountEntry = Object.entries(accounts).find(([key, account]) => 
      account.email && normalizeEmailForComparison(account.email) === elderlyEmailNormalized
    );
    const elderlyUid = elderlyAccountEntry ? elderlyAccountEntry[1].uid : null;
    
    console.log("Elderly UID:", elderlyUid);

    // Loop through all accounts to find caregivers
    Object.entries(accounts).forEach(([accountKey, accountData]) => {
      if (accountData.userType === "caregiver") {
        console.log(`\n🔍 Checking caregiver: ${accountData.email}`);
        
        let isAssigned = false;
        let assignmentReason = "";

        // Check elderlyId (single assignment)
        if (accountData.elderlyId) {
          console.log(`   Checking elderlyId: ${accountData.elderlyId}`);
          if (checkAssignment(accountData.elderlyId, elderlyEmail, elderlyUid, elderlyEmailNormalized)) {
            isAssigned = true;
            assignmentReason = `Assigned caregiver`;
          }
        }

        // Check elderlyIds (array assignment)
        if (!isAssigned && accountData.elderlyIds && Array.isArray(accountData.elderlyIds)) {
          console.log(`   Checking elderlyIds:`, accountData.elderlyIds);
          accountData.elderlyIds.forEach(elderlyId => {
            if (checkAssignment(elderlyId, elderlyEmail, elderlyUid, elderlyEmailNormalized)) {
              isAssigned = true;
              assignmentReason = `Assigned caregiver`;
            }
          });
        }

        // Check linkedElders (alternative field name)
        if (!isAssigned && accountData.linkedElders) {
          console.log(`   Checking linkedElders:`, accountData.linkedElders);
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
          console.log(`   Checking linkedElderUids:`, accountData.linkedElderUids);
          accountData.linkedElderUids.forEach(linkedElderUid => {
            if (checkAssignment(linkedElderUid, elderlyEmail, elderlyUid, elderlyEmailNormalized)) {
              isAssigned = true;
              assignmentReason = `Assigned caregiver`;
            }
          });
        }

        // Check uidOfElder field
        if (!isAssigned && accountData.uidOfElder) {
          console.log(`   Checking uidOfElder: ${accountData.uidOfElder}`);
          if (checkAssignment(accountData.uidOfElder, elderlyEmail, elderlyUid, elderlyEmailNormalized)) {
            isAssigned = true;
            assignmentReason = `Assigned caregiver`;
          }
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
          
          console.log(`🎉 FOUND CAREGIVER: ${fullName} - ${assignmentReason}`);
        } else {
          console.log(`❌ No assignment found for ${accountData.email}`);
        }
      }
    });
    
    console.log("📋 FINAL CAREGIVERS LIST:", caregiversList);
    return caregiversList;
  };

  useEffect(() => {
    const storedName = localStorage.getItem("userName") || "Elderly User";
    const storedUid = localStorage.getItem("uid");
    const storedEmail = localStorage.getItem("userEmail") || localStorage.getItem("loggedInEmail") || 'elderlyone@gmail.com';
    
    setUserName(storedName);
    setUid(storedUid);
    setUserEmail(storedEmail);

    console.log("Loading consultations for user:", { storedEmail, storedUid, storedName });

    // Fetch consultation history from Firebase
    const consultationsRef = ref(database, 'consultations');
    const accountsRef = ref(database, 'Account');
    
    const unsubscribeConsultations = onValue(consultationsRef, (snapshot) => {
      const data = snapshot.val();
      console.log("Raw consultations data from Firebase:", data);
      
      if (data) {
        const normalizedUserEmail = normalizeEmailForComparison(storedEmail);
        
        const consultationsList = Object.entries(data)
          .map(([id, consultation]) => ({
            id,
            ...consultation,
          }))
          .filter(consultation => {
            // Multiple matching strategies to catch all consultations
            const matches = [
              // Direct email match
              consultation.elderlyEmail && normalizeEmailForComparison(consultation.elderlyEmail) === normalizedUserEmail,
              // elderlyId match
              consultation.elderlyId && normalizeEmailForComparison(consultation.elderlyId) === normalizedUserEmail,
              // patientUid match
              consultation.patientUid === storedUid,
              // patientName match (fallback)
              consultation.patientName && normalizeEmailForComparison(consultation.patientName) === normalizedUserEmail,
              // Check if elderlyEmail contains user email (partial match)
              consultation.elderlyEmail && consultation.elderlyEmail.toLowerCase().includes(storedEmail.toLowerCase()),
              // Check appointments collection linkage
              consultation.elderlyId && consultation.elderlyId.toLowerCase() === storedEmail.toLowerCase()
            ];

            const isMatch = matches.some(match => match === true);
            
            if (isMatch) {
              console.log("Matched consultation:", {
                id: consultation.id,
                elderlyEmail: consultation.elderlyEmail,
                elderlyId: consultation.elderlyId,
                patientUid: consultation.patientUid,
                reason: consultation.reason
              });
            }
            
            return isMatch;
          })
          .map(consultation => ({
            ...consultation,
            elderlyEmail: consultation.elderlyEmail || storedEmail,
            elderlyId: consultation.elderlyId || storedEmail,
            elderlyName: consultation.elderlyName || consultation.patientName || storedName,
            displayDate: consultation.appointmentDate || consultation.requestedAt,
            createdDate: consultation.createdAt || consultation.requestedAt
          }))
          .sort((a, b) => {
            const dateA = a.displayDate ? new Date(a.displayDate) : new Date(0);
            const dateB = b.displayDate ? new Date(b.displayDate) : new Date(0);
            return dateB - dateA;
          });
        
        console.log("Filtered consultations:", consultationsList.length, consultationsList);
        setConsultations(consultationsList);
      } else {
        console.log("No consultations data found");
        setConsultations([]);
      }
      setLoading(false);
    }, (error) => {
      console.error("Error loading consultation history:", error);
      setLoading(false);
    });

    // Fetch accounts to get caregivers using the improved function
    const unsubscribeAccounts = onValue(accountsRef, (snapshot) => {
      const accounts = snapshot.val();
      if (accounts) {
        const caregiversList = getCaregiversForElderly(storedEmail, accounts);
        console.log("🎯 Setting caregivers state:", caregiversList);
        setCaregivers(caregiversList);
      } else {
        console.log("No accounts data found");
        setCaregivers([]);
      }
    });

    return () => {
      off(consultationsRef, 'value', unsubscribeConsultations);
      off(accountsRef, 'value', unsubscribeAccounts);
    };
  }, []);

  // Helper function to normalize email for comparison
  const normalizeEmail = (email) => {
    return email ? email.toLowerCase().trim().replace(/\./g, '') : '';
  };

  // Helper function to get user display name
  const getUserDisplayName = (email, accounts) => {
    const normalizedEmail = normalizeEmail(email);
    const account = Object.values(accounts).find(acc => 
      acc.email && normalizeEmail(acc.email) === normalizedEmail
    );
    if (account) {
      return `${account.firstname || ''} ${account.lastname || ''}`.trim() || email;
    }
    return email;
  };

  // Create new consultation and corresponding appointment
  const createNewConsultation = async () => {
    if (!newConsultationData.reason || !newConsultationData.date || !newConsultationData.time) {
      alert('Please fill in all required fields: reason, date, and time.');
      return;
    }

    try {
      setLoading(true);
      
      // Create consultation
      const consultationRef = push(ref(database, 'consultations'));
      const consultationId = consultationRef.key;
      
      // Combine date and time for appointmentDate
      const appointmentDateTime = new Date(`${newConsultationData.date}T${newConsultationData.time}`);
      
      // Get the current user's email properly
      const currentUserEmail = localStorage.getItem("userEmail") || localStorage.getItem("loggedInEmail") || userEmail;
      
      const consultationData = {
        id: consultationId,
        reason: newConsultationData.reason,
        requestedAt: new Date().toISOString(),
        appointmentDate: appointmentDateTime.toISOString(),
        status: 'scheduled',
        elderlyEmail: currentUserEmail,
        elderlyId: currentUserEmail,
        elderlyName: userName,
        patientUid: uid,
        patientName: userName,
        location: newConsultationData.location,
        notes: newConsultationData.notes,
        includeCaregiver: false,
        createdAt: new Date().toISOString(),
        lastUpdated: new Date().toISOString()
      };

      await set(consultationRef, consultationData);

      // Create corresponding appointment
      await createAppointmentFromConsultation(consultationData, currentUserEmail);

      alert('Consultation created successfully! It will appear in your appointments.');
      setShowCreateConsultationModal(false);
      setNewConsultationData({
        reason: '',
        date: '',
        time: '',
        location: 'Virtual Consultation',
        notes: ''
      });
      
    } catch (error) {
      console.error('Error creating consultation:', error);
      alert('Failed to create consultation. Please try again.');
    } finally {
      setLoading(false);
    }
  };

  // Create appointment from consultation
  const createAppointmentFromConsultation = async (consultationData, elderlyEmail) => {
    try {
      const appointmentsRef = ref(database, 'Appointments');
      const newAppointmentRef = push(appointmentsRef);
      
      // Extract date and time from appointmentDate
      const appointmentDateObj = new Date(consultationData.appointmentDate);
      const appointmentDate = appointmentDateObj.toISOString().split('T')[0];
      const appointmentTime = appointmentDateObj.toTimeString().split(' ')[0].substring(0, 5);

      const appointmentData = {
        id: newAppointmentRef.key,
        title: `GP Consultation: ${consultationData.reason}`,
        date: appointmentDate,
        time: appointmentTime,
        location: consultationData.location,
        notes: consultationData.notes,
        status: 'confirmed',
        elderlyId: elderlyEmail,
        elderlyEmail: elderlyEmail,
        elderlyName: consultationData.elderlyName,
        isCompleted: false,
        consultationId: consultationData.id,
        type: 'consultation',
        createdAt: new Date().toISOString(),
        appointmentDate: consultationData.appointmentDate
      };

      
      await set(newAppointmentRef, appointmentData);
      
    } catch (error) {
      console.error('Error creating appointment from consultation:', error);
      throw error;
    }
  };

  // Handle caregiver selection
  const handleCaregiverSelection = (caregiverEmail, isSelected) => {
    if (isSelected) {
      setSelectedCaregivers(prev => [...prev, caregiverEmail]);
    } else {
      setSelectedCaregivers(prev => prev.filter(email => email !== caregiverEmail));
    }
  };

  // Select all caregivers
  const selectAllCaregivers = () => {
    setSelectedCaregivers(caregivers.map(c => c.email));
  };

  // Deselect all caregivers
  const deselectAllCaregivers = () => {
    setSelectedCaregivers([]);
  };

  // Show confirmation modal before inviting
  const showInviteConfirmation = () => {
    if (selectedCaregivers.length === 0) {
      alert('Please select at least one caregiver to invite.');
      return;
    }
    setShowConfirmationModal(true);
  };

  // Invite caregivers to consultation
  const inviteCaregiversToConsultation = async (consultationId, caregiverEmails) => {
    if (!consultationId || caregiverEmails.length === 0) {
      alert('Please select at least one caregiver to invite.');
      return;
    }

    setInviteLoading(true);
    try {
      const consultation = consultations.find(c => c.id === consultationId);
      if (!consultation) {
        throw new Error('Consultation not found');
      }

      // Create invitations for each selected caregiver
      const invitationPromises = caregiverEmails.map(async (caregiverEmail) => {
        const invitationRef = push(ref(database, 'consultationInvitations'));
        const invitationData = {
          consultationId: consultationId,
          elderlyEmail: userEmail,
          elderlyName: userName,
          caregiverEmail: caregiverEmail,
          status: 'pending',
          invitedAt: new Date().toISOString(),
          consultationDate: consultation.appointmentDate || consultation.requestedAt,
          consultationReason: consultation.reason
        };
        console.log('Creating invitation for:', caregiverEmail);
        return set(invitationRef, invitationData);
      });

      await Promise.all(invitationPromises);
      console.log('All invitations created successfully');

      // Update consultation with invited caregivers using normalized keys
      const consultationUpdates = {
        elderlyEmail: userEmail,
        elderlyName: userName,
        lastUpdated: new Date().toISOString()
      };
      
      // Initialize invitedCaregivers if it doesn't exist
      const currentInvitedCaregivers = consultation.invitedCaregivers || {};
      
      caregiverEmails.forEach(caregiverEmail => {
        // Normalize email for Firebase key (replace invalid characters)
        const normalizedKey = normalizeEmailForFirebase(caregiverEmail);
        
        currentInvitedCaregivers[normalizedKey] = {
          invitedAt: new Date().toISOString(),
          status: 'pending',
          elderlyEmail: userEmail,
          caregiverEmail: caregiverEmail, // Store original email in the value
          originalEmail: caregiverEmail // Keep original for display purposes
        };
      });
      
      consultationUpdates.invitedCaregivers = currentInvitedCaregivers;
      
      // Update the consultation in database
      const consultationRef = ref(database, `consultations/${consultationId}`);
      console.log('Updating consultation with:', consultationUpdates);
      await update(consultationRef, consultationUpdates);
      
      alert(`Successfully invited ${caregiverEmails.length} caregiver(s) to the consultation!`);
      setShowInviteModal(false);
      setShowConfirmationModal(false);
      setSelectedCaregivers([]);
      setCurrentConsultationId("");
      setInviteStep(1);
    } catch (error) {
      console.error('Error inviting caregivers:', error);
      console.error('Error details:', error.message, error.stack);
      alert('Failed to invite caregivers. Please check console for details and try again.');
    } finally {
      setInviteLoading(false);
    }
  };

  // Call functionality
  const handleStartCall = (consultation, type = 'video') => {
    setSelectedConsultation(consultation);
    setCallType(type);
    setShowCallModal(true);
    
    // Log call start in Firebase
    logCallStart(consultation.id, type);
  };

  const handleCallInitiation = (consultation) => {
    setSelectedConsultation(consultation);
    setShowCallInitiationModal(true);
  };

  const handleCallEnd = (callData) => {
    // Log call end in Firebase
    logCallEnd(callData);
    
    // Show call summary
    alert(`Call ended. Duration: ${callData.duration} seconds`);
  };

  const logCallStart = async (consultationId, callType) => {
    try {
      const callRef = push(ref(database, 'calls'));
      await set(callRef, {
        consultationId,
        callType,
        startedAt: new Date().toISOString(),
        elderlyEmail: userEmail,
        elderlyName: userName,
        status: 'active'
      });
    } catch (error) {
      console.error('Error logging call start:', error);
    }
  };

  const logCallEnd = async (callData) => {
    try {
      const callsRef = ref(database, 'calls');
      const snapshot = await get(callsRef);
      const calls = snapshot.val();
      
      if (calls) {
        const callEntry = Object.entries(calls).find(([id, call]) => 
          call.consultationId === callData.consultationId && call.status === 'active'
        );
        
        if (callEntry) {
          const [callId, call] = callEntry;
          await update(ref(database, `calls/${callId}`), {
            endedAt: new Date().toISOString(),
            duration: callData.duration,
            status: 'completed'
          });
        }
      }
    } catch (error) {
      console.error('Error logging call end:', error);
    }
  };

  const formatDate = (timestamp) => {
    if (!timestamp) return 'Date Unavailable';
    try {
      const date = new Date(timestamp);
      return date.toLocaleDateString('en-US', {
        month: 'short',
        day: 'numeric',
        year: 'numeric',
        hour: 'numeric',
        minute: '2-digit',
        hour12: true
      });
    } catch (error) {
      console.error('Error formatting date:', error, timestamp);
      return 'Invalid Date';
    }
  };

  // Get display date for consultation (prefer appointmentDate, fallback to requestedAt)
  const getDisplayDate = (consultation) => {
    return consultation.appointmentDate || consultation.requestedAt || consultation.createdAt;
  };

  // Get created date for consultation
  const getCreatedDate = (consultation) => {
    return consultation.createdAt || consultation.requestedAt;
  };

  // Open invite modal
  const openInviteModal = (consultationId) => {
    setCurrentConsultationId(consultationId);
    setSelectedCaregivers([]);
    setShowInviteModal(true);
    setInviteStep(1);
  };

  // Handle step 1 selection
  const handleInviteTypeSelection = (type) => {
    if (type === 'primary' && caregivers.length > 0) {
      const primaryCaregiver = caregivers[0];
      setSelectedCaregivers([primaryCaregiver.email]);
      setInviteStep(2);
    } else if (type === 'choose') {
      setSelectedCaregivers([]);
      setInviteStep(2);
    }
  };

  // Close modal and reset
  const closeModal = () => {
    setShowInviteModal(false);
    setShowConfirmationModal(false);
    setShowCreateConsultationModal(false);
    setSelectedCaregivers([]);
    setInviteStep(1);
  };

  // Handle new consultation form changes
  const handleNewConsultationChange = (e) => {
    const { name, value } = e.target;
    setNewConsultationData(prev => ({
      ...prev,
      [name]: value
    }));
  };

  if (loading) {
    return (
      <div className="loading-container">
        <div className="loading-spinner"></div>
        <p>Loading consultation history...</p>
      </div>
    );
  }

  return (
    <div className="consultation-history-page">
      <div className="page-header">
        <h1 style={{fontSize: "1.4rem"}}>GP Consultation History</h1>
       
        <div className="header-actions" style={{marginLeft: "50px"}}>
          <button 
            className="btn-primary" style={{width: "250px"}}
            onClick={() => setShowCreateConsultationModal(true)}
          >
            + New Consultation
          </button>
        </div>
        {caregivers.length > 0 && (
          <div className="caregiver-info-banner" style={{marginTop: "100px"}}>
            <span>👥 You have {caregivers.length} caregiver(s) assigned</span>
          </div>
        )}
      </div>

      <div className="consultation-content">
        {consultations.length === 0 ? (
          <div className="empty-state">
            <div className="empty-icon">📋</div>
            <h3>No consultations found</h3>
            <p>Your consultation history will appear here after your first GP consultation.</p>
            <button 
              className="btn-primary"
              onClick={() => setShowCreateConsultationModal(true)}
            >
              Schedule Your First Consultation
            </button>
          </div>
        ) : (
          <div className="consultations-list">
            {consultations.map((consultation) => (
              <ConsultationCard
                key={consultation.id}
                consultation={consultation}
                formatDate={formatDate}
                getDisplayDate={getDisplayDate}
                getCreatedDate={getCreatedDate}
                caregivers={caregivers}
                onInviteCaregiver={openInviteModal}
                onStartCall={handleCallInitiation}
                currentUserEmail={userEmail}
                currentUserName={userName}
              />
            ))}
          </div>
        )}
      </div>

      {/* Create New Consultation Modal */}
      {showCreateConsultationModal && (
        <div className="modal-overlay-fixed">
          <div className="modal-content consultation-create-modal">
            <div className="modal-header">
              <h3>Schedule New Consultation</h3>
              <button className="close-btn" onClick={closeModal}>×</button>
            </div>
            
            <div className="modal-body">
              <div className="consultation-form">
                <div className="form-group">
                  <label htmlFor="reason">Reason for Consultation *</label>
                  <input
                    type="text"
                    id="reason"
                    name="reason"
                    value={newConsultationData.reason}
                    onChange={handleNewConsultationChange}
                    placeholder="Describe the reason for consultation"
                    required
                  />
                </div>
                
                <div className="form-row">
                  <div className="form-group">
                    <label htmlFor="date">Date *</label>
                    <input
                      type="date"
                      id="date"
                      name="date"
                      value={newConsultationData.date}
                      onChange={handleNewConsultationChange}
                      required
                      min={new Date().toISOString().split('T')[0]}
                    />
                  </div>
                  
                  <div className="form-group">
                    <label htmlFor="time">Time *</label>
                    <input
                      type="time"
                      id="time"
                      name="time"
                      value={newConsultationData.time}
                      onChange={handleNewConsultationChange}
                      required
                    />
                  </div>
                </div>
                
                <div className="form-group">
                  <label htmlFor="location">Location</label>
                  <select
                    id="location"
                    name="location"
                    value={newConsultationData.location}
                    onChange={handleNewConsultationChange}
                  >
                    <option value="Virtual Consultation">Virtual Consultation</option>
                    <option value="Clinic Visit">Clinic Visit</option>
                    <option value="Home Visit">Home Visit</option>
                  </select>
                </div>
                
                <div className="form-group">
                  <label htmlFor="notes">Additional Notes</label>
                  <textarea
                    id="notes"
                    name="notes"
                    value={newConsultationData.notes}
                    onChange={handleNewConsultationChange}
                    placeholder="Any additional information for the doctor..."
                    rows="3"
                  />
                </div>
              </div>
            </div>
            
            <div className="modal-actions">
              <button className="btn-secondary" onClick={closeModal}>
                Cancel
              </button>
              <button 
                className="btn-primary" 
                onClick={createNewConsultation}
                disabled={!newConsultationData.reason || !newConsultationData.date || !newConsultationData.time}
              >
                Schedule Consultation
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Invite Caregiver Modal */}
      {showInviteModal && (
        <div className="modal-overlay-fixed">
          <div className="modal-content invite-modal" style={{maxWidth: '800px'}}>
            <div className="modal-header">
              <h3>Invite Caregiver to Consultation</h3>
              <button className="close-btn" onClick={closeModal}>×</button>
            </div>
            
            <div className="modal-body">
              {inviteStep === 1 && (
                <div className="invite-step">
                  <h4>Choose Invitation Type</h4>
                  <div className="invite-options">
                    <div 
                      className="invite-option"
                      onClick={() => handleInviteTypeSelection('primary')}
                    >
                      <div className="option-icon">👤</div>
                      <div className="option-title">Primary Caregiver</div>
                      <div className="option-description">
                        Invite your main caregiver automatically
                      </div>
                    </div>
                    
                    <div 
                      className="invite-option"
                      onClick={() => handleInviteTypeSelection('choose')}
                    >
                      <div className="option-icon">👥</div>
                      <div className="option-title">Choose Caregivers</div>
                      <div className="option-description">
                        Select specific caregivers to invite
                      </div>
                    </div>
                  </div>
                </div>
              )}
              
              {inviteStep === 2 && (
                <div className="invite-step">
                  <h4>Select Caregivers to Invite</h4>
                  <div className="caregiver-selection">
                    <div className="selection-actions">
                      <button className="btn-link" onClick={selectAllCaregivers}>
                        Select All
                      </button>
                      <button className="btn-link" onClick={deselectAllCaregivers}>
                        Deselect All
                      </button>
                    </div>
                    
                    <div className="caregiver-list-selection">
                      {caregivers.map((caregiver) => (
                        <div
                          key={caregiver.email}
                          className={`caregiver-item ${selectedCaregivers.includes(caregiver.email) ? 'selected' : ''}`}
                          onClick={() => handleCaregiverSelection(caregiver.email, !selectedCaregivers.includes(caregiver.email))}
                        >
                          <div className="caregiver-checkbox">
                            {selectedCaregivers.includes(caregiver.email) && '✓'}
                          </div>
                          <div className="caregiver-info-modal">
                            <div className="caregiver-name">{caregiver.name}</div>
                            <div className="caregiver-email">{caregiver.email}</div>
                            <div className="caregiver-phone">{caregiver.phoneNum}</div>
                          </div>
                        </div>
                      ))}
                    </div>
                    
                    {caregivers.length === 0 && (
                      <div className="empty-state" style={{padding: '20px'}}>
                        <p>No caregivers found for this elderly account.</p>
                        <p>Please make sure caregivers are properly assigned to your account.</p>
                      </div>
                    )}
                  </div>
                </div>
              )}
            </div>
            
            <div className="modal-actions">
              {inviteStep === 2 && (
                <>
                  <button className="btn-secondary" onClick={() => setInviteStep(1)}>
                    Back
                  </button>
                  <button 
                    className="btn-primary"  style={{width: "200px"}}
                    onClick={showInviteConfirmation}
                    disabled={selectedCaregivers.length === 0 || inviteLoading}
                  >
                    {inviteLoading ? 'Sending...' : `Invite ${selectedCaregivers.length} Caregiver(s)`}
                  </button>
                </>
              )}
            </div>
          </div>
        </div>
      )}

      {/* Confirmation Modal */}
      {showConfirmationModal && (
        <div className="modal-overlay-fixed">
          <div className="modal-content confirmation-modal">
            <div className="modal-header">
              <h3>Confirm Invitation</h3>
              <button className="close-btn" onClick={closeModal}>×</button>
            </div>
            
            <div className="modal-body">
              <div className="confirmation-content">
                <div className="confirmation-icon">📨</div>
                <h4>Send Invitations?</h4>
                <p>You are about to invite {selectedCaregivers.length} caregiver(s) to this consultation.</p>
                
                <div className="selected-caregivers-list">
                  {selectedCaregivers.map(email => {
                    const caregiver = caregivers.find(c => c.email === email);
                    return (
                      <div key={email} className="selected-caregiver-item">
                        <span>👤</span>
                        <span>{caregiver?.name || email}</span>
                        <span className="caregiver-phone-small">{caregiver?.phoneNum}</span>
                      </div>
                    );
                  })}
                </div>
                
                <p>They will receive a notification about this consultation.</p>
              </div>
            </div>
            
            <div className="modal-actions">
              <button className="btn-secondary" onClick={() => setShowConfirmationModal(false)}>
                Cancel
              </button>
              <button 
                className="btn-primary" 
                onClick={() => inviteCaregiversToConsultation(currentConsultationId, selectedCaregivers)}
                disabled={inviteLoading}
              >
                {inviteLoading ? 'Sending...' : 'Send Invitations'}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Call Initiation Modal */}
      <CallInitiationModal
        isOpen={showCallInitiationModal}
        onClose={() => setShowCallInitiationModal(false)}
        consultation={selectedConsultation}
        onCallStart={(type) => handleStartCall(selectedConsultation, type)}
      />
      
      {/* Video Call Modal */}
      <VideoCallModal
        isOpen={showCallModal}
        onClose={() => setShowCallModal(false)}
        consultation={selectedConsultation}
        userType="elderly"
        onCallEnd={handleCallEnd}
        callType={callType}
      />
    </div>
  );
};

const ConsultationCard = ({ consultation, formatDate, getDisplayDate, getCreatedDate, caregivers, onInviteCaregiver, onStartCall, currentUserEmail, currentUserName }) => {
  const {
    id,
    status = 'scheduled',
    reason = 'No reason provided.',
    includeCaregiver = false,
    invitedCaregivers = {},
    attendedCaregivers = {},
    elderlyEmail,
    elderlyName
  } = consultation;

  const displayDate = getDisplayDate(consultation);
  const createdDate = getCreatedDate(consultation);

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

  const displayEmail = elderlyEmail || currentUserEmail || 'elderlyone@gmail.com';
  const displayName = elderlyName || currentUserName || 'Elderly User';

  const gpName = status === 'Completed' ? 'Dr. Smith' : 'N/A';
  const diagnosis = status === 'Completed' ? 'Mild seasonal allergy' : 'Awaiting Outcome';

  const handleViewDetails = () => {
    const detailMessage = `
        Consultation Details:
        Appointment Date: ${formatDate(displayDate)}
        Created Date: ${formatDate(createdDate)}
        Status: ${status}
        Reason: ${reason}

        Elderly Information:
        Email: ${displayEmail}
        Name: ${displayName}

        Invited Caregivers: ${Object.keys(invitedCaregivers).length}
        Attended Caregivers: ${Object.keys(attendedCaregivers || {}).length}

${status === 'Completed' ? `GP: ${gpName}\nDiagnosis: ${diagnosis}` : 'Pending consultation'}
    `.trim();
    
    alert(detailMessage);
  };

  const hasInvitedCaregivers = Object.keys(invitedCaregivers).length > 0;
  const hasAttendedCaregivers = attendedCaregivers && Object.keys(attendedCaregivers).length > 0;
  const invitedCount = Object.keys(invitedCaregivers).length;
  const attendedCount = hasAttendedCaregivers ? Object.keys(attendedCaregivers).length : 0;

  return (
    <div className="consultation-card">
      <div className="consultation-header">
        <div className="consultation-date-info">
          <div className="consultation-date">
            <strong>Appointment:</strong> {formatDate(displayDate)}
          </div>
          <div className="consultation-created-date">
            <strong>Created:</strong> {formatDate(createdDate)}
          </div>
        </div>
        <StatusChip status={status} />
      </div>

      <div className="consultation-divider"></div>

      <div className="consultation-details">
        <div className="symptoms-section">
          <label>Reason for Consultation:</label>
          <p className="symptoms-text">{reason}</p>
        </div>

        <div className="elderly-info">
          <label>Elderly Information:</label>
          <div className="elderly-details">
            <span className="elderly-email">{displayEmail}</span>
            <span className="elderly-name">({displayName})</span>
          </div>
        </div>

        {status === 'Completed' && (
          <div className="medical-info">
            <div className="medical-item">
              <span className="medical-icon">🩺</span>
              <div className="medical-details">
                <div className="gp-name">GP Attended: {gpName}</div>
                <div className="diagnosis">Diagnosis: {diagnosis}</div>
              </div>
            </div>
          </div>
        )}

        {includeCaregiver && (
          <div className="caregiver-info">
            <span className="caregiver-icon">👥</span>
            <span>Caregiver Joined Call</span>
          </div>
        )}

        {hasInvitedCaregivers && (
          <div className="invited-caregivers">
            <label>Invited Caregivers ({invitedCount}):</label>
            <div className="caregiver-list">
              {Object.entries(invitedCaregivers).map(([normalizedKey, data]) => {
                const originalEmail = getOriginalEmail(normalizedKey, data);
                return (
                  <div key={normalizedKey} className={`caregiver-tag ${data.status === 'attended' ? 'attended' : ''}`}>
                    {originalEmail} 
                    <span className="caregiver-status">({data.status || 'pending'})</span>
                    {data.status === 'attended' && <span className="attended-badge">✓ Attended</span>}
                  </div>
                );
              })}
            </div>
          </div>
        )}

        {hasAttendedCaregivers && (
          <div className="attended-caregivers">
            <label>Attended Caregivers ({attendedCount}):</label>
            <div className="caregiver-list">
              {Object.entries(attendedCaregivers).map(([normalizedKey, data]) => {
                const originalEmail = getOriginalEmail(normalizedKey, data);
                return (
                  <div key={normalizedKey} className="caregiver-tag attended">
                    {originalEmail} 
                    <span className="attended-time">
                      at {data.attendedAt ? new Date(data.attendedAt).toLocaleTimeString() : 'unknown time'}
                    </span>
                  </div>
                );
              })}
            </div>
          </div>
        )}
      </div>

      <div className="consultation-actions">
        <button className="view-details-btn" onClick={handleViewDetails}>
          View Full Details
        </button>
        
        {/* Call Button */}
        {status !== 'Cancelled' && status !== 'Completed' && (
          <button 
            className="start-call-btn"
            onClick={() => onStartCall(consultation)}
          >
            📞 Start Call
          </button>
        )}
        
        {caregivers.length > 0 && status !== 'Completed' && (
          <button 
            className="invite-caregiver-btn"
            onClick={() => onInviteCaregiver(id)}
          >
            Invite Caregiver
          </button>
        )}
      </div>
    </div>
  );
};

const StatusChip = ({ status }) => {
  const getStatusConfig = (status) => {
    switch (status) {
      case 'Completed':
        return { color: '#22c55e', icon: '✓', label: 'Completed' };
      case 'scheduled':
        return { color: '#f97316', icon: '⏳', label: 'Scheduled' };
      case 'pending':
        return { color: '#f59e0b', icon: '⏰', label: 'Pending' };
      case 'Cancelled':
        return { color: '#ef4444', icon: '✕', label: 'Cancelled' };
      default:
        return { color: '#6b7280', icon: 'ℹ', label: status };
    }
  };

  const config = getStatusConfig(status);

  return (
    <div 
      className="status-chip"
      style={{ backgroundColor: config.color }}
    >
      <span className="status-icon">{config.icon}</span>
      <span className="status-label">{config.label}</span>
    </div>
  );
};

// Call Initiation Modal Component
const CallInitiationModal = ({ isOpen, onClose, consultation, onCallStart }) => {
  const [callType, setCallType] = useState('video');

  if (!isOpen) return null;

  const handleStartCall = () => {
    onCallStart(callType);
    onClose();
  };

  return (
    <div className="modal-overlay-fixed">
      <div className="modal-content call-initiation-modal" style={{marginTop: "120px", maxWidth: "900px"}}>
        <div className="modal-header">
          <h3>Start Consultation Call</h3>
          <button className="close-btn" onClick={onClose}>×</button>
        </div>
        
        <div className="modal-body">
          <div className="consultation-info">
            <h4>Consultation Details</h4>
            <div className="consultation-detail-item">
              <span className="detail-label">Reason:</span>
              <span className="detail-value">{consultation?.reason || 'General Checkup'}</span>
            </div>
            <div className="consultation-detail-item">
              <span className="detail-label">Status:</span>
              <span className="detail-value">{consultation?.status || 'Scheduled'}</span>
            </div>
          </div>

          <div className="call-type-selection">
            <h4>Select Call Type</h4>
            <div className="call-type-options">
              <div 
                className={`call-type-option ${callType === 'video' ? 'selected' : ''}`}
                onClick={() => setCallType('video')}
              >
                <div className="option-icon">📹</div>
                <div className="option-content">
                  <h5>Video Call</h5>
                  <p>Face-to-face consultation with video</p>
                </div>
                <div className="option-check">✓</div>
              </div>

              <div 
                className={`call-type-option ${callType === 'audio' ? 'selected' : ''}`}
                onClick={() => setCallType('audio')}
              >
                <div className="option-icon">📞</div>
                <div className="option-content">
                  <h5>Voice Call</h5>
                  <p>Audio-only consultation</p>
                </div>
                <div className="option-check">✓</div>
              </div>
            </div>
          </div>

          <div className="call-features">
            <h4>Call Features</h4>
            <ul>
              <li>🔒 Secure encrypted connection</li>
              <li>🎤 Real-time audio communication</li>
              {callType === 'video' && <li>📹 High-quality video streaming</li>}
              <li>⏱️ Call duration tracking</li>
              <li>💾 Automatic call logging</li>
            </ul>
          </div>
        </div>

        <div className="modal-actions">
          <button className="btn-secondary" onClick={onClose}>
            Cancel
          </button>
          <button className="btn-primary" onClick={handleStartCall}>
            Start {callType === 'video' ? 'Video' : 'Voice'} Call
          </button>
        </div>
      </div>
    </div>
  );
};

// Video Call Modal Component
const VideoCallModal = ({ isOpen, onClose, consultation, userType, onCallEnd, callType }) => {
  const [callStatus, setCallStatus] = useState('connecting');
  const [localStream, setLocalStream] = useState(null);
  const [remoteStream, setRemoteStream] = useState(null);
  const [callDuration, setCallDuration] = useState(0);
  const localVideoRef = React.useRef(null);
  const remoteVideoRef = React.useRef(null);
  const peerConnection = React.useRef(null);
  const callTimerRef = React.useRef(null);

  React.useEffect(() => {
    if (isOpen) {
      initializeCall();
    } else {
      cleanupCall();
    }

    return () => {
      cleanupCall();
    };
  }, [isOpen, callType]);

  const initializeCall = async () => {
    try {
      setCallStatus('connecting');
      
      // Get user media
      const stream = await navigator.mediaDevices.getUserMedia({
        video: callType === 'video',
        audio: true
      });
      
      setLocalStream(stream);
      if (localVideoRef.current) {
        localVideoRef.current.srcObject = stream;
      }

      // Initialize peer connection
      const configuration = {
        iceServers: [
          { urls: 'stun:stun.l.google.com:19302' }
        ]
      };
      peerConnection.current = new RTCPeerConnection(configuration);
      
      // Add local stream to connection
      stream.getTracks().forEach(track => {
        peerConnection.current.addTrack(track, stream);
      });

      // Handle remote stream
      peerConnection.current.ontrack = (event) => {
        const remoteStream = event.streams[0];
        setRemoteStream(remoteStream);
        if (remoteVideoRef.current) {
          remoteVideoRef.current.srcObject = remoteStream;
        }
      };

      // Simulate connection success
      setTimeout(() => {
        setCallStatus('active');
        startCallTimer();
        
        setTimeout(() => {
          setRemoteStream(new MediaStream());
        }, 2000);
      }, 1500);

    } catch (error) {
      console.error('Error initializing call:', error);
      alert('Failed to start call. Please check your camera and microphone permissions.');
      onClose();
    }
  };

  const startCallTimer = () => {
    callTimerRef.current = setInterval(() => {
      setCallDuration(prev => prev + 1);
    }, 1000);
  };

  const cleanupCall = () => {
    if (localStream) {
      localStream.getTracks().forEach(track => track.stop());
    }
    if (peerConnection.current) {
      peerConnection.current.close();
    }
    if (callTimerRef.current) {
      clearInterval(callTimerRef.current);
    }
  };

  const handleEndCall = () => {
    setCallStatus('ended');
    cleanupCall();
    if (onCallEnd) {
      onCallEnd({
        duration: callDuration,
        consultationId: consultation?.id,
        type: callType
      });
    }
    setTimeout(() => {
      onClose();
    }, 2000);
  };

  const toggleVideo = () => {
    if (localStream) {
      const videoTrack = localStream.getVideoTracks()[0];
      if (videoTrack) {
        videoTrack.enabled = !videoTrack.enabled;
      }
    }
  };

  const toggleAudio = () => {
    if (localStream) {
      const audioTrack = localStream.getAudioTracks()[0];
      if (audioTrack) {
        audioTrack.enabled = !audioTrack.enabled;
      }
    }
  };

  const switchToAudio = () => {
    if (callStatus === 'active') {
      if (localStream) {
        const videoTrack = localStream.getVideoTracks()[0];
        if (videoTrack) {
          videoTrack.stop();
        }
      }
    }
  };

  const formatDuration = (seconds) => {
    const mins = Math.floor(seconds / 60);
    const secs = seconds % 60;
    return `${mins.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`;
  };

  if (!isOpen) return null;

  return (
    <div className="video-call-modal-overlay">
      <div className="video-call-container">
        {/* Remote Video Stream */}
        <div className="remote-video-container">
          {remoteStream ? (
            <video
              ref={remoteVideoRef}
              autoPlay
              playsInline
              className="remote-video"
              muted={false}
            />
          ) : (
            <div className="remote-video-placeholder">
              <div className="placeholder-avatar">
                {userType === 'elderly' ? '👨‍⚕️' : '👵'}
              </div>
              <p>{callStatus === 'connecting' ? 'Connecting...' : 'Waiting for participant...'}</p>
            </div>
          )}
        </div>

        {/* Local Video Stream */}
        {callType === 'video' && localStream && (
          <div className="local-video-container">
            <video
              ref={localVideoRef}
              autoPlay
              playsInline
              className="local-video"
              muted
            />
          </div>
        )}

        {/* Call Info Bar */}
        <div className="call-info-bar">
          <div className="call-info-left">
            <span className="call-type-badge">
              {callType === 'video' ? '📹 Video Call' : '📞 Audio Call'}
            </span>
            <span className="call-duration">
              {callStatus === 'active' ? formatDuration(callDuration) : '00:00'}
            </span>
          </div>
          <div className="call-info-right">
            <span className="call-status">{callStatus.toUpperCase()}</span>
          </div>
        </div>

        {/* Call Controls */}
        <div className="call-controls">
          {/* Audio Toggle */}
          <button
            className="control-btn audio-toggle"
            onClick={toggleAudio}
            title="Toggle Microphone"
          >
            🎤
          </button>

          {/* Video Toggle - Only in video calls */}
          {callType === 'video' && (
            <button
              className="control-btn video-toggle"
              onClick={toggleVideo}
              title="Toggle Camera"
            >
              📹
            </button>
          )}

          {/* Switch to Audio - Only in video calls */}
          {callType === 'video' && (
            <button
              className="control-btn switch-audio"
              onClick={switchToAudio}
              title="Switch to Audio Only"
            >
              📞
            </button>
          )}

          {/* End Call Button */}
          <button
            className="control-btn end-call"
            onClick={handleEndCall}
            title="End Call"
          >
            📞
          </button>
        </div>

        {/* Participant Info */}
        <div className="participant-info">
          <h3>
            {userType === 'elderly' 
              ? `Call with Caregiver` 
              : `Call with ${consultation?.elderlyName || 'Elderly'}`}
          </h3>
          <p>Consultation: {consultation?.reason || 'General Checkup'}</p>
        </div>
      </div>
    </div>
  );
};

export default ConsultationHistoryPage;