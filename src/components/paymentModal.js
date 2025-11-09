// src/components/PaymentModal.js
import React, { useState } from 'react';
import { SubscriptionController } from '../controller/subscriptionController';
import { createAccount } from './createAccountPage'; 

const PaymentModal = ({ 
  showPaymentModal, 
  setShowPaymentModal, 
  selectedPlan, 
  userEmail, // Make sure this is passed as a prop
  onPaymentSuccess // Callback for successful payment
}) => {
  const [paymentDetails, setPaymentDetails] = useState({
    method: 'card',
    cardName: '',
    cardNumber: '',
    expiry: '',
    cvv: ''
  });
  const [paymentProcessing, setPaymentProcessing] = useState(false);
  const [paymentError, setPaymentError] = useState('');

  if (!showPaymentModal || !selectedPlan) return null;

  const handlePaymentInputChange = (e) => {
    const { name, value } = e.target;
    setPaymentDetails(prev => ({
      ...prev,
      [name]: value
    }));
  };

  // Helper function to map selected plan to plan ID
  function getPlanId(selectedPlan) {
    // Map based on your subscription plans array
    if (selectedPlan.title.includes('Free Trial')) return 0;
    if (selectedPlan.title.includes('Monthly')) return 1;
    if (selectedPlan.title.includes('Annual')) return 2; // Annual = 1 year
    if (selectedPlan.title.includes('3-Year')) return 3; // 3-Year plan = 3 years
    return 0; // Default to free trial
  }

  const handlePaymentSubmit = async (e) => {
    e.preventDefault();
    setPaymentProcessing(true);
    setPaymentError('');

    try {
      // Validate payment details
      if (paymentDetails.method === 'card') {
        if (!paymentDetails.cardName || !paymentDetails.cardNumber || 
            !paymentDetails.expiry || !paymentDetails.cvv) {
          throw new Error('Please fill in all card details');
        }
      }

      // Process the payment using your SubscriptionController
      const subscriptionController = new SubscriptionController(userEmail);
      
      // For new subscriptions
      if (selectedPlan.price === 0) {
        // Free trial
        const success = await subscriptionController.addSubscription({
          paymentMethod: 'trial',
          cardName: '',
          cardNumber: '',
          expiryDate: '',
          cvv: '',
          subscriptionPlan: 0 // Free trial plan
        });
        
        if (!success) {
          throw new Error(subscriptionController.errorMessage || 'Failed to start free trial');
        }
      } else {
        // Paid subscription - you'll need to map your selectedPlan to the correct plan ID
        const planId = getPlanId(selectedPlan);
        
        const success = await subscriptionController.addSubscription({
          paymentMethod: paymentDetails.method,
          cardName: paymentDetails.cardName,
          cardNumber: paymentDetails.cardNumber,
          expiryDate: paymentDetails.expiry,
          cvv: paymentDetails.cvv,
          subscriptionPlan: planId
        });
        
        if (!success) {
          throw new Error(subscriptionController.errorMessage || 'Payment failed');
        }
      }

      // Payment successful
      setPaymentProcessing(false);
      if (onPaymentSuccess) {
        onPaymentSuccess();
      }
      setShowPaymentModal(false);
      
    } catch (err) {
      setPaymentProcessing(false);
      setPaymentError(err.message);
      console.error('Payment error:', err);
    }
  };

  const calculateSubscriptionEndDate = (plan) => {
    const today = new Date();
    const endDate = new Date();
    
    switch(plan) {
      case 0: // Free trial (15 days)
        endDate.setDate(today.getDate() + 15);
        break;
      case 1: // Monthly plan
        endDate.setMonth(today.getMonth() + 1);
        break;
      case 2: // Annual plan (1 year)
        endDate.setFullYear(today.getFullYear() + 1);
        break;
      case 3: // 3-Year plan
        endDate.setFullYear(today.getFullYear() + 3);
        break;
      default:
        endDate.setDate(today.getDate() + 15); // Default to 15-day trial
    }
    
    return endDate.toISOString().split('T')[0]; // Return as YYYY-MM-DD
  };

  return (
    <div className="payment-modal-overlay">
      <div className="payment-modal-content">
        <div className="payment-modal-header">
          <h2>Complete Your Subscription</h2>
          <button 
            className="payment-modal-close" 
            onClick={() => setShowPaymentModal(false)}
            onKeyDown={(e) => {
              if (e.key === 'Enter' || e.key === ' ') {
                setShowPaymentModal(false);
              }
            }}
            aria-label="Close payment modal"
            disabled={paymentProcessing}
          >
            ×
          </button>
        </div>
        
        <div className="payment-plan-summary">
          <h3>{selectedPlan.title} Plan</h3>
          <p className="payment-price">
            {selectedPlan.price === 0 ? 'Free' : `$${selectedPlan.price}/${selectedPlan.period}`}
            {selectedPlan.originalPrice && (
              <span className="payment-original-price">${selectedPlan.originalPrice}</span>
            )}
          </p>
          {selectedPlan.savings && (
            <div className="payment-savings">{selectedPlan.savings}</div>
          )}
        </div>
        
        <form onSubmit={handlePaymentSubmit} className="payment-form">
          <div className="payment-form-group">
            <label htmlFor="payment-method">Payment Method</label>
            <select 
              id="payment-method"
              value={paymentDetails.method} 
              onChange={(e) => setPaymentDetails({...paymentDetails, method: e.target.value})}
              className="payment-select"
              disabled={paymentProcessing}
            >
              <option value="card">Credit/Debit Card</option>
              <option value="paypal">PayPal</option>
            </select>
          </div>
          
          {paymentDetails.method === 'card' && (
            <>
              <div className="payment-form-group">
                <label htmlFor="card-name">Cardholder Name</label>
                <input
                  id="card-name"
                  type="text"
                  name="cardName"
                  value={paymentDetails.cardName}
                  onChange={handlePaymentInputChange}
                  placeholder="John Doe"
                  required
                  className="payment-input"
                  disabled={paymentProcessing}
                />
              </div>
              
              <div className="payment-form-group">
                <label htmlFor="card-number">Card Number</label>
                <input
                  id="card-number"
                  type="text"
                  name="cardNumber"
                  value={paymentDetails.cardNumber}
                  onChange={handlePaymentInputChange}
                  placeholder="1234 5678 9012 3456"
                  required
                  className="payment-input"
                  disabled={paymentProcessing}
                />
              </div>
              
              <div className="payment-form-row">
                <div className="payment-form-group">
                  <label htmlFor="expiry-date">Expiry Date</label>
                  <input
                    id="expiry-date"
                    type="text"
                    name="expiry"
                    value={paymentDetails.expiry}
                    onChange={handlePaymentInputChange}
                    placeholder="MM/YY"
                    required
                    className="payment-input"
                    disabled={paymentProcessing}
                  />
                </div>
                
                <div className="payment-form-group">
                  <label htmlFor="cvv">CVV</label>
                  <input
                    id="cvv"
                    type="text"
                    name="cvv"
                    value={paymentDetails.cvv}
                    onChange={handlePaymentInputChange}
                    placeholder="123"
                    required
                    className="payment-input"
                    disabled={paymentProcessing}
                  />
                </div>
              </div>
            </>
          )}
          
          {paymentError && <div className="payment-error">{paymentError}</div>}
          
          <div className="payment-modal-actions">
            <button 
              type="button" 
              className="payment-cancel-btn"
              onClick={() => setShowPaymentModal(false)}
              disabled={paymentProcessing}
            >
              Cancel
            </button>
            <button 
              type="submit" 
              className="payment-confirm-btn"
              disabled={paymentProcessing}
            >
              {paymentProcessing ? 'Processing...' : `Confirm ${selectedPlan.price === 0 ? 'Subscription' : 'Payment'} - ${selectedPlan.price === 0 ? 'Free Trial' : `$${selectedPlan.price}`}`}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
};

export default PaymentModal;