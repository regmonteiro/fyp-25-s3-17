import './App.css';
import homepage1 from "./homepage1.jpg";
import { FaFacebookF, FaInstagram, FaYoutube } from 'react-icons/fa';
import { useState } from 'react';
import { database, ref, push } from './firebaseConfig';

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
    <div className="App">
      <div id="hero_section">
        <img src={homepage1} alt="Activities" style={{ width: '100%', height: "650px" }} />
      </div>

      <header className="App-header" style={{ backgroundColor: '#f5f5f5', padding: '2rem', color: '#333' }}>
        <h1 style={{ fontSize: '2.5rem', marginBottom: '1rem' }}>Welcome to AllCare</h1>
        <p style={{ fontSize: '1.2rem', maxWidth: '600px', margin: '0 auto' }}>
          Hello! This is home page of FYP Aged Care Platform with personal AI assistants.
        </p>
      </header>

      <footer className="homepage_footer">
        <div className="footer_content">

          <div className="footer_col">
            <h4>AllCare</h4>
            <p>Empowering aged care through AI assistance.</p>
          </div>

          <div className="footer_col">
            <h4>Contact</h4>
            <p><strong>Email:</strong> hello@allcare.com</p>
            <p><strong>Phone:</strong> +65 1234 5678</p>
            <p><strong>Address:</strong> 123 Care Ave, Singapore</p>
            <p><a href="/AboutUs" className="footer-link">About Us</a></p>
          </div>

          <div className="footer_col">
            <h4>Support</h4>
            <p><strong>Email:</strong> support@allcare.com</p>
            <p><strong>Phone:</strong> +65 8765 4321</p>
            <p><a href="/ViewQNAPage" className="footer-link">FAQ</a></p>
          </div>

          <div className="footer_col">
            <h4>Stay in the loop</h4>
            <input
              type="email"
              placeholder="Enter your email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
            />
            <button className="subscribe-button" onClick={handleSubscribe}>Subscribe</button>
            <div className="social-icons">
              <FaFacebookF />
              <FaInstagram />
              <FaYoutube />
            </div>
          </div>
        </div>

        <div className="footer_bottom">
          <p>© 2025 AllCare. All rights reserved.</p>
        </div>
      </footer>
    </div>
  );
}

export default HomePage;
