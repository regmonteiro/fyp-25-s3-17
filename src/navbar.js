import React, { useEffect, useState } from 'react';
import { Link, useNavigate, useLocation } from 'react-router-dom';
import './navbar.css';
import { User, ChevronDown, Settings } from 'lucide-react';

function Navbar() {
  const navigate = useNavigate();
  const location = useLocation();
  const [isLoggedIn, setIsLoggedIn] = useState(false);
  const [userType, setUserType] = useState(null);
  const [menuOpen, setMenuOpen] = useState(false);
  const [scrolled, setScrolled] = useState(false);
  const [manageDropdownOpen, setManageDropdownOpen] = useState(false);

  useEffect(() => {
    const loggedIn = localStorage.getItem('isLoggedIn') === 'true';
    const type = localStorage.getItem('userType');

    setIsLoggedIn(loggedIn);
    setUserType(type);
    setMenuOpen(false);
    setManageDropdownOpen(false);

    const handleScroll = () => setScrolled(window.scrollY > 10);
    window.addEventListener('scroll', handleScroll);
    return () => window.removeEventListener('scroll', handleScroll);
  }, [location.pathname]);

  const handleLogout = () => {
    localStorage.clear();
    setIsLoggedIn(false);
    setUserType(null);
    navigate('/login');
  };

  const toggleMenu = () => setMenuOpen(!menuOpen);

  const toggleManageDropdown = () => {
    setManageDropdownOpen(!manageDropdownOpen);
  };

  const closeAllMenus = () => {
    setMenuOpen(false);
    setManageDropdownOpen(false);
  };

  const renderNavItems = () => {
    if (!isLoggedIn) {
      return (
        <>
          <li><Link to="/homePage" className="nav-link" onClick={closeAllMenus}>Home</Link></li>
          <li><Link to="/viewServicesPage" className="nav-link" onClick={closeAllMenus}>Services</Link></li>
          <li><Link to="/viewActivitiesPage" className="nav-link" onClick={closeAllMenus}>Activities</Link></li>
          <li><Link to="/viewQNAPage" className="nav-link" onClick={closeAllMenus}>Q&A</Link></li>
          <li><Link to="/viewMembershipPage" className="nav-link" onClick={closeAllMenus}>Join Us</Link></li>
          <li><Link to="/chatBotPage" className="nav-link" onClick={closeAllMenus}>Enquiry</Link></li>
        </>
      );
    }

    switch (userType) {
      case 'admin':
        return (
          <>
            <li><Link to="/admin/adminDashboard" className="nav-link" onClick={closeAllMenus}>Dashboard</Link></li>
            
            

            <li><Link to="/admin/adminProfilepage" className="nav-link" onClick={closeAllMenus}>Profile</Link></li>
            <li><Link to="/admin/adminReportPage" className="nav-link" onClick={closeAllMenus}>Reports</Link></li>
            <li><Link to="/admin/adminUserFeedback" className="nav-link" onClick={closeAllMenus}>Feedback</Link></li>
            <li><Link to="/admin/adminrolePage" className="nav-link" onClick={closeAllMenus}>Assign Roles</Link></li>
            <li><Link to="/admin/adminSafetyPage" className="nav-link" onClick={closeAllMenus}>Safety Measures</Link></li>
            <li><Link to="/admin/adminAnnouncementPage" className="nav-link" onClick={closeAllMenus}>Announcements</Link></li>
            
            {/* Manage Dropdown */}
            <li className="nav-item-dropdown">
              <button 
                className="nav-link dropdown-toggle"
                onClick={toggleManageDropdown}
                onMouseEnter={() => setManageDropdownOpen(true)}
              >
                <Settings size={16} />
                <span>Manage</span>
                <ChevronDown size={16} className={`dropdown-arrow ${manageDropdownOpen ? 'rotate' : ''}`} />
              </button>
              <div 
                className={`dropdown-menu ${manageDropdownOpen ? 'active' : ''}`}
                onMouseLeave={() => setManageDropdownOpen(false)}
              >
                <Link to="/admin/adminServicesPage" className="dropdown-item" onClick={closeAllMenus}>
                  Services
                </Link>
                <Link to="/admin/adminMembership" className="dropdown-item" onClick={closeAllMenus}>
                  Membership
                </Link>
                <Link to="/admin/adminActivitiesPage" className="dropdown-item" onClick={closeAllMenus}>
                  Activities
                </Link>
                <Link to="/admin/adminMedicalProducts" className="dropdown-item" onClick={closeAllMenus}>
                  Medical Products
                </Link>
              </div>
            </li>
          </>
        );
      case 'elderly':
        return (
          <>
            <li><Link to="/elderly/viewElderlyDashboard" className="nav-link" onClick={closeAllMenus}>Dashboard</Link></li>
            <li><Link to="/elderly/elderlyprofile" className="nav-link" onClick={closeAllMenus}>Profile</Link></li>
            <li><Link to="/elderly/medicationAndDoctorPage" className="nav-link" onClick={closeAllMenus}>Telemedicine</Link></li>
            <li><Link to="/viewActivitiesPage" className="nav-link" onClick={closeAllMenus}>Activities</Link></li>
            <li><Link to="/elderly/shareExperience" className="nav-link" onClick={closeAllMenus}>Experience</Link></li>
            <li><Link to="/elderly/viewLearningResources" className="nav-link" onClick={closeAllMenus}>Learning</Link></li>
          </>
        );
      case 'caregiver':
        return (
          <>
            <li><Link to="/caregiver/viewCaregiverDashboard" className="nav-link" onClick={closeAllMenus}>Dashboard</Link></li>
            <li><Link to="/caregiver/updateProfileCaregiver" className="nav-link" onClick={closeAllMenus}>Profile</Link></li>
            <li><Link to="/caregiver/medicationReminder" className="nav-link" onClick={closeAllMenus}>Medication</Link></li>
            <li><Link to="/caregiver/appointmentReminder" className="nav-link" onClick={closeAllMenus}>Appointment</Link></li>
            <li><Link to="/caregiver/viewReportsCaregiver" className="nav-link" onClick={closeAllMenus}>Reports</Link></li>
            <li><Link to="/caregiver/careRoutineTemplate" className="nav-link" onClick={closeAllMenus}>Care Routine</Link></li>
            <li><Link to="/caregiver/caregiverMessagesPage" className="nav-link" onClick={closeAllMenus}>Messages</Link></li>
            <li><Link to="/caregiver/receiveNotificationsCaregiver" className="nav-link" onClick={closeAllMenus}>Notifications</Link></li>
          </>
        );
      default:
        return (
          <>
            <li><Link to="/homePage" className="nav-link" onClick={closeAllMenus}>Home</Link></li>
            <li><Link to="/viewServicesPage" className="nav-link" onClick={closeAllMenus}>Services</Link></li>
            <li><Link to="/viewActivitiesPage" className="nav-link" onClick={closeAllMenus}>Activities</Link></li>
            <li><Link to="/viewQNAPage" className="nav-link" onClick={closeAllMenus}>Q&A</Link></li>
            <li><Link to="/viewMembershipPage" className="nav-link" onClick={closeAllMenus}>Join Us</Link></li>
            <li><Link to="/chatBotPage" className="nav-link" onClick={closeAllMenus}>Enquiry</Link></li>
          </>
        );
    }
  };

  return (
    <header className={`navbar ${scrolled ? 'scrolled' : ''}`}>
      <div className="navbar-container">
        <div className="logo-wrapper">
          <img src="../allcarelogo.png" alt="Logo" className="logo-image" />
          <div className="logo-text">
            <span className="logo">AllCare</span>
            <span className="logo-sub">Senior Care</span>
          </div>
        </div>

        <nav className={`nav-menu ${menuOpen ? 'active' : ''}`}>
          <ul className="nav-items">{renderNavItems()}</ul>
          <div className="auth-section">
            {isLoggedIn ? (
              <button className="auth-button logout" onClick={handleLogout}>
                <span>Logout</span>
                <User size={20} />
              </button>
            ) : (
              <Link to="/login" className="auth-button login">
                <span>Login</span>
                <User size={20} />
              </Link>
            )}
          </div>
        </nav>

        <button className="hamburger" onClick={toggleMenu}>
          <span className={`hamburger-line ${menuOpen ? 'active' : ''}`}></span>
          <span className={`hamburger-line ${menuOpen ? 'active' : ''}`}></span>
          <span className={`hamburger-line ${menuOpen ? 'active' : ''}`}></span>
        </button>
      </div>
    </header>
  );
}

export default Navbar;