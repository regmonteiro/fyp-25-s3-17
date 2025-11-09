import React, { useState, useEffect } from 'react';
import { Line, Bar, Doughnut } from 'react-chartjs-2';
import {
  Chart as ChartJS,
  CategoryScale,
  LinearScale,
  PointElement,
  LineElement,
  BarElement,
  Title,
  Tooltip,
  Legend,
  ArcElement,
} from 'chart.js';
import ViewReportsCaregiverController from '../controller/viewReportsCaregiverController';
import './viewReportsCaregiver.css';
import { useNavigate } from 'react-router-dom';
import Footer from '../footer';

ChartJS.register(
  CategoryScale,
  LinearScale,
  PointElement,
  LineElement,
  BarElement,
  ArcElement,
  Title,
  Tooltip,
  Legend
);

// --- DAILY RANDOM DATA HELPERS ---
function getDailySeed() {
  const today = new Date();
  return parseInt(`${today.getFullYear()}${today.getMonth() + 1}${today.getDate()}`);
}

function seededRandom(seed) {
  let x = Math.sin(seed) * 10000;
  return x - Math.floor(x);
}

function seededRandomInt(seed, min, max) {
  return Math.floor(seededRandom(seed) * (max - min + 1)) + min;
}

function generateDailyRandomReports(elderly) {
  const seed = getDailySeed() + (elderly.identifier ? elderly.identifier.charCodeAt(0) : 0);

  const bloodPressureSystolic = seededRandomInt(seed + 1, 110, 130);
  const bloodPressureDiastolic = seededRandomInt(seed + 2, 70, 85);
  const heartRate = seededRandomInt(seed + 3, 60, 80);
  const medicationAdherence = seededRandomInt(seed + 4, 80, 100);
  const missedDoses = seededRandomInt(seed + 5, 0, 3);
  const stepsToday = seededRandomInt(seed + 6, 2000, 5000);
  const sleepHours = (seededRandomInt(seed + 7, 6, 9) + seededRandom(seed + 8)).toFixed(1);
  const emergencyAlertsWeek = seededRandomInt(seed + 9, 0, 2);
  const emergencyAlertsMonth = seededRandomInt(seed + 10, 0, 3);

  const reports = [
    {
      id: 'health-vitals',
      category: 'health',
      title: 'Health Vitals',
      chartData: {
        labels: ['Blood Pressure', 'Heart Rate'],
        datasets: [
          {
            label: 'Vitals',
            data: [bloodPressureSystolic, heartRate],
            borderColor: ['#ff6384', '#36a2eb'],
            backgroundColor: ['#ff6384', '#36a2eb'],
          }
        ]
      },
      stats: [
        { number: `${bloodPressureSystolic}/${bloodPressureDiastolic}`, label: 'Blood Pressure' },
        { number: heartRate, label: 'Heart Rate' }
      ]
    },
    {
      id: 'medication-adherence',
      category: 'medication',
      title: 'Medication Adherence',
      chartData: {
        labels: ['Adherence', 'Missed Doses'],
        datasets: [
          { 
            data: [medicationAdherence, missedDoses], 
            backgroundColor: ['#36a2eb', '#ffcd56'],
            borderColor: ['#36a2eb', '#ffcd56'],
            borderWidth: 1
          }
        ]
      },
      stats: [
        { number: `${medicationAdherence}%`, label: 'Adherence' },
        { number: missedDoses, label: 'Missed Doses' }
      ]
    },
    {
      id: 'daily-activities',
      category: 'activity',
      title: 'Daily Activities',
      chartData: {
        labels: ['Steps', 'Sleep Hours'],
        datasets: [
          {
            label: 'Activity',
            data: [stepsToday, sleepHours],
            borderColor: ['#4bc0c0', '#ff9f40'],
            backgroundColor: ['#4bc0c0', '#ff9f40'],
          }
        ]
      },
      stats: [
        { number: stepsToday.toLocaleString(), label: 'Steps Today' },
        { number: sleepHours, label: 'Sleep Hours' }
      ]
    },
    {
      id: 'emergency-alerts',
      category: 'emergency',
      title: 'Emergency Alerts',
      chartData: {
        labels: ['This Week', 'This Month'],
        datasets: [
          { 
            label: 'Alerts', 
            data: [emergencyAlertsWeek, emergencyAlertsMonth], 
            borderColor: '#ff6384', 
            backgroundColor: '#ff6384' 
          }
        ]
      },
      stats: [
        { number: emergencyAlertsWeek, label: 'This Week' },
        { number: emergencyAlertsMonth, label: 'This Month' }
      ]
    }
  ];

  const alerts = [
    { 
      id: 'med-reminder',
      title: 'Medication Reminder', 
      time: '2 hours ago', 
      message: `${elderly.name} missed afternoon medication.`, 
      type: 'medication' 
    },
    { 
      id: 'activity-update',
      title: 'Activity Update', 
      time: '5 hours ago', 
      message: `${elderly.name} walked ${stepsToday.toLocaleString()} steps today.`, 
      type: 'activity' 
    },
    { 
      id: 'health-check',
      title: 'Health Check', 
      time: '1 day ago', 
      message: `Blood pressure reading recorded for ${elderly.name}: ${bloodPressureSystolic}/${bloodPressureDiastolic} mmHg.`, 
      type: 'health' 
    }
  ];

  return { reports, alerts };
}

// --- MAIN COMPONENT ---
function ViewReportsCaregiver() {
  const [filter, setFilter] = useState('all');
  const [elderlyData, setElderlyData] = useState([]);
  const [selectedElderly, setSelectedElderly] = useState(null);
  const [reports, setReports] = useState([]);
  const [alerts, setAlerts] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  const controller = new ViewReportsCaregiverController();
  const navigate = useNavigate();
  
  useEffect(() => {
    const fetchData = async () => {
      try {
        setLoading(true);
        setError(null);
        
        const currentUserStr = localStorage.getItem('currentUser');
        const currentUser = currentUserStr ? JSON.parse(currentUserStr) : null;
        const loggedInEmail = localStorage.getItem('loggedInEmail');
        const email = (loggedInEmail || currentUser?.email || "").toLowerCase();
        
        if (!email) {
          throw new Error("No logged-in user found. Please log in again.");
        }
        
        const userType = currentUser?.userType || localStorage.getItem('userType');
        if (userType !== 'caregiver') {
          throw new Error('Only caregivers can view reports');
        }
        
        const userForController = {
          email,
          userType,
          ...currentUser
        };
        
        const reportData = await controller.getElderlyReportData(userForController);
        
        console.log('Fetched report data:', reportData);
        
        // Handle both array and single object responses
        let elderlyList = [];
        if (Array.isArray(reportData)) {
          elderlyList = reportData;
        } else if (reportData && typeof reportData === 'object') {
          elderlyList = [reportData];
        }
        
        // --- Inject daily random reports & alerts ---
        elderlyList = elderlyList.map(elderly => {
          const { reports, alerts } = generateDailyRandomReports(elderly);
          return { ...elderly, reports, alerts };
        });
        
        setElderlyData(elderlyList);
        
        if (elderlyList.length > 0) {
          const firstElderly = elderlyList[0];
          setSelectedElderly(firstElderly);
          setReports(firstElderly.reports || []);
          setAlerts(firstElderly.alerts || []);
        } else {
          setError('No elderly assigned to your account.');
        }
      } catch (err) {
        setError(err.message);
        console.error('Error fetching report data:', err);
      } finally {
        setLoading(false);
      }
    };

    fetchData();
  }, []);

  const handleElderlyChange = (elderly) => {
    console.log('Changing to elderly:', elderly);
    setSelectedElderly(elderly);
    setReports(elderly.reports || []);
    setAlerts(elderly.alerts || []);
  };

  const handleSelectChange = (e) => {
    const selectedIdentifier = e.target.value;
    const selected = elderlyData.find(elderly => 
      elderly.identifier === selectedIdentifier || 
      elderly.email === selectedIdentifier
    );
    if (selected) {
      handleElderlyChange(selected);
    }
  };

  // Get display identifier (email or shortened UID)
  const getDisplayIdentifier = (elderly) => {
    if (elderly.identifier && elderly.identifier.includes('@')) {
      return elderly.identifier; // Show full email
    } else if (elderly.email && elderly.email.includes('@')) {
      return elderly.email; // Show full email
    } else if (elderly.identifier) {
      return `${elderly.identifier.substring(0, 8)}...`; // Shorten UID
    } else if (elderly.uid) {
      return `${elderly.uid.substring(0, 8)}...`; // Shorten UID
    }
    return 'Unknown';
  };

  const chartOptions = {
    responsive: true,
    maintainAspectRatio: false,
    plugins: { 
      legend: { 
        position: 'bottom', 
        labels: { 
          padding: 20, 
          usePointStyle: true,
          font: {
            size: 12
          }
        } 
      } 
    },
    scales: {
      y: { 
        beginAtZero: true, 
        grid: { 
          color: 'rgba(0,0,0,0.05)' 
        },
        ticks: {
          font: {
            size: 11
          }
        }
      },
      x: { 
        grid: { 
          color: 'rgba(0,0,0,0.05)' 
        },
        ticks: {
          font: {
            size: 11
          }
        }
      },
    },
  };

  const handleRetry = () => {
    window.location.reload();
  };

  const handleLoginRedirect = () => {
    window.location.href = '/login';
  };

  if (loading) {
    return (
      <div className="container">
        <div className="loading">
          <div style={{ textAlign: 'center' }}>
            <div style={{ fontSize: '3rem', marginBottom: '20px' }}>📊</div>
            <div>Loading reports...</div>
          </div>
        </div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="container">
        <div className="error-container">
          <div style={{ fontSize: '4rem', marginBottom: '20px' }}>⚠️</div>
          <h2>Error Loading Reports</h2>
          <p className="error-message">{error}</p>
          <div className="error-actions">
            <button className="retry-btn" onClick={handleRetry}>
              Try Again
            </button>
            <button className="login-btn" onClick={handleLoginRedirect}>
              Go to Login
            </button>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div>
      <div className="container">
        {/* Header Section */}
        <div className="header">
          <div className="header-content">
            <h1>Reports</h1>
            
            {/* Elderly Selection Section */}
            {elderlyData.length > 0 && (
              <div className="elderly-selection-section">
                <h2>Select Elderly to View Reports</h2>
                
                <div className="selection-container">
                  {/* Dropdown for mobile or when many elderly */}
                  {elderlyData.length > 5 && (
                    <select 
                      className="elderly-dropdown"
                      value={selectedElderly?.identifier || selectedElderly?.email || ''}
                      onChange={handleSelectChange}
                    >
                      {elderlyData.map((elderly) => (
                        <option 
                          key={elderly.identifier || elderly.email} 
                          value={elderly.identifier || elderly.email}
                        >
                          {elderly.name} ({getDisplayIdentifier(elderly)})
                        </option>
                      ))}
                    </select>
                  )}

                  {/* Compact cards for quick selection */}
                  {elderlyData.length <= 5 && (
                    <div className="compact-elderly-cards">
                      {elderlyData.map((elderly, index) => (
                        <div 
                          key={elderly.identifier || elderly.email || index}
                          className={`compact-elderly-card ${
                            (selectedElderly?.identifier === elderly.identifier || 
                             selectedElderly?.email === elderly.email) ? 'active' : ''
                          }`}
                          onClick={() => handleElderlyChange(elderly)}
                        >
                          
                          <div className="compact-elderly-info">
                            <strong>{elderly.name || 'Unknown Elderly'}</strong>
                            <span>Age: {elderly.age || 'N/A'}</span>
                            
                          </div>
                        </div>
                      ))}
                    </div>
                  )}
                </div>
              </div>
            )}

            {/* Current Elderly Display */}
            {selectedElderly && (
              <div className="current-elderly-display">
                
                <div className="current-elderly-details">
                  <h3>{selectedElderly.name || 'Unknown Elderly'}</h3>
                  <p>Age: {selectedElderly.age || 'N/A'} </p>
                  
                  <div className="status-indicator">
                    <div className="status-dot"></div>
                    Active & Monitored
                  </div>
                </div>
              </div>
            )}
          </div>
        </div>

        {/* Main Content */}
        <div className="main-content" style={{maxWidth: "100%"}}>
          {/* Report Filters */}
          <div className="report-filters">
            {['all', 'health', 'medication', 'activity', 'emergency'].map((cat) => (
              <button
                key={cat}
                className={`filter-btn ${filter === cat ? 'active' : ''}`}
                onClick={() => setFilter(cat)}
              >
                {cat === 'all' ? 'All Reports' : `${cat.charAt(0).toUpperCase() + cat.slice(1)} Reports`}
              </button>
            ))}
          </div>

          {/* Reports Grid */}
          <div className="reports-grid">
            {reports.length > 0 ? (
              reports
                .filter((r) => filter === 'all' || r.category === filter)
                .map((report, index) => (
                  <div className="report-card" key={report.id || index}>
                    <div className="report-header">
                      <h3 className="report-title">{report.title}</h3>
                      <div className={`report-icon ${report.iconClass}`}>
                        {report.icon}
                      </div>
                    </div>
                    <div className="chart-container">
                      {report.category === 'health' || report.category === 'emergency' ? (
                        <Line data={report.chartData} options={chartOptions} />
                      ) : report.category === 'medication' ? (
                        <Doughnut
                          data={report.chartData}
                          options={{
                            responsive: true,
                            maintainAspectRatio: false,
                            plugins: { 
                              legend: { 
                                position: 'bottom', 
                                labels: { 
                                  padding: 20,
                                  font: {
                                    size: 11
                                  }
                                } 
                              } 
                            },
                          }}
                        />
                      ) : (
                        <Bar data={report.chartData} options={chartOptions} />
                      )}
                    </div>
                    <div className="stats-row">
                      {report.stats && report.stats.map((stat, idx) => (
                        <div className="stat-item" key={idx}>
                          <div className="stat-number">{stat.number}</div>
                          <div className="stat-label">{stat.label}</div>
                        </div>
                      ))}
                    </div>
                  </div>
                ))
            ) : (
              <div className="no-reports">
                <div style={{ fontSize: '4rem', marginBottom: '20px' }}>📋</div>
                <h3>No Reports Available</h3>
                <p>There are no reports generated for {selectedElderly?.name} yet.</p>
              </div>
            )}
          </div>

          {/* Alerts Section */}
          {alerts.length > 0 && (
            <div className="alert-section">
              <h3>Recent Alerts & Notifications</h3>
              {alerts.map((alert, index) => (
                <div className={`alert-card ${alert.type}`} key={alert.id || index}>
                  <div className="alert-header">
                    <strong>{alert.title}</strong>
                    <span className="alert-time">{alert.time}</span>
                  </div>
                  <p>{alert.message}</p>
                </div>
              ))}
            </div>
          )}
        </div>

        {/* Action Buttons */}
        {selectedElderly && (
          <>
            <button 
              className="export-btn" 
              onClick={() => controller.exportReportsAsPDF(selectedElderly)}
              title="Export PDF Report"
            >
              📄
            </button>

            <button 
              className="generate-report-btn"
              onClick={() => navigate('/caregiver/generatecustomreport')}
              title="Generate Custom Report"
            >
              ✨ Generate Custom Report
            </button>
          </>
        )}
      </div>
      <Footer />
    </div>
  );
}

export default ViewReportsCaregiver;