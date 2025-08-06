// src/App.js
import React from 'react';
import { BrowserRouter as Router, Routes, Route } from 'react-router-dom';
import Navbar from './navbar';
import Login from './login';
import CreateAccountPage from './components/createAccountPage';
import HomePage from './HomePage';
import ViewServicesPage from './components/viewServicesPage';
import ViewActivitiesPage from './components/viewActivitiesPage';
import ViewQNAPage from './components/viewQNAPage';
import ViewMembershipPage from './components/viewMembershipPage';
import ChatBotPage from './components/ChatBotPage';
import AboutUs from "./aboutUs";
import AdminDashboard from "./admin/dashboardPage";
import AdminReportPage from "./admin/reportPage";
import AdminUserFeedback from "./admin/feedbackPage";
import AdminRolePage from "./admin/rolePage";
import AdminSafetyPage from "./admin/safetyPage";
import AdminAnnouncementPage from "./admin/announcementPage";


function App() {
  return (
    <Router>
      <Navbar />
      <Routes>
        <Route path='/homePage' element={<HomePage />} />
        <Route path="/login" element={<Login />} />
        <Route path="/signup" element={<CreateAccountPage />} />
        <Route path="/viewServicesPage" element={<ViewServicesPage />} />
        <Route path="/viewActivitiesPage" element={<ViewActivitiesPage />} />
        <Route path='/viewQNAPage' element={<ViewQNAPage />} />
        <Route path='/viewMembershipPage' element={<ViewMembershipPage />} />
        <Route path='/chatBotPage' element={<ChatBotPage />} />
        <Route path="/aboutUs" element={<AboutUs />} />
        
        {/* Routing page for admin */}
        <Route path='/admin/adminDashboard' element={<AdminDashboard />} />
        <Route path='/admin/adminReportPage' element={<AdminReportPage />} />
        <Route path='/admin/adminUserFeedback' element={<AdminUserFeedback />} />
        <Route path='/admin/adminrolePage' element={<AdminRolePage />} />
        <Route path='/admin/adminSafetyPage' element={<AdminSafetyPage />} />
        <Route path='/admin/adminannouncementPage' element={<AdminAnnouncementPage />} />
      </Routes>
    </Router>
  );
}

export default App;
