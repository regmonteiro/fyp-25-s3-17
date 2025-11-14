import React, { useState, useEffect } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { FiBell, FiCheckCircle, FiTrash2, FiFilter, FiArrowLeft } from 'react-icons/fi';
import { ToastContainer, toast } from 'react-toastify';
import 'react-toastify/dist/ReactToastify.css';
import NotificationsCaregiverController from '../controller/notificationsCaregiverController';
import './receiveNotificationsCaregiver.css';

const NotificationsPage = () => {
  const [notifications, setNotifications] = useState([]);
  const [filter, setFilter] = useState('all');
  const [loading, setLoading] = useState(true);
  const [emailKey, setEmailKey] = useState('');
  const navigate = useNavigate();

  useEffect(() => {
    const loggedInEmail = localStorage.getItem('loggedInEmail');
    
    if (!loggedInEmail) {
      navigate('/caregiver/login');
      return;
    }

    // Convert email to Firebase key format
    const formattedEmailKey = loggedInEmail.replace(/\./g, '_');
    setEmailKey(formattedEmailKey);

    console.log('Setting up notifications listener for:', formattedEmailKey);

    // Setup real-time notifications listener
    const unsubscribe = NotificationsCaregiverController.getCaregiverNotifications(
      formattedEmailKey,
      (notifs) => {
        console.log('Received notifications:', notifs);
        setNotifications(notifs);
        setLoading(false);
      }
    );

    return () => {
      if (unsubscribe) unsubscribe();
    };
  }, [navigate]);

  const filteredNotifications = notifications.filter(notif => {
    if (filter === 'all') return true;
    if (filter === 'unread') return !notif.read;
    return notif.type === filter;
  });

  const handleMarkAllAsRead = async () => {
    if (!emailKey) {
      toast.error('No user identified');
      return;
    }

    try {
      await NotificationsCaregiverController.markAllNotificationsAsRead(emailKey);
      toast.success('All notifications marked as read');
    } catch (error) {
      console.error('Error marking all as read:', error);
      toast.error('Failed to mark all as read');
    }
  };

  const handleDeleteAll = async () => {
    if (window.confirm('Are you sure you want to delete all notifications?')) {
      try {
        // Delete notifications one by one to avoid race conditions
        for (const notif of notifications) {
          await NotificationsCaregiverController.deleteNotification(notif.id);
        }
        toast.success('All notifications deleted');
      } catch (error) {
        console.error('Error deleting all notifications:', error);
        toast.error('Failed to delete notifications');
      }
    }
  };

  if (loading) {
    return (
      <div className="notifications-loading">
        <div className="loading-spinner"></div>
        <p>Loading notifications...</p>
      </div>
    );
  }

  return (
    <div className="notifications-page" >
      <div className="notifications-container">
        {/* Header */}
        <div className="notifications-header" style={{backgroundColor: '#00000033'}}>
          <button onClick={() => navigate('/caregiver/viewCaregiverDashboard')} className="back-btn">
            <FiArrowLeft />
            Back to Dashboard
          </button>
          <h1 style={{ color: '#3b82f6' }}>
            <FiBell /> Notifications
          </h1>
          <div className="header-stats">
            <span className="total-count">{notifications.length} total</span>
            <span className="unread-count">
              {notifications.filter(n => !n.read).length} unread
            </span>
          </div>
        </div>

        {/* Actions */}
        <div className="notifications-actions">
          <div className="filters">
            <button 
              className={`filter-btn ${filter === 'all' ? 'active' : ''}`}
              onClick={() => setFilter('all')}
            >
              All
            </button>
            <button 
              className={`filter-btn ${filter === 'unread' ? 'active' : ''}`}
              onClick={() => setFilter('unread')}
            >
              Unread
            </button>
            <button 
              className={`filter-btn ${filter === 'medication' ? 'active' : ''}`}
              onClick={() => setFilter('medication')}
            >
              Medications
            </button>
            <button 
              className={`filter-btn ${filter === 'appointment' ? 'active' : ''}`}
              onClick={() => setFilter('appointment')}
            >
              Appointments
            </button>
            <button 
              className={`filter-btn ${filter === 'routine' ? 'active' : ''}`}
              onClick={() => setFilter('routine')}
            >
              Routines
            </button>
          </div>
          
          <div className="bulk-actions">
            {notifications.filter(n => !n.read).length > 0 && (
              <button onClick={handleMarkAllAsRead} className="btn btn-primary">
                <FiCheckCircle /> Mark All Read
              </button>
            )}
            {notifications.length > 0 && (
              <button onClick={handleDeleteAll} className="btn btn-danger">
                <FiTrash2 /> Delete All
              </button>
            )}
          </div>
        </div>

        {/* Notifications List */}
        <div className="notifications-list">
          {filteredNotifications.length > 0 ? (
            filteredNotifications.map(notification => (
              <NotificationItem 
                key={notification.id} 
                notification={notification} 
                emailKey={emailKey}
              />
            ))
          ) : (
            <div className="no-notifications">
              <FiBell size={48} />
              <h3>No notifications found</h3>
              <p>
                {filter === 'all' 
                  ? "You don't have any notifications yet."
                  : `No ${filter} notifications found.`
                }
              </p>
            </div>
          )}
        </div>
      </div>
      <ToastContainer position="bottom-right" />
    </div>
  );
};

const NotificationItem = ({ notification, emailKey }) => {
  const [isRead, setIsRead] = useState(notification.read);

  const handleMarkAsRead = async () => {
    try {
      await NotificationsCaregiverController.markNotificationAsRead(notification.id);
      setIsRead(true);
      toast.success('Notification marked as read');
    } catch (error) {
      console.error('Error marking as read:', error);
      toast.error('Failed to mark as read');
    }
  };

  const handleDelete = async () => {
    if (window.confirm('Are you sure you want to delete this notification?')) {
      try {
        await NotificationsCaregiverController.deleteNotification(notification.id);
        toast.success('Notification deleted');
      } catch (error) {
        console.error('Error deleting notification:', error);
        toast.error('Failed to delete notification');
      }
    }
  };

  const getPriorityColor = (priority) => {
    switch (priority) {
      case 'critical': return '#dc3545';
      case 'high': return '#fd7e14';
      case 'medium': return '#ffc107';
      case 'low': return '#28a745';
      default: return '#6c757d';
    }
  };

  const getTypeIcon = (type) => {
    switch (type) {
      case 'medication':
      case 'medication_missed':
        return '💊';
      case 'appointment':
      case 'appointment_missed':
        return '📅';
      case 'routine':
      case 'routine_missed':
        return '🔄';
      case 'health_alert':
        return '❤️';
      default:
        return '🔔';
    }
  };

  const formatTime = (timestamp) => {
    try {
      const now = new Date();
      const notificationTime = new Date(timestamp);
      
      if (isNaN(notificationTime.getTime())) {
        return 'Unknown time';
      }
      
      const diffInHours = (now - notificationTime) / (1000 * 60 * 60);
      
      if (diffInHours < 1) {
        const diffInMinutes = Math.floor(diffInHours * 60);
        return `${diffInMinutes}m ago`;
      } else if (diffInHours < 24) {
        return `${Math.floor(diffInHours)}h ago`;
      } else {
        return notificationTime.toLocaleDateString();
      }
    } catch (error) {
      return 'Invalid time';
    }
  };

  return (
    <div className={`notification-item ${isRead ? 'read' : 'unread'}`}>
      <div 
        className="priority-indicator"
        style={{ backgroundColor: getPriorityColor(notification.priority) }}
      ></div>
      
      <div className="notification-icon">
        {getTypeIcon(notification.type)}
      </div>
      
      <div className="notification-content">
        <div className="notification-header">
          <h3>{notification.title || 'No Title'}</h3>
          <span className="notification-time">
            {formatTime(notification.timestamp)}
          </span>
        </div>
        
        <p className="notification-message">{notification.message || 'No message'}</p>
        
        {notification.elderlyName && (
          <div className="notification-source">
            From: {notification.elderlyName}
          </div>
        )}
        
        {notification.details && Object.keys(notification.details).length > 0 && (
          <div className="notification-details">
            {Object.entries(notification.details).map(([key, value]) => (
              <div key={key} className="detail-item">
                <strong>{key}:</strong> {String(value)}
              </div>
            ))}
          </div>
        )}
      </div>
      
      <div className="notification-actions">
        {!isRead && (
          <button 
            onClick={handleMarkAsRead}
            className="btn btn-success btn-sm"
            title="Mark as read"
          >
            <FiCheckCircle />
          </button>
        )}
        <button 
          onClick={handleDelete}
          className="btn btn-danger btn-sm"
          title="Delete notification"
        >
          <FiTrash2 />
        </button>
      </div>
    </div>
  );
};

export default NotificationsPage;