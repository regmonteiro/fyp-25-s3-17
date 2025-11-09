import React, { useState, useEffect, useRef } from 'react';
import AssistantChat from './assistantChat';
import allCareAIIcon from './images/allCareChatbotwithouttext.png';

export default function FloatingAssistant({ userEmail }) {
  const [open, setOpen] = useState(false);
  const [audioEnabled, setAudioEnabled] = useState(true);
  const [isSpeaking, setIsSpeaking] = useState(false);
  const [isListening, setIsListening] = useState(false);
  const [transcript, setTranscript] = useState('');
  const [isSpeechSupported, setIsSpeechSupported] = useState(true);
  const recognitionRef = useRef(null);

  // ✅ Open chat when icon is clicked
  const toggleChat = () => {
    setOpen((prev) => !prev);
  };

  // ✅ Microphone toggle
  const toggleListening = () => {
    if (!isSpeechSupported) {
      alert("Speech recognition not supported in this browser.");
      return;
    }
    if (isListening) recognitionRef.current.stop();
    else recognitionRef.current.start();
  };

  const toggleAudio = () => {
    if (isSpeaking) window.speechSynthesis.cancel();
    setAudioEnabled((prev) => !prev);
  };

  // ✅ Initialize Speech Recognition
  useEffect(() => {
  const SpeechRecognition = window.SpeechRecognition || window.webkitSpeechRecognition;
  if (!SpeechRecognition) {
    setIsSpeechSupported(false);
    return;
  }

  recognitionRef.current = new SpeechRecognition();
  recognitionRef.current.continuous = true;       // ✅ always listening
  recognitionRef.current.interimResults = true;
  recognitionRef.current.lang = 'en-US';

  const startListening = () => {
    try {
      recognitionRef.current.start();
    } catch (e) {
      // Avoid "already started" errors
    }
  };

  recognitionRef.current.onstart = () => {
    setIsListening(true);
    console.log('🎤 Voice recognition ACTIVE');
  };

  recognitionRef.current.onresult = (event) => {
    let finalTranscript = '';
    for (let i = event.resultIndex; i < event.results.length; i++) {
      if (event.results[i].isFinal) {
        finalTranscript += event.results[i][0].transcript.toLowerCase();
      }
    }

    if (finalTranscript) {
      console.log("Heard:", finalTranscript);

      if (
        finalTranscript.includes("open chat") ||
        finalTranscript.includes("open all care") ||
        finalTranscript.includes("hey all care") ||
        finalTranscript.includes("all care chatbot")
      ) {
        setOpen(true);
        speakText("Opening AllCare chat.");
      } else {
        sendMessageToChat(finalTranscript);
      }
    }
  };

  recognitionRef.current.onerror = (e) => {
    console.log('Speech error:', e.error);
    setIsListening(false);
    setTimeout(startListening, 1000); // ✅ restart after error
  };

  recognitionRef.current.onend = () => {
    console.log("Recognition ended, restarting...");
    setIsListening(false);
    setTimeout(startListening, 500); // ✅ auto-restart if stopped
  };

  // ✅ Start listening when component mounts
  startListening();

  return () => {
    recognitionRef.current.stop();
  };
}, []);


  // ✅ Send voice text to AssistantChat
  const sendMessageToChat = (message) => {
    const event = new CustomEvent('assistant-send-message', { detail: message });
    window.dispatchEvent(event);
    if (audioEnabled) speakText(message);
  };

  // ✅ Speech output
  const speakText = (text) => {
    if ('speechSynthesis' in window && audioEnabled) {
      window.speechSynthesis.cancel();
      const utterance = new SpeechSynthesisUtterance(text);
      utterance.lang = 'en-US';
      utterance.rate = 0.9;
      utterance.pitch = 1;
      utterance.onstart = () => setIsSpeaking(true);
      utterance.onend = () => setIsSpeaking(false);
      window.speechSynthesis.speak(utterance);
    }
  };

  return (
    <div style={{ position: 'fixed', right: 20, bottom: 20, zIndex: 999 }}>
      {open ? (
        <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'flex-end' }}>
          <div style={{ marginBottom: 6, display: 'flex', gap: 6 }}>

            {/* Audio Toggle */}
            <button
              onClick={toggleAudio}
              title={audioEnabled ? 'Mute audio' : 'Enable audio'}
              style={{
                padding: '6px',
                borderRadius: '50%',
                border: 'none',
                background: audioEnabled ? '#4ade80' : '#f87171',
                color: 'white',
                cursor: 'pointer',
                width: "60px",
                height: "60px"
              }}
            >
              {audioEnabled ? '🔊' : '🔇'}
            </button>

            {/* Voice Recognition */}
            <button
              onClick={toggleListening}
              title={isListening ? 'Stop Listening' : 'Start Speaking'}
              style={{
                padding: '6px',
                borderRadius: '50%',
                border: 'none',
                background: isListening ? '#f87171' : '#4f46e5',
                color: 'white',
                cursor: 'pointer',
                width: "60px",
                height: "60px"
              }}
            >
              {isListening ? '🎤…' : '🎤'}
            </button>

            {/* Close Chat */}
            <button
              onClick={toggleChat}
              style={{
                padding: '6px',
                borderRadius: '50%',
                border: 'none',
                background: '#f87171',
                color: 'white',
                cursor: 'pointer',
                width: "60px",
                height: "60px"
              }}
              title="Close Chat"
            >
              ❌
            </button>
          </div>

          <div style={{ width: 500, maxHeight: 500 }}>
            <AssistantChat userEmail={userEmail} />
          </div>
        </div>
      ) : (
        <img
          src={allCareAIIcon}
          alt="AllCare Chatbot"
          onClick={() => setOpen(true)}
          style={{
            width: 100,
            height: 100,
            cursor: 'pointer',
            borderRadius: '50%',
            boxShadow: '0 4px 6px rgba(0,0,0,0.2)'
          }}
        />
      )}
    </div>
  );
}
