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

  setMessages((prev) => [...prev, { sender: 'user', text: msg }]);
  setInput('');
  setIsLoading(true);

  try {
    const selectedLang = localStorage.getItem('selectedLang') || 'en';
    console.log('🌍 Selected Language:', selectedLang);

    // Translate user input → English (if needed)
    let userMsgInEnglish = msg;
    if (selectedLang !== 'en') {
      console.log('🔄 Translating user input to English...');
      userMsgInEnglish = await translateText(msg, 'en', selectedLang);
    }
    console.log('🗣️ User (translated to English):', userMsgInEnglish);

    const lowerMsg = userMsgInEnglish.toLowerCase();

    // Health tip categories
    const categoriesMap = {
      diet: 'nutrition',
      nutrition: 'nutrition',
      exercise: 'exercise',
      sleep: 'general',
      hydration: 'general',
      health: 'general',
      mental: 'mental_health',
      medication: 'medication',
    };

    const detectedCategories = Object.keys(categoriesMap).filter((key) =>
      lowerMsg.includes(key)
    );

    if (detectedCategories.length > 0) {
      // Remove duplicates & map to API categories
      const uniqueCategories = [...new Set(detectedCategories.map((c) => categoriesMap[c]))];

      let combinedReply = '';

      for (const category of uniqueCategories) {
        // Decide endpoint: tips vs recommendations
        const isRecommendation =
          lowerMsg.includes('recommendation') || lowerMsg.includes('recommendations');

        const endpoint = isRecommendation
          ? 'https://gethealthrecommendations-ga4zzowbeq-as.a.run.app'
          : 'https://gethealthtips-ga4zzowbeq-as.a.run.app';

        const body = { userId: userEmail };
        if (!isRecommendation) body.category = category;

        const res = await fetch(endpoint, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(body),
        });

        if (!res.ok) throw new Error(`HTTP error! status: ${res.status}`);
        const data = await res.json();
        const botReplyRaw = data.displayMessage || `Here are your ${category} tips:`;

        combinedReply += `\n\n${botReplyRaw}`;
      }

      let finalReply = combinedReply.trim();
      if (selectedLang !== 'en') {
        console.log('🔄 Translating bot reply to user language...');
        finalReply = await translateText(finalReply, selectedLang, 'en');
      }

      setMessages((prev) => [...prev, { sender: 'bot', text: finalReply }]);
      setIsLoading(false);
      return;
    }

    // Fallback: send to Dialogflow
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

    if (!res.ok) throw new Error(`HTTP error! status: ${res.status}`);
    const data = await res.json();
    console.log('🤖 Dialogflow raw response:', data);

    const botReplyRaw =
      data.reply ||
      data.fulfillmentText ||
      data.queryResult?.fulfillmentText ||
      "Sorry, I didn't understand.";

    let botReply = botReplyRaw;
    if (selectedLang !== 'en') {
      botReply = await translateText(botReplyRaw, selectedLang, 'en');
    }

    setMessages((prev) => [...prev, { sender: 'bot', text: botReply }]);
  } catch (err) {
    console.error('❌ sendMessage error:', err);
    const errorMessage = err.message.includes('Failed to fetch')
      ? 'Network error: Please check your internet connection.'
      : 'Error contacting AI assistant. Please try again.';
    setMessages((prev) => [...prev, { sender: 'bot', text: errorMessage }]);
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