import React, { useEffect, useState } from "react";
import { database } from "../firebaseConfig";
import { ref, onValue, off, set, push, update, get, query, orderByChild, equalTo } from "firebase/database";
import './consultationPageCaregiver.css';

// CORRECTED: Use _com instead of _dot_com for email normalization
const normalizeEmailForFirebase = (email) => {
  if (!email) return '';
  return email
    .toLowerCase()
    .trim()
    .replace(/\./g, '_')
    .replace(/@/g, '_')
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

// Enhanced function to fetch elderly data using identifier (email or UID)
const fetchElderlyData = async (elderlyIdentifier) => {
  try {
    let elderlyRef;
    
    // Check if identifier is an email (contains @)
    if (elderlyIdentifier.includes('@')) {
      const key = normalizeEmailForFirebase(elderlyIdentifier);
      elderlyRef = ref(database, `Account/${key}`);
    } else {
      // Identifier is likely a UID, search through all accounts
      elderlyRef = ref(database, 'Account');
    }
    
    const snapshot = await get(elderlyRef);
    
    if (!snapshot.exists()) {
      console.error(`Elderly not found in Firebase with identifier: ${elderlyIdentifier}`);
      throw new Error('Elderly data not found in database');
    }

    let elderly;
    
    if (elderlyIdentifier.includes('@')) {
      // Direct lookup by email key
      elderly = snapshot.val();
    } else {
      // Search for UID in all accounts
      const allAccounts = snapshot.val();
      elderly = Object.values(allAccounts).find(account => 
        account.uid === elderlyIdentifier || 
        account.email === elderlyIdentifier
      );
      
      if (!elderly) {
        throw new Error('Elderly user not found with the provided identifier');
      }
    }
    
    return {
      id: elderlyIdentifier.includes('@') ? normalizeEmailForFirebase(elderlyIdentifier) : elderlyIdentifier,
      identifier: elderlyIdentifier,
      name: `${elderly.firstname || ''} ${elderly.lastname || ''}`.trim() || 'Unknown Elderly',
      email: elderly.email || elderlyIdentifier,
      uid: elderly.uid || elderlyIdentifier,
    };
  } catch (error) {
    console.error('Error fetching elderly data:', error);
    throw new Error(`Failed to fetch elderly data: ${error.message}`);
  }
};

// Get all elderly identifiers from caregiver's data (supports multiple field names)
const getAllElderlyIdentifiersFromCaregiver = (caregiverData) => {
  const elderlyIdentifiers = [];
  
  // Check all possible field names for elderly connections
  const possibleFields = [
    'elderlyIds',        // Array of emails/UIDs
    'elderlyId',         // Single email/UID
    'linkedElderUids',   // Array of UIDs
    'linkedElders',      // Array of UIDs
    'uidOfElder'         // Single UID
  ];
  
  possibleFields.forEach(field => {
    if (caregiverData[field]) {
      if (Array.isArray(caregiverData[field])) {
        // Handle array fields
        caregiverData[field].forEach(id => {
          if (id && !elderlyIdentifiers.includes(id)) {
            elderlyIdentifiers.push(id);
          }
        });
      } else if (typeof caregiverData[field] === 'string' && caregiverData[field].trim()) {
        // Handle single string fields
        if (!elderlyIdentifiers.includes(caregiverData[field])) {
          elderlyIdentifiers.push(caregiverData[field]);
        }
      }
    }
  });
  
  console.log('Found elderly identifiers:', elderlyIdentifiers);
  return elderlyIdentifiers;
};

const ConsultationHistoryPageCaregiver = () => {
  const [consultations, setConsultations] = useState([]);
  const [loading, setLoading] = useState(true);
  const [userName, setUserName] = useState("Caregiver");
  const [uid, setUid] = useState("");
  const [userEmail, setUserEmail] = useState("");
  const [elderlies, setElderlies] = useState([]);
  const [showCallModal, setShowCallModal] = useState(false);
  const [showCallInitiationModal, setShowCallInitiationModal] = useState(false);
  const [selectedConsultation, setSelectedConsultation] = useState(null);
  const [callType, setCallType] = useState('video');
  const [pendingInvitations, setPendingInvitations] = useState([]);
  const [showInvitationsModal, setShowInvitationsModal] = useState(false);
  const [invitationLoading, setInvitationLoading] = useState(false);
  
  useEffect(() => {
    const storedName = localStorage.getItem("userName") || "Caregiver";
    const storedUid = localStorage.getItem("uid");
    const storedEmail = localStorage.getItem("userEmail") || localStorage.getItem("loggedInEmail");
    
    setUserName(storedName);
    setUid(storedUid);
    setUserEmail(storedEmail);

    console.log("Loading consultations for caregiver:", { storedEmail, storedUid, storedName });

    // Fetch consultation history from Firebase
    const consultationsRef = ref(database, 'consultations');
    const accountsRef = ref(database, 'Account');
    const invitationsRef = ref(database, 'consultationInvitations');
    
    const unsubscribeConsultations = onValue(consultationsRef, (snapshot) => {
      const data = snapshot.val();
      console.log("Raw consultations data from Firebase:", data);
      
      if (data) {
        const consultationsList = Object.entries(data)
          .map(([id, consultation]) => ({
            id,
            ...consultation,
          }))
          .filter(consultation => {
            // NEW: Enhanced filtering logic that checks multiple conditions
            console.log(`Checking consultation ${consultation.id} for caregiver ${storedEmail}`);
            
            // 1. Check if consultation has invitedCaregivers with current caregiver
            if (consultation.invitedCaregivers) {
              const isInvited = Object.values(consultation.invitedCaregivers).some(invite => {
                const isMatch = invite.caregiverEmail === storedEmail || 
                               invite.originalEmail === storedEmail;
                if (isMatch) {
                  console.log(`✅ Found invited caregiver match in consultation ${consultation.id}`);
                }
                return isMatch;
              });
              if (isInvited) return true;
            }
            
            // 2. Check if consultation elderly is assigned to this caregiver
            if (consultation.elderlyId || consultation.patientUid) {
              const elderlyId = consultation.elderlyId || consultation.patientUid;
              // We'll check this after we have the elderlies data
              console.log(`Consultation ${consultation.id} has elderly: ${elderlyId}`);
            }
            
            // 3. Check if caregiver email appears in any caregiver-related fields
            const hasCaregiverReference = consultation.caregiverEmail === storedEmail;
            
            const shouldInclude = hasCaregiverReference;
            
            console.log(`Consultation ${consultation.id} - Include: ${shouldInclude}`);
            
            return shouldInclude;
          });
        
        console.log("Initial filtered consultations:", consultationsList.length, consultationsList);
        
        // Now enhance consultations with elderly data and check assignments
        const enhanceConsultations = async () => {
          const enhancedConsultations = [];
          
          for (const consultation of consultationsList) {
            try {
              let elderlyData = null;
              
              // Get elderly data for this consultation
              if (consultation.elderlyId) {
                if (Array.isArray(consultation.elderlyId)) {
                  // Multiple elderly IDs - take the first one
                  elderlyData = await fetchElderlyData(consultation.elderlyId[0]);
                } else {
                  // Single elderly ID
                  elderlyData = await fetchElderlyData(consultation.elderlyId);
                }
              } else if (consultation.patientUid) {
                elderlyData = await fetchElderlyData(consultation.patientUid);
              } else if (consultation.elderlyEmail) {
                elderlyData = await fetchElderlyData(consultation.elderlyEmail);
              }
              
              enhancedConsultations.push({
                ...consultation,
                elderlyName: elderlyData?.name || 'Unknown Elderly',
                elderlyEmail: elderlyData?.email || 'Unknown Email',
                displayDate: consultation.appointmentDate || consultation.requestedAt,
                createdDate: consultation.createdAt || consultation.requestedAt
              });
            } catch (error) {
              console.error(`Error enhancing consultation ${consultation.id}:`, error);
              // Still include the consultation but with default values
              enhancedConsultations.push({
                ...consultation,
                elderlyName: 'Unknown Elderly',
                elderlyEmail: 'Unknown Email',
                displayDate: consultation.appointmentDate || consultation.requestedAt,
                createdDate: consultation.createdAt || consultation.requestedAt
              });
            }
          }
          
          // Sort by date
          enhancedConsultations.sort((a, b) => {
            const dateA = a.displayDate ? new Date(a.displayDate) : new Date(0);
            const dateB = b.displayDate ? new Date(b.displayDate) : new Date(0);
            return dateB - dateA;
          });
          
          console.log("Final enhanced consultations:", enhancedConsultations);
          setConsultations(enhancedConsultations);
          setLoading(false);
        };
        
        enhanceConsultations();
      } else {
        console.log("No consultations data found");
        setConsultations([]);
        setLoading(false);
      }
    }, (error) => {
      console.error("Error loading consultation history:", error);
      setLoading(false);
    });

    // Fetch accounts to get elderlies assigned to this caregiver
    const unsubscribeAccounts = onValue(accountsRef, async (snapshot) => {
      const accounts = snapshot.val();
      if (accounts) {
        const elderliesList = await getElderliesForCaregiver(storedEmail, accounts);
        setElderlies(elderliesList);
        
        // After we have elderlies, we can also filter consultations by assigned elderlies
        const consultationsRef = ref(database, 'consultations');
        const consultationsSnapshot = await get(consultationsRef);
        const consultationsData = consultationsSnapshot.val();
        
        if (consultationsData) {
          const elderlyConsultations = Object.entries(consultationsData)
            .map(([id, consultation]) => ({
              id,
              ...consultation,
            }))
            .filter(consultation => {
              // Check if consultation's elderly is assigned to this caregiver
              const consultationElderlyId = consultation.elderlyId || consultation.patientUid;
              if (consultationElderlyId) {
                const isAssignedElderly = elderliesList.some(elderly => 
                  elderly.uid === consultationElderlyId || 
                  elderly.email === consultationElderlyId
                );
                return isAssignedElderly;
              }
              return false;
            })
            .map(consultation => {
              // Find the elderly data for this consultation
              const consultationElderlyId = consultation.elderlyId || consultation.patientUid;
              const elderly = elderliesList.find(elderly => 
                elderly.uid === consultationElderlyId || 
                elderly.email === consultationElderlyId
              );
              
              return {
                ...consultation,
                elderlyName: elderly?.name || 'Unknown Elderly',
                elderlyEmail: elderly?.email || 'Unknown Email',
                displayDate: consultation.appointmentDate || consultation.requestedAt,
                createdDate: consultation.createdAt || consultation.requestedAt,
                isFromAssignedElderly: true
              };
            });
          
          console.log("Consultations from assigned elderlies:", elderlyConsultations);
          
          // Merge with existing consultations, avoiding duplicates
          setConsultations(prev => {
            const existingIds = new Set(prev.map(c => c.id));
            const newConsultations = elderlyConsultations.filter(c => !existingIds.has(c.id));
            return [...prev, ...newConsultations].sort((a, b) => {
              const dateA = a.displayDate ? new Date(a.displayDate) : new Date(0);
              const dateB = b.displayDate ? new Date(b.displayDate) : new Date(0);
              return dateB - dateA;
            });
          });
        }
      }
    });

    // Fetch pending invitations
    const unsubscribeInvitations = onValue(invitationsRef, (snapshot) => {
      const data = snapshot.val();
      if (data) {
        const invitationsList = Object.entries(data)
          .map(([id, invitation]) => ({
            id,
            ...invitation,
          }))
          .filter(invitation => 
            invitation.caregiverEmail === storedEmail && 
            invitation.status === 'pending'
          );
        console.log("Pending invitations:", invitationsList);
        setPendingInvitations(invitationsList);
      } else {
        setPendingInvitations([]);
      }
    });

    return () => {
      off(consultationsRef, 'value', unsubscribeConsultations);
      off(accountsRef, 'value', unsubscribeAccounts);
      off(invitationsRef, 'value', unsubscribeInvitations);
    };
  }, []);

  // Get elderlies for caregiver - FIXED VERSION
  const getElderliesForCaregiver = async (caregiverEmail, accounts) => {
    if (!accounts || !caregiverEmail) return [];
    
    const normalizedEmail = normalizeEmailForComparison(caregiverEmail);
    const caregiverAccount = Object.values(accounts).find(acc => 
      acc.email && normalizeEmailForComparison(acc.email) === normalizedEmail
    );

    if (!caregiverAccount) {
      console.log('Caregiver account not found:', caregiverEmail);
      return [];
    }

    const elderlies = [];
    
    // Get all elderly identifiers from caregiver data
    const elderlyIdentifiers = getAllElderlyIdentifiersFromCaregiver(caregiverAccount);
    
    console.log('Processing elderly identifiers for caregiver:', elderlyIdentifiers);

    // Fetch data for each elderly identifier
    for (const elderlyIdentifier of elderlyIdentifiers) {
      try {
        const elderlyData = await fetchElderlyData(elderlyIdentifier);
        
        elderlies.push({
          email: elderlyData.email,
          uid: elderlyData.uid,
          name: elderlyData.name,
          userType: 'elderly'
        });
        
        console.log(`Added elderly: ${elderlyData.name} (${elderlyData.email})`);
      } catch (error) {
        console.error(`Error fetching elderly data for ${elderlyIdentifier}:`, error);
        // Continue with next elderly even if one fails
      }
    }

    console.log('Final elderlies list for caregiver:', elderlies);
    return elderlies;
  };

  // Handle invitation response
  const handleInvitationResponse = async (invitationId, consultationId, response) => {
    setInvitationLoading(true);
    try {
      // Update invitation status
      const invitationRef = ref(database, `consultationInvitations/${invitationId}`);
      await update(invitationRef, {
        status: response,
        respondedAt: new Date().toISOString()
      });

      // Update consultation record if accepted
      if (response === 'accepted') {
        const consultationRef = ref(database, `consultations/${consultationId}`);
        const normalizedEmail = normalizeEmailForFirebase(userEmail);
        
        const updates = {
          [`invitedCaregivers/${normalizedEmail}/status`]: 'accepted',
          [`invitedCaregivers/${normalizedEmail}/respondedAt`]: new Date().toISOString(),
          lastUpdated: new Date().toISOString()
        };
        
        await update(consultationRef, updates);
      }

      alert(`Invitation ${response} successfully!`);
    } catch (error) {
      console.error('Error responding to invitation:', error);
      alert('Failed to respond to invitation. Please try again.');
    } finally {
      setInvitationLoading(false);
    }
  };

  // Mark caregiver as attended for a consultation
  const markAsAttended = async (consultationId) => {
    setInvitationLoading(true);
    try {
      const consultationRef = ref(database, `consultations/${consultationId}`);
      const normalizedEmail = normalizeEmailForFirebase(userEmail);
      
      const updates = {
        [`attendedCaregivers/${normalizedEmail}`]: {
          attendedAt: new Date().toISOString(),
          caregiverEmail: userEmail,
          caregiverName: userName
        },
        includeCaregiver: true,
        lastUpdated: new Date().toISOString()
      };
      
      await update(consultationRef, updates);
      alert('Marked as attended successfully!');
    } catch (error) {
      console.error('Error marking as attended:', error);
      alert('Failed to mark as attended. Please try again.');
    } finally {
      setInvitationLoading(false);
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
        caregiverEmail: userEmail,
        caregiverName: userName,
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

  // Get display date for consultation
  const getDisplayDate = (consultation) => {
    return consultation.appointmentDate || consultation.requestedAt || consultation.createdAt;
  };

  // Get created date for consultation
  const getCreatedDate = (consultation) => {
    return consultation.createdAt || consultation.requestedAt;
  };

  // Get invitation status for caregiver
  const getInvitationStatus = (consultation) => {
    const normalizedEmail = normalizeEmailForFirebase(userEmail);
    
    if (consultation.attendedCaregivers && consultation.attendedCaregivers[normalizedEmail]) {
      return 'attended';
    }
    
    if (consultation.invitedCaregivers && consultation.invitedCaregivers[normalizedEmail]) {
      const invitation = consultation.invitedCaregivers[normalizedEmail];
      return invitation.status || 'pending';
    }
    
    // NEW: Check if caregiver is in the invitedCaregivers by email
    if (consultation.invitedCaregivers) {
      const invitation = Object.values(consultation.invitedCaregivers).find(invite => 
        invite.caregiverEmail === userEmail || invite.originalEmail === userEmail
      );
      if (invitation) {
        return invitation.status || 'pending';
      }
    }
    
    return 'not_invited';
  };

  // Check if caregiver can join call
  const canJoinCall = (consultation) => {
    const invitationStatus = getInvitationStatus(consultation);
    const isActiveStatus = consultation.status !== 'Completed' && consultation.status !== 'Cancelled';
    return invitationStatus === 'accepted' && isActiveStatus;
  };

  // Check if caregiver can mark as attended
  const canMarkAttended = (consultation) => {
    const invitationStatus = getInvitationStatus(consultation);
    return invitationStatus === 'accepted' && 
           consultation.status === 'Completed' && 
           !consultation.attendedCaregivers?.[normalizeEmailForFirebase(userEmail)];
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
        <h1>GP Consultation History</h1>
        <div className="caregiver-header-info">
          <div className="elderly-count-badge">
            <span>👵 Assigned Elderlies: {elderlies.length}</span>
          </div>
          {pendingInvitations.length > 0 && (
            <button 
              className="invitations-badge-btn"
              onClick={() => setShowInvitationsModal(true)}
            >
              📨 Pending Invitations ({pendingInvitations.length})
            </button>
          )}
        </div>
      </div>

      <div className="consultation-content">
        {consultations.length === 0 ? (
          <div className="empty-state">
            <div className="empty-icon">📋</div>
            <h3>No consultation history found</h3>
            <p>Consultations you're invited to will appear here.</p>
            {elderlies.length === 0 && (
              <div className="warning-message">
                <p>⚠️ You are not assigned to any elderly accounts yet.</p>
                <p>Please use the "Link Elderly Account" feature to get assigned.</p>
              </div>
            )}
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
                onMarkAttended={markAsAttended}
                onStartCall={handleCallInitiation}
                invitationStatus={getInvitationStatus(consultation)}
                invitationLoading={invitationLoading}
                canJoinCall={canJoinCall(consultation)}
                canMarkAttended={canMarkAttended(consultation)}
                currentUserEmail={userEmail}
                currentUserName={userName}
              />
            ))}
          </div>
        )}
      </div>

      {/* Pending Invitations Modal */}
      {showInvitationsModal && (
        <div className="modal-overlay-fixed">
          <div className="modal-content invitations-modal">
            <div className="modal-header">
              <h3>Pending Consultation Invitations</h3>
              <button 
                className="close-btn"
                onClick={() => setShowInvitationsModal(false)}
              >
                ×
              </button>
            </div>
            
            <div className="modal-body">
              {pendingInvitations.length === 0 ? (
                <div className="no-invitations">
                  <div className="invitation-icon">✅</div>
                  <h4>No Pending Invitations</h4>
                  <p>All invitations have been responded to.</p>
                </div>
              ) : (
                <div className="invitations-list">
                  {pendingInvitations.map((invitation) => (
                    <div key={invitation.id} className="invitation-card">
                      <div className="invitation-header">
                        <h4>Consultation Invitation</h4>
                        <span className="invitation-status pending">Pending</span>
                      </div>
                      
                      <div className="invitation-details">
                        <div className="detail-row">
                          <span className="detail-label">From:</span>
                          <span className="detail-value">
                            {invitation.elderlyName} ({invitation.elderlyEmail})
                          </span>
                        </div>
                        <div className="detail-row">
                          <span className="detail-label">Consultation Date:</span>
                          <span className="detail-value">
                            {formatDate(invitation.consultationDate)}
                          </span>
                        </div>
                        <div className="detail-row">
                          <span className="detail-label">Reason:</span>
                          <span className="detail-value">{invitation.consultationReason}</span>
                        </div>
                        <div className="detail-row">
                          <span className="detail-label">Invited On:</span>
                          <span className="detail-value">
                            {formatDate(invitation.invitedAt)}
                          </span>
                        </div>
                      </div>

                      <div className="invitation-actions">
                        <button
                          className="btn-accept"
                          onClick={() => handleInvitationResponse(
                            invitation.id, 
                            invitation.consultationId, 
                            'accepted'
                          )}
                          disabled={invitationLoading}
                        >
                          ✅ Accept Invitation
                        </button>
                        <button
                          className="btn-decline"
                          onClick={() => handleInvitationResponse(
                            invitation.id, 
                            invitation.consultationId, 
                            'declined'
                          )}
                          disabled={invitationLoading}
                        >
                          ❌ Decline
                        </button>
                      </div>
                    </div>
                  ))}
                </div>
              )}
            </div>
            
            <div className="modal-actions">
              <button
                className="btn-secondary"
                onClick={() => setShowInvitationsModal(false)}
              >
                Close
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
        userType="caregiver"
        onCallEnd={handleCallEnd}
        callType={callType}
      />
    </div>
  );
};

const ConsultationCard = ({ 
  consultation, 
  formatDate, 
  getDisplayDate, 
  getCreatedDate, 
  onMarkAttended, 
  onStartCall,
  invitationStatus,
  invitationLoading,
  canJoinCall,
  canMarkAttended,
  currentUserEmail,
  currentUserName
}) => {
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
    if (caregiverData && caregiverData.caregiverEmail) {
      return caregiverData.caregiverEmail;
    }
    return normalizedKey
      .replace(/_dot_/g, '.')
      .replace(/_hash_/g, '#')
      .replace(/_dollar_/g, '$')
      .replace(/_slash_/g, '/')
      .replace(/_lbracket_/g, '[')
      .replace(/_rbracket_/g, ']');
  };

  const displayElderlyEmail = elderlyEmail || 'elderly@example.com';
  const displayElderlyName = elderlyName || 'Elderly User';

  const gpName = status === 'Completed' ? 'Dr. Smith' : 'N/A';
  const diagnosis = status === 'Completed' ? 'Mild seasonal allergy' : 'Awaiting Outcome';

  const handleViewDetails = () => {
    const detailMessage = `
Consultation Details:
Appointment Date: ${formatDate(displayDate)}
Status: ${status}
Reason: ${reason}

Elderly Information:
Email: ${displayElderlyEmail}
Name: ${displayElderlyName}

Your Invitation Status: ${invitationStatus}

${status === 'Completed' ? `GP: ${gpName}\nDiagnosis: ${diagnosis}` : 'Pending consultation'}
    `.trim();
    
    alert(detailMessage);
  };

  const hasInvitedCaregivers = Object.keys(invitedCaregivers).length > 0;
  const hasAttendedCaregivers = attendedCaregivers && Object.keys(attendedCaregivers).length > 0;

  return (
    <div className="consultation-card">
      <div className="consultation-header">
        <div className="consultation-date-info">
          <div className="consultation-date">
            <strong>Appointment:</strong> {formatDate(displayDate)}
          </div>
        </div>
        <div className="header-right">
          <StatusChip status={status} />
          <InvitationStatusChip status={invitationStatus} />
        </div>
      </div>

      <div className="consultation-divider"></div>

      <div className="consultation-details">
        <div className="elderly-info-section">
          <label>Elderly Patient:</label>
          <div className="elderly-details">
            <span className="elderly-name">{displayElderlyName}</span>
            <span className="elderly-email">({displayElderlyEmail})</span>
          </div>
        </div>

        <div className="symptoms-section">
          <label>Reason for Consultation:</label>
          <p className="symptoms-text">{reason}</p>
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

        {hasInvitedCaregivers && (
          <div className="invited-caregivers">
            <label>Invited Caregivers:</label>
            <div className="caregiver-list">
              {Object.entries(invitedCaregivers).map(([normalizedKey, data]) => {
                const originalEmail = getOriginalEmail(normalizedKey, data);
                const isCurrentUser = originalEmail === currentUserEmail;
                return (
                  <div key={normalizedKey} className={`caregiver-tag ${isCurrentUser ? 'current-user' : ''} ${data.status === 'attended' ? 'attended' : data.status}`}>
                    {originalEmail} 
                    {isCurrentUser && <span className="you-badge">(You)</span>}
                    <span className="caregiver-status">({data.status || 'pending'})</span>
                    {data.status === 'attended' && <span className="attended-badge">✓ Attended</span>}
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
        {canJoinCall && (
          <button 
            className="start-call-btn"
            onClick={() => onStartCall(consultation)}
          >
            📞 Join Call
          </button>
        )}
        
        {canMarkAttended && (
          <button 
            className="mark-attended-btn"
            onClick={() => onMarkAttended(id)}
            disabled={invitationLoading}
          >
            {invitationLoading ? 'Updating...' : 'Mark as Attended'}
          </button>
        )}

        {invitationStatus === 'attended' && (
          <div className="attended-confirmation">
            <span className="attended-check">✅</span>
            <span>You attended this consultation</span>
          </div>
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

const InvitationStatusChip = ({ status }) => {
  const getInvitationConfig = (status) => {
    switch (status) {
      case 'attended':
        return { color: '#22c55e', icon: '✓', label: 'Attended' };
      case 'accepted':
        return { color: '#3b82f6', icon: '✅', label: 'Accepted' };
      case 'pending':
        return { color: '#f59e0b', icon: '📨', label: 'Invited' };
      case 'declined':
        return { color: '#ef4444', icon: '❌', label: 'Declined' };
      default:
        return { color: '#6b7280', icon: 'ℹ', label: 'Not Invited' };
    }
  };

  const config = getInvitationConfig(status);

  return (
    <div 
      className="invitation-status-chip"
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
      <div className="modal-content call-initiation-modal" style={{maxWidth: "800px"}}>
        <div className="modal-header">
          <h3>Join Consultation Call</h3>
          <button className="close-btn" onClick={onClose}>×</button>
        </div>
        
        <div className="modal-body">
          <div className="consultation-info">
            <h4>Consultation Details</h4>
            <div className="consultation-detail-item">
              <span className="detail-label">Elderly:</span>
              <span className="detail-value">{consultation?.elderlyName || 'Elderly User'}</span>
            </div>
            <div className="consultation-detail-item">
              <span className="detail-label">Reason:</span>
              <span className="detail-value">{consultation?.reason || 'General Checkup'}</span>
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
            Join {callType === 'video' ? 'Video' : 'Voice'} Call
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
      
      const stream = await navigator.mediaDevices.getUserMedia({
        video: callType === 'video',
        audio: true
      });
      
      setLocalStream(stream);
      if (localVideoRef.current) {
        localVideoRef.current.srcObject = stream;
      }

      const configuration = {
        iceServers: [
          { urls: 'stun:stun.l.google.com:19302' }
        ]
      };
      peerConnection.current = new RTCPeerConnection(configuration);
      
      stream.getTracks().forEach(track => {
        peerConnection.current.addTrack(track, stream);
      });

      peerConnection.current.ontrack = (event) => {
        const remoteStream = event.streams[0];
        setRemoteStream(remoteStream);
        if (remoteVideoRef.current) {
          remoteVideoRef.current.srcObject = remoteStream;
        }
      };

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
                {userType === 'caregiver' ? '👵' : '👨‍⚕️'}
              </div>
              <p>{callStatus === 'connecting' ? 'Connecting...' : 'Waiting for participant...'}</p>
            </div>
          )}
        </div>

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

        <div className="call-controls">
          <button
            className="control-btn audio-toggle"
            onClick={toggleAudio}
            title="Toggle Microphone"
          >
            🎤
          </button>

          {callType === 'video' && (
            <button
              className="control-btn video-toggle"
              onClick={toggleVideo}
              title="Toggle Camera"
            >
              📹
            </button>
          )}

          {callType === 'video' && (
            <button
              className="control-btn switch-audio"
              onClick={switchToAudio}
              title="Switch to Audio Only"
            >
              📞
            </button>
          )}

          <button
            className="control-btn end-call"
            onClick={handleEndCall}
            title="End Call"
          >
            📞
          </button>
        </div>

        <div className="participant-info">
          <h3>
            {userType === 'caregiver' 
              ? `Call with ${consultation?.elderlyName || 'Elderly'}` 
              : `Call with Caregiver`}
          </h3>
          <p>Consultation: {consultation?.reason || 'General Checkup'}</p>
        </div>
      </div>
    </div>
  );
};

export default ConsultationHistoryPageCaregiver;