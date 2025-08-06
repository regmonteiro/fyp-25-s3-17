// backend/authenticationController.js
const express = require('express');
const jwt = require('jsonwebtoken');
const admin = require('firebase-admin');
const router = express.Router();

const serviceAccount = require('./firebaseServiceAccount.json'); // 🔐 put this in .gitignore

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    databaseURL: "https://allcarefyp25s322-default-rtdb.firebaseio.com",
  });
}

const db = admin.database();

function encodeEmail(email) {
  return email.replace(/[.#$/[\]]/g, '_');
}

router.post('/login', async (req, res) => {
  const { email, password } = req.body;
  const encodedEmail = encodeEmail(email);
  const userRef = db.ref(`Account/${encodedEmail}`);

  try {
    const snapshot = await userRef.once('value');
    if (!snapshot.exists()) {
      return res.status(404).json({ success: false, message: 'No account found with this email.' });
    }

    const user = snapshot.val();

    if (user.password !== password) {
      return res.status(401).json({ success: false, message: 'Incorrect password.' });
    }

    const now = new Date().toISOString();
    await userRef.child('lastLoginDate').set(now);
    await userRef.child('loginLogs').push({ date: now });

    const token = jwt.sign(
      { userId: encodedEmail, userType: user.userType },
      process.env.JWT_SECRET || 'your_secret_key_here',
      { expiresIn: '1h' }
    );

    return res.json({
      success: true,
      token,
      userType: user.userType,
      email: user.email,
      lastLoginDate: now
    });

  } catch (err) {
    console.error("Login error:", err);
    return res.status(500).json({ success: false, message: 'Internal server error' });
  }
});

module.exports = router;
