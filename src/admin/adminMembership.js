// src/components/AdminMembershipPage.js
import React, { useEffect, useState } from "react";
import "./adminMembership.css";
import { useNavigate } from "react-router-dom";
import { 
  fetchAllMembershipPlans, 
  createMembershipPlan, 
  updateMembershipPlan, 
  deleteMembershipPlan 
} from "../controller/membershipController";
import Footer from "../footer";

function AdminMembershipPage() {
  const [plans, setPlans] = useState([]);
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);
  const [showModal, setShowModal] = useState(false);
  const [editingPlan, setEditingPlan] = useState(null);
  const [formData, setFormData] = useState({
    title: "",
    subtitle: "",
    price: 0,
    period: "",
    originalPrice: 0,
    savings: "",
    popular: false,
    trial: false,
    features: [""],
    colorScheme: "blue"
  });

  const navigate = useNavigate();

  useEffect(() => {
    loadPlans();
  }, []);

  const loadPlans = async () => {
    setLoading(true);
    const result = await fetchAllMembershipPlans();
    if (!result.success) {
      setError(result.error);
    } else {
      setPlans(result.data);
    }
    setLoading(false);
  };

  const handleInputChange = (e) => {
    const { name, value, type, checked } = e.target;
    setFormData(prev => ({
      ...prev,
      [name]: type === 'checkbox' ? checked : value
    }));
  };

  const handleFeatureChange = (index, value) => {
    const newFeatures = [...formData.features];
    newFeatures[index] = value;
    setFormData(prev => ({
      ...prev,
      features: newFeatures
    }));
  };

  const addFeature = () => {
    setFormData(prev => ({
      ...prev,
      features: [...prev.features, ""]
    }));
  };

  const removeFeature = (index) => {
    const newFeatures = formData.features.filter((_, i) => i !== index);
    setFormData(prev => ({
      ...prev,
      features: newFeatures
    }));
  };

  const handleCreatePlan = () => {
    setEditingPlan(null);
    setFormData({
      title: "",
      subtitle: "",
      price: 0,
      period: "",
      originalPrice: 0,
      savings: "",
      popular: false,
      trial: false,
      features: [""],
      colorScheme: "blue"
    });
    setShowModal(true);
  };

  const handleEditPlan = (plan) => {
    setEditingPlan(plan);
    setFormData({
      title: plan.title,
      subtitle: plan.subtitle,
      price: plan.price,
      period: plan.period,
      originalPrice: plan.originalPrice || 0,
      savings: plan.savings || "",
      popular: plan.popular || false,
      trial: plan.trial || false,
      features: plan.features.length > 0 ? plan.features : [""],
      colorScheme: plan.colorScheme || "blue"
    });
    setShowModal(true);
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    setLoading(true);

    // Filter out empty features
    const filteredFeatures = formData.features.filter(feature => feature.trim() !== "");
    
    const submitData = {
      ...formData,
      features: filteredFeatures,
      originalPrice: formData.originalPrice || null,
      savings: formData.savings || null
    };

    let result;
    if (editingPlan) {
      result = await updateMembershipPlan(editingPlan.id, submitData);
    } else {
      result = await createMembershipPlan(submitData);
    }

    if (result.success) {
      setShowModal(false);
      setEditingPlan(null);
      setFormData({ 
        title: "", 
        subtitle: "", 
        price: 0, 
        period: "", 
        originalPrice: 0, 
        savings: "", 
        popular: false, 
        trial: false, 
        features: [""], 
        colorScheme: "blue" 
      });
      await loadPlans();
    } else {
      setError(result.error);
    }
    setLoading(false);
  };

  const handleDeletePlan = async (id) => {
    if (window.confirm("Are you sure you want to delete this membership plan? This action cannot be undone.")) {
      setLoading(true);
      const result = await deleteMembershipPlan(id);
      if (result.success) {
        await loadPlans();
      } else {
        setError(result.error);
      }
      setLoading(false);
    }
  };

  const handleCloseModal = () => {
    setShowModal(false);
    setEditingPlan(null);
    setFormData({ 
      title: "", 
      subtitle: "", 
      price: 0, 
      period: "", 
      originalPrice: 0, 
      savings: "", 
      popular: false, 
      trial: false, 
      features: [""], 
      colorScheme: "blue" 
    });
  };

  return (
    <div>
      <div className="admin-membership-page">
        <div className="admin-header">
          <h1 className="admin-title">Manage Membership Plans</h1>
          <p className="admin-subtitle">
            Create, edit, and manage AllCare Platform membership plans
          </p>
          <button 
            className="btn-create"
            onClick={handleCreatePlan}
          >
            + Add New Plan
          </button>
        </div>

        {error && (
          <div className="error-message">
            {error}
            <button onClick={() => setError("")} className="error-close">×</button>
          </div>
        )}

        {loading && !showModal && (
          <div className="loading">Loading plans...</div>
        )}

        <div className="plans-grid-admin">
          {plans.map((plan) => (
            <div className={`plan-card-admin ${plan.popular ? 'popular' : ''} ${plan.trial ? 'trial' : ''}`} key={plan.id}>
              <div className="plan-header-admin">
                <div className="plan-title-section">
                  <h3 className="plan-title-admin">{plan.title}</h3>
                  <p className="plan-subtitle-admin">{plan.subtitle}</p>
                </div>
                <div className="plan-badges">
                  {plan.popular && <span className="badge popular-badge">Popular</span>}
                  {plan.trial && <span className="badge trial-badge">Trial</span>}
                  {plan.savings && <span className="badge savings-badge">{plan.savings}</span>}
                </div>
              </div>
              
              <div className="plan-content-admin">
                <div className="plan-pricing-admin">
                  <div className="price-main-admin">${plan.price}</div>
                  <div className="price-period-admin">per {plan.period}</div>
                  {plan.originalPrice && plan.originalPrice > plan.price && (
                    <div className="original-price-admin">${plan.originalPrice}</div>
                  )}
                </div>

                <div className="plan-features-admin">
                  <h4>Features:</h4>
                  <ul>
                    {plan.features.map((feature, index) => (
                      <li key={index}>{feature}</li>
                    ))}
                  </ul>
                </div>

                <div className="plan-meta">
                  <span className="plan-color">Color: {plan.colorScheme}</span>
                  <span className="plan-id">ID: {plan.id}</span>
                </div>

                <div className="plan-actions">
                  <button 
                    className="btn-edit"
                    onClick={() => handleEditPlan(plan)}
                  >
                    Edit
                  </button>
                  <button 
                    className="btn-delete"
                    onClick={() => handleDeletePlan(plan.id)}
                  >
                    Delete
                  </button>
                </div>
              </div>
            </div>
          ))}
        </div>

        {plans.length === 0 && !loading && (
          <div className="no-plans">
            <p>No membership plans found. Create your first plan to get started.</p>
          </div>
        )}
      </div>

      {/* Modal for Create/Edit */}
      {showModal && (
        <div className="modal-overlay">
          <div className="modal large-modal">
            <div className="modal-header">
              <h2>{editingPlan ? 'Edit Membership Plan' : 'Create New Membership Plan'}</h2>
              <button className="modal-close" onClick={handleCloseModal}>×</button>
            </div>
            
            <form onSubmit={handleSubmit} className="membership-form">
              <div className="form-row">
                <div className="form-group">
                  <label htmlFor="title">Plan Title *</label>
                  <input
                    type="text"
                    id="title"
                    name="title"
                    value={formData.title}
                    onChange={handleInputChange}
                    required
                    placeholder="e.g., Annual Wellness"
                  />
                </div>

                <div className="form-group">
                  <label htmlFor="subtitle">Subtitle *</label>
                  <input
                    type="text"
                    id="subtitle"
                    name="subtitle"
                    value={formData.subtitle}
                    onChange={handleInputChange}
                    required
                    placeholder="e.g., Best value for yearly plan"
                  />
                </div>
              </div>

              <div className="form-row">
                <div className="form-group">
                  <label htmlFor="price">Price ($) *</label>
                  <input
                    type="number"
                    id="price"
                    name="price"
                    value={formData.price}
                    onChange={handleInputChange}
                    required
                    min="0"
                    step="0.01"
                  />
                </div>

                <div className="form-group">
                  <label htmlFor="period">Period *</label>
                  <select
                    id="period"
                    name="period"
                    value={formData.period}
                    onChange={handleInputChange}
                    required
                  >
                    <option value="">Select period</option>
                    <option value="15 days">15 days</option>
                    <option value="month">Monthly</option>
                    <option value="year">Yearly</option>
                    <option value="3 years">3 Years</option>
                  </select>
                </div>
              </div>

              <div className="form-row">
                <div className="form-group">
                  <label htmlFor="originalPrice">Original Price ($)</label>
                  <input
                    type="number"
                    id="originalPrice"
                    name="originalPrice"
                    value={formData.originalPrice}
                    onChange={handleInputChange}
                    min="0"
                    step="0.01"
                    placeholder="Leave empty if no discount"
                  />
                </div>

                <div className="form-group">
                  <label htmlFor="savings">Savings Text</label>
                  <input
                    type="text"
                    id="savings"
                    name="savings"
                    value={formData.savings}
                    onChange={handleInputChange}
                    placeholder="e.g., Save $180"
                  />
                </div>
              </div>

              <div className="form-row">
                <div className="form-group">
                  <label htmlFor="colorScheme">Color Scheme</label>
                  <select
                    id="colorScheme"
                    name="colorScheme"
                    value={formData.colorScheme}
                    onChange={handleInputChange}
                  >
                    <option value="blue">Blue</option>
                    <option value="sky">Sky</option>
                    <option value="cyan">Cyan</option>
                    <option value="green">Green</option>
                    <option value="purple">Purple</option>
                    <option value="pink">Pink</option>
                  </select>
                </div>

                <div className="form-group checkbox-group">
                  <label className="checkbox-label">
                    <input
                      type="checkbox"
                      name="popular"
                      checked={formData.popular}
                      onChange={handleInputChange}
                    />
                    Mark as Popular
                  </label>

                  <label className="checkbox-label">
                    <input
                      type="checkbox"
                      name="trial"
                      checked={formData.trial}
                      onChange={handleInputChange}
                    />
                    Is Trial Plan
                  </label>
                </div>
              </div>

              <div className="form-group">
                <label>Features *</label>
                {formData.features.map((feature, index) => (
                  <div key={index} className="feature-input-group">
                    <input
                      type="text"
                      value={feature}
                      onChange={(e) => handleFeatureChange(index, e.target.value)}
                      placeholder="Enter feature description"
                      required
                    />
                    {formData.features.length > 1 && (
                      <button 
                        type="button" 
                        className="remove-feature"
                        onClick={() => removeFeature(index)}
                      >
                        ×
                      </button>
                    )}
                  </div>
                ))}
                <button 
                  type="button" 
                  className="add-feature-btn"
                  onClick={addFeature}
                >
                  + Add Feature
                </button>
              </div>

              <div className="form-actions">
                <button 
                  type="button" 
                  className="btn-cancel"
                  onClick={handleCloseModal}
                >
                  Cancel
                </button>
                <button 
                  type="submit" 
                  className="btn-submit"
                  disabled={loading}
                >
                  {loading ? 'Saving...' : (editingPlan ? 'Update Plan' : 'Create Plan')}
                </button>
              </div>
            </form>
          </div>
          <br/><br/><br/><br/><br/><br/><br/><br/><br/><br/><br/><br/><br/><br/><br/><br/><br/><br/><br/><br/><br/><br/><br/><br/><br/><br/><br/><br/><br/><br/><br/><br/><br/><br/><br/><br/><br/><br/><br/><br/><br/><br/><br/><br/><br/><br/><br/><br/><br/><br/><br/>
        </div>
        
      )}
       <Footer  />
      
    </div>
  );
}

export default AdminMembershipPage;