import React, { useState, useRef, useEffect } from "react";
import { Users, Award, Globe, Smartphone, TrendingUp, MessageCircle, FileText, ArrowRight } from "lucide-react";
import unilogo from "./aboutUs.png";
import gppic from "./aboutUs.webp";
import simlogo from "./aboutUs3.jpg";
import { useNavigate } from "react-router-dom";
import { ref, onValue } from 'firebase/database';
import { database } from './firebaseConfig'; // Adjust path if needed

import avatar1 from "./assets/avator1.webp";
import avatar2 from "./assets/avator2.webp";
import avatar3 from "./assets/avator3.webp";
import avatar4 from "./assets/avator4.webp";
import avatar5 from "./assets/avator5.webp";
import Footer from "./footer";

const teamMembers = [
  { 
    name: "Regina", 
    role: "Team Lead", 
    major: "Bachelor of Business Information Systems",
    avatar: avatar1 
  },
  { 
    name: "Min Xuan", 
    role: "Documentation", 
    major: "Bachelor of Computer Science (Cyber Security)",
    avatar: avatar2 
  },
  { 
    name: "May", 
    role: "Full Stack Developer", 
    major: "Bachelor of Computer Science (Game and Mobile Development)",
    avatar: avatar4 
  },
  { 
    name: "Hann", 
    role: "Documentation", 
    major: "Bachelor of Business Information Systems",
    avatar: avatar3 
  },
  { 
    name: "QX", 
    role: "Documentation", 
    major: "Bachelor of Computer Science (Game and Mobile Development)",
    avatar: avatar5 
  },
];

const AboutUs = () => {
  const [modalImage, setModalImage] = useState(null);
  const [subscriberCount, setSubscriberCount] = useState(0);
  const [totalUsers, setTotalUsers] = useState(0);
  const [visibleSections, setVisibleSections] = useState({});
  const teamRef = useRef(null);
  const navigate = useNavigate();

  const scrollToTeam = () => {
    teamRef.current?.scrollIntoView({ behavior: "smooth" });
  };

  // Animation on scroll
  useEffect(() => {
    const observer = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          if (entry.isIntersecting) {
            setVisibleSections(prev => ({ ...prev, [entry.target.id]: true }));
          }
        });
      },
      { threshold: 0.1, rootMargin: '50px' }
    );

    const animatedElements = document.querySelectorAll('[data-animate]');
    animatedElements.forEach((element) => observer.observe(element));

    return () => observer.disconnect();
  }, []);

  useEffect(() => {
    const subsRef = ref(database, 'subscribers');
    const unsubscribeSubs = onValue(subsRef, (snapshot) => {
      const data = snapshot.val();
      const total = data ? Object.keys(data).length : 0;
      setSubscriberCount(total);
    });

    const usersRef = ref(database, 'Account');
    const unsubscribeUsers = onValue(usersRef, (snapshot) => {
      const data = snapshot.val();
      const total = data ? Object.keys(data).length : 0;
      setTotalUsers(total);
    });

    return () => {
      unsubscribeSubs();
      unsubscribeUsers();
    };
  }, []);

  const onNavigateToDocumentation = () => {
    navigate("/documentation");
  };

  return (
    <div className="pageContainer">
      <style jsx>{`
        .pageContainer {
          min-height: 100vh;
          background: linear-gradient(135deg, #f8fafc 0%, #ffffff 50%, #f1f5f9 100%);
          font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
        }

        .imageModal {
          position: fixed;
          top: 0;
          left: 0;
          width: 100vw;
          height: 100vh;
          background: rgba(0, 0, 0, 0.8);
          backdrop-filter: blur(8px);
          display: flex;
          align-items: center;
          justify-content: center;
          z-index: 999;
          padding: 1rem;
        }

        .modalImageContainer {
          position: relative;
          max-width: 80%;
          max-height: 80%;
          animation: modalAppear 0.3s ease-out;
        }

        .modalImage {
          width: 100%;
          height: 100%;
          object-fit: contain;
          border-radius: 16px;
          box-shadow: 0 25px 50px rgba(0, 0, 0, 0.5);
        }

        .closeModalButton {
          position: absolute;
          top: 16px;
          right: 16px;
          background: rgba(255, 255, 255, 0.2);
          backdrop-filter: blur(8px);
          border: none;
          border-radius: 50%;
          padding: 8px;
          cursor: pointer;
          transition: background 0.3s ease;
        }

        .closeModalButton:hover {
          background: rgba(255, 255, 255, 0.3);
        }

        .closeIcon {
          width: 24px;
          height: 24px;
          color: white;
        }

        @keyframes modalAppear {
          from { opacity: 0; transform: scale(0.9); }
          to { opacity: 1; transform: scale(1); }
        }

        .heroSection {
          position: relative;
          overflow: hidden;
        }

        .heroBackgroundPattern {
          position: absolute;
          top: 0;
          left: 0;
          width: 100%;
          height: 100%;
          opacity: 0.3;
        }

        .heroGradient {
          position: absolute;
          top: 0;
          left: 0;
          width: 100%;
          height: 100%;
          background: linear-gradient(90deg, rgba(59, 130, 246, 0.1) 0%, rgba(147, 51, 234, 0.1) 100%);
        }

        .heroWavePattern {
          position: absolute;
          bottom: 0;
          left: 0;
          width: 100%;
          height: 256px;
        }

        .waveShape {
          fill: rgba(59, 130, 246, 0.2);
        }

        .heroContent {
          position: relative;
          max-width: 1200px;
          margin: 0 auto;
          padding: 80px 1rem;
        }

        .institutionLogos {
          display: flex;
          justify-content: center;
          align-items: center;
          flex-wrap: wrap;
          gap: 6rem;
          margin-bottom: 4rem;
          transition: all 1s ease;
        }

        .institutionLogos.fadeInUp {
          opacity: 1;
          transform: translateY(0);
        }

        .institutionLogos:not(.fadeInUp) {
          opacity: 0;
          transform: translateY(32px);
        }

        .logoCard {
          cursor: pointer;
          transition: transform 0.3s ease;
        }

        .logoCard:hover {
          transform: scale(1.05);
        }

        .logoImageContainer {
          position: relative;
          overflow: hidden;
          border-radius: 16px;
          box-shadow: 0 10px 25px rgba(0, 0, 0, 0.15);
          width: 180px;      /* or 100% for responsive */
          height: 180px;     /* make this larger as needed */
          display: flex;
          align-items: center;
          justify-content: center;
          background: #fff;
        }

        .logoImage {
          width: 100%;
          height: 100%;
          object-fit: cover;   /* or object-fit: contain; if you want the whole image visible */
          border-radius: 16px;
          transition: box-shadow 0.3s ease;
        }

        .logoOverlay {
          position: absolute;
          top: 0;
          left: 0;
          width: 100%;
          height: 100%;
          background: linear-gradient(to top, rgba(0, 0, 0, 0.5), transparent);
          opacity: 0;
          transition: opacity 0.3s ease;
        }

        .logoCard:hover .logoOverlay {
          opacity: 1;
        }

        .logoCaption {
          margin-top: 12px;
          text-align: center;
          font-weight: 500;
          color: #374151;
          transition: color 0.3s ease;
        }

        .logoCard:hover .logoCaption {
          color: #3b82f6;
        }

        .mainTitle {
          text-align: center;
          margin-bottom: 4rem;
          transition: all 1s ease;
          transition-delay: 0.3s;
        }

        .mainTitle.fadeInUp {
          opacity: 1;
          transform: translateY(0);
        }

        .mainTitle:not(.fadeInUp) {
          opacity: 0;
          transform: translateY(32px);
        }

        .titleText {
          font-size: clamp(2.5rem, 5vw, 4rem);
          font-weight: 800;
          background: linear-gradient(135deg, #3b82f6, #8b5cf6, #1e40af);
          background-clip: text;
          -webkit-background-clip: text;
          -webkit-text-fill-color: transparent;
          margin-bottom: 1.5rem;
          margin-top: 2rem; 
        }

        .titleUnderline {
          width: 96px;
          height: 4px;
          background: linear-gradient(90deg, #3b82f6, #8b5cf6);
          margin: 0 auto;
          border-radius: 2px;
        }

        .mainContent {
          max-width: 1200px;
          margin: 0 auto;
          padding: 4rem 1rem;
        }

        .introSection {
          margin-bottom: 5rem;
          transition: all 1s ease;
        }

        .introSection.fadeInUp {
          opacity: 1;
          transform: translateY(0);
        }

        .introSection:not(.fadeInUp) {
          opacity: 0;
          transform: translateY(32px);
        }

        .introCard {
          background: white;
          border-radius: 24px;
          box-shadow: 0 10px 25px rgba(0, 0, 0, 0.1);
          padding: 3rem;
          border: 1px solid rgba(229, 231, 235, 0.8);
        }

        .introParagraph {
          font-size: 1.125rem;
          line-height: 1.7;
          color: #374151;
          margin-bottom: 1.5rem;
        }

        .introHighlight {
          font-weight: 600;
          background: linear-gradient(135deg, #f97316, #dc2626);
          background-clip: text;
          -webkit-background-clip: text;
          -webkit-text-fill-color: transparent;
        }

        .secondaryParagraph {
          font-size: 1.125rem;
          line-height: 1.7;
          color: #6b7280;
        }

        .statsSection {
          margin-bottom: 5rem;
          transition: all 1s ease;
          transition-delay: 0.2s;
        }

        .statsSection.fadeInUp {
          opacity: 1;
          transform: translateY(0);
        }

        .statsSection:not(.fadeInUp) {
          opacity: 0;
          transform: translateY(32px);
        }

        .statsGrid {
          display: grid;
          grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
          gap: 1.5rem;
        }

        .statCard {
          background: white;
          border-radius: 16px;
          padding: 1.5rem;
          box-shadow: 0 10px 25px rgba(0, 0, 0, 0.1);
          border: 1px solid rgba(229, 231, 235, 0.8);
          transition: all 0.3s ease;
        }

        .statCard:hover {
          transform: translateY(-8px);
          box-shadow: 0 20px 40px rgba(0, 0, 0, 0.15);
        }

        .statIconContainer {
          width: 48px;
          height: 48px;
          border-radius: 12px;
          display: flex;
          align-items: center;
          justify-content: center;
          margin-bottom: 1rem;
          transition: transform 0.3s ease;
        }

        .statCard:hover .statIconContainer {
          transform: scale(1.1);
        }

        .blueGradient {
          background: linear-gradient(135deg, #3b82f6, #2563eb);
        }

        .greenGradient {
          background: linear-gradient(135deg, #10b981, #059669);
        }

        .purpleGradient {
          background: linear-gradient(135deg, #8b5cf6, #7c3aed);
        }

        .orangeGradient {
          background: linear-gradient(135deg, #f97316, #dc2626);
        }

        .statIcon {
          width: 24px;
          height: 24px;
          color: white;
        }

        .statTitle {
          font-weight: 600;
          color: #1f2937;
          margin-bottom: 0.5rem;
        }

        .statDescription {
          font-size: 0.875rem;
          color: #6b7280;
          line-height: 1.5;
        }

        .featuresSection {
          margin-bottom: 5rem;
          transition: all 1s ease;
        }

        .featuresSection.fadeInUp {
          opacity: 1;
          transform: translateY(0);
        }

        .featuresSection:not(.fadeInUp) {
          opacity: 0;
          transform: translateY(32px);
        }

        .sectionTitle {
          font-size: clamp(1.875rem, 4vw, 2.5rem);
          font-weight: 800;
          text-align: center;
          margin-bottom: 3rem;
          background: linear-gradient(135deg, #059669, #3b82f6);
          background-clip: text;
          -webkit-background-clip: text;
          -webkit-text-fill-color: transparent;
        }

        .featuresCard {
          background: white;
          border-radius: 24px;
          box-shadow: 0 10px 25px rgba(0, 0, 0, 0.1);
          padding: 3rem;
          border: 1px solid rgba(229, 231, 235, 0.8);
        }

        .featuresGrid {
          display: grid;
          grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
          gap: 1.5rem;
        }

        .featureItem {
          display: flex;
          align-items: flex-start;
          gap: 1rem;
          padding: 1rem;
          border-radius: 12px;
          transition: background 0.3s ease;
        }

        .featureItem:hover {
          background: #9ac7f5ff;
        }

        .featureIconContainer {
          width: 40px;
          height: 40px;
          background: linear-gradient(135deg, #3b82f6, #8b5cf6);
          border-radius: 8px;
          display: flex;
          align-items: center;
          justify-content: center;
          flex-shrink: 0;
          margin-top: 4px;
        }

        .featureIcon {
          width: 20px;
          height: 20px;
          color: white;
        }

        .featureText {
          color: #374151;
          line-height: 1.6;
        }

        .teamSection {
          margin-bottom: 5rem;
          transition: all 1s ease;
        }

        .teamSection.fadeInUp {
          opacity: 1;
          transform: translateY(0);
        }

        .teamSection:not(.fadeInUp) {
          opacity: 0;
          transform: translateY(32px);
        }

        .teamSectionTitle {
          font-size: clamp(1.875rem, 4vw, 2.5rem);
          font-weight: 800;
          text-align: center;
          margin-bottom: 3rem;
          background: linear-gradient(135deg, #8b5cf6, #ec4899);
          background-clip: text;
          -webkit-background-clip: text;
          -webkit-text-fill-color: transparent;
        }

        .teamGrid {
          display: grid;
          grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
          gap: 2rem;
        }

        .teamMemberCard {
          background: white;
          border-radius: 16px;
          padding: 1.5rem;
          box-shadow: 0 10px 25px rgba(0, 0, 0, 0.1);
          text-align: center;
          border: 1px solid rgba(229, 231, 235, 0.8);
          transition: all 0.3s ease;
        }

        .teamMemberCard:hover {
          transform: translateY(-8px);
          box-shadow: 0 20px 40px rgba(0, 0, 0, 0.15);
        }

        .memberAvatarContainer {
          position: relative;
          margin: 0 auto 1rem;
          width: 150px;
          height: 150px;
        }

        .memberAvatar {
          width: 100%;
          height: 100%;
          border-radius: 50%;
          object-fit: cover;
          border: 4px solid #f3f4f6;
          transition: border-color 0.3s ease;
        }

        .teamMemberCard:hover .memberAvatar {
          border-color: #bfdbfe;
        }

        .memberAvatarOverlay {
          position: absolute;
          top: 0;
          left: 0;
          width: 100%;
          height: 100%;
          border-radius: 50%;
          background: linear-gradient(to top, rgba(59, 130, 246, 0.2), transparent);
          opacity: 0;
          transition: opacity 0.3s ease;
        }

        .teamMemberCard:hover .memberAvatarOverlay {
          opacity: 1;
        }

        .memberName {
          font-weight: 1000;
          color: #1f2937;
          margin-bottom: 4px;
        }

        .memberRole {
          font-size: 0.875rem;
          color: #6b7280;
        }

        .supervisorsSection {
          margin-bottom: 5rem;
          transition: all 1s ease;
        }

        .supervisorsSection.fadeInUp {
          opacity: 1;
          transform: translateY(0);
        }

        .supervisorsSection:not(.fadeInUp) {
          opacity: 0;
          transform: translateY(32px);
        }

        .supervisorsSectionTitle {
          font-size: clamp(1.875rem, 4vw, 2.5rem);
          font-weight: 800;
          text-align: center;
          margin-bottom: 3rem;
          background: linear-gradient(135deg, #4f46e5, #8b5cf6);
          background-clip: text;
          -webkit-background-clip: text;
          -webkit-text-fill-color: transparent;
        }

        .supervisorsContainer {
          background: linear-gradient(135deg, #dbeafe, #e0e7ff);
          border-radius: 24px;
          padding: 3rem;
          border: 1px solid #bfdbfe;
        }

        .declarationText {
          font-size: 1.125rem;
          color: #374151;
          line-height: 1.7;
          margin-bottom: 2rem;
          text-align: center;
        }

        .supervisorsGrid {
          display: flex;
          flex-direction: column;
          gap: 1.5rem;
          justify-content: center;
          align-items: center;
        }

        @media (min-width: 640px) {
          .supervisorsGrid {
            flex-direction: row;
          }
        }

        .supervisorCard {
          background: white;
          border-radius: 16px;
          padding: 1.5rem;
          box-shadow: 0 10px 25px rgba(0, 0, 0, 0.1);
          text-align: center;
          min-width: 220px;
          transition: box-shadow 0.3s ease;
        }

        .supervisorCard:hover {
          box-shadow: 0 20px 40px rgba(0, 0, 0, 0.15);
        }

        .supervisorName {
          font-weight: 600;
          color: #1f2937;
          margin-bottom: 0.5rem;
        }

        .supervisorTitle {
          font-size: 0.875rem;
          color: #6b7280;
        }

        .closingSection {
          text-align: center;
          transition: all 1s ease;
        }

        .closingSection.fadeInUp {
          opacity: 1;
          transform: translateY(0);
        }

        .closingSection:not(.fadeInUp) {
          opacity: 0;
          transform: translateY(32px);
        }

        .closingCard {
          background: linear-gradient(135deg, #3b82f6, #8b5cf6);
          border-radius: 24px;
          padding: 3rem;
          color: white;
        }

        .closingText {
          font-size: 1.125rem;
          line-height: 1.7;
        }

        .closingDivider {
          margin-top: 1.5rem;
          display: flex;
          justify-content: center;
        }

        .closingLine {
          width: 64px;
          height: 4px;
          background: rgba(255, 255, 255, 0.5);
          border-radius: 2px;
        }

        /* Responsive Design */
        @media (max-width: 768px) {
          .heroContent {
            padding: 3rem 1rem;
          }

          .institutionLogos {
            gap: 1.5rem;
          }

          .logoImage {
            width: 96px;
            height: 96px;
          }

          .introCard, .featuresCard, .supervisorsContainer, .closingCard {
            padding: 2rem;
          }

          .statsGrid, .featuresGrid {
            grid-template-columns: 1fr;
          }

          .teamGrid {
            grid-template-columns: repeat(auto-fit, minmax(160px, 1fr));
            gap: 1.5rem;
          }
        }

        @media (max-width: 480px) {
          .heroContent {
            padding: 2rem 0.5rem;
          }

          .mainContent {
            padding: 2rem 0.5rem;
          }

          .introCard, .featuresCard, .supervisorsContainer, .closingCard {
            padding: 1.5rem;
          }

          .logoImage {
            width: 80px;
            height: 80px;
          }

          .teamGrid {
            grid-template-columns: repeat(auto-fit, minmax(140px, 1fr));
          }
        }
          /* Documentation Navigation Card */
      .navigationCard {
        background: linear-gradient(135deg, #3b82f6, #8b5cf6);
        border-radius: 24px;
        padding: 3rem 2rem;
        text-align: center;
        color: white;
        max-width: 1200px;
        margin: 0 auto 5rem auto;
        box-shadow: 0 15px 40px rgba(0, 0, 0, 0.2);
        transition: transform 0.3s ease, box-shadow 0.3s ease;
      }

      .navigationCard:hover {
        transform: translateY(-8px);
        box-shadow: 0 25px 50px rgba(0, 0, 0, 0.25);
      }

      .navigationTitle {
        font-size: clamp(1.8rem, 4vw, 2.5rem);
        font-weight: 800;
        margin-bottom: 1rem;
        display: flex;
        justify-content: center;
        align-items: center;
        gap: 0.5rem;
      }

      .navigationDescription {
        font-size: 1rem;
        line-height: 1.6;
        margin-bottom: 2rem;
        color: #e0e7ff;
      }

      .documentationButton {
        display: inline-flex;
        align-items: center;
        gap: 0.5rem;
        padding: 0.75rem 1.5rem;
        background: rgba(255, 255, 255, 0.15);
        border: none;
        border-radius: 12px;
        color: white;
        font-weight: 600;
        font-size: 1rem;
        cursor: pointer;
        transition: background 0.3s ease, transform 0.3s ease;
        backdrop-filter: blur(6px);
      }

      .documentationButton:hover {
        background: rgba(255, 255, 255, 0.25);
        transform: translateY(-2px);
      }

      .docButtonIcon {
        width: 20px;
        height: 20px;
      }

      /* Responsive Adjustments */
      @media (max-width: 768px) {
        .navigationCard {
          padding: 2rem 1.5rem;
        }

        .navigationTitle {
          font-size: clamp(1.5rem, 5vw, 2rem);
        }

        .documentationButton {
          width: 100%;
          justify-content: center;
        }
      }

      @media (max-width: 480px) {
        .navigationCard {
          padding: 1.5rem 1rem;
        }

        .navigationDescription {
          font-size: 0.95rem;
        }

        .navigationTitle {
          font-size: 1.5rem;
        }
      }

      `}</style>
      {/* Modal */}
      {modalImage && (
        <div className="imageModal" onClick={() => setModalImage(null)}>
          <div className="modalImageContainer">
            <img src={modalImage} alt="Zoomed" className="modalImage" />
            <button className="closeModalButton" onClick={() => setModalImage(null)}>
              <svg className="closeIcon" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
              </svg>
            </button>
          </div>
        </div>
      )}

      {/* Hero Section */}
      <div className="heroSection">
        <div className="heroBackgroundPattern">
          <div className="heroGradient"></div>
          <svg className="heroWavePattern" viewBox="0 0 1200 120" preserveAspectRatio="none">
            <path d="M321.39,56.44c58-10.79,114.16-30.13,172-41.86,82.39-16.72,168.19-17.73,250.45-.39C823.78,31,906.67,72,985.66,92.83c70.05,18.48,146.53,26.09,214.34,3V0H0V27.35A600.21,600.21,0,0,0,321.39,56.44Z" className="waveShape"></path>
          </svg>
        </div>

        <div className="heroContent">
          {/* Institution Logos */}
          <div 
            id="logoSection" 
            data-animate
            className={`institutionLogos ${visibleSections.logoSection ? 'fadeInUp' : ''}`}
          >
            {[
              { src: gppic, label: "Our Project Team" },
              { src: unilogo, label: "University of Wollongong" },
              { src: simlogo, label: "Singapore Institute of Management" }
            ].map((logo, index) => (
              <div 
                key={index}
                className="logoCard"
                onClick={index === 0 ? scrollToTeam : () => setModalImage(logo.src)}
              >
                <div className="logoImageContainer">
                  <img src={logo.src} alt={logo.label} className="logoImage" />
                  <div className="logoOverlay"></div>
                </div>
                <p className="logoCaption">{logo.label}</p>
              </div>
            ))}
          </div>

          {/* Main Title */}
          <div 
            id="titleSection"
            data-animate
            className={`mainTitle ${visibleSections.titleSection ? 'fadeInUp' : ''}`}
          >
            <h1 className="titleText">About Us</h1>
            <div className="titleUnderline"></div>
          </div>
        </div>
      </div>

      <div className="mainContent">
        {/* Introduction */}
        <div 
          id="introductionSection"
          data-animate
          className={`introSection ${visibleSections.introductionSection ? 'fadeInUp' : ''}`}
        >
          <div className="introCard">
            <p className="introParagraph">
              Welcome to our <span className="introHighlight">Final Year Project: Aged Care Platform with Personal AI Assistants</span> — a digital platform designed to help older adults embrace technology with ease, confidence, and comfort.
            </p>
            <p className="secondaryParagraph">
              Our AI assistant simplifies digital experiences, guiding users through personalized recommendations, learning content, and reminders — like a helpful digital companion.
            </p>
          </div>
        </div>

        {/* Navigation to Documentation */}
        <div 
          id="navigationSection"
          data-animate
          className={`navigationSection ${visibleSections.navigationSection ? 'fadeInUp' : ''}`}
        >
          <div className="navigationCard">
            <h2 className="navigationTitle">📚 Explore Our Documentation</h2>
            <p className="navigationDescription">
              Access comprehensive project documentation including requirements, specifications, and technical design manuals.
            </p>
            <button 
              className="documentationButton" 
              onClick={onNavigateToDocumentation}
            >
              <FileText className="docButtonIcon" />
              View Documentation
              <ArrowRight className="docButtonIcon" />
            </button>
          </div>
        </div>

        {/* Stats Banner */}
        <div 
          id="statisticsSection"
          data-animate
          className={`statsSection ${visibleSections.statisticsSection ? 'fadeInUp' : ''}`}
        >
          <div className="statsGrid">
            {[
              { icon: Globe, title: "Website Version", desc: "Accessible on all modern browsers with responsive design", gradient: "blueGradient" },
              { icon: Smartphone, title: "Mobile App Version", desc: "Available on Android & iOS for convenient use on the go", gradient: "greenGradient" },
              { icon: Users, title: "Total Users", desc: (
  <span>
    <span style={{ color: "#2563eb", fontWeight: 1000, fontSize: '1.5rem' }}>{totalUsers.toLocaleString()}</span> registered users and growing every day!
  </span>
), gradient: "blueGradient" },
              { icon: TrendingUp, title: "Subscribers", desc: (
  <span>
    <span style={{ color: "#2563eb", fontWeight: 1000, fontSize: '1.5rem' }}>{subscriberCount.toLocaleString()}</span> monthly active subscribers
  </span>
), gradient: "blueGradient" }
            ].map((stat, index) => (
              <div key={index} className="statCard">
                <div className={`statIconContainer ${stat.gradient}`}>
                  <stat.icon className="statIcon" />
                </div>
                <h3 className="statTitle">{stat.title}</h3>
                <p className="statDescription">{stat.desc}</p>
              </div>
            ))}
          </div>
        </div>

        {/* What We Offer */}
        <div 
          id="offeringsSection"
          data-animate
          className={`featuresSection ${visibleSections.offeringsSection ? 'fadeInUp' : ''}`}
        >
          <h2 className="sectionTitle">What We Offer</h2>
          
          <div className="featuresCard">
            <div className="featuresGrid">
              {[
                { icon: MessageCircle, text: "Social media integration for easier communication" },
                { icon: Award, text: "Personalized learning resources for engagement" },
                { icon: Users, text: "Scheduling and intelligent reminders" },
                { icon: Globe, text: "Community features for social inclusion" },
                { icon: TrendingUp, text: "AI assistant that adapts to user preferences" }
              ].map((feature, index) => (
                <div key={index} className="featureItem">
                  <div className="featureIconContainer">
                    <feature.icon className="featureIcon" />
                  </div>
                  <p className="featureText">{feature.text}</p>
                </div>
              ))}
            </div>
          </div>
        </div>

        {/* Meet the Team */}
        <div 
          ref={teamRef}
          id="teamMembersSection"
          data-animate
          className={`teamSection ${visibleSections.teamMembersSection ? 'fadeInUp' : ''}`}
        >
          <h2 className="teamSectionTitle">Meet the Team</h2>
          
          <div className="teamGrid">
            {teamMembers.map((member, index) => (
              <div key={index} className="teamMemberCard">
                <div className="memberAvatarContainer">
                  <img src={member.avatar} alt={member.name} className="memberAvatar" />
                  <div className="memberAvatarOverlay"></div>
                </div>
                <h3 className="memberName">{member.name}</h3>
                <p className="memberRole">{member.role}</p>
                <p className="memberMajor">{member.major}</p> {/* Add this line */}
              </div>
            ))}
          </div>
        </div>

        {/* Supervisors */}
        <div 
          id="supervisionSection"
          data-animate
          className={`supervisorsSection ${visibleSections.supervisionSection ? 'fadeInUp' : ''}`}
        >
          <h2 className="supervisorsSectionTitle">Supervisor & Assessor</h2>
          
          <div className="supervisorsContainer">
            <p className="declarationText">
              We hereby declare that this project is the result of our team's dedicated work and was completed under the guidance of our supervisor. All sources have been cited where applicable.
            </p>
            
            <div className="supervisorsGrid">
              {[
                { name: "Mr. Sionggo Japit", title: "Supervisor" },
                { name: "Mr. Premrajan", title: "Assessor" }
              ].map((person, index) => (
                <div key={index} className="supervisorCard">
                  <h3 className="supervisorName">{person.name}</h3>
                  <p className="supervisorTitle">{person.title}</p>
                </div>
              ))}
            </div>
          </div>
        </div>

        

        {/* Closing Statement */}
        <div 
          id="conclusionSection"
          data-animate
          className={`closingSection ${visibleSections.conclusionSection ? 'fadeInUp' : ''}`}
        >
          <div className="closingCard">
            <p className="closingText">
              Our mission is to make digital life accessible, engaging, and empowering for older adults. Thank you for being a part of our journey.
            </p>
            <div className="closingDivider">
              <div className="closingLine"></div>
            </div>
          </div>
        </div>
      </div>
      <Footer />
    </div>
  );
};

export default AboutUs;