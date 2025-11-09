import React, { useEffect, useState } from "react";
import { database } from "../firebaseConfig";
import { ref, get } from "firebase/database";
import ConsultationHistoryPage from "./consulationPage";
import AppointmentBookingPage from "./appointmentBookingPage";
import MedicineAndProductsPage from "./medicineandproducts";
import DoctorsAppointmentPage from "./doctorsAppointmentPage";
import './medicationAndDoctorPage.css';
import { SubscriptionController } from "../controller/subscriptionController";
import FloatingAssistant from "../components/floatingassistantChat";

const currentUser = localStorage.getItem("loggedInEmail");

const MedicationAndDoctorPage = () => {
  const [activeSection, setActiveSection] = useState('wallet');
  const [subscriptionController, setSubscriptionController] = useState(null);
  const [walletBalance, setWalletBalance] = useState(0);
  const [topUpAmount, setTopUpAmount] = useState('');
  const [paymentMethod, setPaymentMethod] = useState('credit');
  const [cardNumber, setCardNumber] = useState('');
  const [expiryDate, setExpiryDate] = useState('');
  const [cvv, setCvv] = useState('');
  const [userName, setUserName] = useState("User");
  const [userType, setUserType] = useState("");
  const [uid, setUid] = useState("");
  const [emailKey, setEmailKey] = useState("");
  const [loading, setLoading] = useState(true);
  const [medicalRecords, setMedicalRecords] = useState([]);
  const [uploading, setUploading] = useState(false);
  const [processingPayment, setProcessingPayment] = useState(false);
  const [transactionHistory, setTransactionHistory] = useState([]);
  const [savedCardDetails, setSavedCardDetails] = useState(null);

  // Initialize subscription controller and fetch data
  useEffect(() => {
    const initializeSubscription = async () => {
      const loggedInEmail = localStorage.getItem("loggedInEmail");
      if (!loggedInEmail) {
        setLoading(false);
        return;
      }

      const controller = new SubscriptionController(loggedInEmail);
      setSubscriptionController(controller);

      // Fetch user data
      const storedName = localStorage.getItem("userName");
      const storedUid = localStorage.getItem("uid");
      const storedUserType = localStorage.getItem("userType");
      
      if (storedName && storedUid && storedUserType) {
        setUserName(storedName);
        setUid(storedUid);
        setUserType(storedUserType);
        setEmailKey(loggedInEmail.replace(/\./g, "_"));
      } else {
        await fetchUserData(loggedInEmail);
      }

      // Fetch subscription data
      const subscription = await controller.fetchSubscription();
      if (subscription) {
        setWalletBalance(subscription.walletBalance);
        setTransactionHistory(controller.getTransactionHistory());
        
        // Load saved card details from subscription
        if (subscription.cardNumber && subscription.cardNumber.length > 4) {
          setSavedCardDetails({
            cardNumber: subscription.cardNumber,
            expiryDate: subscription.expiryDate,
            paymentMethod: subscription.paymentMethod || 'credit'
          });
          
          // Set the form fields with saved card (masked for security)
          setPaymentMethod(subscription.paymentMethod || 'credit');
          setCardNumber(`**** **** **** ${subscription.cardNumber.slice(-4)}`);
        }
      } else {
        // Create default subscription if none exists
        await controller.addSubscription({
          paymentMethod: 'credit',
          subscriptionPlan: 0
        });
        setWalletBalance(100.00); // Default balance
      }

      setLoading(false);
    };

    initializeSubscription();
  }, []);

  const fetchUserData = async (loggedInEmail) => {
    const emailKey = loggedInEmail.replace(/\./g, "_");
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
    }
  };

  const handleTopUp = async (e) => {
    e.preventDefault();
    if (!subscriptionController || !topUpAmount || parseFloat(topUpAmount) <= 0) {
      alert("Please enter a valid amount");
      return;
    }

    setProcessingPayment(true);

    // Use saved card details if user didn't enter new ones
    let cardDetailsToUse = {};
    
    if (savedCardDetails && cardNumber.startsWith('****')) {
      // User is using saved card, use the actual saved details
      cardDetailsToUse = {
        cardNumber: savedCardDetails.cardNumber,
        expiryDate: savedCardDetails.expiryDate,
        cvv: cvv // Still need CVV for security
      };
    } else {
      // User entered new card details
      cardDetailsToUse = {
        cardNumber: cardNumber,
        expiryDate: expiryDate,
        cvv: cvv
      };
    }

    const success = await subscriptionController.topUpWallet(
      parseFloat(topUpAmount),
      paymentMethod,
      cardDetailsToUse
    );

    if (success) {
      setWalletBalance(subscriptionController.getWalletBalance());
      setTransactionHistory(subscriptionController.getTransactionHistory());
      
      // Save card details for next time (only if it's a new card)
      if (!savedCardDetails || !cardNumber.startsWith('****')) {
        const newSavedDetails = {
          cardNumber: cardDetailsToUse.cardNumber,
          expiryDate: cardDetailsToUse.expiryDate,
          paymentMethod: paymentMethod
        };
        setSavedCardDetails(newSavedDetails);
        
        // Update subscription with new card details
        await updateSubscriptionWithCardDetails(newSavedDetails);
        
        // Mask the card number in the form
        setCardNumber(`**** **** **** ${cardDetailsToUse.cardNumber.slice(-4)}`);
      }
      
      setTopUpAmount('');
      setCvv('');
      alert(`Successfully added $${topUpAmount} to your wallet!`);
    } else {
      alert(`Top-up failed: ${subscriptionController.getErrorMessage()}`);
    }

    setProcessingPayment(false);
  };

  // Update subscription with card details for future use
  const updateSubscriptionWithCardDetails = async (cardDetails) => {
    if (!subscriptionController || !subscriptionController.subscription) return;
    
    try {
      subscriptionController.subscription.cardNumber = cardDetails.cardNumber;
      subscriptionController.subscription.expiryDate = cardDetails.expiryDate;
      subscriptionController.subscription.paymentMethod = cardDetails.paymentMethod;
      
      await subscriptionController.updateSubscriptionInDB();
    } catch (error) {
      console.error("Failed to save card details:", error);
    }
  };

  // Handle card number change - detect if user wants to use a new card
  const handleCardNumberChange = (e) => {
    const value = e.target.value;
    setCardNumber(value);
    
    // If user starts typing and we have saved card, clear the saved details
    if (savedCardDetails && !value.startsWith('****')) {
      setSavedCardDetails(null);
    }
  };

  // Clear saved card and reset form for new card entry
  const handleUseNewCard = () => {
    setSavedCardDetails(null);
    setCardNumber('');
    setExpiryDate('');
    setCvv('');
    setPaymentMethod('credit');
  };

  const handlePayNow = async (amount, description, recipient) => {
    if (!subscriptionController) {
      alert("Payment system not initialized");
      return false;
    }

    const success = await subscriptionController.makePayment(
      amount,
      description,
      recipient
    );

    if (success) {
      setWalletBalance(subscriptionController.getWalletBalance());
      setTransactionHistory(subscriptionController.getTransactionHistory());
      return true;
    } else {
      alert(`Payment failed: ${subscriptionController.getErrorMessage()}`);
      return false;
    }
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

  // Get current date in required format
  const getCurrentDate = () => {
    const now = new Date();
    const options = { day: 'numeric', month: 'short', year: 'numeric' };
    return now.toLocaleDateString('en-GB', options);
  };

  // Get current month and year
  const getCurrentMonthYear = () => {
    const now = new Date();
    return now.toLocaleString('default', { month: 'long', year: 'numeric' });
  };

  // Generate current month calendar with proper week alignment
  const generateCurrentMonthCalendar = () => {
    const now = new Date();
    const year = now.getFullYear();
    const month = now.getMonth();
    
    const firstDay = new Date(year, month, 1);
    const lastDay = new Date(year, month + 1, 0);
    const daysInMonth = lastDay.getDate();
    
    let startingDay = firstDay.getDay() - 1;
    if (startingDay < 0) startingDay = 6;
    
    const days = [];
    
    for (let i = 0; i < startingDay; i++) {
      days.push(null);
    }
    
    for (let i = 1; i <= daysInMonth; i++) {
      days.push(i);
    }
    
    return days;
  };

  const calendarDays = generateCurrentMonthCalendar();
  const currentDate = new Date().getDate();
  const currentMonthYear = getCurrentMonthYear();
  const currentDateFormatted = getCurrentDate();

  // Medical Records Upload Handler
  const handleFileUpload = (event) => {
    const files = Array.from(event.target.files);
    setUploading(true);
    
    setTimeout(() => {
      const newRecords = files.map(file => ({
        id: Math.random().toString(36).substr(2, 9),
        name: file.name,
        type: file.type,
        size: file.size,
        uploadDate: new Date().toLocaleDateString(),
        url: URL.createObjectURL(file)
      }));
      
      setMedicalRecords(prev => [...prev, ...newRecords]);
      setUploading(false);
      alert(`Successfully uploaded ${files.length} file(s)`);
    }, 1500);
  };

  // Remove medical record
  const removeMedicalRecord = (id) => {
    setMedicalRecords(prev => prev.filter(record => record.id !== id));
  };

  if (loading) {
    return (
      <div className="loading-container">
        <div className="loading-spinner"></div>
        <p>Loading...</p>
      </div>
    );
  }

  return (
    <div className="medication-doctor-page">
      {/* Top Bar */}
      <div className="top-bar">
        <div className="top-bar-content">
          <div className="logo-section">
            <div className="app-logo">
              <span className="logo-icon">💙</span>
              <span className="logo-text">ElderlyCareConnect</span>
            </div>
          </div>
          
          <div className="user-profile-section">
            <div className="user-info">
              <div className="user-details">
                <h3 className="user-name">{userName}</h3>
                <p className="user-role">{userType || "Elderly User"}</p>
              </div>
              {getProfileImage()}
            </div>
          </div>
        </div>
      </div>

      <div className="page-container">
        <div className="sidebar">
          <div className="sidebar-header">
            <h2>Health Portal</h2>
            <div className="sidebar-subtitle">Your Health Companion</div>
          </div>
          <ul className="sidebar-nav">
            <li 
              className={activeSection === 'wallet' ? 'active' : ''}
              onClick={() => setActiveSection('wallet')}
            >
              <span className="nav-text">My Wallet</span>
            </li>
            <li 
              className={activeSection === 'doctorsappointments' ? 'active' : ''}
              onClick={() => setActiveSection('doctorsappointments')}
            >
              <span className="nav-text">Doctor's Appointment</span>
            </li>
            <li 
              className={activeSection === 'appointments' ? 'active' : ''}
              onClick={() => setActiveSection('appointments')}
            >
              <span className="nav-text">Book Consultation</span>
            </li>
            
            <li 
              className={activeSection === 'consultation' ? 'active' : ''}
              onClick={() => setActiveSection('consultation')}
            >
              <span className="nav-text">Consultation History</span>
            </li>
            <li 
              className={activeSection === 'history' ? 'active' : ''}
              onClick={() => setActiveSection('history')}
            >
              <span className="nav-text">History and Records</span>
            </li>
            <li 
              className={activeSection === 'medication' ? 'active' : ''}
              onClick={() => setActiveSection('medication')}
            >
              <span className="nav-text">Health and Pharmacy</span>
            </li>
          </ul>

          {/* Floating AI Assistant */}
      {currentUser && <FloatingAssistant userEmail={currentUser} />}
      
          
          <div className="sidebar-footer">
            <div className="user-quick-info">
              {getProfileImage()}
              <div className="quick-details">
                <span className="quick-name">{userName.split(' ')[0]}</span>
                <span className="quick-status">Online</span>
              </div>
            </div>
          </div>
        </div>

        <div className="main-content">
          {activeSection === 'wallet' && (
            <div className="section-content">
              <h2>My Wallet</h2>
              
              {/* Wallet Balance */}
              <div className="wallet-balance">
                <h3>Current Balance</h3>
                <div className="balance-amount">${walletBalance.toFixed(2)}</div>
              </div>

              {/* Transaction History */}
              {transactionHistory && transactionHistory.length > 0 && (
                <div className="transaction-history">
                  <h3>Recent Transactions</h3>
                  <div className="transactions-list">
                    {transactionHistory.map((transaction, index) => {
                      // Add safety checks for transaction object
                      if (!transaction) return null;
                      
                      const transactionType = transaction.type || 'payment';
                      const amount = transaction.amount || 0;
                      const description = transaction.description || `Wallet ${transactionType}`;
                      const timestamp = transaction.timestamp || Date.now();
                      
                      return (
                        <div key={transaction.id || index} className="transaction-item">
                          <div className="transaction-details">
                            <span className={`transaction-type ${transactionType}`}>
                              {transactionType === 'topup' ? 'Top Up' : 'Payment'}
                            </span>
                            <span className="transaction-amount">
                              {transactionType === 'topup' ? '+' : '-'}${amount.toFixed(2)}
                            </span>
                          </div>
                          <div className="transaction-meta">
                            <span className="transaction-description">
                              {description}
                            </span>
                            <span className="transaction-date">
                              {new Date(timestamp).toLocaleDateString()}
                            </span>
                          </div>
                        </div>
                      );
                    })}
                  </div>
                </div>
              )}
              
              {/* Top Up Section */}
              <div className="top-up-section">
                <h3>Top Up Wallet</h3>
                
                {/* Saved Card Notice */}
                {savedCardDetails && (
                  <div className="saved-card-notice">
                    <div className="saved-card-info">
                      <span className="saved-card-label">Using saved card:</span>
                      <span className="saved-card-number">
                        **** **** **** {savedCardDetails.cardNumber.slice(-4)}
                      </span>
                      <span className="saved-card-expiry">
                        Expires: {savedCardDetails.expiryDate}
                      </span>
                    </div>
                    <button 
                      type="button" 
                      className="use-new-card-btn"
                      onClick={handleUseNewCard}
                    >
                      Use Different Card
                    </button>
                  </div>
                )}
                
                <form onSubmit={handleTopUp}>
                  <div className="form-group">
                    <label>Amount</label>
                    <input 
                      type="number" 
                      value={topUpAmount}
                      onChange={(e) => setTopUpAmount(e.target.value)}
                      placeholder="Enter amount"
                      min="1"
                      step="0.01"
                      required
                      disabled={processingPayment}
                    />
                  </div>
                  
                  {!savedCardDetails && (
                    <>
                      <div className="form-group">
                        <label>Payment Method</label>
                        <div className="payment-options">
                          <label className="payment-option">
                            <input 
                              type="radio" 
                              value="credit" 
                              checked={paymentMethod === 'credit'}
                              onChange={() => setPaymentMethod('credit')}
                              disabled={processingPayment}
                            />
                            Credit Card
                          </label>
                          <label className="payment-option">
                            <input 
                              type="radio" 
                              value="debit" 
                              checked={paymentMethod === 'debit'}
                              onChange={() => setPaymentMethod('debit')}
                              disabled={processingPayment}
                            />
                            Debit Card
                          </label>
                        </div>
                      </div>
                      
                      <div className="card-details">
                        <div className="form-group">
                          <label>Card Number</label>
                          <input 
                            type="text" 
                            value={cardNumber}
                            onChange={handleCardNumberChange}
                            placeholder="1234 5678 9012 3456"
                            required
                            disabled={processingPayment}
                          />
                        </div>
                        
                        <div className="form-row">
                          <div className="form-group">
                            <label>Expiry Date</label>
                            <input 
                              type="text" 
                              value={expiryDate}
                              onChange={(e) => setExpiryDate(e.target.value)}
                              placeholder="MM/YY"
                              required
                              disabled={processingPayment}
                            />
                          </div>
                          
                          <div className="form-group">
                            <label>CVV</label>
                            <input 
                              type="text" 
                              value={cvv}
                              onChange={(e) => setCvv(e.target.value)}
                              placeholder="123"
                              required
                              disabled={processingPayment}
                            />
                          </div>
                        </div>
                      </div>
                    </>
                  )}
                  
                  {savedCardDetails && (
                    <div className="form-group">
                      <label>CVV</label>
                      <input 
                        type="text" 
                        value={cvv}
                        onChange={(e) => setCvv(e.target.value)}
                        placeholder="Enter CVV"
                        required
                        disabled={processingPayment}
                      />
                      <small className="helper-text">
                        For security, please enter your CVV to confirm this transaction.
                      </small>
                    </div>
                  )}
                  
                  <button 
                    type="submit" 
                    className="pay-now-btn"
                    disabled={processingPayment}
                  >
                    {processingPayment ? 'Processing...' : 'Pay Now'}
                  </button>
                </form>
              </div>
            </div>
          )}

          {activeSection === 'appointments' && (
            <div className="section-content">
              <AppointmentBookingPage 
                userProfile={{ uid, displayName: userName, role: userType }} 
                onMakePayment={handlePayNow}
              />
            </div>
          )}

          {activeSection === 'doctorsappointments' && (
            <div className="section-content">
              <DoctorsAppointmentPage 
                userName={userName}
                userType={userType}
                onMakePayment={handlePayNow}
              />
            </div>
          )}

          {activeSection === 'consultation' && (
            <div className="section-content">
              <ConsultationHistoryPage />
            </div>
          )}

          {activeSection === 'history' && (
            <div className="section-content">
              <HistoryAndRecordsPage 
                medicalRecords={medicalRecords}
                handleFileUpload={handleFileUpload}
                removeMedicalRecord={removeMedicalRecord}
                uploading={uploading}
                currentDateFormatted={currentDateFormatted}
                currentMonthYear={currentMonthYear}
                calendarDays={calendarDays}
                currentDate={currentDate}
              />
            </div>
          )}

          {activeSection === 'medication' && (
            <div className="section-content">
              <MedicineAndProductsPage 
                onMakePayment={handlePayNow}
              />
            </div>
          )}
        </div>
      </div>
    </div>
  );
};

// History and Records Component (Combines Medical Records + Dashboard)
const HistoryAndRecordsPage = ({ 
  medicalRecords, 
  handleFileUpload, 
  removeMedicalRecord, 
  uploading,
  currentDateFormatted,
  currentMonthYear,
  calendarDays,
  currentDate
}) => {
  return (
    <div>
      <h2>History and Records</h2>
      
      {/* Medical Records Upload Section */}
      <div className="medical-records-section">
        <div className="upload-section">
          <h3>Upload Medical Records</h3>
          <div className="upload-area">
            <input 
              type="file" 
              id="medical-records"
              multiple 
              onChange={handleFileUpload}
              accept=".pdf,.jpg,.jpeg,.png,.doc,.docx"
              style={{ display: 'none' }}
            />
            <label htmlFor="medical-records" className="upload-label">
              <div className="upload-icon">📁</div>
              <p>Click to upload or drag and drop</p>
              <span>PDF, JPG, PNG, DOC up to 10MB</span>
            </label>
          </div>
          {uploading && (
            <div className="upload-progress">
              <div className="progress-bar">
                <div className="progress-fill"></div>
              </div>
              <p>Uploading files...</p>
            </div>
          )}
        </div>

        {/* Medical Records List */}
        {medicalRecords.length > 0 && (
          <div className="records-list">
            <h4>Your Medical Records</h4>
            <div className="records-grid">
              {medicalRecords.map(record => (
                <div key={record.id} className="record-card">
                  <div className="record-icon">
                    {record.type.includes('pdf') ? '📄' : 
                     record.type.includes('image') ? '🖼️' : '📝'}
                  </div>
                  <div className="record-info">
                    <h5>{record.name}</h5>
                    <p>Uploaded: {record.uploadDate}</p>
                    <p>Size: {(record.size / 1024 / 1024).toFixed(2)} MB</p>
                  </div>
                  <div className="record-actions">
                    <button 
                      className="view-btn"
                      onClick={() => window.open(record.url, '_blank')}
                    >
                      View
                    </button>
                    <button 
                      className="delete-btn"
                      onClick={() => removeMedicalRecord(record.id)}
                    >
                      Delete
                    </button>
                  </div>
                </div>
              ))}
            </div>
          </div>
        )}
      </div>

      {/* Dashboard Section */}
      <div className="dashboard-section">
        <div className="dashboard-header">
          <h3>Dashboard</h3>
        </div>
        
        <div className="health-overview">
          <div className="leading-head">
            <div className="health-stats">
              <div className="health-stat">
                <span className="stat-label">Healthy Heart</span>
              </div>
              <div className="health-stat">
                <span className="stat-label">Healthy Leg</span>
              </div>
              <div className="health-stat">
                <span className="stat-label">Bone</span>
              </div>
              <div className="health-stat date">
                <span className="stat-label">Date: {currentDateFormatted}</span>
              </div>
              <div className="health-stat">
                <span className="stat-label">Lungs</span>
              </div>
              <div className="health-stat date">
                <span className="stat-label">Date: {currentDateFormatted}</span>
              </div>
              <div className="health-stat">
                <span className="stat-label">Teeth</span>
              </div>
              <div className="health-stat date">
                <span className="stat-label">Date: {currentDateFormatted}</span>
              </div>
            </div>
            
            <div className="human-body-diagram">
              <div className="body-image-container">
                <img 
                  src="https://c02.purpledshub.com/uploads/sites/41/2018/07/How-many-organs-in-the-body-could-you-live-without-©-Getty-78bb986.jpg?w=1880&webp=1" 
                  alt="Human Body Organs"
                  className="human-body-image"
                  onError={(e) => {
                    e.target.style.display = 'none';
                    e.target.nextSibling.style.display = 'block';
                  }}
                />
                <div className="body-fallback">
                  <div className="body-outline">
                    <div className="body-head"></div>
                    <div className="body-torso">
                      <div className="organ heart" title="Heart"></div>
                      <div className="organ lungs" title="Lungs"></div>
                      <div className="organ stomach" title="Stomach"></div>
                    </div>
                    <div className="body-arms">
                      <div className="arm left-arm"></div>
                      <div className="arm right-arm"></div>
                    </div>
                    <div className="body-legs">
                      <div className="leg left-leg"></div>
                      <div className="leg right-leg"></div>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
        
        <div className="calendar-section">
          <div className="calendar-header">
            <h4>{currentMonthYear}</h4>
          </div>
          <div className="calendar-grid">
            <div className="week-days">
              <span>Mon</span>
              <span>Tue</span>
              <span>Wed</span>
              <span>Thu</span>
              <span>Fri</span>
              <span>Sat</span>
              <span>Sun</span>
            </div>
            <div className="calendar-dates">
              {calendarDays.map((day, index) => (
                <span 
                  key={index} 
                  className={day === currentDate ? 'current-date' : ''}
                >
                  {day || ''}
                </span>
              ))}
            </div>
          </div>
        </div>
        
        <div className="appointments-section">
          <div className="appointment-card">
            <div className="appointment-header">
              <h5>Dentist</h5>
            </div>
            <div className="appointment-time">09:00-11:00</div>
            <div className="appointment-doctor">Dr. Cameron Williamson</div>
          </div>
          
          <div className="appointment-card">
            <div className="appointment-header">
              <h5>Physiotherapy Appointment</h5>
            </div>
            <div className="appointment-time">11:00-12:00</div>
            <div className="appointment-doctor">Dr. Kevin Djones</div>
          </div>
        </div>
        
        <div className="upcoming-schedule">
          <h4>The Upcoming Schedule</h4>
          <div className="schedule-activities">
            <div className="activity-day">
              <strong>On Thursday</strong>
              <div className="activity-list">
                <div className="activity-item">
                  <span className="activity-title">Health checkup complete</span>
                  <span className="activity-time">11:00 AM</span>
                </div>
                <div className="activity-item">
                  <span className="activity-title">On Saturday</span>
                </div>
              </div>
            </div>
            
            {[...Array(5)].map((_, index) => (
              <div key={index} className="activity-day repeated">
                <strong>Activity</strong>
                <div className="activity-list">
                  <div className="activity-item">
                    <span className="activity-title">Health checkup complete</span>
                    <span className="activity-time">11:00 AM</span>
                  </div>
                  <div className="activity-item">
                    <span className="activity-title">On Saturday</span>
                  </div>
                </div>
              </div>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
};

export default MedicationAndDoctorPage;