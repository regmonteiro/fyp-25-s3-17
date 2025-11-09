import React, { useState, useEffect, useRef } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { loginAccountEntity } from './entity/loginAccountEntity';
import { loginAccount, updatePassword } from './controller/loginAccountController';
import Footer from './footer';

function Login() {
  const [formData, setFormData] = useState({ email: '', password: '' });
  const [forgotPasswordData, setForgotPasswordData] = useState({ 
    newPassword: '', 
    confirmPassword: '' 
  });
  const [error, setError] = useState('');
  const [accountStatusError, setAccountStatusError] = useState('');
  const [forgotPasswordError, setForgotPasswordError] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const [isResetting, setIsResetting] = useState(false);
  const [showForgotPassword, setShowForgotPassword] = useState(false);
  const [forgotPasswordSuccess, setForgotPasswordSuccess] = useState(false);
  const navigate = useNavigate();

  // Use useRef to persist the timer across renders
  const logoutTimerRef = useRef(null);

  // ⏳ Auto logout after 10 minutes of inactivity
  useEffect(() => {
    const logoutAfterInactivity = 10 * 60 * 1000; // 10 minutes

    const resetTimer = () => {
      // Clear existing timer
      if (logoutTimerRef.current) {
        clearTimeout(logoutTimerRef.current);
      }
      
      // Set new timer
      logoutTimerRef.current = setTimeout(() => {
        localStorage.removeItem('userName');
        localStorage.removeItem('loggedInEmail');
        localStorage.removeItem('role');
        alert('You have been logged out due to inactivity.');
        navigate('/');
      }, logoutAfterInactivity);
    };

    const handleActivity = () => {
      resetTimer();
    };

    // Set up event listeners
    const events = ['mousemove', 'keydown', 'click', 'scroll', 'touchstart', 'mousedown'];
    events.forEach(event => {
      document.addEventListener(event, handleActivity);
    });

    // Initialize the timer
    resetTimer();

    // Cleanup function
    return () => {
      if (logoutTimerRef.current) {
        clearTimeout(logoutTimerRef.current);
      }
      events.forEach(event => {
        document.removeEventListener(event, handleActivity);
      });
    };
  }, [navigate]);

  const handleChange = (e) => {
    setFormData({ ...formData, [e.target.name]: e.target.value });
    setError('');
    setAccountStatusError('');
  };

  const handleForgotPasswordChange = (e) => {
    setForgotPasswordData({ ...forgotPasswordData, [e.target.name]: e.target.value });
    setForgotPasswordError('');
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    setIsLoading(true);
    setError('');
    setAccountStatusError('');

    try {
      const entity = loginAccountEntity(formData);
      const result = await loginAccount(entity);

      if (!result.success) {
        if (result.error === "Account deactivated") {
          setAccountStatusError(
            "Your account is deactivated. Please contact the admin team at allCareITsupport@gmail.com"
          );
        } else {
          setError(result.error);
        }
        setIsLoading(false);
        return;
      }

      if (result.user?.status && result.user.status.toLowerCase() === "deactivated") {
        setIsLoading(false);
        setAccountStatusError(
          "Your account is deactivated. Please contact the admin team at allCareITsupport@gmail.com"
        );
        return;
      }

      const fullName = `${result.user.firstName || result.user.firstname || ''} ${result.user.lastName || result.user.lastname || ''}`.trim() || 'User';

      localStorage.setItem('userName', fullName);
      localStorage.setItem('loggedInEmail', formData.email);
      localStorage.setItem('role', result.user.role || result.user.userType || 'guest');

      navigate('/HomePage');

    } catch (err) {
      setError('An unexpected error occurred');
      setIsLoading(false);
    }
  };

  const handleForgotPasswordSubmit = async (e) => {
    e.preventDefault();
    setIsResetting(true);

    if (forgotPasswordData.newPassword !== forgotPasswordData.confirmPassword) {
      setForgotPasswordError("Passwords don't match");
      setIsResetting(false);
      return;
    }

    if (forgotPasswordData.newPassword.length < 6) {
      setForgotPasswordError("Password should be at least 6 characters");
      setIsResetting(false);
      return;
    }

    try {
      const result = await updatePassword(formData.email, forgotPasswordData.newPassword);

      if (!result.success) {
        setForgotPasswordError(result.error);
        setIsResetting(false);
        return;
      }

      setForgotPasswordSuccess(true);
      setTimeout(() => {
        setShowForgotPassword(false);
        setForgotPasswordSuccess(false);
        setForgotPasswordData({ newPassword: '', confirmPassword: '' });
        setIsResetting(false);
      }, 2000);
    } catch (err) {
      setForgotPasswordError('An unexpected error occurred');
      setIsResetting(false);
    }
  };

  const styles = {
    page: {
      margin: 0,
      padding: 0,
      fontFamily: "'Inter', sans-serif",
      minHeight: '100vh',
      display: 'flex',
      justifyContent: 'center',
      alignItems: 'center',
      backgroundColor: '#f5f7fa',
      color: '#333',
      position: 'relative',
      fontSize: '20px',
      marginTop: '-20px',
    },
    card: {
      background: '#ffffff',
      borderRadius: '16px',
      padding: '40px',
      width: '90%',
      maxWidth: '450px',
      boxShadow: '0 10px 40px rgba(0,0,0,0.1)',
      color: '#333',
      position: 'relative',
      zIndex: 10,
    },
    heading: {
      fontSize: '36px',
      fontWeight: '700',
      marginBottom: '10px',
      textAlign: 'center',
      color: '#2d3748',
      background: 'linear-gradient(90deg, #1479ec, #04aeee)',
      WebkitBackgroundClip: 'text',
      WebkitTextFillColor: 'transparent',
    },
    subheading: {
      fontSize: '24px',
      fontWeight: '400',
      marginBottom: '30px',
      textAlign: 'center',
      color: '#718096',
    },
    inputGroup: {
      marginBottom: '20px',
      position: 'relative',
    },
    input: {
      width: '100%',
      padding: '16px 20px',
      borderRadius: '12px',
      border: '1px solid #e2e8f0',
      fontSize: '18px',
      background: '#f8fafc',
      color: '#2d3748',
      outline: 'none',
      transition: 'all 0.3s ease',
      boxSizing: 'border-box',
    },
    inputFocus: {
      borderColor: '#1479ec',
      boxShadow: '0 0 0 3px rgba(20, 121, 236, 0.1)',
    },
    button: {
      width: '100%',
      padding: '16px',
      borderRadius: '12px',
      border: 'none',
      fontWeight: '600',
      fontSize: '18px',
      background: 'linear-gradient(90deg, #1479ec, #04aeee)',
      color: 'white',
      cursor: 'pointer',
      marginTop: '10px',
      transition: 'all 0.3s ease',
      boxShadow: '0 4px 6px rgba(20, 121, 236, 0.2)',
    },
    buttonHover: {
      transform: 'translateY(-2px)',
      boxShadow: '0 6px 12px rgba(20, 121, 236, 0.25)',
    },
    disabledButton: {
      opacity: 0.7,
      cursor: 'not-allowed',
      transform: 'none',
      boxShadow: 'none',
    },
    errorMessage: {
      marginTop: '12px',
      color: '#e53e3e',
      fontSize: '18px',
      padding: '8px 12px',
      backgroundColor: '#fed7d7',
      borderRadius: '8px',
    },
    successMessage: {
      marginTop: '12px',
      color: '#38a169',
      fontSize: '14px',
      padding: '8px 12px',
      backgroundColor: '#f0fff4',
      borderRadius: '8px',
    },
    linkText: {
      marginTop: '20px',
      textAlign: 'center',
      fontSize: '20px',
      color: '#718096',
    },
    link: {
      color: '#1479ec',
      textDecoration: 'none',
      fontWeight: '900',
      transition: 'color 0.2s ease',
    },
    linkHover: {
      color: '#04aeee',
    },
    forgotPasswordOverlay: {
      position: 'fixed',
      top: 0,
      left: 0,
      right: 0,
      bottom: 0,
      backgroundColor: 'rgba(0, 0, 0, 0.7)',
      display: 'flex',
      justifyContent: 'center',
      alignItems: 'center',
      zIndex: 100,
      backdropFilter: 'blur(5px)',
    },
    forgotPasswordCard: {
      background: '#ffffff',
      borderRadius: '16px',
      padding: '30px',
      width: '90%',
      maxWidth: '450px',
      boxShadow: '0 20px 60px rgba(0,0,0,0.2)',
      position: 'relative',
    },
    closeButton: {
      position: 'absolute',
      top: '15px',
      right: '20px',
      background: 'none',
      border: 'none',
      fontSize: '24px',
      cursor: 'pointer',
      color: '#718096',
      transition: 'color 0.2s ease',
    },
    closeButtonHover: {
      color: '#2d3748',
    },
    passwordRequirements: {
      fontSize: '12px',
      color: '#718096',
      marginTop: '5px',
    },
    emailDisplay: {
      padding: '12px 16px',
      backgroundColor: '#edf2f7',
      borderRadius: '8px',
      marginBottom: '20px',
      fontSize: '14px',
    },
    emailText: {
      fontWeight: '600',
      color: '#2d3748',
    },
  };

  const [hoverStates, setHoverStates] = useState({
    loginButton: false,
    forgotPasswordLink: false,
    closeButton: false,
    resetButton: false,
    signupLink: false,
  });

  const handleHover = (element, isHovered) => {
    setHoverStates(prev => ({ ...prev, [element]: isHovered }));
  };

  const [focusedInput, setFocusedInput] = useState(null);

  return (
    <div>
      <div style={styles.page}>
        <style>
          {`
            ::placeholder {
              color: #a0aec0;
            }
            input:focus {
              border-color: #1479ec !important;
              box-shadow: 0 0 0 3px rgba(20, 121, 236, 0.1) !important;
            }
          `}
        </style>

        <div style={styles.card}>
          <h2 style={styles.heading}>Welcome Back 👋</h2>
          <p style={styles.subheading}>Sign in to continue your journey</p>

          <form onSubmit={handleSubmit}>
            <div style={styles.inputGroup}>
              <input
                type="email"
                name="email"
                placeholder="Email Address"
                value={formData.email}
                onChange={handleChange}
                onFocus={() => setFocusedInput('email')}
                onBlur={() => setFocusedInput(null)}
                style={{
                  ...styles.input,
                  ...(focusedInput === 'email' ? styles.inputFocus : {})
                }}
                required
              />
            </div>

            <div style={styles.inputGroup}>
              <input
                type="password"
                name="password"
                placeholder="Password"
                value={formData.password}
                onChange={handleChange}
                onFocus={() => setFocusedInput('password')}
                onBlur={() => setFocusedInput(null)}
                style={{
                  ...styles.input,
                  ...(focusedInput === 'password' ? styles.inputFocus : {})
                }}
                required
              />
            </div>

            {error && <div style={styles.errorMessage}>{error}</div>}
            {accountStatusError && <div style={styles.errorMessage}>{accountStatusError}</div>}

            <button
              type="submit"
              style={{
                ...styles.button,
                ...(hoverStates.loginButton ? styles.buttonHover : {}),
                ...(isLoading ? styles.disabledButton : {})
              }}
              disabled={isLoading}
              onMouseEnter={() => handleHover('loginButton', true)}
              onMouseLeave={() => handleHover('loginButton', false)}
            >
              {isLoading ? 'Loading...' : 'Login'}
            </button>

            <div style={styles.linkText}>
              <a 
                href="#"
                style={{ ...styles.link, ...(hoverStates.forgotPasswordLink ? styles.linkHover : {}) }}
                onClick={(e) => {
                  e.preventDefault();
                  if (!formData.email) { setError("Please enter your email first"); return; }
                  setShowForgotPassword(true);
                }}
                onMouseEnter={() => handleHover('forgotPasswordLink', true)}
                onMouseLeave={() => handleHover('forgotPasswordLink', false)}
              >
                Forgot password?
              </a>
            </div>

            <div style={styles.linkText}>
              Don't have an account?{' '}
              <Link
                to="/signup"
                style={{ ...styles.link, ...(hoverStates.signupLink ? styles.linkHover : {}) }}
                onMouseEnter={() => handleHover('signupLink', true)}
                onMouseLeave={() => handleHover('signupLink', false)}
              >
                Sign Up →
              </Link>
            </div>
          </form>
        </div>

        {showForgotPassword && (
          <div style={styles.forgotPasswordOverlay}>
            <div style={styles.forgotPasswordCard}>
              <button
                style={{ ...styles.closeButton, ...(hoverStates.closeButton ? styles.closeButtonHover : {}) }}
                onClick={() => {
                  setShowForgotPassword(false);
                  setForgotPasswordData({ newPassword: '', confirmPassword: '' });
                  setForgotPasswordError('');
                }}
                onMouseEnter={() => handleHover('closeButton', true)}
                onMouseLeave={() => handleHover('closeButton', false)}
              >
                ×
              </button>

              <h2 style={{ ...styles.heading, marginBottom: '20px' }}>Reset Password</h2>

              <div style={styles.emailDisplay}>
                Resetting password for: <span style={styles.emailText}>{formData.email}</span>
              </div>

              {forgotPasswordSuccess ? (
                <div style={styles.successMessage}>
                  Password updated successfully! Redirecting to login...
                </div>
              ) : (
                <form onSubmit={handleForgotPasswordSubmit}>
                  <div style={styles.inputGroup}>
                    <input
                      type="password"
                      name="newPassword"
                      placeholder="New Password"
                      value={forgotPasswordData.newPassword}
                      onChange={handleForgotPasswordChange}
                      onFocus={() => setFocusedInput('newPassword')}
                      onBlur={() => setFocusedInput(null)}
                      style={{ ...styles.input, ...(focusedInput === 'newPassword' ? styles.inputFocus : {}) }}
                      required
                    />
                    <div style={styles.passwordRequirements}>Must be at least 6 characters</div>
                  </div>

                  <div style={styles.inputGroup}>
                    <input
                      type="password"
                      name="confirmPassword"
                      placeholder="Confirm New Password"
                      value={forgotPasswordData.confirmPassword}
                      onChange={handleForgotPasswordChange}
                      onFocus={() => setFocusedInput('confirmPassword')}
                      onBlur={() => setFocusedInput(null)}
                      style={{ ...styles.input, ...(focusedInput === 'confirmPassword' ? styles.inputFocus : {}) }}
                      required
                    />
                  </div>

                  {forgotPasswordError && <div style={styles.errorMessage}>{forgotPasswordError}</div>}

                  <button
                    type="submit"
                    style={{ ...styles.button, ...(hoverStates.resetButton ? styles.buttonHover : {}), ...(isResetting ? styles.disabledButton : {}) }}
                    disabled={isResetting}
                    onMouseEnter={() => handleHover('resetButton', true)}
                    onMouseLeave={() => handleHover('resetButton', false)}
                  >
                    {isResetting ? 'Updating...' : 'Reset Password'}
                  </button>
                </form>
              )}
            </div>
          </div>
        )}
      </div>
      <Footer />
    </div>
  );
}

export default Login;