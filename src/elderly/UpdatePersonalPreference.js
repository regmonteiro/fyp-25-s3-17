import React, { useState } from "react";
import Footer from "../footer";

import FloatingAssistant from "../components/floatingassistantChat";

const currentUser = localStorage.getItem("loggedInEmail");

export default function UpdatePersonalPreference() {
  const [language, setLanguage] = useState("");
  const [message, setMessage] = useState("");

  const handleSubmit = (e) => {
    e.preventDefault();

    if (!language) {
      setMessage("⚠ Please select a language before confirming.");
      return;
    }

    // Simulate API call
    setTimeout(() => {
      setMessage(` Your AI Assistant preference has been updated to ${language}.`);
    }, 500);
  };

  const languageOptions = [
    { label: "English", icon: "🇬🇧" },
    { label: "Tamil", icon: "🇮🇳" },
    { label: "TBC Dialect", icon: "🗣️" },
  ];

  return (
    <div>
    <div style={styles.page}>
      <div style={styles.card}>
        <h1 style={styles.title}>🌐 Update Personal Preference</h1>
        <p style={styles.subtitle}>
          Choose your preferred language or dialect for interacting with your AI Assistant.
        </p>

        <form onSubmit={handleSubmit} style={styles.form}>
          {languageOptions.map((option) => (
            <label
              key={option.label}
              style={{
                ...styles.option,
                borderColor: language === option.label ? "#4fc3f7" : "#ddd",
                backgroundColor:
                  language === option.label ? "rgba(79, 195, 247, 0.1)" : "#fff",
              }}
              onClick={() => setLanguage(option.label)}
            >
              <input
                type="radio"
                value={option.label}
                checked={language === option.label}
                onChange={() => setLanguage(option.label)}
                style={{ display: "none" }}
              />
              <span style={styles.icon}>{option.icon}</span>
              <span style={styles.optionText}>{option.label}</span>
            </label>
          ))}

          <button type="submit" style={styles.button}>
            Confirm
          </button>
        </form>

        {message && <p style={styles.message}>{message}</p>}
      </div>

       {/* Floating AI Assistant */}
       {currentUser && <FloatingAssistant userEmail={currentUser} />}
      </div>
      <Footer />
    </div>
  );
}

const styles = {
  page: {
    display: "flex",
    justifyContent: "center",
    alignItems: "center",
    padding: "40px 20px",
    minHeight: "100vh",
    background: "linear-gradient(135deg, #e0f7fa, #f1f8e9)",
    marginTop: "-20px",
  },
  card: {
    width: "100%",
    maxWidth: "800px",
    backgroundColor: "#fff",
    borderRadius: "20px",
    padding: "30px",
    boxShadow: "0 10px 25px rgba(0,0,0,0.1)",
    fontFamily: "'Segoe UI', sans-serif",
    textAlign: "center",
  },
  title: {
    fontSize: "1.8rem",
    fontWeight: "bold",
    color: "#166088",
    marginBottom: "10px",
  },
  subtitle: {
    fontSize: "1rem",
    color: "#555",
    marginBottom: "20px",
  },
  form: {
    display: "flex",
    flexDirection: "column",
    gap: "15px",
  },
  option: {
    padding: "15px",
    borderRadius: "12px",
    border: "2px solid #ddd",
    cursor: "pointer",
    transition: "all 0.3s ease",
    fontSize: "1.1rem",
    display: "flex",
    alignItems: "center",
    gap: "10px",
    textAlign: "left",
  },
  icon: {
    fontSize: "1.5rem",
  },
  optionText: {
    color: "#333",
    fontWeight: "500",
  },
  button: {
    marginTop: "20px",
    padding: "12px 20px",
    backgroundColor: "#4a6fa5",
    color: "#fff",
    border: "none",
    borderRadius: "8px",
    cursor: "pointer",
    fontSize: "1.1rem",
    fontWeight: "bold",
    transition: "background-color 0.3s ease, transform 0.2s ease",
  },
  message: {
    marginTop: "20px",
    fontSize: "1rem",
    color: "#166088",
    backgroundColor: "rgba(79, 195, 247, 0.1)",
    padding: "10px",
    borderRadius: "8px",
  },
};
