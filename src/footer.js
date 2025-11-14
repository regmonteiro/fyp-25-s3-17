import React, { useState } from "react";
import { FaFacebookF, FaInstagram, FaYoutube } from "react-icons/fa";
import { database, ref, push } from './firebaseConfig';

const Footer = () => {
  const [email, setEmail] = useState("");

  const handleSubscribe = () => {
    if (email.trim() !== "") {
      const subscribersRef = ref(database, "subscribers");
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

  // CSS in JS
  const styles = {
    homepage_footer: {
      background: "linear-gradient(to right, #132837, #6CA0DC)",
      color: "#ffffff",
      padding: "50px 20px 30px",
      fontFamily: "Arial, sans-serif",
    },
    footer_content: {
      display: "flex",
      flexWrap: "wrap",
      justifyContent: "space-around",
      gap: "2rem",
      maxWidth: "1200px",
      margin: "auto",
    },
    footer_col: {
      flex: "1 1 220px",
      minWidth: "220px",
      marginBottom: "1rem",
    },
    h4: {
      marginBottom: "1rem",
      fontSize: "1.3rem",
      borderBottom: "2px solid #A8D5BA",
      paddingBottom: "0.3rem",
    },
    p: {
      marginBottom: "0.5rem",
      fontSize: "0.95rem",
      lineHeight: "1.5",
    },
    footer_link: {
      color: "#FFF9C4",
      textDecoration: "none",
      fontWeight: "bold",
    },
    input: {
      width: "100%",
      padding: "10px",
      marginTop: "0.5rem",
      border: "none",
      borderBottom: "1px solid #ccc",
      backgroundColor: "transparent",
      color: "white",
      outline: "none",
    },
    subscribe_button: {
      backgroundColor: "#D9534F",
      border: "none",
      color: "white",
      padding: "10px 18px",
      fontWeight: "bold",
      borderRadius: "20px",
      cursor: "pointer",
      marginTop: "0.8rem",
      transition: "background-color 0.3s",
    },
    social_icons: {
      marginTop: "1rem",
      display: "flex",
      gap: "1rem",
      fontSize: "1.4rem",
    },
    footer_bottom: {
      textAlign: "center",
      borderTop: "1px solid #35556a",
      marginTop: "2rem",
      paddingTop: "1rem",
      fontSize: "0.85rem",
      color: "#ccc",
    },
  };

  return (
    <footer style={styles.homepage_footer}>
      <div style={styles.footer_content}>
        <div style={styles.footer_col}>
          <h4 style={styles.h4}>AllCare</h4>
          <p style={styles.p}>Empowering aged care through AI assistance.</p>
        </div>

        <div style={styles.footer_col}>
          <h4 style={styles.h4}>Contact</h4>
          <p style={styles.p}><strong>Email:</strong> hello@allcare.com</p>
          <p style={styles.p}><strong>Phone:</strong> +65 1234 5678</p>
          <p style={styles.p}><strong>Address:</strong> 461 Clementi Road, Singapore 599491</p>
          <a href="/AboutUs" style={styles.footer_link}>About Us</a>
        </div>

        <div style={styles.footer_col}>
          <h4 style={styles.h4}>Support</h4>
          <p style={styles.p}><strong>Email:</strong> support@allcare.com</p>
          <p style={styles.p}><strong>Phone:</strong> +65 8765 4321</p>
          <a href="/ViewQNAPage" style={styles.footer_link}>FAQ</a>
        </div>

        <div style={styles.footer_col}>
          <h4 style={styles.h4}>Stay in the loop</h4>
          <input
            type="email"
            placeholder="Enter your email"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            style={styles.input}
          />
          <button
            style={styles.subscribe_button}
            onClick={handleSubscribe}
          >
            Subscribe
          </button>
          <div style={styles.social_icons}>
            <FaFacebookF />
            <FaInstagram />
            <FaYoutube />
          </div>
        </div>
      </div>

      <div style={styles.footer_bottom}>
        <p>© 2025 AllCare. All rights reserved.</p>
      </div>
    </footer>
  );
};

export default Footer;
