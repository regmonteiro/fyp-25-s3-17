// src/components/viewQNAPage.js

import React, { useState } from 'react';
import "./viewQNAPage.css";
import Footer from '../footer';
const qnaList = [
  {
    id: 1,
    question: "What is the AllCare platform?",
    answer: "AllCare is a digital platform designed to support older adults by offering AI-powered assistance, activity recommendations and social connectivity."
  },
  {
    id: 2,
    question: "How AllCare Platform work?",
    answer: "The platform uses AI to learn your preferences and habits, providing personalized suggestions and reminders to enhance your daily life."
  },
  {
    id: 3,
    question: "What can the personal AI assistant do?",
    answer: "The AI assistant can remember your preferences, help you schedule events, suggest activities, and assist with daily reminders."
  },
  {
    id: 4,
    question: "Is this platform safe and private?",
    answer: "Yes. This follow strict data privacy standards to ensure your information is secure and confidential."
  },
  {
    id: 5,
    question: "Can I connect with other users?",
    answer: "You can share experiences, find local social activities, and join community chats designed for older adults."
  },
  {
    id: 6,
    question: "What are the available membership plans?",
    answer: "We offer Free trial, Monthly Care, Annual Wellness and 3-Year plans, each with different features and benefits."
  },
  {
    id: 7,
    question: "How much you need to pay for additional caregivers?",
    answer: "Each additional caregiver costs $25 per month."
  }
];

function ViewQNAPage() {
  const [expandedId, setExpandedId] = useState(null);

  const toggleAnswer = (id) => {
    setExpandedId(prevId => (prevId === id ? null : id));
  };

  return (
    <div>
    <div className="qna-page">
      <h1>Frequently Asked Questions (QNA)</h1>
      <p>Find answers to common questions about the AllCare platform.</p>

      <div className="qna-list">
        {qnaList.map((qna) => (
          <div className="qna-card" key={qna.id}>
            <button
              className="qna-question"
              onClick={() => toggleAnswer(qna.id)}
              aria-expanded={expandedId === qna.id}
              aria-controls={`answer-${qna.id}`}
            >
              {qna.question}
            </button>
            {expandedId === qna.id && (
              <div id={`answer-${qna.id}`} className="qna-answer">
                {qna.answer}
              </div>
            )}
          </div>
        ))}
      </div>
    </div>
      <Footer />  
    </div>
  );
}

export default ViewQNAPage;
