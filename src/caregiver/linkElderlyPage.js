import { useState } from "react";
import { Search, Link, Users, CheckCircle, AlertCircle, Loader } from "lucide-react";
import { searchElderly, linkCaregiverToElderly, calculateAge } from "../controller/linkElderlyController";

export default function LinkElderlyPage() {
  const [searchQuery, setSearchQuery] = useState("");
  const [isSearching, setIsSearching] = useState(false);
  const [searchResults, setSearchResults] = useState([]);
  const [selectedElderly, setSelectedElderly] = useState(null);
  const [linkStatus, setLinkStatus] = useState(null);
  const [errorMessage, setErrorMessage] = useState("");

  const caregiverEmail = localStorage.getItem("userEmail");

  const handleSearch = async () => {
    if (!searchQuery.trim()) return;
    setIsSearching(true);
    setErrorMessage("");
    setSearchResults([]);
    setSelectedElderly(null);

    try {
      // FIX: Pass the current caregiver email to only check links to THIS caregiver
      const results = await searchElderly(searchQuery, caregiverEmail);

      if (!results || results.length === 0) {
        setErrorMessage("No matches found.");
      } else {
        setSearchResults(results);
      }
    } catch (err) {
      setErrorMessage("Error searching elderly.");
    } finally {
      setIsSearching(false);
    }
  };

  const handleLink = async (elderly) => {
    if (!elderly) return;
    setSelectedElderly(elderly);
    setLinkStatus("pending");
    setErrorMessage("");

    try {
      // FIX: Pass the elderly object or UID instead of just email
      await linkCaregiverToElderly(caregiverEmail, elderly.uid || elderly.email);
      setLinkStatus("success");
    } catch (err) {
      setErrorMessage(err.message || "Failed to link caregiver. Please try again.");
      setLinkStatus(null);
    }
  };

  const handleReset = () => {
    setSearchQuery("");
    setSearchResults([]);
    setSelectedElderly(null);
    setLinkStatus(null);
    setErrorMessage("");
  };

  // ✅ Success UI
  if (linkStatus === "success" && selectedElderly) {
    return (
      <div className="link-elderly-page-wrapper">
        <div className="link-elderly-success-card">
          <div className="link-elderly-success-icon-wrapper">
            <div className="link-elderly-success-icon-circle">
              <CheckCircle className="link-elderly-success-icon" />
            </div>
          </div>
          <h2 className="link-elderly-success-title">Successfully Linked!</h2>
          <p className="link-elderly-success-message">
            Your account has been successfully linked with {selectedElderly.firstname}{" "}
            {selectedElderly.lastname}'s profile.
          </p>
          <div className="link-elderly-connected-box">
            <Users className="link-elderly-connected-icon" />
            <span>You are now connected</span>
          </div>
          <button onClick={handleReset} className="link-elderly-primary-button">
            Link Another Account
          </button>
        </div>
      </div>
    );
  }

  // 🔍 Main Search UI
  return (
    <div className="link-elderly-page-wrapper">
      <div className="link-elderly-page-content">
        <div className="link-elderly-page-header">
          <div className="link-elderly-page-header-icon">
            <Link className="link-elderly-page-header-link-icon" />
          </div>
          <h1 className="link-elderly-page-title">Link Elderly Account</h1>
          
          <p className="link-elderly-page-subtitle">Connect your caregiver profile with your elderly user's account</p>
        </div>

        <div className="link-elderly-form-card">
          <label className="link-elderly-form-label">Search by Name or Email</label>
          <div className="link-elderly-search-container">
            <div className="link-elderly-form-input-wrapper">
              <Search className="link-elderly-form-input-icon" />
              <input
                type="text"
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                onKeyDown={(e) => e.key === "Enter" && handleSearch()}
                placeholder="Enter elderly user's name or email..."
                className="link-elderly-form-input"
                disabled={linkStatus === "pending"}
              />
            </div>
            <button
              onClick={handleSearch}
              disabled={isSearching || !searchQuery.trim() || linkStatus === "pending"}
              className="link-elderly-search-button"
            >
              {isSearching ? (
                <>
                  <Loader className="link-elderly-search-button-loader" />
                  Searching...
                </>
              ) : (
                <>
                  <Search className="link-elderly-search-button-icon" />
                  Search
                </>
              )}
            </button>
          </div>

          {errorMessage && (
            <div className="link-elderly-error-box">
              <AlertCircle className="link-elderly-error-icon" />
              <span>{errorMessage}</span>
            </div>
          )}

          {/* Show multiple results */}
          {searchResults.length > 0 && !linkStatus && (
            <div className="link-elderly-results-list">
              {searchResults.map((elderly) => (
                <div key={elderly.uid || elderly.email} className="link-elderly-result-card">
                  <div className="link-elderly-result-header">
                    <div className="link-elderly-result-avatar">
                      {elderly.gender === 'female' ? '👵' : elderly.gender === 'male' ? '👴' : '👤'}
                    </div>
                    <div className="link-elderly-result-info">
                      <h3 className="link-elderly-result-name">
                        {elderly.firstname} {elderly.lastname}
                      </h3>
                      <p className="link-elderly-result-age">Age: {calculateAge(elderly.dob) ?? "N/A"}</p>
                      {elderly.hasCaregiver && (
                        <p className="link-elderly-warning-text">⚠ Already linked with you</p>
                      )}
                    </div>
                  </div>
                  {!elderly.hasCaregiver ? (
                    <button
                      onClick={() => handleLink(elderly)}
                      className="link-elderly-primary-button link-elderly-with-icon"
                    >
                      <Link className="link-elderly-button-icon" />
                      Send Link Request
                    </button>
                  ) : (
                    <button
                      disabled
                      className="link-elderly-disabled-button"
                    >
                      Already Linked
                    </button>
                  )}
                </div>
              ))}
            </div>
          )}

          {linkStatus === "pending" && selectedElderly && (
            <div className="link-elderly-pending-box">
              <div className="link-elderly-pending-header">
                <Loader className="link-elderly-pending-spinner" />
                <h3 className="link-elderly-pending-title">Link Request Sent</h3>
              </div>
              <p className="link-elderly-pending-text">
                Waiting for {selectedElderly.firstname} {selectedElderly.lastname} to accept the link
                request...
              </p>
            </div>
          )}

          <div className="link-elderly-info-box">
            <div className="link-elderly-info-header">
              <AlertCircle className="link-elderly-info-icon" /> Important Information
            </div>
            <ul className="link-elderly-info-list">
              <li>The elderly user must have a registered account</li>
              <li>Some accounts may auto-link without requiring acceptance</li>
              <li>Make sure you have the correct user email or name</li>
            </ul>
          </div>
        </div>
      </div>

     
      {/* CSS Styles - Add the new UID style */}
      <style jsx>{`
        .link-elderly-page-wrapper {
          min-height: 100vh;
          display: flex;
          align-items: flex-start;
          justify-content: center;
          background: linear-gradient(to bottom right, #e0e7ff, #ffffff, #f3e8ff);
          padding: 2rem 1rem;
        }
        
        .link-elderly-page-content {
          max-width: 1200px;
          width: 100%;
        }
        
        .link-elderly-page-header {
          text-align: center;
          margin-bottom: 2rem;
        }
        
        .link-elderly-page-header-icon {
          display: inline-flex;
          align-items: center;
          justify-content: center;
          width: 4rem;
          height: 4rem;
          background: #2563eb;
          border-radius: 50%;
          margin-bottom: 1rem;
        }
        
        .link-elderly-page-header-link-icon {
          width: 2rem;
          height: 2rem;
          color: #fff;
        }
        
        .link-elderly-page-title {
          font-size: 2rem;
          font-weight: bold;
          color: #1f2937;
          margin-bottom: 0.5rem;
        }
        
        .link-elderly-page-subtitle {
          color: #6b7280;
          font-size: 1.1rem;
          line-height: 1.5;
        }
        
        .link-elderly-form-card {
          background: #fff;
          border-radius: 1rem;
          box-shadow: 0 4px 12px rgba(0,0,0,0.1);
          padding: 2rem;
          border: 1px solid #e5e7eb;
        }
        
        .link-elderly-form-label {
          display: block;
          font-size: 1rem;
          font-weight: 600;
          margin-bottom: 0.75rem;
          color: #374151;
        }
        
        .link-elderly-search-container {
          display: flex;
          gap: 0.75rem;
          margin-bottom: 1.5rem;
          align-items: stretch;
        }
        
        .link-elderly-form-input-wrapper {
          position: relative;
          flex: 1;
        }
        
        .link-elderly-form-input-icon {
          position: absolute;
          left: 0.75rem;
          top: 50%;
          transform: translateY(-50%);
          color: #9ca3af;
          width: 1.25rem;
          height: 1.25rem;
        }
        
        .link-elderly-form-input {
          width: 88%;
          height: 50%;
          padding: 0.75rem 0.75rem 0.75rem 2.5rem;
          border: 2px solid #d1d5db;
          border-radius: 0.75rem;
          font-size: 1rem;
          transition: all 0.2s;
        }
        
        .link-elderly-form-input:focus {
          outline: none;
          border-color: #2563eb;
          box-shadow: 0 0 0 3px rgba(37, 99, 235, 0.1);
        }
        
        .link-elderly-form-input:disabled {
          background-color: #f9fafb;
          cursor: not-allowed;
        }
        
        .link-elderly-search-button {
          display: flex;
          align-items: center;
          gap: 0.5rem;
          padding: 0.75rem 1.5rem;
          border-radius: 0.75rem;
          font-weight: 600;
          background: #2563eb;
          color: white;
          border: none;
          cursor: pointer;
          transition: all 0.2s;
          font-size: 1rem;
          white-space: nowrap;
          height: auto;
        }
        
        .link-elderly-search-button:hover:not(:disabled) {
          background: #1e40af;
          transform: translateY(-1px);
        }
        
        .link-elderly-search-button:disabled {
          background: #9ca3af;
          cursor: not-allowed;
          transform: none;
        }
        
        .link-elderly-search-button-loader {
          width: 1rem;
          height: 1rem;
          animation: link-elderly-spin 1s linear infinite;
        }
        
        .link-elderly-search-button-icon {
          width: 1rem;
          height: 1rem;
        }
        
        .link-elderly-error-box {
          display: flex;
          align-items: center;
          gap: 0.5rem;
          padding: 1rem;
          margin-bottom: 1.5rem;
          background: #fef2f2;
          border: 1px solid #fecaca;
          color: #b91c1c;
          border-radius: 0.75rem;
          font-size: 0.875rem;
        }
        
        .link-elderly-error-icon {
          width: 1.25rem;
          height: 1.25rem;
          flex-shrink: 0;
        }
        
        .link-elderly-results-list {
          display: flex;
          flex-direction: column;
          gap: 1rem;
          margin-bottom: 1.5rem;
        }
        
        .link-elderly-result-card {
          border: 2px solid #e5e7eb;
          border-radius: 0.75rem;
          padding: 1.5rem;
          background: linear-gradient(to right, #f8fafc, #fdf4ff);
          transition: all 0.2s;
        }
        
        .link-elderly-result-card:hover {
          border-color: #2563eb;
          box-shadow: 0 2px 8px rgba(37, 99, 235, 0.1);
        }
        
        .link-elderly-result-header {
          display: flex;
          align-items: flex-start;
          gap: 1rem;
          margin-bottom: 1rem;
        }
        
        .link-elderly-result-avatar {
          font-size: 2.5rem;
          flex-shrink: 0;
        }
        
        .link-elderly-result-info {
          flex: 1;
        }
        
        .link-elderly-result-name {
          font-weight: 700;
          color: #1f2937;
          margin: 0 0 0.25rem 0;
          font-size: 1.25rem;
        }
        
        .link-elderly-result-email {
          color: #6b7280;
          margin: 0 0 0.25rem 0;
          font-size: 0.875rem;
        }
        
        .link-elderly-result-age {
          font-size: 0.875rem;
          color: #6b7280;
          margin: 0 0 0.25rem 0;
        }
        
        .link-elderly-result-uid {
          font-size: 0.75rem;
          color: #9ca3af;
          margin: 0 0 0.5rem 0;
          font-family: monospace;
        }
        
        .link-elderly-warning-text {
          color: #dc2626;
          font-size: 0.875rem;
          font-weight: 600;
          margin: 0;
          display: flex;
          align-items: center;
          gap: 0.25rem;
        }
        
        .link-elderly-primary-button {
          background: #2563eb;
          color: white;
          padding: 0.75rem 1.5rem;
          border-radius: 0.75rem;
          font-weight: 600;
          transition: all 0.2s;
          border: none;
          cursor: pointer;
          font-size: 1rem;
          display: block;
          width: 100%;
        }
        
        .link-elderly-primary-button:hover {
          background: #1e40af;
          transform: translateY(-1px);
        }
        
        .link-elderly-with-icon {
          display: flex;
          align-items: center;
          justify-content: center;
          gap: 0.5rem;
        }
        
        .link-elderly-button-icon {
          width: 1.25rem;
          height: 1.25rem;
        }
        
        .link-elderly-disabled-button {
          background: #9ca3af;
          color: white;
          padding: 0.75rem 1.5rem;
          border-radius: 0.75rem;
          font-weight: 600;
          border: none;
          cursor: not-allowed;
          font-size: 1rem;
          display: block;
          width: 100%;
        }
        
        .link-elderly-pending-box {
          border: 2px solid #bfdbfe;
          border-radius: 0.75rem;
          padding: 1.5rem;
          background: #eff6ff;
          margin-bottom: 1.5rem;
        }
        
        .link-elderly-pending-header {
          display: flex;
          align-items: center;
          gap: 0.75rem;
          margin-bottom: 0.75rem;
        }
        
        .link-elderly-pending-spinner {
          width: 1.5rem;
          height: 1.5rem;
          color: #2563eb;
          animation: link-elderly-spin 1s linear infinite;
        }
        
        @keyframes link-elderly-spin {
          to { transform: rotate(360deg); }
        }
        
        .link-elderly-pending-title {
          font-weight: 600;
          color: #1f2937;
          margin: 0;
          font-size: 1.125rem;
        }
        
        .link-elderly-pending-text {
          color: #4b5563;
          margin: 0;
          font-size: 0.875rem;
          line-height: 1.5;
        }
        
        .link-elderly-info-box {
          margin-top: 1.5rem;
          background: #f9fafb;
          border: 1px solid #e5e7eb;
          border-radius: 0.75rem;
          padding: 1.5rem;
          font-size: 0.875rem;
          color: #4b5563;
        }
        
        .link-elderly-info-header {
          display: flex;
          align-items: center;
          gap: 0.5rem;
          font-weight: 600;
          margin-bottom: 0.75rem;
          color: #1f2937;
          font-size: 1rem;
        }
        
        .link-elderly-info-icon {
          width: 1.25rem;
          height: 1.25rem;
          color: #2563eb;
        }
        
        .link-elderly-info-list {
          list-style: disc;
          padding-left: 1.5rem;
          margin: 0;
          line-height: 1.6;
        }
        
        .link-elderly-info-list li {
          margin-bottom: 0.5rem;
        }
        
        .link-elderly-success-card {
          max-width: 28rem;
          width: 100%;
          background: white;
          border-radius: 1rem;
          box-shadow: 0 8px 16px rgba(0,0,0,0.1);
          padding: 2rem;
          text-align: center;
        }
        
        .link-elderly-success-icon-wrapper {
          display: flex;
          justify-content: center;
          margin-bottom: 1.5rem;
        }
        
        .link-elderly-success-icon-circle {
          background: #dcfce7;
          padding: 1rem;
          border-radius: 50%;
        }
        
        .link-elderly-success-icon {
          width: 4rem;
          height: 4rem;
          color: #16a34a;
        }
        
        .link-elderly-success-title {
          font-size: 1.5rem;
          font-weight: bold;
          color: #1f2937;
          margin-bottom: 0.5rem;
        }
        
        .link-elderly-success-message {
          color: #6b7280;
          margin-bottom: 1.5rem;
          line-height: 1.5;
        }
        
        .link-elderly-connected-box {
          background: #eff6ff;
          padding: 1rem;
          border-radius: 0.75rem;
          margin-bottom: 1.5rem;
          display: flex;
          align-items: center;
          justify-content: center;
          gap: 0.5rem;
          font-weight: 600;
          color: #1e40af;
        }
        
        .link-elderly-connected-icon {
          width: 1.25rem;
          height: 1.25rem;
        }

        /* Responsive Design */
        @media (max-width: 768px) {
          .link-elderly-page-wrapper {
            padding: 1rem 0.5rem;
            align-items: flex-start;
          }
          
          .link-elderly-page-content {
            max-width: 100%;
          }
          
          .link-elderly-form-card {
            padding: 1.5rem;
          }
          
          .link-elderly-search-container {
            flex-direction: column;
          }
          
          .link-elderly-search-button {
            justify-content: center;
          }
          
          .link-elderly-page-title {
            font-size: 1.75rem;
          }
          
          .link-elderly-page-subtitle {
            font-size: 1rem;
          }
        }
      `}</style>
    </div>
  );
}