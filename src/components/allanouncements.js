// AllAnnouncements.js
import React, { useEffect, useState } from "react";
import { fetchAnnouncementsForUser, markAnnouncementRead, getUnreadCount } from "../controller/announcementController";
import { toast } from "react-toastify";
import 'react-toastify/dist/ReactToastify.css';
import { FiBell, FiCheckCircle, FiChevronLeft, FiChevronRight, FiRefreshCw, FiUser, FiCalendar, FiUsers } from "react-icons/fi";
import "./allannouncement.css";

function AllAnnouncements({ uid }) {
  const [announcements, setAnnouncements] = useState([]);
  const [unreadCount, setUnreadCount] = useState(0);
  const [currentPage, setCurrentPage] = useState(1);
  const [loading, setLoading] = useState(true);
  const [userType, setUserType] = useState(null);
  const [refreshing, setRefreshing] = useState(false);
  const pageSize = 6;

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
        let determinedType = 'elderly'; // default
        
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

  const loadAnnouncements = async () => {
    if (!userType) {
      setLoading(false);
      return;
    }
    
    try {
      setRefreshing(true);
      let anns = await fetchAnnouncementsForUser(userType);
      setAnnouncements(anns);

      const count = await getUnreadCount(uid, userType);
      setUnreadCount(count);
    } catch (error) {
      console.error("Error loading announcements:", error);
      toast.error("Failed to load announcements");
    } finally {
      setLoading(false);
      setRefreshing(false);
    }
  };

  useEffect(() => {
    loadAnnouncements();
  }, [uid, userType]);

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

  const handleMarkAllRead = async () => {
    try {
      const unreadAnnouncements = announcements.filter(a => !a.readBy || !a.readBy[uid]);
      
      for (const announcement of unreadAnnouncements) {
        await markAnnouncementRead(uid, announcement.id);
      }
      
      setAnnouncements(prev =>
        prev.map(a => ({ 
          ...a, 
          readBy: { ...(a.readBy || {}), [uid]: true } 
        }))
      );
      setUnreadCount(0);
      toast.success("All announcements marked as read!");
    } catch (error) {
      console.error("Error marking all as read:", error);
      toast.error("Failed to mark all as read");
    }
  };

  if (!userType) {
    return (
      <div className="announcements-container">
        <div className="announcements-header">
          <h1><FiBell /> Announcements</h1>
        </div>
        <div className="error-state">
          <FiUser size={48} />
          <h2>User Information Needed</h2>
          <p>Please make sure you're logged in correctly to view announcements.</p>
          <button className="retry-button" onClick={() => window.location.reload()}>
            <FiRefreshCw /> Refresh Page
          </button>
        </div>
      </div>
    );
  }

  const totalPages = Math.ceil(announcements.length / pageSize);
  const paginated = announcements.slice((currentPage - 1) * pageSize, currentPage * pageSize);

  return (
    <div className="announcements-container">
      <div className="announcements-header">
        <div className="header-content">
          <h1><FiBell /> Announcements</h1>
          <div className="header-actions">
            {unreadCount > 0 && (
              <button className="mark-all-read-btn" onClick={handleMarkAllRead}>
                <FiCheckCircle /> Mark All Read
              </button>
            )}
            <button className="refresh-btn" onClick={loadAnnouncements} disabled={refreshing}>
              <FiRefreshCw className={refreshing ? "spinning" : ""} />
            </button>
          </div>
        </div>
        
        <div className="header-stats">
          <span className="stat-badge">
            {announcements.length} announcement{announcements.length !== 1 ? 's' : ''}
          </span>
          {unreadCount > 0 && (
            <span className="unread-badge">
              {unreadCount} unread
            </span>
          )}
          <span className="user-type-badge">
            <FiUser /> {userType}
          </span>
        </div>
      </div>

      {loading ? (
        <div className="loading-state">
          <div className="loading-spinner"></div>
          <p>Loading announcements...</p>
        </div>
      ) : paginated.length === 0 ? (
        <div className="empty-state">
          <FiBell size={64} />
          <h2>No Announcements</h2>
          <p>There are no announcements available for your user type ({userType}).</p>
        </div>
      ) : (
        <>
          <div className="announcements-grid">
            {paginated.map(a => {
              const isRead = a.readBy && a.readBy[uid];
              return (
                <div key={a.id} className={`announcement-card ${isRead ? 'read' : 'unread'}`}>
                  {!isRead && <div className="unread-indicator"></div>}
                  <div className="card-header">
                    <h3>{a.title}</h3>
                    <button 
                      className={`read-btn ${isRead ? 'read' : ''}`}
                      onClick={() => handleMarkRead(a.id)}
                      title={isRead ? 'Already read' : 'Mark as read'}
                    >
                      <FiCheckCircle />
                    </button>
                  </div>
                  <p className="announcement-description">{a.description}</p>
                  
                  <div className="card-footer">
                    <div className="announcement-meta">
                      <span className="meta-item">
                        <FiUsers /> For: {Array.isArray(a.userGroups) ? a.userGroups.join(", ") : "All users"}
                      </span>
                      <span className="meta-item">
                        <FiCalendar /> {new Date(a.createdAt).toLocaleDateString('en-US', {
                          year: 'numeric',
                          month: 'short',
                          day: 'numeric',
                          hour: '2-digit',
                          minute: '2-digit'
                        })}
                      </span>
                    </div>
                  </div>
                </div>
              );
            })}
          </div>

          {totalPages > 1 && (
            <div className="pagination">
              <button
                className="pagination-btn"
                disabled={currentPage === 1}
                onClick={() => setCurrentPage(prev => prev - 1)}
              >
                <FiChevronLeft /> Previous
              </button>
              
              <div className="pagination-pages">
                {Array.from({ length: totalPages }, (_, i) => i + 1).map(page => (
                  <button
                    key={page}
                    className={`pagination-page ${currentPage === page ? 'active' : ''}`}
                    onClick={() => setCurrentPage(page)}
                  >
                    {page}
                  </button>
                ))}
              </div>
              
              <button
                className="pagination-btn"
                disabled={currentPage === totalPages}
                onClick={() => setCurrentPage(prev => prev + 1)}
              >
                Next <FiChevronRight />
              </button>
            </div>
          )}
        </>
      )}
    </div>
  );
}

export default AllAnnouncements;