import React, { useState, useEffect, useRef } from 'react';
import { translateText } from './translate';

export default function AssistantChat({ userEmail }) {
  const [messages, setMessages] = useState([
    { sender: 'bot', text: 'Hello! I am your AI assistant.' }
  ]);
  const [input, setInput] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const inputRef = useRef(null);

  const sendMessage = async (msg) => {
    if (!msg.trim()) return;

    // Display user message immediately
    setMessages((prev) => [...prev, { sender: 'user', text: msg }]);
    setInput('');
    setIsLoading(true);

    try {
      const selectedLang = localStorage.getItem('selectedLang') || 'en';
      console.log('🌍 Selected Language:', selectedLang);

      // 1️⃣ Translate user input → English (if needed)
      let userMsgInEnglish = msg;
      if (selectedLang !== 'en') {
        console.log('🔄 Translating user input to English...');
        userMsgInEnglish = await translateText(msg, 'en', selectedLang);
      }
      console.log('🗣️ User (translated to English):', userMsgInEnglish);

      // 2️⃣ Send to Dialogflow
      console.log('📡 Sending to Dialogflow...');
      const res = await fetch(
        'https://us-central1-elderly-aiassistant.cloudfunctions.net/dialogflowGateway',
        {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            userId: userEmail,
            message: userMsgInEnglish,
          }),
        }
      );

      if (!res.ok) {
        throw new Error(`HTTP error! status: ${res.status}`);
      }

      const data = await res.json();
      console.log('🤖 Dialogflow raw response:', data);

      // 3️⃣ Extract bot reply
      const botReplyRaw = 
        data.reply || 
        data.fulfillmentText || 
        data.queryResult?.fulfillmentText || 
        "Sorry, I didn't understand.";

      console.log('💬 Bot (raw English):', botReplyRaw);

      // 4️⃣ Translate bot reply → user's language (if needed)
      let botReply = botReplyRaw;
      if (selectedLang !== 'en') {
        console.log('🔄 Translating bot reply to user language...');
        botReply = await translateText(botReplyRaw, selectedLang, 'en');
      }
      console.log('🌐 Bot (translated):', botReply);

      // 5️⃣ Show bot reply
      setMessages((prev) => [...prev, { sender: 'bot', text: botReply }]);

    } catch (err) {
      console.error('❌ sendMessage error:', err);
      
      const errorMessage = err.message.includes('Failed to fetch') 
        ? 'Network error: Please check your internet connection.'
        : 'Error contacting AI assistant. Please try again.';
      
      setMessages((prev) => [
        ...prev,
        { sender: 'bot', text: errorMessage },
      ]);
    } finally {
      setIsLoading(false);
    }
  };

  const handleKeyDown = (e) => {
    if (e.key === 'Enter' && !isLoading) {
      sendMessage(input);
    }
  };

  useEffect(() => {
    // Listen for voice input from FloatingAssistant
    const handleVoiceMessage = (e) => {
      const voiceMessage = e.detail;
      setInput(voiceMessage);
      sendMessage(voiceMessage);
      inputRef.current?.focus();
    };

    window.addEventListener('assistant-send-message', handleVoiceMessage);
    return () =>
      window.removeEventListener('assistant-send-message', handleVoiceMessage);
  }, []);

  return (
    <div
      className="assistant-chat"
      style={{
        border: '1px solid #ccc',
        borderRadius: 8,
        padding: 10,
        background: '#f8f9fa',
        maxHeight: 400,
        display: 'flex',
        flexDirection: 'column',
      }}
    >
      <div style={{ flex: 1, overflowY: 'auto', marginBottom: 6 }}>
        {messages.map((msg, idx) => (
          <div
            key={idx}
            style={{
              alignSelf: msg.sender === 'bot' ? 'flex-start' : 'flex-end',
              background: msg.sender === 'bot' ? '#add8e6' : '#87cefa',
              padding: '6px 10px',
              borderRadius: 12,
              marginBottom: 4,
              color: '#000',
              maxWidth: '80%',
              wordWrap: 'break-word',
            }}
          >
            {msg.text}
          </div>
        ))}
        
        {isLoading && (
          <div
            style={{
              alignSelf: 'flex-start',
              background: '#add8e6',
              padding: '6px 10px',
              borderRadius: 12,
              marginBottom: 4,
              color: '#000',
              maxWidth: '80%',
              wordWrap: 'break-word',
              fontStyle: 'italic'
            }}
          >
            AI is thinking...
          </div>
        )}
      </div>

      <div style={{ display: 'flex', gap: 4 }}>
        <input
          ref={inputRef}
          type="text"
          value={input}
          onChange={(e) => setInput(e.target.value)}
          onKeyDown={handleKeyDown}
          placeholder="Type or speak a message..."
          disabled={isLoading}
          style={{
            flex: 1,
            padding: 6,
            borderRadius: 4,
            border: '1px solid #ccc',
          }}
        />
        <button
          onClick={() => sendMessage(input)}
          disabled={isLoading || !input.trim()}
          style={{
            padding: '6px 12px',
            borderRadius: 4,
            border: 'none',
            background: '#4f46e5',
            color: 'white',
          }}
        >
          Send
        </button>
      </div>
    </div>
  );
}