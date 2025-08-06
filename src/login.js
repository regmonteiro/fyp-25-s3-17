import React, { useState } from 'react';
import './App.css';
import { Link, useNavigate } from 'react-router-dom';
import { loginAccountEntity } from './entity/loginAccountEntity';
import { loginAccount } from './controller/loginAccountController';

function Login() {
  const [formData, setFormData] = useState({ email: '', password: '' });
  const [error, setError] = useState('');
  const navigate = useNavigate();

  const handleChange = (e) => {
    setFormData({ ...formData, [e.target.name]: e.target.value });
    setError('');
  };

  const handleSubmit = async (e) => {
    e.preventDefault();

    const entity = loginAccountEntity(formData);
    const result = await loginAccount(entity);

    if (!result.success) {
      setError(result.error);
      return;
    }

    // Save login state
    localStorage.setItem("isLoggedIn", "true");
    localStorage.setItem("userEmail", formData.email);

    alert("Login successful!");
    navigate('/HomePage');
  };

  return (
    <div className="login-page">
      <div className="login-card">
        <h1>Welcome to AllCare</h1>
        <p>Please log in to continue</p>
        <form className="login-form" onSubmit={handleSubmit}>
          <label htmlFor="email">Email Address</label>
          <input
            type="email"
            id="email"
            name="email"
            placeholder="Enter your email"
            value={formData.email}
            onChange={handleChange}
            required
            aria-label="Email Address"
          />

          <label htmlFor="password">Password</label>
          <input
            type="password"
            id="password"
            name="password"
            placeholder="Enter your password"
            value={formData.password}
            onChange={handleChange}
            required
            aria-label="Password"
          />

          <button type="submit">Log In</button>

          {error && <p className="error-message">{error}</p>}

          <p className="help-text">
            Forgot password? <a href="#" onClick={(e) => e.preventDefault()}>Click here</a>
          </p>

          <p style={{ marginTop: '1rem' }}>
            Don't have an account? <Link to="/signup">Sign Up</Link>
          </p>
        </form>
      </div>
    </div>
  );
}

export default Login;
