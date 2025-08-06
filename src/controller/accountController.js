// backend/accountController.js
const express = require('express');
const admin = require('firebase-admin');
const router = express.Router();

// Helper to encode email keys to Firebase paths
function encodeEmail(email) {
  return email.replace(/[.#$/[\]]/g, '_');
}

// Deactivate user account
router.post('/deactivate-account', async (req, res) => {
  const { email } = req.body;

  if (!email) {
    return res.status(400).json({ success: false, message: 'Email is required' });
  }

  const encodedEmail = encodeEmail(email);

  try {
    const userRef = admin.database().ref(`Account/${encodedEmail}`);
    const snapshot = await userRef.once('value');

    if (!snapshot.exists()) {
      return res.status(404).json({ success: false, message: 'User not found' });
    }

    // Update user status to 'Deactivated'
    await userRef.update({ status: 'Deactivated' });

    return res.json({ success: true, message: `Account for ${email} has been deactivated.` });
  } catch (error) {
    console.error('Deactivate account error:', error);
    return res.status(500).json({ success: false, message: 'Server error during deactivation.' });
  }
});

module.exports = router;
