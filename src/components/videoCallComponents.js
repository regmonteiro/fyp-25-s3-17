// src/components/VideoCallComponents.js
import React, { useState, useEffect, useRef } from 'react';
import './VideoCallComponents.css';

// Video Call Modal Component
export const VideoCallModal = ({ isOpen, onClose, consultation, userType, onCallEnd }) => {
  const [callType, setCallType] = useState('video'); // 'video' or 'audio'
  const [callStatus, setCallStatus] = useState('connecting'); // 'connecting', 'active', 'ended'
  const [localStream, setLocalStream] = useState(null);
  const [remoteStream, setRemoteStream] = useState(null);
  const [callDuration, setCallDuration] = useState(0);
  const localVideoRef = useRef(null);
  const remoteVideoRef = useRef(null);
  const peerConnection = useRef(null);
  const callTimerRef = useRef(null);

  // Simulated WebRTC configuration (replace with your actual signaling server)
  const configuration = {
    iceServers: [
      { urls: 'stun:stun.l.google.com:19302' }
    ]
  };

  useEffect(() => {
    if (isOpen) {
      initializeCall();
    } else {
      cleanupCall();
    }

    return () => {
      cleanupCall();
    };
  }, [isOpen]);

  const initializeCall = async () => {
    try {
      setCallStatus('connecting');
      
      // Get user media
      const stream = await navigator.mediaDevices.getUserMedia({
        video: callType === 'video',
        audio: true
      });
      
      setLocalStream(stream);
      if (localVideoRef.current) {
        localVideoRef.current.srcObject = stream;
      }

      // Initialize peer connection (simplified - in real app, you'd have signaling)
      peerConnection.current = new RTCPeerConnection(configuration);
      
      // Add local stream to connection
      stream.getTracks().forEach(track => {
        peerConnection.current.addTrack(track, stream);
      });

      // Handle remote stream
      peerConnection.current.ontrack = (event) => {
        const remoteStream = event.streams[0];
        setRemoteStream(remoteStream);
        if (remoteVideoRef.current) {
          remoteVideoRef.current.srcObject = remoteStream;
        }
      };

      // Simulate connection success
      setTimeout(() => {
        setCallStatus('active');
        startCallTimer();
        
        // Simulate receiving remote stream after 2 seconds
        setTimeout(() => {
          // In real implementation, this would come from the other peer
          setRemoteStream(new MediaStream()); // Placeholder
        }, 2000);
      }, 1500);

    } catch (error) {
      console.error('Error initializing call:', error);
      alert('Failed to start call. Please check your camera and microphone permissions.');
      onClose();
    }
  };

  const startCallTimer = () => {
    callTimerRef.current = setInterval(() => {
      setCallDuration(prev => prev + 1);
    }, 1000);
  };

  const cleanupCall = () => {
    if (localStream) {
      localStream.getTracks().forEach(track => track.stop());
    }
    if (peerConnection.current) {
      peerConnection.current.close();
    }
    if (callTimerRef.current) {
      clearInterval(callTimerRef.current);
    }
  };

  const handleEndCall = () => {
    setCallStatus('ended');
    cleanupCall();
    if (onCallEnd) {
      onCallEnd({
        duration: callDuration,
        consultationId: consultation?.id,
        type: callType
      });
    }
    setTimeout(() => {
      onClose();
    }, 2000);
  };

  const toggleVideo = () => {
    if (localStream) {
      const videoTrack = localStream.getVideoTracks()[0];
      if (videoTrack) {
        videoTrack.enabled = !videoTrack.enabled;
      }
    }
  };

  const toggleAudio = () => {
    if (localStream) {
      const audioTrack = localStream.getAudioTracks()[0];
      if (audioTrack) {
        audioTrack.enabled = !audioTrack.enabled;
      }
    }
  };

  const switchToAudio = () => {
    if (callStatus === 'active') {
      setCallType('audio');
      if (localStream) {
        const videoTrack = localStream.getVideoTracks()[0];
        if (videoTrack) {
          videoTrack.stop();
        }
      }
    }
  };

  const formatDuration = (seconds) => {
    const mins = Math.floor(seconds / 60);
    const secs = seconds % 60;
    return `${mins.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`;
  };

  if (!isOpen) return null;

  return (
    <div className="video-call-modal-overlay">
      <div className="video-call-container">
        {/* Remote Video Stream */}
        <div className="remote-video-container">
          {remoteStream ? (
            <video
              ref={remoteVideoRef}
              autoPlay
              playsInline
              className="remote-video"
              muted={false}
            />
          ) : (
            <div className="remote-video-placeholder">
              <div className="placeholder-avatar">
                {consultation?.elderlyName?.charAt(0) || 'U'}
              </div>
              <p>{callStatus === 'connecting' ? 'Connecting...' : 'Waiting for participant...'}</p>
            </div>
          )}
        </div>

        {/* Local Video Stream */}
        {callType === 'video' && localStream && (
          <div className="local-video-container">
            <video
              ref={localVideoRef}
              autoPlay
              playsInline
              className="local-video"
              muted
            />
          </div>
        )}

        {/* Call Info Bar */}
        <div className="call-info-bar">
          <div className="call-info-left">
            <span className="call-type-badge">
              {callType === 'video' ? '📹 Video Call' : '📞 Audio Call'}
            </span>
            <span className="call-duration">
              {callStatus === 'active' ? formatDuration(callDuration) : '00:00'}
            </span>
          </div>
          <div className="call-info-right">
            <span className="call-status">{callStatus.toUpperCase()}</span>
          </div>
        </div>

        {/* Call Controls */}
        <div className="call-controls">
          {/* Audio Toggle */}
          <button
            className="control-btn audio-toggle"
            onClick={toggleAudio}
            title="Toggle Microphone"
          >
            🎤
          </button>

          {/* Video Toggle - Only in video calls */}
          {callType === 'video' && (
            <button
              className="control-btn video-toggle"
              onClick={toggleVideo}
              title="Toggle Camera"
            >
              📹
            </button>
          )}

          {/* Switch to Audio - Only in video calls */}
          {callType === 'video' && (
            <button
              className="control-btn switch-audio"
              onClick={switchToAudio}
              title="Switch to Audio Only"
            >
              📞
            </button>
          )}

          {/* End Call Button */}
          <button
            className="control-btn end-call"
            onClick={handleEndCall}
            title="End Call"
          >
            📞
          </button>
        </div>

        {/* Participant Info */}
        <div className="participant-info">
          <h3>
            {userType === 'elderly' 
              ? `Call with Caregiver` 
              : `Call with ${consultation?.elderlyName || 'Elderly'}`}
          </h3>
          <p>Consultation: {consultation?.reason || 'General Checkup'}</p>
        </div>
      </div>
    </div>
  );
};

// Call Initiation Component
export const CallInitiationModal = ({ isOpen, onClose, consultation, onCallStart }) => {
  const [callType, setCallType] = useState('video');

  if (!isOpen) return null;

  const handleStartCall = () => {
    onCallStart(callType);
    onClose();
  };

  return (
    <div className="modal-overlay">
      <div className="modal-content call-initiation-modal">
        <div className="modal-header">
          <h3>Start Consultation Call</h3>
          <button className="close-btn" onClick={onClose}>×</button>
        </div>
        
        <div className="modal-body">
          <div className="consultation-info">
            <h4>Consultation Details</h4>
            <div className="consultation-detail-item">
              <span className="detail-label">Patient:</span>
              <span className="detail-value">{consultation?.elderlyName || 'Elderly User'}</span>
            </div>
            <div className="consultation-detail-item">
              <span className="detail-label">Reason:</span>
              <span className="detail-value">{consultation?.reason || 'General Checkup'}</span>
            </div>
          </div>

          <div className="call-type-selection">
            <h4>Select Call Type</h4>
            <div className="call-type-options">
              <div 
                className={`call-type-option ${callType === 'video' ? 'selected' : ''}`}
                onClick={() => setCallType('video')}
              >
                <div className="option-icon">📹</div>
                <div className="option-content">
                  <h5>Video Call</h5>
                  <p>Face-to-face consultation with video</p>
                </div>
                <div className="option-check">✓</div>
              </div>

              <div 
                className={`call-type-option ${callType === 'audio' ? 'selected' : ''}`}
                onClick={() => setCallType('audio')}
              >
                <div className="option-icon">📞</div>
                <div className="option-content">
                  <h5>Voice Call</h5>
                  <p>Audio-only consultation</p>
                </div>
                <div className="option-check">✓</div>
              </div>
            </div>
          </div>

          <div className="call-features">
            <h4>Call Features</h4>
            <ul>
              <li>🔒 Secure encrypted connection</li>
              <li>🎤 Real-time audio communication</li>
              {callType === 'video' && <li>📹 High-quality video streaming</li>}
              <li>⏱️ Call duration tracking</li>
              <li>💾 Automatic call logging</li>
            </ul>
          </div>
        </div>

        <div className="modal-actions">
          <button className="btn-secondary" onClick={onClose}>
            Cancel
          </button>
          <button className="btn-primary" onClick={handleStartCall}>
            Start {callType === 'video' ? 'Video' : 'Voice'} Call
          </button>
        </div>
      </div>
    </div>
  );
};