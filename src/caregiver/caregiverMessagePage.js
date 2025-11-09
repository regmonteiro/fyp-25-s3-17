import React, { useState, useEffect, useRef } from 'react';
import { Search, Send, Paperclip, Mic, Volume2 } from 'lucide-react';
import { CaregiverMessagingController } from '../controller/careGiverMessageController';
import { useNavigate } from 'react-router-dom';

const normalizeEmail = (email) => email.replace(/\./g, "_");

export default function CaregiverMessagesPage() {
  const [elderlyUsers, setElderlyUsers] = useState([]);
  const [selectedUser, setSelectedUser] = useState(null);
  const [messages, setMessages] = useState([]);
  const [newMessage, setNewMessage] = useState('');
  const [accounts, setAccounts] = useState({});
  const [isLoading, setIsLoading] = useState(true);
  const [isListening, setIsListening] = useState(false);
  const [transcript, setTranscript] = useState('');
  const [currentlyPlaying, setCurrentlyPlaying] = useState(null);
  const [attachedFiles, setAttachedFiles] = useState([]);
  const [isSpeechSupported, setIsSpeechSupported] = useState(true);

  const messagesEndRef = useRef(null);
  const fileInputRef = useRef(null);
  const recognitionRef = useRef(null);
  const navigate = useNavigate();

  const caregiverEmail = localStorage.getItem("userEmail") || localStorage.getItem("loggedInEmail");

  // Initialize speech recognition
  useEffect(() => {
    const SpeechRecognition = window.SpeechRecognition || window.webkitSpeechRecognition;
    if (!SpeechRecognition) {
      setIsSpeechSupported(false);
      console.warn("Speech recognition not supported in this browser");
      return;
    }

    const recognition = new SpeechRecognition();
    recognitionRef.current = recognition;
    recognition.continuous = false;
    recognition.interimResults = true;
    recognition.lang = "en-US";

    recognition.onstart = () => {
      setIsListening(true);
      setTranscript("");
    };

    recognition.onresult = (event) => {
      let finalTranscript = '';
      let interimTranscript = '';
      for (let i = event.resultIndex; i < event.results.length; i++) {
        const t = event.results[i][0].transcript;
        if (event.results[i].isFinal) finalTranscript += t;
        else interimTranscript += t;
      }
      setTranscript(finalTranscript || interimTranscript);
      if (finalTranscript) setNewMessage(finalTranscript);
    };

    recognition.onerror = (event) => {
      console.error("Speech recognition error:", event.error);
      setIsListening(false);
      if (event.error === "not-allowed") alert("Please allow microphone access.");
    };

    recognition.onend = () => setIsListening(false);

    return () => {
      recognition.stop();
      window.speechSynthesis.cancel();
    };
  }, []);

  // Load accounts and elderly users
  useEffect(() => {
    if (!caregiverEmail) {
      setIsLoading(false);
      return;
    }

    const loadData = async () => {
      setIsLoading(true);
      try {
        const accountsData = await CaregiverMessagingController.getAccounts();
        setAccounts(accountsData);
        CaregiverMessagingController.getElderlyForCaregiver(
          caregiverEmail,
          accountsData,
          (elderlies) => {
            setElderlyUsers(elderlies);
            if (elderlies.length > 0) setSelectedUser(elderlies[0]);
            setIsLoading(false);
          }
        );
      } catch (err) {
        console.error('Error loading data:', err);
        setIsLoading(false);
      }
    };
    loadData();
  }, [caregiverEmail]);

  // Load messages for selected user
  useEffect(() => {
    if (!selectedUser || !caregiverEmail || Object.keys(accounts).length === 0) return;
    
    const hasAccess = CaregiverMessagingController.verifyCaregiverAccess(
      caregiverEmail,
      selectedUser.email,
      accounts
    );
    
    if (!hasAccess) {
      console.warn('No access to messages for this elderly user');
      return;
    }

    const unsubscribe = CaregiverMessagingController.getMessages(
      caregiverEmail,
      selectedUser.email,
      setMessages,
      accounts
    );

    // Mark messages as read when opening conversation
    CaregiverMessagingController.markMessagesAsRead(selectedUser.email, caregiverEmail);
    
    return unsubscribe;
  }, [selectedUser, caregiverEmail, accounts]);

  // Auto-scroll to bottom when new messages arrive
  useEffect(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: "smooth" });
  }, [messages]);

  const handleSendMessage = async () => {
    if ((!newMessage.trim() && attachedFiles.length === 0) || !selectedUser || !caregiverEmail) {
      return;
    }

    try {
      const message = {
        fromUser: caregiverEmail,
        toUser: selectedUser.email,
        content: newMessage,
        attachments: attachedFiles.map(file => ({
          name: file.name,
          type: file.type,
          size: file.size,
          url: URL.createObjectURL(file),
        })),
        timestamp: new Date().toISOString()
      };

      await CaregiverMessagingController.sendMessage(message);
      setNewMessage('');
      setAttachedFiles([]);
      setTranscript('');
    } catch (error) {
      console.error('Error sending message:', error);
      alert('Failed to send message. Please try again.');
    }
  };

  const handleKeyPress = (e) => {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      handleSendMessage();
    }
  };

  const isSentByMe = (msg) => {
    return normalizeEmail(msg.fromUser) === normalizeEmail(caregiverEmail);
  };

  const toggleListening = () => {
    if (!isSpeechSupported) {
      alert("Speech recognition not supported in this browser");
      return;
    }
    
    if (isListening) {
      recognitionRef.current.stop();
    } else {
      try {
        recognitionRef.current.start();
      } catch (err) {
        console.error('Speech recognition error:', err);
        alert("Check microphone permissions.");
      }
    }
  };

  const readMessageAloud = (msg) => {
    if (currentlyPlaying === msg.id) {
      window.speechSynthesis.cancel();
      setCurrentlyPlaying(null);
      return;
    }

    let textToRead = '';
    const sender = isSentByMe(msg) ? "You" : selectedUser?.name || "Elderly";

    try {
      if (msg.attachments?.length) {
        textToRead = `Sent ${msg.attachments.length} attachment${msg.attachments.length > 1 ? "s" : ""}`;
      } else {
        textToRead = msg.content;
      }
    } catch {
      textToRead = msg.content;
    }

    setCurrentlyPlaying(msg.id);
    const utterance = new SpeechSynthesisUtterance(`${sender} said: ${textToRead}`);
    utterance.lang = "en-US";
    utterance.rate = 0.9;
    utterance.pitch = 1;
    utterance.volume = 1;
    utterance.onend = () => setCurrentlyPlaying(null);
    utterance.onerror = () => setCurrentlyPlaying(null);
    window.speechSynthesis.speak(utterance);
  };

  const handleFileAttach = (e) => {
    const files = Array.from(e.target.files);
    setAttachedFiles(prev => [...prev, ...files]);
  };

  if (!caregiverEmail) {
    return (
      <div style={{ 
        display: 'flex', 
        justifyContent: 'center', 
        alignItems: 'center', 
        height: '100vh',
        flexDirection: 'column',
        gap: '1rem'
      }}>
        <h2>Please log in to access messages</h2>
        <button 
          onClick={() => navigate('/caregiver/login')}
          style={{
            padding: '0.5rem 1rem',
            backgroundColor: '#3b82f6',
            color: 'white',
            border: 'none',
            borderRadius: '4px',
            cursor: 'pointer'
          }}
        >
          Go to Login
        </button>
      </div>
    );
  }

  if (isLoading) {
    return (
      <div style={{ 
        display: 'flex', 
        justifyContent: 'center', 
        alignItems: 'center', 
        height: '100vh' 
      }}>
        <div>Loading messages...</div>
      </div>
    );
  }

  if (elderlyUsers.length === 0) {
    return (
      <div style={{ 
        display: 'flex', 
        justifyContent: 'center', 
        alignItems: 'center', 
        height: '100vh',
        flexDirection: 'column',
        gap: '1rem'
      }}>
        <h2>No elderly users assigned to you</h2>
        <p>Please contact administrator to get assigned to elderly users.</p>
      </div>
    );
  }

  return (
    <div style={{ display: 'flex', height: '100vh', fontFamily: 'Arial, sans-serif', background: '#f3f4f6'}}>
      {/* Sidebar */}
      <div style={{ width: 360, borderRight: '1px solid #e5e7eb', background: '#ffffff', display: 'flex', flexDirection: 'column' }}>
        <div style={{ padding: '1rem', borderBottom: '1px solid #e5e7eb' }}>
          <h2 style={{ margin: 0, color: '#3b82f6' }}>Messages</h2>
          <div style={{ position: 'relative', marginTop: '0.5rem', width: '90%' }}>
            <Search style={{ position: 'absolute', left: 10, top: '50%', transform: 'translateY(-50%)', color: '#9ca3af' }} />
            <input 
              placeholder="Search elderly users" 
              style={{ 
                width: '100%', 
                paddingLeft: 30, 
                borderRadius: 8, 
                border: '1px solid #e5e7eb', 
                height: 32,
                outline: 'none'
              }} 
            />
          </div>
        </div>
        <div style={{ flex: 1, overflowY: 'auto' }}>
          {elderlyUsers.map(user => (
            <div
              key={user.email}
              style={{
                display: 'flex',
                alignItems: 'center',
                padding: '0.75rem 1rem',
                cursor: 'pointer',
                background: selectedUser?.email === user.email ? '#e0f2fe' : '#fff',
                borderBottom: '1px solid #f1f5f9',
                transition: 'background-color 0.2s ease'
              }}
              onClick={() => setSelectedUser(user)}
            >
              <div style={{
                width: 48, 
                height: 48, 
                borderRadius: '50%',
                background: '#3b82f6', 
                color: 'white',
                display: 'flex', 
                justifyContent: 'center', 
                alignItems: 'center', 
                fontWeight: 'bold',
                fontSize: '14px'
              }}>
                {user.name ? user.name.charAt(0).toUpperCase() : 'E'}
              </div>
              <div style={{ marginLeft: 12, flex: 1 }}>
                <h3 style={{ margin: 0, fontSize: 16, color: '#111827' }}>{user.name}</h3>
              </div>
            </div>
          ))}
        </div>
      </div>

      {/* Chat Area */}
      <div style={{ flex: 1, display: 'flex', flexDirection: 'column' }}>
        {selectedUser && (
          <>
            <div style={{ 
              padding: '1rem 1.5rem', 
              borderBottom: '1px solid #e5e7eb', 
              background: '#ffffff',
              display: 'flex',
              alignItems: 'center',
              gap: '12px'
            }}>
              <div style={{
                width: 40, 
                height: 40, 
                borderRadius: '50%',
                background: '#3b82f6', 
                color: 'white',
                display: 'flex', 
                justifyContent: 'center', 
                alignItems: 'center', 
                fontWeight: 'bold',
                fontSize: '14px'
              }}>
                {selectedUser.name ? selectedUser.name.charAt(0).toUpperCase() : 'E'}
              </div>
              <div>
                <h2 style={{ margin: 0, color: '#3b82f6', fontSize: '18px' }}>{selectedUser.name}</h2>
              </div>
            </div>

            <div style={{ 
              flex: 1, 
              overflowY: 'auto', 
              padding: '1rem', 
              background: '#f9fafb',
              display: 'flex',
              flexDirection: 'column',
              gap: '8px'
            }}>
              {messages.length === 0 ? (
                <div style={{
                  display: 'flex',
                  justifyContent: 'center',
                  alignItems: 'center',
                  height: '100%',
                  color: '#6b7280',
                  flexDirection: 'column',
                  gap: '8px'
                }}>
                  <p>No messages yet. Start a conversation!</p>
                </div>
              ) : (
                messages.map(msg => {
                  const isMe = isSentByMe(msg);
                  return (
                    <div key={msg.id} style={{ 
                      display: 'flex', 
                      justifyContent: isMe ? 'flex-end' : 'flex-start', 
                      marginBottom: 8 
                    }}>
                      <div style={{
                        maxWidth: '70%',
                        padding: '12px 16px',
                        borderRadius: 16,
                        backgroundColor: isMe ? '#3b82f6' : '#e5e7eb',
                        color: isMe ? 'white' : '#111827',
                        display: 'flex',
                        alignItems: 'center',
                        gap: '8px'
                      }}>
                        <span style={{ flex: 1 }}>{msg.content}</span>
                        <Volume2 
                          size={18} 
                          style={{ 
                            cursor: 'pointer', 
                            color: currentlyPlaying === msg.id ? '#f59e0b' : 'inherit',
                            flexShrink: 0
                          }} 
                          onClick={() => readMessageAloud(msg)} 
                        />
                      </div>
                    </div>
                  );
                })
              )}
              <div ref={messagesEndRef}></div>
            </div>

            {/* Message Input */}
            <div style={{ 
              display: 'flex', 
              padding: '1rem', 
              borderTop: '1px solid #e5e7eb', 
              background: '#ffffff', 
              gap: 12,
              alignItems: 'flex-end'
            }}>
              {/* File Attachment */}
              <div style={{ display: 'flex', gap: 8, alignItems: 'center' }}>
                <Paperclip 
                  size={20} 
                  onClick={() => fileInputRef.current?.click()} 
                  style={{ 
                    cursor: 'pointer', 
                    color: '#3b82f6',
                    flexShrink: 0
                  }} 
                />
                <input
                  ref={fileInputRef}
                  type="file"
                  style={{ display: 'none' }}
                  multiple
                  onChange={handleFileAttach}
                />
                {attachedFiles.length > 0 && (
                  <div style={{ 
                    fontSize: '12px', 
                    color: '#6b7280',
                    display: 'flex',
                    alignItems: 'center',
                    gap: '4px'
                  }}>
                    <Paperclip size={12} />
                    {attachedFiles.length} file(s)
                  </div>
                )}
              </div>

              {/* Message Input */}
              <input
                type="text"
                placeholder={isListening ? transcript || "Listening..." : "Type a message..."}
                value={newMessage}
                onChange={(e) => setNewMessage(e.target.value)}
                onKeyPress={handleKeyPress}
                style={{ 
                  flex: 1, 
                  padding: '12px 16px', 
                  borderRadius: 20, 
                  border: '1px solid #e5e7eb',
                  outline: 'none',
                  fontSize: '14px'
                }}
              />

              {/* Voice Message */}
              <Mic 
                size={20} 
                onClick={toggleListening} 
                style={{ 
                  cursor: 'pointer', 
                  color: isListening ? 'red' : '#3b82f6',
                  flexShrink: 0
                }} 
              />

              {/* Send Button */}
              <Send 
                size={20} 
                onClick={handleSendMessage} 
                style={{ 
                  cursor: 'pointer', 
                  color: '#3b82f6',
                  flexShrink: 0
                }} 
              />
            </div>
          </>
        )}
      </div>
    </div>
  );
}