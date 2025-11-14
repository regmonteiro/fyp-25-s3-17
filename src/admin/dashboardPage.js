import React, { useEffect, useState } from 'react';
import { ref, onValue, update } from 'firebase/database';
import { database } from '../firebaseConfig';
import { useNavigate } from 'react-router-dom';

const DashboardPage = () => {
  const [users, setUsers] = useState([]);
  const [filteredUsers, setFilteredUsers] = useState([]);
  const [searchTerm, setSearchTerm] = useState('');
  const [loadingUsers, setLoadingUsers] = useState(true);
  const [fetchError, setFetchError] = useState(false);
  const [actionLoadingUserId, setActionLoadingUserId] = useState(null);

  const navigate = useNavigate();

  useEffect(() => {
    const accountRef = ref(database, 'Account');
    const unsubscribe = onValue(
      accountRef,
      (snapshot) => {
        const data = snapshot.val();
        if (data) {
          const usersArray = Object.keys(data).map((key) => ({
            id: key,
            firstname: data[key].firstname || '',
            lastname: data[key].lastname || '',
            email: data[key].email || '',
            userType: data[key].userType || 'unknown',
            phoneNum: data[key].phoneNum || '',
            dob: data[key].dob || '',
            createdAt: data[key].createdAt || '',
            lastLoginDate: data[key].lastLoginDate || '',
            status: data[key].status || 'Active',
          }));
          const filteredUsers = usersArray.filter(
            (user) => user.userType !== 'unknown'
          );
          setUsers(filteredUsers);
          setFilteredUsers(filteredUsers);
        } else {
          setUsers([]);
          setFilteredUsers([]);
        }
        setLoadingUsers(false);
      },
      (error) => {
        console.error(error);
        setFetchError(true);
        setLoadingUsers(false);
      }
    );

    return () => unsubscribe();
  }, []);

  // Search filter
  useEffect(() => {
    if (searchTerm.trim() === '') {
      setFilteredUsers(users);
    } else {
      const lowercasedTerm = searchTerm.toLowerCase();
      const filtered = users.filter(
        (user) =>
          user.firstname.toLowerCase().includes(lowercasedTerm) ||
          user.lastname.toLowerCase().includes(lowercasedTerm) ||
          user.email.toLowerCase().includes(lowercasedTerm) ||
          user.userType.toLowerCase().includes(lowercasedTerm) ||
          user.phoneNum.toLowerCase().includes(lowercasedTerm)
      );
      setFilteredUsers(filtered);
    }
  }, [searchTerm, users]);

  const toggleUserStatus = async (userId, email, currentStatus) => {
    const action = currentStatus === 'Active' ? 'deactivate' : 'activate';
    if (
      !window.confirm(
        `Are you sure you want to ${action} the account for ${email}?`
      )
    )
      return;

    setActionLoadingUserId(userId);
    try {
      const newStatus = currentStatus === 'Active' ? 'Deactivated' : 'Active';
      const userRef = ref(database, `Account/${userId}`);
      await update(userRef, { status: newStatus });
      alert(`Account for ${email} has been ${newStatus.toLowerCase()}.`);
    } catch (error) {
      console.error(error);
      alert(`Failed to ${action} the account. Please try again.`);
    }
    setActionLoadingUserId(null);
  };

  const handleSearchChange = (e) => {
    setSearchTerm(e.target.value);
  };

  const handleMembershipNavigation = () => {
    navigate('/adminMembership');
  };

  return (
    <div style={styles.container}>
      <h1 style={styles.title}>Admin Dashboard</h1>

      <section style={styles.usersSection}>
        <div style={styles.sectionHeader}>
          <h2 style={styles.sectionTitle}>Registered Users</h2>
          <div style={styles.rightControls}>
            <input
              type="text"
              placeholder="Search users..."
              value={searchTerm}
              onChange={handleSearchChange}
              style={styles.searchInput}
            />
          </div>
        </div>

        {loadingUsers ? (
          <p style={styles.loading}>Loading users...</p>
        ) : fetchError ? (
          <p style={styles.error}>Failed to load users. Try again later.</p>
        ) : filteredUsers.length === 0 ? (
          <p>No {searchTerm ? 'matching ' : ''}registered users found.</p>
        ) : (
          <div style={styles.tableWrapper}>
            <table style={styles.table}>
              <thead>
                <tr>
                  {[
                    'First Name',
                    'Last Name',
                    'Email',
                    'User Type',
                    'Phone',
                    'DOB',
                    'Created At',
                    'Last Login',
                    'Status',
                    'Actions',
                  ].map((header) => (
                    <th key={header} style={styles.th}>
                      {header}
                    </th>
                  ))}
                </tr>
              </thead>
              <tbody>
                {filteredUsers.map((user) => (
                  <tr key={user.id} style={styles.tr}>
                    <td style={styles.td}>{user.firstname}</td>
                    <td style={styles.td}>{user.lastname}</td>
                    <td style={{ ...styles.td, color: '#005f73' }}>
                      {user.email}
                    </td>
                    <td style={styles.td}>
                      <UserTypeBadge type={user.userType} />
                    </td>
                    <td style={styles.td}>{user.phoneNum}</td>
                    <td style={styles.td}>{user.dob}</td>
                    <td style={styles.td}>
                      {user.createdAt
                        ? new Date(user.createdAt).toLocaleDateString()
                        : ''}
                    </td>
                    <td style={styles.td}>
                      {user.lastLoginDate
                        ? new Date(user.lastLoginDate).toLocaleString()
                        : ''}
                    </td>
                    <td
                      style={{
                        ...styles.td,
                        fontWeight: '700',
                        color:
                          user.status === 'Deactivated'
                            ? '#d9534f'
                            : '#3c763d',
                      }}
                    >
                      {user.status}
                    </td>
                    <td style={styles.td}>
                      <button
                        onClick={() =>
                          toggleUserStatus(user.id, user.email, user.status)
                        }
                        style={{
                          ...styles.actionButton,
                          backgroundColor:
                            user.status === 'Active' ? '#d9534f' : '#5cb85c',
                        }}
                        disabled={actionLoadingUserId === user.id}
                      >
                        {actionLoadingUserId === user.id
                          ? 'Processing...'
                          : user.status === 'Active'
                          ? 'Deactivate'
                          : 'Activate'}
                      </button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </section>
    </div>
  );
};

const UserTypeBadge = ({ type }) => {
  const colors = {
    admin: '#f28482',
    caregiver: '#82c0cc',
    elderly: '#f7ede2',
    unknown: '#ccc5b9',
  };
  const textColors = {
    admin: '#4a2c2a',
    caregiver: '#1e3d47',
    elderly: '#5f4b3e',
    unknown: '#6e6b5a',
  };
  return (
    <span
      style={{
        ...styles.badge,
        backgroundColor: colors[type] || colors.unknown,
        color: textColors[type] || textColors.unknown,
        border: `1.5px solid ${textColors[type] || textColors.unknown}`,
        fontWeight: '600',
      }}
    >
      {type.charAt(0).toUpperCase() + type.slice(1)}
    </span>
  );
};

const styles = {
  container: {
    color: '#000',
    minHeight: '100vh',
    padding: 24,
    fontFamily: "'Segoe UI', Tahoma, Geneva, Verdana, sans-serif",
    backgroundColor: '#f4f6f8',
    marginTop: '-20px',
  },
  title: {
    fontSize: 32,
    fontWeight: '700',
    marginBottom: 24,
  },
  usersSection: {
    backgroundColor: '#fff',
    padding: 28,
    borderRadius: 16,
    boxShadow: '0 6px 30px rgba(0,0,0,0.15)',
    color: '#1c1c1b',
    marginTop: 20,
  },
  sectionHeader: {
    display: 'flex',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 16,
    flexWrap: 'wrap',
    gap: 16,
  },
  sectionTitle: {
    fontSize: 24,
    fontWeight: '600',
    margin: 0,
  },
  rightControls: {
    display: 'flex',
    alignItems: 'center',
    gap: 12,
  },
  searchInput: {
    padding: '10px 16px',
    borderRadius: 8,
    border: '1.5px solid #1e1d1dff',
    fontSize: 15,
    minWidth: 250,
    outline: 'none',
    transition: 'border-color 0.2s',
  },
  membershipButton: {
    backgroundColor: '#3d405b',
    color: 'white',
    border: 'none',
    padding: '12px 20px',
    borderRadius: 8,
    fontWeight: '600',
    cursor: 'pointer',
    fontSize: 16,
    transition: 'background 0.3s',
    marginBottom: 20,
  },
  loading: {
    color: '#5f4b3e',
    fontWeight: '600',
  },
  error: {
    color: '#b23a48',
    fontWeight: '700',
  },
  tableWrapper: {
    overflowX: 'auto',
    marginTop: 16,
  },
  table: {
    width: '100%',
    borderCollapse: 'collapse',
    minWidth: 950,
    color: '#080808',
  },
  th: {
    textAlign: 'left',
    padding: '14px 15px',
    borderBottom: '3px solid #3d405b',
    fontWeight: '700',
    fontSize: 16,
  },
  tr: {
    borderBottom: '1.5px solid #a58a6f',
  },
  td: {
    padding: '14px 15px',
    fontSize: 15,
    verticalAlign: 'middle',
  },
  badge: {
    padding: '5px 14px',
    borderRadius: 20,
    fontSize: 13,
    display: 'inline-block',
  },
  actionButton: {
    color: 'white',
    border: 'none',
    padding: '6px 12px',
    borderRadius: 6,
    cursor: 'pointer',
    fontWeight: '600',
    fontSize: 14,
    minWidth: 90,
  },
};

export default DashboardPage;