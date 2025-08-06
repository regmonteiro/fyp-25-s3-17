import React from 'react';
import { useNavigate } from 'react-router-dom';
import './viewActivitiesPage.css';
import activities1 from '../components/images/activities1.webp';

const activities = [
  {
    id: 1,
    title: 'Morning Stretch Exercises',
    summary: 'Morning Exercises',
  },
  {
    id: 2,
    title: 'Digital Literacy Workshop',
    summary: 'Learn how to use digital devices',
  },
  {
    id: 3,
    title: 'Community Gardening',
    summary: 'Join local gardening groups',
  },
  {
    id: 4,
    title: 'Memory Games',
    summary: 'fun and stimulating memory games.',
  },
  {
    id: 5,
    title: 'Cooking for Health',
    summary: 'Healthy and easy recipes cooking',
  },
];

function ViewActivitiesPage() {
  const navigate = useNavigate();

  const handleActivityClick = (title) => {
    alert(`Please log in or sign up to view full details about "${title}".`);
    navigate('/login');
  };

  return (
    <div className="activities">
      <div className="hero-section">
        <img src={activities1} alt="Activities"style={{width: '100%', height: "600px"}} />

      </div>
    
    <div className="activities-page">
      <h1>Activities on AllCare Platform</h1>
      <p>Explore various activities designed to engage, educate, and empower elderly users.</p>

      <div className="activities-list">
        {activities.map((activity) => (
          <div
            key={activity.id}
            className="activity-card"
            onClick={() => handleActivityClick(activity.title)}
            role="button"
            tabIndex={0}
            onKeyPress={(e) => {
              if (e.key === 'Enter' || e.key === ' ') {
                handleActivityClick(activity.title);
              }
            }}
          >
            <h3>{activity.title}</h3>
            <p>{activity.summary}</p>
            <button
              onClick={(e) => {
                e.stopPropagation();
                handleActivityClick(activity.title);
              }}
              className="details-button"
            >
              View Overview
            </button>
          </div>
        ))}
      </div>
    </div>
    </div>
  );
}

export default ViewActivitiesPage;
