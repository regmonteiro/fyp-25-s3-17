// src/App.js
import React from 'react';
import { BrowserRouter as Router, Routes, Route } from 'react-router-dom';
import Navbar from './navbar';

import GoogleTranslate from './googleTranslate';

import Login from './login';
import CreateAccountPage from './components/createAccountPage';
import HomePage from './HomePage';
import ViewServicesPage from './components/viewServicesPage';
import ViewActivitiesPage from './components/viewActivitiesPage';
import ViewQNAPage from './components/viewQNAPage';
import ViewMembershipPage from './components/viewMembershipPage';
import ChatBotPage from './components/ChatBotPage';
import AboutUs from "./aboutUs";
import Footer from './footer';
import DocumentationPage from './projectdocumentation';
import { useNavigate } from "react-router-dom";

import AdminMembershipPage from './admin/adminMembership';


//Admin
import AdminDashboard from "./admin/dashboardPage";
import AdminReportPage from "./admin/reportPage";
import AdminUserFeedback from "./admin/feedbackPage";
import AdminRolePage from "./admin/rolePage";
import AdminSafetyPage from "./admin/safetyPage";
import AdminAnnouncementPage from "./admin/announcementPage";
import AdminProfilepage from "./admin/adminProfilepage";
import AdminServicesPage from "./admin/adminServicePage";
import AnnouncementsWidget from './components/announcementWidget';
import announcements from './components/allanouncements';
import AllAnnouncements from './components/allanouncements';
import AdminActivitiesPage from './admin/adminActivities';
import AdminMedicalProducts from './admin/adminMedicalProducts';


//Elderly
import ViewElderlyDashboard from './elderly/viewElderlyDashboard';
import ShareExperience from './elderly/shareExperience';
import CreateEventReminder from './elderly/createEventreminders';
import ViewLearningResources from './elderly/viewLearningResources';
import UpdatePersonalPreference from './elderly/UpdatePersonalPreference';
import ElderlyProfile from './elderly/elderlyprofile';
import ManageSecureSubscription from './elderly/manageSecureSubscription';
import ViewAppointments from './elderly/viewAppointments';
import MedicationandDoctorPage from './elderly/medicationAndDoctorPage';
import MedicineAndProducts from './elderly/medicineandproducts';
import Cart from './elderly/cart';
import AdditionalCaregiverPage from './elderly/additionalCaregiver';

//Caregiver
import MedicationReminder from './caregiver/MedicationReminder';
import AppointmentReminder from './caregiver/AppointmentReminder';
import ViewCaregiverDashboard from './caregiver/viewCaregiverDashboard';
import ViewReportsCaregiver from './caregiver/viewReportsCaregiver';
import GenerateCustomReport from './caregiver/generatecustomReports';
import UpdateProfileCaregiver from './caregiver/updateProfileCaregiver';
import CareRoutineTemplate from './caregiver/setCareRoutineTemplate';
import ReceiveNotificationsCaregiver from './caregiver/receiveNotificationsCaregiver';
import CaregiverMessagesPage from './caregiver/caregiverMessagePage';
import LinkElderlyPage from './caregiver/linkElderlyPage';
import ConsultationHistoryPage from './caregiver/consultationPageCaregiver';

function App() {
  return (
    <Router>
      
      <Navbar />
      
      {/* 👇 The Translate button appears across the whole app */}
      <GoogleTranslate />

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
        <Route path="/documentation" element={<ProjectDocumentationWrapper />} />

        <Route path="/AnnouncementsWidget" element={<AnnouncementsWidget />} />
        <Route path="/announcements" element={<AllAnnouncements />} />


        
        {/* Routing page for admin */}
        <Route path='/admin/adminDashboard' element={<AdminDashboard />} />
        <Route path='/admin/adminServicesPage' element={<AdminServicesPage />} />
        <Route path='/admin/adminProfilepage' element={<AdminProfilepage />} />
        <Route path='/admin/adminReportPage' element={<AdminReportPage />} />
        <Route path='/admin/adminUserFeedback' element={<AdminUserFeedback />} />
        <Route path='/admin/adminrolePage' element={<AdminRolePage />} />
        <Route path='/admin/adminSafetyPage' element={<AdminSafetyPage />} />
        <Route path='/admin/adminannouncementPage' element={<AdminAnnouncementPage />} />
        <Route path="/admin/adminMembership" element={<AdminMembershipPage />} />
        <Route path="/admin/adminActivitiesPage" element={<AdminActivitiesPage />} />
        <Route path="/admin/adminMedicalProducts" element={<AdminMedicalProducts />} />

        
        {/* Routing page for Elderly */}
        <Route path='/elderly/viewElderlyDashboard' element={<ViewElderlyDashboard />} />
        <Route path='/elderly/shareExperience' element={<ShareExperience />} />
        <Route path='/elderly/createEventReminder' element={<CreateEventReminder />} /> 
        <Route path='/elderly/viewLearningResources' element={<ViewLearningResources />} />
        <Route path='/elderly/updatePersonalPreference' element={<UpdatePersonalPreference />} />
        <Route path='/elderly/elderlyProfile' element={<ElderlyProfile />} />
        <Route path='/elderly/manageSecureSubscription' element={<ManageSecureSubscription />} />
        <Route path='/elderly/viewAppointments' element={<ViewAppointments />} />
        <Route path='/elderly/medicationandDoctorPage' element={<MedicationandDoctorPage />} />
        <Route path='/elderly/cart' element={<Cart />} />
        <Route path='/elderly/additionalCaregiver' element={<AdditionalCaregiverPage />} /> 
        
        {/* Routing page for Caregiver */}
        <Route path='/caregiver/viewCaregiverDashboard' element={<ViewCaregiverDashboard />} />
        <Route path='/caregiver/medicationReminder' element={<MedicationReminder />} /> 
        <Route path='/caregiver/appointmentReminder' element={<AppointmentReminder />} />
        <Route path='/caregiver/viewReportsCaregiver' element={<ViewReportsCaregiver />} />
        <Route path="/caregiver/generatecustomreport" element={<GenerateCustomReport />} />
        <Route path="/caregiver/updateProfileCaregiver" element={<UpdateProfileCaregiver />} />
        <Route path="/caregiver/careRoutineTemplate" element={<CareRoutineTemplate />} />
        <Route path="/caregiver/receiveNotificationsCaregiver" element={<ReceiveNotificationsCaregiver />} />
        <Route path="/caregiver/caregiverMessagesPage" element={<CaregiverMessagesPage />} />
        <Route path="/caregiver/linkElderlyPage" element={<LinkElderlyPage />} />
        <Route path="/caregiver/consultationHistoryPage" element={<ConsultationHistoryPage />} />
      </Routes>
    </Router>
  );
}

function ProjectDocumentationWrapper() {
  const navigate = useNavigate();
  return <DocumentationPage onBackToAbout={() => navigate("/aboutus")} />;
}

export default App;
