import React, { useState, useEffect } from 'react';
import './additionalCaregiver.css';
import { AddCaregiverController } from '../controller/additionalCaregiverController';

const AdditionalCaregiverPage = ({ navigation }) => {
  const [searchEmail, setSearchEmail] = useState('');
  const [searching, setSearching] = useState(false);
  const [pageLoading, setPageLoading] = useState(true);
  const [elderlyInfo, setElderlyInfo] = useState(null);
  const [walletBalance, setWalletBalance] = useState(0);
  const [searchedCaregiver, setSearchedCaregiver] = useState(null);
  const [showConfirmModal, setShowConfirmModal] = useState(false);
  const [paymentMethod, setPaymentMethod] = useState('wallet');
  const [cardDetails, setCardDetails] = useState({
    cardNumber: '',
    expiryDate: '',
    cvv: '',
    cardName: ''
  });

  useEffect(() => {
    loadInitialData();
  }, []);

  const loadInitialData = async () => {
    try {
      const [elderlyResult, caregiversResult] = await Promise.all([
        AddCaregiverController.getElderlyInfo(),
        AddCaregiverController.getLinkedCaregivers()
      ]);

      if (elderlyResult.success) {
        setElderlyInfo(elderlyResult.data.elderly);
        setWalletBalance(elderlyResult.data.walletBalance);
      }
    } catch (error) {
      alert("Error: Failed to load data");
    } finally {
      setPageLoading(false);
    }
  };

  const handleSearchCaregiver = async () => {
    if (!searchEmail.trim()) {
      alert("Error: Please enter caregiver's email");
      return;
    }

    setSearching(true);
    setSearchedCaregiver(null);

    try {
      const result = await AddCaregiverController.searchCaregiver(searchEmail.trim());
      
      if (result.success) {
        setSearchedCaregiver(result.data);
      } else {
        alert("Not Found: " + result.error);
      }
    } catch (error) {
      alert("Error: Search failed");
    } finally {
      setSearching(false);
    }
  };

  const handleAddCaregiver = async () => {
    if (!searchedCaregiver) return;

    try {
      const result = await AddCaregiverController.addCaregiverWithPayment(
        searchedCaregiver.email, 
        paymentMethod,
        paymentMethod === 'credit_card' ? cardDetails : null
      );
      
      if (result.success) {
        alert("Success: " + result.message);
        setSearchedCaregiver(null);
        setSearchEmail('');
        setShowConfirmModal(false);
        setPaymentMethod('wallet');
        setCardDetails({ cardNumber: '', expiryDate: '', cvv: '', cardName: '' });
        
        if (result.newBalance !== null) {
          setWalletBalance(result.newBalance);
        }
        loadInitialData();
      } else {
        alert("Error: " + result.error);
      }
    } catch (error) {
      alert("Error: Failed to add caregiver");
    }
  };

  const handleRemoveCaregiver = async (caregiver) => {
    if (window.confirm(`Are you sure you want to remove ${caregiver.firstname} ${caregiver.lastname}?`)) {
      const result = await AddCaregiverController.removeCaregiver(caregiver.uid);
      if (result.success) {
        alert("Success: " + result.message);
        loadInitialData();
      } else {
        alert("Error: " + result.error);
      }
    }
  };

  const showConfirmationModal = () => {
    if (!searchedCaregiver) return;
    setShowConfirmModal(true);
  };

  const handleCardInputChange = (field, value) => {
    setCardDetails(prev => ({ ...prev, [field]: value }));
  };

  const formatCardNumber = (value) => {
    const v = value.replace(/\s+/g, '').replace(/[^0-9]/gi, '');
    const matches = v.match(/\d{4,16}/g);
    const match = (matches && matches[0]) || '';
    const parts = [];
    
    for (let i = 0, len = match.length; i < len; i += 4) {
      parts.push(match.substring(i, i + 4));
    }
    
    if (parts.length) {
      return parts.join(' ');
    } else {
      return value;
    }
  };

  const formatExpiryDate = (value) => {
    const v = value.replace(/\s+/g, '').replace(/[^0-9]/gi, '');
    if (v.length >= 2) {
      return v.substring(0, 2) + (v.length > 2 ? '/' + v.substring(2, 4) : '');
    }
    return v;
  };

  if (pageLoading) {
    return (
      <div className="center-container">
        <div className="spinner"></div>
        <p className="loading-text">Loading...</p>
      </div>
    );
  }

  return (
    <div className="container">
      <div className="header">
        <h1 className="title">Add Caregiver</h1>
        <p className="subtitle" style={{color: "black"}}>
          For {elderlyInfo?.firstname} {elderlyInfo?.lastname}
        </p>
        
        <div className="wallet-info">
          <span className="wallet-label">Wallet Balance:</span>
          <span className="wallet-amount">${walletBalance.toFixed(2)}</span>
        </div>
        
        <div className="fee-info">
          <span className="fee-text">Caregiver Fee: $25.00</span>
        </div>
      </div>

      <div className="search-section">
        <h2 className="section-title">Search Caregiver</h2>
        
        <div className="search-container">
          <input
            className="search-input"
            placeholder="Enter caregiver's email address"
            value={searchEmail}
            onChange={(e) => setSearchEmail(e.target.value)}
            type="email"
          />
          <button 
            className="search-button"
            onClick={handleSearchCaregiver}
            disabled={searching}
          >
            {searching ? 'Searching...' : 'Search'}
          </button>
        </div>

        {searchedCaregiver && (
          <div className="caregiver-card">
            <div className="caregiver-header">
              <div className="avatar">
                {searchedCaregiver.firstname?.[0]}{searchedCaregiver.lastname?.[0]}
              </div>
              <div className="caregiver-info">
  <div className="caregiver-name">
    {searchedCaregiver.firstname} {searchedCaregiver.lastname}
  </div>
  <div className="caregiver-contact">
    <div className="caregiver-email">{searchedCaregiver.email}</div>
    <div className="caregiver-phone">{searchedCaregiver.phoneNum}</div>
  </div>
</div>
            </div>
            
            {searchedCaregiver.isLinked ? (
              <div className="already-linked">
                Already linked to your account
              </div>
            ) : (
              <button 
                className="add-button"
                onClick={showConfirmationModal}
              >
                Add Caregiver - $25.00
              </button>
            )}
          </div>
        )}
      </div>

      {showConfirmModal && searchedCaregiver && (
        <div className="modal-overlay">
          <div className="modal-content">
            <h2 className="modal-title">Confirm Payment</h2>
            
            <div className="confirmation-info">
              <p className="confirmation-text">
                You are about to add:
              </p>
              <div className="caregiver-name-large">
                {searchedCaregiver.firstname} {searchedCaregiver.lastname}
              </div>
              <div className="caregiver-email">{searchedCaregiver.email}</div>
              
              <div className="payment-info">
                <span className="payment-label">Amount to pay:</span>
                <span className="payment-amount">$25.00</span>
              </div>

              <h3 className="payment-method-title">Payment Method</h3>
              <div className="payment-method-container">
                <button 
                  className={`payment-method-option ${paymentMethod === 'wallet' ? 'payment-method-selected' : ''}`}
                  onClick={() => setPaymentMethod('wallet')}
                >
                  <div className="payment-method-text">Wallet</div>
                  <div className="payment-method-subtext">
                    Balance: ${walletBalance.toFixed(2)}
                  </div>
                  {walletBalance < 25 && (
                    <div className="insufficient-text">Insufficient funds</div>
                  )}
                </button>
                
                <button 
                  className={`payment-method-option ${paymentMethod === 'credit_card' ? 'payment-method-selected' : ''}`}
                  onClick={() => setPaymentMethod('credit_card')}
                >
                  <div className="payment-method-text">Credit Card</div>
                  <div className="payment-method-subtext">Pay with card</div>
                </button>
              </div>

              {paymentMethod === 'credit_card' && (
                <div className="card-form">
                  <h4 className="card-form-title">Card Details</h4>
                  
                  <label className="input-label">Cardholder Name</label>
                  <input
                    className="card-input"
                    placeholder="John Doe"
                    value={cardDetails.cardName}
                    onChange={(e) => handleCardInputChange('cardName', e.target.value)}
                  />
                  
                  <label className="input-label">Card Number</label>
                  <input
                    className="card-input"
                    placeholder="1234 5678 9012 3456"
                    value={cardDetails.cardNumber}
                    onChange={(e) => handleCardInputChange('cardNumber', formatCardNumber(e.target.value))}
                    type="text"
                    maxLength={19}
                  />
                  
                  <div className="card-row">
                    <div className="half-input">
                      <label className="input-label">Expiry Date</label>
                      <input
                        className="card-input"
                        placeholder="MM/YY"
                        value={cardDetails.expiryDate}
                        onChange={(e) => handleCardInputChange('expiryDate', formatExpiryDate(e.target.value))}
                        type="text"
                        maxLength={5}
                      />
                    </div>
                    
                    <div className="half-input">
                      <label className="input-label">CVV</label>
                      <input
                        className="card-input"
                        placeholder="123"
                        value={cardDetails.cvv}
                        onChange={(e) => handleCardInputChange('cvv', e.target.value.replace(/[^0-9]/g, ''))}
                        type="password"
                        maxLength={4}
                      />
                    </div>
                  </div>
                </div>
              )}

              {paymentMethod === 'wallet' && (
                <div className="balance-summary">
                  <div className="balance-row">
                    <span className="balance-label">Current balance:</span>
                    <span className="balance-amount">${walletBalance.toFixed(2)}</span>
                  </div>
                  
                  <div className="balance-row">
                    <span className="balance-label">Payment amount:</span>
                    <span className="payment-amount">-$25.00</span>
                  </div>
                  
                  <div className="balance-row">
                    <span className="new-balance-label">New balance:</span>
                    <span className="new-balance-amount">
                      ${(walletBalance - 25).toFixed(2)}
                    </span>
                  </div>
                </div>
              )}
            </div>

            <div className="modal-buttons">
              <button 
                className="cancel-button"
                onClick={() => {
                  setShowConfirmModal(false);
                  setPaymentMethod('wallet');
                  setCardDetails({ cardNumber: '', expiryDate: '', cvv: '', cardName: '' });
                }}
              >
                Cancel
              </button>
              
              <button 
                className={`confirm-button ${(paymentMethod === 'wallet' && walletBalance < 25) ? 'confirm-button-disabled' : ''}`}
                onClick={handleAddCaregiver}
                disabled={paymentMethod === 'wallet' && walletBalance < 25}
              >
                {paymentMethod === 'wallet' ? 'Pay from Wallet' : 'Pay with Card'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default AdditionalCaregiverPage;