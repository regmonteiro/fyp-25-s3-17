// src/components/AdminServicesPage.js
import React, { useEffect, useState } from "react";
import "./adminServicePage.css";
import { useNavigate } from "react-router-dom";

import { 
  fetchAllServices, 
  createService, 
  updateService, 
  deleteService 
} from "../controller/viewServicesController";
import Footer from "../footer";

function AdminServicesPage() {
  const [services, setServices] = useState([]);
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);
  const [showModal, setShowModal] = useState(false);
  const [editingService, setEditingService] = useState(null);
  const [formData, setFormData] = useState({
    title: "",
    description: "",
    details: ""
  });

  const navigate = useNavigate();

  useEffect(() => {
    loadServices();
  }, []);

  const loadServices = async () => {
    setLoading(true);
    const result = await fetchAllServices();
    if (!result.success) {
      setError(result.error);
    } else {
      setServices(result.data);
    }
    setLoading(false);
  };

  const handleInputChange = (e) => {
    const { name, value } = e.target;
    setFormData(prev => ({
      ...prev,
      [name]: value
    }));
  };

  const handleCreateService = () => {
    setEditingService(null);
    setFormData({
      title: "",
      description: "",
      details: ""
    });
    setShowModal(true);
  };

  const handleEditService = (service) => {
    setEditingService(service);
    setFormData({
      title: service.title,
      description: service.description,
      details: service.details || ""
    });
    setShowModal(true);
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    setLoading(true);

    let result;
    if (editingService) {
      result = await updateService(editingService.id, formData);
    } else {
      result = await createService(formData);
    }

    if (result.success) {
      setShowModal(false);
      setEditingService(null);
      setFormData({ title: "", description: "", details: "" });
      await loadServices();
    } else {
      setError(result.error);
    }
    setLoading(false);
  };

  const handleDeleteService = async (id) => {
    if (window.confirm("Are you sure you want to delete this service? This action cannot be undone.")) {
      setLoading(true);
      const result = await deleteService(id);
      if (result.success) {
        await loadServices();
      } else {
        setError(result.error);
      }
      setLoading(false);
    }
  };

  const handleCloseModal = () => {
    setShowModal(false);
    setEditingService(null);
    setFormData({ title: "", description: "", details: "" });
  };

  return (
    <div>
      <div className="admin-services-page">
        <div className="admin-header">
          <h1 className="admin-title">Manage Services</h1>
          <p className="admin-subtitle">
            Create, edit, and manage AllCare Platform services
          </p>
          <button 
            className="btn-create"
            onClick={handleCreateService}
          >
            + Add New Service
          </button>
        </div>

        {error && (
          <div className="error-message">
            {error}
            <button onClick={() => setError("")} className="error-close">×</button>
          </div>
        )}

        {loading && !showModal && (
          <div className="loading">Loading services...</div>
        )}

        <div className="services-grid">
          {services.map((service) => (
            <div className="service-card-admin" key={service.id}>
              <div className="service-header">
                <h3 className="service-title">{service.title}</h3>
                <div className="service-actions">
                  <button 
                    className="btn-edit"
                    onClick={() => handleEditService(service)}
                  >
                    Edit
                  </button>
                  <button 
                    className="btn-delete"
                    onClick={() => handleDeleteService(service.id)}
                  >
                    Delete
                  </button>
                </div>
              </div>
              
              <div className="service-content">
                <p className="service-description">{service.description}</p>
                {service.details && (
                  <div className="service-details">
                    <strong>Full Details:</strong>
                    <p>{service.details}</p>
                  </div>
                )}
                <div className="service-meta">
                  <span className="service-id">ID: {service.id}</span>
                </div>
              </div>
            </div>
          ))}
        </div>

        {services.length === 0 && !loading && (
          <div className="no-services">
            <p>No services found. Create your first service to get started.</p>
          </div>
        )}
      </div>

      {/* Modal for Create/Edit */}
      {showModal && (
        <div className="modal-overlay">
          <div className="modal">
            <div className="modal-header">
              <h2>{editingService ? 'Edit Service' : 'Create New Service'}</h2>
              <button className="modal-close" onClick={handleCloseModal}>×</button>
            </div>
            
            <form onSubmit={handleSubmit} className="service-form">
              <div className="form-group">
                <label htmlFor="title">Service Title *</label>
                <input
                  type="text"
                  id="title"
                  name="title"
                  value={formData.title}
                  onChange={handleInputChange}
                  required
                  placeholder="Enter service title"
                />
              </div>

              <div className="form-group">
                <label htmlFor="description">Short Description *</label>
                <textarea
                  id="description"
                  name="description"
                  value={formData.description}
                  onChange={handleInputChange}
                  required
                  rows="3"
                  placeholder="Enter brief description (shown in service list)"
                  maxLength="200"
                />
                <div className="char-count">{formData.description.length}/200</div>
              </div>

              <div className="form-group">
                <label htmlFor="details">Full Details</label>
                <textarea
                  id="details"
                  name="details"
                  value={formData.details}
                  onChange={handleInputChange}
                  rows="6"
                  placeholder="Enter detailed information about the service (shown when expanded)"
                />
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
                  {loading ? 'Saving...' : (editingService ? 'Update Service' : 'Create Service')}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      <Footer />
    </div>
  );
}

export default AdminServicesPage;