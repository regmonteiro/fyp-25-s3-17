import React, { useState, useEffect } from 'react';
import { ref, onValue } from 'firebase/database';
import { database } from '../firebaseConfig';

const FeedbackPage = () => {
  const [feedbacks, setFeedbacks] = useState([]);
  const [loading, setLoading] = useState(true);
  const [showAll, setShowAll] = useState(false);
  const [randomFeedbacks, setRandomFeedbacks] = useState([]);

  useEffect(() => {
    const feedbackRef = ref(database, 'feedback');
    const unsubscribe = onValue(
      feedbackRef,
      (snapshot) => {
        const data = snapshot.val();
        if (data) {
          const feedbackArray = Object.values(data);
          feedbackArray.sort((a, b) => new Date(b.date) - new Date(a.date));
          setFeedbacks(feedbackArray);
          setLoading(false);
          setRandomFeedbacks(pickRandom(feedbackArray, 5));
        } else {
          setFeedbacks([]);
          setRandomFeedbacks([]);
          setLoading(false);
        }
      },
      (error) => {
        console.error('Failed to read feedback:', error);
        setFeedbacks([]);
        setRandomFeedbacks([]);
        setLoading(false);
      }
    );

    return () => unsubscribe();
  }, []);

  function pickRandom(arr, n) {
    if (arr.length <= n) return arr;
    const result = [];
    const taken = new Set();
    while (result.length < n) {
      const index = Math.floor(Math.random() * arr.length);
      if (!taken.has(index)) {
        taken.add(index);
        result.push(arr[index]);
      }
    }
    return result;
  }

  if (loading) return <p style={styles.loading}>Loading feedback...</p>;
  if (feedbacks.length === 0) return <p style={styles.noFeedback}>No feedback available.</p>;

  const visibleFeedbacks = showAll ? feedbacks : randomFeedbacks;

  // Extract initials from email for avatar
  const getInitials = (email) => {
    if (!email) return '?';
    const namePart = email.split('@')[0];
    const parts = namePart.split(/[.\-_]/).filter(Boolean);
    if (parts.length === 0) return email[0].toUpperCase();
    if (parts.length === 1) return parts[0][0].toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  };

  return (
    <main style={styles.container}>
      <h2 style={styles.title}>User Feedback</h2>
      <ul style={styles.list}>
        {visibleFeedbacks.map((fb, idx) => (
          <li key={idx} style={styles.card} tabIndex={0} aria-label={`Feedback from ${fb.userEmail}`}>
            <div style={styles.avatar}>{getInitials(fb.userEmail)}</div>
            <div style={styles.content}>
              <header style={styles.header}>
                <p style={styles.email}>{fb.userEmail}</p>
                <time style={styles.date} dateTime={fb.date}>
                  {new Date(fb.date).toLocaleDateString()}
                </time>
              </header>
              <p style={styles.comment}>{fb.comment}</p>
              <div style={styles.rating}>⭐ {fb.rating} / 5</div>
            </div>
          </li>
        ))}
      </ul>
      {feedbacks.length > 5 && (
        <button
          style={styles.button}
          onClick={() => setShowAll(!showAll)}
          aria-expanded={showAll}
          aria-label="Toggle view more feedbacks"
          onMouseEnter={(e) =>
            (e.currentTarget.style.background = 'linear-gradient(45deg, #2691f5, #81c0fb)')
          }
          onMouseLeave={(e) =>
            (e.currentTarget.style.background = 'linear-gradient(45deg, #81c0fb, #2691f5)')
          }
        >
          {showAll ? 'Show Less' : 'Show More'}
        </button>
      )}
    </main>
  );
};

const styles = {
  container: {
    maxWidth: '900px',
    margin: '50px auto',
    padding: '0 15px 60px',
    fontFamily: "'Segoe UI', Tahoma, Geneva, Verdana, sans-serif",
    backgroundColor: '#fff',
    borderRadius: '18px',
    boxShadow: '0 8px 25px rgba(0,0,0,0.08)',
  },
  title: {
    fontWeight: '900',
    fontSize: '2.4rem',
    textAlign: 'center',
    margin: '40px 0 50px',
    color: '#222',
    letterSpacing: '1.1px',
  },
  list: {
    listStyle: 'none',
    margin: 0,
    padding: 0,
  },
  card: {
    display: 'flex',
    alignItems: 'flex-start',
    gap: '20px',
    padding: '22px 25px',
    borderBottom: '1px solid #eee',
    transition: 'background-color 0.2s ease',
    cursor: 'default',
    outline: 'none',
  },
  avatar: {
    flexShrink: 0,
    width: '55px',
    height: '55px',
    borderRadius: '50%',
    background: 'linear-gradient(45deg, #81c0fb, #2691f5)', // avatar gradient
    color: '#fff',
    fontWeight: '800',
    fontSize: '1.5rem',
    lineHeight: '55px',
    textAlign: 'center',
    userSelect: 'none',
  },
  content: {
    flex: 1,
  },
  header: {
    display: 'flex',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: '10px',
  },
  email: {
    fontWeight: '700',
    fontSize: '1.1rem',
    color: '#333',
    margin: 0,
  },
  date: {
    fontSize: '0.85rem',
    color: '#888',
    fontWeight: '500',
  },
  comment: {
    fontSize: '1rem',
    color: '#555',
    marginBottom: '12px',
    lineHeight: 1.5,
  },
  rating: {
    fontWeight: '700',
    fontSize: '1.05rem',
    color: '#2691f5', // rating color aligned with gradient blue
  },
  button: {
    display: 'block',
    margin: '40px auto 0',
    padding: '14px 36px',
    fontSize: '1.2rem',
    fontWeight: '700',
    color: '#fff',
    background: 'linear-gradient(45deg, #81c0fb, #2691f5)', // same gradient as avatar
    border: 'none',
    borderRadius: '35px',
    cursor: 'pointer',
    boxShadow: '0 8px 22px rgba(38, 145, 245, 0.5)',
    userSelect: 'none',
    transition: 'background 0.3s ease',
  },

  // Responsive tweaks
  '@media (max-width: 600px)': {
    container: {
      margin: '30px 10px',
      padding: '0 12px 40px',
    },
    card: {
      flexDirection: 'column',
      alignItems: 'flex-start',
      gap: '15px',
      padding: '18px 20px',
    },
    avatar: {
      width: '50px',
      height: '50px',
      fontSize: '1.3rem',
      lineHeight: '50px',
    },
    button: {
      padding: '12px 30px',
      fontSize: '1.1rem',
    },
  },
};

export default FeedbackPage;
