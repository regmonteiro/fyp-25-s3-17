import React, { useEffect, useState } from 'react';
import { Link, useNavigate, useLocation } from 'react-router-dom';
import './navbar.css';

function Navbar() {
  const navigate = useNavigate();
  const location = useLocation();
  const [isLoggedIn, setIsLoggedIn] = useState(false);
  const [userType, setUserType] = useState(null);

  // For hamburger menu open/close state
  const [menuOpen, setMenuOpen] = useState(false);

  useEffect(() => {
    const loggedIn = localStorage.getItem('isLoggedIn') === 'true';
    const type = localStorage.getItem('userType');

    setIsLoggedIn(loggedIn);
    setUserType(type);

    // Close menu on route change
    setMenuOpen(false);
  }, [location.pathname]);

  const handleLogout = () => {
    localStorage.removeItem('isLoggedIn');
    localStorage.removeItem('userEmail');
    localStorage.removeItem('userType');
    setIsLoggedIn(false);
    setUserType(null);
    alert('You have been logged out.');
    navigate('/login');
  };

  const toggleMenu = () => {
    setMenuOpen(!menuOpen);
  };

  const renderNavItems = () => {
    if (!isLoggedIn) {
      return (
        <>
          <li><Link to="/homePage">Home</Link></li>
          <li><Link to="/viewServicesPage">Services</Link></li>
          <li><Link to="/viewActivitiesPage">Activities</Link></li>
          <li><Link to="/viewQNAPage">QNA</Link></li>
          <li><Link to="/viewMembershipPage">Join Us</Link></li>
          <li><Link to="/chatBotPage">Enquiry</Link></li>
        </>
      );
    }

    switch (userType) {
      case 'admin':
        return (
          <>
            <li><Link to="/admin/adminDashboard">Dashboard</Link></li>
            <li><Link to="/admin/adminReportPage">Generate Report</Link></li>
            <li><Link to="/admin/adminUserFeedback">User Feedback</Link></li>
            <li><Link to="/admin/adminrolePage">Assign Roles</Link></li>
            <li><Link to="/admin/adminSafetyPage">Safety Measures</Link></li>
            <li><Link to="/admin/adminAnnouncementPage">Announcement</Link></li>
          </>
        );
      case 'elderly':
        return (
          <>
            <li><Link to="/elderly/home">My Home</Link></li>
            <li><Link to="/elderly/services">My Services</Link></li>
            <li><Link to="/elderly/appointments">Appointments</Link></li>
          </>
        );
      case 'caregiver':
        return (
          <>
            <li><Link to="/caregiver/dashboard">Dashboard</Link></li>
            <li><Link to="/caregiver/patients">My elderly</Link></li>
            <li><Link to="/caregiver/schedule">Schedule</Link></li>
          </>
        );
      default:
        return (
          <>
            <li><Link to="/homePage">Home</Link></li>
            <li><Link to="/viewServicesPage">Services</Link></li>
            <li><Link to="/viewActivitiesPage">Activities</Link></li>
            <li><Link to="/viewQNAPage">QNA</Link></li>
            <li><Link to="/viewMembershipPage">Join Us</Link></li>
            <li><Link to="/chatBotPage">Enquiry</Link></li>
          </>
        );
    }
  };

  return (
    <nav className={`navbar navbar-${userType || 'guest'}`}>
      <div className="logo">AllCare</div>

      {/* Hamburger Button - visible on mobile */}
      <button className="hamburger" onClick={toggleMenu} aria-label="Toggle menu">
        {/* simple hamburger icon */}
        &#9776;
      </button>

      {/* Navigation links */}
      <ul className={`nav-links ${menuOpen ? 'open' : ''}`}>
        {renderNavItems()}

        {isLoggedIn ? (
          <li><button className="logout-button" onClick={handleLogout}>Logout</button></li>
        ) : (
          <li><Link to="/login" className="login-button">Login</Link></li>
        )}
      </ul>
    </nav>
  );
}

export default Navbar;
