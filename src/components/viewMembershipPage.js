// src/pages/viewMembershipPage.js

import React from 'react';
import './viewMembershipPage.css';
import membershipImage from '../components/images/membership.jpg';

const membershipPlans = [
  {
    id: 1,
    title: "Montly Plan",
    price: "$90 / month",
    features: [
      "You can use 1 month"
    ]
  },
  {
    id: 2,
    title: "Yearly Plan",
    price: "$1080 / 1yr",
    features: [
       "You can use 1 yr Plan"
    ]
  },
  {
    id: 3,
    title: "Long Time Plan",
    price: "$5000 / 5yrs",
    features: [
      "You can use 5 years Plan"
    ]
  }
];

function ViewMembershipPage() {
  return (
    
    <div className="membership">
      <div className="hero-section">
        <img src={membershipImage} alt="Membership"style={{width: '100%', height: "600px"}} />

      </div>
    
      <div className="membership-page">
      <h1>Membership Options</h1>
      <p>Choose a plan that suits your needs. You can upgrade anytime.</p>

      <div className="membership-list">
        {membershipPlans.map(plan => (
          <div className="membership-card" key={plan.id}>
            <h2>{plan.title}</h2>
            <p className="price">{plan.price}</p>
            <ul>
              {plan.features.map((feature, index) => (
                <li key={index}>✓ {feature}</li>
              ))}
            </ul>
            <button className="join-button" disabled>
              Join Now
            </button>
          </div>
        ))}
      </div>
      </div>
    </div>
  );
}

export default ViewMembershipPage;
