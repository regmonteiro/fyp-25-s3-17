// components/NotificationsWidget.js
import React, { useEffect, useState } from "react";
import { 
  fetchNotificationsForUser, 
  markNotificationRead, 
  getUnreadNotificationsCount 
} from "../controller/notificationsCaregiverController";
import { Bell, Clock, User, CheckCircle, ChevronRight, AlertTriangle } from "lucide-react";
import { useNavigate } from "react-router-dom";
import "./notificationsWidget.css";

function NotificationsWidget({ userId }) {
  const [notifications, setNotifications] = useState([]);
  const [unreadCount, setUnreadCount] = useState(0);
  const [loading, setLoading] = useState(true);
  const navigate = useNavigate();

  useEffect(() => {
    const loadNotifications = async () => {
      try {
        setLoading(true);
        const userNotifications = await fetchNotificationsForUser(userId);
        setNotifications(userNotifications.slice(0, 5)); // Show only latest 5
        
        const count = await getUnreadNotificationsCount(userId);
        setUnreadCount(count);
      } catch (error) {
        console.error("Error loading notifications:", error);
      } finally {
        setLoading(false);
      }
    };

    if (userId) {
      loadNotifications();
    }
  }, [userId]);

  const handleMarkAsRead = async (notificationId) => {
    try {
      await markNotificationRead(userId, notificationId);
      setNotifications(prev => 
        prev.map(n => 
          n.id === notificationId ? { ...n, isRead: true } : n
        )
      );
      setUnreadCount(prev => Math.max(prev - 1, 0));
    } catch (error) {
      console.error("Error marking notification as read:", error);
    }
  };

  const getNotificationIcon = (type) => {
    switch (type) {
      case 'medication': return <Bell size={16} />;
      case 'appointment': return <Clock size={16} />;
      case 'routine': return <CheckCircle size={16} />;
      case 'critical': return <AlertTriangle size={16} />;
      default: return <Bell size={16} />;
    }
  };

  const formatTime = (timestamp) => {
    if (!timestamp) return '';
    const date = timestamp instanceof Date ? timestamp : new Date(timestamp);
    const now = new Date();
    const diffInMinutes = Math.floor((now - date) / (1000 * 60));
    
    if (diffInMinutes < 1) return 'Just now';
    if (diffInMinutes < 60) return `${diffInMinutes}m ago`;
    if (diffInMinutes < 1440) return `${Math.floor(diffInMinutes / 60)}h ago`;
    return date.toLocaleDateString();
  };

  if (loading) {
    return (
      <div className="notifications-widget">
        <div className="widget-header">
          <h3 >Notifications</h3>
        </div>
        <div className="widget-loading">
          <div className="loading-spinner"></div>
          <p>Loading notifications...</p>
        </div>
      </div>
    );
  }

  return (
    <div className="notifications-widget">
      <div className="widget-header">
        <div className="header-title">
          <Bell size={20} />
          <h3>Notifications</h3>
          {unreadCount > 0 && (
            <span className="unread-badge">{unreadCount}</span>
          )}
        </div>
        <button 
          className="view-all-btn"
          onClick={() => navigate('/notifications')}
        >
          View All
        </button>
      </div>

      <div className="notifications-list">
        {notifications.length === 0 ? (
          <div className="empty-state">
            <Bell size={32} />
            <p>No notifications</p>
          </div>
        ) : (
          notifications.map(notification => (
            <div 
              key={notification.id} 
              className={`notification-item ${notification.isRead ? 'read' : 'unread'}`}
            >
              <div className="notification-icon">
                {getNotificationIcon(notification.type)}
              </div>
              <div className="notification-content">
                <h4 className="notification-title">{notification.title}</h4>
                <p className="notification-message">{notification.message}</p>
                <div className="notification-meta">
                  <span className="notification-time">
                    {formatTime(notification.timestamp)}
                  </span>
                  {notification.elderlyName && (
                    <>
                      <span className="meta-separator">•</span>
                      <span className="notification-recipient">
                        <User size={12} />
                        {notification.elderlyName}
                      </span>
                    </>
                  )}
                </div>
              </div>
              {!notification.isRead && (
                <button 
                  className="mark-read-btn"
                  onClick={() => handleMarkAsRead(notification.id)}
                  title="Mark as read"
                >
                  <CheckCircle size={16} />
                </button>
              )}
            </div>
          ))
        )}
      </div>

      {notifications.length > 0 && (
        <div className="widget-footer">
          <button 
            className="view-all-link"
            onClick={() => navigate('/notifications')}
          >
            View all notifications <ChevronRight size={16} />
          </button>
        </div>
      )}
    </div>
  );
}

export default NotificationsWidget;