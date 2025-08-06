import React, { useEffect, useState } from 'react';
import { fetchSafetyMeasures, saveSafetyMeasure } from '../controller/safetyController';

function SafetyPage() {
  const [contentGuidelines, setContentGuidelines] = useState('');
  const [parameters, setParameters] = useState('');
  const [createdBy, setCreatedBy] = useState('');
  const [safetyList, setSafetyList] = useState([]);
  const [message, setMessage] = useState('');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    loadSafetyData();
  }, []);

  const loadSafetyData = async () => {
    setLoading(true);
    try {
      const data = await fetchSafetyMeasures();
      setSafetyList(data);
    } catch (err) {
      setError('Failed to load safety measures.');
    }
    setLoading(false);
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    setMessage('');
    setError('');

    if (!parameters.trim() || !contentGuidelines.trim() || !createdBy.trim()) {
      setError('All fields are required.');
      return;
    }

    let parsedParams;
    try {
      parsedParams = JSON.parse(parameters);
    } catch {
      setError('Parameters must be valid JSON.');
      return;
    }

    setLoading(true);
    try {
      await saveSafetyMeasure({
        title: contentGuidelines.slice(0, 30),
        description: contentGuidelines,
        parameters: parsedParams,
        createdBy: createdBy.replace('.', '_'),
      });

      setContentGuidelines('');
      setParameters('');
      setCreatedBy('');
      setMessage('Safety measure saved successfully!');
      loadSafetyData();
    } catch (err) {
      setError(err.message);
    }
    setLoading(false);
  };

  // Render parameters in readable form
  const renderParameters = (params) => {
    if (!params || typeof params !== 'object') return null;

    return (
      <ul style={styles.paramList}>
        {Object.entries(params).map(([key, value]) => (
          <li key={key} style={styles.paramItem}>
            <strong>{key}:</strong>{' '}
            {Array.isArray(value)
              ? value.join(', ')
              : typeof value === 'boolean'
              ? value ? 'Yes' : 'No'
              : value}
          </li>
        ))}
      </ul>
    );
  };

  return (
    <div style={styles.container}>
      <h1 style={styles.title}>Create or Edit Safety Measures</h1>

      <form onSubmit={handleSubmit} style={styles.form}>
        <label style={styles.label}>Created By (email)</label>
        <input
          style={styles.input}
          value={createdBy}
          onChange={(e) => setCreatedBy(e.target.value)}
          placeholder="admin@gmail.com"
          disabled={loading}
        />

        <label style={styles.label}>Content Guidelines</label>
        <textarea
          style={styles.textarea}
          value={contentGuidelines}
          onChange={(e) => setContentGuidelines(e.target.value)}
          placeholder="Define content guidelines here..."
          rows={4}
          disabled={loading}
        />

        <label style={styles.label}>Safety Parameters (JSON)</label>
        <textarea
          style={styles.textarea}
          value={parameters}
          onChange={(e) => setParameters(e.target.value)}
          placeholder={`{
  "prohibitedWords": ["badword1"],
  "maxResponseLength": 300,
  "enforcePoliteness": true,
  "flagSuspiciousContent": true
}`}
          rows={8}
          disabled={loading}
        />

        <button type="submit" style={styles.button} disabled={loading}>
          {loading ? 'Saving...' : 'Save Safety Measures'}
        </button>
      </form>

      {message && <p style={styles.success}>{message}</p>}
      {error && <p style={styles.error}>{error}</p>}

      <h2 style={styles.sectionTitle}>Existing Safety Guidelines</h2>
      {safetyList.length === 0 ? (
        <p style={styles.noData}>No safety measures found.</p>
      ) : (
        <ul style={styles.safetyList}>
          {safetyList.map((item) => (
            <li key={item.id} style={styles.safetyItem}>
              <h3 style={styles.safetyTitle}>{item.title}</h3>
              <p style={styles.safetyDescription}>{item.description}</p>
              <div>{renderParameters(item.parameters)}</div>
              <footer style={styles.safetyFooter}>
                By: {item.createdBy.replace('_', '.')} |{' '}
                {new Date(item.createdAt).toLocaleString()}
              </footer>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}

const styles = {
  container: {
    maxWidth: 800,
    margin: '2rem auto',
    padding: '2rem',
    backgroundColor: '#f3f9ff',
    borderRadius: 12,
    boxShadow: '0 8px 20px rgba(0,0,0,0.08)',
    fontFamily: "'Segoe UI', Tahoma, Geneva, Verdana, sans-serif",
  },
  title: {
    fontSize: '2rem',
    fontWeight: '700',
    color: '#003366',
    marginBottom: '1.5rem',
    textAlign: 'center',
  },
  form: {
    display: 'flex',
    flexDirection: 'column',
    gap: '1rem',
    marginBottom: '2rem',
  },
  label: {
    fontWeight: '600',
    fontSize: 15,
    color: '#003366',
  },
  input: {
    padding: '0.75rem',
    borderRadius: 8,
    border: '1.5px solid #ccc',
    fontSize: 15,
  },
  textarea: {
    padding: '0.75rem',
    borderRadius: 8,
    border: '1.5px solid #ccc',
    fontSize: 15,
    fontFamily: "'Segoe UI', Tahoma, Geneva, Verdana, sans-serif",
  },
  button: {
    marginTop: '1rem',
    padding: '0.75rem',
    backgroundColor: '#007BFF',
    color: '#fff',
    border: 'none',
    fontWeight: '700',
    fontSize: 16,
    borderRadius: 8,
    cursor: 'pointer',
  },
  success: {
    color: 'green',
    textAlign: 'center',
    fontWeight: '600',
    marginBottom: '1rem',
  },
  error: {
    color: 'red',
    textAlign: 'center',
    fontWeight: '600',
    marginBottom: '1rem',
  },
  sectionTitle: {
    fontSize: '1.5rem',
    fontWeight: '700',
    marginBottom: '1rem',
    color: '#004080',
  },
  noData: {
    fontStyle: 'italic',
    color: '#666',
  },
  safetyList: {
    listStyle: 'none',
    padding: 0,
  },
  safetyItem: {
    backgroundColor: '#e6f0ff',
    padding: '1rem',
    borderRadius: 10,
    marginBottom: '1rem',
    boxShadow: '0 4px 10px rgba(0,0,0,0.05)',
  },
  safetyTitle: {
    fontSize: 18,
    fontWeight: '700',
    color: '#003366',
  },
  safetyDescription: {
    fontSize: 15,
    color: '#003366',
    marginBottom: 8,
  },
  paramList: {
    paddingLeft: '1.2rem',
    marginBottom: '0.5rem',
  },
  paramItem: {
    fontSize: 14,
    color: '#002244',
    marginBottom: 4,
  },
  safetyFooter: {
    fontSize: 13,
    color: '#555',
    marginTop: 6,
    fontStyle: 'italic',
  },
};

export default SafetyPage;
