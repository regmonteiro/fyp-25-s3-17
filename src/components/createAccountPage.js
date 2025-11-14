// src/components/createAccount.js
import React, { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { createAccountEntity } from '../entity/createAccountEntity';
import { createAccount } from '../controller/createAccountController';
import { fetchAllMembershipPlans } from '../controller/membershipController';
import "../components/createAccountPage.css";
import Footer from '../footer';
import PaymentModal from './paymentModal';

// ✅ Phone input + validation
import PhoneInput from 'react-phone-input-2';
import 'react-phone-input-2/lib/style.css';
import { parsePhoneNumberFromString } from 'libphonenumber-js';

// Icons for subscription plans
import { Sparkles, Clock, Star, Heart } from 'lucide-react';

// Icon mapping for membership plans
const planIcons = {
  'Free Trial': <Sparkles className="plan-icon" />,
  'Monthly Care': <Clock className="plan-icon" />,
  'Annual Wellness': <Star className="plan-icon" />,
  '3-Year Care Plan': <Heart className="plan-icon" />,
  'default': <Sparkles className="plan-icon" />
};

function CreateAccountPage() {
  const [formData, setFormData] = useState({
    firstname: '',
    lastname: '',
    email: '',
    dob: '',
    phoneNum: '',
    password: '',
    confirmPassword: '',
    userType: 'admin',
    elderlyId: '',
    subscriptionPlan: null
  });

  const [membershipPlans, setMembershipPlans] = useState([]);
  const [loadingPlans, setLoadingPlans] = useState(false);
  const [acceptTerms, setAcceptTerms] = useState(false);
  const [error, setError] = useState('');
  const [successMessage, setSuccessMessage] = useState('');
  const [showPassword, setShowPassword] = useState(false);
  const [showConfirmPassword, setShowConfirmPassword] = useState(false);
  const [showPaymentModal, setShowPaymentModal] = useState(false);
  const [selectedPlan, setSelectedPlan] = useState(null);
  const [paymentProcessing, setPaymentProcessing] = useState(false);
  const [paymentError, setPaymentError] = useState('');
  const [paymentDetails, setPaymentDetails] = useState({
    method: 'card',
    cardName: '',
    cardNumber: '',
    expiry: '',
    cvv: ''
  });
  
  const today = new Date().toISOString().split('T')[0];
  const navigate = useNavigate();

  // Fetch membership plans from the controller
  useEffect(() => {
    const loadMembershipPlans = async () => {
      if (formData.userType === 'elderly') {
        setLoadingPlans(true);
        const result = await fetchAllMembershipPlans();
        if (result.success) {
          setMembershipPlans(result.data);
        } else {
          setError('Failed to load membership plans');
        }
        setLoadingPlans(false);
      }
    };

    loadMembershipPlans();
  }, [formData.userType]);

  const handleChange = (e) => {
    setFormData({ ...formData, [e.target.name]: e.target.value });
    setError('');
    setSuccessMessage('');
  };

  const handlePlanSelect = (plan) => {
    setFormData({ ...formData, subscriptionPlan: plan.id });
    setSelectedPlan(plan);
    
    if (plan.price === 0) {
      // Free trial - no payment needed
      handleSubmit(null, true);
    } else {
      setShowPaymentModal(true);
    }
  };

  const handlePaymentInputChange = (e) => {
    const { name, value } = e.target;
    setPaymentDetails(prev => ({
      ...prev,
      [name]: value
    }));
  };

  const handlePaymentSubmit = async (e) => {
    e.preventDefault();
    setPaymentProcessing(true);
    setPaymentError('');

    try {
      // Simulate payment processing
      await new Promise(resolve => setTimeout(resolve, 2000));
      
      // In a real app, you would call your payment API here
      const paymentSuccess = Math.random() > 0.2; // 80% success rate for demo
      
      if (paymentSuccess) {
        handleSubmit(null, true);
        setShowPaymentModal(false);
      } else {
        setPaymentError("Payment failed. Please try again.");
      }
    } catch (err) {
      setPaymentError("An error occurred during payment processing");
    } finally {
      setPaymentProcessing(false);
    }
  };

  const handleSubmit = async (e, fromPlanSelection = false) => {
    if (e) e.preventDefault();

    // If coming from plan selection, skip validation
    if (!fromPlanSelection) {
      // ✅ Must accept Terms & Conditions
      if (!acceptTerms) {
        setError("You must accept the Terms & Conditions before creating an account.");
        return;
      }

      // Validate password match
      if (formData.password !== formData.confirmPassword) {
        setError("Passwords do not match");
        return;
      }
      
      if (formData.password.length < 8) {
        setError("Password must be at least 8 characters long");
        return;
      }

      // ✅ Ensure phone number always has + prefix
      const rawPhone = formData.phoneNum.startsWith('+')
        ? formData.phoneNum
        : `+${formData.phoneNum}`;

      const phoneNumber = parsePhoneNumberFromString(rawPhone);
      if (!phoneNumber || !phoneNumber.isPossible()) {
        setError("Please enter a valid phone number.");
        return;
      }
    }

    // Calculate subscription end date
    let subscriptionEndDate = null;
    if (selectedPlan) {
      const endDate = new Date();
      if (selectedPlan.period.includes('day') || selectedPlan.period.includes('trial')) {
        endDate.setDate(endDate.getDate() + 15);
      } else if (selectedPlan.period.includes('month')) {
        endDate.setMonth(endDate.getMonth() + 1);
      } else if (selectedPlan.period.includes('year')) {
        endDate.setFullYear(endDate.getFullYear() + 1);
      } else if (selectedPlan.period.includes('3')) {
        endDate.setFullYear(endDate.getFullYear() + 3);
      }
      subscriptionEndDate = endDate.toISOString().split('T')[0];
    }

    const accountEntity = createAccountEntity({ 
      ...formData, 
      phoneNum: formData.phoneNum.startsWith('+') ? formData.phoneNum : `+${formData.phoneNum}`,
      subscriptionPlan: selectedPlan ? selectedPlan.id : null,
      subscriptionEndDate: subscriptionEndDate,
      // For free trial, set payment details to "N/A"
      paymentDetails: selectedPlan && selectedPlan.price === 0 ? {
        method: 'trial',
        cardName: 'N/A',
        cardNumber: 'N/A',
        expiry: 'N/A',
        cvv: 'N/A'
      } : paymentDetails
    });
    
    const result = await createAccount(accountEntity);

    if (!result.success) {
      setError(result.error);
      setSuccessMessage('');
      return;
    }

    // Use custom message if available, otherwise default
    setSuccessMessage(result.message || "Account successfully created!");
    
    if (fromPlanSelection) {
      setSuccessMessage(selectedPlan.price === 0 
        ? "Free trial activated! Redirecting to login..." 
        : "Payment successful! Redirecting to login..."
      );
    }
    
    setTimeout(() => {
      navigate('/login');
    }, 3000); // Increased timeout to show the assignment message
    
    setError('');
  };

  // Get icon for plan based on title
  const getPlanIcon = (planTitle) => {
    return planIcons[planTitle] || planIcons.default;
  };

  // ✅ Terms & Conditions text
  const termsText = `
Last Updated: August 10, 2025

Welcome to Allcare! These Terms and Conditions govern your access to and use of the Allcare website and mobile application (the "Platform"). By creating an account or using the Platform, you agree to be bound by these terms. If you do not agree, you may not use the Platform.

1. Acceptance of Terms: By using the Allcare Platform, you confirm that you are at least 18 years of age or a legal guardian of an elderly user. All caregivers and administrators must be at least 18 years of age. Elderly users who are not of legal age to enter into a contract must have their account created and managed by a legal guardian.

2. Platform Purpose and Features: Allcare is a digital platform designed to assist elderly individuals and their caregivers. The Platform's features include, but are not limited to: an AI assistant to provide personalized support; scheduling and reminders for appointments and events; learning resources and social activities; experience sharing and social media integration.

3. User Accounts and Responsibilities: You are responsible for providing accurate and complete information during registration. You are responsible for safeguarding your password and for all activities that occur under your account. You must notify us immediately of any unauthorized use.

4. Content and Conduct: You agree to use the Platform for its intended purpose and not for any unlawful or prohibited activities. You are solely responsible for any content you post, share, or submit on the Platform.

5. Privacy Policy: Your privacy is important to us. Our Privacy Policy, which is incorporated into these Terms by reference, explains how we collect, use, and protect your personal information. By using the Platform, you consent to our collection and use of your data as described in the Privacy Policy.

6. Disclaimers and Limitation of Liability: The Platform is provided "as is" and "as available" without any warranties of any kind, whether express or implied. Allcare, its developers, and its affiliates will not be liable for any damages, including but not limited to direct, indirect or incidental damages, arising from your use or inability to use the Platform.

7. Changes to Terms: We may revise these Terms and Conditions from time to time. The most current version will always be posted on the Platform. By continuing to use the Platform after changes have been made, you agree to be bound by the revised terms.

8. Governing Law: These Terms and Conditions are governed by the laws of Singapore. Any disputes arising from these terms will be resolved in the courts of Singapore.

9. Contact Information: If you have any questions about these Terms and Conditions, please contact us at admin@allcare.com.
  `;

  return (
    <div>
      <div className="modern-signup-container">
        <div className="signup-card">
          <div className="signup-header">
            <h2>Create Your Account</h2>
            <p>Join our community and get started</p>
          </div>

          <form onSubmit={handleSubmit} className="modern-signup-form">
            <div className="form-row">
              <div className="input-group">
                <label htmlFor="firstname">First Name</label>
                <input
                  id="firstname"
                  type="text"
                  name="firstname"
                  value={formData.firstname}
                  onChange={handleChange}
                  placeholder="First name"
                  required
                  className="modern-input"
                />
              </div>

              <div className="input-group">
                <label htmlFor="lastname">Last Name</label>
                <input
                  id="lastname"
                  type="text"
                  name="lastname"
                  value={formData.lastname}
                  onChange={handleChange}
                  placeholder="Last name"
                  required
                  className="modern-input"
                />
              </div>
            </div>

            <div className="input-group">
              <label htmlFor="email">Email Address</label>
              <input
                id="email"
                type="email"
                name="email"
                value={formData.email}
                onChange={handleChange}
                placeholder="helloworld@gmail.com"
                required
                className="modern-input"
              />
            </div>

            <div className="form-row">
              <div className="input-group">
                <label htmlFor="dob">Date of Birth</label>
                <input
                  id="dob"
                  type="date"
                  name="dob"
                  value={formData.dob}
                  onChange={handleChange}
                  max={today}
                  required
                  className="modern-input"
                />
              </div>

              <div className="input-group">
                <label htmlFor="phoneNum">Phone Number</label>
                <PhoneInput
                  country={'sg'}
                  value={formData.phoneNum}
                  onChange={(phone) =>
                    setFormData({ ...formData, phoneNum: `+${phone}` })
                  } 
                  inputProps={{
                    name: 'phone',
                    required: true,
                    className: 'modern-input',
                    style: { marginLeft: "20px" }
                  }} 
                  enableSearch={true} 
                />
              </div>
            </div>

            <div className="input-group password-group">
              <label htmlFor="password">Password</label>
              <div className="password-input-container">
                <input
                  id="password"
                  type={showPassword ? "text" : "password"}
                  name="password"
                  value={formData.password}
                  onChange={handleChange}
                  placeholder="Enter password"
                  required
                  className="modern-input"
                />
                <button
                  type="button"
                  className="password-toggle"
                  onClick={() => setShowPassword(!showPassword)}
                >
                  {showPassword ? "Hide" : "Show"}
                </button>
              </div>
            </div>

            <div className="input-group password-group">
              <label htmlFor="confirmPassword">Confirm Password</label>
              <div className="password-input-container">
                <input
                  id="confirmPassword"
                  type={showConfirmPassword ? "text" : "password"}
                  name="confirmPassword"
                  value={formData.confirmPassword}
                  onChange={handleChange}
                  placeholder="Confirm password"
                  required
                  className="modern-input"
                />
                <button
                  type="button"
                  className="password-toggle"
                  onClick={() => setShowConfirmPassword(!showConfirmPassword)}
                >
                  {showConfirmPassword ? "Hide" : "Show"}
                </button>
              </div>
            </div>

            <div className="input-group">
              <label htmlFor="userType">User Type</label>
              <div className="select-wrapper">
                <select
                  id="userType"
                  name="userType"
                  value={formData.userType}
                  onChange={handleChange}
                  required
                  className="modern-select"
                >
                  <option value="admin">Admin</option>
                  <option value="elderly">Elderly</option>
                  <option value="caregiver">Caregiver</option>
                </select>
              </div>
            </div>

            {formData.userType === 'caregiver' && (
              <div className="input-group">
                <label htmlFor="elderlyId">
                  Elderly ID (optional - will be automatically assigned if left blank)
                </label>
                <input
                  id="elderlyId"
                  type="text"
                  name="elderlyId"
                  value={formData.elderlyId}
                  onChange={handleChange}
                  placeholder="Enter specific Elderly User ID (or leave blank for auto-assignment)"
                  className="modern-input"
                />
                <small style={{color: '#666', fontSize: '12px', marginTop: '4px'}}>
                  If you leave this blank, we'll automatically assign you to an elderly user who needs a caregiver.
                </small>
              </div>
            )}

            {/* Subscription Plans Section - Only show for elderly users */}
            {formData.userType === 'elderly' && (
              <div className="subscription-section">
                <h3>Choose Your Subscription Plan</h3>
                <p>Select the plan that best fits your needs</p>
                
                {loadingPlans ? (
                  <div className="loading-plans">Loading plans...</div>
                ) : (
                  <div className="subscription-plans-container">
                    {membershipPlans.map((plan) => (
                      <div 
                        key={plan.id} 
                        className={`subscription-plan ${plan.popular ? 'popular' : ''} ${plan.trial ? 'trial' : ''} ${formData.subscriptionPlan === plan.id ? 'selected' : ''}`}
                        onClick={() => handlePlanSelect(plan)}
                      >
                        {plan.popular && <div className="popular-badge">Most Popular</div>}
                        {plan.trial && <div className="trial-badge">Trial</div>}
                        <div className="plan-icon">{getPlanIcon(plan.title)}</div>
                        <h3>{plan.title}</h3>
                        <p className="plan-subtitle">{plan.subtitle}</p>
                        
                        <div className="plan-price">
                          {plan.price === 0 ? (
                            <span className="free-price">Free</span>
                          ) : (
                            <>
                              <span className="price-amount">${plan.price}</span>
                              {plan.originalPrice && plan.originalPrice > plan.price && (
                                <span className="original-price">${plan.originalPrice}</span>
                              )}
                            </>
                          )}
                          <span className="billing-period">/{plan.period}</span>
                        </div>
                        
                        {plan.savings && (
                          <div className="savings-badge">{plan.savings}</div>
                        )}
                        
                        <ul className="plan-features">
                          {plan.features.map((feature, index) => (
                            <li key={index}>{feature}</li>
                          ))}
                        </ul>
                        
                        <div className="select-indicator">
                          {formData.subscriptionPlan === plan.id ? 'Selected' : 'Select Plan'}
                        </div>
                      </div>
                    ))}
                  </div>
                )}
              </div>
            )}

            {/* ✅ Terms & Conditions Checkbox */}
            <div
              style={{
                display: "flex",
                alignItems: "center",
                gap: "6px",
                margin: "12px 0",
                flexWrap: "nowrap",
                overflow: "hidden",
              }}
            >
              <input
                type="checkbox"
                id="acceptTerms"
                checked={acceptTerms}
                onChange={() => setAcceptTerms(!acceptTerms)}
                style={{
                  accentColor: "#4CAF50",
                  width: "16px",
                  height: "16px",
                  cursor: "pointer",
                  margin: 0,
                  flexShrink: 0,
                }}
              />
              <label
                htmlFor="acceptTerms"
                style={{
                  fontSize: "14px",
                  color: "#333",
                  cursor: "pointer",
                  whiteSpace: "nowrap",
                  flexShrink: 0,
                  display: "inline-flex",
                  alignItems: "center",
                }}
              >
                I agree to the{" "}
                <span
                  onClick={() => alert(termsText)}
                  style={{
                    color: "#007bff",
                    textDecoration: "underline",
                    cursor: "pointer",
                    fontWeight: 500,
                    marginLeft: "2px",
                  }}
                >
                  Terms & Conditions
                </span>
              </label>
            </div>
            
            <button type="submit" className="modern-submit-btn">Create Account</button>
          </form>

          {error && <div className="modern-error-message">{error}</div>}
          {successMessage && <div className="modern-success-message">{successMessage}</div>}

          <div className="signin-redirect">
            Already have an account? <span onClick={() => navigate('/login')}>Sign in</span>
          </div>
        </div>

        <PaymentModal
          showPaymentModal={showPaymentModal}
          setShowPaymentModal={setShowPaymentModal}
          selectedPlan={selectedPlan}
          paymentDetails={paymentDetails}
          setPaymentDetails={setPaymentDetails}
          handlePaymentSubmit={handlePaymentSubmit}
          paymentProcessing={paymentProcessing}
          paymentError={paymentError}
          userEmail={formData.email} 
          onPaymentSuccess={() => {
            // This will be handled in handlePaymentSubmit
          }}
        />
      </div>
      <Footer />
    </div>
  );
}

export default CreateAccountPage;