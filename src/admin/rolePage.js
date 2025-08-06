// src/pages/rolePage.jsx
import React, { useState } from 'react';
import { ref, get, update } from 'firebase/database';
import { database } from '../firebaseConfig';

const styles = {
  container: {
    maxWidth: 400,
    margin: '4rem auto',
    padding: '2.5rem 2rem',
    backgroundColor: '#ffffff',
    borderRadius: 16,
    boxShadow: '0 12px 28px rgba(0, 123, 255, 0.12)',
    fontFamily: "'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen",
    color: '#222',
  },
  title: {
    fontSize: '2.25rem',
    fontWeight: 700,
    color: '#007bff',
    textAlign: 'center',
    marginBottom: 32,
    letterSpacing: '0.04em',
  },
  formGroup: {
    marginBottom: 24,
    display: 'flex',
    flexDirection: 'column',
  },
  label: {
    fontWeight: 600,
    fontSize: '1rem',
    marginBottom: 8,
    color: '#444',
  },
  input: {
    padding: '0.75rem 1rem',
    fontSize: '1rem',
    borderRadius: 10,
    border: '1.5px solid #cbd5e1',
    transition: 'border-color 0.3s ease, box-shadow 0.3s ease',
    outline: 'none',
  },
  inputFocus: {
    borderColor: '#007bff',
    boxShadow: '0 0 0 3px rgba(0, 123, 255, 0.25)',
  },
  select: {
    padding: '0.75rem 1rem',
    fontSize: '1rem',
    borderRadius: 10,
    border: '1.5px solid #cbd5e1',
    transition: 'border-color 0.3s ease, box-shadow 0.3s ease',
    outline: 'none',
    appearance: 'none',
    background: `url("data:image/svg+xml;charset=US-ASCII,%3csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 4 5'%3e%3cpath fill='%23444' d='M2 0L0 2h4zm0 5L0 3h4z'/%3e%3c/svg%3e") no-repeat right 1rem center/8px 10px`,
  },
  button: {
    width: '100%',
    padding: '0.85rem',
    backgroundColor: '#007bff',
    color: '#fff',
    fontWeight: 700,
    fontSize: '1.15rem',
    borderRadius: 12,
    border: 'none',
    cursor: 'pointer',
    boxShadow: '0 6px 12px rgba(0, 123, 255, 0.35)',
    transition: 'background-color 0.3s ease, box-shadow 0.3s ease',
  },
  buttonHover: {
    backgroundColor: '#0056b3',
    boxShadow: '0 8px 18px rgba(0, 86, 179, 0.6)',
  },
  buttonDisabled: {
    backgroundColor: '#a3c5ff',
    cursor: 'not-allowed',
    boxShadow: 'none',
  },
  message: {
    marginTop: 20,
    fontWeight: 600,
    fontSize: '1rem',
    textAlign: 'center',
  },
  successMessage: {
    color: '#198754',
  },
  errorMessage: {
    color: '#dc3545',
  },
};

function encodeEmail(email) {
  return email.replace(/[.#$/[\]]/g, '_');
}

function RolePage() {
  const [email, setEmail] = useState('');
  const [role, setRole] = useState('');
  const [roles] = useState(['elderly', 'caregiver', 'admin']);
  const [message, setMessage] = useState('');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);
  const [buttonHover, setButtonHover] = useState(false);
  const [inputFocus, setInputFocus] = useState({ email: false, role: false });

  const handleAssign = async () => {
    setMessage('');
    setError('');

    if (!email.trim()) {
      setError('Email is required.');
      return;
    }
    if (!roles.includes(role)) {
      setError('Please select a valid role.');
      return;
    }

    setLoading(true);
    try {
      const encodedEmail = encodeEmail(email.trim());
      const userRef = ref(database, 'Account/' + encodedEmail);
      const snapshot = await get(userRef);

      if (!snapshot.exists()) {
        setError('No account found with that email.');
        setLoading(false);
        return;
      }

      await update(userRef, { userType: role });
      setMessage(`Role "${role.charAt(0).toUpperCase() + role.slice(1)}" assigned to ${email.trim()}`);
      setLoading(false);
    } catch (err) {
      console.error(err);
      setError('Error assigning role. Please try again.');
      setLoading(false);
    }
  };

  return (
    <div style={styles.container}>
      <h2 style={styles.title}>Assign User Roles</h2>

      <div style={styles.formGroup}>
        <label htmlFor="email" style={styles.label}>User Email</label>
        <input
          id="email"
          type="email"
          placeholder="Enter user email"
          value={email}
          onChange={(e) => setEmail(e.target.value)}
          disabled={loading}
          style={{
            ...styles.input,
            ...(inputFocus.email ? styles.inputFocus : {}),
          }}
          onFocus={() => setInputFocus({ ...inputFocus, email: true })}
          onBlur={() => setInputFocus({ ...inputFocus, email: false })}
        />
      </div>

      <div style={styles.formGroup}>
        <label htmlFor="role" style={styles.label}>Select Role</label>
        <select
          id="role"
          value={role}
          onChange={(e) => setRole(e.target.value)}
          disabled={loading}
          style={{
            ...styles.select,
            ...(inputFocus.role ? styles.inputFocus : {}),
          }}
          onFocus={() => setInputFocus({ ...inputFocus, role: true })}
          onBlur={() => setInputFocus({ ...inputFocus, role: false })}
        >
          <option value="">-- Select Role --</option>
          {roles.map((r) => (
            <option key={r} value={r}>
              {r.charAt(0).toUpperCase() + r.slice(1)}
            </option>
          ))}
        </select>
      </div>

      <button
        onClick={handleAssign}
        disabled={loading || !email.trim() || !role}
        style={{
          ...styles.button,
          ...(loading || !email.trim() || !role ? styles.buttonDisabled : {}),
          ...(buttonHover && !(loading || !email.trim() || !role) ? styles.buttonHover : {}),
        }}
        onMouseEnter={() => setButtonHover(true)}
        onMouseLeave={() => setButtonHover(false)}
      >
        {loading ? 'Assigning...' : 'Assign Role'}
      </button>

      {message && <p style={{ ...styles.message, ...styles.successMessage }}>{message}</p>}
      {error && <p style={{ ...styles.message, ...styles.errorMessage }}>{error}</p>}
    </div>
  );
}

export default RolePage;
