import './App.css';
import homepage1 from "./homepage1.jpg";
import { useState, useEffect, useRef } from 'react';
import { database, ref, push } from './firebaseConfig';
import howitworks from "./seniorcare.jpg"; 
import Footer from './footer';
import FeedbackSection from "./feedbackSection";
import AllCareVideo from './assets/AllCare.mp4';

// App version declaration
const APP_VERSION = "1.2.5";

// New Animated Introduction Section Component
const IntroductionSection = () => {
  const [displayedText, setDisplayedText] = useState('');
  const [currentLine, setCurrentLine] = useState(0);
  const [isDeleting, setIsDeleting] = useState(false);
  const [isTypingPaused, setIsTypingPaused] = useState(false);
  
  const lines = [
    "Many tools are made for schedules,",
    "reminders, and checklists. That's not us.",
    "",
    "AllCare is here to nurture connections,",
    "preserve legacies, honor stories,",
    "and celebrate life in all its seasons."
  ];

  useEffect(() => {
    let timer;
    
    const handleTyping = () => {
      if (isTypingPaused) return;
      
      const currentLineText = lines[currentLine];
      
      if (isDeleting) {
        // Backspace effect
        if (displayedText.length > 0) {
          setDisplayedText(currentLineText.substring(0, displayedText.length - 1));
        } else {
          setIsDeleting(false);
          setCurrentLine((prev) => (prev + 1) % lines.length);
        }
      } else {
        // Typing effect
        if (displayedText.length < currentLineText.length) {
          setDisplayedText(currentLineText.substring(0, displayedText.length + 1));
        } else {
          // Pause at the end of line before moving to next
          if (currentLine === lines.length - 1) {
            setIsTypingPaused(true);
            timer = setTimeout(() => {
              setIsDeleting(true);
              setIsTypingPaused(false);
            }, 3000);
          } else {
            setIsTypingPaused(true);
            timer = setTimeout(() => {
              setCurrentLine((prev) => prev + 1);
              setDisplayedText('');
              setIsTypingPaused(false);
            }, 1000);
          }
        }
      }
    };

    const typingSpeed = isDeleting ? 50 : 100;
    timer = setTimeout(handleTyping, typingSpeed);
    
    return () => {
      if (timer) {
        clearTimeout(timer);
      }
    };
  }, [displayedText, isDeleting, currentLine, isTypingPaused, lines]);

  return (
    <section className="introduction-section">
      <div className="introduction-container">
        <div className="introduction-content">
          <div className="text-animation-container">
            <h2 className="introduction-heading">
              <span className="typed-text">{displayedText}</span>
              <span className="cursor">|</span>
            </h2>
          </div>
          <div className="button-container">
            <button 
              className="cta-button primary"
              onClick={() => window.location.href = "/ChatBotPage"}
            >
              Speak with Our Care
            </button>
            <button 
              className="cta-button secondary"
              onClick={() => {
                const element = document.querySelector('.how-it-works');
                if (element) {
                  element.scrollIntoView({ behavior: 'smooth' });
                }
              }}
            >
              How It Works
            </button>
          </div>
        </div>
      </div>
    </section>
  );
};

// Collaboration Section Component
const CollaborationSection = () => {
  return (
    <section className="collaboration-section">
      <div className="wave-border">
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1200 120" preserveAspectRatio="none">
          <path d="M985.66,92.83C906.67,72,823.78,31,743.84,14.19c-82.26-17.34-168.06-16.33-250.45.39-57.84,11.73-114,31.07-172,41.86A600.21,600.21,0,0,1,0,27.35V120H1200V95.8C1132.19,118.92,1055.71,111.31,985.66,92.83Z" className="shape-fill"></path>
        </svg>
      </div>
      
      <div className="collaboration-container">
        <div className="collaboration-content">
          <div className="text-content">
            <h2 className="collaboration-heading">
              That's us, collaborating!
            </h2>
            <p className="collaboration-subtitle">
              One platform for care, communication, and peace of mind
            </p>
            <p className="collaboration-description">
              Your complex network of caregivers, family chats, medical updates, and scheduling tools isn't providing the seamless care experience your loved one deserves. (And to be honest, it's probably adding to your stress.) Streamline the way you coordinate care, share updates, and manage wellbeing with AllCare.
            </p>
          </div>
          
          <div className="app-promo-container">
            <div className="app-promo-card">
              <div className="floating-elements">
                <div className="floating-circle circle-1"></div>
                <div className="floating-circle circle-2"></div>
              </div>
        
              <div className="content-section">
                <div className="app-header">
                  <div className="app-icon-wrapper">
                    <div className="app-icon image-icon"></div>
                  </div>
                  <div className="app-info">
                    <h3>AllCare App</h3>
                    <p>v1.1.0</p>
                  </div>
                </div>
                
                <h1 className="main-title">All your care in one place</h1>
                
                <div className="app-description">
                  <p>Download our app to manage care on the go, receive notifications, and stay connected with your care team.</p>
                </div>

                <ul className="features-list">
                  <li>Easy one-touch login with single use verification codes</li>
                  <li>Secure document storage and sharing</li>
                  <li>Real-time notifications and updates</li>
                  <li>24/7 access to your care information</li>
                </ul>
                
                <div className="download-buttons">
                  <button className="download-btn app-store">
                    <span>Download on the</span>
                    <span>App Store</span>
                  </button>
                  <button className="download-btn google-play">
                    <span>GET IT ON</span>
                    <span>Google Play</span>
                  </button>
                </div>
              </div>

              <div className="phone-mockup">
                <div className="phone">
                  <div className="phone-screen">
                    <div className="status-bar">
                      <span>9:41</span>
                      <span>●●●●○</span>
                    </div>
                    <div className="app-content">
                      <h4>AllCare Dashboard</h4>
                      <p>Your complete care management solution in one convenient app</p>
                      <button className="mock-button">Get Started</button>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
};

// Marketing Video Section Component
const MarketingVideoSection = () => {
  const [isVisible, setIsVisible] = useState(false);
  const [isVideoPlaying, setIsVideoPlaying] = useState(false);
  const videoRef = useRef(null);
  const sectionRef = useRef(null);

  useEffect(() => {
    const observer = new IntersectionObserver(
      ([entry]) => {
        if (entry.isIntersecting) {
          setIsVisible(true);
        }
      },
      { threshold: 0.1 }
    );

    if (sectionRef.current) {
      observer.observe(sectionRef.current);
    }

    return () => observer.disconnect();
  }, []);

  const handlePlayVideo = () => {
    if (videoRef.current) {
      videoRef.current.play().catch(error => {
        console.log("Video play failed:", error);
      });
      setIsVideoPlaying(true);
    }
  };

  return (
    <section 
  ref={sectionRef} 
  style={{
    padding: "80px 20px",
    background: "linear-gradient(135deg, #f8f9fa 0%, #e9ecef 100%)",
    opacity: isVisible ? 1 : 0,
    transform: isVisible ? "translateY(0)" : "translateY(30px)",
    transition: "opacity 0.8s ease, transform 0.8s ease"
  }}
>
  <div style={{ maxWidth: "1400px", margin: "0 auto" }}>
    {/* Header Section */}
    <div style={{ 
      textAlign: "center", 
      marginBottom: "60px",
      animation: "fadeInDown 0.8s ease"
    }}>
      <h2 style={{
        fontSize: "3rem",
        fontWeight: "700",
        color: "#2c3e50",
        marginBottom: "16px",
        background: "linear-gradient(135deg, #4A90E2 0%, #357ABD 100%)",
        WebkitBackgroundClip: "text",
        WebkitTextFillColor: "transparent",
        backgroundClip: "text"
      }}>
        See AllCare in Action
      </h2>
      <p style={{
        fontSize: "1.25rem",
        color: "#6c757d",
        maxWidth: "700px",
        margin: "0 auto",
        lineHeight: "1.6"
      }}>
        Experience how our proactive care service transforms aging-in-place for seniors and their caregivers
      </p>
    </div>
    
    {/* Content Wrapper - Side by Side Layout */}
    <div style={{
      display: "grid",
      gridTemplateColumns: "1.2fr 1fr",
      gap: "50px",
      alignItems: "center"
    }}>
      
      {/* Video Player Section */}
      <div style={{ animation: "fadeInLeft 0.8s ease 0.2s both" }}>
        <div style={{
          position: "relative",
          width: "100%",
          borderRadius: "20px",
          overflow: "hidden",
          boxShadow: "0 20px 60px rgba(0, 0, 0, 0.15)",
          background: "#000",
          aspectRatio: "16 / 9",
          transition: "transform 0.3s ease, box-shadow 0.3s ease"
        }}>
          {!isVideoPlaying && (
            <div 
              style={{
                position: "absolute",
                top: 0,
                left: 0,
                width: "100%",
                height: "100%",
                background: "linear-gradient(135deg, rgba(74, 144, 226, 0.9) 0%, rgba(53, 122, 189, 0.9) 100%)",
                display: "flex",
                alignItems: "center",
                justifyContent: "center",
                cursor: "pointer",
                zIndex: 2,
                transition: "background 0.3s ease"
              }}
              onClick={handlePlayVideo}
            >
              <div style={{
                textAlign: "center",
                animation: "pulse 2s ease-in-out infinite"
              }}>
                <div style={{
                  margin: "0 auto 20px",
                  cursor: "pointer",
                  transition: "transform 0.3s ease",
                  filter: "drop-shadow(0 4px 15px rgba(0, 0, 0, 0.2))"
                }}>
                  <svg width="80" height="80" viewBox="0 0 80 80" fill="none">
                    <circle cx="40" cy="40" r="40" fill="white" fillOpacity="0.9"/>
                    <path d="M50 40L34 48.9282L34 31.0718L50 40Z" fill="#4A90E2"/>
                  </svg>
                </div>
                <div>
                  <h3 style={{
                    color: "white",
                    fontSize: "1.8rem",
                    fontWeight: "700",
                    marginBottom: "8px"
                  }}>
                    Watch Our Story
                  </h3>
                  <p style={{
                    color: "rgba(255, 255, 255, 0.9)",
                    fontSize: "1.1rem"
                  }}>
                    Click to see how AllCare makes a difference
                  </p>
                </div>
              </div>
            </div>
          )}
          
          <div style={{
            position: "relative",
            width: "100%",
            height: "100%",
            opacity: isVideoPlaying ? 1 : 0,
            transition: "opacity 0.3s ease",
            zIndex: isVideoPlaying ? 3 : 1
          }}>
            <video 
              ref={videoRef}
              controls 
              style={{
                width: "100%",
                height: "100%",
                objectFit: "cover"
              }}
              onPlay={() => setIsVideoPlaying(true)}
              onPause={() => setIsVideoPlaying(false)}
            >
              <source src={AllCareVideo} type="video/mp4" />
              Your browser does not support the video tag.
            </video>
          </div>
        </div>
      </div>

      {/* Marketing Text Section */}
      <div style={{ animation: "fadeInRight 0.8s ease 0.2s both" }}>
        <div style={{
          background: "white",
          padding: "50px",
          borderRadius: "20px",
          boxShadow: "0 10px 40px rgba(0, 0, 0, 0.1)",
          transition: "transform 0.3s ease, box-shadow 0.3s ease"
        }}>
          <h3 style={{
            fontSize: "2rem",
            fontWeight: "700",
            color: "#2c3e50",
            marginBottom: "20px",
            position: "relative",
            paddingBottom: "15px"
          }}>
            Why Choose AllCare?
            <span style={{
              content: "''",
              position: "absolute",
              bottom: "0",
              left: "0",
              width: "60px",
              height: "4px",
              background: "linear-gradient(90deg, #4A90E2 0%, #357ABD 100%)",
              borderRadius: "2px"
            }}></span>
          </h3>
          <p style={{
            fontSize: "1.1rem",
            color: "#495057",
            lineHeight: "1.7",
            marginBottom: "30px"
          }}>
            At AllCare, we make care simple, reliable, and personal. Our team ensures comfort,
            safety, and peace of mind for you and your loved ones every day.
          </p>
          <ul style={{
            listStyle: "none",
            paddingLeft: "1.5em"
          }}>
            {[
              "Experienced, trusted professionals",
              "Care tailored for every stage of life",
              "Smart technology for better outcomes",
              "Compassionate, personal support",
            ].map((item, index) => (
              <li
                key={index}
                style={{
                  position: "relative",
                  marginBottom: "8px",
                  paddingLeft: "1.2em",
                  fontSize: "1rem",
                  color: "#495057"
                }}
              >
                <span
                  style={{
                    position: "absolute",
                    left: 0,
                    color: "#4A90E2"
                  }}
                >
                  ★
                </span>
                {item}
              </li>
            ))}
          </ul>
        </div>
      </div>
    </div>
  </div>

  {/* Animation keyframes need to be in a style tag or separate CSS file */}
  <style>
    {`
      @keyframes fadeInDown {
        from {
          opacity: 0;
          transform: translateY(-20px);
        }
        to {
          opacity: 1;
          transform: translateY(0);
        }
      }

      @keyframes fadeInLeft {
        from {
          opacity: 0;
          transform: translateX(-30px);
        }
        to {
          opacity: 1;
          transform: translateX(0);
        }
      }

      @keyframes fadeInRight {
        from {
          opacity: 0;
          transform: translateX(30px);
        }
        to {
          opacity: 1;
          transform: translateX(0);
        }
      }

      @keyframes pulse {
        0%, 100% {
          transform: scale(1);
        }
        50% {
          transform: scale(1.05);
        }
      }

      /* Responsive styles */
      @media (max-width: 1024px) {
        section {
          padding: 60px 20px !important;
        }
        
        h2 {
          font-size: 2.5rem !important;
        }
        
        .video-subtitle {
          font-size: 1.1rem !important;
        }
        
        .video-content-wrapper {
          grid-template-columns: 1fr !important;
          gap: 40px !important;
        }
        
        .marketing-content {
          padding: 40px !important;
        }
        
        .marketing-content h3 {
          font-size: 1.75rem !important;
        }
      }

      @media (max-width: 768px) {
        section {
          padding: 40px 15px !important;
        }
        
        .video-header {
          margin-bottom: 40px !important;
        }
        
        h2 {
          font-size: 2rem !important;
        }
        
        .video-subtitle {
          font-size: 1rem !important;
        }
        
        .video-content-wrapper {
          gap: 30px !important;
        }
        
        .marketing-content {
          padding: 30px 25px !important;
        }
        
        .marketing-content h3 {
          font-size: 1.5rem !important;
        }
        
        .intro-text {
          font-size: 1rem !important;
        }
        
        .play-button svg {
          width: 60px !important;
          height: 60px !important;
        }
        
        .poster-text h3 {
          font-size: 1.4rem !important;
        }
        
        .poster-text p {
          font-size: 0.95rem !important;
        }
      }

      @media (max-width: 480px) {
        section {
          padding: 30px 10px !important;
        }
        
        h2 {
          font-size: 1.75rem !important;
        }
        
        .video-subtitle {
          font-size: 0.95rem !important;
        }
        
        .marketing-content {
          padding: 25px 20px !important;
        }
        
        .marketing-content h3 {
          font-size: 1.3rem !important;
        }
        
        .video-wrapper {
          border-radius: 15px !important;
        }
        
        .marketing-content {
          border-radius: 15px !important;
        }
      }
    `}
  </style>
</section>
  );
};


function HomePage() {
  const [email, setEmail] = useState('');

  const handleSubscribe = () => {
    if (email.trim() !== "") {
      const subscribersRef = ref(database, 'subscribers');
      push(subscribersRef, { email: email.trim() })
        .then(() => {
          alert("Subscribed successfully!");
          setEmail("");
        })
        .catch((error) => {
          console.error("Error subscribing:", error);
        });
    } else {
      alert("Please enter a valid email.");
    }
  };

  return (
    <div className="App" style={{marginTop: '-30px'}}>
      {/* Hero Section */}
      <div id="hero_section">
        <img src={homepage1} alt="Activities" style={{ width: '100%', height: "700px" }} />
      </div>

      {/* New Animated Introduction Section */}
      <IntroductionSection />

      {/* Collaboration Section */}
      <CollaborationSection />

      {/* Marketing Video Section - Replaced Testimonials */}
      <MarketingVideoSection />

      {/* Feedback Section */}
      <div style={{marginTop: '-120px'}}>
        <FeedbackSection /> 
      </div>

      {/* Footer */}
      <div style={{marginTop: '-30px'}}>
        <Footer />
      </div>
    </div>
  );
}

export default HomePage;