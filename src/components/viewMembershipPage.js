import React, { useState, useEffect } from 'react';
import { Star, Check, Sparkles, Heart, Users, Clock, Zap, Shield, Trophy, CreditCard, X } from 'lucide-react';
import { useNavigate } from 'react-router-dom';
import { SubscriptionController } from '../controller/subscriptionController';
import { fetchAllMembershipPlans } from '../controller/membershipController';
import './viewMembershipPage.css';
import Footer from '../footer';

const ModernMembershipPage = () => {
  const [selectedPlan, setSelectedPlan] = useState(0);
  const [isVisible, setIsVisible] = useState(false);
  const [caregiversByPlan, setCaregiversByPlan] = useState({});
  const [isProcessing, setIsProcessing] = useState(false);
  const [showPaymentPopup, setShowPaymentPopup] = useState(false);
  const [paymentDetails, setPaymentDetails] = useState({
    cardName: '',
    cardNumber: '',
    expiryDate: '',
    cvv: ''
  });
  const [membershipPlans, setMembershipPlans] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  
  const navigate = useNavigate();
  
  // Check if user is logged in using localStorage
  const isAuthenticated = !!localStorage.getItem("loggedInEmail");
  const loggedInEmail = localStorage.getItem("loggedInEmail");
  
  useEffect(() => {
    const timer = setTimeout(() => setIsVisible(true), 100);
    return () => clearTimeout(timer);
  }, []);

  // Fetch membership plans from controller
  useEffect(() => {
    const loadMembershipPlans = async () => {
      try {
        setLoading(true);
        const result = await fetchAllMembershipPlans();
        
        if (result.success) {
          // Map the plans from database to the format expected by the component
          const formattedPlans = result.data.map((plan, index) => ({
            id: plan.id,
            title: plan.title,
            subtitle: plan.subtitle,
            price: plan.price,
            period: plan.period,
            originalPrice: plan.originalPrice || null,
            savings: plan.savings || null,
            popular: plan.popular || false,
            trial: plan.trial || false,
            features: plan.features || [],
            colorScheme: plan.colorScheme || getDefaultColorScheme(index),
            gradient: getDefaultGradient(index),
            icon: getDefaultIcon(index)
          }));
          
          setMembershipPlans(formattedPlans);
          
          // Initialize caregivers state for each plan
          const initialCaregivers = {};
          formattedPlans.forEach(plan => {
            initialCaregivers[plan.id] = 0;
          });
          setCaregiversByPlan(initialCaregivers);
        } else {
          setError(result.error || "Failed to load membership plans");
        }
      } catch (err) {
        console.error("Error loading membership plans:", err);
        setError("Failed to load membership plans");
      } finally {
        setLoading(false);
      }
    };

    loadMembershipPlans();
  }, []);

  // Helper functions to map database plans to UI properties
  const getDefaultColorScheme = (index) => {
    const schemes = ["green", "blue", "sky", "cyan"];
    return schemes[index % schemes.length];
  };

  const getDefaultGradient = (index) => {
    const gradients = [
      "from-green-300 via-emerald-400 to-green-500",
      "from-sky-300 via-blue-400 to-blue-500",
      "from-blue-400 via-sky-400 to-cyan-300",
      "from-cyan-400 via-blue-400 to-indigo-400"
    ];
    return gradients[index % gradients.length];
  };

  const getDefaultIcon = (index) => {
    const icons = [
      <Sparkles className="plan-icon" />,
      <Clock className="plan-icon" />,
      <Star className="plan-icon" />,
      <Heart className="plan-icon" />
    ];
    return icons[index % icons.length];
  };

  const handlePlanSelect = (planId) => {
    setSelectedPlan(planId);
  };

  const handleCaregiverChange = (planId, delta) => {
    setCaregiversByPlan(prev => ({
      ...prev,
      [planId]: Math.max(0, (prev[planId] || 0) + delta)
    }));
  };

  const calculateCaregiverCost = (planId, count) => {
    const plan = membershipPlans.find(p => p.id === planId);
    if (!plan || plan.trial) return 0;
    
    switch(plan.period) {
      case "month": return count * 25;
      case "year": return count * 25 * 12;
      case "3 years": return count * 25 * 36;
      default: return count * 25;
    }
  };

  const calculateExpiryDate = (period) => {
    const today = new Date();
    switch(period) {
      case "15 days":
        today.setDate(today.getDate() + 15);
        break;
      case "month":
        today.setMonth(today.getMonth() + 1);
        break;
      case "year":
        today.setFullYear(today.getYear() + 1);
        break;
      case "3 years":
        today.setFullYear(today.getFullYear() + 3);
        break;
      default:
        today.setMonth(today.getMonth() + 1);
    }
    return today.toISOString().split('T')[0];
  };

  const handlePaymentInputChange = (e) => {
    const { name, value } = e.target;
    setPaymentDetails(prev => ({
      ...prev,
      [name]: value
    }));
  };

  const handleSubscribe = async (planId) => {
    if (!isAuthenticated) {
      navigate('/login', { state: { from: '/membership' } });
      return;
    }

    const selectedPlanData = membershipPlans.find(plan => plan.id === planId);
    if (!selectedPlanData) return;
    
    // For trial plan, we don't need payment details
    if (selectedPlanData.trial) {
      setIsProcessing(true);
      
      try {
        const expiryDate = calculateExpiryDate(selectedPlanData.period);
        const subscriptionController = new SubscriptionController(loggedInEmail);
        const success = await subscriptionController.addSubscription({
          paymentMethod: "Trial",
          cardName: "Trial User",
          cardNumber: "",
          expiryDate: expiryDate,
          cvv: ""
        });
        
        if (success) {
          alert("Your free trial has started! Enjoy 15 days of premium features.");
          navigate('/dashboard');
        } else {
          alert("Failed to start trial. Please try again.");
        }
      } catch (error) {
        console.error("Subscription error:", error);
        alert("An error occurred. Please try again.");
      } finally {
        setIsProcessing(false);
      }
    } else {
      // For paid plans, show payment popup
      setSelectedPlan(planId);
      setShowPaymentPopup(true);
    }
  };

  const processPayment = async () => {
    setIsProcessing(true);
    
    try {
      const selectedPlanData = membershipPlans.find(plan => plan.id === selectedPlan);
      if (!selectedPlanData) {
        alert("Plan not found. Please try again.");
        return;
      }

      const subscriptionController = new SubscriptionController(loggedInEmail);
      const expiryDate = calculateExpiryDate(selectedPlanData.period);
      
      const success = await subscriptionController.addSubscription({
        paymentMethod: "Credit Card",
        cardName: paymentDetails.cardName,
        cardNumber: paymentDetails.cardNumber,
        expiryDate: paymentDetails.expiryDate,
        cvv: paymentDetails.cvv
      });
      
      if (success) {
        alert("Payment successful! Your subscription is now active.");
        setShowPaymentPopup(false);
        navigate('/dashboard');
      } else {
        alert("Payment failed. Please check your details and try again.");
      }
    } catch (error) {
      console.error("Payment error:", error);
      alert("An error occurred during payment. Please try again.");
    } finally {
      setIsProcessing(false);
    }
  };

  // Get the selected plan data safely
  const selectedPlanData = membershipPlans.find(plan => plan.id === selectedPlan);
  
  // Calculate costs only if selectedPlanData exists
  const caregiverCost = selectedPlanData ? calculateCaregiverCost(selectedPlan, caregiversByPlan[selectedPlan] || 0) : 0;
  const totalPrice = selectedPlanData ? selectedPlanData.price + caregiverCost : 0;

  if (loading) {
    return (
      <div className="membership-page">
        <div className="loading-container">
          <div className="loading-spinner"></div>
          <p>Loading membership plans...</p>
        </div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="membership-page">
        <div className="error-container">
          <p>Error: {error}</p>
          <button onClick={() => window.location.reload()}>Retry</button>
        </div>
      </div>
    );
  }

  if (membershipPlans.length === 0) {
    return (
      <div className="membership-page">
        <div className="empty-container">
          <p>No membership plans available at the moment.</p>
        </div>
      </div>
    );
  }

  return (
    <div style={{ marginTop: '-30px'}}>
      <div className="membership-page" style={{maxWidth: '100%', margin: '0 auto'}}>
        <div className="background-elements">
          <div className="bg-shape shape-blue"></div>
          <div className="bg-shape shape-sky"></div>
          <div className="bg-shape shape-cyan"></div>
          <div className="bg-shape shape-green"></div>
        </div>

        <div className="main-content" style={{maxWidth: '100%', margin: '0 auto'}}>
          <section className="hero-section">
            <div className={`hero-content ${isVisible ? 'visible' : ''}`}>
              <div className="hero-header">
                <div className="hero-icon-container">
                  <Sparkles className="hero-icon" />
                </div>
                <h1 className="hero-title">
                  Choose Your Care Plan
                </h1>
              </div>
              <p className="hero-description">
                Enjoy AllCare's AI-assisted aged care platform with flexible payment plans, a free 15-day trial, 
                and customizable caregiver options for your loved ones.
              </p>
            </div>
          </section>

          <section className="plans-section">
            <div className="plans-grid" style={{gridTemplateColumns: `repeat(${Math.min(membershipPlans.length, 4)}, 1fr)`}}>
              {membershipPlans.map((plan) => {
                const planCaregiverCost = calculateCaregiverCost(plan.id, caregiversByPlan[plan.id] || 0);
                const planTotalPrice = plan.price + planCaregiverCost;
                
                return (
                  <div
                    key={plan.id}
                    className={`plan-card ${plan.popular ? 'popular' : ''} ${selectedPlan === plan.id ? 'selected' : ''} ${plan.trial ? 'trial-plan' : ''}`}
                  >
                    {plan.popular && (
                      <div className="popular-badge">
                        <Trophy size={16} />
                        Most Popular
                      </div>
                    )}
                    {plan.trial && (
                      <div className="trial-badge">
                        <Sparkles size={16} />
                        Risk-Free
                      </div>
                    )}
                    {plan.savings && (
                      <div className="savings-badge">{plan.savings}</div>
                    )}
                    <div className={`plan-header ${plan.colorScheme}`}>
                      <div className="plan-header-content">
                        <div className="plan-title-wrapper">
                          <div className="plan-icon-container">{plan.icon}</div>
                          <h3 className="plan-title">{plan.title}</h3>
                        </div>
                        <p className="plan-subtitle">{plan.subtitle}</p>
                      </div>
                    </div>
                    <div className="plan-body">
                      <div className="plan-pricing">
                        <div className="price-display">
                          <span className="price-main">${plan.price}</span>
                          <div className="price-period">
                            <div className="price-per">{plan.trial ? 'for' : 'per'}</div>
                            <div className="price-unit">{plan.period}</div>
                          </div>
                        </div>
                        {plan.originalPrice && plan.originalPrice > plan.price && (
                          <p className="original-price">${plan.originalPrice}</p>
                        )}
                      </div>
                      <ul className="plan-features">
                        {plan.features.map((feature, i) => (
                          <li key={i} className="feature-item">
                           
                            <span>{feature}</span>
                          </li>
                        ))}
                      </ul>

                      {!plan.trial && (
                        <div className="caregiver-addon">
                          <p>Add Additional Caregivers ($25/month each):</p>
                          <div className="caregiver-controls">
                            <button onClick={(e) => { e.stopPropagation(); handleCaregiverChange(plan.id, -1); }}>-</button>
                            <span>{caregiversByPlan[plan.id] || 0}</span>
                            <button onClick={(e) => { e.stopPropagation(); handleCaregiverChange(plan.id, 1); }}>+</button>
                          </div>
                          {selectedPlan === plan.id && planTotalPrice > 0 && (
                            <p className="total-price">Total Price: ${planTotalPrice}</p>
                          )}
                        </div>
                      )}

                      <button 
                        className={`plan-button ${selectedPlan === plan.id ? `selected ${plan.colorScheme}` : 'unselected'}`}
                        onClick={() => handleSubscribe(plan.id)}
                        disabled={isProcessing}
                      >
                        {isProcessing && selectedPlan === plan.id ? (
                          'Processing...'
                        ) : plan.trial ? (
                          <>
                            <Sparkles className="button-icon" />
                            Start Trial
                          </>
                        ) : (
                          <>
                            <Zap className="button-icon" />
                            Subscribe Now
                          </>
                        )}
                      </button>
                    </div>
                  </div>
                );
              })}
            </div>

            {/* Authentication notice */}
            {!isAuthenticated && (
              <div style={{textAlign: 'center', marginTop: '20px', color: '#64748b'}}>
                You'll need to login or create an account to subscribe
              </div>
            )}
          </section>

          {/* Trust Indicators */}
          <section className="trust-section">
            <div className="trust-container">
              <h3 className="trust-title">
                Trusted by Families Worldwide
              </h3>
              <div className="trust-stats">
                <div className="trust-stat">
                  <div className="trust-number blue">24/7</div>
                  <div className="trust-label">AI Assistant Support</div>
                </div>
                <div className="trust-stat">
                  <div className="trust-number sky">99.9%</div>
                  <div className="trust-label">Platform Uptime</div>
                </div>
                <div className="trust-stat">
                  <div className="trust-number cyan">15K+</div>
                  <div className="trust-label">Active Users</div>
                </div>
                <div className="trust-stat">
                  <div className="trust-number green">15 Days</div>
                  <div className="trust-label">Free Trial</div>
                </div>
              </div>
            </div>
          </section>

          {/* Call to Action */}
          <section className="cta-section">
            <div className="cta-container">
              <div className="cta-overlay"></div>
              <div className="cta-content">
                <h3 className="cta-title">Ready to Transform Your Care Experience?</h3>
                <p className="cta-description">
                  Join thousands of families who trust our revolutionary platform for personalized aged care with AI assistance.
                </p>
                <button className="cta-button" onClick={() => membershipPlans[0] && handleSubscribe(membershipPlans[0].id)}>
                  <span>Start Your Free Trial Today</span>
                  <Sparkles className="cta-button-icon" />
                </button>
                <p className="cta-note">No credit card required. Cancel anytime during trial.</p>
              </div>
            </div>
          </section>
        </div>
      </div>
      
      {/* Payment Popup */}
      {showPaymentPopup && selectedPlanData && (
        <div className="payment-popup-overlay">
          <div className="payment-popup">
            <div className="payment-popup-header">
              <h3>Complete Payment</h3>
              <button className="close-popup" onClick={() => setShowPaymentPopup(false)}>
                <X size={20} />
              </button>
            </div>
            <div className="payment-popup-content">
              <div className="payment-summary">
                <h4>Order Summary</h4>
                <p>Plan: {selectedPlanData.title}</p>
                <p>Base Price: ${selectedPlanData.price}</p>
                {caregiverCost > 0 && <p>Additional Caregivers: ${caregiverCost}</p>}
                <p className="total-amount">Total: ${totalPrice}</p>
              </div>
              
              <div className="payment-form">
                <h4>Payment Details</h4>
                <div className="form-group">
                  <label>Cardholder Name</label>
                  <input
                    type="text"
                    name="cardName"
                    value={paymentDetails.cardName}
                    onChange={handlePaymentInputChange}
                    placeholder="John Doe"
                  />
                </div>
                <div className="form-group">
                  <label>Card Number</label>
                  <input
                    type="text"
                    name="cardNumber"
                    value={paymentDetails.cardNumber}
                    onChange={handlePaymentInputChange}
                    placeholder="1234 5678 9012 3456"
                    maxLength="19"
                  />
                </div>
                <div className="form-row">
                  <div className="form-group">
                    <label>Expiry Date</label>
                    <input
                      type="text"
                      name="expiryDate"
                      value={paymentDetails.expiryDate}
                      onChange={handlePaymentInputChange}
                      placeholder="MM/YY"
                      maxLength="5"
                    />
                  </div>
                  <div className="form-group">
                    <label>CVV</label>
                    <input
                      type="text"
                      name="cvv"
                      value={paymentDetails.cvv}
                      onChange={handlePaymentInputChange}
                      placeholder="123"
                      maxLength="3"
                    />
                  </div>
                </div>
              </div>
            </div>
            <div className="payment-popup-footer">
              <button 
                className="pay-now-button"
                onClick={processPayment}
                disabled={isProcessing}
              >
                {isProcessing ? 'Processing...' : `Pay Now $${totalPrice}`}
              </button>
            </div>
          </div>
        </div>
      )}
      
      <Footer />
    </div>
  );
};

export default ModernMembershipPage;