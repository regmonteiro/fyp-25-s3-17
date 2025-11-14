import React, { useState, useEffect } from "react";
import { ProfileController } from "../controller/profileController";
import {
  User,
  Mail,
  Phone,
  Calendar,
  Shield,
  Clock,
  AlertTriangle,
  Trash2,
} from "lucide-react";
import "./adminProfilepage.css";
import { useNavigate } from "react-router-dom";
import Footer from "../footer";

export default function AdminProfilepage() {
  const navigate = useNavigate();
  const [controller, setController] = useState(null);
  const [profile, setProfile] = useState({});
  const [loading, setLoading] = useState(true);
  const [errorMessage, setErrorMessage] = useState("");
  const [successMessage, setSuccessMessage] = useState("");
  const [showLoginLogs, setShowLoginLogs] = useState(false);

  const userEmail = localStorage.getItem("userEmail");

  useEffect(() => {
    async function fetchProfileData() {
      if (!userEmail) {
        setErrorMessage("Not logged in.");
        setLoading(false);
        return;
      }
      const profileController = new ProfileController(userEmail);
      await profileController.fetchProfile();
      setController(profileController);

      if (profileController.profile) {
        setProfile(profileController.profile);
      } else {
        setErrorMessage(profileController.errorMessage);
      }
      setLoading(false);
    }
    fetchProfileData();
  }, [userEmail]);

  const handleChange = (e) => {
    const { name, value } = e.target;
    setProfile((prev) => ({ ...prev, [name]: value }));
  };

  const handleSave = async () => {
    if (!controller) return;
    setErrorMessage("");
    setSuccessMessage("");

    const success = await controller.updateProfile({
      firstname: profile.firstname,
      lastname: profile.lastname,
      dob: profile.dob,
      phoneNum: profile.phoneNum,
      password: profile.password,
      elderlyId: profile.elderlyId,
      status: profile.status,
    });

    if (success) {
      setSuccessMessage("Profile updated successfully!");
      setTimeout(() => setSuccessMessage(""), 5000);
    } else {
      setErrorMessage(controller.errorMessage);
    }
  };

  const handleDelete = async () => {
    if (!controller) return;
    const confirmOnce = window.confirm(
      "Are you sure you want to delete your account?"
    );
    if (!confirmOnce) return;

    const confirmTwice = window.confirm(
      "⚠️ WARNING: Once deleted, your account cannot be recovered.\n\nDo you really want to proceed?"
    );
    if (!confirmTwice) return;

    const success = await controller.deleteProfile();
    if (success) {
      alert("Account deleted successfully.");
      localStorage.clear();
      window.location.href = "/login";
    } else {
      setErrorMessage(controller.errorMessage);
    }
  };

  const getLoginLogs = () => {
    if (!controller) return [];
    return controller.getLoginLogsArray();
  };

  if (loading) {
    return (
      <div className="loading-screen">
        <div className="loading-spinner"></div>
        <p>Loading your profile...</p>
      </div>
    );
  }

  return (
    <div>
      <div className="profile-wrapper">
        {/* Header */}
        <div className="profile-header">
          <div className="avatar-circle">
            <User size={48} />
          </div>
          <div>
            <h1>My Profile</h1>
            <p>Manage and update your personal information</p>
          </div>
        </div>

        {/* Messages */}
        {errorMessage && (
          <div className="alert alert-error">
            <AlertTriangle size={20} />
            <span>{errorMessage}</span>
          </div>
        )}
        {successMessage && (
          <div className="alert alert-success">{successMessage}</div>
        )}

        {/* Main content: Form + Sidebar */}
        <div style={{
          display: "flex",
          flexDirection: "row",
          gap: "20px",
          alignItems: "flex-start",
          width: "100%"
        }}>
          {/* Left: Form */}
          <div style={{
            flex: "2",
            minWidth: "0",
            background: "white",
            padding: "20px",
            borderRadius: "12px",
            boxShadow: "0 4px 10px rgba(0, 119, 182, 0.08)",
          }}>
            <h2>Personal Information</h2>
            <div className="form-grid">
              <label>
                <span>
                  <User size={16} /> First Name
                </span>
                <input
                  type="text"
                  name="firstname"
                  value={profile.firstname || ""}
                  onChange={handleChange}
                />
              </label>

              <label>
                <span>
                  <User size={16} /> Last Name
                </span>
                <input
                  type="text"
                  name="lastname"
                  value={profile.lastname || ""}
                  onChange={handleChange}
                />
              </label>

              <label>
                <span>
                  <Mail size={16} /> Email
                </span>
                <input value={profile.email || ""} disabled />
              </label>

              <label>
                <span>
                  <Shield size={16} /> User Type
                </span>
                <input value={profile.userType || ""} disabled />
              </label>

              <label>
                <span>
                  <Calendar size={16} /> Date of Birth
                </span>
                <input
                  type="date"
                  name="dob"
                  value={profile.dob || ""}
                  onChange={handleChange}
                />
              </label>

              <label>
                <span>
                  <Phone size={16} /> Phone Number
                </span>
                <input
                  type="tel"
                  name="phoneNum"
                  value={profile.phoneNum || ""}
                  onChange={handleChange}
                />
              </label>

              <label className="full-width">
                <span>Password</span>
                <input
                  type="password"
                  name="password"
                  placeholder="***************"
                  value={profile.password || ""}
                  onChange={handleChange}
                />
              </label>

              {profile.userType === "caregiver" && (
                <>
                  <label>
                    <span>Elderly ID</span>
                    <input
                      name="elderlyId"
                      value={profile.elderlyId || ""}
                      onChange={handleChange}
                    />
                  </label>
                  <label>
                    <span>Status</span>
                    <select
                      name="status"
                      value={profile.status || ""}
                      onChange={handleChange}
                      disabled
                    >
                      <option value="">Select Status</option>
                      <option value="Active">Active</option>
                      <option value="Inactive">Inactive</option>
                    </select>
                  </label>
                </>
              )}
            </div>

            {/* Buttons */}
            <div className="form-actions">
              <button className="btn-primary" onClick={handleSave}>
                Save Changes
              </button>
              <button
                className="btn-secondary"
                onClick={() => setShowLoginLogs(!showLoginLogs)}
              >
                {showLoginLogs ? "Hide" : "View"} Login History
              </button>
              
            </div>
          </div>

          {/* Right: Sidebar */}
          <div style={{
            flex: "1",
            maxWidth: "320px",
            display: "flex",
            flexDirection: "column",
            gap: "20px",
          }}>
            {/* Account Info */}
            <div style={{
              background: "white",
              padding: "20px",
              borderRadius: "12px",
              boxShadow: "0 4px 10px rgba(0, 119, 182, 0.08)",
            }}>
              <h3 style={{
                marginBottom: "15px",
                color: "#0077b6",
                fontSize: "1.2rem",
                display: "flex",
                alignItems: "center",
                gap: "8px",
              }}>
                <Clock size={18} /> Account Info
              </h3>
              <p style={{ margin: "10px 0", fontSize: "0.95rem" }}>
                Created:{" "}
                {profile.createdAt
                  ? new Date(profile.createdAt).toLocaleDateString()
                  : "N/A"}
              </p>
              <p style={{ margin: "10px 0", fontSize: "0.95rem" }}>
                Last Login:{" "}
                {profile.lastLoginDate
                  ? new Date(profile.lastLoginDate).toLocaleString()
                  : "N/A"}
              </p>
            </div>

            {/* Danger Zone */}
            <div style={{
              border: "2px solid #ff4d4f",
              backgroundColor: "#fffafa",
              padding: "20px",
              borderRadius: "12px",
              boxShadow: "0 4px 10px rgba(0, 119, 182, 0.08)",
            }}>
              <h3 style={{
                color: "#ff4d4f",
                marginBottom: "15px",
                fontSize: "1.2rem",
                display: "flex",
                alignItems: "center",
                gap: "8px",
              }}>
                <AlertTriangle size={18} /> Danger Zone
              </h3>
              <p style={{ color: "#7c0a02", marginBottom: "15px" }}>
                Once deleted, your account cannot be recovered.
              </p>
              <button
                onClick={handleDelete}
                style={{
                  width: "100%",
                  background: "#ff4d4f",
                  border: "none",
                  color: "white",
                  padding: "12px",
                  borderRadius: "8px",
                  cursor: "pointer",
                  fontWeight: 600,
                  display: "flex",
                  alignItems: "center",
                  justifyContent: "center",
                  gap: "8px",
                }}
              >
                <Trash2 size={16} /> Delete Account
              </button>
            </div>
          </div>
        </div>

        {/* Login Logs - This will appear below both columns */}
        {showLoginLogs && (
          <div style={{
            marginTop: "25px",
            background: "white",
            padding: "15px",
            borderRadius: "12px",
            boxShadow: "0 4px 10px rgba(0, 119, 182, 0.08)",
            overflow: "hidden",
            border: "1px solid #cce4ff",
            width: "100%"
          }}>
            <h3 style={{ color: "#004d99", marginTop: "0" }}>Recent Login History</h3>
            {getLoginLogs().length > 0 ? (
              <table style={{
                width: "100%",
                borderCollapse: "collapse",
                marginTop: "1rem",
                fontSize: "0.95rem"
              }}>
                <thead>
                  <tr>
                    <th style={{
                      padding: "10px 12px",
                      textAlign: "left",
                      background: "linear-gradient(90deg, #0077b6, #00b4d8)",
                      color: "white",
                      fontWeight: 600
                    }}>#</th>
                    <th style={{
                      padding: "10px 12px",
                      textAlign: "left",
                      background: "linear-gradient(90deg, #0077b6, #00b4d8)",
                      color: "white",
                      fontWeight: 600
                    }}>Date</th>
                    <th style={{
                      padding: "10px 12px",
                      textAlign: "left",
                      background: "linear-gradient(90deg, #0077b6, #00b4d8)",
                      color: "white",
                      fontWeight: 600
                    }}>Time</th>
                  </tr>
                </thead>
                <tbody>
                  {getLoginLogs().map((log, index) => {
                    const dateObj = new Date(log.date);
                    return (
                      <tr key={log.id || index} style={{
                        backgroundColor: index % 2 === 0 ? "#f0f8ff" : "#ffffff"
                      }}>
                        <td style={{
                          padding: "10px 12px",
                          textAlign: "left",
                          fontWeight: 500,
                          color: "#0077b6"
                        }}>{index + 1}</td>
                        <td style={{ padding: "10px 12px", textAlign: "left" }}>
                          {dateObj.toLocaleDateString()}
                        </td>
                        <td style={{ padding: "10px 12px", textAlign: "left" }}>
                          {dateObj.toLocaleTimeString()}
                        </td>
                      </tr>
                    );
                  })}
                </tbody>
              </table>
            ) : (
              <p>No login history available</p>
            )}
          </div>
        )}
      </div>
      <Footer />
    </div>
  );
}