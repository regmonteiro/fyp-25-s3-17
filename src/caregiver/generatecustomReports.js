import React, { useState, useEffect } from 'react';
import { Calendar, Filter, Download, Eye, FileText, TrendingUp, Activity, Heart, Thermometer, Pill, Clock, Users, BarChart3, LineChart, PieChart } from 'lucide-react';
import { 
  getLinkedElderlyId,
  getElderlyInfo,
  emailToKey 
} from "../controller/appointmentController";
import { LineChart as RechartsLineChart, BarChart, PieChart as RechartsPieChart, Line, Bar, Pie, XAxis, YAxis, CartesianGrid, Tooltip, Legend, ResponsiveContainer, Cell } from 'recharts';
import jsPDF from 'jspdf';
import html2canvas from 'html2canvas';

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

function generateDailyRandomData(patientId, metrics, dateRange) {
  const seed = getDailySeed() + (patientId ? patientId.charCodeAt(0) : 0);
  const data = {};

  // Generate random data based on selected metrics
  metrics.forEach((metric, index) => {
    const metricSeed = seed + index * 100;
    
    switch (metric) {
      case 'blood-pressure':
        data.bloodPressure = {
          systolic: seededRandomInt(metricSeed + 1, 110, 140),
          diastolic: seededRandomInt(metricSeed + 2, 70, 90)
        };
        break;
      case 'heart-rate':
        data.heartRate = seededRandomInt(metricSeed + 3, 60, 85);
        break;
      case 'temperature':
        data.temperature = (seededRandomInt(metricSeed + 4, 97, 99) + seededRandom(metricSeed + 5)).toFixed(1);
        break;
      case 'blood-sugar':
        data.bloodSugar = seededRandomInt(metricSeed + 6, 80, 160);
        break;
      case 'weight':
        data.weight = (seededRandomInt(metricSeed + 7, 120, 180) + seededRandom(metricSeed + 8)).toFixed(1);
        break;
      case 'sleep-quality':
        data.sleepQuality = seededRandomInt(metricSeed + 9, 4, 9);
        break;
      case 'mood':
        const moods = ['Excellent', 'Good', 'Fair', 'Poor'];
        data.mood = moods[seededRandomInt(metricSeed + 10, 0, 3)];
        break;
      case 'pain-level':
        data.painLevel = seededRandomInt(metricSeed + 11, 0, 10);
        break;
      case 'medication-adherence':
        data.medicationAdherence = seededRandomInt(metricSeed + 12, 75, 98);
        break;
      case 'exercise':
        data.exercise = seededRandomInt(metricSeed + 13, 15, 60);
        break;
    }
  });

  return data;
}

function generateChartData(patientId, metrics, chartType, dateRange) {
  const seed = getDailySeed() + (patientId ? patientId.charCodeAt(0) : 0);
  const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  
  if (chartType === 'line' || chartType === 'bar') {
    return days.map((day, index) => {
      const daySeed = seed + index * 10;
      const dataPoint = { name: day };
      
      if (metrics.includes('heart-rate')) {
        dataPoint.heartRate = seededRandomInt(daySeed + 1, 60, 85);
      }
      if (metrics.includes('blood-pressure')) {
        dataPoint.systolic = seededRandomInt(daySeed + 2, 110, 140);
        dataPoint.diastolic = seededRandomInt(daySeed + 3, 70, 90);
      }
      if (metrics.includes('blood-sugar')) {
        dataPoint.bloodSugar = seededRandomInt(daySeed + 4, 80, 160);
      }
      
      return dataPoint;
    });
  }
  
  if (chartType === 'pie') {
    return [
      { name: 'Normal', value: seededRandomInt(seed + 1, 60, 80) },
      { name: 'Elevated', value: seededRandomInt(seed + 2, 10, 25) },
      { name: 'High', value: seededRandomInt(seed + 3, 5, 15) },
    ];
  }
  
  return [];
}

const CustomReportsGenerator = () => {
  const [selectedReportType, setSelectedReportType] = useState('');
  const [dateRange, setDateRange] = useState({ start: '', end: '' });
  const [selectedMetrics, setSelectedMetrics] = useState([]);
  const [selectedPatients, setSelectedPatients] = useState([]);
  const [showPreview, setShowPreview] = useState(false);
  const [isGenerating, setIsGenerating] = useState(false);
  const [generatedReport, setGeneratedReport] = useState(null);
  const [patients, setPatients] = useState([]);
  const [isLoadingPatients, setIsLoadingPatients] = useState(true);
  const [currentUser, setCurrentUser] = useState(null);
  const [previewData, setPreviewData] = useState(null);
  const [selectedChartType, setSelectedChartType] = useState('line');

  const downloadReport = async () => {
    if (!generatedReport) return;

    try {
      const reportElement = document.createElement('div');
      reportElement.style.padding = '20px';
      reportElement.style.backgroundColor = 'white';

      // Get patient details
      const selectedPatientDetails = patients.filter(p =>
        selectedPatients.includes(p.id)
      );

      // Build previewData (with fallback values)
      const preview = generatedReport.previewData || {};

      const previewHtml = `
        <div style="margin-top: 20px; padding: 15px; border: 1px solid #e5e7eb; border-radius: 10px; background-color: #f9fafb;">
          <h4 style="font-size: 16px; font-weight: 600; margin-bottom: 10px; color: #374151;">Data Preview</h4>
          <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 12px;">
            <div style="display: flex; justify-content: space-between;">
              <span style="font-weight: 500; color: #374151;">Blood Pressure Avg:</span>
              <span style="color: #111827;">${preview.bloodPressure || "128/82 mmHg"}</span>
            </div>
            <div style="display: flex; justify-content: space-between;">
              <span style="font-weight: 500; color: #374151;">Heart Rate Avg:</span>
              <span style="color: #111827;">${preview.heartRate || "74 BPM"}</span>
            </div>
            <div style="display: flex; justify-content: space-between;">
              <span style="font-weight: 500; color: #374151;">Med Adherence:</span>
              <span style="color: #16a34a; font-weight: 600;">${preview.medAdherence || "87%"}</span>
            </div>
            <div style="display: flex; justify-content: space-between;">
              <span style="font-weight: 500; color: #374151;">Data Points:</span>
              <span style="color: #111827;">${preview.dataPoints || "245"}</span>
            </div>
          </div>
        </div>
      `;

      reportElement.innerHTML = `
        <h1 style="text-align: center; color: #2563eb;">Health Monitoring Report</h1>
        
        <div style="margin: 20px 0; border-bottom: 1px solid #e5e7eb; padding-bottom: 20px;">
          <p><strong>Report ID:</strong> ${generatedReport.reportId}</p>
          <p><strong>Generated At:</strong> ${new Date(generatedReport.generatedAt).toLocaleString()}</p>
          <p><strong>Date Range:</strong> ${generatedReport.dateRange.start} to ${generatedReport.dateRange.end}</p>
          <p><strong>Report Type:</strong> ${reportTypes.find(r => r.id === generatedReport.reportType)?.name}</p>
        </div>

        <h2 style="color: #374151;">Elderly Details</h2>
        <ul style="margin-bottom: 20px;">
          ${selectedPatientDetails.map(p => `
            <li><strong>Name:</strong> ${p.name || "N/A"} | <strong>Age:</strong> ${p.age || "N/A"}</li>
          `).join('')}
        </ul>

        <h2 style="color: #374151;">Summary</h2>
        <div style="display: grid; grid-template-columns: repeat(2, 1fr); gap: 10px; margin-bottom: 20px;">
          <div style="padding: 10px; background-color: #f9fafb; border-radius: 8px;">
            <p style="margin: 0; font-size: 14px;">Average Compliance</p>
            <p style="margin: 0; font-size: 18px; color: #16a34a; font-weight: bold;">${generatedReport.summary.avgCompliance}%</p>
          </div>
          <div style="padding: 10px; background-color: #f9fafb; border-radius: 8px;">
            <p style="margin: 0; font-size: 14px;">Alerts Generated</p>
            <p style="margin: 0; font-size: 18px; color: #ea580c; font-weight: bold;">${generatedReport.summary.alertsGenerated}</p>
          </div>
          <div style="padding: 10px; background-color: #f9fafb; border-radius: 8px;">
            <p style="margin: 0; font-size: 14px;">Trends Identified</p>
            <p style="margin: 0; font-size: 18px; color: #2563eb; font-weight: bold;">${generatedReport.summary.trendsIdentified}</p>
          </div>
          <div style="padding: 10px; background-color: #f9fafb; border-radius: 8px;">
            <p style="margin: 0; font-size: 14px;">Recommendations</p>
            <p style="margin: 0; font-size: 18px; color: #9333ea; font-weight: bold;">${generatedReport.summary.recommendations}</p>
          </div>
        </div>

        <h2 style="color: #374151;">Selected Metrics</h2>
        <ul>
          ${generatedReport.metrics.map(metricId => {
            const metric = healthMetrics.find(m => m.id === metricId);
            return metric ? `<li>${metric.name}</li>` : '';
          }).join('')}
        </ul>

        ${previewHtml}

        <h2 style="color: #374151; margin-top: 20px;">Data Visualization</h2>
        <div id="chart-container" style="height: 300px; width: 100%;"></div>
      `;

      document.body.appendChild(reportElement);

      // Embed chart if available
      if (selectedChartType) {
        const chartContainer = reportElement.querySelector('#chart-container');
        const chartPreview = document.querySelector('.recharts-wrapper');
        if (chartPreview) {
          chartContainer.innerHTML = chartPreview.outerHTML;
        }
      }

      // Convert to PDF
      const canvas = await html2canvas(reportElement);
      const imgData = canvas.toDataURL('image/png');
      const pdf = new jsPDF('p', 'mm', 'a4');
      const imgProps = pdf.getImageProperties(imgData);
      const pdfWidth = pdf.internal.pageSize.getWidth();
      const pdfHeight = (imgProps.height * pdfWidth) / imgProps.width;

      pdf.addImage(imgData, 'PNG', 0, 0, pdfWidth, pdfHeight);
      pdf.save(`health-report-${generatedReport.reportId}.pdf`);

      document.body.removeChild(reportElement);
    } catch (error) {
      console.error('Error generating PDF:', error);
      alert('Failed to download report. Please try again.');
    }
  };

  // Calculate age from date of birth
  const calculateAge = (dob) => {
    if (!dob) return 'Unknown';
    
    const birthDate = new Date(dob);
    const today = new Date();
    let age = today.getFullYear() - birthDate.getFullYear();
    const monthDiff = today.getMonth() - birthDate.getMonth();
    
    if (monthDiff < 0 || (monthDiff === 0 && today.getDate() < birthDate.getDate())) {
      age--;
    }
    
    return age;
  };

  // Get current user from localStorage
  useEffect(() => {
    const loggedInEmail = localStorage.getItem("loggedInEmail");
    const userType = localStorage.getItem("userType");
    
    if (loggedInEmail && userType) {
      setCurrentUser({
        email: loggedInEmail,
        userType: userType
      });
    } else {
      setIsLoadingPatients(false);
    }
  }, []);

  // Get all elderly users from Firebase
  const getAllElderlyUsers = async () => {
    try {
      const mockElderlyData = [
        {
          id: "VuCi0D8TEUh7slr4DGxQg3eVnB02",
          name: "Elderly One",
          age: calculateAge("1950-10-10"),
          condition: "General wellness monitoring",
          email: "elderlyone@gmail.com"
        },
        {
          id: "yx1fAQSPQIgn9Cvnb7t6hXePVa02",
          name: "Elderly Two",
          age: calculateAge("1955-10-01"),
          condition: "Routine health check",
          email: "elderlytwo@gmail.com"
        },
        {
          id: "OVExOULS9jfhDhzAZ6oBcGqR2Bz1",
          name: "elderly four",
          age: calculateAge("1956-08-01"),
          condition: "Health monitoring",
          email: "elderly4@gmail.com"
        },
        {
          id: "MES0FsBUYMb7BuDyc6QLY5XemEB3",
          name: "Elderly Five",
          age: calculateAge("1960-10-01"),
          condition: "General care",
          email: "elderlyfive@gmail.com"
        }
      ];
      
      return mockElderlyData;
    } catch (error) {
      console.error("Error fetching elderly users:", error);
      return [];
    }
  };

  // Get linked elderly for caregiver
  const getLinkedElderlyForCaregiver = async (caregiverEmail) => {
    try {
      const caregiverElderlyMap = {
        "caregiver1@gmail.com": ["MES0FsBUYMb7BuDyc6QLY5XemEB3", "VuCi0D8TEUh7slr4DGxQg3eVnB02"],
        "caregiver2@gmail.com": ["yx1fAQSPQIgn9Cvnb7t6hXePVa02"],
        "caregiver3@gmail.com": ["Ck75GhY7hoUdeJJgtwpADcQyHmB3"],
        "bobmarley1@gmail.com": ["2bixGIJ3EaddvjtpaFd4oz4NFjA3"],
        "brocklee@hotmail.com": ["oxIcrL7U5zcCPCS0sSZc5SdIPrl1"]
      };
      
      return caregiverElderlyMap[caregiverEmail] || [];
    } catch (error) {
      console.error("Error getting linked elderly:", error);
      return [];
    }
  };

  // Fetch elderly data based on user type
  useEffect(() => {
    const fetchElderlyData = async () => {
      if (!currentUser) {
        setIsLoadingPatients(false);
        return;
      }

      try {
        setIsLoadingPatients(true);
        let elderlyData = [];

        if (currentUser.userType === "caregiver") {
          const linkedElderlyIds = await getLinkedElderlyForCaregiver(currentUser.email);
          const allElderly = await getAllElderlyUsers();
          
          elderlyData = allElderly.filter(elderly => 
            linkedElderlyIds.includes(elderly.id)
          );
          
          if (elderlyData.length === 0) {
            elderlyData = allElderly;
          }
        } else if (currentUser.userType === "elderly") {
          const allElderly = await getAllElderlyUsers();
          elderlyData = allElderly.filter(elderly => 
            elderly.email === currentUser.email
          );
        } else if (currentUser.userType === "admin") {
          elderlyData = await getAllElderlyUsers();
        }

        setPatients(elderlyData);
      } catch (error) {
        console.error('Error fetching elderly data:', error);
        setPatients([
          { id: 1, name: 'Eleanor Smith', age: 78, condition: 'Diabetes, Hypertension' },
          { id: 2, name: 'Robert Johnson', age: 82, condition: 'Arthritis, Heart Disease' },
          { id: 3, name: 'Margaret Brown', age: 75, condition: 'Alzheimer\'s, Osteoporosis' },
          { id: 4, name: 'William Davis', age: 80, condition: 'COPD, Depression' }
        ]);
      } finally {
        setIsLoadingPatients(false);
      }
    };

    if (currentUser) {
      fetchElderlyData();
    }
  }, [currentUser]);

  // Mock data
  const reportTypes = [
    { id: 'health-logs', name: 'Health Logs Report', icon: Heart, description: 'Vital signs, symptoms and health indicators' },
    { id: 'medication', name: 'Medication Adherence', icon: Pill, description: 'Medication schedules and compliance tracking' },
    { id: 'activity', name: 'Daily Activities', icon: Activity, description: 'Daily living activities and mobility patterns' },
    { id: 'appointments', name: 'Appointments & Care', icon: Clock, description: 'Medical appointments and care sessions' },
    { id: 'comprehensive', name: 'Comprehensive Report', icon: FileText, description: 'All available data combined' }
  ];

  const healthMetrics = [
    { id: 'blood-pressure', name: 'Blood Pressure', category: 'Vitals' },
    { id: 'heart-rate', name: 'Heart Rate', category: 'Vitals' },
    { id: 'temperature', name: 'Temperature', category: 'Vitals' },
    { id: 'blood-sugar', name: 'Blood Sugar', category: 'Vitals' },
    { id: 'weight', name: 'Weight', category: 'Physical' },
    { id: 'sleep-quality', name: 'Sleep Quality', category: 'Wellness' },
    { id: 'mood', name: 'Mood Assessment', category: 'Mental Health' },
    { id: 'pain-level', name: 'Pain Level', category: 'Symptoms' },
    { id: 'medication-adherence', name: 'Medication Adherence', category: 'Treatment' },
    { id: 'exercise', name: 'Physical Activity', category: 'Lifestyle' }
  ];

  const chartTypes = [
    { id: 'line', name: 'Line Chart', icon: LineChart },
    { id: 'bar', name: 'Bar Chart', icon: BarChart3 },
    { id: 'pie', name: 'Pie Chart', icon: PieChart }
  ];

  const COLORS = ['#0088FE', '#00C49F', '#FFBB28', '#FF8042'];

  const handleMetricToggle = (metricId) => {
    setSelectedMetrics(prev => 
      prev.includes(metricId) 
        ? prev.filter(id => id !== metricId)
        : [...prev, metricId]
    );
  };

  const handlePatientToggle = (patientId) => {
    setSelectedPatients(prev => 
      prev.includes(patientId) 
        ? prev.filter(id => id !== patientId)
        : [...prev, patientId]
    );
  };

  const generatePreview = () => {
    if (!selectedReportType || !dateRange.start || !dateRange.end) {
      alert('Please select report type and date range to generate preview');
      return;
    }

    // Generate daily random data for preview
    const previewData = {};
    if (selectedPatients.length > 0) {
      const patientId = selectedPatients[0]; // Use first selected patient for preview
      const dailyData = generateDailyRandomData(patientId, selectedMetrics, dateRange);
      
      // Update preview data based on selected metrics
      if (dailyData.bloodPressure) {
        previewData.bloodPressure = `${dailyData.bloodPressure.systolic}/${dailyData.bloodPressure.diastolic} mmHg`;
      }
      if (dailyData.heartRate) {
        previewData.heartRate = `${dailyData.heartRate} BPM`;
      }
      if (dailyData.medicationAdherence) {
        previewData.medAdherence = `${dailyData.medicationAdherence}%`;
      }
      
      previewData.dataPoints = Math.floor(Math.random() * 500) + 100;
    }

    setPreviewData(previewData);
    setShowPreview(true);
  };

  const generateReport = () => {
    setIsGenerating(true);
    
    // Generate daily random data for the final report
    const reportData = {};
    selectedPatients.forEach(patientId => {
      reportData[patientId] = generateDailyRandomData(patientId, selectedMetrics, dateRange);
    });

    // Simulate API call
    setTimeout(() => {
      const mockData = {
        reportId: `RPT-${Date.now()}`,
        generatedAt: new Date().toISOString(),
        dateRange,
        reportType: selectedReportType,
        metrics: selectedMetrics,
        patients: selectedPatients,
        previewData: previewData,
        dailyData: reportData,
        totalDataPoints: Math.floor(Math.random() * 500) + 100,
        summary: {
          avgCompliance: seededRandomInt(getDailySeed() + 100, 80, 95),
          alertsGenerated: seededRandomInt(getDailySeed() + 101, 0, 15),
          trendsIdentified: seededRandomInt(getDailySeed() + 102, 3, 8),
          recommendations: seededRandomInt(getDailySeed() + 103, 5, 12)
        }
      };
      setGeneratedReport(mockData);
      setIsGenerating(false);
    }, 3000);
  };

  const renderChart = () => {
    if (!selectedChartType || selectedPatients.length === 0) return null;

    const patientId = selectedPatients[0]; // Use first patient for chart
    const chartData = generateChartData(patientId, selectedMetrics, selectedChartType, dateRange);

    switch (selectedChartType) {
      case 'line':
        return (
          <ResponsiveContainer width="100%" height={300}>
            <RechartsLineChart data={chartData}>
              <CartesianGrid strokeDasharray="3 3" />
              <XAxis dataKey="name" />
              <YAxis />
              <Tooltip />
              <Legend />
              {selectedMetrics.includes('heart-rate') && (
                <Line type="monotone" dataKey="heartRate" stroke="#8884d8" name="Heart Rate" />
              )}
              {selectedMetrics.includes('blood-pressure') && (
                <Line type="monotone" dataKey="systolic" stroke="#82ca9d" name="Systolic" />
              )}
            </RechartsLineChart>
          </ResponsiveContainer>
        );
      case 'bar':
        return (
          <ResponsiveContainer width="100%" height={300}>
            <BarChart data={chartData}>
              <CartesianGrid strokeDasharray="3 3" />
              <XAxis dataKey="name" />
              <YAxis />
              <Tooltip />
              <Legend />
              {selectedMetrics.includes('heart-rate') && (
                <Bar dataKey="heartRate" fill="#8884d8" name="Heart Rate" />
              )}
              {selectedMetrics.includes('blood-pressure') && (
                <Bar dataKey="systolic" fill="#82ca9d" name="Systolic" />
              )}
            </BarChart>
          </ResponsiveContainer>
        );
      case 'pie':
        return (
          <ResponsiveContainer width="100%" height={300}>
            <RechartsPieChart>
              <Pie
                data={chartData}
                cx="50%"
                cy="50%"
                labelLine={false}
                label={({ name, percent }) => `${name}: ${(percent * 100).toFixed(0)}%`}
                outerRadius={80}
                fill="#8884d8"
                dataKey="value"
              >
                {chartData.map((entry, index) => (
                  <Cell key={`cell-${index}`} fill={COLORS[index % COLORS.length]} />
                ))}
              </Pie>
              <Tooltip />
              <Legend />
            </RechartsPieChart>
          </ResponsiveContainer>
        );
      default:
        return null;
    }
  };

  const groupedMetrics = healthMetrics.reduce((acc, metric) => {
    if (!acc[metric.category]) acc[metric.category] = [];
    acc[metric.category].push(metric);
    return acc;
  }, {});

  // ... (rest of your JSX remains exactly the same, only the data generation changes)

  return (
    <>
      <style>{`
        @media (min-width: 768px) {
          .options-grid { grid-template-columns: repeat(2, 1fr); }
          .date-grid { grid-template-columns: repeat(2, 1fr); }
          .metrics-grid { grid-template-columns: repeat(2, 1fr); }
          .patients-grid { grid-template-columns: repeat(2, 1fr); }
        }
        @media (min-width: 1024px) {
          .main-grid { grid-template-columns: 2fr 1fr; }
        }
        @keyframes spin {
          0% { transform: rotate(0deg); }
          100% { transform: rotate(360deg); }
        }
      `}</style>
      <div style={{
        maxWidth: '95%',
        margin: '0 auto',
        padding: '24px',
        backgroundColor: '#f9fafb',
        minHeight: '100vh',
        marginTop: '-10px'
      }}>
        {/* Header */}
        <div style={{ marginBottom: '32px' }}>
          <h1 style={{
            fontSize: '30px',
            fontWeight: 'bold',
            color: '#111827',
            marginBottom: '8px'
          }}>Generate Custom Reports</h1>
          <p style={{ color: '#6b7280' }}>
            Create personalized reports with daily-changing data. Data updates automatically every day.
          </p>
        </div>

        <div style={{
          display: 'grid',
          gridTemplateColumns: '1fr',
          gap: '24px'
        }} className="main-grid">
          {/* Configuration Panel */}
          <div style={{
            display: 'flex',
            flexDirection: 'column',
            gap: '24px'
          }}>
            {/* Report Type Selection */}
            <div style={{
              backgroundColor: 'white',
              borderRadius: '12px',
              boxShadow: '0 1px 3px 0 rgba(0, 0, 0, 0.1)',
              padding: '24px'
            }}>
              <h2 style={{
                fontSize: '20px',
                fontWeight: '600',
                color: '#111827',
                marginBottom: '16px',
                display: 'flex',
                alignItems: 'center'
              }}>
                <FileText style={{
                  width: '20px',
                  height: '20px',
                  marginRight: '8px',
                  color: '#2563eb'
                }} />
                Report Type
              </h2>
              <div style={{
                display: 'grid',
                gridTemplateColumns: '1fr',
                gap: '16px'
              }} className="options-grid">
                {reportTypes.map((type) => {
                  const IconComponent = type.icon;
                  const isSelected = selectedReportType === type.id;
                  return (
                    <div
                      key={type.id}
                      onClick={() => setSelectedReportType(type.id)}
                      style={{
                        padding: '16px',
                        borderRadius: '8px',
                        border: '2px solid',
                        cursor: 'pointer',
                        transition: 'all 0.2s',
                        ...(isSelected ? {
                          borderColor: '#2563eb',
                          backgroundColor: '#eff6ff'
                        } : {
                          borderColor: '#e5e7eb'
                        })
                      }}
                    >
                      <div style={{
                        display: 'flex',
                        alignItems: 'flex-start',
                        gap: '12px'
                      }}>
                        <IconComponent 
                          style={{
                            width: '24px',
                            height: '24px',
                            ...(isSelected ? {
                              color: '#2563eb'
                            } : {
                              color: '#9ca3af'
                            })
                          }} 
                        />
                        <div>
                          <h3 style={{
                            fontWeight: '500',
                            color: '#111827'
                          }}>{type.name}</h3>
                          <p style={{
                            fontSize: '14px',
                            color: '#6b7280',
                            marginTop: '4px'
                          }}>{type.description}</p>
                        </div>
                      </div>
                    </div>
                  );
                })}
              </div>
            </div>

            {/* Date Range */}
            <div style={{
              backgroundColor: 'white',
              borderRadius: '12px',
              boxShadow: '0 1px 3px 0 rgba(0, 0, 0, 0.1)',
              padding: '24px'
            }}>
              <h2 style={{
                fontSize: '20px',
                fontWeight: '600',
                color: '#111827',
                marginBottom: '16px',
                display: 'flex',
                alignItems: 'center'
              }}>
                <Calendar style={{
                  width: '20px',
                  height: '20px',
                  marginRight: '8px',
                  color: '#2563eb'
                }} />
                Date Range
              </h2>
              <div style={{
                display: 'grid',
                gridTemplateColumns: '1fr',
                gap: '16px'
              }} className="date-grid">
                <div>
                  <label style={{
                    display: 'block',
                    fontSize: '14px',
                    fontWeight: '500',
                    color: '#374151',
                    marginBottom: '8px'
                  }}>Start Date</label>
                  <input
                    type="date"
                    value={dateRange.start}
                    onChange={(e) => setDateRange(prev => ({ ...prev, start: e.target.value }))}
                    style={{
                      width: '100%',
                      padding: '8px 12px',
                      border: '1px solid #d1d5db',
                      borderRadius: '8px',
                      fontSize: '14px'
                    }}
                  />
                </div>
                <div>
                  <label style={{
                    display: 'block',
                    fontSize: '14px',
                    fontWeight: '500',
                    color: '#374151',
                    marginBottom: '8px'
                  }}>End Date</label>
                  <input
                    type="date"
                    value={dateRange.end}
                    onChange={(e) => setDateRange(prev => ({ ...prev, end: e.target.value }))}
                    style={{
                      width: '100%',
                      padding: '8px 12px',
                      border: '1px solid #d1d5db',
                      borderRadius: '8px',
                      fontSize: '14px'
                    }}
                  />
                </div>
              </div>
              <div style={{
                marginTop: '16px',
                display: 'flex',
                flexWrap: 'wrap',
                gap: '8px'
              }}>
                <button
                  onClick={() => {
                    const end = new Date();
                    const start = new Date();
                    start.setDate(end.getDate() - 7);
                    setDateRange({
                      start: start.toISOString().split('T')[0],
                      end: end.toISOString().split('T')[0]
                    });
                  }}
                  style={{
                    padding: '4px 12px',
                    fontSize: '14px',
                    backgroundColor: '#f3f4f6',
                    color: '#374151',
                    borderRadius: '6px',
                    border: 'none',
                    cursor: 'pointer'
                  }}
                >
                  Last 7 days
                </button>
                <button
                  onClick={() => {
                    const end = new Date();
                    const start = new Date();
                    start.setMonth(end.getMonth() - 1);
                    setDateRange({
                      start: start.toISOString().split('T')[0],
                      end: end.toISOString().split('T')[0]
                    });
                  }}
                  style={{
                    padding: '4px 12px',
                    fontSize: '14px',
                    backgroundColor: '#f3f4f6',
                    color: '#374151',
                    borderRadius: '6px',
                    border: 'none',
                    cursor: 'pointer'
                  }}
                >
                  Last 30 days
                </button>
                <button
                  onClick={() => {
                    const end = new Date();
                    const start = new Date();
                    start.setMonth(end.getMonth() - 3);
                    setDateRange({
                      start: start.toISOString().split('T')[0],
                      end: end.toISOString().split('T')[0]
                    });
                  }}
                  style={{
                    padding: '4px 12px',
                    fontSize: '14px',
                    backgroundColor: '#f3f4f6',
                    color: '#374151',
                    borderRadius: '6px',
                    border: 'none',
                    cursor: 'pointer'
                  }}
                >
                  Last 3 months
                </button>
              </div>
            </div>
            
            {/* Patient Selection */}
            <div style={{
              backgroundColor: 'white',
              borderRadius: '12px',
              boxShadow: '0 1px 3px 0 rgba(0, 0, 0, 0.1)',
              padding: '24px'
            }}>
              <h2 style={{
                fontSize: '20px',
                fontWeight: '600',
                color: '#111827',
                marginBottom: '16px',
                display: 'flex',
                alignItems: 'center'
              }}>
                <Users style={{
                  width: '20px',
                  height: '20px',
                  marginRight: '8px',
                  color: '#2563eb'
                }} />
                Elderly
              </h2>
              {isLoadingPatients ? (
                <p style={{
                  textAlign: 'center',
                  color: '#6b7280',
                  padding: '20px'
                }}>Loading elderly data...</p>
              ) : patients.length === 0 ? (
                <p style={{
                  textAlign: 'center',
                  color: '#6b7280',
                  padding: '20px'
                }}>No elderly patients found. Please link elderly accounts first.</p>
              ) : (
                <div style={{
                  display: 'grid',
                  gridTemplateColumns: '1fr',
                  gap: '16px'
                }} className="patients-grid">
                  {patients.map((patient) => {
                    const isSelected = selectedPatients.includes(patient.id);
                    return (
                      <div
                        key={patient.id}
                        onClick={() => handlePatientToggle(patient.id)}
                        style={{
                          padding: '16px',
                          borderRadius: '8px',
                          border: '2px solid',
                          cursor: 'pointer',
                          transition: 'all 0.2s',
                          ...(isSelected ? {
                            borderColor: '#2563eb',
                            backgroundColor: '#eff6ff'
                          } : {
                            borderColor: '#e5e7eb'
                          })
                        }}
                      >
                        <div style={{
                          display: 'flex',
                          alignItems: 'center',
                          gap: '12px'
                        }}>
                          <input
                            type="checkbox"
                            checked={isSelected}
                            onChange={() => {}}
                            style={{
                              borderRadius: '4px',
                              borderColor: '#d1d5db'
                            }}
                          />
                          <div style={{ flex: 1 }}>
                            <h3 style={{
                              fontWeight: '500',
                              color: '#111827'
                            }}>{patient.name}</h3>
                            <p style={{
                              fontSize: '14px',
                              color: '#6b7280'
                            }}>Age: {patient.age}</p>
                            <p style={{
                              fontSize: '14px',
                              color: '#6b7280'
                            }}>{patient.condition}</p>
                          </div>
                        </div>
                      </div>
                    );
                  })}
                </div>
              )}
            </div>

            {/* Health Metrics Selection */}
            <div style={{
              backgroundColor: 'white',
              borderRadius: '12px',
              boxShadow: '0 1px 3px 0 rgba(0, 0, 0, 0.1)',
              padding: '24px'
            }}>
              <h2 style={{
                fontSize: '20px',
                fontWeight: '600',
                color: '#111827',
                marginBottom: '16px',
                display: 'flex',
                alignItems: 'center'
              }}>
                <Filter style={{
                  width: '20px',
                  height: '20px',
                  marginRight: '8px',
                  color: '#2563eb'
                }} />
                Health Metrics
              </h2>
              <div style={{
                display: 'flex',
                flexDirection: 'column',
                gap: '16px'
              }}>
                {Object.entries(groupedMetrics).map(([category, metrics]) => (
                  <div key={category} style={{
                    border: '1px solid #e5e7eb',
                    borderRadius: '8px',
                    padding: '16px'
                  }}>
                    <h3 style={{
                      fontWeight: '500',
                      color: '#111827',
                      marginBottom: '12px'
                    }}>{category}</h3>
                    <div style={{
                      display: 'grid',
                      gridTemplateColumns: '1fr',
                      gap: '8px'
                    }} className="metrics-grid">
                      {metrics.map((metric) => (
                        <label key={metric.id} style={{
                          display: 'flex',
                          alignItems: 'center',
                          gap: '8px',
                          cursor: 'pointer'
                        }}>
                          <input
                            type="checkbox"
                            checked={selectedMetrics.includes(metric.id)}
                            onChange={() => handleMetricToggle(metric.id)}
                            style={{
                              borderRadius: '4px',
                              borderColor: '#d1d5db'
                            }}
                          />
                          <span style={{
                            fontSize: '14px',
                            color: '#374151'
                          }}>{metric.name}</span>
                        </label>
                      ))}
                    </div>
                  </div>
                ))}
              </div>
            </div>

            {/* Chart Type Selection */}
            <div style={{
              backgroundColor: 'white',
              borderRadius: '12px',
              boxShadow: '0 1px 3px 0 rgba(0, 0, 0, 0.1)',
              padding: '24px'
            }}>
              <h2 style={{
                fontSize: '20px',
                fontWeight: '600',
                color: '#111827',
                marginBottom: '16px',
                display: 'flex',
                alignItems: 'center'
              }}>
                <TrendingUp style={{
                  width: '20px',
                  height: '20px',
                  marginRight: '8px',
                  color: '#2563eb'
                }} />
                Chart Type
              </h2>
              <div style={{
                display: 'grid',
                gridTemplateColumns: 'repeat(3, 1fr)',
                gap: '16px'
              }}>
                {chartTypes.map((chart) => {
                  const IconComponent = chart.icon;
                  const isSelected = selectedChartType === chart.id;
                  return (
                    <div
                      key={chart.id}
                      onClick={() => setSelectedChartType(chart.id)}
                      style={{
                        padding: '16px',
                        borderRadius: '8px',
                        border: '2px solid',
                        cursor: 'pointer',
                        transition: 'all 0.2s',
                        textAlign: 'center',
                        ...(isSelected ? {
                          borderColor: '#2563eb',
                          backgroundColor: '#eff6ff'
                        } : {
                          borderColor: '#e5e7eb'
                        })
                      }}
                    >
                      <IconComponent 
                        style={{
                          width: '32px',
                          height: '32px',
                          margin: '0 auto 8px',
                          ...(isSelected ? {
                            color: '#2563eb'
                          } : {
                            color: '#9ca3af'
                          })
                        }} 
                      />
                      <span style={{
                        fontSize: '14px',
                        fontWeight: '500',
                        color: '#111827'
                      }}>{chart.name}</span>
                    </div>
                  );
                })}
              </div>
            </div>
          </div>

          {/* Actions & Preview Panel */}
          <div style={{
            display: 'flex',
            flexDirection: 'column',
            gap: '24px'
          }}>
            {/* Action Buttons */}
            <div style={{
              backgroundColor: 'white',
              borderRadius: '12px',
              boxShadow: '0 1px 3px 0 rgba(0, 0, 0, 0.1)',
              padding: '24px'
            }}>
              <h2 style={{
                fontSize: '18px',
                fontWeight: '600',
                color: '#111827',
                marginBottom: '16px'
              }}>Actions</h2>
              <div style={{
                display: 'flex',
                flexDirection: 'column',
                gap: '12px'
              }}>
                <button
                  onClick={generatePreview}
                  disabled={!selectedReportType || !dateRange.start || !dateRange.end}
                  style={{
                    width: '100%',
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                    padding: '12px 16px',
                    borderRadius: '8px',
                    border: 'none',
                    cursor: 'pointer',
                    fontSize: '14px',
                    fontWeight: '500',
                    transition: 'all 0.2s',
                    backgroundColor: '#dbeafe',
                    color: '#1d4ed8',
                    ...(!selectedReportType || !dateRange.start || !dateRange.end ? {
                      opacity: '0.5',
                      cursor: 'not-allowed'
                    } : {})
                  }}
                >
                  <Eye style={{
                    width: '20px',
                    height: '20px',
                    marginRight: '8px'
                  }} />
                  Generate Preview
                </button>
                <button
                  onClick={generateReport}
                  disabled={!showPreview || isGenerating}
                  style={{
                    width: '100%',
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                    padding: '12px 16px',
                    borderRadius: '8px',
                    border: 'none',
                    cursor: 'pointer',
                    fontSize: '14px',
                    fontWeight: '500',
                    transition: 'all 0.2s',
                    backgroundColor: '#2563eb',
                    color: 'white',
                    ...(!showPreview || isGenerating ? {
                      opacity: '0.5',
                      cursor: 'not-allowed'
                    } : {})
                  }}
                >
                  {isGenerating ? (
                    <>
                      <div style={{
                        animation: 'spin 1s linear infinite',
                        borderRadius: '50%',
                        width: '20px',
                        height: '20px',
                        border: '2px solid transparent',
                        borderTop: '2px solid white',
                        marginRight: '8px'
                      }}></div>
                      Generating...
                    </>
                  ) : (
                    <>
                      <FileText style={{
                        width: '20px',
                        height: '20px',
                        marginRight: '8px'
                      }} />
                      Generate Report
                    </>
                  )}
                </button>
                {generatedReport && (
                  <button 
                    onClick={downloadReport}
                    style={{
                      width: '100%',
                      display: 'flex',
                      alignItems: 'center',
                      justifyContent: 'center',
                      padding: '12px 16px',
                      borderRadius: '8px',
                      border: 'none',
                      cursor: 'pointer',
                      fontSize: '14px',
                      fontWeight: '500',
                      transition: 'all 0.2s',
                      backgroundColor: '#16a34a',
                      color: 'white'
                    }}
                  >
                    <Download style={{
                      width: '20px',
                      height: '20px',
                      marginRight: '8px'
                    }} />
                    Download Report
                  </button>
                )}
              </div>
            </div>

            {/* Preview */}
            {showPreview && (
              <div style={{
                backgroundColor: 'white',
                borderRadius: '12px',
                boxShadow: '0 1px 3px 0 rgba(0, 0, 0, 0.1)',
                padding: '24px'
              }}>
                <h2 style={{
                  fontSize: '18px',
                  fontWeight: '600',
                  color: '#111827',
                  marginBottom: '16px'
                }}>Report Preview</h2>
                <div style={{
                  display: 'flex',
                  flexDirection: 'column',
                  gap: '16px'
                }}>
                  <div style={{ fontSize: '14px' }}>
                    <p><span style={{ fontWeight: '500' }}>Report Type:</span> {reportTypes.find(r => r.id === selectedReportType)?.name}</p>
                    <p><span style={{ fontWeight: '500' }}>Date Range:</span> {dateRange.start} to {dateRange.end}</p>
                    <p><span style={{ fontWeight: '500' }}>Metrics:</span> {selectedMetrics.length} selected</p>
                    <p><span style={{ fontWeight: '500' }}>Patients:</span> {selectedPatients.length} selected</p>
                    <p><span style={{ fontWeight: '500' }}>Chart Type:</span> {chartTypes.find(c => c.id === selectedChartType)?.name}</p>
                  </div>
                  <div style={{
                    borderTop: '1px solid #e5e7eb',
                    paddingTop: '16px'
                  }}>
                    <div style={{
                      backgroundColor: '#f9fafb',
                      padding: '16px',
                      borderRadius: '8px'
                    }}>
                      <h4 style={{
                        fontWeight: '500',
                        color: '#111827',
                        marginBottom: '8px'
                      }}>Data Preview</h4>
                      <div style={{
                        display: 'grid',
                        gridTemplateColumns: 'repeat(2, 1fr)',
                        gap: '16px',
                        fontSize: '14px'
                      }}>
                        <div style={{
                          display: 'flex',
                          justifyContent: 'space-between'
                        }}>
                          <span style={{ color: '#6b7280' }}>Blood Pressure Avg:</span>
                          <span style={{ fontWeight: '500' }}>{previewData?.bloodPressure || "128/82 mmHg"}</span>
                        </div>
                        <div style={{
                          display: 'flex',
                          justifyContent: 'space-between'
                        }}>
                          <span style={{ color: '#6b7280' }}>Heart Rate Avg:</span>
                          <span style={{ fontWeight: '500' }}>{previewData?.heartRate || "74 BPM"}</span>
                        </div>
                        <div style={{
                          display: 'flex',
                          justifyContent: 'space-between'
                        }}>
                          <span style={{ color: '#6b7280' }}>Med Adherence:</span>
                          <span style={{ fontWeight: '500', color: '#16a34a' }}>{previewData?.medAdherence || "87%"}</span>
                        </div>
                        <div style={{
                          display: 'flex',
                          justifyContent: 'space-between'
                        }}>
                          <span style={{ color: '#6b7280' }}>Data Points:</span>
                          <span style={{ fontWeight: '500' }}>{previewData?.dataPoints || "245"}</span>
                        </div>
                      </div>
                    </div>
                  </div>
                  {selectedChartType && (
                    <div style={{ marginTop: '20px' }}>
                      <h4 style={{
                        fontWeight: '500',
                        color: '#111827',
                        marginBottom: '8px'
                      }}>Chart Preview</h4>
                      <div style={{
                        height: '300px',
                        width: '100%',
                        marginTop: '16px'
                      }}>
                        {renderChart()}
                      </div>
                    </div>
                  )}
                </div>
              </div>
            )}

            {/* Generated Report Summary */}
            {generatedReport && (
              <div style={{
                backgroundColor: 'white',
                borderRadius: '12px',
                boxShadow: '0 1px 3px 0 rgba(0, 0, 0, 0.1)',
                padding: '24px'
              }}>
                <h2 style={{
                  fontSize: '18px',
                  fontWeight: '600',
                  color: '#111827',
                  marginBottom: '16px'
                }}>Report Generated</h2>
                <div style={{
                  display: 'flex',
                  flexDirection: 'column',
                  gap: '16px'
                }}>
                  <div style={{
                    backgroundColor: '#f0fdf4',
                    border: '1px solid #bbf7d0',
                    borderRadius: '8px',
                    padding: '16px',
                    marginBottom: '16px'
                  }}>
                    <div style={{
                      display: 'flex',
                      alignItems: 'center'
                    }}>
                      <div style={{
                        width: '32px',
                        height: '32px',
                        backgroundColor: '#dcfce7',
                        borderRadius: '50%',
                        display: 'flex',
                        alignItems: 'center',
                        justifyContent: 'center',
                        marginRight: '12px'
                      }}>
                        <FileText style={{
                          width: '20px',
                          height: '20px',
                          color: '#16a34a'
                        }} />
                      </div>
                      <div>
                        <h3 style={{
                          fontSize: '14px',
                          fontWeight: '500',
                          color: '#15803d'
                        }}>Report Ready</h3>
                        <p style={{
                          fontSize: '14px',
                          color: '#16a34a'
                        }}>ID: {generatedReport.reportId}</p>
                      </div>
                    </div>
                  </div>
                  <div style={{
                    display: 'grid',
                    gridTemplateColumns: 'repeat(2, 1fr)',
                    gap: '16px',
                    fontSize: '14px'
                  }}>
                    <div style={{
                      display: 'flex',
                      justifyContent: 'space-between'
                    }}>
                      <span style={{ color: '#6b7280' }}>Data Points:</span>
                      <span style={{ fontWeight: '500' }}>{generatedReport.totalDataPoints}</span>
                    </div>
                    <div style={{
                      display: 'flex',
                      justifyContent: 'space-between'
                    }}>
                      <span style={{ color: '#6b7280' }}>Compliance Avg:</span>
                      <span style={{ fontWeight: '500', color: '#16a34a' }}>{generatedReport.summary.avgCompliance}%</span>
                    </div>
                    <div style={{
                      display: 'flex',
                      justifyContent: 'space-between'
                    }}>
                      <span style={{ color: '#6b7280' }}>Alerts:</span>
                      <span style={{ fontWeight: '500', color: '#ea580c' }}>{generatedReport.summary.alertsGenerated}</span>
                    </div>
                    <div style={{
                      display: 'flex',
                      justifyContent: 'space-between'
                    }}>
                      <span style={{ color: '#6b7280' }}>Trends:</span>
                      <span style={{ fontWeight: '500', color: '#2563eb' }}>{generatedReport.summary.trendsIdentified}</span>
                    </div>
                  </div>
                </div>
              </div>
            )}
          </div>
        </div>
      </div>
    </>
  );
};

export default CustomReportsGenerator;