// backend/roleController.js
const express = require('express');
const admin = require('firebase-admin');
const router = express.Router();

const allowedRoles = ['elderly', 'caregiver', 'admin'];

router.post('/assign-role', async (req, res) => {
  const { email, role } = req.body;

  if (!email || !role) {
    return res.status(400).json({ success: false, message: 'Email and role are required' });
  }

  if (!allowedRoles.includes(role)) {
    return res.status(400).json({ success: false, message: 'Invalid role' });
  }

  try {
    const usersRef = admin.firestore().collection('Account');
    const snapshot = await usersRef.where('email', '==', email).get();

    if (snapshot.empty) {
      return res.status(404).json({ success: false, message: 'User not found' });
    }

    const userDoc = snapshot.docs[0];
    await userDoc.ref.update({ userType: role });

    return res.json({ success: true, message: `Role "${role}" assigned to ${email}` });
  } catch (err) {
    console.error('Role assignment error:', err);
    return res.status(500).json({ success: false, message: 'Server error during role assignment' });
  }
});

module.exports = router;
