import React, { useState } from "react";
import { 
  Download, FileText, Users, BookOpen, ArrowLeft, ExternalLink, Shield,
  Brain, Calendar, Share2
} from "lucide-react";
import Footer from "./footer";

const ProjectDocumentation = ({ onBackToAbout }) => {
  const [activeSection, setActiveSection] = useState("summary");
  const [downloadingDoc, setDownloadingDoc] = useState(null);

  const handleDownload = async (docName) => {
    setDownloadingDoc(docName);
    // Simulate download delay
    await new Promise(resolve => setTimeout(resolve, 2000));
    setDownloadingDoc(null);
    
    console.log(`Downloading ${docName}...`);
  };

  const documentationItems = [
  {
    id: 1,
    title: "Project Requirements Documentation",
    description: "Comprehensive overview of project objectives, scope, and functional requirements for the aged care platform.",
    icon: FileText,
    category: "Requirements",
    pages: "84 pages",
    lastUpdated: "9 August 2025",
    downloadKey: "project-requirements",
    fileUrl: "https://docs.google.com/document/d/1atDUz_nYjPNIXAt_hgrnDrrFpjSRVqbn9J1Z407DiKc/edit?usp=sharing"
  },
  {
    id: 2,
    title: "Preliminary Technical Documentation",
    description: "Detailed analysis of system architecture, database design, and technical implementation guidelines.",
    icon: Users,
    category: "Technical",
    pages: "92 pages",
    lastUpdated: "13 September 2025",
    downloadKey: "prelim-technical-docs",
    fileUrl: "https://docs.google.com/document/d/1rOcHpltlfWy2jiOTwn_gGJVFo6ic9QxWDJ-GtYmVjG4/edit?usp=sharing"
  },
  {
    id: 3,
    title: "Preliminary User Manual",
    description: "Step-by-step instructions for users to interact with the AI assistant platform.",
    icon: BookOpen,
    category: "Technical",
    pages: "12 pages",
    lastUpdated: "13 September 2025",
    downloadKey: "prelim-user-manual",
    fileUrl: "https://docs.google.com/document/d/190b7fUsmNoe9eHjWpOIHIrpzy1D6rlTG2VPTOJUGZLM/edit?usp=sharing"
  },
  {
    id: 4,
    title: "Presentation Slides",
    description: "Slides summarizing project objectives, design, and progress.",
    icon: BookOpen,
    category: "Presentation",
    pages: "25 slides",
    lastUpdated: "13 September 2025",
    downloadKey: "presentation-slides",
    fileUrl: "https://docs.google.com/presentation/d/1hxztXhJUohfQDDjs21AQU05dYIzYogN49Xa4jpkgXlg/edit?usp=sharing"
  },
  /*
  {
    id: 5,
    title: "Final Technical Documentation",
    description: "Comprehensive final version of the technical documentation including all updates.",
    icon: Users,
    category: "Technical",
    pages: "102 pages",
    lastUpdated: "15 November 2025",
    downloadKey: "final-technical-docs",
    fileUrl: "https://docs.google.com/document/d/YOUR_DOC_ID_5/export?format=pdf"
  },
  {
    id: 6,
    title: "Final User Manual",
    description: "Updated user manual with all finalized instructions and guides.",
    icon: BookOpen,
    category: "Technical",
    pages: "88 pages",
    lastUpdated: "15 November 2025",
    downloadKey: "final-user-manual",
    fileUrl: "https://docs.google.com/document/d/YOUR_DOC_ID_6/export?format=pdf"
  },
  {
    id: 7,
    title: "Final Source Code",
    description: "Complete source code for the AI assistant platform project.",
    icon: BookOpen,
    category: "Technical",
    pages: "N/A",
    lastUpdated: "15 November 2025",
    downloadKey: "final-source-code",
    fileUrl: "https://drive.google.com/uc?export=download&id=YOUR_FILE_ID_7"
  },
  {
    id: 8,
    title: "Final Project Video",
    description: "Demonstration video showcasing the final project and features.",
    icon: Users,
    category: "Media",
    pages: "N/A",
    lastUpdated: "15 November 2025",
    downloadKey: "final-project-video",
    fileUrl: "https://drive.google.com/uc?export=download&id=YOUR_FILE_ID_8"
  },
  {
    id: 9,
    title: "Final Presentation Slides",
    description: "Slides used in the final presentation of the project.",
    icon: BookOpen,
    category: "Presentation",
    pages: "30 slides",
    lastUpdated: "15 November 2025",
    downloadKey: "final-presentation-slides",
    fileUrl: "https://docs.google.com/presentation/d/YOUR_DOC_ID_9/export/pdf"
  }*/
];


  const featureItems = [
    {
      icon: Users,
      title: "Social Media Integration",
      description: "Connect with family and friends through an elderly-friendly social interface"
    },
    {
      icon: BookOpen,
      title: "Learning Resources",
      description: "Access educational content on various topics tailored for older adults"
    },
    {
      icon: Calendar,
      title: "Event Scheduling & Reminders",
      description: "Never miss important appointments or activities with smart reminders"
    },
    {
      icon: Share2,
      title: "Experience Sharing",
      description: "Share life experiences and connect with others in the community"
    },
    {
      icon: Brain,
      title: "Adaptive AI Assistant",
      description: "Personal assistant that learns your habits and preferences over time"
    }
  ];

  const renderSummarySection = () => (
    <div className="mainContent">
      {/* Page Title */}
      <div className="pageTitle">
        <h1 className="titleText">Project Summary</h1>
        <p className="titleSubtext">
          Comprehensive overview of our Aged Care Platform with Personal AI Assistants
        </p>
      </div>

      {/* Project Information */}
      <div className="projectInfo">
        <div className="infoGrid">
          <div className="infoItem">
            <div className="infoLabel">Project ID</div>
            <div className="infoValue">CSIT-25-S3-07</div>
          </div>
          <div className="infoItem">
            <div className="infoLabel">Proposed Title</div>
            <div className="infoValue">Aged Care Platform with Personal AI Assistants</div>
          </div>
          <div className="infoItem">
            <div className="infoLabel">University</div>
            <div className="infoValue">University of Wollongong</div>
          </div>
        </div>

        <div className="descriptionBox">
          <h3 className="descriptionTitle">Project Description</h3>
          <p className="descriptionText">
            Elderly individuals often find technology complex and intimidating. To
            address this, the platform provides a personal AI assistant linked to each user's
            account, making navigation effortless and easy to use. With the assistant's
            support, users can seamlessly resume their activities from where they left off
            and remember their favourite activities on the platform. Additionally, the AI
            assistant continuously learns user behaviors, adapting to their needs and habits
            for a more personalized and intuitive experience.
          </p>

          <h3 className="descriptionTitle">Expected Outcomes</h3>
          <ul className="outcomesList">
            <li>A dedicated digital platform for aging individuals.</li>
            <li>The platform's features: social media integration, learning resources
              for various topics, event scheduling and reminder, social activities,
              experience sharing</li>
            <li>The AI assistant's features: being able to learn habits of the user and
              provide proper assistance to the user whose account is linked to the AI
              assistant, and having functionalities and features like those of a
              personal assistant.</li>
          </ul>
        </div>

        <h3 className="descriptionTitle">Platform Features</h3>
        <div className="featuresGrid">
          {featureItems.map((feature, index) => (
            <div key={index} className="featureCard">
              <div className="featureIcon">
                <feature.icon />
              </div>
              <h4 className="featureTitle">{feature.title}</h4>
              <p className="featureDescription">{feature.description}</p>
            </div>
          ))}
        </div>

        
      </div>
    </div>
  );

  const renderDocumentationSection = () => (
    <div className="mainContent">
      {/* Protected Banner */}
      <div className="protectedBanner">
        <Shield className="protectedIcon" />
        <span className="protectedText">Protected: Documentation</span>
      </div>

      {/* Page Title */}
      <div className="pageTitle">
        <h1 className="titleText">Project Documentation</h1>
        <p className="titleSubtext">
          Access comprehensive documentation for our Aged Care Platform with Personal AI Assistants project
        </p>
      </div>

      {/* Documents Grid */}
      <div className="documentsGrid">
        {documentationItems.map((doc) => (
          <div key={doc.id} className="documentCard">
            <div className="cardHeader">
              <div className="cardIcon">
                <doc.icon className="documentIcon" />
              </div>
              <div className="cardContent">
                <h3 className="documentTitle">{doc.title}</h3>
              </div>
            </div>
            
            <p className="documentDescription">{doc.description}</p>
            
            <div className="cardMeta">
              <div className="categoryBadge">{doc.category}</div>
              <div className="metaItem">📄 {doc.pages}</div>
              <div className="metaItem">🕒 {doc.lastUpdated}</div>
            </div>
            
            <button 
              className={`downloadButton ${downloadingDoc === doc.downloadKey ? 'downloading' : ''}`}
              onClick={() => window.open(doc.fileUrl, '_blank')}
              disabled={downloadingDoc === doc.downloadKey}
            >
              <Download className="downloadIcon" />
              Download
            </button>
          </div>
        ))}
      </div>

      {/* Additional Information */}
      <div className="additionalInfo">
        <h3 className="infoTitle">Need More Information?</h3>
        <p className="infoText">
          If you need additional documentation or have questions about our project, 
          please don't hesitate to contact our team for more details.
        </p>
        <button className="contactButton">
          Contact Team <ExternalLink className="externalIcon" />
        </button>
      </div>
    </div>
  );

  return (
    <div className="combinedContainer">
      <style jsx>{`
        .combinedContainer {
          min-height: 100vh;
          background: linear-gradient(135deg, #f8fafc 0%, #ffffff 50%, #f1f5f9 100%);
          font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
        }

        .headerSection {
          background: linear-gradient(135deg, #3b82f6, #8b5cf6);
          color: white;
          padding: 3rem 1rem;
          position: relative;
          overflow: hidden;
        }

        .headerBackground {
          position: absolute;
          top: 0;
          left: 0;
          width: 100%;
          height: 100%;
          opacity: 0.1;
        }

        .headerPattern {
          position: absolute;
          top: 0;
          left: 0;
          width: 100%;
          height: 100%;
          background-image: radial-gradient(circle at 25% 25%, rgba(255,255,255,0.1) 1px, transparent 1px);
          background-size: 30px 30px;
        }

        .headerContent {
          position: relative;
          max-width: 1200px;
          margin: 0 auto;
          text-align: center;
        }

        .backButton {
          position: absolute;
          top: -1rem;
          left: 0;
          background: rgba(255, 255, 255, 0.2);
          backdrop-filter: blur(10px);
          border: 1px solid rgba(255, 255, 255, 0.3);
          color: white;
          padding: 0.75rem 1.5rem;
          border-radius: 50px;
          cursor: pointer;
          transition: all 0.3s ease;
          display: flex;
          align-items: center;
          gap: 0.5rem;
          font-weight: 500;
        }

        .backButton:hover {
          background: rgba(255, 255, 255, 0.3);
          transform: translateY(-2px);
          box-shadow: 0 10px 20px rgba(0, 0, 0, 0.2);
        }

        .backIcon {
          width: 20px;
          height: 20px;
        }

        .projectTitle {
          font-size: clamp(1.5rem, 3vw, 2rem);
          margin-bottom: 0.5rem;
          opacity: 0.9;
        }

        .projectId {
          font-size: clamp(2.5rem, 5vw, 4rem);
          font-weight: 800;
          margin-bottom: 1rem;
          background: linear-gradient(45deg, #ffffff, #e2e8f0);
          background-clip: text;
          -webkit-background-clip: text;
          -webkit-text-fill-color: transparent;
        }

        .headerNav {
          display: flex;
          justify-content: center;
          gap: 2rem;
          margin-top: 2rem;
          flex-wrap: wrap;
        }

        .navItem {
          padding: 0.5rem 1rem;
          border-radius: 25px;
          transition: all 0.3s ease;
          cursor: pointer;
          font-weight: 500;
        }

        .navItem.active {
          background: rgba(255, 255, 255, 0.2);
          backdrop-filter: blur(10px);
        }

        .navItem:hover {
          background: rgba(255, 255, 255, 0.1);
        }

        .mainContent {
          max-width: 1200px;
          margin: 0 auto;
          padding: 4rem 1rem;
        }

        /* Documentation Styles */
        .protectedBanner {
          background: linear-gradient(135deg, #fef3c7, #fde68a);
          border: 1px solid #f59e0b;
          border-radius: 16px;
          padding: 1.5rem;
          margin-bottom: 3rem;
          display: flex;
          align-items: center;
          gap: 1rem;
        }

        .protectedIcon {
          width: 24px;
          height: 24px;
          color: #d97706;
          flex-shrink: 0;
        }

        .protectedText {
          color: #92400e;
          font-weight: 600;
          font-size: 1.125rem;
        }

        .pageTitle {
          text-align: center;
          margin-bottom: 3rem;
        }

        .titleText {
          font-size: clamp(2.5rem, 4vw, 3.5rem);
          font-weight: 800;
          background: linear-gradient(135deg, #1f2937, #4b5563);
          background-clip: text;
          -webkit-background-clip: text;
          -webkit-text-fill-color: transparent;
          margin-bottom: 1rem;
        }

        .titleSubtext {
          font-size: 1.25rem;
          color: #6b7280;
          max-width: 600px;
          margin: 0 auto;
          line-height: 1.6;
        }

        .documentsGrid {
          display: grid;
          grid-template-columns: repeat(auto-fit, minmax(350px, 1fr));
          gap: 2rem;
          margin-bottom: 4rem;
        }

        .documentCard {
          background: white;
          border-radius: 20px;
          padding: 2rem;
          box-shadow: 0 10px 25px rgba(0, 0, 0, 0.1);
          border: 1px solid rgba(229, 231, 235, 0.8);
          transition: all 0.3s ease;
          position: relative;
          overflow: hidden;
        }

        .documentCard::before {
          content: '';
          position: absolute;
          top: 0;
          left: 0;
          width: 100%;
          height: 4px;
          background: linear-gradient(90deg, #3b82f6, #8b5cf6, #ec4899);
          transform: scaleX(0);
          transition: transform 0.3s ease;
          transform-origin: left;
        }

        .documentCard:hover::before {
          transform: scaleX(1);
        }

        .documentCard:hover {
          transform: translateY(-8px);
          box-shadow: 0 20px 40px rgba(0, 0, 0, 0.15);
        }

        .cardHeader {
          display: flex;
          align-items: flex-start;
          gap: 1rem;
          margin-bottom: 1.5rem;
        }

        .cardIcon {
          width: 48px;
          height: 48px;
          background: linear-gradient(135deg, #dbeafe, #bfdbfe);
          border-radius: 12px;
          display: flex;
          align-items: center;
          justify-content: center;
          flex-shrink: 0;
        }

        .documentIcon {
          width: 24px;
          height: 24px;
          color: #3b82f6;
        }

        .cardContent {
          flex: 1;
        }

        .documentTitle {
          font-size: 1.25rem;
          font-weight: 700;
          color: #1f2937;
          margin-bottom: 0.5rem;
          line-height: 1.3;
        }

        .documentDescription {
          color: #6b7280;
          line-height: 1.6;
          margin-bottom: 1.5rem;
        }

        .cardMeta {
          display: flex;
          flex-wrap: wrap;
          gap: 1rem;
          margin-bottom: 1.5rem;
        }

        .metaItem {
          display: flex;
          align-items: center;
          gap: 0.5rem;
          font-size: 0.875rem;
          color: #6b7280;
        }

        .categoryBadge {
          background: linear-gradient(135deg, #e0e7ff, #c7d2fe);
          color: #4338ca;
          padding: 0.25rem 0.75rem;
          border-radius: 20px;
          font-size: 0.75rem;
          font-weight: 600;
        }

        .downloadButton {
          width: 100%;
          background: linear-gradient(135deg, #3b82f6, #2563eb);
          color: white;
          border: none;
          padding: 0.875rem 1.5rem;
          border-radius: 12px;
          font-weight: 600;
          cursor: pointer;
          transition: all 0.3s ease;
          display: flex;
          align-items: center;
          justify-content: center;
          gap: 0.5rem;
          position: relative;
          overflow: hidden;
        }

        .downloadButton:hover {
          transform: translateY(-2px);
          box-shadow: 0 10px 20px rgba(59, 130, 246, 0.3);
        }

        .downloadButton:active {
          transform: translateY(0);
        }

        .downloadButton.downloading {
          background: linear-gradient(135deg, #6b7280, #4b5563);
          cursor: not-allowed;
        }

        .downloadIcon {
          width: 20px;
          height: 20px;
        }

        .loadingSpinner {
          width: 20px;
          height: 20px;
          border: 2px solid rgba(255, 255, 255, 0.3);
          border-top: 2px solid white;
          border-radius: 50%;
          animation: spin 1s linear infinite;
        }

        @keyframes spin {
          to { transform: rotate(360deg); }
        }

        .additionalInfo {
          background: linear-gradient(135deg, #f0f9ff, #e0f2fe);
          border-radius: 20px;
          padding: 2rem;
          text-align: center;
          border: 1px solid #0ea5e9;
        }

        .infoTitle {
          font-size: 1.5rem;
          font-weight: 700;
          color: #0c4a6e;
          margin-bottom: 1rem;
        }

        .infoText {
          color: #075985;
          line-height: 1.6;
          margin-bottom: 1.5rem;
        }

        .contactButton {
          background: linear-gradient(135deg, #0ea5e9, #0284c7);
          color: white;
          border: none;
          padding: 0.75rem 2rem;
          border-radius: 50px;
          font-weight: 600;
          cursor: pointer;
          transition: all 0.3s ease;
          display: inline-flex;
          align-items: center;
          gap: 0.5rem;
        }

        .contactButton:hover {
          transform: translateY(-2px);
          box-shadow: 0 10px 20px rgba(14, 165, 233, 0.3);
        }

        .externalIcon {
          width: 18px;
          height: 18px;
        }

        /* Summary Styles */
        .projectInfo {
          background: white;
          border-radius: 20px;
          padding: 2.5rem;
          box-shadow: 0 10px 25px rgba(0, 0, 0, 0.1);
          margin-bottom: 3rem;
          border: 1px solid rgba(229, 231, 235, 0.8);
        }

        .infoGrid {
          display: grid;
          grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
          gap: 2rem;
          margin-bottom: 2rem;
        }

        .infoItem {
          padding: 1.5rem;
          background: #f8fafc;
          border-radius: 16px;
          border-left: 4px solid #3b82f6;
        }

        .infoLabel {
          font-size: 0.875rem;
          color: #6b7280;
          margin-bottom: 0.5rem;
          font-weight: 600;
        }

        .infoValue {
          font-size: 1.125rem;
          color: #1f2937;
          font-weight: 700;
        }

        .descriptionBox {
          background: #f0f9ff;
          padding: 2rem;
          border-radius: 16px;
          border: 1px solid #bae6fd;
          margin-bottom: 2rem;
        }

        .descriptionTitle {
          font-size: 1.5rem;
          font-weight: 700;
          color: #0c4a6e;
          margin-bottom: 1rem;
        }

        .descriptionText {
          color: #075985;
          line-height: 1.7;
          margin-bottom: 1.5rem;
        }

        .outcomesList {
          list-style-type: none;
          padding: 0;
        }

        .outcomesList li {
          padding: 0.5rem 0;
          color: #075985;
          display: flex;
          align-items: flex-start;
          gap: 0.5rem;
        }

        .outcomesList li:before {
          content: "✓";
          color: #0ea5e9;
          font-weight: bold;
          font-size: 1.2rem;
        }

        .featuresGrid {
          display: grid;
          grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
          gap: 2rem;
          margin-bottom: 3rem;
        }

        .featureCard {
          background: white;
          border-radius: 16px;
          padding: 1.5rem;
          box-shadow: 0 4px 6px rgba(0, 0, 0, 0.05);
          border: 1px solid rgba(229, 231, 235, 0.8);
          transition: all 0.3s ease;
          display: flex;
          flex-direction: column;
          align-items: center;
          text-align: center;
        }

        .featureCard:hover {
          transform: translateY(-5px);
          box-shadow: 0 10px 25px rgba(0, 0, 0, 0.1);
        }

        .featureIcon {
          width: 48px;
          height: 48px;
          background: linear-gradient(135deg, #dbeafe, #bfdbfe);
          border-radius: 12px;
          display: flex;
          align-items: center;
          justify-content: center;
          margin-bottom: 1rem;
        }

        .featureIcon svg {
          width: 24px;
          height: 24px;
          color: #3b82f6;
        }

        .featureTitle {
          font-size: 1.125rem;
          font-weight: 700;
          color: #1f2937;
          margin-bottom: 0.5rem;
        }

        .featureDescription {
          color: #6b7280;
          line-height: 1.6;
        }

        .universitySection {
          text-align: center;
          padding: 2rem;
          background: linear-gradient(135deg, #f0f9ff, #e0f2fe);
          border-radius: 20px;
          border: 1px solid #0ea5e9;
        }

        .universityLogo {
          font-size: 2rem;
          font-weight: 800;
          color: #0c4a6e;
          margin-bottom: 1rem;
        }

        .universityText {
          color: #075985;
          font-weight: 600;
        }

        /* Responsive Design */
        @media (max-width: 768px) {
          .headerContent {
            padding: 0 1rem;
          }

          .backButton {
            position: relative;
            top: 0;
            margin-bottom: 2rem;
          }

          .headerNav {
            gap: 1rem;
          }

          .navItem {
            padding: 0.5rem 0.75rem;
            font-size: 0.875rem;
          }

          .mainContent {
            padding: 2rem 1rem;
          }

          .documentsGrid {
            grid-template-columns: 1fr;
            gap: 1.5rem;
          }

          .documentCard {
            padding: 1.5rem;
          }

          .cardHeader {
            flex-direction: column;
            align-items: flex-start;
            gap: 1rem;
          }

          .cardIcon {
            align-self: flex-start;
          }

          .infoGrid,
          .featuresGrid {
            grid-template-columns: 1fr;
            gap: 1.5rem;
          }

          .projectInfo {
            padding: 1.5rem;
          }

          .descriptionBox {
            padding: 1.5rem;
          }
        }

        @media (max-width: 480px) {
          .protectedBanner {
            flex-direction: column;
            text-align: center;
          }

          .documentCard {
            padding: 1.25rem;
          }

          .additionalInfo {
            padding: 1.5rem;
          }

          .featureCard {
            padding: 1.25rem;
          }

          .universitySection {
            padding: 1.5rem;
          }
        }
      `}</style>

      {/* Header Section */}
      <div className="headerSection">
        <div className="headerBackground">
          <div className="headerPattern"></div>
        </div>
        <div className="headerContent">
          <button className="backButton" onClick={onBackToAbout}>
            <ArrowLeft className="backIcon" />
            Back to About Us
          </button>
          <h1 className="projectTitle">FYP25 - S317</h1>
          <h2 className="projectId">All Care</h2>
          <nav className="headerNav">
            <div 
              className={`navItem ${activeSection === "summary" ? "active" : ""}`}
              onClick={() => setActiveSection("summary")}
            >
              Project Summary
            </div>
            <div 
              className={`navItem ${activeSection === "documentation" ? "active" : ""}`}
              onClick={() => setActiveSection("documentation")}
            >
              Documentation
            </div>
          </nav>
        </div>
      </div>

      {activeSection === "summary" ? renderSummarySection() : renderDocumentationSection()}
      <Footer />
    </div>
  );
};

export default ProjectDocumentation;