import React, { useState, useEffect } from 'react';
import { Plus, Clock, Pill, Utensils, Coffee, Moon, Heart, User, Check, X, Edit3, Trash2, AlertTriangle, Users } from 'lucide-react';
import { 
  createCareRoutineTemplate, 
  getUserCareRoutineTemplates, 
  assignRoutineToElderly, 
  getLinkedElderlyUsers,
  getLinkedElderlyId,
  subscribeToUserTemplates,
  deleteCareRoutineTemplate,
  isTemplateAssigned,
  getAssignedRoutines,
  removeAssignedRoutine,
  subscribeToAssignedRoutines,
  getCurrentUserType
} from '../controller/careRoutineTemplateController';
import "./setCareRoutineTemplate.css";

const CareRoutineTemplate = () => {
  const [currentStep, setCurrentStep] = useState('templates');
  const [templates, setTemplates] = useState([]);
  const [assignedTemplates, setAssignedTemplates] = useState([]);
  const [newTemplate, setNewTemplate] = useState({ name: '', description: '', items: [] });
  const [linkedUsers, setLinkedUsers] = useState([]);
  const [selectedUser, setSelectedUser] = useState(null);
  const [selectedTemplate, setSelectedTemplate] = useState(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [success, setSuccess] = useState('');
  const [deleteConfirm, setDeleteConfirm] = useState(null);
  const [unassignConfirm, setUnassignConfirm] = useState(null);
  const [currentUserType, setCurrentUserType] = useState('');

  const routineTypes = [
    { type: 'medication', icon: Pill, color: 'bg-medication', label: 'Medication' },
    { type: 'meal', icon: Utensils, color: 'bg-meal', label: 'Meal' },
    { type: 'rest', icon: Moon, color: 'bg-rest', label: 'Rest/Activity' },
    { type: 'entertainment', icon: Heart, color: 'bg-entertainment', label: 'Entertainment' }
  ];

  useEffect(() => {
    initializeUserData();
  }, []);

  const initializeUserData = async () => {
    try {
      setLoading(true);
      
      // Get current user type first
      const userType = await getCurrentUserType();
      setCurrentUserType(userType);
      
      // Load data based on user type
      await loadLinkedUsers();
      await loadTemplates();
      await loadAssignedTemplates();
      
      // Subscribe to template changes
      const unsubscribe = subscribeToUserTemplates((templates) => {
        setTemplates(templates);
      });
      
      return () => unsubscribe();
    } catch (err) {
      console.error('Error initializing user data:', err);
      setError(err.message || 'Failed to load user data');
    } finally {
      setLoading(false);
    }
  };

  const loadLinkedUsers = async () => {
    try {
      setError('');
      const users = await getLinkedElderlyUsers();
      setLinkedUsers(users);
      
      // Auto-select for elderly users (themselves)
      if (currentUserType === 'elderly' && users.length > 0) {
        setSelectedUser(users[0]);
      }
      
      if (users.length === 0 && currentUserType === 'caregiver') {
        setError('No elderly users are linked to your account. Please link an elderly user first.');
      }
    } catch (err) {
      console.error('Error loading linked users:', err);
      setError(err.message || 'Failed to load linked users');
    }
  };

  const loadTemplates = async () => {
    try {
      const userTemplates = await getUserCareRoutineTemplates();
      setTemplates(userTemplates);
    } catch (err) {
      console.error('Error loading templates:', err);
      setError(err.message || 'Failed to load templates');
    }
  };

  const loadAssignedTemplates = async () => {
    try {
      let assigned = [];
      
      if (currentUserType === 'caregiver') {
        // For caregivers, load assigned templates for all linked users
        for (const user of linkedUsers) {
          const userAssigned = await getAssignedRoutines(user.id);
          assigned.push(...userAssigned.map(item => ({
            ...item,
            elderlyUser: user
          })));
        }
      } else if (currentUserType === 'elderly') {
        // For elderly, load their own assigned templates
        const elderlyId = await getLinkedElderlyId();
        const userAssigned = await getAssignedRoutines(elderlyId);
        assigned = userAssigned.map(item => ({
          ...item,
          elderlyUser: {
            id: elderlyId,
            name: 'Me',
            relationship: 'Self'
          }
        }));
      }
      
      setAssignedTemplates(assigned);
    } catch (err) {
      console.error('Error loading assigned templates:', err);
    }
  };

  const addTemplateItem = (type) => {
    const newItem = {
      type,
      time: '',
      title: '',
      description: ''
    };
    setNewTemplate(prev => ({
      ...prev,
      items: [...prev.items, newItem]
    }));
  };

  const updateTemplateItem = (index, field, value) => {
    setNewTemplate(prev => ({
      ...prev,
      items: prev.items.map((item, i) => 
        i === index ? { ...item, [field]: value } : item
      )
    }));
  };

  const removeTemplateItem = (index) => {
    setNewTemplate(prev => ({
      ...prev,
      items: prev.items.filter((_, i) => i !== index)
    }));
  };

  const createTemplate = async () => {
    try {
      setLoading(true);
      setError('');
      setSuccess('');
      
      if (!newTemplate.name.trim()) {
        throw new Error('Template name is required');
      }
      if (newTemplate.items.length === 0) {
        throw new Error('Please add at least one activity to the template');
      }
      
      for (let i = 0; i < newTemplate.items.length; i++) {
        const item = newTemplate.items[i];
        if (!item.time.trim()) {
          throw new Error(`Activity ${i + 1}: Time is required`);
        }
        if (!item.title.trim()) {
          throw new Error(`Activity ${i + 1}: Title is required`);
        }
      }
      
      await createCareRoutineTemplate(newTemplate);
      setNewTemplate({ name: '', description: '', items: [] });
      setSuccess('Routine template created successfully!');
      setCurrentStep('templates');
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  };

  const handleDeleteTemplate = async (templateId, templateName) => {
    try {
      setLoading(true);
      setError('');
      setSuccess('');
      
      await deleteCareRoutineTemplate(templateId);
      setSuccess(`Routine template "${templateName}" deleted successfully!`);
      setDeleteConfirm(null);
      await loadTemplates();
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  };

  const handleUnassignTemplate = async (assignment) => {
    try {
      setLoading(true);
      setError('');
      setSuccess('');
      
      await removeAssignedRoutine(assignment.elderlyId, assignment.templateId);
      setSuccess(`Routine "${assignment.templateData.name}" has been unassigned!`);
      setUnassignConfirm(null);
      await loadAssignedTemplates();
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  };

  const openDeleteConfirm = async (template) => {
    try {
      const isAssigned = await isTemplateAssigned(template.id);
      
      if (isAssigned) {
        setError(`Cannot delete "${template.name}" because it is currently assigned. Please unassign it first.`);
        return;
      }
      
      setDeleteConfirm(template);
    } catch (err) {
      setError(err.message);
    }
  };

  const assignTemplate = async () => {
    try {
      setLoading(true);
      setError('');
      setSuccess('');
      
      if (!selectedUser || !selectedTemplate) {
        throw new Error('Please select both a user and a template');
      }
      
      await assignRoutineToElderly(selectedUser.id, selectedTemplate.id);
      
      let successMessage = '';
      if (currentUserType === 'elderly') {
        successMessage = `Routine "${selectedTemplate.name}" has been assigned to your schedule!`;
      } else {
        successMessage = `Routine "${selectedTemplate.name}" has been assigned to ${selectedUser.name}!`;
      }
      
      setSuccess(successMessage);
      setCurrentStep('templates');
      setSelectedUser(null);
      setSelectedTemplate(null);
      await loadAssignedTemplates();
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  };

  const getTypeIcon = (type) => {
    const typeConfig = routineTypes.find(t => t.type === type);
    return typeConfig ? typeConfig.icon : Clock;
  };

  const getTypeColor = (type) => {
    const typeConfig = routineTypes.find(t => t.type === type);
    return typeConfig ? typeConfig.color : 'bg-default';
  };

  // Clear messages after 5 seconds
  useEffect(() => {
    if (error || success) {
      const timer = setTimeout(() => {
        setError('');
        setSuccess('');
      }, 5000);
      return () => clearTimeout(timer);
    }
  }, [error, success]);

  // Show different UI based on user type
  const isElderly = currentUserType === 'elderly';
  const isCaregiver = currentUserType === 'caregiver';

  if (loading && templates.length === 0 && linkedUsers.length === 0) {
    return (
      <div className="care-routine-container flex items-center justify-center">
        <div className="text-center">
          <div className="spinner mx-auto border-blue-500"></div>
          <p className="mt-4 text-gray-600">Loading care routines...</p>
        </div>
      </div>
    );
  }

  return (
    <div className="care-routine-container">
      {/* Header */}
      <div className="care-routine-header">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="py-6">
            <h1 className="care-routine-title">
              <div className="p-2 bg-blue-500 rounded-xl text-white">
                <Clock className="w-8 h-8" />
              </div>
              {isElderly ? 'My Daily Routine' : 'Care Routine Management'}
            </h1>
            <p className="care-routine-subtitle">
              {isElderly 
                ? 'Manage your daily schedule and routines' 
                : 'Create and assign daily care routines for your loved ones'
              }
            </p>
          </div>
        </div>
      </div>

      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        {error && (
          <div className="alert alert-error mb-6">
            <AlertTriangle className="w-5 h-5" />
            {error}
          </div>
        )}

        {success && (
          <div className="alert alert-success mb-6">
            <Check className="w-5 h-5" />
            {success}
          </div>
        )}

        {/* Navigation Steps - Simplified for elderly users */}
        <div className="step-nav">
          <button
            onClick={() => setCurrentStep('templates')}
            className={`step-button ${currentStep === 'templates' ? 'active' : 'inactive'}`}
          >
            {isElderly ? 'My Templates' : 'Routine Templates'}
          </button>
          <div className="step-divider"></div>
          <button
            onClick={() => setCurrentStep('create')}
            className={`step-button ${currentStep === 'create' ? 'active' : 'inactive'}`}
          >
            Create New
          </button>
          {isCaregiver && (
            <>
              <div className="step-divider"></div>
              <button
                onClick={() => setCurrentStep('assign')}
                className={`step-button ${currentStep === 'assign' ? 'active' : 'inactive'}`}
              >
                Assign Routine
              </button>
            </>
          )}
          <div className="step-divider"></div>
          <button
            onClick={() => setCurrentStep('assigned')}
            className={`step-button ${currentStep === 'assigned' ? 'active' : 'inactive'}`}
          >
            {isElderly ? 'My Schedule' : 'Assigned Routines'}
          </button>
        </div>

        {/* Delete Confirmation Modal */}
        {deleteConfirm && (
          <div className="modal-overlay">
            <div className="modal-content">
              <div className="modal-header">
                <AlertTriangle className="w-6 h-6 text-red-500" />
                <h3 className="modal-title">Delete Routine Template</h3>
              </div>
              <div className="modal-body">
                <p>Are you sure you want to delete the routine template <strong>"{deleteConfirm.name}"</strong>?</p>
                <p className="text-sm text-gray-600 mt-2">This action cannot be undone.</p>
              </div>
              <div className="modal-actions">
                <button
                  onClick={() => setDeleteConfirm(null)}
                  className="secondary-button"
                  disabled={loading}
                >
                  Cancel
                </button>
                <button
                  onClick={() => handleDeleteTemplate(deleteConfirm.id, deleteConfirm.name)}
                  className="delete-button"
                  disabled={loading}
                >
                  {loading ? (
                    <>
                      <div className="spinner border-white"></div>
                      Deleting...
                    </>
                  ) : (
                    <>
                      <Trash2 className="w-4 h-4" />
                      Delete Template
                    </>
                  )}
                </button>
              </div>
            </div>
          </div>
        )}

        {/* Unassign Confirmation Modal */}
        {unassignConfirm && (
          <div className="modal-overlay">
            <div className="modal-content">
              <div className="modal-header">
                <AlertTriangle className="w-6 h-6 text-orange-500" />
                <h3 className="modal-title">Unassign Routine</h3>
              </div>
              <div className="modal-body">
                <p>Are you sure you want to unassign the routine <strong>"{unassignConfirm.templateData.name}"</strong>?</p>
                <p className="text-sm text-gray-600 mt-2">This will remove the routine from your schedule.</p>
              </div>
              <div className="modal-actions">
                <button
                  onClick={() => setUnassignConfirm(null)}
                  className="secondary-button"
                  disabled={loading}
                >
                  Cancel
                </button>
                <button
                  onClick={() => handleUnassignTemplate(unassignConfirm)}
                  className="unassign-button-modal"
                  disabled={loading}
                >
                  {loading ? (
                    <>
                      <div className="spinner border-white"></div>
                      Unassigning...
                    </>
                  ) : (
                    <>
                      <Users className="w-4 h-4" />
                      Unassign Routine
                    </>
                  )}
                </button>
              </div>
            </div>
          </div>
        )}

        {/* Templates View */}
        {currentStep === 'templates' && (
          <div className="space-y-6">
            <div className="flex items-center justify-between">
              <h2 className="form-title">
                {isElderly ? 'My Routine Templates' : 'Routine Templates'}
              </h2>
              <button
                onClick={() => setCurrentStep('create')}
                className="primary-button"
              >
                <Plus className="w-5 h-5" />
                Create New Template
              </button>
            </div>

            {templates.length === 0 ? (
              <div className="empty-state">
                <Clock className="empty-icon mb-4" />
                <h3 className="text-xl font-semibold text-gray-700 mb-2">
                  {isElderly ? 'No Templates Created Yet' : 'No Templates Yet'}
                </h3>
                <p className="text-gray-500 mb-6">
                  {isElderly 
                    ? 'Create your first routine template to organize your daily schedule'
                    : 'Create your first care routine template to get started'
                  }
                </p>
                <button
                  onClick={() => setCurrentStep('create')}
                  className="primary-button"
                >
                  Create Your First Template
                </button>
              </div>
            ) : (
              <div className="template-grid">
                {templates.map(template => (
                  <div key={template.id} className="template-card">
                    <div className="template-header">
                      <div>
                        <h3 className="text-xl font-bold">{template.name}</h3>
                        {template.description && (
                          <p className="text-sm text-gray-600 mt-1">{template.description}</p>
                        )}
                      </div>
                      <div className="template-actions">
                        <button
                          onClick={() => openDeleteConfirm(template)}
                          className="action-button delete"
                          title="Delete template"
                        >
                          <Trash2 className="w-4 h-4" />
                        </button>
                      </div>
                    </div>
                    <div className="template-content">
                      <p className="text-sm text-blue-600 mb-3">{template.items.length} activities</p>
                      {template.items.slice(0, 3).map((item, index) => {
                        const Icon = getTypeIcon(item.type);
                        return (
                          <div key={index} className="template-activity">
                            <div className={`activity-icon ${getTypeColor(item.type)}`}>
                              <Icon className="w-4 h-4" />
                            </div>
                            <div className="activity-details">
                              <p className="activity-title">{item.title}</p>
                              <p className="activity-time">{item.time}</p>
                            </div>
                          </div>
                        );
                      })}
                      {template.items.length > 3 && (
                        <p className="text-sm text-gray-500 text-center mt-2">
                          +{template.items.length - 3} more activities
                        </p>
                      )}
                    </div>
                    <div className="template-footer">
                      <button
                        onClick={() => {
                          setSelectedTemplate(template);
                          if (isElderly) {
                            // Auto-assign to self for elderly users
                            assignTemplate();
                          } else {
                            setCurrentStep('assign');
                          }
                        }}
                        className="assign-button"
                      >
                        {isElderly ? 'Add to My Schedule' : 'Assign Routine'}
                      </button>
                    </div>
                  </div>
                ))}
              </div>
            )}
          </div>
        )}

        {/* Create Template View */}
        {currentStep === 'create' && (
          <div className="space-y-8">
            <div className="form-container">
              <h2 className="form-title">Create New Routine Template</h2>
              
              <div className="mb-6">
                <label className="form-label">Template Name</label>
                <input
                  type="text"
                  value={newTemplate.name}
                  onChange={(e) => setNewTemplate(prev => ({ ...prev, name: e.target.value }))}
                  placeholder="Enter template name (e.g., Morning Routine)"
                  className="form-input"
                />
              </div>

              <div className="mb-6">
                <label className="form-label">Description (Optional)</label>
                <textarea
                  value={newTemplate.description}
                  onChange={(e) => setNewTemplate(prev => ({ ...prev, description: e.target.value }))}
                  placeholder="Describe this routine template"
                  rows={2}
                  className="form-input"
                />
              </div>

              <div className="mb-8">
                <h3 className="form-label">Add Activities</h3>
                <div className="activity-types">
                  {routineTypes.map(({ type, icon: Icon, color, label }) => (
                    <button
                      key={type}
                      onClick={() => addTemplateItem(type)}
                      className="activity-type-button"
                    >
                      <div className={`activity-type-icon ${color}`}>
                        <Icon className="w-6 h-6" />
                      </div>
                      <p className="activity-type-label">{label}</p>
                    </button>
                  ))}
                </div>
              </div>

              {/* Template Items */}
              {newTemplate.items.length > 0 && (
                <div className="space-y-4 mb-8">
                  <h3 className="form-label">Routine Activities</h3>
                  {newTemplate.items.map((item, index) => {
                    const Icon = getTypeIcon(item.type);
                    return (
                      <div key={index} className="activity-item">
                        <div className="flex items-start gap-4">
                          <div className={`activity-icon ${getTypeColor(item.type)} flex-shrink-0 mt-1`}>
                            <Icon className="w-5 h-5" />
                          </div>
                          <div className="activity-item-grid">
                            <div>
                              <label className="form-label">Time</label>
                              <input
                                type="time"
                                value={item.time}
                                onChange={(e) => updateTemplateItem(index, 'time', e.target.value)}
                                className="form-input"
                                required
                              />
                            </div> 
                            <div style={{marginLeft: "50px"}}>
                              <label className="form-label">Title</label>
                              <input
                                type="text"
                                value={item.title}
                                onChange={(e) => updateTemplateItem(index, 'title', e.target.value)}
                                placeholder="Activity title"
                                className="form-input"
                                required
                              />
                            </div>
                            <div style={{marginLeft: "50px"}}>
                              <label className="form-label">Description</label>
                              <input
                                type="text"
                                value={item.description}
                                onChange={(e) => updateTemplateItem(index, 'description', e.target.value)}
                                placeholder="Additional notes"
                                className="form-input"
                              />
                            </div>
                          </div>
                          <button
                            onClick={() => removeTemplateItem(index)}
                            className="text-red-500 hover:text-red-700 p-2 hover:bg-red-50 rounded-lg transition-all flex-shrink-0"
                          >
                            <X className="w-5 h-5" />
                          </button>
                        </div>
                      </div>
                    );
                  })}
                </div>
              )}

              <div className="form-button-group">
                <button
                  onClick={() => setCurrentStep('templates')}
                  className="secondary-button"
                >
                  Cancel
                </button>
                <button
                  onClick={createTemplate}
                  disabled={!newTemplate.name || newTemplate.items.length === 0 || loading}
                  className="primary-button"
                >
                  {loading ? (
                    <>
                      <div className="spinner border-white"></div>
                      Creating...
                    </>
                  ) : (
                    <>
                      <Plus className="w-5 h-5" />
                      Create Routine
                    </>
                  )}
                </button>
              </div>
            </div>
          </div>
        )}

        {/* Assign Template View - Only for caregivers */}
        {currentStep === 'assign' && isCaregiver && (
          <div className="space-y-8">
            <div className="form-container">
              <h2 className="form-title">Assign Routine to User</h2>

              {/* Select User */}
              <div className="mb-8">
                <h3 className="form-label">Select Linked User</h3>
                {linkedUsers.length === 0 ? (
                  <div className="alert alert-warning text-center">
                    <User className="empty-icon mx-auto mb-4" />
                    <h4 className="font-semibold mb-2">No Linked Users</h4>
                    <p className="mb-4">You need to be linked to an elderly user to assign routines.</p>
                    <button
                      onClick={loadLinkedUsers}
                      className="secondary-button"
                    >
                      Retry Loading Users
                    </button>
                  </div>
                ) : (
                  <div className="user-grid">
                    {linkedUsers.map(user => (
                      <button
                        key={user.id}
                        onClick={() => setSelectedUser(user)}
                        className={`user-button ${selectedUser?.id === user.id ? 'selected' : ''}`}
                      >
                        <div className="flex items-center gap-4">
                          <div className="user-icon">
                            <User className="w-6 h-6" />
                          </div>
                          <div>
                            <h4 className="font-semibold text-gray-900">{user.name}</h4>
                            <p className="text-sm text-gray-600">Age {user.age} • {user.relationship}</p>
                          </div>
                          {selectedUser?.id === user.id && (
                            <Check className="w-5 h-5 text-blue-500 ml-auto" />
                          )}
                        </div>
                      </button>
                    ))}
                  </div>
                )}
              </div>

              {/* Select Template */}
              {selectedUser && templates.length > 0 && (
                <div className="mb-8">
                  <h3 className="form-label">Select Routine Template</h3>
                  <div className="user-grid">
                    {templates.map(template => (
                      <button
                        key={template.id}
                        onClick={() => setSelectedTemplate(template)}
                        className={`user-button ${selectedTemplate?.id === template.id ? 'selected' : ''}`}
                      >
                        <div className="flex items-start justify-between">
                          <div>
                            <h4 className="font-semibold text-gray-900">{template.name}</h4>
                            <p className="text-sm text-gray-600 mb-3">{template.items.length} activities</p>
                            <div className="space-y-2">
                              {template.items.slice(0, 2).map((item, index) => (
                                <div key={index} className="flex items-center gap-2">
                                  <div className={`p-1 rounded ${getTypeColor(item.type)}`}>
                                    {React.createElement(getTypeIcon(item.type), { className: "w-3 h-3" })}
                                  </div>
                                  <span className="text-xs text-gray-600">{item.time} - {item.title}</span>
                                </div>
                              ))}
                              {template.items.length > 2 && (
                                <p className="text-xs text-gray-500">+{template.items.length - 2} more</p>
                              )}
                            </div>
                          </div>
                          {selectedTemplate?.id === template.id && (
                            <Check className="w-5 h-5 text-blue-500" />
                          )}
                        </div>
                      </button>
                    ))}
                  </div>
                </div>
              )}

              {selectedUser && templates.length === 0 && (
                <div className="alert alert-warning text-center mb-8">
                  <Clock className="empty-icon mx-auto mb-4" />
                  <h4 className="font-semibold mb-2">No Templates Available</h4>
                  <p className="mb-4">Create a routine template first before assigning.</p>
                  <button
                    onClick={() => setCurrentStep('create')}
                    className="primary-button"
                  >
                    Create Template
                  </button>
                </div>
              )}

              {/* Confirmation */}
              {selectedUser && selectedTemplate && (
                <div className="confirmation-box">
                  <h3 className="font-semibold text-gray-900 mb-2">Assignment Confirmation</h3>
                  <p className="text-gray-700">
                    You are about to assign the <strong>"{selectedTemplate.name}"</strong> routine to{' '}
                    <strong>{selectedUser.name}</strong>. This routine contains {selectedTemplate.items.length} activities.
                  </p>
                </div>
              )}

              <div className="form-button-group">
                <button
                  onClick={() => setCurrentStep('templates')}
                  className="secondary-button"
                >
                  Cancel
                </button>
                <button
                  onClick={assignTemplate}
                  disabled={!selectedUser || !selectedTemplate || loading}
                  className="primary-button"
                >
                  {loading ? (
                    <>
                      <div className="spinner border-white"></div>
                      Assigning...
                    </>
                  ) : (
                    'Confirm Assignment'
                  )}
                </button>
              </div>
            </div>
          </div>
        )}

        {/* Assigned Routines View */}
        {currentStep === 'assigned' && (
          <div className="space-y-6">
            <div className="flex items-center justify-between">
              <h2 className="form-title">
                {isElderly ? 'My Daily Schedule' : 'Assigned Routines'}
              </h2>
              <button
                onClick={loadAssignedTemplates}
                className="secondary-button"
              >
                Refresh
              </button>
            </div>

            {assignedTemplates.length === 0 ? (
              <div className="empty-state">
                <Users className="empty-icon mb-4" />
                <h3 className="text-xl font-semibold text-gray-700 mb-2">
                  {isElderly ? 'No Routines Scheduled' : 'No Assigned Routines'}
                </h3>
                <p className="text-gray-500 mb-6">
                  {isElderly 
                    ? 'Assign routines to your schedule to see them here'
                    : 'Assign routines to elderly users to see them here'
                  }
                </p>
                <button
                  onClick={() => setCurrentStep(isElderly ? 'templates' : 'assign')}
                  className="primary-button"
                >
                  {isElderly ? 'Add Routine to Schedule' : 'Assign Routine'}
                </button>
              </div>
            ) : (
              <div className="space-y-4">
                {assignedTemplates.map((assignment) => (
                  <div key={`${assignment.elderlyId}-${assignment.templateId}`} className="assigned-template-item">
                    <div className="assigned-template-header">
                      <div>
                        <h3 className="assigned-template-name">{assignment.templateData.name}</h3>
                        <p className="assigned-template-user">
                          {isElderly ? (
                            <>Assigned on: {new Date(assignment.assignedAt).toLocaleDateString()}</>
                          ) : (
                            <>
                              Assigned to: <strong>{assignment.elderlyUser.name}</strong> • 
                              Assigned on: {new Date(assignment.assignedAt).toLocaleDateString()}
                            </>
                          )}
                        </p>
                      </div>
                      <span className="assignment-status assigned">
                        <Check className="w-3 h-3" />
                        Active
                      </span>
                    </div>
                    
                    <div className="space-y-2">
                      {assignment.templateData.items.map((item, index) => {
                        const Icon = getTypeIcon(item.type);
                        return (
                          <div key={index} className="flex items-center gap-3 text-sm">
                            <div className={`p-1 rounded ${getTypeColor(item.type)}`}>
                              <Icon className="w-3 h-3 text-white" />
                            </div>
                            <span className="text-gray-600">{item.time}</span>
                            <span className="font-medium">{item.title}</span>
                            {item.description && (
                              <span className="text-gray-500">- {item.description}</span>
                            )}
                          </div>
                        );
                      })}
                    </div>

                    <div className="assigned-template-actions">
                      <button
                        onClick={() => setUnassignConfirm(assignment)}
                        className="unassign-button"
                      >
                        <Users className="w-4 h-4" />
                        {isElderly ? 'Remove from Schedule' : 'Unassign Routine'}
                      </button>
                    </div>
                  </div>
                ))}
              </div>
            )}
          </div>
        )}
      </div>
    </div>
  );
};

export default CareRoutineTemplate;