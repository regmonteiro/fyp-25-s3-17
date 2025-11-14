// src/pages/AdminActivitiesPage.js
import React, { useEffect, useState } from "react";
import { useNavigate } from "react-router-dom";
import "./adminActivities.css";
import { 
  fetchAllActivities, 
  createActivity, 
  updateActivity, 
  deleteActivity 
} from "../controller/viewActivitiesController";
import Footer from "../footer";

function AdminActivitiesPage() {
  const [activities, setActivities] = useState([]);
  const [filteredActivities, setFilteredActivities] = useState([]);
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);
  const [showModal, setShowModal] = useState(false);
  const [editingActivity, setEditingActivity] = useState(null);
  const [searchQuery, setSearchQuery] = useState("");
  const [formData, setFormData] = useState({
    title: "",
    summary: "",
    category: "",
    difficulty: "",
    duration: "",
    image: "",
    description: "",
    requiresAuth: false,
    tags: [""]
  });

  const navigate = useNavigate();

  const categories = ["Exercise", "Social", "Educational", "Creative", "Wellness", "Entertainment"];
  const difficulties = ["Beginner", "Intermediate", "Advanced"];
  const durations = ["15 mins", "30 mins", "45 mins", "1 hour", "1.5 hours", "2 hours", "2+ hours"];

  useEffect(() => {
    loadActivities();
  }, []);

  useEffect(() => {
    // Filter activities based on search query
    if (searchQuery.trim() === "") {
      setFilteredActivities(activities);
    } else {
      const filtered = activities.filter(activity =>
        activity.title?.toLowerCase().includes(searchQuery.toLowerCase()) ||
        activity.summary?.toLowerCase().includes(searchQuery.toLowerCase()) ||
        activity.category?.toLowerCase().includes(searchQuery.toLowerCase()) ||
        activity.tags?.some(tag => tag.toLowerCase().includes(searchQuery.toLowerCase()))
      );
      setFilteredActivities(filtered);
    }
  }, [searchQuery, activities]);

  const loadActivities = async () => {
    setLoading(true);
    const result = await fetchAllActivities();
    if (!result.success) {
      setError(result.error);
    } else {
      setActivities(result.data);
      setFilteredActivities(result.data);
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

  const handleSearchChange = (e) => {
    setSearchQuery(e.target.value);
  };

  const handleTagChange = (index, value) => {
    const newTags = [...formData.tags];
    newTags[index] = value;
    setFormData(prev => ({
      ...prev,
      tags: newTags
    }));
  };

  const addTag = () => {
    setFormData(prev => ({
      ...prev,
      tags: [...prev.tags, ""]
    }));
  };

  const removeTag = (index) => {
    const newTags = formData.tags.filter((_, i) => i !== index);
    setFormData(prev => ({
      ...prev,
      tags: newTags
    }));
  };

  const handleCreateActivity = () => {
    setEditingActivity(null);
    setFormData({
      title: "",
      summary: "",
      category: "",
      difficulty: "",
      duration: "",
      image: "",
      description: "",
      requiresAuth: false,
      tags: [""]
    });
    setShowModal(true);
  };

  const handleEditActivity = (activity) => {
    setEditingActivity(activity);
    setFormData({
      title: activity.title || "",
      summary: activity.summary || "",
      category: activity.category || "",
      difficulty: activity.difficulty || "",
      duration: activity.duration || "",
      image: activity.image || "",
      description: activity.description || "",
      requiresAuth: activity.requiresAuth || false,
      tags: activity.tags && activity.tags.length > 0 ? activity.tags : [""]
    });
    setShowModal(true);
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    setLoading(true);

    // Filter out empty tags
    const filteredTags = formData.tags.filter(tag => tag.trim() !== "");
    
    const submitData = {
      ...formData,
      tags: filteredTags
    };

    let result;
    if (editingActivity) {
      result = await updateActivity(editingActivity.id, submitData);
    } else {
      result = await createActivity(submitData);
    }

    if (result.success) {
      setShowModal(false);
      setEditingActivity(null);
      setFormData({ 
        title: "",
        summary: "",
        category: "",
        difficulty: "",
        duration: "",
        image: "",
        description: "",
        requiresAuth: false,
        tags: [""]
      });
      await loadActivities();
    } else {
      setError(result.error);
    }
    setLoading(false);
  };

  const handleDeleteActivity = async (id) => {
    if (window.confirm("Are you sure you want to delete this activity? This action cannot be undone.")) {
      setLoading(true);
      const result = await deleteActivity(id);
      if (result.success) {
        await loadActivities();
      } else {
        setError(result.error);
      }
      setLoading(false);
    }
  };

  const handleCloseModal = () => {
    setShowModal(false);
    setEditingActivity(null);
    setFormData({ 
      title: "",
      summary: "",
      category: "",
      difficulty: "",
      duration: "",
      image: "",
      description: "",
      requiresAuth: false,
      tags: [""]
    });
  };

  return (
    <div>
      <div className="admin-activities-page">
        <div className="admin-header">
          <h1 className="admin-title">Manage Activities</h1>
          <p className="admin-subtitle">
            Create, edit, and manage activities for elderly users
          </p>
          
          <div className="admin-toolbar">
            <button 
              className="btn-create"
              onClick={handleCreateActivity}
            >
              + Add New Activity
            </button>
            
            <div className="search-container">
              <input
                type="text"
                placeholder="Search activities..."
                value={searchQuery}
                onChange={handleSearchChange}
                className="search-input"
              />
              <span className="search-icon">🔍</span>
            </div>
          </div>
        </div>

        {error && (
          <div className="error-message">
            {error}
            <button onClick={() => setError("")} className="error-close">×</button>
          </div>
        )}

        {loading && !showModal && (
          <div className="loading">Loading activities...</div>
        )}

        <div className="activities-grid-admin">
          {filteredActivities.map((activity) => (
            <div className="activity-card-admin" key={activity.id}>
              <div className="activity-image-container">
                {activity.image ? (
                  <img src={activity.image} alt={activity.title} className="activity-image" />
                ) : (
                  <div className="activity-image-placeholder">No Image</div>
                )}
              </div>
              
              <div className="activity-content-admin">
                <h3 className="activity-title-admin">{activity.title}</h3>
                <p className="activity-summary-admin">{activity.summary}</p>
                
                <div className="activity-meta">
                  {/* Category and Difficulty as tags */}
                  <div className="tags-container">
                    {activity.category && (
                      <span className="tag category-tag">{activity.category}</span>
                    )}
                    {activity.difficulty && (
                      <span className="tag difficulty-tag">{activity.difficulty}</span>
                    )}
                    {activity.duration && (
                      <span className="tag duration-tag">{activity.duration}</span>
                    )}
                    {/* Additional tags */}
                    {activity.tags && activity.tags.map((tag, index) => (
                      <span key={index} className="tag custom-tag">{tag}</span>
                    ))}
                  </div>
                </div>

                {activity.description && (
                  <div className="activity-description">
                    <p>{activity.description}</p>
                  </div>
                )}

                <div className="activity-actions">
                  <button 
                    className="btn-edit"
                    onClick={() => handleEditActivity(activity)}
                  >
                    Edit
                  </button>
                  <button 
                    className="btn-delete"
                    onClick={() => handleDeleteActivity(activity.id)}
                  >
                    Delete
                  </button>
                </div>
              </div>
            </div>
          ))}
        </div>

        {filteredActivities.length === 0 && !loading && (
          <div className="no-activities">
            <p>
              {searchQuery ? 
                `No activities found matching "${searchQuery}"` : 
                "No activities found. Create your first activity to get started."
              }
            </p>
          </div>
        )}
      </div>

      {/* Modal for Create/Edit */}
      {showModal && (
        <div className="modal-overlay">
          <div className="modal large-modal">
            <div className="modal-header">
              <h2>{editingActivity ? 'Edit Activity' : 'Create New Activity'}</h2>
              <button className="modal-close" onClick={handleCloseModal}>×</button>
            </div>
            
            <form onSubmit={handleSubmit} className="activity-form">
              <div className="form-group">
                <label htmlFor="title">Activity Title *</label>
                <input
                  type="text"
                  id="title"
                  name="title"
                  value={formData.title}
                  onChange={handleInputChange}
                  required
                  placeholder="e.g., Morning Yoga Session"
                />
              </div>

              <div className="form-group">
                <label htmlFor="summary">Summary *</label>
                <textarea
                  id="summary"
                  name="summary"
                  value={formData.summary}
                  onChange={handleInputChange}
                  required
                  placeholder="Brief description of the activity"
                  rows="3"
                />
              </div>

              <div className="form-row">
                <div className="form-group">
                  <label htmlFor="category">Category</label>
                  <select
                    id="category"
                    name="category"
                    value={formData.category}
                    onChange={handleInputChange}
                  >
                    <option value="">Select category</option>
                    {categories.map(category => (
                      <option key={category} value={category}>{category}</option>
                    ))}
                  </select>
                </div>

                <div className="form-group">
                  <label htmlFor="difficulty">Difficulty Level</label>
                  <select
                    id="difficulty"
                    name="difficulty"
                    value={formData.difficulty}
                    onChange={handleInputChange}
                  >
                    <option value="">Select difficulty</option>
                    {difficulties.map(difficulty => (
                      <option key={difficulty} value={difficulty}>{difficulty}</option>
                    ))}
                  </select>
                </div>
              </div>

              <div className="form-row">
                <div className="form-group">
                  <label htmlFor="duration">Duration</label>
                  <select
                    id="duration"
                    name="duration"
                    value={formData.duration}
                    onChange={handleInputChange}
                  >
                    <option value="">Select duration</option>
                    {durations.map(duration => (
                      <option key={duration} value={duration}>{duration}</option>
                    ))}
                  </select>
                </div>

                <div className="form-group">
                  <label htmlFor="image">Image URL</label>
                  <input
                    type="url"
                    id="image"
                    name="image"
                    value={formData.image}
                    onChange={handleInputChange}
                    placeholder="https://example.com/image.jpg"
                  />
                </div>
              </div>

              <div className="form-group">
                <label htmlFor="description">Full Description</label>
                <textarea
                  id="description"
                  name="description"
                  value={formData.description}
                  onChange={handleInputChange}
                  placeholder="Detailed description of the activity, instructions, benefits, etc."
                  rows="4"
                />
              </div>

              <div className="form-group">
                <label className="checkbox-label">
                  <input
                    type="checkbox"
                    name="requiresAuth"
                    checked={formData.requiresAuth}
                    onChange={handleInputChange}
                  />
                  Requires User Authentication
                </label>
              </div>

              <div className="form-group">
                <label>Additional Tags</label>
                {formData.tags.map((tag, index) => (
                  <div key={index} className="tag-input-group">
                    <input
                      type="text"
                      value={tag}
                      onChange={(e) => handleTagChange(index, e.target.value)}
                      placeholder="Enter tag (e.g., yoga, social, learning)"
                    />
                    {formData.tags.length > 1 && (
                      <button 
                        type="button" 
                        className="remove-tag"
                        onClick={() => removeTag(index)}
                      >
                        ×
                      </button>
                    )}
                  </div>
                ))}
                <button 
                  type="button" 
                  className="add-tag-btn"
                  onClick={addTag}
                >
                  + Add Tag
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
                  {loading ? 'Saving...' : (editingActivity ? 'Update Activity' : 'Create Activity')}
                </button>
              </div>
            </form>
          </div>
          
        </div>
      )}
    <div style={{marginTop: '100px'}}><Footer /></div>
      
    </div>
  );
}

export default AdminActivitiesPage;