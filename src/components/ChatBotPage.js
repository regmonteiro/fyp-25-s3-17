import React, { useEffect, useState, useRef } from "react";
import Footer from "../footer";
import "./ChatBotPage.css";
import allCareAIIcon from "./images/allCareChatbot.png";

// SVG Icons as React components
const MapIcon = () => (
  <svg className="info-icon" viewBox="0 0 24 24" width="24" height="24">
    <path
      fill="currentColor"
      d="M12 2C8.13 2 5 5.13 5 9c0 5.25 7 13 7 13s7-7.75 7-13c0-3.87-3.13-7-7-7zm0 9.5a2.5 2.5 0 010-5 2.5 2.5 0 010 5z"
    />
  </svg>
);

const PhoneIcon = () => (
  <svg className="info-icon" viewBox="0 0 24 24" width="24" height="24">
    <path
      fill="currentColor"
      d="M20.01 15.38c-1.23 0-2.42-.2-3.53-.56a.977.977 0 00-1.01.24l-1.57 1.97c-2.83-1.35-5.48-3.9-6.89-6.83l1.95-1.66c.27-.28.35-.67.24-1.02-.37-1.11-.56-2.3-.56-3.53 0-.54-.45-.99-.99-.99H4.19C3.65 3 3 3.24 3 3.99 3 13.28 10.73 21 20.01 21c.71 0 .99-.63.99-1.18v-3.45c0-.54-.45-.99-.99-.99z"
    />
  </svg>
);

const EmailIcon = () => (
  <svg className="info-icon" viewBox="0 0 24 24" width="24" height="24">
    <path
      fill="currentColor"
      d="M20 4H4c-1.1 0-1.99.9-1.99 2L2 18c0 1.1.9 2 2 2h16c1.1 0 2-.9 2-2V6c0-1.1-.9-2-2-2zm0 4l-8 5-8-5V6l8 5 8-5v2z"
    />
  </svg>
);

const ClockIcon = () => (
  <svg className="info-icon" viewBox="0 0 24 24" width="24" height="24">
    <path
      fill="currentColor"
      d="M11.99 2C6.47 2 2 6.48 2 12s4.47 10 9.99 10C17.52 22 22 17.52 22 12S17.52 2 11.99 2zM12 20c-4.42 0-8-3.58-8-8s3.58-8 8-8 8 3.58 8 8-3.58 8-8 8zm.5-13H11v6l5.25 3.15.75-1.23-4.5-2.67z"
    />
  </svg>
);

// Audio control icons
const VolumeUpIcon = () => (
  <svg viewBox="0 0 24 24" width="20" height="20" fill="currentColor">
    <path d="M3 9v6h4l5 5V4L7 9H3zm13.5 3c0-1.77-1.02-3.29-2.5-4.03v8.05c1.48-.73 2.5-2.25 2.5-4.02zM14 3.23v2.06c2.89.86 5 3.54 5 6.71s-2.11 5.85-5 6.71v2.06c4.01-.91 7-4.49 7-8.77s-2.99-7.86-7-8.77z"/>
  </svg>
);

const VolumeOffIcon = () => (
  <svg viewBox="0 0 24 24" width="20" height="20" fill="currentColor">
    <path d="M16.5 12c0-1.77-1.02-3.29-2.5-4.03v2.21l2.45 2.45c.03-.2.05-.41.05-.63zm2.5 0c0 .94-.2 1.82-.54 2.64l1.51 1.51C20.63 14.91 21 13.5 21 12c0-4.28-2.99-7.86-7-8.77v2.06c2.89.86 5 3.54 5 6.71zM4.27 3L3 4.27 7.73 9H3v6h4l5 5v-6.73l4.25 4.25c-.67.52-1.42.93-2.25 1.18v2.06c1.38-.31 2.63-.95 3.69-1.81L19.73 21 21 19.73l-9-9L4.27 3zM12 4L9.91 6.09 12 8.18V4z"/>
  </svg>
);

// Microphone icons for speech recognition
const MicIcon = () => (
  <svg viewBox="0 0 24 24" width="24" height="24" fill="currentColor">
    <path d="M12 14c1.66 0 3-1.34 3-3V5c0-1.66-1.34-3-3-3S9 3.34 9 5v6c0 1.66 1.34 3 3 3z"/>
    <path d="M17 11c0 2.76-2.24 5-5 5s-5-2.24-5-5H5c0 3.53 2.61 6.43 6 6.92V21h2v-3.08c3.39-.49 6-3.39 6-6.92h-2z"/>
  </svg>
);

const MicOffIcon = () => (
  <svg viewBox="0 0 24 24" width="24" height="24" fill="currentColor">
    <path d="M19 11h-1.7c0 .74-.16 1.43-.43 2.05l1.23 1.23c.56-.98.9-2.09.9-3.28zm-4.02.17c0-.06.02-.11.02-.17V5c0-1.66-1.34-3-3-3S9 3.34 9 5v.18l5.98 5.99zM4.27 3L3 4.27l6.01 6.01V11c0 1.66 1.33 3 2.99 3 .22 0 .44-.03.65-.08l1.66 1.66c-.71.33-1.5.52-2.31.52-2.76 0-5.3-2.1-5.3-5.1H5c0 3.41 2.72 6.23 6 6.72V21h2v-3.28c.91-.13 1.77-.45 2.54-.9L19.73 21 21 19.73 4.27 3z"/>
  </svg>
);

function ChatBotPage() {
  const [audioEnabled, setAudioEnabled] = useState(true);
  const [isSpeaking, setIsSpeaking] = useState(false);
  const [isListening, setIsListening] = useState(false);
  const [transcript, setTranscript] = useState("");
  const [isSpeechSupported, setIsSpeechSupported] = useState(true);
  const recognitionRef = useRef(null);

  useEffect(() => {
    // Check if speech recognition is supported
    const SpeechRecognition = window.SpeechRecognition || window.webkitSpeechRecognition;
    
    if (!SpeechRecognition) {
      setIsSpeechSupported(false);
      console.warn('Speech recognition not supported in this browser');
    } else {
      // Initialize speech recognition
      recognitionRef.current = new SpeechRecognition();
      recognitionRef.current.continuous = false;
      recognitionRef.current.interimResults = true;
      recognitionRef.current.lang = 'en-US';

      recognitionRef.current.onstart = () => {
        setIsListening(true);
        setTranscript("");
      };

      recognitionRef.current.onresult = (event) => {
        let finalTranscript = '';
        let interimTranscript = '';

        for (let i = event.resultIndex; i < event.results.length; i++) {
          const transcript = event.results[i][0].transcript;
          if (event.results[i].isFinal) {
            finalTranscript += transcript;
          } else {
            interimTranscript += transcript;
          }
        }

        setTranscript(finalTranscript || interimTranscript);

        // If final result, send to chatbot after a short delay
        if (finalTranscript) {
          setTimeout(() => {
            sendMessageToChatBot(finalTranscript);
          }, 500);
        }
      };

      recognitionRef.current.onerror = (event) => {
        console.error('Speech recognition error:', event.error);
        setIsListening(false);
        if (event.error === 'not-allowed') {
          alert('Please allow microphone access to use voice commands.');
        }
      };

      recognitionRef.current.onend = () => {
        setIsListening(false);
      };
    }

    // Load Dialogflow script
    if (!document.querySelector("script[src*='dialogflow-console']")) {
      const script = document.createElement("script");
      script.src = "https://www.gstatic.com/dialogflow-console/fast/messenger/bootstrap.js?v=1";
      script.async = true;
      document.body.appendChild(script);
    }

    // Create the <df-messenger> if it doesn't exist
    if (!document.querySelector("df-messenger")) {
      const dfMessenger = document.createElement("df-messenger");
      dfMessenger.setAttribute("intent", "WELCOME");
      dfMessenger.setAttribute("chat-title", "AllCare Voice Assistant");
      dfMessenger.setAttribute("agent-id", "8e1a3999-53bc-4ecc-b9e8-f3e7fa1dbbfb");
      dfMessenger.setAttribute("language-code", "en");
      dfMessenger.setAttribute("chat-icon", allCareAIIcon);
      dfMessenger.setAttribute("expand", "true");
      document.body.appendChild(dfMessenger);
    }

    // Add speech synthesis for bot responses
    const handleResponseReceived = (event) => {
      if (!audioEnabled) return;
      
      const messages = event.detail?.response?.queryResult?.fulfillmentMessages || [];
      const textToSpeak = messages
        .filter(msg => msg.text?.text?.length)
        .map(msg => msg.text.text[0])
        .join(". ");
        
      if (textToSpeak) {
        speakText(textToSpeak);
      }
    };

    // Add event listener for responses
    const messengerEl = document.querySelector("df-messenger");
    if (messengerEl) {
      messengerEl.addEventListener("df-response-received", handleResponseReceived);
    }

    // Cleanup
    return () => {
      const widget = document.querySelector("df-messenger");
      if (widget) {
        widget.removeEventListener("df-response-received", handleResponseReceived);
        widget.remove();
      }
      
      if (recognitionRef.current) {
        recognitionRef.current.stop();
      }
      
      if ('speechSynthesis' in window) {
        window.speechSynthesis.cancel();
      }
    };
  }, [audioEnabled]);

  // Function to speak text
  const speakText = (text) => {
    if ('speechSynthesis' in window && audioEnabled) {
      window.speechSynthesis.cancel();
      
      const utterance = new SpeechSynthesisUtterance(text);
      utterance.lang = "en-US";
      utterance.rate = 0.9;
      utterance.pitch = 1;
      utterance.volume = 1;
      
      utterance.onstart = () => setIsSpeaking(true);
      utterance.onend = () => setIsSpeaking(false);
      utterance.onerror = () => setIsSpeaking(false);
      
      window.speechSynthesis.speak(utterance);
    }
  };

 const sendMessageToChatBot = (message) => {
  const dfMessenger = document.querySelector("df-messenger");
  if (!dfMessenger || !dfMessenger.shadowRoot) {
    console.error("df-messenger or its shadowRoot not found");
    return;
  }

  // Get the chat UI
  const chatEl = dfMessenger.shadowRoot.querySelector("df-messenger-chat");
  if (!chatEl || !chatEl.shadowRoot) {
    console.error("df-messenger-chat not found");
    return;
  }

  // Get the user input container
  const userInputEl = chatEl.shadowRoot.querySelector("df-messenger-user-input");
  if (!userInputEl || !userInputEl.shadowRoot) {
    console.error("df-messenger-user-input not found");
    return;
  }

  // Finally get input and button
  const inputField = userInputEl.shadowRoot.querySelector("input");
  const sendBtn = userInputEl.shadowRoot.querySelector("button");

  if (inputField && sendBtn) {
    inputField.value = message;

    // Dispatch input event so df-messenger knows value changed
    inputField.dispatchEvent(new Event("input", { bubbles: true }));

    // Auto click send
    setTimeout(() => sendBtn.click(), 200);

    console.log("Message injected:", message);
  } else {
    console.error("Could not find input or send button inside df-messenger-user-input");
  }
};


// Fallback: just logs message (can be extended with Dialogflow API)
const fallbackSendMessage = (message) => {
  console.warn("Fallback triggered. Implement Dialogflow API to send:", message);
};

  // Alternative API approach if shadow DOM access fails
  const sendMessageViaAPI = async (message) => {
    // You would need to implement Dialogflow API integration here
    console.log('Sending message via API:', message);
  };

  // Toggle speech recognition
  const toggleListening = () => {
    if (!isSpeechSupported) {
      alert("Speech recognition is not supported in your browser. Please use Chrome, Edge, or Safari.");
      return;
    }

    if (isListening) {
      recognitionRef.current.stop();
    } else {
      setTranscript("");
      try {
        recognitionRef.current.start();
      } catch (error) {
        console.error('Error starting speech recognition:', error);
        alert('Error accessing microphone. Please check permissions.');
      }
    }
  };

  const toggleAudio = () => {
    if (isSpeaking) {
      window.speechSynthesis.cancel();
      setIsSpeaking(false);
    }
    setAudioEnabled(!audioEnabled);
  };

  return (
    <div className="chatbot-page" style={{marginTop: '-40px'}}>
      {/* Voice Control Buttons */}
      <div className="voice-controls">
        <button 
          onClick={toggleAudio}
          className={`audio-toggle ${isSpeaking ? 'speaking' : ''}`}
          aria-label={audioEnabled ? "Mute audio" : "Enable audio"}
          title={audioEnabled ? "Mute audio" : "Enable audio"}
        >
          {audioEnabled ? <VolumeUpIcon /> : <VolumeOffIcon />}
        </button>
        
        <button 
          onClick={toggleListening}
          className={`mic-toggle ${isListening ? 'listening' : ''} ${!audioEnabled ? 'disabled' : ''}`}
          aria-label={isListening ? "Stop listening" : "Start speaking"}
          title={isListening ? "Stop listening" : "Start speaking"}
          disabled={!audioEnabled}
        >
          {isListening ? <MicOffIcon /> : <MicIcon />}
        </button>
      </div>

      {/* Speech Recognition Feedback */}
      {isListening && (
        <div className="speech-feedback">
          <div className="listening-indicator">
            <span>Listening... Speak now</span>
            <div className="pulse-animation"></div>
          </div>
          {transcript && (
            <div className="transcript-container">
              <p className="transcript-label">You said:</p>
              <p className="transcript">"{transcript}"</p>
            </div>
          )}
        </div>
      )}
      
      {/* Main Banner */}
      <div className="animated-banner">
        <div className="banner-content">
          <h1 className="banner-title">AllCare ChatBot</h1>
          <p className="banner-subtitle">Talk naturally and get instant help</p>
          <div className="ai-icon">
            <img src={allCareAIIcon} alt="AllCare AI Icon" />
          </div>
        </div>
      </div>

      {/* Voice Instructions */}
      <div className="voice-instructions">
        <div className="instructions-content">
          <h3>🎯 Voice Commands Guide</h3>
          <p>Click the microphone icon and try saying:</p>
          <ul>
            <li>"Hello, I need help with..."</li>
            <li>"What are your opening hours?"</li>
            <li>"Tell me about your services"</li>
            <li>"How can I make an appointment?"</li>
          </ul>
          {!isSpeechSupported && (
            <div className="browser-warning">
              ⚠️ Voice features work best in Chrome, Edge, or Safari
            </div>
          )}
        </div>
      </div>


      {/* Contact Section */}
      <div className="contact-section">
        <h2 className="contact-title">Get in Touch</h2>
        <p className="contact-subtitle">
          We're here to help and answer any questions you might have
        </p>

        <div className="contact-content">
          <div className="contact-info">
            <div className="info-item">
              <div className="info-icon-container">
                <MapIcon />
              </div>
              <div className="info-details">
                <h3>Visit Us</h3>
                <p>
                  461 Clementi Rd,
                  <br />
                  Singapore 599491
                </p>
              </div>
            </div>

            <div className="info-item">
              <div className="info-icon-container">
                <PhoneIcon />
              </div>
              <div className="info-details">
                <h3>Call Us</h3>
                <p>
                  (+65) 123-4567
                  <br />
                  Mon-Fri: 8am-6pm
                </p>
              </div>
            </div>

            <div className="info-item">
              <div className="info-icon-container">
                <EmailIcon />
              </div>
              <div className="info-details">
                <h3>Email Us</h3>
                <p>
                  info@allcarecenter.org
                  <br />
                  support@allcare.com
                </p>
              </div>
            </div>

            <div className="info-item">
              <div className="info-icon-container">
                <ClockIcon />
              </div>
              <div className="info-details">
                <h3>Opening Hours</h3>
                <p>
                  Monday-Friday: 8am to 6pm
                  <br />
                  Saturday: 9am to 4pm
                  <br />
                  Sunday: Closed
                </p>
              </div>
            </div>
          </div>
        </div>
      </div>

      <Footer />
    </div>
  );
}

export default ChatBotPage;
