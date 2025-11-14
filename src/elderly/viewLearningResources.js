import React, { useState, useEffect } from "react";
import { database, ref, get, set, update } from "../firebaseConfig";
import Footer from "../footer";
import { Search, Filter, Star, Trophy, Gift, History, BookOpen, Play, ExternalLink, Sparkles, Clock, Calendar, Flame, Zap, Target, Users, Shield, Heart, Brain, Dumbbell, Download, X } from "lucide-react";
import ViewLearningResourceController from "../controller/viewLearningResourceController";
import FloatingAssistant from "../components/floatingassistantChat";

// Import  voucher image
import voucherImage from "./voucher.png"; // Adjust the path as needed

const currentUser = localStorage.getItem("loggedInEmail");

const styles = {
  container: {
    maxWidth: "1400px",
    margin: "0 auto",
    padding: "20px",
    fontFamily: "'Segoe UI', Tahoma, Geneva, Verdana, sans-serif",
  },
  
  hero: {
    textAlign: "center",
    marginBottom: "40px",
    padding: "40px 20px",
    background: "linear-gradient(135deg, #667eea 0%, #764ba2 100%)",
    borderRadius: "15px",
    color: "white",
  },
  
  heroTitle: {
    fontSize: "2.5rem",
    fontWeight: "700",
    marginBottom: "10px",
  },
  
  heroSubtitle: {
    fontSize: "1.2rem",
    opacity: "0.9",
    maxWidth: "600px",
    margin: "0 auto",
  },
  
  rewardsCard: {
    backgroundColor: "white",
    borderRadius: "15px",
    padding: "25px",
    marginBottom: "30px",
    boxShadow: "0 4px 15px rgba(0,0,0,0.1)",
    border: "1px solid #e0e0e0",
  },
  
  rewardsHeader: {
    display: "flex",
    justifyContent: "space-between",
    alignItems: "center",
    marginBottom: "20px",
  },
  
  rewardsTitle: {
    display: "flex",
    alignItems: "center",
    gap: "10px",
    fontSize: "1.5rem",
    fontWeight: "600",
    color: "#333",
  },
  
  pointsCircle: {
    display: "flex",
    flexDirection: "column",
    alignItems: "center",
    justifyContent: "center",
    width: "80px",
    height: "80px",
    borderRadius: "50%",
    background: "linear-gradient(135deg, #5377f6ff 0%, #0154edff 100%)",
    color: "white",
    fontWeight: "bold",
  },
  
  pointsValue: {
    fontSize: "1.8rem",
    lineHeight: "1",
  },
  
  pointsLabel: {
    fontSize: "0.7rem",
    opacity: "0.9",
  },
  
  rewardsContent: {
    display: "grid",
    gridTemplateColumns: "1fr 1fr",
    gap: "30px",
    marginBottom: "20px",
  },
  
  progressSection: {
    display: "flex",
    flexDirection: "column",
    gap: "10px",
  },
  
  progressText: {
    display: "flex",
    justifyContent: "space-between",
    fontSize: "0.9rem",
    color: "#666",
  },
  
  progressBar: {
    width: "100%",
    height: "8px",
    backgroundColor: "#f0f0f0",
    borderRadius: "10px",
    overflow: "hidden",
  },
  
  progressFill: {
    height: "100%",
    background: "linear-gradient(90deg, #0e39e8ff 0%, #3568eaff 100%)",
    borderRadius: "10px",
    transition: "width 0.3s ease",
  },
  
  redeemSection: {
    display: "flex",
    flexDirection: "column",
    alignItems: "center",
    gap: "15px",
  },
  
  voucherBadge: {
    backgroundColor: "#fff3cd",
    color: "#856404",
    padding: "8px 15px",
    borderRadius: "20px",
    fontSize: "0.9rem",
    fontWeight: "600",
  },
  
  redeemButton: {
    display: "flex",
    alignItems: "center",
    gap: "8px",
    backgroundColor: "#4CAF50",
    color: "white",
    border: "none",
    padding: "12px 24px",
    borderRadius: "25px",
    fontSize: "1rem",
    fontWeight: "600",
    cursor: "pointer",
    transition: "all 0.3s ease",
  },
  
  redeemButtonDisabled: {
    backgroundColor: "#cccccc",
    cursor: "not-allowed",
    opacity: "0.6",
  },
  
  achievementsRow: {
    display: "flex",
    justifyContent: "space-between",
    alignItems: "center",
    paddingTop: "15px",
    borderTop: "1px solid #f0f0f0",
  },
  
  achievementBadge: {
    backgroundColor: "#e9ecef",
    color: "#495057",
    padding: "6px 12px",
    borderRadius: "15px",
    fontSize: "0.8rem",
    fontWeight: "500",
  },
  
  searchInput: {
    width: "100%",
    padding: "15px 20px",
    fontSize: "1rem",
    border: "2px solid #e0e0e0",
    borderRadius: "50px",
    marginBottom: "30px",
    outline: "none",
    transition: "all 0.3s ease",
  },
  
  filterSection: {
    marginBottom: "30px",
  },
  
  filterTitle: {
    fontSize: "1.2rem",
    fontWeight: "600",
    marginBottom: "15px",
    color: "#333",
  },
  
  categoryContainer: {
    display: "flex",
    flexWrap: "wrap",
    gap: "10px",
  },
  
  categoryButton: {
    padding: "10px 20px",
    border: "2px solid #e0e0e0",
    borderRadius: "25px",
    backgroundColor: "white",
    cursor: "pointer",
    fontSize: "0.9rem",
    fontWeight: "500",
    transition: "all 0.3s ease",
  },
  
  categoryButtonActive: {
    backgroundColor: "#667eea",
    color: "white",
    borderColor: "#667eea",
  },
  
  grid: {
    display: "grid",
    gridTemplateColumns: "repeat(auto-fill, minmax(350px, 1fr))",
    gap: "25px",
    marginBottom: "40px",
  },
  
  card: {
    backgroundColor: "white",
    border: "2px solid #f0f0f0",
    borderRadius: "15px",
    padding: "20px",
    cursor: "pointer",
    transition: "all 0.3s ease",
    boxShadow: "0 2px 10px rgba(0,0,0,0.05)",
  },
  
  cardHover: {
    transform: "translateY(-5px)",
    boxShadow: "0 8px 25px rgba(0,0,0,0.15)",
    borderColor: "#667eea",
  },
  
  titleLink: {
    fontSize: "1.2rem",
    fontWeight: "600",
    color: "#333",
    textDecoration: "none",
    marginBottom: "10px",
    display: "block",
  },
  
  description: {
    color: "#666",
    fontSize: "0.95rem",
    lineHeight: "1.5",
    marginBottom: "15px",
  },
  
  categoryTag: {
    backgroundColor: "#e9ecef",
    color: "#495057",
    padding: "4px 12px",
    borderRadius: "15px",
    fontSize: "0.8rem",
    fontWeight: "500",
  },
  
  iframeContainer: {
    marginTop: "40px",
    borderRadius: "15px",
    overflow: "hidden",
    boxShadow: "0 4px 20px rgba(0,0,0,0.1)",
  },
  
  iframe: {
    width: "100%",
    height: "600px",
    border: "none",
  },
  
  error: {
    color: "#dc3545",
    textAlign: "center",
    padding: "20px",
    fontSize: "1.1rem",
  },
  
  loading: {
    textAlign: "center",
    padding: "40px",
    fontSize: "1.2rem",
    color: "#666",
  },

  streakIndicator: {
    display: "flex",
    alignItems: "center",
    gap: "8px",
    backgroundColor: "#fff3cd",
    border: "1px solid #ffeaa7",
    borderRadius: "20px",
    padding: "8px 16px",
    marginBottom: "16px",
    fontSize: "0.9rem",
    fontWeight: "600",
    color: "#856404",
  },

  pointsEarnedPopup: {
    position: "fixed",
    top: "20px",
    right: "20px",
    backgroundColor: "#4caf50",
    color: "white",
    padding: "12px 20px",
    borderRadius: "8px",
    boxShadow: "0 4px 12px rgba(0,0,0,0.3)",
    zIndex: 1000,
    animation: "slideIn 0.5s ease-out",
    display: "flex",
    alignItems: "center",
    gap: "8px",
  },

  streakBonus: {
    backgroundColor: "#ff6b6b",
    color: "white",
    padding: "4px 8px",
    borderRadius: "12px",
    fontSize: "0.8rem",
    marginLeft: "8px",
  },

  statsGrid: {
    display: "grid",
    gridTemplateColumns: "repeat(auto-fit, minmax(200px, 1fr))",
    gap: "15px",
    marginBottom: "20px",
  },

  statCard: {
    backgroundColor: "#f8f9fa",
    padding: "15px",
    borderRadius: "10px",
    textAlign: "center",
  },

  statValue: {
    fontSize: "1.5rem",
    fontWeight: "bold",
    color: "#667eea",
    margin: "5px 0",
  },

  statLabel: {
    fontSize: "0.8rem",
    color: "#666",
  },

  // New styles for voucher system
  voucherModal: {
    position: "fixed",
    top: "0",
    left: "0",
    width: "100%",
    height: "100%",
    backgroundColor: "rgba(0,0,0,0.7)",
    display: "flex",
    justifyContent: "center",
    alignItems: "center",
    zIndex: 2000,
  },
  
  voucherContent: {
    backgroundColor: "white",
    borderRadius: "15px",
    padding: "30px",
    maxWidth: "500px",
    width: "90%",
    textAlign: "center",
    boxShadow: "0 10px 30px rgba(0,0,0,0.3)",
    position: "relative",
  },
  
  closeButton: {
    position: "absolute",
    top: "15px",
    right: "15px",
    background: "none",
    border: "none",
    fontSize: "1.5rem",
    cursor: "pointer",
    color: "#666",
  },
  
  voucherImage: {
    width: "100%",
    maxWidth: "400px",
    borderRadius: "10px",
    margin: "20px 0",
    border: "2px solid #e0e0e0",
  },
  
  voucherActions: {
    display: "flex",
    gap: "10px",
    justifyContent: "center",
    marginTop: "20px",
  },
  
  voucherButton: {
    padding: "12px 24px",
    borderRadius: "25px",
    border: "none",
    fontSize: "1rem",
    fontWeight: "600",
    cursor: "pointer",
    display: "flex",
    alignItems: "center",
    gap: "8px",
    transition: "all 0.3s ease",
  },
  
  downloadButton: {
    backgroundColor: "#4CAF50",
    color: "white",
  },
  
  closeVoucherButton: {
    backgroundColor: "#6c757d",
    color: "white",
  },
  
  redemptionHistory: {
    backgroundColor: "white",
    borderRadius: "15px",
    padding: "25px",
    marginTop: "30px",
    boxShadow: "0 4px 15px rgba(0,0,0,0.1)",
  },
  
  historyTitle: {
    fontSize: "1.5rem",
    fontWeight: "600",
    marginBottom: "20px",
    color: "#333",
    display: "flex",
    alignItems: "center",
    gap: "10px",
  },
  
  historyGrid: {
    display: "grid",
    gridTemplateColumns: "repeat(auto-fill, minmax(300px, 1fr))",
    gap: "20px",
  },
  
  historyCard: {
    border: "2px solid #f0f0f0",
    borderRadius: "10px",
    padding: "15px",
    backgroundColor: "#f8f9fa",
    textAlign: "center",
  },
  
  historyVoucherImage: {
    width: "100%",
    maxWidth: "300px",
    borderRadius: "8px",
    marginBottom: "10px",
    border: "2px solid #e0e0e0",
  },
  
  historyDetails: {
    fontSize: "0.9rem",
    color: "#666",
  },
  
  noHistory: {
    textAlign: "center",
    padding: "40px",
    color: "#666",
    fontSize: "1.1rem",
  },
  
  voucherCodeDisplay: {
    backgroundColor: "#333",
    color: "white",
    padding: "10px",
    borderRadius: "8px",
    margin: "10px 0",
    fontSize: "0.9rem",
    fontWeight: "bold",
    letterSpacing: "1px",
  }
};

// Add CSS animation
const styleSheet = document.styleSheets[0];
if (styleSheet) {
  styleSheet.insertRule(`
    @keyframes slideIn {
      from { transform: translateX(100%); opacity: 0; }
      to { transform: translateX(0); opacity: 1; }
    }
  `, styleSheet.cssRules.length);
}

// Category icons mapping
const categoryIcons = {
  "Health": Heart,
  "Legal": Shield,
  "Mental Health": Brain,
  "Recreational": Users,
  "Safety": Shield,
  "Technology": Zap,
  "Exercise": Dumbbell,
  "Other": BookOpen,
};

export default function LearningResourcesPage() {
  const [resources, setResources] = useState([]);
  const [selectedResource, setSelectedResource] = useState(null);
  const [errorMessage, setErrorMessage] = useState("");
  const [loading, setLoading] = useState(true);
  const [hoveredId, setHoveredId] = useState(null);
  const [searchQuery, setSearchQuery] = useState("");
  const [selectedCategory, setSelectedCategory] = useState("All");
  
  // Combined user data state
  const [userData, setUserData] = useState({
    currentPoints: 0,
    totalEarned: 0,
    pointHistory: [],
    dailyStreak: 0,
    lastLearningDate: null,
    totalLearningTime: 0,
    resourcesClicked: [],
    learningSessions: [],
    totalResources: 0,
    completedResources: 0,
    averageTimePerSession: 0,
    redemptionHistory: []
  });

  const [dataLoading, setDataLoading] = useState(true);
  const [pointsPopup, setPointsPopup] = useState({ show: false, points: 0, message: "" });

  // Voucher redemption state
  const [voucherModal, setVoucherModal] = useState({
    show: false,
    vouchers: [],
    totalPointsRedeemed: 0
  });

  // Track time spent on resources
  const [timeTrackers, setTimeTrackers] = useState({});
  const [activeSession, setActiveSession] = useState(null);

  const simplifiedCategories = [
    "All",
    "Health",
    "Legal",
    "Mental Health",
    "Recreational",
    "Safety",
    "Technology",
    "Exercise",
  ];

  useEffect(() => {
    async function fetchResources() {
      try {
        const resourcesRef = ref(database, "resources");
        const snapshot = await get(resourcesRef);

        if (snapshot.exists()) {
          const data = snapshot.val();

          const simplifiedCategoryMap = {
            "Health": "Health",
            "Legal": "Legal",
            "Mental Health": "Mental Health",
            "Recreational": "Recreational",
            "Safety": "Safety",
            "Safety / Fraud Prevention": "Safety",
            "Exercise / Wellness": "Exercise",
            "Technology / Cybersecurity": "Technology",
            "Exercise": "Exercise",
            "Technology": "Technology"
          };

          const resourcesFromDb = Object.entries(data).map(([id, resource]) => {
            const simplifiedCategory =
              simplifiedCategoryMap[resource.category] || "Other";
            return { id, ...resource, category: simplifiedCategory };
          });

          setResources(resourcesFromDb);
        } else {
          setErrorMessage("No learning resources found.");
        }
      } catch (error) {
        console.error("Failed to load resources:", error);
        setErrorMessage("Failed to load resources. Please try again later.");
      } finally {
        setLoading(false);
      }
    }
    fetchResources();
  }, []);

  useEffect(() => {
    // Fetch combined user data from Account node
    async function fetchUserData() {
      try {
        const userEmail = localStorage.getItem("userEmail");
        if (!userEmail) {
          console.warn("No user email found in localStorage");
          setDataLoading(false);
          return;
        }

        // Use the same format as your database (replace . and @ with _)
        const sanitizedEmail = userEmail.replace(/[.@]/g, '_');
        
        // Fetch user data from Account node
        const userRef = ref(database, `Account/${sanitizedEmail}`);
        const userSnapshot = await get(userRef);

        if (userSnapshot.exists()) {
          const userDataFromDb = userSnapshot.val();
          
          // Initialize points data if it doesn't exist
          const pointsData = userDataFromDb.pointsData || {
            currentPoints: 0,
            totalEarned: 0,
            pointHistory: [],
            dailyStreak: 0,
            lastLearningDate: null,
            totalLearningTime: 0,
            resourcesClicked: [],
            learningSessions: [],
            totalResources: resources.length,
            completedResources: 0,
            averageTimePerSession: 0,
            redemptionHistory: []
          };

          setUserData({
            ...userDataFromDb,
            ...pointsData
          });
        } else {
          console.warn("User not found in Account node, initializing with default data");
          // Initialize with default data
          setUserData({
            currentPoints: 0,
            totalEarned: 0,
            pointHistory: [],
            dailyStreak: 0,
            lastLearningDate: null,
            totalLearningTime: 0,
            resourcesClicked: [],
            learningSessions: [],
            totalResources: resources.length,
            completedResources: 0,
            averageTimePerSession: 0,
            redemptionHistory: []
          });
        }

      } catch (error) {
        console.error("Failed to load user data:", error);
        setErrorMessage("Failed to load user data.");
      } finally {
        setDataLoading(false);
      }
    }

    if (resources.length > 0) {
      fetchUserData();
    }
  }, [resources.length]);

  // Function to update user data in database under Account node
  const updateUserDataInDatabase = async (updates) => {
    try {
      const userEmail = localStorage.getItem("userEmail");
      if (!userEmail) return;

      const sanitizedEmail = userEmail.replace(/[.@]/g, '_');
      const userRef = ref(database, `Account/${sanitizedEmail}`);
      const snapshot = await get(userRef);

      let currentUserData = {};
      let currentPointsData = {
        currentPoints: 0,
        totalEarned: 0,
        pointHistory: [],
        dailyStreak: 0,
        lastLearningDate: null,
        totalLearningTime: 0,
        resourcesClicked: [],
        learningSessions: [],
        totalResources: resources.length,
        completedResources: 0,
        averageTimePerSession: 0,
        redemptionHistory: []
      };
      
      if (snapshot.exists()) {
        currentUserData = snapshot.val();
        currentPointsData = currentUserData.pointsData || currentPointsData;
      }

      // Merge points data updates
      const updatedPointsData = { ...currentPointsData, ...updates };
      
      // Update the main user data with pointsData nested
      const updatedUserData = { 
        ...currentUserData, 
        pointsData: updatedPointsData,
        lastUpdated: new Date().toISOString()
      };

      // Update state first for immediate UI feedback
      setUserData(prev => ({
        ...prev,
        ...updatedPointsData
      }));
      
      // Then update database
      await set(userRef, updatedUserData);

      console.log("User data updated successfully");

    } catch (error) {
      console.error("Failed to update user data:", error);
    }
  };

  // Function to update points
  const updatePointsInDatabase = async (pointsToAdd, reason = "Learning activity") => {
    try {
      const userEmail = localStorage.getItem("userEmail");
      if (!userEmail) {
        console.error("No user email found");
        return;
      }

      const sanitizedEmail = userEmail.replace(/[.@]/g, '_');
      const userRef = ref(database, `Account/${sanitizedEmail}`);
      const snapshot = await get(userRef);

      let currentUserData = {};
      let currentPointsData = {
        currentPoints: 0,
        totalEarned: 0,
        pointHistory: [],
        dailyStreak: 0,
        lastLearningDate: null,
        totalLearningTime: 0,
        resourcesClicked: [],
        learningSessions: [],
        totalResources: resources.length,
        completedResources: 0,
        averageTimePerSession: 0,
        redemptionHistory: []
      };
      
      if (snapshot.exists()) {
        currentUserData = snapshot.val();
        currentPointsData = currentUserData.pointsData || currentPointsData;
      }

      const newCurrentPoints = (currentPointsData.currentPoints || 0) + pointsToAdd;
      const newTotalEarned = (currentPointsData.totalEarned || 0) + pointsToAdd;

      // Add to point history
      const newPointEntry = {
        points: pointsToAdd,
        reason: reason,
        timestamp: new Date().toISOString(),
        type: pointsToAdd > 0 ? "earning" : "redemption"
      };

      const updatedPointHistory = [
        ...(currentPointsData.pointHistory || []),
        newPointEntry
      ].slice(-50); // Keep last 50 entries

      const updatedPointsData = {
        ...currentPointsData,
        currentPoints: newCurrentPoints,
        totalEarned: newTotalEarned,
        pointHistory: updatedPointHistory
      };

      // Update the main user data with pointsData nested
      const updatedUserData = { 
        ...currentUserData, 
        pointsData: updatedPointsData,
        lastUpdated: new Date().toISOString()
      };

      // Update state first for immediate UI feedback
      setUserData(prev => ({
        ...prev,
        ...updatedPointsData
      }));
      
      // Then update database
      await set(userRef, updatedUserData);

      // Show points earned popup for positive points
      if (pointsToAdd > 0) {
        setPointsPopup({
          show: true,
          points: pointsToAdd,
          message: reason
        });
        
        setTimeout(() => {
          setPointsPopup({ show: false, points: 0, message: "" });
        }, 3000);
      }

      console.log(`Points updated: ${pointsToAdd} for reason: ${reason}`);
      return newCurrentPoints;

    } catch (error) {
      console.error("Failed to update points:", error);
    }
  };

  // Function to check and update daily streak
  const updateDailyStreak = async () => {
    try {
      const today = new Date().toDateString();
      const lastLearningDate = userData.lastLearningDate;
      
      let newStreak = userData.dailyStreak || 0;
      let streakBonus = 0;

      if (lastLearningDate) {
        const lastDate = new Date(lastLearningDate);
        const yesterday = new Date();
        yesterday.setDate(yesterday.getDate() - 1);
        
        if (lastDate.toDateString() === yesterday.toDateString()) {
          // Consecutive day - increment streak
          newStreak += 1;
        } else if (lastDate.toDateString() !== today) {
          // Broken streak - reset to 1
          newStreak = 1;
        }
      } else {
        // First time learning
        newStreak = 1;
      }

      // Award streak bonuses
      if (newStreak >= 7 && (userData.dailyStreak || 0) < 7) {
        streakBonus = 10;
      } else if (newStreak > (userData.dailyStreak || 0)) {
        streakBonus = 2; // Daily bonus
      }

      const updates = {
        dailyStreak: newStreak,
        lastLearningDate: new Date().toISOString()
      };

      await updateUserDataInDatabase(updates);

      if (streakBonus > 0) {
        const bonusReason = newStreak >= 7 ? "7-day streak bonus! 🎉" : "Daily learning bonus!";
        await updatePointsInDatabase(streakBonus, bonusReason);
      }

      return { newStreak, streakBonus };
    } catch (error) {
      console.error("Error updating daily streak:", error);
    }
  };

  // Function to start tracking time for a resource
  const startTimeTracking = async (resourceId) => {
    console.log("startTimeTracking called for resource:", resourceId);
    console.log("Current resourcesClicked:", userData.resourcesClicked);
    
    const startTime = Date.now();
    setActiveSession({ resourceId, startTime });
    
    setTimeTrackers(prev => ({
      ...prev,
      [resourceId]: startTime
    }));

    // Check if this is a new resource click
    const isNewResource = !userData.resourcesClicked?.includes(resourceId);
    console.log("Is new resource?", isNewResource);

    if (isNewResource) {
      console.log("Awarding 1 point for new resource click");
      // Award 1 point for clicking a new resource
      await updatePointsInDatabase(1, "Clicked learning resource");
      
      // Update resources clicked list
      const updatedResourcesClicked = [...(userData.resourcesClicked || []), resourceId];
      await updateUserDataInDatabase({
        resourcesClicked: updatedResourcesClicked
      });
    } else {
      console.log("Resource already clicked, no points awarded");
    }

    // Update daily streak
    await updateDailyStreak();
  };

  // Function to stop tracking time and award points
  const stopTimeTracking = async (resourceId) => {
    if (!timeTrackers[resourceId]) return;

    const endTime = Date.now();
    const startTime = timeTrackers[resourceId];
    const timeSpentSeconds = Math.floor((endTime - startTime) / 1000);
    const timeSpentMinutes = Math.floor(timeSpentSeconds / 60);

    let pointsEarned = 0;

    // Award points based on time spent
    if (timeSpentMinutes >= 10) {
      pointsEarned = 10;
    } else if (timeSpentMinutes >= 5) {
      pointsEarned = 7;
    } else if (timeSpentMinutes >= 2) {
      pointsEarned = 5;
    } else if (timeSpentMinutes >= 1) {
      pointsEarned = 2;
      console.log("Awarding 2 points for at least 1 minute spent");
    }

    if (pointsEarned > 0) {
      await updatePointsInDatabase(pointsEarned, `Learned for ${timeSpentMinutes} minutes`);
      
      // Add learning session
      const newSession = {
        resourceId,
        startTime: new Date(startTime).toISOString(),
        endTime: new Date(endTime).toISOString(),
        duration: timeSpentSeconds,
        pointsEarned: pointsEarned
      };

      const updatedSessions = [...(userData.learningSessions || []), newSession].slice(-100);
      
      // Update learning data
      await updateUserDataInDatabase({
        totalLearningTime: (userData.totalLearningTime || 0) + timeSpentSeconds,
        learningSessions: updatedSessions,
        averageTimePerSession: Math.round(((userData.totalLearningTime || 0) + timeSpentSeconds) / (updatedSessions.length || 1))
      });
    }

    // Clear the tracker
    setTimeTrackers(prev => {
      const newTrackers = { ...prev };
      delete newTrackers[resourceId];
      return newTrackers;
    });

    setActiveSession(null);
  };

  const handleLinkClick = async (e, resource) => {
    e.stopPropagation();
    if (resource.url) {
      await startTimeTracking(resource.id);
      window.open(resource.url, "_blank", "noopener,noreferrer");
    }
  };

  const handleCardClick = async (resource) => {
    if (resource.url) {
      await startTimeTracking(resource.id);
      window.open(resource.url, "_blank", "noopener,noreferrer");
      setSelectedResource(resource);
    }
  };

  // Auto-stop tracking when component unmounts
  useEffect(() => {
    return () => {
      Object.keys(timeTrackers).forEach(resourceId => {
        stopTimeTracking(resourceId);
      });
    };
  }, []);

  const handleCategoryClick = (category) => setSelectedCategory(category);

  // Function to generate voucher code
  const generateVoucherCode = () => {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    let result = '';
    for (let i = 0; i < 8; i++) {
      result += chars.charAt(Math.floor(Math.random() * chars.length));
    }
    return result;
  };

  // Function to handle voucher redemption
  const handleRedeemPoints = async () => {
    const currentPoints = userData.currentPoints || 0;
    const pointsPerVoucher = 50;
    const voucherAmount = 5;
    
    const maxVouchers = Math.floor(currentPoints / pointsPerVoucher);
    
    if (maxVouchers === 0) {
      alert(`You need ${pointsPerVoucher - currentPoints} more points to redeem a voucher!`);
      return;
    }

    const vouchersToRedeem = maxVouchers;
    const totalPointsToRedeem = vouchersToRedeem * pointsPerVoucher;
    const totalVoucherValue = vouchersToRedeem * voucherAmount;
    
    if (window.confirm(`Redeem ${totalPointsToRedeem} points for ${vouchersToRedeem} $${voucherAmount} voucher${vouchersToRedeem > 1 ? 's' : ''} (total value: $${totalVoucherValue})?`)) {
      // Generate vouchers
      const newVouchers = [];
      const redemptionDate = new Date().toISOString();
      
      for (let i = 0; i < vouchersToRedeem; i++) {
        newVouchers.push({
          id: `voucher_${Date.now()}_${i}`,
          amount: voucherAmount,
          code: generateVoucherCode(),
          issueDate: new Date().toLocaleDateString(),
          redeemedAt: redemptionDate,
          pointsRedeemed: pointsPerVoucher
        });
      }

      // Update points
      await updatePointsInDatabase(-totalPointsToRedeem, `Redeemed ${totalPointsToRedeem} points for ${vouchersToRedeem} voucher${vouchersToRedeem > 1 ? 's' : ''}`);
      
      // Add to redemption history
      const updatedRedemptionHistory = [
        ...(userData.redemptionHistory || []),
        ...newVouchers
      ];

      await updateUserDataInDatabase({
        redemptionHistory: updatedRedemptionHistory
      });

      // Show voucher modal
      setVoucherModal({
        show: true,
        vouchers: newVouchers,
        totalPointsRedeemed: totalPointsToRedeem
      });
    }
  };

  // Function to download voucher image
  const downloadVoucher = (voucher) => {
    // Create a temporary link element
    const link = document.createElement('a');
    link.href = voucherImage;
    link.download = `voucher-${voucher.code}.png`;
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
  };

  const handleViewHistory = () => {
    // Toggle showing redemption history
    const historySection = document.getElementById('redemptionHistory');
    if (historySection) {
      historySection.scrollIntoView({ behavior: 'smooth' });
    }
  };

  const closeVoucherModal = () => {
    setVoucherModal({ show: false, vouchers: [], totalPointsRedeemed: 0 });
  };

  const filteredResources = resources.filter((resource) => {
    const matchesSearch =
      resource.title.toLowerCase().includes(searchQuery.toLowerCase()) ||
      resource.description.toLowerCase().includes(searchQuery.toLowerCase());
    const matchesCategory =
      selectedCategory === "All" || resource.category === selectedCategory;
    return matchesSearch && matchesCategory;
  });

  // Build rewards section component
  const buildRewardsSection = () => {
    if (dataLoading) {
      return (
        <div style={{ 
          textAlign: "center", 
          padding: "40px", 
          backgroundColor: "#f8f9fa",
          borderRadius: "15px",
          marginBottom: "30px"
        }}>
          Loading rewards...
        </div>
      );
    }

    const currentPoints = userData.currentPoints || 0;
    const dailyStreak = userData.dailyStreak || 0;
    const resourcesClicked = userData.resourcesClicked || [];
    const learningSessions = userData.learningSessions || [];
    const totalLearningTime = userData.totalLearningTime || 0;
    const averageTimePerSession = userData.averageTimePerSession || 0;

    const isRedeemable = currentPoints >= 50;
    const pointsToNextReward = 50 - (currentPoints % 50);
    const progressPercentage = Math.min((currentPoints % 50) / 50 * 100, 100);
    const voucherValue = Math.floor(currentPoints / 50) * 5;
    const availableVouchers = Math.floor(currentPoints / 50);

    return (
      <div style={styles.rewardsCard}>
        {/* Streak Indicator */}
        {dailyStreak > 0 && (
          <div style={styles.streakIndicator}>
            <Flame size={16} color="#ff6b6b" />
            {dailyStreak}-day learning streak! 
            {dailyStreak >= 7 && (
              <span style={styles.streakBonus}>🔥 7-day streak!</span>
            )}
          </div>
        )}

        {/* Stats Grid */}
        <div style={styles.statsGrid}>
          <div style={styles.statCard}>
            <Clock size={24} color="#667eea" />
            <div style={styles.statValue}>{Math.floor(totalLearningTime / 60)}m</div>
            <div style={styles.statLabel}>Total Learning</div>
          </div>
          <div style={styles.statCard}>
            <BookOpen size={24} color="#667eea" />
            <div style={styles.statValue}>{resourcesClicked.length}</div>
            <div style={styles.statLabel}>Resources Viewed</div>
          </div>
          <div style={styles.statCard}>
            <Target size={24} color="#667eea" />
            <div style={styles.statValue}>{userData.completedResources || 0}</div>
            <div style={styles.statLabel}>Completed</div>
          </div>
          <div style={styles.statCard}>
            <Zap size={24} color="#667eea" />
            <div style={styles.statValue}>{learningSessions.length}</div>
            <div style={styles.statLabel}>Sessions</div>
          </div>
        </div>

        <div style={styles.rewardsHeader}>
          <h3 style={styles.rewardsTitle}>
            <Trophy size={24} />
            My Learning Rewards
          </h3>
          <div style={styles.pointsCircle}>
            <span style={styles.pointsValue}>{currentPoints}</span>
            <span style={styles.pointsLabel}>POINTS</span>
          </div>
        </div>

        <div style={styles.rewardsContent}>
          <div style={styles.progressSection}>
            <div style={styles.progressText}>
              <span>Progress to next reward</span>
              <span>{pointsToNextReward} points needed</span>
            </div>
            <div style={styles.progressBar}>
              <div 
                style={{
                  ...styles.progressFill,
                  width: `${progressPercentage}%`
                }}
              />
            </div>
            <div style={styles.progressText}>
              <span>Session avg: {averageTimePerSession}s</span>
              <span>{currentPoints % 50}/50 points</span>
            </div>
          </div>

          <div style={styles.redeemSection}>
            <div style={styles.voucherBadge}>
              <Gift size={20} style={{ display: "inline", marginRight: "8px" }} />
              {availableVouchers} ${voucherValue > 0 ? voucherValue/availableVouchers : 5} Voucher{availableVouchers !== 1 ? 's' : ''} Available
            </div>
            <button
              style={{
                ...styles.redeemButton,
                ...(!isRedeemable ? styles.redeemButtonDisabled : {})
              }}
              onClick={handleRedeemPoints}
              disabled={!isRedeemable}
            >
              <Gift size={18} />
              {isRedeemable ? `Redeem ${Math.floor(currentPoints / 50) * 50} Points` : "Need 50 Points"}
            </button>
          </div>
        </div>

        <div style={styles.achievementsRow}>
          <div style={{ display: "flex", gap: "8px" }}>
            <span style={styles.achievementBadge}>
              <Star size={14} style={{ display: "inline", marginRight: "4px" }} />
              Total Earned: {userData.totalEarned || 0}
            </span>
            <span style={styles.achievementBadge}>
              Resources: {resourcesClicked.length}/{resources.length}
            </span>
            <span style={styles.achievementBadge}>
              Streak: {dailyStreak}
            </span>
          </div>
          <button 
            style={{
              background: "transparent",
              color: "#667eea",
              border: "1px solid #667eea",
              borderRadius: "20px",
              padding: "8px 16px",
              cursor: "pointer",
              fontSize: "0.9rem",
              fontWeight: "600",
              display: "flex",
              alignItems: "center",
              gap: "6px",
            }}
            onClick={handleViewHistory}
          >
            <History size={16} />
            View History
          </button>
        </div>
      </div>
    );
  };

  if (loading) return <div style={styles.loading}>Loading learning resources...</div>;

  return (
    <div>
      {/* Points Earned Popup */}
      {pointsPopup.show && (
        <div style={styles.pointsEarnedPopup}>
          <Sparkles size={20} />
          +{pointsPopup.points} points! {pointsPopup.message}
        </div>
      )}

      {/* Voucher Redemption Modal */}
      {voucherModal.show && (
        <div style={styles.voucherModal}>
          <div style={styles.voucherContent}>
            <button 
              style={styles.closeButton}
              onClick={closeVoucherModal}
            >
              <X size={20} />
            </button>
            
            <h2>🎉 Voucher Redemption Successful!</h2>
            <p>You redeemed {voucherModal.totalPointsRedeemed} points for {voucherModal.vouchers.length} voucher{voucherModal.vouchers.length > 1 ? 's' : ''}</p>
            
            {voucherModal.vouchers.map((voucher, index) => (
              <div key={voucher.id}>
                <img 
                  src={voucherImage} 
                  alt={`$${voucher.amount} Voucher`}
                  style={styles.voucherImage}
                />
                
                <div style={styles.voucherCodeDisplay}>
                  Voucher Code: {voucher.code}
                </div>
                
                <div style={styles.voucherActions}>
                  <button
                    style={{
                      ...styles.voucherButton,
                      ...styles.downloadButton
                    }}
                    onClick={() => downloadVoucher(voucher)}
                  >
                    <Download size={18} />
                    Download Voucher {voucherModal.vouchers.length > 1 ? index + 1 : ''}
                  </button>
                </div>
                
                {index < voucherModal.vouchers.length - 1 && <hr style={{ margin: '20px 0', border: '1px dashed #e0e0e0' }} />}
              </div>
            ))}
            
            <div style={styles.voucherActions}>
              <button
                style={{
                  ...styles.voucherButton,
                  ...styles.closeVoucherButton
                }}
                onClick={closeVoucherModal}
              >
                Close
              </button>
            </div>
          </div>
        </div>
      )}

      <div style={styles.container}>
        {/* Hero Section */}
        <div style={styles.hero}>
          <h1 style={styles.heroTitle}>Learning Resource Hub</h1>
          <p style={styles.heroSubtitle}>
            Discover curated resources to enhance your knowledge and earn rewards while learning
          </p>
        </div>

        {/* Rewards Section */}
        {buildRewardsSection()}

        {/* Search */}
        <input
          type="text"
          placeholder="Search learning topics..."
          value={searchQuery}
          onChange={(e) => setSearchQuery(e.target.value)}
          style={styles.searchInput}
        />

        {/* Category Filter */}
        <div style={styles.filterSection}>
          <h3 style={styles.filterTitle}>Filter by Category</h3>
          <div style={styles.categoryContainer}>
            {simplifiedCategories.map((category) => {
              const isActive = selectedCategory === category;
              const IconComponent = categoryIcons[category] || categoryIcons.Other;
              return (
                <button
                  key={category}
                  style={{
                    ...styles.categoryButton,
                    ...(isActive ? styles.categoryButtonActive : {}),
                  }}
                  onClick={() => handleCategoryClick(category)}
                >
                  <IconComponent size={16} style={{ display: "inline", marginRight: "8px" }} />
                  {category}
                </button>
              );
            })}
          </div>
        </div>

        {errorMessage && <div style={styles.error}>{errorMessage}</div>}

        <div style={styles.grid}>
          {filteredResources.length > 0 ? (
            filteredResources.map((resource) => {
              const isSelected = selectedResource?.id === resource.id;
              const isHovered = hoveredId === resource.id;
              const isBeingTracked = timeTrackers[resource.id];
              const IconComponent = categoryIcons[resource.category] || categoryIcons.Other;
              const resourcesClicked = userData.resourcesClicked || [];
              
              return (
                <div
                  key={resource.id}
                  style={{
                    ...styles.card,
                    ...(isHovered ? styles.cardHover : {}),
                    ...(isSelected ? { border: "2px solid #4CAF50" } : {}),
                    ...(isBeingTracked ? { 
                      border: "2px solid #ff6b6b",
                      backgroundColor: "#fff5f5" 
                    } : {})
                  }}
                  onClick={() => handleCardClick(resource)}
                  onMouseEnter={() => setHoveredId(resource.id)}
                  onMouseLeave={() => setHoveredId(null)}
                >
                  <div style={{ display: "flex", justifyContent: "space-between", alignItems: "flex-start" }}>
                    <span
                      onClick={(e) => handleLinkClick(e, resource)}
                      style={{
                        ...styles.titleLink,
                        cursor: resource.url ? "pointer" : "default",
                      }}
                      title={resource.url ? "Open in new tab" : "No URL available"}
                    >
                      {resource.title}
                    </span>
                    {isBeingTracked && (
                      <Clock size={16} color="#ff6b6b" title="Time being tracked" />
                    )}
                  </div>
                  <p style={styles.description}>{resource.description}</p>
                  <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
                    <span style={styles.categoryTag}>
                      <IconComponent size={12} style={{ display: "inline", marginRight: "4px" }} />
                      {resource.category}
                    </span>
                    {resourcesClicked.includes(resource.id) && (
                      <span style={{ fontSize: "0.8rem", color: "#4caf50" }}>✓ Viewed</span>
                    )}
                  </div>
                </div>
              );
            })
          ) : (
            <div style={styles.error}>No matching learning topics found.</div>
          )}
        </div>

        {/* Redemption History Section */}
        <div id="redemptionHistory" style={styles.redemptionHistory}>
          <h3 style={styles.historyTitle}>
            <History size={24} />
            Redemption History
          </h3>
          
          {userData.redemptionHistory && userData.redemptionHistory.length > 0 ? (
            <div style={styles.historyGrid}>
              {userData.redemptionHistory.map((voucher) => (
                <div key={voucher.id} style={styles.historyCard}>
                  <img 
                    src={voucherImage} 
                    alt={`$${voucher.amount} Voucher`}
                    style={styles.historyVoucherImage}
                  />
                  <div style={styles.historyDetails}>
                    <div style={styles.voucherCodeDisplay}>
                      Code: {voucher.code}
                    </div>
                    <p><strong>Redeemed:</strong> {new Date(voucher.redeemedAt).toLocaleDateString()}</p>
                    <p><strong>Points Used:</strong> {voucher.pointsRedeemed}</p>
                    <button
                      style={{
                        ...styles.voucherButton,
                        ...styles.downloadButton,
                        padding: "8px 16px",
                        fontSize: "0.9rem"
                      }}
                      onClick={() => downloadVoucher(voucher)}
                    >
                      <Download size={16} />
                      Download
                    </button>
                  </div>
                </div>
              ))}
            </div>
          ) : (
            <div style={styles.noHistory}>
              No redemption history yet. Start learning and redeem your points for vouchers!
            </div>
          )}
        </div>
      </div>

      {/* Floating AI Assistant */}
      {currentUser && <FloatingAssistant userEmail={currentUser} />}
          
      <div style={{ marginTop: "100px" }}>
        <Footer />
      </div>
    </div>
  );
}