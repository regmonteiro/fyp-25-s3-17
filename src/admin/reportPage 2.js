// src/admin/ReportPage.js
import React, { useState, useEffect } from 'react';
import { generateUsageReport, getAllUserTypeDistribution } from '../controller/reportController';
import {
  BarChart, Bar, XAxis, YAxis, Tooltip, CartesianGrid, ResponsiveContainer,
  PieChart, Pie, Cell, Legend
} from 'recharts';
import { ref, onValue } from 'firebase/database';
import { database } from '../firebaseConfig';

const COLORS = ['#b76ffaff', '#0088FE'];
const USER_TYPE_COLORS = {
  admin: '#7B68EE',
  caregiver: '#20B2AA',
  elderly: '#FF8C00',
  unknown: '#b7a5f7ff',
};

const today = new Date().toISOString().split("T")[0];

const ReportPage = () => {
  const [startDate, setStartDate] = useState('');
  const [endDate, setEndDate] = useState('');
  const [filteredReportData, setFilteredReportData] = useState([]);
  const [error, setError] = useState('');
  const [subscriberStatus, setSubscriberStatus] = useState([
    { name: 'Subscribers', value: 0 },
    { name: 'Inactive (mock)', value: 0 },
  ]);
  const [userTypeCount, setUserTypeCount] = useState([]);
  const [selectedUserType, setSelectedUserType] = useState('all');
  const [searchTerm, setSearchTerm] = useState('');

  useEffect(() => {
    getAllUserTypeDistribution().then(setUserTypeCount);
  }, []);

  useEffect(() => {
    const subsRef = ref(database, 'subscribers');
    const unsubscribe = onValue(subsRef, (snapshot) => {
      const data = snapshot.val();
      const total = data ? Object.keys(data).length : 0;
      setSubscriberStatus([
        { name: 'Subscribers', value: total },
        { name: 'Inactive', value: 0 }
      ]);
    });

    return () => unsubscribe();
  }, []);

  const handleGenerateReport = async () => {
    setError('');
    setFilteredReportData([]);

    if (!startDate || !endDate) {
      setError('Please select both start and end date.');
      return;
    }
    if (startDate > endDate) {
      setError('Start date cannot be later than end date.');
      return;
    }
    if (startDate > today || endDate > today) {
      setError('Dates cannot be in the future.');
      return;
    }

    const result = await generateUsageReport(startDate, endDate);
    if (!result || result.length === 0) {
      setError('No data found in the selected range.');
      setFilteredReportData([]);
    } else {
      setFilteredReportData(result);
    }
  };

  return (
    <div style={styles.container}>
      <h2 style={styles.heading}>Admin Usage Report</h2>

      <div style={styles.form}>
        <div style={styles.inputGroup}>
          <label style={styles.label}>Start Date:</label>
          <input
            type="date"
            max={today}
            value={startDate}
            onChange={e => setStartDate(e.target.value)}
            style={styles.input}
          />
        </div>

        <div style={styles.inputGroup}>
          <label style={styles.label}>End Date:</label>
          <input
            type="date"
            max={today}
            value={endDate}
            onChange={e => setEndDate(e.target.value)}
            style={styles.input}
          />
        </div>

        <button onClick={handleGenerateReport} style={styles.button}>Generate Report</button>
      </div>

      {error && <p style={styles.error}>{error}</p>}

      {filteredReportData.length > 0 && (
        <>
          {/* Filter Buttons */}
          <div style={styles.filterButtons}>
            {['all', 'admin', 'elderly', 'caregiver'].map(type => (
              <button
                key={type}
                onClick={() => setSelectedUserType(type)}
                style={{
                  ...styles.filterButton,
                  backgroundColor: selectedUserType === type ? USER_TYPE_COLORS[type] || '#ccc' : '#f1f1f1',
                  color: selectedUserType === type ? '#fff' : '#333',
                  border: `2px solid ${USER_TYPE_COLORS[type] || '#ccc'}`,
                }}
              >
                {type === 'all' ? 'Show All' : type.charAt(0).toUpperCase() + type.slice(1)}
              </button>
            ))}
          </div>

          {/* Search Bar */}
          <div style={styles.searchBar}>
            <input
              type="text"
              placeholder="Search by email..."
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
              style={styles.searchInput}
            />
          </div>

          {/* Grouped Tables */}
          <div style={styles.tablesWrapper}>
            {Object.entries(
              filteredReportData.reduce((acc, user) => {
                const type = user.userType || 'unknown';
                if (!acc[type]) acc[type] = [];
                acc[type].push(user);
                return acc;
              }, {})
            )
              .filter(([userType]) => selectedUserType === 'all' || selectedUserType === userType)
              .map(([userType, users]) => {
                const filteredUsers = users.filter(user =>
                  user.email.toLowerCase().includes(searchTerm.toLowerCase())
                );

                if (filteredUsers.length === 0) return null;

                return (
                  <div
                    key={userType}
                    style={{
                      ...styles.userTypeCard,
                      borderTopColor: USER_TYPE_COLORS[userType] || USER_TYPE_COLORS.unknown,
                    }}
                  >
                    <h3 style={{
                      ...styles.subTitle,
                      color: USER_TYPE_COLORS[userType] || USER_TYPE_COLORS.unknown,
                      textAlign: 'left',
                      marginBottom: '12px',
                    }}>
                      {userType.charAt(0).toUpperCase() + userType.slice(1)} Users
                    </h3>
                    <div style={styles.tableContainer}>
                      <table style={styles.table}>
                        <thead>
                          <tr>
                            <th style={styles.th}>Email</th>
                            <th style={styles.th}>Login Count</th>
                            <th style={styles.th}>Last Active</th>
                          </tr>
                        </thead>
                        <tbody>
                          {filteredUsers.map((user, index) => (
                            <tr key={user.id || index}>
                              <td style={styles.td}>{user.email}</td>
                              <td style={styles.td}>{user.loginCount}</td>
                              <td style={styles.td}>
                                {user.lastActiveDate !== 'N/A'
                                  ? new Date(user.lastActiveDate).toLocaleString()
                                  : 'N/A'}
                              </td>
                            </tr>
                          ))}
                        </tbody>
                      </table>
                    </div>
                  </div>
                );
              })}
          </div>
        </>
      )}

      {/* User Type Distribution Chart */}
      <h3 style={styles.subTitle}>User Type Distribution</h3>
      <ResponsiveContainer width="100%" height={300}>
        <BarChart data={userTypeCount} margin={{ top: 20, right: 30, left: 20, bottom: 40 }}>
          <CartesianGrid strokeDasharray="3 3" />
          <XAxis dataKey="name" />
          <YAxis allowDecimals={false} />
          <Tooltip />
          <Bar dataKey="value" fill="#7ca1f6ff" />
        </BarChart>
      </ResponsiveContainer>

      {/* Subscriber Status Pie Chart */}
      <h3 style={styles.subTitle}>Subscriber Status</h3>
      <ResponsiveContainer width="100%" height={300}>
        <PieChart>
          <Pie
            data={subscriberStatus}
            dataKey="value"
            nameKey="name"
            cx="50%"
            cy="50%"
            outerRadius={100}
            label
          >
            {subscriberStatus.map((entry, index) => (
              <Cell key={`cell-${index}`} fill={COLORS[index % COLORS.length]} />
            ))}
          </Pie>
          <Tooltip />
          <Legend verticalAlign="bottom" height={36} />
        </PieChart>
      </ResponsiveContainer>
    </div>
  );
};

const styles = {
  container: {
    padding: '40px 20px',
    fontFamily: 'Segoe UI, Tahoma, Geneva, Verdana, sans-serif',
    backgroundColor: '#f9fafa',
    minHeight: '100vh',
    maxWidth: '1200px',
    margin: 'auto',
  },
  heading: {
    fontSize: '28px',
    marginBottom: '25px',
    color: '#333',
    textAlign: 'center',
  },
  subTitle: {
    marginTop: '40px',
    fontSize: '22px',
    color: '#2d3436',
  },
  form: {
    display: 'flex',
    flexWrap: 'wrap',
    gap: '20px',
    alignItems: 'flex-end',
    marginBottom: '35px',
    justifyContent: 'center',
  },
  inputGroup: {
    display: 'flex',
    flexDirection: 'column',
    minWidth: '180px',
  },
  label: {
    marginBottom: '6px',
    fontWeight: '600',
    color: '#555',
  },
  input: {
    padding: '8px 12px',
    borderRadius: '5px',
    border: '1px solid #ccc',
    fontSize: '14px',
  },
  button: {
    width: '180px',
    height: '42px',
    padding: '10px 20px',
    borderRadius: '5px',
    backgroundColor: '#007bff',
    color: 'white',
    border: 'none',
    fontWeight: '600',
    cursor: 'pointer',
    marginTop: 'auto',
    transition: 'background-color 0.3s ease',
  },
  error: {
    color: 'red',
    marginBottom: '20px',
    textAlign: 'center',
    fontWeight: '600',
  },
  tablesWrapper: {
    display: 'flex',
    flexDirection: 'column',
    gap: '30px',
  },
  userTypeCard: {
    backgroundColor: '#fff',
    borderRadius: '8px',
    padding: '20px',
    boxShadow: '0 4px 12px rgba(0,0,0,0.08)',
    borderTop: '5px solid',
  },
  tableContainer: {
    overflowX: 'auto',
  },
  table: {
    width: '100%',
    borderCollapse: 'collapse',
    minWidth: '700px',
  },
  th: {
    backgroundColor: '#f1f1f1',
    textAlign: 'left',
    padding: '12px',
    borderBottom: '1px solid #ddd',
    fontWeight: '700',
  },
  td: {
    padding: '12px',
    borderBottom: '1px solid #f0f0f0',
    fontSize: '14px',
  },
  filterButtons: {
    display: 'flex',
    gap: '12px',
    marginBottom: '16px',
    justifyContent: 'center',
    flexWrap: 'wrap',
  },
  filterButton: {
    padding: '8px 16px',
    borderRadius: '20px',
    cursor: 'pointer',
    fontWeight: '600',
    fontSize: '14px',
    transition: 'all 0.2s ease-in-out',
    outline: 'none',
  },
  searchBar: {
    textAlign: 'center',
    marginBottom: '30px',
  },
  searchInput: {
    padding: '10px 16px',
    borderRadius: '5px',
    border: '1px solid #ccc',
    fontSize: '14px',
    width: '300px',
    maxWidth: '100%',
  },
};

export default ReportPage;
