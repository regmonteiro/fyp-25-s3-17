// src/pages/AnnouncementPage.jsx
import React, { useEffect, useState } from 'react';
import { fetchAllAnnouncements, createAnnouncement } from '../controller/announcementController';

function AnnouncementPage() {
  const [announcements, setAnnouncements] = useState([]);
  const [title, setTitle] = useState('');
  const [description, setDescription] = useState('');
  const [userGroups, setUserGroups] = useState([]);
  const [message, setMessage] = useState('');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);
  const [showForm, setShowForm] = useState(false);

  const availableGroups = ['all users ','elderly', 'caregiver', 'admin'];

  useEffect(() => {
    async function loadAnnouncements() {
      try {
        const data = await fetchAllAnnouncements();
        setAnnouncements(data);
      } catch (err) {
        console.error(err);
        setError('Could not load previous announcements.');
      }
    }
    loadAnnouncements();
  }, []);

  const toggleUserGroup = (group) => {
    setUserGroups(prev =>
      prev.includes(group) ? prev.filter(g => g !== group) : [...prev, group]
    );
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    setMessage('');
    setError('');

    if (!title.trim() || !description.trim()) {
      setError('Please fill in both title and description.');
      return;
    }

    if (userGroups.length === 0) {
      setError('Please select at least one user group.');
      return;
    }

    setLoading(true);
    try {
      const newAnnouncement = await createAnnouncement({ title, description, userGroups });
      setAnnouncements(prev => [newAnnouncement, ...prev]);
      setMessage('Announcement sent successfully!');
      setTitle('');
      setDescription('');
      setUserGroups([]);
      setShowForm(false);
    } catch (err) {
      console.error(err);
      setError('Failed to send announcement');
    }
    setLoading(false);
  };

  return (
    <div style={styles.pageContainer}>
      <h1 style={styles.title}>System Announcements</h1>

      <button
        onClick={() => setShowForm(!showForm)}
        style={{ ...styles.button, ...styles.toggleButton }}
        aria-expanded={showForm}
      >
        {showForm ? 'Cancel' : 'New Announcement'}
      </button>

      {showForm && (
        <form onSubmit={handleSubmit} style={styles.form}>
          <label htmlFor="title" style={styles.label}>Title</label>
          <input
            id="title"
            style={styles.input}
            type="text"
            value={title}
            onChange={e => setTitle(e.target.value)}
            disabled={loading}
            placeholder="Announcement title"
            required
          />

          <label htmlFor="description" style={styles.label}>Description</label>
          <textarea
            id="description"
            style={styles.textarea}
            value={description}
            onChange={e => setDescription(e.target.value)}
            rows={5}
            disabled={loading}
            placeholder="Details about the announcement"
            required
          />

          <fieldset style={styles.fieldset}>
            <legend style={styles.legend}>Send To User Groups</legend>
            <div style={styles.checkboxGroup}>
              {availableGroups.map(group => (
                <label key={group} style={styles.checkboxLabel}>
                  <input
                    type="checkbox"
                    checked={userGroups.includes(group)}
                    onChange={() => toggleUserGroup(group)}
                    disabled={loading}
                  />
                  <span style={{ marginLeft: 8 }}>{group.charAt(0).toUpperCase() + group.slice(1)}</span>
                </label>
              ))}
            </div>
          </fieldset>

          <button
            type="submit"
            disabled={loading}
            style={{ ...styles.button, ...styles.submitButton }}
          >
            {loading ? 'Sending...' : 'Send Announcement'}
          </button>
        </form>
      )}

      {message && <p style={styles.success}>{message}</p>}
      {error && <p style={styles.error}>{error}</p>}

      <h2 style={styles.subTitle}>Previous Announcements</h2>
      {announcements.length === 0 ? (
        <p style={styles.noData}>No announcements found.</p>
      ) : (
        <ul style={styles.announcementList}>
          {announcements.map(a => (
            <li key={a.id} style={styles.announcementItem} tabIndex={0}>
              <header style={styles.announcementHeader}>
                <h3 style={styles.announcementTitle}>{a.title}</h3>
                <time style={styles.announcementTime}>
                  {new Date(a.createdAt).toLocaleString()}
                </time>
              </header>
              <p style={styles.announcementDescription}>{a.description}</p>
              <footer style={styles.announcementFooter}>
                To: {a.userGroups.map(g => g.charAt(0).toUpperCase() + g.slice(1)).join(', ')}
              </footer>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}

const styles = {
  pageContainer: {
    maxWidth: 1200,
    margin: '1rem auto',
    padding: '1rem 2rem 3rem',
    fontFamily: "'Segoe UI', Tahoma, Geneva, Verdana, sans-serif",
    backgroundColor: '#e6f0fa',  // very light blue background
    borderRadius: 16,
    boxShadow: '0 12px 30px rgba(0,0,0,0.1)',
    color: '#002f6c', // dark blue text for readability
  },
  title: {
    fontSize: '2.4rem',
    fontWeight: '700',
    color: '#003366', // deep blue
    textAlign: 'center',
    marginBottom: 24,
    userSelect: 'none',
  },
  subTitle: {
    fontSize: '1.6rem',
    fontWeight: '600',
    color: '#004080', // medium blue
    marginTop: 10,
    marginBottom: 16,
    borderBottom: '2px solid #99badd', // soft blue border
    paddingBottom: 6,
  },
  button: {
    fontWeight: '700',
    fontSize: 16,
    borderRadius: 12,
    padding: '12px 20px',
    border: 'none',
    cursor: 'pointer',
    transition: 'background-color 0.3s ease',
    boxShadow: '0 4px 8px rgb(0 0 0 / 0.1)',
  },
  toggleButton: {
    backgroundColor: '#4a90e2', // friendly blue
    color: 'white',
    marginBottom: 20,
    alignSelf: 'center',
    display: 'block',
    width: 'fit-content',
    minWidth: 180,
  },
  submitButton: {
    backgroundColor: '#007acc', // bright but comfortable blue
    color: 'white',
    marginTop: 12,
  },
  form: {
    display: 'flex',
    flexDirection: 'column',
    gap: 16,
    paddingBottom: 24,
  },
  label: {
    fontWeight: '600',
    fontSize: 16,
    color: '#003366',
  },
  input: {
    padding: '14px 16px',
    fontSize: 16,
    borderRadius: 10,
    border: '1.8px solid #99badd',
    outlineColor: '#4a90e2',
    transition: 'border-color 0.25s ease',
    boxShadow: 'inset 0 1px 3px rgba(0,0,0,0.1)',
    color: '#003366',
    backgroundColor: '#f7faff',
  },
  textarea: {
    padding: '14px 16px',
    fontSize: 16,
    borderRadius: 10,
    border: '1.8px solid #99badd',
    outlineColor: '#4a90e2',
    resize: 'vertical',
    minHeight: 120,
    boxShadow: 'inset 0 1px 3px rgba(0,0,0,0.1)',
    color: '#003366',
    backgroundColor: '#f7faff',
  },
  fieldset: {
    border: '1.5px solid #99badd',
    borderRadius: 12,
    padding: 12,
  },
  legend: {
    fontWeight: '700',
    fontSize: 16,
    padding: '0 8px',
    color: '#004080',
  },
  checkboxGroup: {
    display: 'flex',
    gap: 24,
    flexWrap: 'wrap',
  },
  checkboxLabel: {
    fontSize: 15,
    cursor: 'pointer',
    userSelect: 'none',
    color: '#003366',
  },
  success: {
    marginTop: 20,
    fontWeight: '700',
    fontSize: 16,
    color: '#2a9d8f',
    textAlign: 'center',
  },
  error: {
    marginTop: 20,
    fontWeight: '700',
    fontSize: 16,
    color: '#d00000',
    textAlign: 'center',
  },
  noData: {
    color: '#555',
    fontStyle: 'italic',
    textAlign: 'center',
    marginTop: 20,
  },
  announcementList: {
    listStyleType: 'none',
    padding: 0,
    maxHeight: 400,
    overflowY: 'auto',
  },
  announcementItem: {
    backgroundColor: '#dbe9ff', // soft light blue background for each announcement
    borderRadius: 14,
    padding: 20,
    marginBottom: 16,
    boxShadow: '0 6px 15px rgba(0,0,0,0.05)',
    transition: 'transform 0.2s ease, box-shadow 0.2s ease',
    outline: 'none',
    color: '#002f6c',
  },
  announcementHeader: {
    display: 'flex',
    justifyContent: 'space-between',
    marginBottom: 8,
    flexWrap: 'wrap',
    gap: 10,
  },
  announcementTitle: {
    fontSize: 20,
    fontWeight: '700',
    margin: 0,
    color: '#004080',
  },
  announcementTime: {
    fontSize: 14,
    color: '#336699',
    fontStyle: 'italic',
  },
  announcementDescription: {
    fontSize: 16,
    color: '#003366',
    marginBottom: 8,
  },
  announcementFooter: {
    fontSize: 14,
    color: '#003366',
  },

  // Responsive
  '@media (max-width: 600px)': {
    pageContainer: {
      margin: '1rem',
      padding: '1rem',
    },
    announcementItem: {
      padding: 16,
    },
    announcementHeader: {
      flexDirection: 'column',
      alignItems: 'flex-start',
    },
  },
};

export default AnnouncementPage;
