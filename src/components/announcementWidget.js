// AnnouncementsWidget.js
import React, { useEffect, useState } from "react";
import { 
  getUnreadCount, 
  fetchAnnouncementsForUser, 
  markAnnouncementRead, 
  listenToNewAnnouncements 
} from "../controller/announcementController";
import { toast } from "react-toastify";
import "react-toastify/dist/ReactToastify.css";
import { Link, useNavigate } from "react-router-dom";  // ⬅️ added useNavigate
import { 
  FiBell, 
  FiCheckCircle, 
  FiChevronRight, 
  FiClock, 
  FiUsers, 
  FiAlertCircle 
} from "react-icons/fi";
import "./announcementswidget.css";

function AnnouncementsWidget({ uid }) {
  const [announcements, setAnnouncements] = useState([]);
  const [unreadCount, setUnreadCount] = useState(0);
  const [loading, setLoading] = useState(true);
  const [userType, setUserType] = useState(null);
  const navigate = useNavigate();   // ⬅️ navigation hook

  // Get user type from localStorage or user data
  useEffect(() => {
    const getUserType = () => {
      const storedUserType = localStorage.getItem('userType');
      if (storedUserType) {
        setUserType(storedUserType);
        return;
      }

      const loggedInEmail = localStorage.getItem('loggedInEmail');
      if (loggedInEmail) {
        let determinedType = 'elderly';
        
        if (loggedInEmail.includes('admin') || loggedInEmail.includes('helloworld2')) {
          determinedType = 'admin';
        } else if (loggedInEmail.includes('caregiver')) {
          determinedType = 'caregiver';
        } else if (loggedInEmail.includes('elderly') || loggedInEmail.includes('helloworld3')) {
          determinedType = 'elderly';
        }
        
        setUserType(determinedType);
        localStorage.setItem('userType', determinedType);
      } else {
        setUserType(null);
      }
    };

    getUserType();
  }, []);

  // Load announcements + unread count
  useEffect(() => {
    async function load() {
      if (!userType) {
        setLoading(false);
        return;
      }
      
      try {
        setLoading(true);
        const anns = await fetchAnnouncementsForUser(userType);
        setAnnouncements(anns);

        const count = await getUnreadCount(uid, userType);
        setUnreadCount(count);
      } catch (error) {
        console.error("Error loading announcements:", error);
      } finally {
        setLoading(false);
      }
    }
    
    if (userType) {
      load();
    }
  }, [uid, userType]);

  // Real-time listener
  useEffect(() => {
    if (!userType) return;
    
    const handleNewAnnouncements = (newAnnouncements) => {
      setAnnouncements(newAnnouncements);
      
      // Check if any new announcement is unread
      const newUnread = newAnnouncements.filter(a => !a.readBy || !a.readBy[uid]).length;
      if (newUnread > unreadCount) {
        toast.info(`📢 New announcement available!`, { 
          position: "top-right", 
          autoClose: 10000,
          onClick: () => navigate("/announcements")  // ⬅️ redirect on click
        });
      }
    };
    
    const unsubscribe = listenToNewAnnouncements(userType, handleNewAnnouncements);
    
    return () => {
      if (unsubscribe && typeof unsubscribe === 'function') {
        unsubscribe();
      }
    };
  }, [userType, uid, unreadCount, navigate]);

  const handleMarkRead = async (id) => {
    try {
      await markAnnouncementRead(uid, id);
      setAnnouncements(prev =>
        prev.map(a => a.id === id ? { 
          ...a, 
          readBy: { ...(a.readBy || {}), [uid]: true } 
        } : a)
      );
      setUnreadCount(prev => Math.max(prev - 1, 0));
      toast.success("Marked as read!");
    } catch (error) {
      console.error("Error marking as read:", error);
      toast.error("Failed to mark as read");
    }
  };

  const formatDate = (dateString) => {
    return new Date(dateString).toLocaleDateString('en-US', {
      month: 'short',
      day: 'numeric',
      year: 'numeric'
    });
  };

  // Get the latest announcement (most recent)
  const getLatestAnnouncement = () => {
    if (announcements.length === 0) return null;
    
    // Sort by date to get the latest one
    const sorted = [...announcements].sort((a, b) => 
      new Date(b.createdAt) - new Date(a.createdAt)
    );
    
    return sorted[0]; // Return the first (latest) announcement
  };

  const latestAnnouncement = getLatestAnnouncement();

  if (!userType) {
    return (
      <div className="announcements-widget">
        <div className="widget-header">
          <h3><FiBell /> Announcements</h3>
        </div>
        <div className="widget-error">
          <FiAlertCircle size={24} />
          <p>User information not available</p>
        </div>
      </div>
    );
  }

  if (loading) {
    return (
      <div className="announcements-widget">
        <div className="widget-header">
          <h3><FiBell /> Announcements</h3>
        </div>
        <div className="widget-loading">
          <div className="loading-spinner"></div>
          <p>Loading announcements...</p>
        </div>
      </div>
    );
  }

  return (
    <div className="announcements-widget">
      <div className="widget-header">
        <div className="header-content">
          <h3><FiBell /> Announcements</h3>
          {unreadCount > 0 && (
            <span className="unread-badge">{unreadCount}</span>
          )}
        </div>
        <p className="widget-subtitle">Latest updates and important information</p>
      </div>

      <div className="announcements-content">
        {!latestAnnouncement ? (
          <div className="empty-state">
            <FiBell size={48} />
            <h4>No Announcements</h4>
            <p>There are no announcements at this time.</p>
          </div>
        ) : (
          <div className="announcements-list">
            <div 
              key={latestAnnouncement.id} 
              className={`announcement-item ${latestAnnouncement.readBy && latestAnnouncement.readBy[uid] ? 'read' : 'unread'}`}
            >
              {!(latestAnnouncement.readBy && latestAnnouncement.readBy[uid]) && <div className="unread-dot"></div>}
              <div className="announcement-content">
                <h4 className="announcement-title">{latestAnnouncement.title}</h4>
                <p className="announcement-description">{latestAnnouncement.description}</p>
                <div className="announcement-meta">
                  <span className="meta-item">
                    <FiUsers /> {Array.isArray(latestAnnouncement.userGroups) ? latestAnnouncement.userGroups.join(", ") : "All users"}
                  </span>
                  <span className="meta-item">
                    <FiClock /> {formatDate(latestAnnouncement.createdAt)}
                  </span>
                </div>
              </div>
              {!(latestAnnouncement.readBy && latestAnnouncement.readBy[uid]) && (
                <button 
                  className="mark-read-btn"
                  onClick={() => handleMarkRead(latestAnnouncement.id)}
                  title="Mark as read"
                >
                  <FiCheckCircle />
                </button>
              )}
            </div>
          </div>
        )}
      </div>

      <Link to="/announcements" className="view-all-link">
        View All Announcements <FiChevronRight />
      </Link>
    </div>
  );
}

export default AnnouncementsWidget;
