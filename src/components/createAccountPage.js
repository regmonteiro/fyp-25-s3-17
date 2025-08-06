// src/components/createAccount.js
import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { createAccountEntity } from '../entity/createAccountEntity';
import { createAccount } from '../controller/createAccountController';
import "../components/createAccountPage.css";

function CreateAccountPage() {
  const [formData, setFormData] = useState({
    firstname: '',
    lastname: '',
    email: '',
    dob: '',
    phoneNum: '',
    password: '',
    confirmPassword: '',
    userType: 'admin',   // default user type
    elderlyId: '',       // for caregiver only
  });

  const [error, setError] = useState('');
  const [successMessage, setSuccessMessage] = useState('');
  const today = new Date().toISOString().split('T')[0];
  const navigate = useNavigate();

  const handleChange = (e) => {
    setFormData({ ...formData, [e.target.name]: e.target.value });
    setError('');
    setSuccessMessage('');
  };

  const handleSubmit = async (e) => {
    e.preventDefault();

    // Validate elderlyId if userType is caregiver
    if (formData.userType === 'caregiver' && !formData.elderlyId.trim()) {
      setError("Please provide the Elderly ID to link caregiver.");
      setSuccessMessage('');
      return;
    }

    // Optional: You can add more validations here (e.g., password match)

    const accountEntity = createAccountEntity(formData);
    const result = await createAccount(accountEntity);

    if (!result.success) {
      setError(result.error);
      setSuccessMessage('');
      return;
    }

    setSuccessMessage("Account successfully created! Redirecting to login...");
    setError('');
    setFormData({
      firstname: '',
      lastname: '',
      email: '',
      dob: '',
      phoneNum: '',
      password: '',
      confirmPassword: '',
      userType: 'admin',
      elderlyId: '',
    });

    setTimeout(() => {
      navigate('/login');
    }, 2000);
  };

  return (
    <div className="signup-container">
      <h2>Create Account</h2>
      <form onSubmit={handleSubmit} className="signup-form">

        <label htmlFor="firstname">First Name</label>
        <input
          id="firstname"
          type="text"
          name="firstname"
          value={formData.firstname}
          onChange={handleChange}
          placeholder="First name"
          required
        />

        <label htmlFor="lastname">Last Name</label>
        <input
          id="lastname"
          type="text"
          name="lastname"
          value={formData.lastname}
          onChange={handleChange}
          placeholder="Last name"
          required
        />

        <label htmlFor="email">Email Address</label>
        <input
          id="email"
          type="email"
          name="email"
          value={formData.email}
          onChange={handleChange}
          placeholder="helloworld@gmail.com"
          required
        />

        <label htmlFor="dob">Date of Birth</label>
        <input
          id="dob"
          type="date"
          name="dob"
          value={formData.dob}
          onChange={handleChange}
          max={today}
          required
        />

        <label htmlFor="phoneNum">Phone Number</label>
        <input
          id="phoneNum"
          type="tel"
          name="phoneNum"
          value={formData.phoneNum}
          onChange={handleChange}
          placeholder="Phone number"
          required
        />

        <label htmlFor="password">Password</label>
        <input
          id="password"
          type="password"
          name="password"
          value={formData.password}
          onChange={handleChange}
          placeholder="Enter password"
          required
        />

        <label htmlFor="confirmPassword">Confirm Password</label>
        <input
          id="confirmPassword"
          type="password"
          name="confirmPassword"
          value={formData.confirmPassword}
          onChange={handleChange}
          placeholder="Confirm password"
          required
        />

        <label htmlFor="userType">User Type</label>
        <select
          id="userType"
          name="userType"
          value={formData.userType}
          onChange={handleChange}
          required
        >
          <option value="admin">Admin</option>
          <option value="elderly">Elderly</option>
          <option value="caregiver">Caregiver</option>
        </select>

        {formData.userType === 'caregiver' && (
          <>
            <label htmlFor="elderlyId">Elderly ID (to link caregiver)</label>
            <input
              id="elderlyId"
              type="text"
              name="elderlyId"
              value={formData.elderlyId}
              onChange={handleChange}
              placeholder="Enter Elderly User ID"
              required
            />
          </>
        )}

        <button type="submit">Create Account</button>
      </form>

      {error && <p className="error-message">{error}</p>}
      {successMessage && <p className="success-message">{successMessage}</p>}
    </div>
  );
}

export default CreateAccountPage;
