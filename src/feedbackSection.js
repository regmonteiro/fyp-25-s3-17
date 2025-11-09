// src/components/FeedbackSection.js
import React, { useState, useEffect } from "react";
import { ref, onValue, push, get } from "firebase/database";
import { database } from "./firebaseConfig";

const FeedbackSection = () => {
  const [feedbacks, setFeedbacks] = useState([]);
  const [loading, setLoading] = useState(true);
  const [showForm, setShowForm] = useState(false);
  const [submitting, setSubmitting] = useState(false);
  const [currentIndex, setCurrentIndex] = useState(0);
  const [formData, setFormData] = useState({
    name: "",
    email: "",
    rating: 0,
    comment: "",
    userType: ""
  });

  useEffect(() => {
    const feedbackRef = ref(database, "feedback");
    const unsubscribe = onValue(
      feedbackRef,
      (snapshot) => {
        const data = snapshot.val();
        if (data) {
          const feedbackArray = Object.values(data);
          feedbackArray.sort((a, b) => new Date(b.date) - new Date(a.date));
          setFeedbacks(feedbackArray);
        } else {
          setFeedbacks([]);
        }
        setLoading(false);
      },
      (error) => {
        console.error("Failed to read feedback:", error);
        setFeedbacks([]);
        setLoading(false);
      }
    );

    return () => unsubscribe();
  }, []);

  const getInitials = (email) => {
    if (!email) return "?";
    const namePart = email.split("@")[0];
    const parts = namePart.split(/[.\-_]/).filter(Boolean);
    if (parts.length === 0) return email[0].toUpperCase();
    if (parts.length === 1) return parts[0][0].toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  };

  const handleInputChange = (e) => {
    const { name, value } = e.target;
    setFormData({
      ...formData,
      [name]: value
    });
  };

  const handleRatingChange = (rating) => {
    setFormData({
      ...formData,
      rating
    });
  };

  const getUserTypeFromEmail = async (email) => {
    if (!email) return "guest";
    
    try {
      // Convert email to the format used as keys in the database
      const dbEmailKey = email.replace(/\./g, '_');
      
      // Check if this email exists in the Account section
      const accountRef = ref(database, `Account/${dbEmailKey}`);
      const snapshot = await get(accountRef);
      
      if (snapshot.exists()) {
        const userData = snapshot.val();
        console.log(`Found user data for ${email}:`, userData);
        
        // Return the userType if found
        return userData.userType || "guest";
      }
      
      console.log(`Email ${email} not found in user database`);
      return "guest";
    } catch (error) {
      console.error("Error fetching user data:", error);
      return "guest";
    }
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    setSubmitting(true);
    
    try {
      console.log("Form submitted with email:", formData.email);
      
      // Check if email exists in database and get userType
      const detectedUserType = await getUserTypeFromEmail(formData.email);
      console.log("Detected user type:", detectedUserType);
      
      const feedbackRef = ref(database, "feedback");
      await push(feedbackRef, {
        userName: formData.name,
        userEmail: formData.email,
        rating: formData.rating,
        comment: formData.comment,
        userType: detectedUserType,
        date: new Date().toISOString()
      });
      
      // Reset form
      setFormData({
        name: "",
        email: "",
        rating: 0,
        comment: "",
        userType: ""
      });
      
      setShowForm(false);
      alert("Thank you for your feedback!");
    } catch (error) {
      console.error("Error submitting feedback:", error);
      alert("There was an error submitting your feedback. Please try again.");
    } finally {
      setSubmitting(false);
    }
  };

  const handleCancel = () => {
    setShowForm(false);
    setFormData({
      name: "",
      email: "",
      rating: 0,
      comment: "",
      userType: ""
    });
  };

  const nextFeedback = () => {
    setCurrentIndex((prevIndex) => 
      prevIndex + 3 >= feedbacks.length ? 0 : prevIndex + 3
    );
  };

  const prevFeedback = () => {
    setCurrentIndex((prevIndex) => 
      prevIndex - 3 < 0 ? Math.max(0, feedbacks.length - 3) : prevIndex - 3
    );
  };

  if (loading) return <p>Loading feedback...</p>;

  return (
    <div className="feedback-section">
      <style>{`
        .feedback-section {
          width: 100%;
          margin: 60px 0;
          padding: 40px 0;
          background: linear-gradient(135deg, #f5f7ff 0%, #e3e8ff 100%);
          position: relative;
          overflow: hidden;
        }
        
        .feedback-container {
          max-width: 1200px;
          margin: 0 auto;
          padding: 0 20px;
          position: relative;
          z-index: 1;
        }
        
        .feedback-title {
          text-align: center;
          font-size: 2rem;
          font-weight: 700;
          margin-bottom: 40px;
          color: #2d2d5a;
          position: relative;
        }
        
        .feedback-title::after {
          content: "";
          position: absolute;
          bottom: -12px;
          left: 50%;
          transform: translateX(-50%);
          width: 50px;
          height: 3px;
          background: linear-gradient(90deg, #7877ed, #ff6b6b);
          border-radius: 2px;
        }
        
        .feedback-grid {
          display: grid;
          grid-template-columns: repeat(3, 1fr);
          gap: 25px;
          margin-bottom: 40px;
        }
        
        .feedback-card {
          background: white;
          border-radius: 14px;
          padding: 25px;
          box-shadow: 0 8px 25px rgba(0,0,0,0.08);
          position: relative;
          transition: all 0.3s ease;
        }
        
        .feedback-card:hover {
          transform: translateY(-5px);
          box-shadow: 0 12px 30px rgba(0,0,0,0.12);
        }
        
        .feedback-card::before {
          content: """;
          position: absolute;
          top: 18px;
          right: 18px;
          font-size: 50px;
          color: #e3e8ff;
          font-family: Georgia, serif;
          line-height: 1;
        }
        
        .feedback-header {
          display: flex;
          align-items: center;
          margin-bottom: 18px;
        }
        
        .feedback-avatar {
          width: 50px;
          height: 50px;
          border-radius: 50%;
          background: linear-gradient(45deg, #7877ed, #5a59d3);
          color: white;
          font-weight: bold;
          font-size: 1.2rem;
          text-align: center;
          line-height: 50px;
          margin-right: 15px;
          box-shadow: 0 4px 10px rgba(120, 119, 237, 0.3);
        }
        
        .feedback-info {
          flex: 1;
        }
        
        .feedback-role {
          font-size: 0.85rem;
          color: #7877ed;
          font-weight: 600;
          margin-bottom: 4px;
        }
        
        .feedback-name {
          font-weight: 700;
          color: #2d2d5a;
          font-size: 1rem;
        }
        
        .feedback-comment {
          color: #555;
          line-height: 1.6;
          font-size: 0.95rem;
          margin-bottom: 18px;
          position: relative;
          z-index: 1;
        }
        
        .feedback-rating {
          color: #ffc107;
          font-size: 1rem;
          letter-spacing: 1.5px;
        }
        
        .feedback-navigation {
          display: flex;
          justify-content: center;
          gap: 12px;
          margin-top: 25px;
        }
        
        .nav-button {
          background: white;
          border: 2px solid #7877ed;
          color: #7877ed;
          width: 45px;
          height: 45px;
          border-radius: 50%;
          display: flex;
          align-items: center;
          justify-content: center;
          font-size: 1.1rem;
          cursor: pointer;
          transition: all 0.3s ease;
        }
        
        .nav-button:hover {
          background: #7877ed;
          color: white;
          transform: scale(1.1);
        }
        
        .feedback-actions {
          text-align: center;
          margin-top: 35px;
        }
        
        .feedback-toggle-btn {
          background: linear-gradient(90deg, #7877ed, #ff6b6b);
          color: white;
          border: none;
          padding: 14px 28px;
          border-radius: 50px;
          font-weight: 600;
          cursor: pointer;
          transition: all 0.3s ease;
          box-shadow: 0 5px 15px rgba(120, 119, 237, 0.4);
          font-size: 1rem;
          position: relative;
          overflow: hidden;
          z-index: 1;
        }
        
        .feedback-toggle-btn::before {
          content: "";
          position: absolute;
          top: 0;
          left: 0;
          width: 100%;
          height: 100%;
          background: linear-gradient(90deg, #ff6b6b, #7877ed);
          opacity: 0;
          transition: opacity 0.3s ease;
          z-index: -1;
        }
        
        .feedback-toggle-btn:hover {
          transform: translateY(-2px);
          box-shadow: 0 7px 20px rgba(120, 119, 237, 0.5);
        }
        
        .feedback-toggle-btn:hover::before {
          opacity: 1;
        }
        
        .feedback-form-overlay {
          position: fixed;
          top: 0;
          left: 0;
          right: 0;
          bottom: 0;
          background: rgba(45, 45, 90, 0.85);
          display: flex;
          justify-content: center;
          align-items: center;
          z-index: 1000;
          padding: 20px;
          animation: fadeIn 0.3s ease;
        }
        
        .feedback-form {
          background: white;
          padding: 30px;
          border-radius: 18px;
          width: 100%;
          max-width: 700px; 
          box-shadow: 0 15px 40px rgba(0, 0, 0, 0.2);
          animation: slideUp 0.3s ease;
          max-height: 80vh;
          overflow-y: auto;
          position: relative;
        }
        
        .feedback-form h3 {
          margin-top: 0;
          margin-bottom: 25px;
          text-align: center;
          color: #2d2d5a;
          font-size: 1.6rem; /* Slightly larger title */
          font-weight: 700;
        }
        
        .form-group {
          margin-bottom: 22px; /* Slightly more spacing */
        }
        
        .form-group label {
          display: block;
          margin-bottom: 8px;
          font-weight: 600;
          color: #444;
          font-size: 0.95rem;
        }
        
        .form-group input,
        .form-group textarea {
          width: 100%;
          padding: 14px 18px; /* Slightly larger padding */
          border: 2px solid #e2e2f0;
          border-radius: 10px;
          font-size: 1rem; /* Slightly larger font */
          transition: all 0.3s;
          box-sizing: border-box;
          font-family: inherit;
        }
        
        .form-group input:focus,
        .form-group textarea:focus {
          outline: none;
          border-color: #7877ed;
          box-shadow: 0 0 0 3px rgba(120, 119, 237, 0.2);
        }
        
        .rating-stars {
          display: flex;
          gap: 8px; /* Slightly more spacing between stars */
        }
        
        .rating-stars .star {
          font-size: 2rem; /* Larger stars */
          color: #e2e2f0;
          cursor: pointer;
          transition: all 0.2s;
        }
        
        .rating-stars .star.selected {
          color: #ffc107;
          text-shadow: 0 2px 5px rgba(255, 193, 7, 0.4);
        }
        
        .rating-stars .star:hover {
          color: #ffc107;
          transform: scale(1.15);
        }
        
        .form-buttons {
          display: flex;
          gap: 15px; /* Slightly more spacing between buttons */
          margin-top: 15px;
        }
        
        .submit-btn {
          background: linear-gradient(90deg, #7877ed, #5a59d3);
          color: white;
          border: none;
          padding: 14px 24px; /* Slightly larger buttons */
          border-radius: 10px;
          font-weight: 600;
          cursor: pointer;
          transition: all 0.3s ease;
          flex: 2;
          font-size: 1rem; /* Slightly larger font */
        }
        
        .submit-btn:hover:not(:disabled) {
          transform: translateY(-2px);
          box-shadow: 0 5px 12px rgba(120, 119, 237, 0.4);
        }
        
        .submit-btn:disabled {
          opacity: 0.7;
          cursor: not-allowed;
        }
        
        .cancel-btn {
          background: #f0f0f7;
          color: #666;
          border: none;
          padding: 14px 24px; /* Slightly larger buttons */
          border-radius: 10px;
          font-weight: 600;
          cursor: pointer;
          transition: all 0.3s ease;
          flex: 1;
          font-size: 1rem; /* Slightly larger font */
        }
        
        .cancel-btn:hover {
          background: #e2e2f0;
          transform: translateY(-2px);
        }
        
        .close-form {
          position: absolute;
          top: 18px;
          right: 18px;
          background: #f0f0f7;
          width: 38px;
          height: 38px;
          border: none;
          border-radius: 50%;
          font-size: 1.4rem;
          color: #666;
          cursor: pointer;
          display: flex;
          justify-content: center;
          align-items: center;
          transition: all 0.3s;
        }
        
        .close-form:hover {
          background: #ff6b6b;
          color: white;
          transform: rotate(90deg);
        }
        
        @keyframes fadeIn {
          from { opacity: 0; }
          to { opacity: 1; }
        }
        
        @keyframes slideUp {
          from { 
            opacity: 0;
            transform: translateY(30px);
          }
          to { 
            opacity: 1;
            transform: translateY(0);
          }
        }
        
        @media (max-width: 968px) {
          .feedback-grid {
            grid-template-columns: repeat(2, 1fr);
          }
        }
        
        @media (max-width: 768px) {
          .feedback-section {
            padding: 30px 0;
          }
          
          .feedback-title {
            font-size: 1.7rem;
          }
          
          .feedback-grid {
            grid-template-columns: 1fr;
          }
          
          .feedback-form {
            padding: 25px;
            max-width: 90%;
          }
          
          .rating-stars .star {
            font-size: 1.8rem;
          }
          
          .form-buttons {
            flex-direction: column;
          }
        }
      `}</style>

      <div className="feedback-container">
        <h2 className="feedback-title">What Our Users Say</h2>

        {feedbacks.length === 0 ? (
          <p style={{ textAlign: "center", color: "#666", padding: "40px 20px" }}>
            No feedback yet. Be the first to share your experience!
          </p>
        ) : (
          <>
            <div className="feedback-grid">
              {feedbacks.slice(currentIndex, currentIndex + 3).map((fb, idx) => (
                <div key={idx} className="feedback-card">
                  <div className="feedback-header">
                    <div className="feedback-avatar">{getInitials(fb.userEmail)}</div>
                    <div className="feedback-info">
                      
                      <div className="feedback-name">{fb.userName || fb.userEmail}</div>
                    </div>
                  </div>
                  <p className="feedback-comment">{fb.comment}</p>
                  <div className="feedback-rating">
                    {"★".repeat(fb.rating) + "☆".repeat(5 - fb.rating)}
                  </div>
                </div>
              ))}
            </div>
            
            {feedbacks.length > 3 && (
              <div className="feedback-navigation">
                <button className="nav-button" onClick={prevFeedback}>‹</button>
                <button className="nav-button" onClick={nextFeedback}>›</button>
              </div>
            )}
          </>
        )}
        
        <div className="feedback-actions">
          <button 
            className="feedback-toggle-btn"
            onClick={() => setShowForm(true)}
          >
            Share Feedback
          </button>
        </div>
        
        {showForm && (
          <div className="feedback-form-overlay">
            <form className="feedback-form" onSubmit={handleSubmit}>
              <button 
                type="button"
                className="close-form"
                onClick={handleCancel}
              >
                ×
              </button>
              <h3>Share Feedback</h3>
              
              <div className="form-group">
                <label htmlFor="name">Your Name</label>
                <input
                  type="text"
                  id="name"
                  name="name"
                  value={formData.name}
                  onChange={handleInputChange}
                  required
                  placeholder="Enter your name"
                />
              </div>
              
              <div className="form-group">
                <label htmlFor="email">Email Address</label>
                <input
                  type="email"
                  id="email"
                  name="email"
                  value={formData.email}
                  onChange={handleInputChange}
                  required
                  placeholder="Enter your email"
                />
              </div>
              
              <div className="form-group">
                <label>Your Rating</label>
                <div className="rating-stars">
                  {[1, 2, 3, 4, 5].map((star) => (
                    <span
                      key={star}
                      className={`star ${star <= formData.rating ? 'selected' : ''}`}
                      onClick={() => handleRatingChange(star)}
                    >
                      ★
                    </span>
                  ))}
                </div>
              </div>
              
              <div className="form-group">
                <label htmlFor="comment">Your Feedback</label>
                <textarea
                  id="comment"
                  name="comment"
                  value={formData.comment}
                  onChange={handleInputChange}
                  required
                  rows="4"
                  placeholder="Share your thoughts about our service..."
                ></textarea>
              </div>
              
              <div className="form-buttons">
                <button 
                  type="submit" 
                  className="submit-btn"
                  disabled={submitting}
                >
                  {submitting ? 'Submitting...' : 'Submit Feedback'}
                </button>
                <button 
                  type="button" 
                  className="cancel-btn"
                  onClick={handleCancel}
                >
                  Cancel
                </button>
              </div>
            </form>
          </div>
        )}
      </div>
    </div>
  );
};

export default FeedbackSection;