import React, { useState, useRef, useEffect } from "react";
import { ref, onValue } from "firebase/database";
import { database } from "./firebaseConfig"; // adjust path if needed

import unilogo from "./aboutUs.png";
import gppic from "./aboutUs.webp";
import simlogo from "./aboutUs3.jpg";

import avatar1 from "./assets/avator1.webp";
import avatar2 from "./assets/avator2.webp";
import avatar3 from "./assets/avator3.webp";
import avatar4 from "./assets/avator4.webp";
import avatar5 from "./assets/avator5.webp";

const teamMembers = [
  { name: "Regina", role: "Team Lead", avatar: avatar1 },
  { name: "Min Xuan", role: "Documentation", avatar: avatar2 },
  { name: "May", role: "Full Stack Developer", avatar: avatar4 },
  { name: "Hann", role: "Documentation", avatar: avatar3 },
  { name: "QX", role: "Documentation", avatar: avatar5 },
];

const AboutUs = () => {
  const [modalImage, setModalImage] = useState(null);
  const [subscriberCount, setSubscriberCount] = useState(0);
  const teamRef = useRef(null);

  const scrollToTeam = () => {
    teamRef.current?.scrollIntoView({ behavior: "smooth" });
  };

  // Fetch subscriber count from Firebase Realtime Database
  useEffect(() => {
    const subscribersRef = ref(database, "subscribers");
    const unsubscribe = onValue(subscribersRef, (snapshot) => {
      const data = snapshot.val();
      if (data) {
        setSubscriberCount(Object.keys(data).length);
      } else {
        setSubscriberCount(0);
      }
    });

    return () => unsubscribe();
  }, []);

  return (
    <div style={styles.container}>
      {modalImage && (
        <div style={styles.modalOverlay} onClick={() => setModalImage(null)}>
          <img src={modalImage} alt="Zoomed" style={styles.modalImage} />
        </div>
      )}

      <div style={styles.topBanner}>
        <ImageCard src={gppic} label="Our Project Team" onClick={scrollToTeam} />
        <ImageCard src={unilogo} label="University of Wollongong" onClick={() => setModalImage(unilogo)} />
        <ImageCard src={simlogo} label="Singapore Institute of Management" onClick={() => setModalImage(simlogo)} />
      </div>

      <SectionTitle text="About Us" />
      <TextBlock>
        Welcome to our <Highlight>Final Year Project: Aged Care Platform with Personal AI Assistants</Highlight> — a digital platform designed to help older adults embrace technology with ease, confidence, and comfort.
      </TextBlock>
      <TextBlock>
        Our AI assistant simplifies digital experiences, guiding users through personalized recommendations, learning content, and reminders — like a helpful digital companion.
      </TextBlock>

      {/* Banner Section */}
      <div style={styles.bannerSection}>
        <div style={styles.bannerCard}>
          <h3 style={styles.bannerTitle}>Website Version</h3>
          <p style={styles.bannerText}>Accessible on all modern browsers with responsive design.</p>
        </div>
        <div style={styles.bannerCard}>
          <h3 style={styles.bannerTitle}>Mobile App Version</h3>
          <p style={styles.bannerText}>Available on Android & iOS for convenient use on the go.</p>
        </div>
        <div style={styles.bannerCard}>
          <h3 style={styles.bannerTitle}>Total Users</h3>
          <p style={styles.bannerText}>3,245 registered users and growing every day!</p>
        </div>
        <div style={styles.bannerCard}>
          <h3 style={styles.bannerTitle}>Subscribers</h3>
          <p style={styles.bannerText}>
            Over <span style={{ color: '#e17055', fontWeight: '700' }}>{subscriberCount.toLocaleString()}</span> monthly active subscribers.
          </p>

        </div>
      </div>

      <SectionTitle text="What We Offer" />
      <ul style={styles.list}>
        <li>Social media integration for easier communication</li>
        <li>Personalized learning resources for engagement</li>
        <li>Scheduling and intelligent reminders</li>
        <li>Community features for social inclusion</li>
        <li>AI assistant that adapts to user preferences</li>
      </ul>

      <SectionTitle text="Meet the Team" refProp={teamRef} />
      <div style={styles.teamGrid}>
        {teamMembers.map((m, i) => (
          <div key={i} style={styles.teamCard}>
            <img src={m.avatar} alt={m.name} style={styles.avatarImg} />
            <div style={styles.memberName}>{m.name}</div>
            <div style={styles.memberRole}>{m.role}</div>
          </div>
        ))}
      </div>

      <SectionTitle text="Supervisor & Assessor" />
      <div style={styles.declarationBox}>
        <TextBlock>
          We hereby declare that this project is the result of our team’s dedicated work and was completed under the guidance of our supervisor. All sources have been cited where applicable.
        </TextBlock>
        <div style={styles.supervisorGroup}>
          <Supervisor name="Mr. Sionggo Japit" title="Supervisor" />
          <Supervisor name="Mr. Premrajan" title="Assessor" />
        </div>
      </div>

      <TextBlock>
        Our mission is to make digital life accessible, engaging, and empowering for older adults. Thank you for being a part of our journey.
      </TextBlock>
    </div>
  );
};

export default AboutUs;

const ImageCard = ({ src, label, onClick }) => (
  <div style={styles.imageBox} onClick={onClick}>
    <img src={src} alt={label} style={styles.image} />
    <div style={styles.caption}>{label}</div>
  </div>
);

const SectionTitle = ({ text, refProp }) => (
  <h2 ref={refProp} style={styles.subheading}>{text}</h2>
);

const TextBlock = ({ children }) => (
  <p style={styles.paragraph}>{children}</p>
);

const Highlight = ({ children }) => (
  <span style={styles.highlight}>{children}</span>
);

const Supervisor = ({ name, title }) => (
  <div style={styles.supervisorCard}>
    <div style={styles.supervisorName}>{name}</div>
    <div style={styles.supervisorTitle}>{title}</div>
  </div>
);

const styles = {
  container: {
    maxWidth: "1100px",
    margin: "40px auto",
    padding: "40px 30px",
    backgroundColor: "#f9fafb",
    color: "#2c3e50",
    fontFamily: "'Segoe UI', Tahoma, Geneva, Verdana, sans-serif",
    borderRadius: "16px",
    boxShadow: "0 6px 24px rgba(0,0,0,0.08)",
    position: "relative",
  },
  topBanner: {
    display: "flex",
    justifyContent: "center",
    alignItems: "center",
    flexWrap: "wrap",
    gap: "40px",
    marginBottom: "40px",
  },
  imageBox: {
    display: "flex",
    flexDirection: "column",
    alignItems: "center",
    cursor: "pointer",
    transition: "transform 0.3s",
  },
  image: {
    width: "160px",
    height: "160px",
    objectFit: "cover",
    borderRadius: "20px",
    boxShadow: "0 4px 12px rgba(0,0,0,0.15)",
    backgroundColor: "#fff",
  },
  caption: {
    marginTop: "10px",
    fontSize: "15px",
    fontWeight: "500",
    color: "#6c5ce7",
    textAlign: "center",
  },
  subheading: {
    fontSize: "28px",
    margin: "50px 0 20px",
    color: "#00b894",
    textAlign: "center",
  },
  paragraph: {
    marginBottom: "20px",
    fontSize: "18px",
    lineHeight: "1.8",
    textAlign: "justify",
  },
  highlight: {
    color: "#d35400",
    fontWeight: "600",
  },
  list: {
    fontSize: "18px",
    lineHeight: "1.8",
    paddingLeft: "20px",
    marginBottom: "40px",
  },
  teamGrid: {
    display: "grid",
    gridTemplateColumns: "repeat(auto-fit, minmax(180px, 1fr))",
    gap: "30px",
    marginBottom: "50px",
  },
  teamCard: {
    backgroundColor: "#fff",
    borderRadius: "16px",
    boxShadow: "0 4px 14px rgba(0,0,0,0.1)",
    padding: "20px",
    textAlign: "center",
  },
  avatarImg: {
    width: "120px",
    height: "120px",
    borderRadius: "50%",
    objectFit: "cover",
    marginBottom: "15px",
    border: "3px solid #e1e1e1",
  },
  memberName: {
    fontSize: "18px",
    fontWeight: "600",
    marginBottom: "6px",
  },
  memberRole: {
    fontSize: "15px",
    color: "#636e72",
  },
  modalOverlay: {
    position: "fixed",
    top: 0,
    left: 0,
    width: "100vw",
    height: "100vh",
    backgroundColor: "rgba(0, 0, 0, 0.7)",
    display: "flex",
    justifyContent: "center",
    alignItems: "center",
    zIndex: 999,
  },
  modalImage: {
    maxWidth: "90%",
    maxHeight: "90%",
    borderRadius: "12px",
  },
  declarationBox: {
    marginBottom: "40px",
  },
  supervisorGroup: {
    display: "flex",
    justifyContent: "center",
    gap: "40px",
    marginTop: "20px",
    flexWrap: "wrap",
  },
  supervisorCard: {
    backgroundColor: "#ffffff",
    borderRadius: "12px",
    padding: "20px",
    boxShadow: "0 2px 10px rgba(0,0,0,0.1)",
    minWidth: "220px",
    textAlign: "center",
  },
  supervisorName: {
    fontSize: "18px",
    fontWeight: "600",
    color: "#2d3436",
    marginBottom: "6px",
  },
  supervisorTitle: {
    fontSize: "15px",
    color: "#6c757d",
  },
  bannerSection: {
    display: "grid",
    gridTemplateColumns: "repeat(auto-fit, minmax(240px, 1fr))",
    gap: "30px",
    margin: "40px 0",
  },
  bannerCard: {
    backgroundColor: "#ffffff",
    borderRadius: "14px",
    padding: "20px",
    boxShadow: "0 3px 10px rgba(0,0,0,0.1)",
    textAlign: "center",
  },
  bannerTitle: {
    fontSize: "20px",
    fontWeight: "600",
    color: "#0984e3",
    marginBottom: "10px",
  },
  bannerText: {
    fontSize: "16px",
    color: "#636e72",
  },
};
