// controller/announcementController.js
const express = require('express');
const router = express.Router();
const db = require('../firebaseAdmin'); // This gets the admin.database()

// GET announcements
router.get('/', async (req, res) => {
  try {
    const ref = db.ref('Announcements');
    const snapshot = await ref.once('value');

    if (!snapshot.exists()) {
      return res.status(200).json([]);
    }

    const data = snapshot.val();

    // Convert to array
    const announcements = Object.entries(data).map(([id, value]) => ({
      id,
      ...value,
    }));

    // Optional: sort by createdAt (newest first)
    announcements.sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt));

    return res.status(200).json(announcements);
  } catch (error) {
    console.error('Error fetching announcements:', error);
    return res.status(500).json({ message: 'Internal server error' });
  }
});

module.exports = router;
