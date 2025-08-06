import React, { useState, useEffect } from 'react';
import './ChatBotPage.css';

function ChatBotPage() {
  const [messages, setMessages] = useState([
    { from: 'bot', text: 'Hi! I am here to help you! Got any questions?' }
  ]);
  const [input, setInput] = useState('');
  const [chatbotLoaded, setChatbotLoaded] = useState(true); 
  const [error, setError] = useState(null);

  useEffect(() => {
    const simulateLoad = setTimeout(() => {
      const fail = false; 
      if (fail) {
        setChatbotLoaded(false);
        setError("Sorry, we couldn't load the chatbot.");
      }
    }, 1000);
    return () => clearTimeout(simulateLoad);
  }, []);

  const quickStartQuestions = [
    "What services do you provide?",
    "How can I book an appointment?",
    "What are your working hours?"
  ];

  const handleSend = () => {
    if (!input.trim()) return;
    const newMessages = [...messages, { from: 'user', text: input }];
    setMessages(newMessages);
    setInput('');


    setTimeout(() => {
      setMessages(prev => [...prev, {
        from: 'bot',
        text: `Thanks for your question: "${input}". We'll get back to you soon.`
      }]);
    }, 1000);
  };

  const handleQuickQuestion = (question) => {
    setInput(question);
    handleSend();
  };

  if (!chatbotLoaded) {
    return (
      <div className="chatbot-container error">
        <p>{error}</p>
        <a href="/qna" className="chatbot-qna-link">Go to Q&A Section</a>
      </div>
    );
  }

  return (
    <div className="chatbot-container">
      <h2 className="chatbot-title">Ask AllCare AI</h2>

      <div className="chatbot-messages">
        {messages.map((msg, idx) => (
          <div key={idx} className={`chatbot-message ${msg.from}`}>
            {msg.text}
          </div>
        ))}
      </div>

      <div className="chatbot-quick-questions">
        {quickStartQuestions.map((q, i) => (
          <button key={i} onClick={() => handleQuickQuestion(q)}>{q}</button>
        ))}
      </div>

      <div className="chatbot-input-area">
        <input
          type="text"
          value={input}
          onChange={(e) => setInput(e.target.value)}
          placeholder="Type your question..."
        />
        <button onClick={handleSend}>Send</button>
      </div>
    </div>
  );
}

export default ChatBotPage;
