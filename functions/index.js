const functions = require("firebase-functions");
const admin = require("firebase-admin");
const { getDatabase } = require("firebase-admin/database");
const { getFirestore } = require("firebase-admin/firestore"); // Add Firestore
const { onRequest } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { onValueWritten } = require('firebase-functions/v2/database');
const { onDocumentWritten } = require('firebase-functions/v2/firestore');

const { setGlobalOptions } = require("firebase-functions/v2");

// Track recent syncs to prevent loops
const recentSyncs = new Set();
const SYNC_TIMEOUT = 5000; // 5 seconds

// Set global options for all functions
setGlobalOptions({
  timeoutSeconds: 60,
  memory: "256MiB",
  region: "asia-southeast1", // Make sure this is asia-southeast1
});

// âœ… Initialize Firebase Admin with both databases
if (!admin.apps.length) admin.initializeApp();

// Initialize both databases
const rtdb = getDatabase(); // Realtime Database
const firestore = getFirestore(); // Firestore Database

const VERSION = "1.0.7";

/* ---------------------------------------------------
 ðŸ”„ Hybrid Data Fetching Functions
--------------------------------------------------- */

// Enhanced getUserData that tries both databases
async function getUserDataHybrid(userId, intent = { type: 'both', dateQuery: 'upcoming' }) {
  const start = Date.now();
  
  if (!validateEmail(userId)) return null;

  let userData = null;
  let dataSource = 'unknown';

  // Try Firestore first
  try {
    userData = await getUserDataFromFirestore(userId);
    if (userData) {
      dataSource = 'firestore';
      console.log(`âœ… Found user data in Firestore for: ${userId}`);
    }
  } catch (firestoreError) {
    console.log('Firestore user lookup failed, trying Realtime Database...');
  }

  // If Firestore fails, try Realtime Database
  if (!userData) {
    userData = await getUserData(userId, intent); // Your existing RTDB function
    if (userData) {
      dataSource = 'realtime-db';
      console.log(`âœ… Found user data in Realtime Database for: ${userId}`);
    }
  }

  if (!userData) {
    console.log(`âŒ User not found in either database: ${userId}`);
    return null;
  }

  const userInfo = extractUserInfo(userData);
  const { uid, email } = userInfo;

  if (intent.type === 'user_info' || intent.type === 'caregiver_info' || 
      intent.type === 'learning_resources' || intent.type === 'routines') {
    return { 
      userInfo, 
      appointments: [],
      consultations: [],
      intent,
      dataSource,
      timestamp: new Date().toISOString() 
    };
  }

  let appointments = [];
  let consultations = [];

  // Try to get appointments from both databases
  if (intent.type === 'appointments' || intent.type === 'both') {
    try {
      // Try Firestore first
      appointments = await getAppointmentsFromFirestore(userId, intent.dateQuery);
      if (appointments.length > 0) {
        console.log(`âœ… Found ${appointments.length} appointments in Firestore`);
      } else {
        // Fall back to Realtime Database
        appointments = await getAppointmentsFromRTDB(userId, intent); // You'll need to create this from your existing code
      }
    } catch (error) {
      console.error('Error getting appointments from both databases:', error);
      appointments = await getAppointmentsFromRTDB(userId, intent);
    }
  }

  // Similar approach for consultations, medications, etc.

  return { 
    userInfo, 
    appointments, 
    consultations,
    intent,
    dataSource,
    timestamp: new Date().toISOString() 
  };
}

// Helper function to extract appointments from RTDB (from your existing code)
async function getAppointmentsFromRTDB(userId, intent) {
  // Extract the appointment logic from your existing getUserData function
  const appointmentsSnap = await rtdb.ref("Appointments").get();
  if (!appointmentsSnap.exists()) {
    return [];
  }

  const allAppointments = appointmentsSnap.val();
  const appointmentList = Object.keys(allAppointments).map(key => ({
    id: key,
    type: 'appointment',
    ...allAppointments[key]
  }));

  const userData = await getUserData(userId, { type: 'user_info', subType: 'all' });
  if (!userData) return [];

  const identifiers = [userData.userInfo.uid, userData.userInfo.email];
  const matchedAppointments = appointmentList.filter((appt) => {
    if (!appt || typeof appt !== "object") return false;

    const matches = 
      matchesAnyIdentifier(appt.elderlyId, identifiers) ||
      matchesAnyIdentifier(appt.elderlyIds, identifiers) ||
      matchesAnyIdentifier(appt.assignedTo, identifiers);

    return matches;
  });

  return filterItemsByDate(matchedAppointments, intent.dateQuery, 'date');
}

/* ---------------------------------------------------
 ðŸ”§ Helper Functions
--------------------------------------------------- */
const normalizeEmailForFirebase = (email) =>
  email?.toLowerCase().replace(/\./g, "_") || "";

const validateEmail = (email) =>
  /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);

function matchesAnyIdentifier(field, identifiers = []) {
  if (!field || !identifiers.length) return false;
  
  const identifierSet = new Set();
  identifiers.forEach(id => {
    if (id) {
      const normalized = id.toString().toLowerCase().trim();
      identifierSet.add(normalized);
    }
  });

  if (Array.isArray(field)) {
    return field.some(item => {
      if (!item) return false;
      const normalizedItem = item.toString().toLowerCase().trim();
      return identifierSet.has(normalizedItem);
    });
  }
  
  const normalizedField = field.toString().toLowerCase().trim();
  return identifierSet.has(normalizedField);
}

function parseUserIntent(message) {
  if (!message) return { type: 'appointments', dateQuery: 'upcoming' };
  
  const lowerMessage = message.toLowerCase().trim();
  
  if (lowerMessage.includes('who are you') || lowerMessage.includes('what is your name')|| lowerMessage.includes('Introduce yourself')|| lowerMessage.includes('tell me about yourself')) {
    return { type: 'bot_info' };
  }
  
  if (
  lowerMessage.includes('who am i') ||
  lowerMessage.includes('my name') ||
  lowerMessage.includes('name') ||
  lowerMessage.includes('what is my name') ||
  lowerMessage.includes('tell me my name') ||
  lowerMessage.includes('introduce myself') ||
  lowerMessage.includes('do you know my name') ||
  lowerMessage.includes('can you tell my name') ||
  lowerMessage.includes('say my name') ||
  lowerMessage.includes('remember my name') ||
  lowerMessage.match(/\bwhat'?s my name\b/)
) {
  return { type: 'user_info', subType: 'name' };
}

  
  if (lowerMessage.includes('how old') || lowerMessage.includes('my age') || lowerMessage.includes('what is my age')|| lowerMessage.includes('tell me my age')|| lowerMessage.includes('how old am I')) {
    return { type: 'user_info', subType: 'age' };
  }
  
  if (lowerMessage.includes('medical condition') || lowerMessage.includes('health problem') || lowerMessage.includes('my condition')) {
    return { type: 'user_info', subType: 'medical' };
  }
  
  if (lowerMessage.includes('contact') || lowerMessage.includes('phone') || lowerMessage.includes('number')||lowerMessage.includes('my contact')|| lowerMessage.includes('how can people reach me')|| lowerMessage.includes('what is my phone number')) {
    return { type: 'user_info', subType: 'contact' };
  }
  
  if (lowerMessage.includes('address') || lowerMessage.includes('where do i live') || lowerMessage.includes('my address') || lowerMessage.includes('what is my address')|| lowerMessage.includes('tell me my location')|| lowerMessage.includes('where am i located')|| lowerMessage.includes('my location')) {
    return { type: 'user_info', subType: 'address' };
  }
  
  if (lowerMessage.includes('emergency') || lowerMessage.includes('emergency contact')) {
    return { type: 'user_info', subType: 'emergency' };
  }
  
  if (lowerMessage.includes('my info') || lowerMessage.includes('information about me') || lowerMessage.includes('profile')||lowerMessage.includes('my details')|| lowerMessage.includes('tell me about myself details')|| lowerMessage.includes('what do you know about me')|| lowerMessage.includes('give me my information')) {
    return { type: 'user_info', subType: 'all' };
  }
  
  if (lowerMessage.includes('caregiver') || 
      lowerMessage.includes('who is taking care of me') || 
      lowerMessage.includes('who helps me') ||
      lowerMessage.includes('my caretaker') ||
      lowerMessage.includes('who looks after me') ||
      lowerMessage.includes('who is my caregiver')) {
    return { type: 'caregiver_info' };
  }
  
  if (lowerMessage.includes('my routines') || 
      lowerMessage.includes('assigned routines') ||
      lowerMessage.includes('care routines') ||
      lowerMessage.includes('daily routines') ||
      lowerMessage.includes('my care routines') ||
      lowerMessage.includes('what are my routines') ||
      lowerMessage.includes('show my routines') ||
      lowerMessage.includes('routine schedule') ||
      lowerMessage.includes('care schedule') ||
      lowerMessage.includes('daily schedule') && !lowerMessage.includes('appointment')) {
    return { type: 'routines', dateQuery: parseDateQuery(message) };
  }
  
  if (lowerMessage.includes('activities preferences') || 
      lowerMessage.includes('activity preferences') ||
      lowerMessage.includes('my activities preferences') ||
      lowerMessage.includes('what are my activity preferences') ||
      lowerMessage.includes('activity interests') ||
      lowerMessage.includes('my activity interests') ||
      lowerMessage.includes('what activities do i like') ||
      lowerMessage.includes('preferred activities') ||
      lowerMessage.includes('my preferred activities') ||
      lowerMessage.includes('what is my activities preferences') ||
      lowerMessage.includes('show my activities preferences')) {
    return { type: 'activities_preferences' };
  }

  if (lowerMessage.includes('preferences') || 
      lowerMessage.includes('my preferences') || 
      lowerMessage.includes('user preferences') ||
      lowerMessage.includes('my interests') ||
      lowerMessage.includes('what i like') ||
      lowerMessage.includes('my favorite') ||
      lowerMessage.includes('show me my preferences')) {
    return { type: 'user_preferences' };
  }
 
  if (lowerMessage.includes('today schedule') || 
      lowerMessage.includes("today's schedule") ||
      lowerMessage.includes('my schedule today') ||
      lowerMessage.includes('what do i have today') ||
      lowerMessage.includes('today agenda') ||
      lowerMessage.includes("today's agenda") ||
      lowerMessage.includes('my day today') ||
      lowerMessage.includes('what is happening today') ||
      lowerMessage.includes('whats on today') ||
      lowerMessage.includes('notify me today') ||
      lowerMessage.includes('today notification')) {
    return { type: 'comprehensive_schedule', dateQuery: 'today' };
  }
  
  if ((lowerMessage.includes('medication') || 
      lowerMessage.includes('medicine') || 
      lowerMessage.includes('pill') ||
      lowerMessage.includes('tablet') ||
      lowerMessage.includes('drug')) && 
      !lowerMessage.includes('appointment')) {
    return { type: 'medications', dateQuery: parseDateQuery(message) };
  }
  
  if ((lowerMessage.includes('reminder') && !lowerMessage.includes('medication') && !lowerMessage.includes('medicine') && !lowerMessage.includes('pill')) ||
      lowerMessage.includes('event') ||
      lowerMessage.includes('remember') && !lowerMessage.includes('medication') ||
      lowerMessage.includes('alert') && !lowerMessage.includes('medication')) {
    return { type: 'reminders', dateQuery: parseDateQuery(message) };
  }

  // CAREGIVER-SPECIFIC INTENTS
  if (lowerMessage.includes('my elderly') || 
      lowerMessage.includes('assigned elderly') ||
      lowerMessage.includes('who am i caring for') ||
      lowerMessage.includes('my patients')) {
    return { type: 'caregiver_elderly' };
  }
  
  if (lowerMessage.includes('my schedule') && 
      (lowerMessage.includes('caregiver') || lowerMessage.includes('consultation'))) {
    return { type: 'caregiver_schedule' };
  }
  
  if ((lowerMessage.includes('elderly') && lowerMessage.includes('appointment')) ||
      (lowerMessage.includes('elderly') && lowerMessage.includes('appointments')) ||
      lowerMessage.includes('elderly appointments') ||
      lowerMessage.includes('appointments of elderly') ||
      lowerMessage.includes('my elderly appointments') ||
      lowerMessage.includes('elderly schedule') ||
      lowerMessage.includes('elderly patient appointments') ||
      lowerMessage.includes('appointments for my elderly')) {
    
    // Check if user wants "all" appointments
    if (lowerMessage.includes('all') || lowerMessage.includes('every')) {
      return { type: 'caregiver_elderly_appointments', dateQuery: 'all' };
    }
    
    return { type: 'caregiver_elderly_appointments', dateQuery: 'upcoming' };
  }

  // In parseUserIntent function, update this section:
if (lowerMessage.includes('elderly all appointments') ||
    lowerMessage.includes('all elderly appointments') ||
    lowerMessage.includes('my elderly all appointments')) {
  return { type: 'caregiver_elderly_appointments', dateQuery: 'all' };
}
// In the parseUserIntent function, update the caregiver consultation section:
if (lowerMessage.includes('my consultations') || 
    lowerMessage.includes('my consultation') ||
    lowerMessage.includes('caregiver consultation') ||
    lowerMessage.includes('caregiver consultations') ||
    lowerMessage.includes('show my consultations')) {
  
  // Check for date filters
  if (lowerMessage.includes('all consultation') || lowerMessage.includes('all consultations')) {
    return { type: 'caregiver_schedule', dateQuery: 'all' };
  } else if (lowerMessage.includes('past consultation') || lowerMessage.includes('past consultations')) {
    return { type: 'caregiver_schedule', dateQuery: 'past' };
  } else if (lowerMessage.includes('today consultation') || lowerMessage.includes('today consultations')) {
    return { type: 'caregiver_schedule', dateQuery: 'today' };
  } else if (lowerMessage.includes('upcoming consultation') || lowerMessage.includes('upcoming consultations')) {
    return { type: 'caregiver_schedule', dateQuery: 'upcoming' };
  }
  
  return { type: 'caregiver_schedule', dateQuery: 'upcoming' };
}

// CAREGIVER CONSULTATION INTENTS - ENHANCED
  if (lowerMessage.includes('my consultations') || 
      lowerMessage.includes('my consultation') ||
      lowerMessage.includes('caregiver consultation') ||
      lowerMessage.includes('caregiver consultations') ||
      lowerMessage.includes('consultation schedule') ||
      lowerMessage.includes('consultations schedule')) {
    
    // Check for date filters
    if (lowerMessage.includes('all consultation') || lowerMessage.includes('all consultations')) {
      return { type: 'caregiver_consultations', dateQuery: 'all' };
    } else if (lowerMessage.includes('past consultation') || lowerMessage.includes('past consultations')) {
      return { type: 'caregiver_consultations', dateQuery: 'past' };
    } else if (lowerMessage.includes('today consultation') || lowerMessage.includes('today consultations')) {
      return { type: 'caregiver_consultations', dateQuery: 'today' };
    } else if (lowerMessage.includes('upcoming consultation') || lowerMessage.includes('upcoming consultations')) {
      return { type: 'caregiver_consultations', dateQuery: 'upcoming' };
    }
    
    return { type: 'caregiver_consultations', dateQuery: 'upcoming' };
  }
  
  // SPECIFIC "ALL CONSULTATIONS" HANDLER
  if (lowerMessage.includes('all consultation') || 
      lowerMessage.includes('all consultations') ||
      (lowerMessage.includes('consultation') && lowerMessage.includes('all'))) {
    return { type: 'caregiver_consultations', dateQuery: 'all' };
  }
  
  // PAST CONSULTATIONS HANDLER
  if (lowerMessage.includes('past consultation') || 
      lowerMessage.includes('past consultations')) {
    return { type: 'caregiver_consultations', dateQuery: 'past' };
  }
// SPECIFIC ELDERLY APPOINTMENTS (like "my Elderly One appointments")
if ((lowerMessage.includes('elderly') && lowerMessage.match(/appointments?$/)) ||
    (lowerMessage.match(/my elderly \w+ appointments?/i))) {
  return { type: 'caregiver_elderly_appointments' };
}// SPECIFIC ELDERLY NAME APPOINTMENT QUERIES
const elderlyNameMatch = lowerMessage.match(/my elderly (\w+) appointments?/i);
if (elderlyNameMatch) {
  return { 
    type: 'caregiver_elderly_appointments', 
    specificElderly: elderlyNameMatch[1].toLowerCase() 
  };
}

// "ELDERLY ALL APPOINTMENTS" SPECIFIC HANDLER
if (lowerMessage.includes('elderly all appointments') ||
    lowerMessage.includes('all elderly appointments') ||
    lowerMessage.includes('my elderly all appointments')) {
  return { type: 'caregiver_elderly_appointments', showAll: true };
}
  
  if (lowerMessage.includes('elderly health') ||
      lowerMessage.includes('health of my elderly') ||
      lowerMessage.includes('elderly medical')) {
    return { type: 'caregiver_elderly_health' };
  }
  
  const dateQuery = parseDateQuery(message);
  
  if (lowerMessage.includes('consultation') || lowerMessage.includes('doctor') || lowerMessage.includes('medical')) {
    return { type: 'consultations', dateQuery };
  }
  
  if (lowerMessage.includes('appointment') || 
      lowerMessage.includes('meeting') || 
      lowerMessage.includes('schedule') ||
      lowerMessage.includes('appointments')) {
    return { type: 'appointments', dateQuery };
  }

  if (lowerMessage.includes('my activities') || 
    lowerMessage.includes("today's activities") ||
    lowerMessage.includes('my activities today') ||
    lowerMessage.includes('what activities do i have') ||
    lowerMessage.includes('my registered activities') ||
    lowerMessage.includes('activities i signed up for') ||
    lowerMessage.includes('my activity schedule') ||
    lowerMessage.includes('what activities am i in') ||
    lowerMessage.includes('show my activities') ||
    lowerMessage.includes('list my activities') ||
    lowerMessage.includes('my joined activities') ||
    lowerMessage.includes('activities i registered for') ||
    lowerMessage.includes('my activity registrations') ||
    lowerMessage.includes('what am i doing today') && lowerMessage.includes('activity')) {
  return { type: 'activities', dateQuery: parseDateQuery(message) };
}

if (lowerMessage.includes('available activities') || 
    lowerMessage.includes('suggested activities') ||
    lowerMessage.includes('find activities') ||
    lowerMessage.includes('browse activities') ||
    lowerMessage.includes('explore activities') ||
    lowerMessage.includes('new activities') ||
    lowerMessage.includes('activity suggestions') ||
    lowerMessage.includes('recommend activities') ||
    lowerMessage.includes('what activities are available') ||
    lowerMessage.includes('show available activities') ||
    lowerMessage.includes('list all activities') ||
    lowerMessage.includes('discover activities')) {
  return { type: 'activities', dateQuery: 'all' };
}

if (lowerMessage.includes('register for activity') || 
    lowerMessage.includes('sign up for activity') ||
    lowerMessage.includes('join activity') ||
    lowerMessage.includes('enroll in activity') ||
    lowerMessage.includes('add me to activity') ||
    lowerMessage.includes('participate in activity')) {
  return { type: 'activity_registration', dateQuery: parseDateQuery(message) };
}
  
  // HEALTH RECOMMENDATIONS INTENTS - ADD THESE
  if (lowerMessage.includes('health recommendation') ||
      lowerMessage.includes('health advice') ||
      lowerMessage.includes('wellness recommendation') ||
      lowerMessage.includes('what should i do for my health') ||
      lowerMessage.includes('health suggestion') ||
      lowerMessage.includes('give me health tips') ||
      lowerMessage.includes('health tips for me')) {
    return { type: 'health_recommendations' };
  }

  if (lowerMessage.includes('health tip') ||
      lowerMessage.includes('wellness tip') ||
      lowerMessage.includes('fitness tip') ||
      lowerMessage.includes('nutrition tip') ||
      lowerMessage.includes('exercise tip') ||
      lowerMessage.includes('mental health tip') ||
      lowerMessage.includes('diet tip') ||
      lowerMessage.includes('eating tip')) {
    
    // Determine category from message
    let category = 'general';
    if (lowerMessage.includes('exercise') || lowerMessage.includes('fitness')) category = 'exercise';
    if (lowerMessage.includes('nutrition') || lowerMessage.includes('diet') || lowerMessage.includes('eating')) category = 'nutrition';
    if (lowerMessage.includes('mental') || lowerMessage.includes('stress')) category = 'mental_health';
    if (lowerMessage.includes('medication')) category = 'medication';
    
    return { type: 'health_tips', category: category };
  }

  // SPECIFIC NUTRITION REQUESTS
  if (lowerMessage.includes('what should i eat') ||
      lowerMessage.includes('healthy food') ||
      lowerMessage.includes('eating healthy') ||
      lowerMessage.includes('nutrition advice') ||
      lowerMessage.includes('diet advice')) {
    return { type: 'health_tips', category: 'nutrition' };
  }

  // EXERCISE SPECIFIC REQUESTS
  if (lowerMessage.includes('exercise advice') ||
      lowerMessage.includes('workout tip') ||
      lowerMessage.includes('physical activity') ||
      lowerMessage.includes('how to exercise')) {
    return { type: 'health_tips', category: 'exercise' };
  }

  // MENTAL HEALTH SPECIFIC REQUESTS
  if (lowerMessage.includes('mental health advice') ||
      lowerMessage.includes('reduce stress') ||
      lowerMessage.includes('feel better') ||
      lowerMessage.includes('anxiety tips')) {
    return { type: 'health_tips', category: 'mental_health' };
  }

  // LEARNING RESOURCES - FIXED SECTION
  const learningKeywords = [
    'learning resource', 'education material', 'study guide', 'learn about',
    'exercise topic', 'exercise topics', 'health topic', 'health topics',
    'technology topic', 'safety topic', 'mental health topic'
  ];
  
  const pointsKeywords = ['my points', 'my score', 'point balance', 'how many points', 'learning points'];
  const rewardKeywords = ['voucher', 'reward', 'redeem points'];
  const streakKeywords = ['my streak', 'daily streak', 'learning streak'];
  
  const isLearningQuery = learningKeywords.some(keyword => lowerMessage.includes(keyword));
  const isPointsQuery = pointsKeywords.some(keyword => lowerMessage.includes(keyword));
  const isRewardQuery = rewardKeywords.some(keyword => lowerMessage.includes(keyword));
  const isStreakQuery = streakKeywords.some(keyword => lowerMessage.includes(keyword));
  
  if (isLearningQuery || isPointsQuery || isRewardQuery || isStreakQuery) {
    return { type: 'learning_resources' };
  }
  
  // SPECIFIC TOPIC QUERIES - ENHANCED
  if (lowerMessage.includes('exercise topic') || 
      lowerMessage.includes('exercise topics') ||
      (lowerMessage.includes('exercise') && 
       !lowerMessage.includes('appointment') && 
       !lowerMessage.includes('routine'))) {
    return { type: 'learning_resources', subType: 'exercise' };
  }
  
  if (lowerMessage.includes('health topic') || 
      lowerMessage.includes('health topics') ||
      (lowerMessage.includes('health') && 
       !lowerMessage.includes('appointment') && 
       !lowerMessage.includes('medical condition') &&
       !lowerMessage.includes('doctor'))) {
    return { type: 'learning_resources', subType: 'health' };
  }
  
  if (lowerMessage.includes('technology topic') || 
      lowerMessage.includes('tech topic') ||
      (lowerMessage.includes('technology') && 
       !lowerMessage.includes('appointment'))) {
    return { type: 'learning_resources', subType: 'technology' };
  }
  
  if (lowerMessage.includes('safety topic') || 
      lowerMessage.includes('safety topics') ||
      (lowerMessage.includes('safety') && 
       !lowerMessage.includes('appointment'))) {
    return { type: 'learning_resources', subType: 'safety' };
  }
  
  if (lowerMessage.includes('my schedule') || 
      lowerMessage.includes('what do i have') || 
      lowerMessage.includes('when is my') ||
      lowerMessage.includes('upcoming events') ||
      lowerMessage.includes('what\'s coming up')) {
    return { type: 'both', dateQuery };
  }
  
  return { type: 'appointments', dateQuery };
}

function parseDateQuery(message) {
  if (!message) return 'upcoming';
  
  const lowerMessage = message.toLowerCase();
  
  if (lowerMessage.includes('today') || lowerMessage.includes('tdy')) {
    return 'today';
  } else if (lowerMessage.includes('tomorrow') || lowerMessage.includes('tmr') || lowerMessage.includes('tmw')) {
    return 'tomorrow';
  } else if (lowerMessage.includes('yesterday')) {
    return 'yesterday';
  } else if (lowerMessage.includes('past') || lowerMessage.includes('previous')) {
    return 'past';
  } else if (lowerMessage.includes('all') || lowerMessage.includes('every')) {
    return 'all';
  } else if (lowerMessage.includes('upcoming') || lowerMessage.includes('future')) {
    return 'upcoming';
  }
  
  const datePatterns = [
    /(january|february|march|april|may|june|july|august|september|october|november|december)\s+(\d{1,2})/i,
    /(\d{1,2})\s+(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)/i,
    /(\d{1,2})\/(\d{1,2})/,
    /(\d{4})-(\d{1,2})-(\d{1,2})/
  ];
  
  for (const pattern of datePatterns) {
    const match = lowerMessage.match(pattern);
    if (match) {
      return `specific:${lowerMessage}`;
    }
  }
  
  return 'upcoming';
}

function filterItemsByDate(items, dateQuery, dateField = 'date') {
  const today = new Date();
  today.setHours(0, 0, 0, 0);
  
  const tomorrow = new Date(today);
  tomorrow.setDate(tomorrow.getDate() + 1);
  
  const yesterday = new Date(today);
  yesterday.setDate(yesterday.getDate() - 1);
  
  switch (dateQuery) {
    case 'today':
      return items.filter(item => {
        if (!item[dateField]) return false;
        const itemDate = new Date(item[dateField]);
        itemDate.setHours(0, 0, 0, 0);
        return itemDate.getTime() === today.getTime();
      });
      
    case 'tomorrow':
      return items.filter(item => {
        if (!item[dateField]) return false;
        const itemDate = new Date(item[dateField]);
        itemDate.setHours(0, 0, 0, 0);
        return itemDate.getTime() === tomorrow.getTime();
      });
      
    case 'yesterday':
      return items.filter(item => {
        if (!item[dateField]) return false;
        const itemDate = new Date(item[dateField]);
        itemDate.setHours(0, 0, 0, 0);
        return itemDate.getTime() === yesterday.getTime();
      });
      
    case 'past':
      return items.filter(item => {
        if (!item[dateField]) return false;
        const itemDate = new Date(item[dateField]);
        itemDate.setHours(0, 0, 0, 0);
        return itemDate < today;
      });
      
    case 'all':
      return items;
      
    case 'upcoming':
    default:
      return items.filter(item => {
        if (!item[dateField]) return false;
        const itemDate = new Date(item[dateField]);
        itemDate.setHours(0, 0, 0, 0);
        return itemDate >= today;
      });
  }
}

function formatDisplayDate(dateStr) {
  if (!dateStr) return 'Unknown date';
  
  try {
    let date;
    
    if (typeof dateStr === 'string') {
      // Handle ISO format with time: "2025-11-09T21:30"
      if (dateStr.includes('T')) {
        // Check if it has timezone info
        if (dateStr.endsWith('Z')) {
          date = new Date(dateStr);
        } else {
          // No timezone - assume local time
          date = new Date(dateStr);
          // If that fails, try adding timezone
          if (isNaN(date.getTime())) {
            date = new Date(dateStr + 'Z');
          }
        }
      } 
      // Simple date format: "2025-11-09"
      else if (dateStr.match(/^\d{4}-\d{2}-\d{2}$/)) {
        date = new Date(dateStr);
      }
      // Fallback - try direct parsing
      else {
        date = new Date(dateStr);
      }
    } else {
      date = new Date(dateStr);
    }
    
    // Check if date is valid
    if (isNaN(date.getTime())) {
      console.log(`âŒ Invalid date: ${dateStr}`);
      return 'Unknown date';
    }
    
    return date.toLocaleDateString('en-US', { 
      weekday: 'long', 
      year: 'numeric', 
      month: 'long', 
      day: 'numeric' 
    });
  } catch (error) {
    console.error(`âŒ Error formatting date: ${dateStr}`, error);
    return 'Unknown date';
  }
}

function formatDisplayTime(timeStr) {
  if (!timeStr) return 'Unknown time';
  
  try {
    if (timeStr.includes('T')) {
      const date = new Date(timeStr);
      return date.toLocaleTimeString('en-US', { 
        hour: '2-digit', 
        minute: '2-digit',
        hour12: true 
      });
    } else {
      const [hours, minutes] = timeStr.split(':');
      const hour = parseInt(hours);
      const ampm = hour >= 12 ? 'PM' : 'AM';
      const displayHour = hour % 12 || 12;
      return `${displayHour}:${minutes} ${ampm}`;
    }
  } catch (error) {
    return timeStr;
  }
}

function calculateAge(birthDate) {
  if (!birthDate) return null;
  
  try {
    let birth;
    if (typeof birthDate === 'string') {
      birth = new Date(birthDate);
    } else if (birthDate instanceof Date) {
      birth = birthDate;
    } else {
      birth = new Date(birthDate);
    }
    
    if (isNaN(birth.getTime())) {
      return null;
    }
    
    const today = new Date();
    let age = today.getFullYear() - birth.getFullYear();
    const monthDiff = today.getMonth() - birth.getMonth();
    
    if (monthDiff < 0 || (monthDiff === 0 && today.getDate() < birth.getDate())) {
      age--;
    }
    
    return age;
  } catch (error) {
    return null;
  }
}

/* ---------------------------------------------------
 ðŸ‘¤ Extract User Info
--------------------------------------------------- */
function extractUserInfo(userData) {
  if (!userData) return { 
    name: "", 
    firstName: "", 
    lastName: "", 
    email: "", 
    userType: "", 
    uid: "",
    age: null,
    birthDate: null,
    medicalConditions: [],
    phone: "",
    address: "",
    emergencyContact: ""
  };
  
  const firstName = userData.firstname || userData.firstName || "";
  const lastName = userData.lastname || userData.lastName || "";
  const email = userData.email || "";
  const userType = userData.userType || "";
  const uid = userData.uid || "";
  
  let birthDate = null;
  if (userData.dob) {
    birthDate = userData.dob;
  } else if (userData.birthDate) {
    birthDate = userData.birthDate;
  } else if (userData.dateOfBirth) {
    birthDate = userData.dateOfBirth;
  }
  
  const age = calculateAge(birthDate);
  const medicalConditions = userData.medicalConditions || userData.conditions || [];
  const phone = userData.phone || userData.phoneNumber || userData.mobile || userData.phoneNum || "";
  const address = userData.address || userData.homeAddress || "";
  const emergencyContact = userData.emergencyContact || userData.emergencyPhone || "";
  
  let name = "";
  if (firstName && lastName) {
    name = `${firstName} ${lastName}`;
  } else if (firstName) {
    name = firstName;
  } else if (lastName) {
    name = lastName;
  } else {
    name = email ? email.split("@")[0] : "Friend";
  }
  
  return { 
    name, 
    firstName, 
    lastName, 
    email, 
    userType, 
    uid,
    age,
    birthDate,
    medicalConditions,
    phone,
    address,
    emergencyContact
  };
}

/* ---------------------------------------------------
 ðŸ“… COMPREHENSIVE SCHEDULE FUNCTIONS
--------------------------------------------------- */
async function getComprehensiveSchedule(userId, dateQuery = 'today') {
  try {
    const [appointments, consultations, medications, reminders, assignedRoutines, activities] = await Promise.all([
      getAppointmentsForSchedule(userId, dateQuery),
      getConsultationsForSchedule(userId, dateQuery),
      getMedicationReminders(userId, dateQuery),
      getEventReminders(userId, dateQuery),
      getAssignedRoutinesForSchedule(userId, dateQuery),
      getActivitiesForSchedule(userId, dateQuery)
    ]);
    
    const allEvents = [
      ...appointments.map(apt => ({ ...apt, type: 'appointment', sortTime: `${apt.date}T${apt.time || '00:00'}` })),
      ...consultations.map(cons => ({ ...cons, type: 'consultation', sortTime: `${cons.appointmentDate || cons.date}T${cons.time || '00:00'}` })),
      ...medications.map(med => ({ ...med, type: 'medication', sortTime: `${med.date}T${med.reminderTime || '00:00'}` })),
      ...reminders.map(rem => ({ ...rem, type: 'reminder', sortTime: rem.startTime || '00:00' })),
      ...assignedRoutines.map(routine => ({ ...routine, type: 'assigned_routine', sortTime: `${routine.date}T${routine.time || '00:00'}` })),
      ...activities.map(activity => ({ ...activity, type: 'activity', sortTime: `${activity.date}T${activity.time || '10:00'}` }))
    ];
    
    const sortedEvents = allEvents.sort((a, b) => {
      return new Date(a.sortTime || '9999-12-31') - new Date(b.sortTime || '9999-12-31');
    });
    
    return {
      appointments,
      consultations,
      medications,
      reminders,
      assignedRoutines,
      activities,
      allEvents: sortedEvents
    };
    
  } catch (error) {
    return {
      appointments: [],
      consultations: [],
      medications: [],
      reminders: [],
      assignedRoutines: [],
      activities: [],
      allEvents: []
    };
  }
}

async function getAppointmentsForSchedule(userId, dateQuery = 'today') {
  try {
    const userData = await getUserData(userId, { type: 'appointments', dateQuery });
    return userData?.appointments || [];
  } catch (error) {
    return [];
  }
}

async function getConsultationsForSchedule(userId, dateQuery = 'today') {
  try {
    const userData = await getUserData(userId, { type: 'consultations', dateQuery });
    return userData?.consultations || [];
  } catch (error) {
    return [];
  }
}

async function getAssignedRoutinesForSchedule(userId, dateQuery = 'today') {
  try {
    const userData = await getUserData(userId, { type: 'user_info', subType: 'all' });
    if (!userData) {
      return [];
    }
    
    const userUid = userData.userInfo.uid;
    const assignedRef = rtdb.ref(`AssignedRoutines/${userUid}`);
    const snapshot = await assignedRef.get();
    
    if (!snapshot.exists()) {
      return [];
    }
    
    const data = snapshot.val();
    let routines = [];
    
    for (const [routineId, routine] of Object.entries(data)) {
      if (routine.isActive !== false && routine.templateData) {
        const template = routine.templateData;
        
        if (template.items && Array.isArray(template.items)) {
          template.items.forEach((item, index) => {
            if (item.time && item.title) {
              const today = new Date();
              const todayStr = today.toISOString().split('T')[0];
              
              routines.push({
                id: `${routineId}_${index}`,
                type: 'assigned_routine',
                title: item.title,
                description: item.description || template.description || 'Daily care routine',
                time: item.time,
                date: todayStr,
                duration: item.duration || '15 mins',
                frequency: 'daily',
                category: item.type || 'care',
                templateName: template.name,
                assignedBy: routine.assignedBy,
                assignedAt: routine.assignedAt,
                isActive: routine.isActive,
                elderlyId: routine.elderlyId,
                templateId: routineId,
                ...routine
              });
            }
          });
        } else {
          const today = new Date();
          const todayStr = today.toISOString().split('T')[0];
          
          routines.push({
            id: routineId,
            type: 'assigned_routine',
            title: template.name,
            description: template.description || 'Daily care routine',
            time: '09:00',
            date: todayStr,
            duration: '30 mins',
            frequency: 'daily',
            category: 'care',
            assignedBy: routine.assignedBy,
            assignedAt: routine.assignedAt,
            isActive: routine.isActive,
            elderlyId: routine.elderlyId,
            templateId: routineId,
            ...routine
          });
        }
      }
    }
    
    const filteredRoutines = filterItemsByDate(routines, dateQuery, 'date');
    return filteredRoutines;
    
  } catch (error) {
    return [];
  }
}

async function getElderlyUserData(elderlyId) {
  try {
    const accountsRef = rtdb.ref('Account');
    const accountsSnap = await accountsRef.get();
    
    if (accountsSnap.exists()) {
      const accounts = accountsSnap.val();
      
      for (const [key, account] of Object.entries(accounts)) {
        if (account.uid === elderlyId || 
            account.email === elderlyId || 
            key === elderlyId ||
            key === normalizeEmailForFirebase(elderlyId)) {
          
          return {
            name: `${account.firstname || ''} ${account.lastname || ''}`.trim() || 'Elderly User',
            email: account.email,
            userType: account.userType
          };
        }
      }
    }
    
    return null;
  } catch (error) {
    return null;
  }
}

/* ---------------------------------------------------
 ðŸ’Š Medication Reminder Functions
--------------------------------------------------- */
async function getMedicationReminders(userId, dateQuery = 'today') {
  try {
    const allMedsRef = rtdb.ref('medicationReminders');
    const allMedsSnapshot = await allMedsRef.get();
    
    if (!allMedsSnapshot.exists()) {
      return [];
    }

    const allMedsData = allMedsSnapshot.val();
    const allUserKeys = Object.keys(allMedsData);
    
    const possibleKeys = [
      userId.toLowerCase().replace(/@/g, '_at_').replace(/\./g, '_') + ',com',
      userId.toLowerCase().replace(/\./g, '_'),
      userId.toLowerCase().replace(/@/g, '_at_').replace(/\./g, ','),
      userId
    ];
    
    let correctKey = null;
    for (const tryKey of possibleKeys) {
      if (allUserKeys.includes(tryKey)) {
        correctKey = tryKey;
        break;
      }
    }

    if (!correctKey) {
      for (const dbKey of allUserKeys) {
        const normalizedUserId = userId.toLowerCase().replace(/[\.@]/g, '');
        const normalizedDbKey = dbKey.toLowerCase().replace(/[\.@,_]/g, '');
        if (normalizedDbKey.includes(normalizedUserId)) {
          correctKey = dbKey;
          break;
        }
      }
    }

    if (!correctKey) {
      return [];
    }

    const path = `medicationReminders/${correctKey}`;
    const medsRef = rtdb.ref(path);
    const snapshot = await medsRef.get();

    if (!snapshot.exists()) {
      return [];
    }

    const data = snapshot.val();
    const medications = Object.keys(data).map(medKey => ({
      id: medKey,
      type: 'medication',
      ...data[medKey]
    }));

    const today = new Date();
    today.setHours(0, 0, 0, 0);
    
    const filteredMeds = medications.filter(med => {
      if (!med.date) return false;

      try {
        const medDate = new Date(med.date);
        medDate.setHours(0, 0, 0, 0);
        
        let shouldInclude = false;
        
        switch (dateQuery) {
          case 'today':
            shouldInclude = medDate.getTime() === today.getTime();
            break;
          case 'tomorrow':
            const tomorrow = new Date(today);
            tomorrow.setDate(tomorrow.getDate() + 1);
            shouldInclude = medDate.getTime() === tomorrow.getTime();
            break;
          case 'all':
            shouldInclude = true;
            break;
          case 'upcoming':
          default:
            shouldInclude = medDate >= today;
            break;
        }
        
        return shouldInclude;
        
      } catch (error) {
        return false;
      }
    });

    const sortedMeds = filteredMeds.sort((a, b) => {
      if (a.isCompleted !== b.isCompleted) {
        return a.isCompleted ? 1 : -1;
      }
      const timeA = a.reminderTime || '00:00';
      const timeB = b.reminderTime || '00:00';
      return timeA.localeCompare(timeB);
    });

    return sortedMeds;

  } catch (error) {
    return [];
  }
}

function generateMedicationResponse(userInfo, medications, dateQuery) {
  const timeContext = getTimeContext(dateQuery).replace('appointments', 'medications');
  
  if (medications.length === 0) {
    return `You don't have any ${timeContext}, ${userInfo.name}.`;
  }
  
  let response = `Here are your ${timeContext}, ${userInfo.name}:\n\n`;
  
  medications.forEach((med, index) => {
    const status = med.isCompleted ? 'âœ… Taken' : 'â° Pending';
    const dosage = med.dosage ? ` (${med.dosage})` : '';
    const quantity = med.quantity ? `, ${med.quantity} pill${med.quantity > 1 ? 's' : ''}` : '';
    const medicationName = med.medicationName || 'Unnamed Medication';
    const reminderTime = med.reminderTime ? formatDisplayTime(med.reminderTime) : 'No time specified';
    
    response += `${index + 1}. ðŸ’Š **${medicationName}**${dosage}${quantity}\n`;
    response += `   â° ${reminderTime} â€¢ ${status}\n`;
    
    if (med.notes) {
      response += `   ðŸ“ ${med.notes}\n`;
    }
    
    response += `\n`;
  });
  
  const pendingCount = medications.filter(med => !med.isCompleted).length;
  if (pendingCount > 0 && (dateQuery === 'today' || dateQuery === 'upcoming')) {
    response += `\nYou have ${pendingCount} medication${pendingCount > 1 ? 's' : ''} to take. Remember to take them on time!`;
  }
  
  return response;
}

/* ---------------------------------------------------
 â° Event Reminder Functions
--------------------------------------------------- */
async function getEventReminders(userId, dateQuery = 'upcoming') {
  try {
    const underscoreKey = normalizeEmailForFirebase(userId);
    const commaKey = userId.toLowerCase().replace(/\./g, '_').replace('@', '_at_') + ',com';
    
    const possiblePaths = [
      `reminders/${underscoreKey}`,
      `reminders/${commaKey}`,
      `reminders/${userId.replace(/[\.@]/g, '_')}`,
      `reminders/${userId}`,
    ];
    
    let reminders = [];
    
    for (const path of possiblePaths) {
      const remindersRef = rtdb.ref(path);
      const snapshot = await remindersRef.get();
      
      if (snapshot.exists()) {
        const data = snapshot.val();
        
        reminders = Object.keys(data).map(key => ({
          id: key,
          type: 'reminder',
          ...data[key]
        }));
        break;
      }
    }
    
    if (reminders.length === 0) {
      return [];
    }
    
    const filteredReminders = filterItemsByDate(reminders, dateQuery, 'startTime');
    const sortedReminders = filteredReminders.sort((a, b) => {
      const timeA = a.startTime || '00:00';
      const timeB = b.startTime || '00:00';
      return new Date(timeA) - new Date(timeB);
    });
    
    return sortedReminders;
    
  } catch (error) {
    return [];
  }
}

function generateEventRemindersResponse(userInfo, reminders, dateQuery) {
  const timeContext = getTimeContext(dateQuery).replace('appointments', 'reminders');
  
  if (reminders.length === 0) {
    return `You don't have any ${timeContext}, ${userInfo.name}.`;
  }
  
  let response = `Here are your ${timeContext}, ${userInfo.name}:\n\n`;
  
  reminders.forEach((reminder, index) => {
    const displayTime = formatDisplayTime(reminder.startTime);
    const duration = reminder.duration ? ` (${reminder.duration} min)` : '';
    
    response += `${index + 1}. â° **${reminder.title}**${duration}\n`;
    response += `   â° ${displayTime}\n`;
    
    if (reminder.description) {
      response += `   ðŸ“ ${reminder.description}\n`;
    }
    
    response += `\n`;
  });
  
  return response;
}

/* ---------------------------------------------------
 ðŸ‘¨â€âš•ï¸ Caregiver Functions
--------------------------------------------------- */
function getCaregiversForElderly(elderlyEmail, elderlyUid, accounts) {
  const caregivers = [];
  const identifiers = [elderlyUid, elderlyEmail, normalizeEmailForFirebase(elderlyEmail)];
  
  Object.entries(accounts).forEach(([accountKey, account]) => {
    if (account.userType === "caregiver") {
      let isMatch = false;
      let matchReason = "";
      
      if (account.elderlyId && identifiers.includes(account.elderlyId)) {
        isMatch = true;
        matchReason = `elderlyId: ${account.elderlyId}`;
      }
      
      if (account.elderlyIds && Array.isArray(account.elderlyIds)) {
        const elderlyIdsMatch = account.elderlyIds.some(id => identifiers.includes(id));
        if (elderlyIdsMatch) {
          isMatch = true;
          matchReason = `elderlyIds array: ${account.elderlyIds.join(', ')}`;
        }
      }
      
      if (account.linkedElders && Array.isArray(account.linkedElders)) {
        const linkedEldersMatch = account.linkedElders.some(id => identifiers.includes(id));
        if (linkedEldersMatch) {
          isMatch = true;
          matchReason = `linkedElders: ${account.linkedElders.join(', ')}`;
        }
      }
      
      if (account.linkedElderUids && Array.isArray(account.linkedElderUids)) {
        const linkedElderUidsMatch = account.linkedElderUids.some(id => identifiers.includes(id));
        if (linkedElderUidsMatch) {
          isMatch = true;
          matchReason = `linkedElderUids: ${account.linkedElderUids.join(', ')}`;
        }
      }
      
      if (account.uidOfElder && identifiers.includes(account.uidOfElder)) {
        isMatch = true;
        matchReason = `uidOfElder: ${account.uidOfElder}`;
      }
      
      if (account.assignedElders && Array.isArray(account.assignedElders)) {
        const assignedEldersMatch = account.assignedElders.some(id => identifiers.includes(id));
        if (assignedEldersMatch) {
          isMatch = true;
          matchReason = `assignedElders: ${account.assignedElders.join(', ')}`;
        }
      }
      
      if (isMatch) {
        caregivers.push({
          key: accountKey,
          email: account.email,
          firstname: account.firstname,
          lastname: account.lastname,
          phoneNum: account.phoneNum,
          matchReason: matchReason,
          ...account
        });
      }
    }
  });
  
  return caregivers;
}

async function getCaregiverInfo(userId) {
  if (!validateEmail(userId)) return null;

  const userData = await getUserData(userId, { type: 'user_info', subType: 'all' });
  if (!userData) {
    return null;
  }

  const { userInfo } = userData;
  
  const accountsSnap = await rtdb.ref("Account").get();
  if (!accountsSnap.exists()) {
    return { userInfo, caregivers: [] };
  }

  const accounts = accountsSnap.val();
  const caregivers = getCaregiversForElderly(userInfo.email, userInfo.uid, accounts);
  
  return { userInfo, caregivers };
}

function generateCaregiverResponse(userInfo, caregivers) {
  if (caregivers.length === 0) {
    return `I don't see any caregivers assigned to you in my records, ${userInfo.name}. If you need assistance setting up caregiver connections, please contact support.`;
  }
  
  if (caregivers.length === 1) {
    const caregiver = caregivers[0];
    return `Your caregiver is ${caregiver.firstname} ${caregiver.lastname}. You can contact them at ${caregiver.email}${caregiver.phoneNum ? ` or ${caregiver.phoneNum}` : ''}.`;
  }
  
  let response = `You have ${caregivers.length} caregivers assigned to you, ${userInfo.name}:\n\n`;
  
  caregivers.forEach((caregiver, index) => {
    response += `${index + 1}. ${caregiver.firstname} ${caregiver.lastname}\n`;
    response += `    ${caregiver.email}\n`;
    if (caregiver.phoneNum) {
      response += `   ðŸ“ž ${caregiver.phoneNum}\n`;
    }
    response += `\n`;
  });
  
  return response;
}
/* ---------------------------------------------------
 ðŸ‘¨â€âš•ï¸ CAREGIVER-SPECIFIC FUNCTIONS
--------------------------------------------------- */

// Enhanced function to get elderly data from various identifier types
const getElderlyDataByIdentifier = async (elderlyIdentifier) => {
  try {
    let elderlyKey;
    let elderlyRef;
    
    // Check if identifier is an email (contains @)
    if (elderlyIdentifier.includes('@')) {
      elderlyKey = normalizeEmailForFirebase(elderlyIdentifier);
      elderlyRef = rtdb.ref(`Account/${elderlyKey}`);
    } else {
      // Identifier is likely a UID, search through all accounts
      elderlyRef = rtdb.ref('Account');
    }
    
    const snapshot = await elderlyRef.get();
    
    if (!snapshot.exists()) {
      console.warn(`No data found for elderly identifier: ${elderlyIdentifier}`);
      return { 
        idKey: elderlyIdentifier.includes('@') ? elderlyKey : elderlyIdentifier,
        identifier: elderlyIdentifier,
        firstname: "Unknown",
        lastname: "User",
        email: elderlyIdentifier.includes('@') ? elderlyIdentifier : 'Unknown',
        error: true 
      };
    }
    
    let elderlyData;
    
    if (elderlyIdentifier.includes('@')) {
      // Direct lookup by email key
      elderlyData = snapshot.val();
    } else {
      // Search for UID in all accounts
      const allAccounts = snapshot.val();
      elderlyData = Object.values(allAccounts).find(account => 
        account.uid === elderlyIdentifier || account.email === elderlyIdentifier
      );
      
      if (!elderlyData) {
        console.warn(`No account found with UID: ${elderlyIdentifier}`);
        return { 
          idKey: elderlyIdentifier,
          identifier: elderlyIdentifier,
          firstname: "Unknown",
          lastname: "User",
          email: 'Unknown',
          error: true 
        };
      }
    }
    
    return { 
      idKey: elderlyIdentifier.includes('@') ? elderlyKey : elderlyIdentifier,
      ...elderlyData, 
      identifier: elderlyIdentifier,
      email: elderlyData.email || (elderlyIdentifier.includes('@') ? elderlyIdentifier : 'Unknown')
    };
  } catch (error) {
    console.error(`Error fetching data for elderly ${elderlyIdentifier}:`, error);
    return { 
      idKey: elderlyIdentifier.includes('@') ? normalizeEmailForFirebase(elderlyIdentifier) : elderlyIdentifier,
      identifier: elderlyIdentifier,
      firstname: "Unknown",
      lastname: "User",
      email: elderlyIdentifier.includes('@') ? elderlyIdentifier : 'Unknown',
      error: true 
    };
  }
};

// Get caregiver's assigned elderly with full info
async function getCaregiverAssignedElderly(caregiverUserId) {
  try {
    const caregiverData = await getUserData(caregiverUserId, { type: 'user_info', subType: 'all' });
    if (!caregiverData) {
      return { success: false, error: "Caregiver not found", elderly: [] };
    }

    const accountsSnap = await rtdb.ref("Account").get();
    if (!accountsSnap.exists()) {
      return { success: false, error: "No accounts found", elderly: [] };
    }

    const accounts = accountsSnap.val();
    const elderlyIdentifiers = [];
    const caregiverAccount = Object.values(accounts).find(account => 
      account.email === caregiverUserId || account.uid === caregiverData.userInfo.uid
    );

    if (!caregiverAccount) {
      return { success: false, error: "Caregiver account not found", elderly: [] };
    }

    // Check all possible field names for elderly connections
    if (caregiverAccount.elderlyIds && Array.isArray(caregiverAccount.elderlyIds)) {
      elderlyIdentifiers.push(...caregiverAccount.elderlyIds);
    }
    if (caregiverAccount.elderlyId) {
      elderlyIdentifiers.push(caregiverAccount.elderlyId);
    }
    

    // Remove duplicates
    const uniqueIdentifiers = [...new Set(elderlyIdentifiers.filter(id => id))];
    
    console.log("Found elderly identifiers:", uniqueIdentifiers);

    if (uniqueIdentifiers.length === 0) {
      return { success: true, elderly: [] };
    }

    const elderlyDataPromises = uniqueIdentifiers.map(async (elderlyIdentifier) => {
      return await getElderlyDataByIdentifier(elderlyIdentifier);
    });

    const elderlyDataArray = await Promise.all(elderlyDataPromises);
    const validElderlyData = elderlyDataArray.filter(elderly => !elderly.error);
    
    // Enhance with health and schedule data
    const enhancedElderlyData = await Promise.all(
      validElderlyData.map(async (elderly) => {
        const healthData = await getElderlyHealthSummary(elderly.identifier);
        const upcomingAppointments = await getElderlyUpcomingAppointments(elderly.identifier);
        const medicationSummary = await getElderlyMedicationSummary(elderly.identifier);
        
        return {
          ...elderly,
          healthSummary: healthData,
          upcomingAppointments: upcomingAppointments,
          medicationSummary: medicationSummary,
          lastActive: await getElderlyLastActive(elderly.identifier)
        };
      })
    );

    return {
      success: true,
      caregiver: caregiverData.userInfo,
      elderly: enhancedElderlyData,
      totalElderly: enhancedElderlyData.length
    };

  } catch (error) {
    console.error("Error getting caregiver assigned elderly:", error);
    return { success: false, error: error.message, elderly: [] };
  }
}

// Get elderly health summary
async function getElderlyHealthSummary(elderlyIdentifier) {
  try {
    const elderlyData = await getElderlyDataByIdentifier(elderlyIdentifier);
    if (elderlyData.error) {
      return { error: "Elderly data not found" };
    }

    const medications = await getMedicationReminders(elderlyIdentifier, 'today');
    const appointments = await getAppointmentsForSchedule(elderlyIdentifier, 'upcoming');
    const consultations = await getConsultationsForSchedule(elderlyIdentifier, 'upcoming');

    const pendingMeds = medications.filter(med => !med.isCompleted);
    const totalMeds = medications.length;
    const adherenceRate = totalMeds > 0 ? (medications.filter(med => med.isCompleted).length / totalMeds) * 100 : 100;

    return {
      medicalConditions: elderlyData.medicalConditions || elderlyData.conditions || [],
      age: calculateAge(elderlyData.dob),
      totalMedications: totalMeds,
      pendingMedications: pendingMeds.length,
      medicationAdherence: Math.round(adherenceRate),
      upcomingAppointments: appointments.length + consultations.length,
      lastCheckup: await getLastCheckupDate(elderlyIdentifier),
      emergencyContact: elderlyData.emergencyContact || elderlyData.emergencyPhone || 'Not set'
    };
  } catch (error) {
    return { error: "Unable to fetch health data" };
  }
}

// Get elderly upcoming appointments
async function getElderlyUpcomingAppointments(elderlyIdentifier) {
  try {
    const appointments = await getAppointmentsForSchedule(elderlyIdentifier, 'upcoming');
    const consultations = await getConsultationsForSchedule(elderlyIdentifier, 'upcoming');
    
    const allAppointments = [
      ...appointments.map(apt => ({ ...apt, type: 'appointment' })),
      ...consultations.map(cons => ({ ...cons, type: 'consultation' }))
    ];

    return allAppointments
      .sort((a, b) => new Date(`${a.date}T${a.time || '00:00'}`) - new Date(`${b.date}T${b.time || '00:00'}`))
      .slice(0, 5);
  } catch (error) {
    return [];
  }
}

// Get elderly medication summary
async function getElderlyMedicationSummary(elderlyIdentifier) {
  try {
    const medications = await getMedicationReminders(elderlyIdentifier, 'today');
    const pendingMeds = medications.filter(med => !med.isCompleted);
    
    return {
      total: medications.length,
      pending: pendingMeds.length,
      completed: medications.filter(med => med.isCompleted).length,
      nextMedication: pendingMeds.length > 0 ? pendingMeds[0] : null
    };
  } catch (error) {
    return { total: 0, pending: 0, completed: 0, nextMedication: null };
  }
}

// Get elderly last active time
async function getElderlyLastActive(elderlyIdentifier) {
  try {
    const elderlyData = await getElderlyDataByIdentifier(elderlyIdentifier);
    if (elderlyData.error) return 'Unknown';
    
    return elderlyData.lastLoginDate || elderlyData.lastActive || 'Unknown';
  } catch (error) {
    return 'Unknown';
  }
}

// Get last checkup date for elderly
async function getLastCheckupDate(elderlyIdentifier) {
  try {
    const consultations = await getConsultationsForSchedule(elderlyIdentifier, 'past');
    if (consultations.length > 0) {
      const sorted = consultations.sort((a, b) => new Date(b.appointmentDate || b.date) - new Date(a.appointmentDate || a.date));
      return sorted[0].appointmentDate || sorted[0].date;
    }
    return 'No recent checkups';
  } catch (error) {
    return 'Unknown';
  }
}

// CORRECTED: Get caregiver consultations with proper elderly matching
async function getCaregiverConsultations(caregiverUserId, dateQuery = 'upcoming') {
  try {
    console.log("ðŸ‘¨â€âš•ï¸ Getting consultations for caregiver:", caregiverUserId, "Date query:", dateQuery);
    
    // Get caregiver's assigned elderly first
    const elderlyData = await getCaregiverAssignedElderly(caregiverUserId);
    if (!elderlyData.success || elderlyData.elderly.length === 0) {
      console.log("âŒ No elderly assigned to caregiver");
      return [];
    }

    // Create comprehensive list of elderly identifiers
    const elderlyIdentifiers = elderlyData.elderly.flatMap(elderly => [
      elderly.uid,
      elderly.email,
      normalizeEmailForFirebase(elderly.email),
      elderly.identifier,
      elderly.idKey,
      elderly.uid?.toLowerCase(),
      elderly.email?.toLowerCase()
    ]).filter(id => id && id !== 'Unknown');

    console.log("ðŸ” Elderly identifiers for consultation matching:", elderlyIdentifiers);

    // Get all consultations from both consultations and appointments nodes
    const consultationsRef = rtdb.ref("consultations");
    const appointmentsRef = rtdb.ref("Appointments");
    
    const [consultationsSnap, appointmentsSnap] = await Promise.all([
      consultationsRef.get(),
      appointmentsRef.get()
    ]);

    let allConsultations = [];

    // Process consultations from consultations node
    if (consultationsSnap.exists()) {
      const consultations = consultationsSnap.val();
      Object.entries(consultations).forEach(([consultId, consultation]) => {
        if (consultation && isConsultationForElderly(consultation, elderlyIdentifiers)) {
          allConsultations.push({
            id: consultId,
            type: 'consultation',
            source: 'consultations',
            elderlyName: getElderlyNameFromConsultation(consultation, elderlyData.elderly),
            ...consultation
          });
        }
      });
    }

    // Process consultations from Appointments node (type: consultation)
    if (appointmentsSnap.exists()) {
      const appointments = appointmentsSnap.val();
      Object.entries(appointments).forEach(([apptId, appointment]) => {
        if (appointment && 
            (appointment.type === 'consultation' || 
             appointment.appointmentType === 'consultation' ||
             appointment.title?.toLowerCase().includes('consultation') ||
             appointment.reason?.toLowerCase().includes('consultation')) && 
            isConsultationForElderly(appointment, elderlyIdentifiers)) {
          allConsultations.push({
            id: apptId,
            type: 'consultation',
            source: 'Appointments',
            elderlyName: getElderlyNameFromConsultation(appointment, elderlyData.elderly),
            ...appointment
          });
        }
      });
    }

    console.log(`âœ… Found ${allConsultations.length} consultations for caregiver's elderly`);

    // Filter based on date query
    const filteredConsultations = filterConsultationsByDate(allConsultations, dateQuery);

    // Sort consultations by date
    const sortedConsultations = filteredConsultations.sort((a, b) => {
      try {
        const dateA = new Date(a.appointmentDate || a.date || a.requestedAt || '9999-12-31');
        const dateB = new Date(b.appointmentDate || b.date || b.requestedAt || '9999-12-31');
        return dateA - dateB;
      } catch (error) {
        return 0;
      }
    });

    console.log(`ðŸ“… Filtered consultations for ${dateQuery}: ${sortedConsultations.length}`);

    return sortedConsultations;

  } catch (error) {
    console.error("ðŸ’¥ Error getting caregiver consultations:", error);
    return [];
  }
}

// NEW: Improved consultation matching function
function isConsultationForElderly(consultation, elderlyIdentifiers) {
  if (!consultation) return false;

  console.log(`ðŸ” Checking consultation for elderly match:`, {
    id: consultation.id,
    elderlyId: consultation.elderlyId,
    elderlyEmail: consultation.elderlyEmail,
    patientUid: consultation.patientUid,
    assignedTo: consultation.assignedTo
  });

  // Check all possible fields that might contain elderly identifiers
  const fieldsToCheck = [
    consultation.elderlyId,
    consultation.elderlyEmail,
    consultation.patientUid,
    consultation.assignedTo,
    consultation.elderlyUid,
    consultation.patientEmail,
    consultation.userId,
    consultation.patientId
  ].filter(field => field !== undefined && field !== null && field !== '');

  // Check array fields separately
  if (consultation.elderlyIds && Array.isArray(consultation.elderlyIds)) {
    fieldsToCheck.push(...consultation.elderlyIds.filter(id => id));
  }

  // Enhanced matching with multiple strategies
  const isMatch = fieldsToCheck.some(field => {
    if (!field) return false;
    
    // Handle array fields
    if (Array.isArray(field)) {
      return field.some(item => 
        elderlyIdentifiers.some(identifier => {
          const match = matchesIdentifier(item, identifier);
          if (match) {
            console.log(`âœ… Consultation array match: ${item} === ${identifier}`);
          }
          return match;
        })
      );
    }
    
    // Handle string fields with multiple comparison methods
    return elderlyIdentifiers.some(identifier => {
      const match = matchesIdentifier(field, identifier);
      if (match) {
        console.log(`âœ… Consultation field match: ${field} === ${identifier}`);
      }
      return match;
    });
  });

  console.log(`ðŸ“Š Consultation match result: ${isMatch}`);
  return isMatch;
}

// NEW: Universal identifier matching function
function matchesIdentifier(fieldValue, identifier) {
  if (!fieldValue || !identifier) return false;
  
  const fieldStr = String(fieldValue).toLowerCase().trim();
  const identifierStr = String(identifier).toLowerCase().trim();
  
  // Direct match
  if (fieldStr === identifierStr) return true;
  
  // Email normalization match
  if (normalizeEmailForComparison(fieldStr) === normalizeEmailForComparison(identifierStr)) return true;
  
  // Partial matches
  if (fieldStr.includes(identifierStr) || identifierStr.includes(fieldStr)) return true;
  
  // Remove special characters and compare
  const cleanField = fieldStr.replace(/[\._@,\-\s]/g, '');
  const cleanIdentifier = identifierStr.replace(/[\._@,\-\s]/g, '');
  if (cleanField === cleanIdentifier) return true;
  
  return false;
}

// Helper function for email comparison
function normalizeEmailForComparison(email) {
  if (!email) return '';
  return email.toLowerCase().replace(/[\._@,]/g, '');
}


// CORRECTED: Better response generator for caregiver consultations
function generateCaregiverConsultationsResponse(caregiverInfo, consultations, dateQuery) {
  const timeContext = getConsultationTimeContext(dateQuery);
  
  if (consultations.length === 0) {
    return `You don't have any ${timeContext} for your elderly patients, ${caregiverInfo.name}.`;
  }

  let response = `Here are your ${timeContext}, ${caregiverInfo.name}:\n\n`;

  consultations.forEach((consult, index) => {
    const date = consult.appointmentDate || consult.date;
    const time = consult.appointmentTime || consult.time;
    const reason = consult.reason || consult.title || 'Medical Consultation';
    const patient = consult.elderlyName || consult.patientName || 'Patient';
    const location = consult.location || 'Virtual';
    const doctor = consult.doctor || consult.provider || 'Healthcare Provider';
    const status = consult.status || 'Scheduled';
    
    response += `${index + 1}. ðŸ¥ **${reason}**\n`;
    response += `   ðŸ‘¤ Patient: ${patient}\n`;
    response += `   ðŸ©º Doctor: ${doctor}\n`;
    response += `   ðŸ“… ${formatDisplayDate(date)}\n`;
    if (time) response += `   â° ${formatDisplayTime(time)}\n`;
    response += `   ðŸ“ ${location}\n`;
    response += `   ðŸ“Š Status: ${status}\n`;
    
    if (consult.notes) {
      response += `   ðŸ“ ${consult.notes}\n`;
    }
    
    response += `\n`;
  });

  response += `**Total:** ${consultations.length} consultation${consultations.length !== 1 ? 's' : ''}`;

  return response;
}

function getConsultationTimeContext(dateQuery) {
  switch (dateQuery) {
    case 'today': return 'consultations today';
    case 'tomorrow': return 'consultations tomorrow';
    case 'yesterday': return 'consultations yesterday';
    case 'past': return 'past consultations';
    case 'all': return 'consultations';
    case 'upcoming': 
    default: return 'upcoming consultations';
  }
}


// ENHANCED: Better consultation matching
function isConsultationMatch(consultation, elderlyIdentifiers) {
  if (!consultation) return false;

  // Check all possible fields that might contain elderly identifiers
  const fieldsToCheck = [
    consultation.elderlyId,
    consultation.elderlyEmail,
    consultation.patientUid,
    consultation.assignedTo,
    consultation.elderlyUid,
    consultation.patientEmail
  ].filter(field => field !== undefined && field !== null && field !== '');

  // Check array fields separately
  if (consultation.elderlyIds && Array.isArray(consultation.elderlyIds)) {
    fieldsToCheck.push(...consultation.elderlyIds.filter(id => id));
  }

  // Enhanced matching with multiple strategies
  const isMatch = fieldsToCheck.some(field => {
    if (!field) return false;
    
    // Handle array fields
    if (Array.isArray(field)) {
      return field.some(item => 
        elderlyIdentifiers.some(identifier => {
          const match = String(identifier).toLowerCase() === String(item).toLowerCase();
          if (match) {
            console.log(`âœ… Consultation array match: ${item} === ${identifier}`);
          }
          return match;
        })
      );
    }
    
    // Handle string fields with multiple comparison methods
    const fieldStr = String(field).toLowerCase().trim();
    return elderlyIdentifiers.some(identifier => {
      const identifierStr = String(identifier).toLowerCase().trim();
      
      const match = (
        identifierStr === fieldStr ||
        fieldStr.includes(identifierStr) ||
        identifierStr.includes(fieldStr) ||
        normalizeEmailForComparison(identifierStr) === normalizeEmailForComparison(fieldStr)
      );
      
      if (match) {
        console.log(`âœ… Consultation field match: ${fieldStr} === ${identifierStr}`);
      }
      return match;
    });
  });

  console.log(`ðŸ“Š Consultation match result: ${isMatch}`);
  return isMatch;
}

// Helper function to get elderly name from consultation
function getElderlyNameFromConsultation(consultation, elderlyList) {
  // Try to find the elderly in the list based on identifiers
  for (const elderly of elderlyList) {
    const elderlyIdentifiers = [
      elderly.uid,
      elderly.email,
      normalizeEmailForFirebase(elderly.email),
      elderly.identifier
    ];
    
    const fieldsToCheck = [
      consultation.elderlyId,
      consultation.elderlyEmail,
      consultation.patientUid,
      consultation.assignedTo
    ];
    
    const isMatch = fieldsToCheck.some(field => 
      field && elderlyIdentifiers.some(identifier => 
        String(identifier).toLowerCase() === String(field).toLowerCase()
      )
    );
    
    if (isMatch) {
      return `${elderly.firstname || ''} ${elderly.lastname || ''}`.trim() || elderly.email;
    }
  }
  
  return consultation.patientName || consultation.elderlyName || 'Patient';
}

// CORRECTED: Enhanced date filtering for consultations
function filterConsultationsByDate(consultations, dateQuery) {
  const today = new Date();
  today.setHours(0, 0, 0, 0);
  
  const tomorrow = new Date(today);
  tomorrow.setDate(tomorrow.getDate() + 1);
  
  const yesterday = new Date(today);
  yesterday.setDate(yesterday.getDate() - 1);
  
  console.log(`ðŸ“… Filtering consultations for: ${dateQuery}, Today: ${today.toISOString()}`);
  
  switch (dateQuery) {
    case 'today':
      return consultations.filter(consult => {
        if (!consult.appointmentDate && !consult.date) return false;
        try {
          const consultDate = new Date(consult.appointmentDate || consult.date);
          consultDate.setHours(0, 0, 0, 0);
          const isToday = consultDate.getTime() === today.getTime();
          console.log(`ðŸ” Checking if ${consult.appointmentDate || consult.date} is today: ${isToday}`);
          return isToday;
        } catch (error) {
          console.log(`âŒ Error parsing date: ${consult.appointmentDate || consult.date}`);
          return false;
        }
      });
      
    case 'tomorrow':
      return consultations.filter(consult => {
        if (!consult.appointmentDate && !consult.date) return false;
        try {
          const consultDate = new Date(consult.appointmentDate || consult.date);
          consultDate.setHours(0, 0, 0, 0);
          return consultDate.getTime() === tomorrow.getTime();
        } catch (error) {
          return false;
        }
      });
      
    case 'yesterday':
      return consultations.filter(consult => {
        if (!consult.appointmentDate && !consult.date) return false;
        try {
          const consultDate = new Date(consult.appointmentDate || consult.date);
          consultDate.setHours(0, 0, 0, 0);
          return consultDate.getTime() === yesterday.getTime();
        } catch (error) {
          return false;
        }
      });
      
    case 'past':
      return consultations.filter(consult => {
        if (!consult.appointmentDate && !consult.date) return false;
        try {
          const consultDate = new Date(consult.appointmentDate || consult.date);
          consultDate.setHours(0, 0, 0, 0);
          return consultDate < today;
        } catch (error) {
          return false;
        }
      });
      
    case 'all':
      return consultations;
      
    case 'upcoming':
    default:
      return consultations.filter(consult => {
        if (!consult.appointmentDate && !consult.date) return false;
        try {
          const consultDate = new Date(consult.appointmentDate || consult.date);
          consultDate.setHours(0, 0, 0, 0);
          return consultDate >= today;
        } catch (error) {
          return false;
        }
      });
  }
}

// ENHANCED: Better response generator for caregiver consultations
function generateCaregiverConsultationsResponse(caregiverInfo, consultations, dateQuery) {
  const timeContext = getTimeContext(dateQuery).replace('appointments', 'consultations');
  
  if (consultations.length === 0) {
    return `You don't have any ${timeContext} for your elderly patients, ${caregiverInfo.name}.`;
  }

  let response = `Here are your ${timeContext}, ${caregiverInfo.name}:\n\n`;

  consultations.forEach((consult, index) => {
    const date = consult.appointmentDate || consult.date;
    const time = consult.appointmentTime || consult.time;
    const reason = consult.reason || consult.title || 'Medical Consultation';
    const patient = consult.elderlyName || consult.patientName || 'Patient';
    const location = consult.location || 'Virtual';
    const doctor = consult.doctor || consult.provider || 'Healthcare Provider';
    const status = consult.status || 'Scheduled';
    
    response += `${index + 1}. ðŸ¥ **${reason}**\n`;
    response += `   ðŸ‘¤ Patient: ${patient}\n`;
    response += `   ðŸ©º Doctor: ${doctor}\n`;
    response += `   ðŸ“… ${formatDisplayDate(date)}\n`;
    if (time) response += `   â° ${formatDisplayTime(time)}\n`;
    response += `   ðŸ“ ${location}\n`;
    response += `   ðŸ“Š Status: ${status}\n`;
    
    if (consult.notes) {
      response += `   ðŸ“ ${consult.notes}\n`;
    }
    
    response += `\n`;
  });

  return response;
}

// IMPROVED: Better appointment matching with null checks and case handling
function isElderlyMatchEnhanced(appointment, elderlyIdentifiers) {
  if (!appointment || typeof appointment !== 'object') {
    console.log('âŒ Invalid appointment object');
    return false;
  }

  console.log(`ðŸ” Checking appointment:`, {
    id: appointment.id || 'undefined',
    elderlyId: appointment.elderlyId || 'undefined',
    assignedTo: appointment.assignedTo || 'undefined',
    elderlyIds: appointment.elderlyIds || 'undefined'
  });

  // Early return if critical fields are missing
  if (!appointment.elderlyId && 
      !appointment.elderlyEmail && 
      !appointment.assignedTo && 
      (!appointment.elderlyIds || !Array.isArray(appointment.elderlyIds))) {
    console.log('ðŸ“Š Match result: false (no elderly identifiers found)');
    return false;
  }

  // Check all possible fields that might contain elderly identifiers
  const fieldsToCheck = [
    appointment.elderlyId,
    appointment.elderlyEmail,
    appointment.patientUid,
    appointment.assignedTo,
    appointment.elderlyUid
  ].filter(field => field !== undefined && field !== null && field !== '');

  // Check array fields separately
  if (appointment.elderlyIds && Array.isArray(appointment.elderlyIds)) {
    const validElderlyIds = appointment.elderlyIds.filter(id => id && id !== 'undefined');
    fieldsToCheck.push(...validElderlyIds);
  }

  console.log('ðŸ“‹ Fields to check:', fieldsToCheck);
  console.log('ðŸ‘µ Elderly identifiers:', elderlyIdentifiers);

  // Enhanced matching with better logging
  const isMatch = fieldsToCheck.some(field => {
    if (!field) return false;
    
    // Handle array fields
    if (Array.isArray(field)) {
      const arrayMatch = field.some(item => 
        elderlyIdentifiers.some(identifier => {
          const match = matchesIdentifier(item, identifier);
          if (match) {
            console.log(`âœ… Array match: ${item} === ${identifier}`);
          }
          return match;
        })
      );
      return arrayMatch;
    }
    
    // Handle string fields with multiple comparison methods
    const fieldStr = String(field).toLowerCase().trim();
    return elderlyIdentifiers.some(identifier => {
      const identifierStr = String(identifier).toLowerCase().trim();
      
      const match = (
        identifierStr === fieldStr ||
        fieldStr.includes(identifierStr) ||
        identifierStr.includes(fieldStr) ||
        normalizeEmailForComparison(identifierStr) === normalizeEmailForComparison(fieldStr) ||
        fieldStr.replace(/[\._@,]/g, '') === identifierStr.replace(/[\._@,]/g, '')
      );
      
      if (match) {
        console.log(`âœ… Field match: ${fieldStr} === ${identifierStr}`);
      }
      return match;
    });
  });

  console.log(`ðŸ“Š Match result for ${appointment.id || 'undefined'}: ${isMatch}`);
  return isMatch;
}
// IMPROVED: Universal identifier matching function
function matchesIdentifier(fieldValue, identifier) {
  if (!fieldValue || !identifier || fieldValue === 'undefined' || identifier === 'undefined') {
    return false;
  }
  
  const fieldStr = String(fieldValue).toLowerCase().trim();
  const identifierStr = String(identifier).toLowerCase().trim();
  
  // Direct match
  if (fieldStr === identifierStr) return true;
  
  // Email normalization match
  if (normalizeEmailForComparison(fieldStr) === normalizeEmailForComparison(identifierStr)) return true;
  
  // Remove special characters and compare
  const cleanField = fieldStr.replace(/[\._@,\-\s]/g, '');
  const cleanIdentifier = identifierStr.replace(/[\._@,\-\s]/g, '');
  if (cleanField === cleanIdentifier) return true;
  
  return false;
}
function normalizeEmailForComparison(email) {
  if (!email) return '';
  return email.toLowerCase().replace(/[\._@,]/g, '');
}

function analyzeActivitiesPreferences(recentActivities) {
  // Simple implementation
  return {
    preferredCategories: ['General'],
    activityFrequency: 'New User',
    preferredDifficulty: 'Easy',
    preferredDuration: '30 mins',
    interests: ['General activities'],
    totalActivities: 0
  };
}

function generateActivitiesPreferencesResponse(userInfo, activitiesPreferences) {
  return `Your activity preferences are being processed, ${userInfo.name}. This feature is coming soon!`;
}

function generateActivitiesResponse(userInfo, activities, dateQuery) {
  if (activities.length === 0) {
    return `No activities found for ${dateQuery}, ${userInfo.name}.`;
  }
  
  let response = `Here are your activities:\n\n`;
  activities.forEach((activity, index) => {
    response += `${index + 1}. ${activity.title}\n`;
  });
  return response;
}


// Helper function to get caregiver UID (you might need to implement this)
async function getCaregiverUid(caregiverEmail) {
  try {
    const accountsRef = rtdb.ref("Account");
    const snapshot = await accountsRef.get();
    
    if (snapshot.exists()) {
      const accounts = snapshot.val();
      for (const [key, account] of Object.entries(accounts)) {
        if (account.email === caregiverEmail) {
          return account.uid;
        }
      }
    }
    return null;
  } catch (error) {
    console.error("Error getting caregiver UID:", error);
    return null;
  }
}


// ENHANCED: Better elderly matching for appointments
function isElderlyMatchEnhanced(appointment, elderlyIdentifiers) {
  if (!appointment) return false;

  console.log(`ðŸ” Checking appointment:`, {
    id: appointment.id,
    elderlyId: appointment.elderlyId,
    assignedTo: appointment.assignedTo,
    elderlyIds: appointment.elderlyIds
  });

  // Check all possible fields that might contain elderly identifiers
  const fieldsToCheck = [
    appointment.elderlyId,
    appointment.elderlyEmail,
    appointment.patientUid,
    appointment.assignedTo,
    appointment.elderlyUid
  ].filter(field => field !== undefined && field !== null && field !== '');

  // Check array fields separately
  if (appointment.elderlyIds && Array.isArray(appointment.elderlyIds)) {
    fieldsToCheck.push(...appointment.elderlyIds.filter(id => id));
  }

  // Enhanced matching with better logging
  const isMatch = fieldsToCheck.some(field => {
    if (!field) return false;
    
    // Handle array fields
    if (Array.isArray(field)) {
      const arrayMatch = field.some(item => 
        elderlyIdentifiers.some(identifier => {
          const match = String(identifier).toLowerCase() === String(item).toLowerCase();
          if (match) {
            console.log(`âœ… Array match: ${item} === ${identifier}`);
          }
          return match;
        })
      );
      return arrayMatch;
    }
    
    // Handle string fields with multiple comparison methods
    const fieldStr = String(field).toLowerCase().trim();
    return elderlyIdentifiers.some(identifier => {
      const identifierStr = String(identifier).toLowerCase().trim();
      
      const match = (
        identifierStr === fieldStr ||
        fieldStr.includes(identifierStr) ||
        identifierStr.includes(fieldStr) ||
        normalizeEmailForComparison(identifierStr) === normalizeEmailForComparison(fieldStr)
      );
      
      if (match) {
        console.log(`âœ… Field match: ${fieldStr} === ${identifierStr}`);
      }
      return match;
    });
  });

  console.log(`ðŸ“Š Match result for ${appointment.id}: ${isMatch}`);
  return isMatch;
}

function normalizeEmailForComparison(email) {
  if (!email) return '';
  return email.toLowerCase().replace(/[\._@,]/g, '');
}

// ENHANCED: Better appointment discovery with proper debugging
async function getElderlyAppointmentsForCaregiverEnhanced(caregiverUserId, dateQuery = 'upcoming') {
  try {
    console.log("ðŸ”„ ENHANCED: Getting elderly appointments for:", caregiverUserId, "Date query:", dateQuery);
    
    if (!caregiverUserId) {
      throw new Error("Caregiver user ID is required");
    }

    // Step 1: Get caregiver's assigned elderly
    const elderlyData = await getCaregiverAssignedElderly(caregiverUserId);
    
    if (!elderlyData.success || elderlyData.elderly.length === 0) {
      console.log("âŒ No elderly assigned to caregiver");
      return {
        success: true,
        appointments: [],
        totalAppointments: 0,
        message: "No elderly assigned to this caregiver"
      };
    }

    console.log("ðŸ‘µ Elderly assigned:", elderlyData.elderly.map(e => ({
      name: `${e.firstname} ${e.lastname}`,
      email: e.email,
      uid: e.uid
    })));

    // Create comprehensive list of elderly identifiers
    const elderlyIdentifiers = elderlyData.elderly.flatMap(elderly => [
      elderly.uid,
      elderly.email,
      normalizeEmailForFirebase(elderly.email),
      elderly.identifier,
      elderly.idKey,
      elderly.uid?.toLowerCase(),
      elderly.email?.toLowerCase()
    ]).filter(id => id && id !== 'Unknown' && id !== 'undefined');

    console.log("ðŸ” Elderly identifiers for appointment matching:", elderlyIdentifiers);

    // Step 2: Get all appointments from database
    const appointmentsRef = rtdb.ref("Appointments");
    const appointmentsSnap = await appointmentsRef.get();
    
    let allAppointments = [];

    // Step 3: Process each appointment and find matches
    if (appointmentsSnap.exists()) {
      const appointments = appointmentsSnap.val();
      let totalChecked = 0;
      let totalMatched = 0;
      
      Object.entries(appointments).forEach(([apptId, appointment]) => {
        totalChecked++;
        if (appointment && isElderlyMatchEnhanced(appointment, elderlyIdentifiers)) {
          totalMatched++;
          allAppointments.push({
            id: apptId,
            type: 'appointment',
            appointmentType: 'appointment',
            elderlyName: getElderlyNameFromAppointment(appointment, elderlyData.elderly),
            elderlyEmail: getElderlyEmailFromAppointment(appointment, elderlyData.elderly),
            elderlyUid: getElderlyUidFromAppointment(appointment, elderlyData.elderly),
            source: 'Appointments',
            ...appointment
          });
        }
      });
      
      console.log(`âœ… Checked ${totalChecked} appointments, found ${totalMatched} matches`);
    }

    console.log(`ðŸ“Š Total appointments found: ${allAppointments.length}`);

    // Step 4: Filter appointments based on date query - FIXED FOR 'ALL'
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    
    let filteredAppointments = [];
    
    switch (dateQuery) {
      case 'today':
        filteredAppointments = allAppointments.filter(appt => {
          if (!appt.date && !appt.appointmentDate) return false;
          try {
            const appointmentDate = new Date(appt.date || appt.appointmentDate);
            appointmentDate.setHours(0, 0, 0, 0);
            return appointmentDate.getTime() === today.getTime();
          } catch (error) {
            return false;
          }
        });
        break;
        
      case 'past':
        filteredAppointments = allAppointments.filter(appt => {
          if (!appt.date && !appt.appointmentDate) return false;
          try {
            const appointmentDate = new Date(appt.date || appt.appointmentDate);
            appointmentDate.setHours(0, 0, 0, 0);
            return appointmentDate < today;
          } catch (error) {
            return false;
          }
        });
        break;
        
      case 'all':
        // Show all appointments - past, present, and future (NO FILTERING)
        filteredAppointments = allAppointments;
        break;
        
      case 'upcoming':
      default:
        // Default behavior - show only future appointments
        filteredAppointments = allAppointments.filter(appt => {
          if (!appt.date && !appt.appointmentDate) return false;
          try {
            const appointmentDate = new Date(appt.date || appt.appointmentDate);
            appointmentDate.setHours(0, 0, 0, 0);
            return appointmentDate >= today;
          } catch (error) {
            return false;
          }
        });
        break;
    }

    // Sort appointments by date (chronological order)
    const sortedAppointments = filteredAppointments.sort((a, b) => {
      try {
        const dateA = new Date(`${a.date || a.appointmentDate}T${a.time || a.appointmentTime || '00:00'}`);
        const dateB = new Date(`${b.date || b.appointmentDate}T${b.time || b.appointmentTime || '00:00'}`);
        return dateA - dateB;
      } catch (error) {
        return 0;
      }
    });

    console.log(`âœ… ENHANCED: Found ${sortedAppointments.length} appointments for date query: ${dateQuery}`);

    // Debug: Show which elderly have appointments
    const elderlyWithAppointments = {};
    sortedAppointments.forEach(apt => {
      if (!elderlyWithAppointments[apt.elderlyEmail]) {
        elderlyWithAppointments[apt.elderlyEmail] = 0;
      }
      elderlyWithAppointments[apt.elderlyEmail]++;
    });
    
    console.log("ðŸ“‹ Appointments by elderly:", elderlyWithAppointments);

    return {
      success: true,
      appointments: sortedAppointments,
      totalAppointments: sortedAppointments.length,
      totalElderly: elderlyData.elderly.length,
      dateQuery: dateQuery,
      elderlyList: elderlyData.elderly.map(elderly => ({
        name: `${elderly.firstname || ''} ${elderly.lastname || ''}`.trim(),
        email: elderly.email,
        uid: elderly.uid,
        appointmentCount: sortedAppointments.filter(apt => 
          apt.elderlyEmail === elderly.email || apt.elderlyUid === elderly.uid
        ).length
      })),
      debug: {
        elderlyWithAppointments: elderlyWithAppointments,
        dateQueryUsed: dateQuery
      }
    };

  } catch (error) {
    console.error("ðŸ’¥ CRITICAL ERROR in enhanced function:", error);
    return {
      success: false,
      error: error.message,
      appointments: [],
      totalAppointments: 0
    };
  }
}
// Helper function to get elderly name from appointment
function getElderlyNameFromAppointment(appointment, elderlyList) {
  if (!appointment || !elderlyList) return 'Unknown Elderly';
  
  // Try to find which elderly this appointment belongs to
  for (const elderly of elderlyList) {
    const elderlyIdentifiers = [
      elderly.uid,
      elderly.email,
      normalizeEmailForFirebase(elderly.email)
    ];
    
    if (elderlyIdentifiers.includes(appointment.elderlyId) ||
        elderlyIdentifiers.includes(appointment.elderlyEmail) ||
        elderlyIdentifiers.includes(appointment.assignedTo)) {
      return `${elderly.firstname || ''} ${elderly.lastname || ''}`.trim() || elderly.email;
    }
  }
  
  return 'Unknown Elderly';
}

// Helper function to get elderly email from appointment
function getElderlyEmailFromAppointment(appointment, elderlyList) {
  if (!appointment || !elderlyList) return 'unknown';
  
  for (const elderly of elderlyList) {
    const elderlyIdentifiers = [
      elderly.uid,
      elderly.email,
      normalizeEmailForFirebase(elderly.email)
    ];
    
    if (elderlyIdentifiers.includes(appointment.elderlyId) ||
        elderlyIdentifiers.includes(appointment.elderlyEmail) ||
        elderlyIdentifiers.includes(appointment.assignedTo)) {
      return elderly.email;
    }
  }
  
  return 'unknown';
}

// Helper function to get elderly UID from appointment
function getElderlyUidFromAppointment(appointment, elderlyList) {
  if (!appointment || !elderlyList) return 'unknown';
  
  for (const elderly of elderlyList) {
    const elderlyIdentifiers = [
      elderly.uid,
      elderly.email,
      normalizeEmailForFirebase(elderly.email)
    ];
    
    if (elderlyIdentifiers.includes(appointment.elderlyId) ||
        elderlyIdentifiers.includes(appointment.elderlyEmail) ||
        elderlyIdentifiers.includes(appointment.assignedTo)) {
      return elderly.uid;
    }
  }
  
  return 'unknown';
}

// FIXED: Correct normalization that matches your database
function normalizeEmailForFirebase1(email) {
  if (!email) return '';
  
  let normalized = email.toString().toLowerCase().trim();
  
  console.log(`ðŸ”„ Normalizing: "${email}"`);
  
  // Your database uses: "elderlyfive_at_gmail,com" (with COMMAS)
  // But the current function is creating: "elderlyfive@gmail_com" (with UNDERSCORES)
  
  // FIX: Replace @ with _at_ and . with , (COMMA)
  normalized = normalized
    .replace(/@/g, '_at_')
    .replace(/\./g, ',');  // DOTS become COMMAS
  
  console.log(`   Result: "${normalized}"`);
  return normalized;
}
// Enhanced helper function to check if appointment belongs to elderly
function isElderlyMatch(appointment, elderlyIdentifiers) {
  if (!appointment) return false;

  // Check all possible fields that might contain elderly identifiers
  const fieldsToCheck = [
    appointment.elderlyId,
    appointment.elderlyEmail,
    appointment.patientUid,
    appointment.assignedTo,
    appointment.elderlyIds // This might be an array
  ].filter(field => field); 

  // Check array fields separately
  if (appointment.elderlyIds && Array.isArray(appointment.elderlyIds)) {
    fieldsToCheck.push(...appointment.elderlyIds);
  }

  // Check if any field matches any elderly identifier
  return fieldsToCheck.some(field => {
    if (!field) return false;
    
    if (Array.isArray(field)) {
      return field.some(item => elderlyIdentifiers.includes(item));
    }
    
    // Handle both string and array comparisons
    const fieldStr = field.toString();
    return elderlyIdentifiers.some(identifier => 
      identifier.toString() === fieldStr || 
      fieldStr.includes(identifier) ||
      identifier.includes(fieldStr)
    );
  });
}

// ENHANCED: Main caregiver schedule function with proper reminder handling
async function fetchCaregiverSchedule(userId, dateQuery = 'upcoming') {
  try {
    console.log("ðŸ“… Getting COMPLETE schedule for caregiver:", userId, "Date query:", dateQuery);
    
    // Get ALL schedule components in parallel
    const [
      caregiverConsultations,
      caregiverSpecificConsultations,
      elderlyAppointments,
      elderlyMedications,
      elderlyActivities,
      elderlyReminders,
      elderlyData
    ] = await Promise.all([
      getCaregiverConsultations(userId, dateQuery).catch(error => {
        console.error("Error getting caregiver consultations:", error);
        return [];
      }),
      getCaregiverSpecificConsultations(userId, dateQuery).catch(error => {
        console.error("Error getting caregiver-specific consultations:", error);
        return [];
      }),
      getElderlyAppointmentsForCaregiverEnhanced(userId, dateQuery).catch(error => {
        console.error("Error getting elderly appointments:", error);
        return { appointments: [] };
      }),
      getElderlyMedicationsForCaregiver(userId, dateQuery).catch(error => {
        console.error("Error getting elderly medications:", error);
        return [];
      }),
      getElderlyActivitiesForCaregiver(userId, dateQuery).catch(error => {
        console.error("Error getting elderly activities:", error);
        return [];
      }),
      getElderlyRemindersForCaregiver(userId, dateQuery).catch(error => {
        console.error("Error getting elderly reminders:", error);
        return [];
      }),
      getCaregiverAssignedElderly(userId).catch(error => {
        console.error("Error getting assigned elderly:", error);
        return { success: false, elderly: [] };
      })
    ]);

    console.log("ðŸ“Š COMPLETE Schedule results:", {
      consultations: caregiverConsultations.length,
      caregiverSpecificConsultations: caregiverSpecificConsultations.length,
      elderlyAppointments: elderlyAppointments.appointments?.length || 0,
      elderlyMedications: elderlyMedications.length,
      elderlyActivities: elderlyActivities.length,
      elderlyReminders: elderlyReminders.length,
      elderlyCount: elderlyData.elderly?.length || 0
    });

    // Combine ALL events with proper categorization
    const allEvents = [
      // CAREGIVER'S PERSONAL CONSULTATIONS
      ...caregiverConsultations.map(cons => ({ 
        ...cons, 
        eventType: 'caregiver_consultation',
        displayType: 'My Consultation',
        sortDate: cons.appointmentDate || cons.date || cons.requestedAt,
        isCaregiverEvent: true,
        title: cons.reason || cons.title || 'Medical Consultation',
        time: cons.appointmentTime || cons.time,
        location: cons.location || 'Virtual'
      })),
      
      // Caregiver-specific consultations
      ...caregiverSpecificConsultations.map(cons => ({
        ...cons,
        eventType: 'caregiver_specific_consultation',
        displayType: 'My Consultation Invitation',
        sortDate: cons.appointmentDate || cons.date || cons.requestedAt,
        isCaregiverEvent: true,
        isInvitation: true,
        title: cons.reason || cons.title || 'Consultation Invitation',
        time: cons.appointmentTime || cons.time,
        location: cons.location || 'Virtual'
      })),
      
      // ELDERLY PATIENT EVENTS
      // Elderly appointments
      ...(elderlyAppointments.appointments || []).map(apt => ({ 
        ...apt, 
        eventType: apt.type === 'consultation' ? 'elderly_consultation' : 'elderly_appointment',
        displayType: apt.type === 'consultation' ? 'Elderly Consultation' : 'Elderly Appointment',
        sortDate: apt.date || apt.appointmentDate,
        isElderlyEvent: true,
        title: apt.title || apt.reason || (apt.type === 'consultation' ? 'Medical Consultation' : 'Appointment')
      })),
      
      // Elderly medications (from medicationReminders)
      ...elderlyMedications.map(med => ({
        ...med,
        eventType: 'elderly_medication',
        displayType: 'Elderly Medication',
        sortDate: `${med.date}T${med.reminderTime || '00:00'}`,
        isElderlyEvent: true,
        title: med.medicationName || 'Medication'
      })),
      
      // Elderly activities
      ...elderlyActivities.map(act => ({
        ...act,
        eventType: 'elderly_activity',
        displayType: 'Elderly Activity',
        sortDate: `${act.date}T${act.time || '10:00'}`,
        isElderlyEvent: true,
        title: act.title || 'Activity'
      })),
      
      // Elderly reminders (from reminders path - excluding medications)
      ...elderlyReminders.filter(rem => rem.type === 'reminder').map(rem => ({
        ...rem,
        eventType: 'elderly_reminder',
        displayType: 'Elderly Reminder',
        sortDate: rem.startTime || '9999-12-31T00:00',
        isElderlyEvent: true,
        title: rem.title || 'Reminder'
      }))
    ];

    // Apply date filtering to ALL events based on dateQuery
    const filteredEvents = filterCaregiverEventsByDate(allEvents, dateQuery);

    // Sort filtered events by date
    const sortedEvents = filteredEvents.sort((a, b) => {
      const dateA = new Date(a.sortDate || '9999-12-31');
      const dateB = new Date(b.sortDate || '9999-12-31');
      return dateA - dateB;
    });

    return {
      success: true,
      schedule: sortedEvents,
      
      // Individual components for detailed display
      caregiverConsultations: caregiverConsultations,
      caregiverSpecificConsultations: caregiverSpecificConsultations,
      elderlyAppointments: elderlyAppointments.appointments || [],
      elderlyMedications: elderlyMedications,
      elderlyActivities: elderlyActivities,
      elderlyReminders: elderlyReminders,
      
      // Summary counts
      totalEvents: sortedEvents.length,
      summary: {
        totalConsultations: caregiverConsultations.length + caregiverSpecificConsultations.length,
        totalElderlyAppointments: elderlyAppointments.appointments?.length || 0,
        totalElderlyMedications: elderlyMedications.length,
        totalElderlyActivities: elderlyActivities.length,
        totalElderlyReminders: elderlyReminders.filter(rem => rem.type === 'reminder').length,
        totalElderly: elderlyData.totalElderly || 0,
        dateQuery: dateQuery
      },
      
      elderlyData: elderlyData
    };

  } catch (error) {
    console.error("ðŸ’¥ Error in fetchCaregiverSchedule:", error);
    return { 
      success: false, 
      error: error.message, 
      schedule: [],
      caregiverConsultations: [],
      caregiverSpecificConsultations: [],
      elderlyAppointments: [],
      elderlyMedications: [],
      elderlyActivities: [],
      elderlyReminders: []
    };
  }
}

// ADD THESE MISSING FUNCTIONS:

/**
 * Get caregiver-specific consultations
 */
async function getCaregiverSpecificConsultations(caregiverUserId, dateQuery = 'upcoming') {
  try {
    console.log("ðŸ‘¨â€âš•ï¸ Getting caregiver-specific consultations for:", caregiverUserId);
    
    // Get caregiver data to get UID
    const caregiverData = await getUserData(caregiverUserId, { type: 'user_info', subType: 'all' });
    if (!caregiverData) {
      return [];
    }

    const caregiverUid = caregiverData.userInfo.uid;
    const caregiverEmail = caregiverData.userInfo.email;
    
    const caregiverIdentifiers = [
      caregiverUid,
      caregiverEmail,
      normalizeEmailForFirebase(caregiverEmail),
      caregiverUserId,
      caregiverUid?.toLowerCase(),
      caregiverEmail?.toLowerCase()
    ].filter(id => id && id !== 'Unknown');

    console.log("ðŸ” Caregiver identifiers for consultation matching:", caregiverIdentifiers);

    // Get all consultations from both consultations and appointments nodes
    const consultationsRef = rtdb.ref("consultations");
    const appointmentsRef = rtdb.ref("Appointments");
    
    const [consultationsSnap, appointmentsSnap] = await Promise.all([
      consultationsRef.get(),
      appointmentsRef.get()
    ]);

    let caregiverSpecificConsultations = [];

    // Process consultations from consultations node
    if (consultationsSnap.exists()) {
      const consultations = consultationsSnap.val();
      Object.entries(consultations).forEach(([consultId, consultation]) => {
        if (consultation && isCaregiverSpecificMatch(consultation, caregiverIdentifiers)) {
          caregiverSpecificConsultations.push({
            id: consultId,
            type: 'consultation',
            source: 'consultations',
            isCaregiverSpecific: true,
            ...consultation
          });
        }
      });
    }

    // Process consultations from Appointments node
    if (appointmentsSnap.exists()) {
      const appointments = appointmentsSnap.val();
      Object.entries(appointments).forEach(([apptId, appointment]) => {
        if (appointment && 
            (appointment.type === 'consultation' || 
             appointment.appointmentType === 'consultation' ||
             appointment.title?.toLowerCase().includes('consultation')) && 
            isCaregiverSpecificMatch(appointment, caregiverIdentifiers)) {
          caregiverSpecificConsultations.push({
            id: apptId,
            type: 'consultation',
            source: 'Appointments',
            isCaregiverSpecific: true,
            ...appointment
          });
        }
      });
    }

    console.log(`âœ… Found ${caregiverSpecificConsultations.length} caregiver-specific consultations`);

    // Filter based on date query
    const filteredConsultations = filterConsultationsByDate(caregiverSpecificConsultations, dateQuery);

    return filteredConsultations;

  } catch (error) {
    console.error("ðŸ’¥ Error getting caregiver-specific consultations:", error);
    return [];
  }
}

/**
 * Check if consultation is specifically assigned to caregiver
 */
function isCaregiverSpecificMatch(consultation, caregiverIdentifiers) {
  if (!consultation) return false;

  // Check fields that might indicate caregiver assignment
  const caregiverFields = [
    consultation.caregiverId,
    consultation.assignedCaregiver,
    consultation.caregiverUid,
    consultation.caregiverEmail,
    consultation.invitedCaregiver,
    consultation.caregiverInvite,
    // Also check general assignment fields that might point to caregiver
    consultation.assignedTo,
    consultation.assignedProvider
  ].filter(field => field !== undefined && field !== null && field !== '');

  console.log(`ðŸ” Checking caregiver-specific match:`, {
    caregiverFields: caregiverFields,
    caregiverIdentifiers: caregiverIdentifiers
  });

  // Check if any caregiver field matches caregiver identifiers
  const isMatch = caregiverFields.some(field => {
    if (!field) return false;
    
    const fieldStr = String(field).toLowerCase().trim();
    return caregiverIdentifiers.some(identifier => {
      const identifierStr = String(identifier).toLowerCase().trim();
      
      const match = (
        identifierStr === fieldStr ||
        fieldStr.includes(identifierStr) ||
        identifierStr.includes(fieldStr) ||
        normalizeEmailForComparison(identifierStr) === normalizeEmailForComparison(fieldStr)
      );
      
      if (match) {
        console.log(`âœ… Caregiver-specific match: ${fieldStr} === ${identifierStr}`);
      }
      return match;
    });
  });

  console.log(`ðŸ“Š Caregiver-specific match result: ${isMatch}`);
  return isMatch;
}

/**
 * Main caregiver schedule function
 */
// CORRECTED: Main caregiver schedule function
async function getCaregiverSchedule(userId, dateQuery = 'upcoming') {
  try {
    console.log("ðŸ“… Getting COMPLETE schedule for caregiver:", userId, "Date query:", dateQuery);
    
    // Get ALL schedule components in parallel with better error handling
    const [
      caregiverConsultations,
      caregiverSpecificConsultations,
      elderlyAppointments,
      elderlyMedications,
      elderlyActivities,
      elderlyReminders,
      elderlyData
    ] = await Promise.all([
      getCaregiverConsultations(userId, dateQuery).catch(error => {
        console.error("Error getting caregiver consultations:", error);
        return [];
      }),
      getCaregiverSpecificConsultations(userId, dateQuery).catch(error => {
        console.error("Error getting caregiver-specific consultations:", error);
        return [];
      }),
      getElderlyAppointmentsForCaregiverEnhanced(userId, dateQuery).catch(error => {
        console.error("Error getting elderly appointments:", error);
        return { appointments: [] };
      }),
      getElderlyMedicationsForCaregiver(userId, dateQuery).catch(error => {
        console.error("Error getting elderly medications:", error);
        return [];
      }),
      getElderlyActivitiesForCaregiver(userId, dateQuery).catch(error => {
        console.error("Error getting elderly activities:", error);
        return [];
      }),
      getElderlyRemindersForCaregiver(userId, dateQuery).catch(error => {
        console.error("Error getting elderly reminders:", error);
        return [];
      }),
      getCaregiverAssignedElderly(userId).catch(error => {
        console.error("Error getting assigned elderly:", error);
        return { success: false, elderly: [] };
      })
    ]);

    console.log("ðŸ“Š COMPLETE Schedule results:", {
      consultations: caregiverConsultations.length,
      caregiverSpecificConsultations: caregiverSpecificConsultations.length,
      elderlyAppointments: elderlyAppointments.appointments?.length || 0,
      elderlyMedications: elderlyMedications.length,
      elderlyActivities: elderlyActivities.length,
      elderlyReminders: elderlyReminders.length,
      elderlyCount: elderlyData.elderly?.length || 0
    });

    // Combine ALL events with proper categorization
    const allEvents = [
      // CAREGIVER'S PERSONAL CONSULTATIONS
      ...caregiverConsultations.map(cons => ({ 
        ...cons, 
        eventType: 'caregiver_consultation',
        displayType: 'My Consultation',
        sortDate: cons.appointmentDate || cons.date || cons.requestedAt,
        isCaregiverEvent: true,
        title: cons.reason || cons.title || 'Medical Consultation',
        time: cons.appointmentTime || cons.time,
        location: cons.location || 'Virtual'
      })),
      
      // Caregiver-specific consultations
      ...caregiverSpecificConsultations.map(cons => ({
        ...cons,
        eventType: 'caregiver_specific_consultation',
        displayType: 'My Consultation Invitation',
        sortDate: cons.appointmentDate || cons.date || cons.requestedAt,
        isCaregiverEvent: true,
        isInvitation: true,
        title: cons.reason || cons.title || 'Consultation Invitation',
        time: cons.appointmentTime || cons.time,
        location: cons.location || 'Virtual'
      })),
      
      // ELDERLY PATIENT EVENTS
      // Elderly appointments
      ...(elderlyAppointments.appointments || []).map(apt => ({ 
        ...apt, 
        eventType: apt.type === 'consultation' ? 'elderly_consultation' : 'elderly_appointment',
        displayType: apt.type === 'consultation' ? 'Elderly Consultation' : 'Elderly Appointment',
        sortDate: apt.date || apt.appointmentDate,
        isElderlyEvent: true,
        title: apt.title || apt.reason || (apt.type === 'consultation' ? 'Medical Consultation' : 'Appointment')
      })),
      
      // Elderly medications
      ...elderlyMedications.map(med => ({
        ...med,
        eventType: 'elderly_medication',
        displayType: 'Elderly Medication',
        sortDate: `${med.date}T${med.reminderTime || '00:00'}`,
        isElderlyEvent: true,
        title: med.medicationName || 'Medication'
      })),
      
      // Elderly activities
      ...elderlyActivities.map(act => ({
        ...act,
        eventType: 'elderly_activity',
        displayType: 'Elderly Activity',
        sortDate: `${act.date}T${act.time || '10:00'}`,
        isElderlyEvent: true,
        title: act.title || 'Activity'
      })),
      
      // Elderly reminders
      ...elderlyReminders.map(rem => ({
        ...rem,
        eventType: 'elderly_reminder',
        displayType: 'Elderly Reminder',
        sortDate: rem.startTime || '00:00',
        isElderlyEvent: true,
        title: rem.title || 'Reminder'
      }))
    ];

    // Apply date filtering to ALL events based on dateQuery
    const filteredEvents = filterCaregiverEventsByDate(allEvents, dateQuery);

    // Sort filtered events by date
    const sortedEvents = filteredEvents.sort((a, b) => {
      const dateA = new Date(a.sortDate || '9999-12-31');
      const dateB = new Date(b.sortDate || '9999-12-31');
      return dateA - dateB;
    });

    return {
      success: true,
      schedule: sortedEvents,
      
      // Individual components for detailed display
      caregiverConsultations: caregiverConsultations,
      caregiverSpecificConsultations: caregiverSpecificConsultations,
      elderlyAppointments: elderlyAppointments.appointments || [],
      elderlyMedications: elderlyMedications,
      elderlyActivities: elderlyActivities,
      elderlyReminders: elderlyReminders,
      
      // Summary counts
      totalEvents: sortedEvents.length,
      summary: {
        totalConsultations: caregiverConsultations.length + caregiverSpecificConsultations.length,
        totalElderlyAppointments: elderlyAppointments.appointments?.length || 0,
        totalElderlyMedications: elderlyMedications.length,
        totalElderlyActivities: elderlyActivities.length,
        totalElderlyReminders: elderlyReminders.length,
        totalElderly: elderlyData.totalElderly || 0,
        dateQuery: dateQuery
      },
      
      elderlyData: elderlyData
    };

  } catch (error) {
    console.error("ðŸ’¥ Error in getCaregiverSchedule:", error);
    return { 
      success: false, 
      error: error.message, 
      schedule: [],
      caregiverConsultations: [],
      caregiverSpecificConsultations: [],
      elderlyAppointments: [],
      elderlyMedications: [],
      elderlyActivities: [],
      elderlyReminders: []
    };
  }
}

/**
 * Filter caregiver events by date query
 */
function filterCaregiverEventsByDate(events, dateQuery) {
  const today = new Date();
  today.setHours(0, 0, 0, 0);
  
  const tomorrow = new Date(today);
  tomorrow.setDate(tomorrow.getDate() + 1);
  
  switch (dateQuery) {
    case 'today':
      return events.filter(event => {
        if (!event.sortDate) return false;
        try {
          const eventDate = new Date(event.sortDate);
          eventDate.setHours(0, 0, 0, 0);
          return eventDate.getTime() === today.getTime();
        } catch (error) {
          return false;
        }
      });
      
    case 'tomorrow':
      return events.filter(event => {
        if (!event.sortDate) return false;
        try {
          const eventDate = new Date(event.sortDate);
          eventDate.setHours(0, 0, 0, 0);
          return eventDate.getTime() === tomorrow.getTime();
        } catch (error) {
          return false;
        }
      });
      
    case 'past':
      return events.filter(event => {
        if (!event.sortDate) return false;
        try {
          const eventDate = new Date(event.sortDate);
          eventDate.setHours(0, 0, 0, 0);
          return eventDate < today;
        } catch (error) {
          return false;
        }
      });
      
    case 'all':
      return events;
      
    case 'upcoming':
    default:
      return events.filter(event => {
        if (!event.sortDate) return false;
        try {
          const eventDate = new Date(event.sortDate);
          eventDate.setHours(0, 0, 0, 0);
          return eventDate >= today;
        } catch (error) {
          return false;
        }
      });
  }
}

// COMPLETELY REWRITTEN: Get elderly medications - FIXED VERSION
async function getElderlyMedicationsForCaregiver(caregiverUserId, dateQuery = 'today') {
  try {
    console.log("ðŸ’Š FIXED VERSION: Getting medications for caregiver:", caregiverUserId);
    
    const elderlyData = await getCaregiverAssignedElderly(caregiverUserId);
    if (!elderlyData.success || elderlyData.elderly.length === 0) {
      console.log("âŒ No elderly assigned to caregiver");
      return [];
    }

    let allElderlyMeds = [];
    
    // Get all medications from database
    const medsRef = rtdb.ref('medicationReminders');
    const medsSnapshot = await medsRef.get();
    
    if (!medsSnapshot.exists()) {
      console.log("âŒ No medication reminders found in database");
      return [];
    }

    const medsData = medsSnapshot.val();
    console.log("ðŸ“Š Found medication keys in database:", Object.keys(medsData));
    
    // Create mapping of elderly normalized emails
    const elderlyNormalizedMap = {};
    elderlyData.elderly.forEach(elderly => {
      const normalizedEmail = normalizeEmailForFirebase1(elderly.email);
      elderlyNormalizedMap[normalizedEmail] = elderly;
      console.log(`ðŸ‘µ Elderly mapping: "${elderly.email}" -> "${normalizedEmail}"`);
    });

    // DIRECT MATCHING: Check each medication user key
    for (const [userKey, userMeds] of Object.entries(medsData)) {
      if (!userMeds || typeof userMeds !== 'object') continue;
      
      console.log(`\nðŸ” Processing medication user key: "${userKey}"`);
      
      // Check if this userKey matches any elderly normalized email
      const normalizedUserKey = normalizeEmailForFirebase(userKey);
      const matchingElderly = elderlyNormalizedMap[normalizedUserKey];
      
      if (matchingElderly) {
        console.log(`âœ… DIRECT MATCH: "${userKey}" -> "${matchingElderly.email}"`);
        
        // Process all medications for this user
        for (const [medKey, medication] of Object.entries(userMeds)) {
          if (!medication || typeof medication !== 'object') continue;
          
          console.log(`ðŸ’Š Adding: ${medication.medicationName} for ${matchingElderly.email} on ${medication.date}`);
          
          allElderlyMeds.push({
            id: medKey,
            type: 'medication',
            displayType: 'Medication',
            elderlyName: `${matchingElderly.firstname || ''} ${matchingElderly.lastname || ''}`.trim() || matchingElderly.email,
            elderlyEmail: matchingElderly.email,
            elderlyUid: matchingElderly.uid,
            source: 'medicationReminders',
            userKey: userKey,
            medicationName: medication.medicationName,
            date: medication.date,
            reminderTime: medication.reminderTime,
            dosage: medication.dosage,
            quantity: medication.quantity,
            isCompleted: medication.isCompleted || false,
            notes: medication.notes,
            ...medication
          });
        }
      } else {
        console.log(`âŒ No match for: "${userKey}" (normalized: "${normalizedUserKey}")`);
        console.log(`   Available elderly: ${Object.keys(elderlyNormalizedMap).join(', ')}`);
      }
    }

    // Filter based on date query
    const filteredMeds = filterItemsByDate(allElderlyMeds, dateQuery, 'date');
    
    // Sort by time
    const sortedMeds = filteredMeds.sort((a, b) => {
      const timeA = a.reminderTime || '00:00';
      const timeB = b.reminderTime || '00:00';
      return timeA.localeCompare(timeB);
    });

    console.log(`\nðŸ“Š FINAL RESULT: Found ${sortedMeds.length} medications`);
    
    if (sortedMeds.length > 0) {
      console.log("ðŸŽ¯ SUCCESS - Medications found:");
      sortedMeds.forEach((med, index) => {
        console.log(`${index + 1}. ${med.elderlyName} - ${med.medicationName} on ${med.date} at ${med.reminderTime}`);
      });
    }
    
    return sortedMeds;
  } catch (error) {
    console.error("ðŸ’¥ Error in medication function:", error);
    return [];
  }
}

// NEW: Special function for medication matching
function isMedicationMatch(medication, elderlyIdentifiers, userKey = '') {
  if (!medication) return false;
  
  // Check if userKey matches any elderly identifier
  if (userKey) {
    const normalizedUserKey = normalizeEmailForFirebase(userKey);
    const isUserKeyMatch = elderlyIdentifiers.some(identifier => {
      const normalizedIdentifier = normalizeEmailForFirebase(identifier);
      return normalizedUserKey === normalizedIdentifier;
    });
    
    if (isUserKeyMatch) {
      console.log(`âœ… Medication userKey match: ${userKey}`);
      return true;
    }
  }
  
  // Check medication elderlyId field
  if (medication.elderlyId) {
    const isElderlyIdMatch = elderlyIdentifiers.some(identifier => {
      if (!identifier) return false;
      
      const match = (
        medication.elderlyId.toLowerCase() === identifier.toLowerCase() ||
        normalizeEmailForFirebase(medication.elderlyId) === normalizeEmailForFirebase(identifier)
      );
      
      if (match) {
        console.log(`âœ… Medication elderlyId match: ${medication.elderlyId} === ${identifier}`);
      }
      return match;
    });
    
    if (isElderlyIdMatch) return true;
  }
  
  return false;
}
async function getElderlyActivitiesForCaregiver(caregiverUserId, dateQuery = 'today') {
  try {
    const elderlyData = await getCaregiverAssignedElderly(caregiverUserId);
    if (!elderlyData.success || elderlyData.elderly.length === 0) {
      console.log("âŒ No elderly assigned to caregiver");
      return [];
    }

    let allElderlyActivities = [];
    
    // Get all activities from database
    const activitiesRef = rtdb.ref("Activities");
    const activitiesSnapshot = await activitiesRef.get();
    
    if (!activitiesSnapshot.exists()) {
      console.log("âŒ No activities found in database");
      return [];
    }

    const allActivities = activitiesSnapshot.val();
    console.log(`ðŸ“Š Found ${Object.keys(allActivities).length} total activities in database`);
    
    // Process each elderly and find their activities
    for (const elderly of elderlyData.elderly) {
      // Create comprehensive list of identifiers for this elderly
      const elderlyIdentifiers = [
        elderly.uid,
        elderly.email,
        normalizeEmailForFirebase(elderly.email),
        elderly.identifier,
        elderly.uid?.toLowerCase(),
        elderly.email?.toLowerCase(),
        elderly.idKey
      ].filter(id => id && id !== 'Unknown');

      console.log(`ðŸ” Searching activities for elderly: ${elderly.email}`, {
        name: `${elderly.firstname} ${elderly.lastname}`,
        identifiers: elderlyIdentifiers
      });

      let foundActivities = 0;
      
      // Search through all activities
      for (const [activityId, activity] of Object.entries(allActivities)) {
        if (!activity || typeof activity !== 'object') continue;
        
        // DEBUG: Log activity structure
        console.log(`ðŸ“ Activity ${activityId}:`, {
          title: activity.title,
          hasRegistrations: !!activity.registrations,
          registrationCount: activity.registrations ? Object.keys(activity.registrations).length : 0
        });
        
        // Check registrations for this activity
        if (activity.registrations && typeof activity.registrations === 'object') {
          for (const [registrationId, registration] of Object.entries(activity.registrations)) {
            if (!registration || typeof registration !== 'object') continue;
            
            console.log(`ðŸ“‹ Registration ${registrationId}:`, {
              registeredEmail: registration.registeredEmail,
              status: registration.status,
              date: registration.date
            });
            
            // FIXED: Use direct email comparison for registrations
            const isMatch = elderlyIdentifiers.some(identifier => {
              if (!registration.registeredEmail) return false;
              
              // Direct email comparison
              if (registration.registeredEmail.toLowerCase() === identifier.toLowerCase()) {
                return true;
              }
              
              // Normalized email comparison
              const normalizedRegEmail = normalizeEmailForFirebase(registration.registeredEmail);
              const normalizedIdentifier = normalizeEmailForFirebase(identifier);
              if (normalizedRegEmail === normalizedIdentifier) {
                return true;
              }
              
              // Partial match for email variations
              if (identifier.toLowerCase().includes(registration.registeredEmail.toLowerCase()) ||
                  registration.registeredEmail.toLowerCase().includes(identifier.toLowerCase())) {
                return true;
              }
              
              return false;
            });
            
            if (isMatch) {
              console.log(`âœ… FOUND MATCH: Elderly ${elderly.email} registered for activity ${activity.title}`);
              foundActivities++;
              
              allElderlyActivities.push({
                id: activityId,
                registrationId: registrationId,
                type: 'activity',
                elderlyName: `${elderly.firstname || ''} ${elderly.lastname || ''}`.trim() || elderly.email,
                elderlyEmail: elderly.email,
                elderlyUid: elderly.uid,
                source: 'Activities',
                isRegistered: true,
                activityTitle: activity.title,
                activityDescription: activity.description,
                activityCategory: activity.category,
                activityDuration: activity.duration,
                activityDifficulty: activity.difficulty,
                activityImage: activity.image,
                registrationDate: registration.date,
                registrationTime: registration.time,
                registrationStatus: registration.status,
                // Include both activity and registration data
                ...activity,
                ...registration
              });
            }
          }
        }
        
        // FIXED: Remove direct activity matching as activities don't typically have elderly assignment
        // Activities are assigned through registrations, not direct elderly assignment
      }
      
      console.log(`âœ… Found ${foundActivities} registered activities for ${elderly.email}`);
    }

    // Filter based on date query
    const filteredActivities = filterItemsByDate(allElderlyActivities, dateQuery, 'registrationDate');
    
    // Sort by time
    const sortedActivities = filteredActivities.sort((a, b) => {
      const timeA = a.registrationTime || a.time || '10:00';
      const timeB = b.registrationTime || b.time || '10:00';
      return timeA.localeCompare(timeB);
    });

    console.log(`ðŸ“Š Final elderly activities count: ${sortedActivities.length}`);
    
    // DEBUG: Show what we found
    if (sortedActivities.length > 0) {
      console.log("ðŸŽ¯ Found elderly activities:");
      sortedActivities.forEach((activity, index) => {
        console.log(`${index + 1}. ${activity.elderlyName} - ${activity.activityTitle} on ${activity.registrationDate}`);
      });
    }
    
    return sortedActivities;
  } catch (error) {
    console.error("ðŸ’¥ Error getting elderly activities:", error);
    return [];
  }
}
// NEW: Special function for activity registration matching
function isActivityRegistrationMatch(registration, elderlyIdentifiers) {
  if (!registration || !registration.registeredEmail) {
    return false;
  }
  
  const registeredEmail = registration.registeredEmail.toLowerCase().trim();
  
  return elderlyIdentifiers.some(identifier => {
    if (!identifier) return false;
    
    const identifierStr = identifier.toString().toLowerCase().trim();
    
    // Direct match
    if (identifierStr === registeredEmail) {
      console.log(`âœ… Direct email match: ${identifierStr} === ${registeredEmail}`);
      return true;
    }
    
    // Normalized email match
    const normalizedIdentifier = normalizeEmailForFirebase(identifierStr);
    const normalizedRegistered = normalizeEmailForFirebase(registeredEmail);
    if (normalizedIdentifier === normalizedRegistered) {
      console.log(`âœ… Normalized email match: ${normalizedIdentifier} === ${normalizedRegistered}`);
      return true;
    }
    
    // Handle email variations
    if (registeredEmail.includes(identifierStr) || identifierStr.includes(registeredEmail)) {
      console.log(`âœ… Partial email match: ${identifierStr} <-> ${registeredEmail}`);
      return true;
    }
    
    return false;
  });
}
// FIXED: Get elderly reminders for caregiver
async function getElderlyRemindersForCaregiver(caregiverUserId, dateQuery = 'upcoming') {
  try {
    console.log("â° FIXED: Getting reminders for caregiver:", caregiverUserId);
    
    const elderlyData = await getCaregiverAssignedElderly(caregiverUserId);
    if (!elderlyData.success || elderlyData.elderly.length === 0) {
      console.log("âŒ No elderly assigned to caregiver");
      return [];
    }

    let allElderlyReminders = [];
    
    // Get all reminders from reminders path
    const remindersRef = rtdb.ref('reminders');
    const remindersSnapshot = await remindersRef.get();
    
    if (!remindersSnapshot.exists()) {
      console.log("âŒ No reminders found in database");
      return [];
    }

    const remindersData = remindersSnapshot.val();
    console.log("ðŸ“Š Found reminder keys:", Object.keys(remindersData));
    
    // Create mapping of elderly normalized emails
    const elderlyNormalizedMap = {};
    elderlyData.elderly.forEach(elderly => {
      const normalizedEmail = normalizeEmailForFirebase(elderly.email);
      elderlyNormalizedMap[normalizedEmail] = elderly;
      console.log(`ðŸ‘µ Elderly mapping: "${elderly.email}" -> "${normalizedEmail}"`);
    });

    // DIRECT MATCHING: Check each reminder user key
    for (const [userKey, userReminders] of Object.entries(remindersData)) {
      if (!userReminders || typeof userReminders !== 'object') continue;
      
      console.log(`\nðŸ” Processing reminder user key: "${userKey}"`);
      
      // Check if this userKey matches any elderly normalized email
      const normalizedUserKey = normalizeEmailForFirebase(userKey);
      const matchingElderly = elderlyNormalizedMap[normalizedUserKey];
      
      if (matchingElderly) {
        console.log(`âœ… DIRECT MATCH: "${userKey}" -> "${matchingElderly.email}"`);
        
        // Process all reminders for this user
        for (const [reminderKey, reminder] of Object.entries(userReminders)) {
          if (!reminder || typeof reminder !== 'object') continue;
          
          console.log(`â° Adding: ${reminder.title} for ${matchingElderly.email} on ${reminder.startTime}`);
          
          allElderlyReminders.push({
            id: reminderKey,
            type: 'reminder',
            displayType: 'Elderly Reminder',
            elderlyName: `${matchingElderly.firstname || ''} ${matchingElderly.lastname || ''}`.trim() || matchingElderly.email,
            elderlyEmail: matchingElderly.email,
            elderlyUid: matchingElderly.uid,
            source: 'reminders',
            userKey: userKey,
            title: reminder.title,
            startTime: reminder.startTime,
            duration: reminder.duration,
            ...reminder
          });
        }
      } else {
        console.log(`âŒ No match for: "${userKey}" (normalized: "${normalizedUserKey}")`);
        console.log(`   Available elderly: ${Object.keys(elderlyNormalizedMap).join(', ')}`);
      }
    }

    // Filter based on date query - FIXED: Use consistent function name
    const filteredReminders = filterItemsByDateforEvent(allElderlyReminders, dateQuery, 'startTime');
    
    // Sort by time
    const sortedReminders = filteredReminders.sort((a, b) => {
      const timeA = a.startTime || '00:00';
      const timeB = b.startTime || '00:00';
      return new Date(timeA) - new Date(timeB);
    });

    console.log(`ðŸ“Š FINAL: Found ${sortedReminders.length} reminders`);
    
    if (sortedReminders.length > 0) {
      console.log("ðŸŽ¯ SUCCESS - Reminders found:");
      sortedReminders.forEach((reminder, index) => {
        console.log(`${index + 1}. ${reminder.elderlyName} - ${reminder.title} on ${reminder.startTime}`);
      });
    }
    
    return sortedReminders;
  } catch (error) {
    console.error("ðŸ’¥ Error getting elderly reminders:", error);
    return [];
  }
}

// ENHANCED: Better date filtering for reminders
function filterItemsByDateforEvent(items, dateQuery, dateField = 'date') {
  const today = new Date();
  today.setHours(0, 0, 0, 0);
  
  const tomorrow = new Date(today);
  tomorrow.setDate(tomorrow.getDate() + 1);
  
  const yesterday = new Date(today);
  yesterday.setDate(yesterday.getDate() - 1);
  
  console.log(`ðŸ“… Filtering ${items.length} items by date: ${dateQuery}, field: ${dateField}`);
  
  switch (dateQuery) {
    case 'today':
      return items.filter(item => {
        const itemDate = getItemDateforEvent(item, dateField); // FIXED: Consistent function name
        if (!itemDate) return false;
        return itemDate.getTime() === today.getTime();
      });
      
    case 'tomorrow':
      return items.filter(item => {
        const itemDate = getItemDateforEvent(item, dateField); // FIXED: Consistent function name
        if (!itemDate) return false;
        return itemDate.getTime() === tomorrow.getTime();
      });
      
    case 'yesterday':
      return items.filter(item => {
        const itemDate = getItemDateforEvent(item, dateField); // FIXED: Consistent function name
        if (!itemDate) return false;
        return itemDate.getTime() === yesterday.getTime();
      });
      
    case 'past':
      return items.filter(item => {
        const itemDate = getItemDateforEvent(item, dateField); // FIXED: Consistent function name
        if (!itemDate) return false;
        return itemDate < today;
      });
      
    case 'all':
      return items;
      
    case 'upcoming':
    default:
      return items.filter(item => {
        const itemDate = getItemDateforEvent(item, dateField); // FIXED: Consistent function name
        if (!itemDate) return false;
        return itemDate >= today;
      });
  }
}

// Helper function to get date from different field types
function getItemDateforEvent(item, dateField) {
  if (!item[dateField]) return null;
  
  try {
    let dateStr = item[dateField];
    
    // Handle different date formats
    if (dateField === 'startTime' && dateStr.includes('T')) {
      // Parse ISO date string like "2025-11-06T21:00"
      const date = new Date(dateStr);
      date.setHours(0, 0, 0, 0);
      return isNaN(date.getTime()) ? null : date;
    } else {
      // Regular date string
      const date = new Date(dateStr);
      date.setHours(0, 0, 0, 0);
      return isNaN(date.getTime()) ? null : date;
    }
  } catch (error) {
    console.error(`âŒ Error parsing date: ${item[dateField]}`, error);
    return null;
  }
}
function formatReminderDateTime(startTime) {
  if (!startTime || typeof startTime !== "string") {
    return { date: "Unknown date", time: "Unknown time" };
  }

  try {
    let date;

    // Handle ISO format like "2025-11-09T21:30"
    if (startTime.includes("T")) {
      // Try parsing as-is first
      date = new Date(startTime);
      
      // If that fails, try with timezone
      if (isNaN(date.getTime())) {
        date = new Date(startTime + "Z");
      }
    } else {
      // Try direct parsing for other formats
      date = new Date(startTime);
    }

    if (isNaN(date.getTime())) {
      console.log("âŒ Invalid reminder date:", startTime);
      return { date: "Unknown date", time: "Unknown time" };
    }

    const formattedDate = date.toLocaleDateString("en-US", {
      weekday: "long",
      year: "numeric",
      month: "long",
      day: "numeric",
    });

    // Check if it's a full datetime or just a date
    const hasTime = startTime.includes("T") && !startTime.endsWith("T00:00") && !startTime.includes("T00:00:00");
    
    const formattedTime = hasTime
      ? date.toLocaleTimeString("en-US", {
          hour: "2-digit",
          minute: "2-digit",
          hour12: true,
        })
      : "All day";

    return {
      date: formattedDate,
      time: formattedTime,
      isAllDay: !hasTime,
    };
  } catch (err) {
    console.error("âŒ Error formatting reminder:", startTime, err);
    return { date: "Unknown date", time: "Unknown time" };
  }
}

// Helper function to get elderly name from reminder
function getElderlyNameFromReminder(reminder, elderlyList) {
  if (!reminder || !elderlyList) return 'Elderly Patient';
  
  // Try to find which elderly this reminder belongs to
  for (const elderly of elderlyList) {
    if (reminder.userId === elderly.email || 
        reminder.userId === elderly.uid ||
        reminder.elderlyId === elderly.uid) {
      return `${elderly.firstname || ''} ${elderly.lastname || ''}`.trim() || elderly.email;
    }
  }
  
  return 'Elderly Patient';
}
// NEW FUNCTION: Get consultations specifically assigned to caregiver
async function getCaregiverSpecificConsultations(caregiverUserId, dateQuery = 'upcoming') {
  try {
    console.log("ðŸ‘¨â€âš•ï¸ Getting caregiver-specific consultations for:", caregiverUserId);
    
    // Get caregiver data to get UID
    const caregiverData = await getUserData(caregiverUserId, { type: 'user_info', subType: 'all' });
    if (!caregiverData) {
      return [];
    }

    const caregiverUid = caregiverData.userInfo.uid;
    const caregiverEmail = caregiverData.userInfo.email;
    
    const caregiverIdentifiers = [
      caregiverUid,
      caregiverEmail,
      normalizeEmailForFirebase(caregiverEmail),
      caregiverUserId,
      caregiverUid?.toLowerCase(),
      caregiverEmail?.toLowerCase()
    ].filter(id => id && id !== 'Unknown');

    console.log("ðŸ” Caregiver identifiers for consultation matching:", caregiverIdentifiers);

    // Get all consultations from both consultations and appointments nodes
    const consultationsRef = rtdb.ref("consultations");
    const appointmentsRef = rtdb.ref("Appointments");
    
    const [consultationsSnap, appointmentsSnap] = await Promise.all([
      consultationsRef.get(),
      appointmentsRef.get()
    ]);

    let caregiverSpecificConsultations = [];

    // Process consultations from consultations node
    if (consultationsSnap.exists()) {
      const consultations = consultationsSnap.val();
      Object.entries(consultations).forEach(([consultId, consultation]) => {
        if (consultation && isCaregiverSpecificMatch(consultation, caregiverIdentifiers)) {
          caregiverSpecificConsultations.push({
            id: consultId,
            type: 'consultation',
            source: 'consultations',
            isCaregiverSpecific: true,
            ...consultation
          });
        }
      });
    }

    // Process consultations from Appointments node
    if (appointmentsSnap.exists()) {
      const appointments = appointmentsSnap.val();
      Object.entries(appointments).forEach(([apptId, appointment]) => {
        if (appointment && 
            (appointment.type === 'consultation' || 
             appointment.appointmentType === 'consultation' ||
             appointment.title?.toLowerCase().includes('consultation')) && 
            isCaregiverSpecificMatch(appointment, caregiverIdentifiers)) {
          caregiverSpecificConsultations.push({
            id: apptId,
            type: 'consultation',
            source: 'Appointments',
            isCaregiverSpecific: true,
            ...appointment
          });
        }
      });
    }

    console.log(`âœ… Found ${caregiverSpecificConsultations.length} caregiver-specific consultations`);

    // Filter based on date query
    const filteredConsultations = filterConsultationsByDate(caregiverSpecificConsultations, dateQuery);

    return filteredConsultations;

  } catch (error) {
    console.error("ðŸ’¥ Error getting caregiver-specific consultations:", error);
    return [];
  }
}

// NEW FUNCTION: Check if consultation is specifically assigned to caregiver
function isCaregiverSpecificMatch(consultation, caregiverIdentifiers) {
  if (!consultation) return false;

  // Check fields that might indicate caregiver assignment
  const caregiverFields = [
    consultation.caregiverId,
    consultation.assignedCaregiver,
    consultation.caregiverUid,
    consultation.caregiverEmail,
    consultation.invitedCaregiver,
    consultation.caregiverInvite,
    // Also check general assignment fields that might point to caregiver
    consultation.assignedTo,
    consultation.assignedProvider
  ].filter(field => field !== undefined && field !== null && field !== '');

  console.log(`ðŸ” Checking caregiver-specific match:`, {
    caregiverFields: caregiverFields,
    caregiverIdentifiers: caregiverIdentifiers
  });

  // Check if any caregiver field matches caregiver identifiers
  const isMatch = caregiverFields.some(field => {
    if (!field) return false;
    
    const fieldStr = String(field).toLowerCase().trim();
    return caregiverIdentifiers.some(identifier => {
      const identifierStr = String(identifier).toLowerCase().trim();
      
      const match = (
        identifierStr === fieldStr ||
        fieldStr.includes(identifierStr) ||
        identifierStr.includes(fieldStr) ||
        normalizeEmailForComparison(identifierStr) === normalizeEmailForComparison(fieldStr)
      );
      
      if (match) {
        console.log(`âœ… Caregiver-specific match: ${fieldStr} === ${identifierStr}`);
      }
      return match;
    });
  });

  console.log(`ðŸ“Š Caregiver-specific match result: ${isMatch}`);
  return isMatch;
}

// NEW FUNCTION: Filter caregiver events by date query
function filterCaregiverEventsByDate(events, dateQuery) {
  const today = new Date();
  today.setHours(0, 0, 0, 0);
  
  const tomorrow = new Date(today);
  tomorrow.setDate(tomorrow.getDate() + 1);
  
  switch (dateQuery) {
    case 'today':
      return events.filter(event => {
        if (!event.sortDate) return false;
        try {
          const eventDate = new Date(event.sortDate);
          eventDate.setHours(0, 0, 0, 0);
          return eventDate.getTime() === today.getTime();
        } catch (error) {
          return false;
        }
      });
      
    case 'tomorrow':
      return events.filter(event => {
        if (!event.sortDate) return false;
        try {
          const eventDate = new Date(event.sortDate);
          eventDate.setHours(0, 0, 0, 0);
          return eventDate.getTime() === tomorrow.getTime();
        } catch (error) {
          return false;
        }
      });
      
    case 'past':
      return events.filter(event => {
        if (!event.sortDate) return false;
        try {
          const eventDate = new Date(event.sortDate);
          eventDate.setHours(0, 0, 0, 0);
          return eventDate < today;
        } catch (error) {
          return false;
        }
      });
      
    case 'all':
      return events;
      
    case 'upcoming':
    default:
      return events.filter(event => {
        if (!event.sortDate) return false;
        try {
          const eventDate = new Date(event.sortDate);
          eventDate.setHours(0, 0, 0, 0);
          return eventDate >= today;
        } catch (error) {
          return false;
        }
      });
  }
}

// Helper function to get elderly name from medication
function getElderlyNameFromMedication(medication, elderlyList) {
  if (!medication || !elderlyList) return 'Elderly Patient';
  
  // Try to find which elderly this medication belongs to
  for (const elderly of elderlyList) {
    if (medication.userId === elderly.email || 
        medication.userId === elderly.uid ||
        medication.elderlyId === elderly.uid) {
      return `${elderly.firstname || ''} ${elderly.lastname || ''}`.trim() || elderly.email;
    }
  }
  
  return 'Elderly Patient';
}

// Helper function to get elderly name from activity  
function getElderlyNameFromActivity(activity, elderlyList) {
  if (!activity || !elderlyList) return 'Elderly Patient';
  
  // For activities, check registration email
  if (activity.registeredEmail) {
    for (const elderly of elderlyList) {
      if (activity.registeredEmail === elderly.email) {
        return `${elderly.firstname || ''} ${elderly.lastname || ''}`.trim() || elderly.email;
      }
    }
  }
  
  return 'Elderly Patient';
}

/* ---------------------------------------------------
 ðŸ‘¨â€âš•ï¸ CAREGIVER RESPONSE GENERATORS
--------------------------------------------------- */

function generateCaregiverElderlyResponse(caregiverInfo, elderlyData) {
  if (elderlyData.elderly.length === 0) {
    return `You don't have any elderly assigned to your care, ${caregiverInfo.name}.`;
  }

  let response = `You are caring for ${elderlyData.elderly.length} elderly:\n\n`;

  elderlyData.elderly.forEach((elderly, index) => {
    response += `${index + 1}. ${elderly.firstname} ${elderly.lastname}\n`;
    response += `   Email: ${elderly.email}\n`;
    
    if (elderly.healthSummary && !elderly.healthSummary.error) {
      const health = elderly.healthSummary;
      response += `   Age: ${health.age || 'Unknown'}\n`;
      response += `   Medications: ${health.totalMedications} total, ${health.pendingMedications} pending\n`;
      response += `   Adherence: ${health.medicationAdherence}%\n`;
      response += `   Upcoming appointments: ${health.upcomingAppointments}\n`;
    }
    
    if (elderly.upcomingAppointments && elderly.upcomingAppointments.length > 0) {
      const nextAppointment = elderly.upcomingAppointments[0];
      response += `   Next appointment: ${nextAppointment.title} on ${formatDisplayDate(nextAppointment.date)}\n`;
    }
    
    response += `\n`;
  });

  return response;
}

// ENHANCED: Better response generator for caregiver schedule
function generateEnhancedCaregiverScheduleResponse(caregiverInfo, scheduleData) {
  const userName = caregiverInfo?.name || 'Caregiver';
  const timeContext = getCaregiverTimeContext(scheduleData.summary?.dateQuery || 'upcoming');
  
  if (scheduleData.totalEvents === 0) {
    return `You don't have any ${timeContext} in your schedule, ${userName}.`;
  }

  let response = `Your ${timeContext}, ${userName}\n\n`;

  // CAREGIVER'S PERSONAL EVENTS
  const caregiverEvents = scheduleData.schedule.filter(event => event.isCaregiverEvent);
  if (caregiverEvents.length > 0) {
    response += `Your Personal Schedule\n`;
    
    caregiverEvents.forEach((event, index) => {
      const typeLabel = event.isInvitation ? 'Invitation' : event.displayType;
      
      response += `${index + 1}. ${event.title}\n`;
     
      if (event.eventType === 'elderly_reminder' && event.startTime) {
        const reminderDateTime = formatReminderDateTime(event.startTime);
        response += `   Date: ${reminderDateTime.date}\n`;
        if (!reminderDateTime.isAllDay) {
          response += `   Time: ${reminderDateTime.time}\n`;
        }
      } else {
        response += `   Date: ${formatDisplayDate(event.date || event.appointmentDate)}\n`;
      }

      if (event.time || event.reminderTime) {
        response += `   Time: ${formatDisplayTime(event.time || event.reminderTime)}\n`;
      }
      
      if (event.location) response += `   Location: ${event.location}\n`;
      if (event.doctor) response += `   Doctor: ${event.doctor}\n`;
      response += `   Type: ${typeLabel}\n`;
      
      if (event.isInvitation) {
        response += `   Consultation Invitation\n`;
      }
      
      response += `\n`;
    });
  }

  // ELDERLY PATIENT EVENTS
  const elderlyEvents = scheduleData.schedule.filter(event => event.isElderlyEvent);
  if (elderlyEvents.length > 0) {
    if (caregiverEvents.length > 0) {
      response += `\n`;
    }
    
    response += `Elderly Patient Schedule\n`;
    
    // Group by elderly
    const eventsByElderly = {};
    elderlyEvents.forEach(event => {
      const elderlyName = event.elderlyName || 'Elderly Patient';
      if (!eventsByElderly[elderlyName]) {
        eventsByElderly[elderlyName] = [];
      }
      eventsByElderly[elderlyName].push(event);
    });

    let eventCounter = caregiverEvents.length + 1;
    
    Object.entries(eventsByElderly).forEach(([elderlyName, events]) => {
      response += `\n${elderlyName}\n`;
      
      events.forEach((event, index) => {
        response += `${eventCounter}. ${event.title}\n`;
        
        // Handle date display based on event type
        if (event.eventType === 'elderly_reminder' && event.startTime) {
          const reminderDateTime = formatReminderDateTime(event.startTime);
          if (reminderDateTime.date !== 'Unknown date') {
            response += `   Date: ${reminderDateTime.date}\n`;
          }
          if (!reminderDateTime.isAllDay) {
            response += `   Time: ${reminderDateTime.time}\n`;
          }
        } else {
          // For non-reminder events, use regular date formatting
          response += `   Date: ${formatDisplayDate(event.date || event.appointmentDate)}\n`;
          if (event.time || event.reminderTime) {
            response += `   Time: ${formatDisplayTime(event.time || event.reminderTime)}\n`;
          }
        }
        
        if (event.location) response += `   Location: ${event.location}\n`;
        if (event.doctor) response += `   Doctor: ${event.doctor}\n`;
        
        // Add specific details based on event type
        switch (event.eventType) {
          case 'elderly_medication':
            if (event.dosage) response += `   Dosage: ${event.dosage}\n`;
            if (event.quantity) response += `   Quantity: ${event.quantity}\n`;
            if (event.isCompleted !== undefined) {
              response += `   Status: ${event.isCompleted ? 'Taken' : 'Pending'}\n`;
            }
            response += `   Type: Medication\n`;
            break;
          case 'elderly_activity':
            if (event.category) response += `   Category: ${event.category}\n`;
            if (event.duration) response += `   Duration: ${event.duration}\n`;
            response += `   Type: Activity\n`;
            break;
          case 'elderly_reminder':
            // Date and time already handled above, just add description and duration
            if (event.description && event.description !== event.title) {
              response += `   Description: ${event.description}\n`;
            }
            if (event.duration) {
              response += `   Duration: ${event.duration} min\n`;
            }
            response += `   Type: ${event.displayType}\n`;
            break;
          default:
            response += `   Type: ${event.displayType || 'Event'}\n`;
            break;
        }
        
        response += `\n`;
        eventCounter++;
      });
    });
  }

  // SUMMARY
  response += `Summary:\n`;
  response += `â€¢ Your consultations: ${scheduleData.summary?.totalConsultations || 0}\n`;
  response += `â€¢ Elderly appointments: ${scheduleData.summary?.totalElderlyAppointments || 0}\n`;
  response += `â€¢ Elderly medications: ${scheduleData.summary?.totalElderlyMedications || 0}\n`;
  response += `â€¢ Elderly activities: ${scheduleData.summary?.totalElderlyActivities || 0}\n`;
  response += `â€¢ Elderly reminders: ${scheduleData.summary?.totalElderlyReminders || 0}\n`;
  response += `â€¢ Total events: ${scheduleData.totalEvents}\n`;
  
  if (scheduleData.summary?.totalElderly > 0) {
    response += `â€¢ Elderly patients: ${scheduleData.summary.totalElderly}\n`;
  }

  return response;
}
// NEW FUNCTION: Get proper time context for caregiver schedule
function getCaregiverTimeContext(dateQuery) {
  switch (dateQuery) {
    case 'today': return "Today's Schedule";
    case 'tomorrow': return "Tomorrow's Schedule";
    case 'yesterday': return "Yesterday's Schedule";
    case 'past': return 'Past Schedule';
    case 'all': return 'Complete Schedule';
    case 'upcoming': 
    default: return 'Upcoming Schedule';
  }
}
// Enhanced event icons for better visualization
function getEventIcon(eventType) {
  switch (eventType) {
    case 'caregiver_consultation':
    case 'caregiver_specific_consultation':
    case 'elderly_consultation': 
      return 'ðŸ¥';
    case 'elderly_appointment': 
      return 'ðŸ“…';
    case 'elderly_medication': 
      return 'ðŸ’Š';
    case 'elderly_activity': 
      return 'ðŸŽ¯';
    case 'elderly_reminder': 
      return 'â°';
    default: 
      return 'ðŸ“Œ';
  }
}
// ENHANCED: Better response formatting
function generateElderlyAppointmentsNotification(caregiverInfo, appointmentsData) {
  if (appointmentsData.totalAppointments === 0) {
    let response = `No upcoming appointments found for your elderly patients, ${caregiverInfo.name}.\n\n`;
    
    if (appointmentsData.elderlyList && appointmentsData.elderlyList.length > 0) {
      response += `**Your assigned elderly:**\n`;
      appointmentsData.elderlyList.forEach((elderly, index) => {
        response += `${index + 1}. ${elderly.name} (${elderly.email})\n`;
      });
    }
    
    response += `\n**Note:** This could mean:\n`;
    response += `â€¢ No appointments are currently scheduled\n`;
    response += `â€¢ Appointments might be in different format in database\n`;
    response += `â€¢ Check if appointments exist in Appointments node\n`;
    
    return response;
  }

  let response = `**Upcoming appointments for your elderly patients, ${caregiverInfo.name}:**\n\n`;

  // Group appointments by elderly
  const appointmentsByElderly = {};
  appointmentsData.appointments.forEach(apt => {
    if (!appointmentsByElderly[apt.elderlyEmail]) {
      appointmentsByElderly[apt.elderlyEmail] = [];
    }
    appointmentsByElderly[apt.elderlyEmail].push(apt);
  });

  // Show appointments grouped by elderly
  Object.entries(appointmentsByElderly).forEach(([elderlyEmail, elderlyAppointments]) => {
    const elderly = appointmentsData.elderlyList?.find(e => e.email === elderlyEmail) || { name: 'Unknown Elderly' };
    
    response += `ðŸ‘µ **${elderly.name}**\n`;
    
    elderlyAppointments.forEach((apt, index) => {
      const dateField = apt.date || apt.appointmentDate;
      const timeField = apt.time || apt.appointmentTime;
      
      response += `${index + 1}. ${apt.title || apt.reason || 'Appointment'}\n`;
      response += `   ðŸ“… ${formatDisplayDate(dateField)}\n`;
      if (timeField) response += `   â° ${formatDisplayTime(timeField)}\n`;
      if (apt.location) response += `   ðŸ“ ${apt.location}\n`;
      if (apt.doctor || apt.provider) response += `   ðŸ‘¨â€âš•ï¸ ${apt.doctor || apt.provider}\n`;
      if (apt.notes) response += `   ðŸ“ ${apt.notes}\n`;
      response += `   ðŸ”§ Type: ${apt.appointmentType || apt.type || 'appointment'}\n`;
      response += `\n`;
    });
    
    response += `\n`;
  });

  response += `**Summary:** ${appointmentsData.totalAppointments} upcoming appointments across ${Object.keys(appointmentsByElderly).length} elderly patients.`;

  return response;
}

/* ---------------------------------------------------
 ðŸ“š Learning Resources Functions
--------------------------------------------------- */
async function getLearningResources(category = null, searchQuery = null) {
  try {
    const resourcesRef = rtdb.ref("resources");
    const snapshot = await resourcesRef.get();
    
    if (!snapshot.exists()) {
      return [];
    }
    
    const resources = snapshot.val();
    const resourceList = Object.keys(resources).map(key => {
      const resource = resources[key];
      return {
        id: key,
        title: resource.title || 'Untitled',
        description: resource.description || '',
        category: resource.category || 'General',
        url: resource.url || '',
        createdAt: resource.createdAt || '',
        ...resource
      };
    });
    
    let filteredResources = resourceList;
    if (category && category !== 'All') {
      filteredResources = resourceList.filter(resource => {
        const resourceCategory = resource.category || '';
        return resourceCategory.toLowerCase().includes(category.toLowerCase());
      });
    }
    
    if (searchQuery) {
      filteredResources = filteredResources.filter(resource => {
        const title = resource.title || '';
        const description = resource.description || '';
        const resourceCategory = resource.category || '';
        
        return (
          title.toLowerCase().includes(searchQuery.toLowerCase()) ||
          description.toLowerCase().includes(searchQuery.toLowerCase()) ||
          resourceCategory.toLowerCase().includes(searchQuery.toLowerCase())
        );
      });
    }
    
    return filteredResources.slice(0, 20);
    
  } catch (error) {
    return [];
  }
}

async function getUserLearningData(userId) {
  if (!validateEmail(userId)) return null;

  try {
    const userData = await getUserData(userId, { type: 'user_info', subType: 'all' });
    if (!userData) {
      return null;
    }

    const { userInfo } = userData;
    const normalizedEmail = normalizeEmailForFirebase(userId);

    let pointsData = null;
    let foundPath = null;

    const userRef = rtdb.ref(`Account/${normalizedEmail}`);
    const userSnap = await userRef.get();
    
    if (userSnap.exists()) {
      const userData = userSnap.val();
      
      if (userData.pointsData) {
        pointsData = userData.pointsData;
        foundPath = `Account/${normalizedEmail}/pointsData`;
      } else if (userData.learningData) {
        pointsData = userData.learningData;
        foundPath = `Account/${normalizedEmail}/learningData`;
      } else if (userData.currentPoints !== undefined) {
        pointsData = {
          currentPoints: userData.currentPoints || 0,
          totalEarned: userData.totalEarned || userData.currentPoints || 0,
          dailyStreak: userData.dailyStreak || userData.streak || 0,
          pointHistory: userData.pointHistory || [],
          lastLearningDate: userData.lastLearningDate || null,
          resourcesClicked: userData.resourcesClicked || [],
          averageTimePerSession: userData.averageTimePerSession || 0,
          completedResources: userData.completedResources || 0,
          totalLearningTime: userData.totalLearningTime || 0,
          totalResources: userData.totalResources || 0
        };
        foundPath = `Account/${normalizedEmail} (root level)`;
      }
    }

    if (!pointsData) {
      const underscoreEmail = userId.toLowerCase().replace(/[\.@]/g, "_");
      const underscoreRef = rtdb.ref(`Account/${underscoreEmail}`);
      const underscoreSnap = await underscoreRef.get();
      
      if (underscoreSnap.exists()) {
        const userData = underscoreSnap.val();
        if (userData.pointsData) {
          pointsData = userData.pointsData;
          foundPath = `Account/${underscoreEmail}/pointsData`;
        }
      }
    }

    if (!pointsData) {
      const learningRef = rtdb.ref(`learningData/${normalizedEmail}`);
      const learningSnap = await learningRef.get();
      
      if (learningSnap.exists()) {
        pointsData = learningSnap.val();
        foundPath = `learningData/${normalizedEmail}`;
      }
    }

    if (!pointsData) {
      pointsData = {
        currentPoints: 0,
        totalEarned: 0,
        dailyStreak: 0,
        pointHistory: [],
        lastLearningDate: null,
        resourcesClicked: [],
        averageTimePerSession: 0,
        completedResources: 0,
        totalLearningTime: 0,
        totalResources: 0
      };
      foundPath = "default";
    }

    pointsData = {
      currentPoints: pointsData.currentPoints || 0,
      totalEarned: pointsData.totalEarned || pointsData.currentPoints || 0,
      dailyStreak: pointsData.dailyStreak || pointsData.streak || 0,
      pointHistory: pointsData.pointHistory || [],
      lastLearningDate: pointsData.lastLearningDate || null,
      resourcesClicked: pointsData.resourcesClicked || [],
      averageTimePerSession: pointsData.averageTimePerSession || 0,
      completedResources: pointsData.completedResources || 0,
      totalLearningTime: pointsData.totalLearningTime || 0,
      totalResources: pointsData.totalResources || 0
    };

    return { 
      userInfo, 
      learningData: pointsData,
      dataSource: foundPath
    };

  } catch (error) {
    const learningData = {
      currentPoints: 0,
      totalEarned: 0,
      dailyStreak: 0,
      pointHistory: [],
      lastLearningDate: null,
      resourcesClicked: []
    };
    return { userInfo, learningData, dataSource: "error_default" };
  }
}

function generatePointsResponse(userInfo, learningData) {
  const { 
    currentPoints = 0, 
    totalEarned = 0, 
    dailyStreak = 0,
    pointHistory = [],
    resourcesClicked = []
  } = learningData || {};
  
  let response = `ðŸŽ¯ **Your Learning Progress**, ${userInfo.name}!\n\n`;
  response += `ðŸŸ£ **Current Points:** ${currentPoints}\n`;
  response += `ðŸ† **Total Points Earned:** ${totalEarned}\n`;
  response += `ðŸ”¥ **Daily Streak:** ${dailyStreak} day${dailyStreak !== 1 ? 's' : ''}\n`;
  response += `ðŸ“š **Resources Viewed:** ${resourcesClicked.length}\n\n`;
  
  if (currentPoints >= 50) {
    const vouchers = Math.floor(currentPoints / 50);
    const remainingPoints = currentPoints % 50;
    response += `ðŸŽ **Reward Available!** You can redeem ${vouchers} voucher${vouchers > 1 ? 's' : ''} ($${vouchers * 5})\n`;
    response += `ðŸ’° You have ${currentPoints} points (${remainingPoints} points toward next voucher)\n`;
    response += `ðŸ”” *Say "redeem points" to get your voucher!*\n`;
  } else {
    const pointsNeeded = 50 - currentPoints;
    response += `ðŸ“ˆ You need ${pointsNeeded} more points to redeem your first $5 voucher!\n`;
    response += `ðŸŒ± *Earn points by exploring learning resources!*\n`;
  }
  
  if (pointHistory && pointHistory.length > 0) {
    const recentHistory = pointHistory.slice(-3).reverse();
    response += `\nðŸ“ **Recent Activity:**\n`;
    recentHistory.forEach(entry => {
      const date = new Date(entry.timestamp).toLocaleDateString();
      response += `â€¢ +${entry.points} pts: ${entry.reason} (${date})\n`;
    });
  }
  
  response += `\nðŸ”” **How to Earn Points:**\n`;
  response += `â€¢ Click on learning resources to earn 1 point each\n`;
  response += `â€¢ Learn daily to build your streak and earn bonuses\n`;
  response += `â€¢ Complete resources for extra rewards\n`;
  response += `â€¢ 50 points = $5 voucher reward!\n`;
  
  return response;
}

function generateStreakResponse(userInfo, learningData) {
  const { dailyStreak = 0, lastLearningDate = null, currentPoints = 0 } = learningData || {};
  
  let response = `ðŸ”¥ **Your Learning Streak**, ${userInfo.name}!\n\n`;
  response += `ðŸ“… **Current Streak:** ${dailyStreak} day${dailyStreak !== 1 ? 's' : ''}\n`;
  
  if (lastLearningDate) {
    const lastDate = new Date(lastLearningDate).toLocaleDateString();
    response += `â° **Last Learning Activity:** ${lastDate}\n`;
  }
  
  response += `ðŸŸ£ **Current Points:** ${currentPoints}\n\n`;
  
  if (dailyStreak === 0) {
    response += `ðŸ”” **Start your streak today!** Learn something new to begin building your daily learning habit.\n`;
  } else if (dailyStreak < 7) {
    response += `ðŸ”” **Keep going!** Continue learning daily to earn streak bonuses and unlock rewards!\n`;
  } else if (dailyStreak < 30) {
    response += `ðŸŽ‰ **Great consistency!** You're building a strong learning habit. Keep it up!\n`;
  } else {
    response += `ðŸ† **Amazing dedication!** You've maintained your learning streak for over a month!\n`;
  }
  
  response += `\nðŸŒ± **Streak Benefits:**\n`;
  response += `â€¢ Daily learning builds better memory retention\n`;
  response += `â€¢ Consistent streaks earn bonus points\n`;
  response += `â€¢ Unlock achievement badges for milestones\n`;
  response += `â€¢ Improve overall wellbeing through continuous learning\n`;
  
  return response;
}

function generateResourcesListResponse(userInfo, learningData, resources, query) {
  const { currentPoints = 0, resourcesClicked = [] } = learningData;

  let response = ` **Learning Resources for You, ${userInfo.name}!**\n\n`;

  if (resources.length === 0) {
    response += `No learning resources found matching "${query}".\n\n`;
    response += `**Try searching for:**\n`;
    response += `â€¢ "health" - Health and wellness resources\n`;
    response += `â€¢ "exercise" - Physical activity guides\n`;
    response += `â€¢ "technology" - Digital literacy and safety\n`;
    response += `â€¢ "safety" - Home safety and fraud prevention\n`;
    response += `â€¢ "mental health" - Emotional wellbeing resources\n`;
    return response;
  }

  response += `Found ${resources.length} resources:\n\n`;

  resources.slice(0, 8).forEach((resource, index) => {
    const isViewed = resourcesClicked.includes(resource.id);
    const status = isViewed ? "âœ… Viewed" : "ðŸ”” New";
    const category = resource.category || "General";

    response += `${index + 1}. **${resource.title}**\n`;
    response += `   ${resource.description || "No description available"}\n`;
    response += `   ${category} â€¢ ${status}\n\n`;
  });

  if (resources.length > 8) {
    response += `... and ${resources.length - 8} more resources available!\n\n`;
  }

  response += `ðŸ”” **How to earn points:**\n`;
  response += `â€¢ Click on resources to earn 1 point each\n`;
  response += `â€¢ Learn daily for streak bonuses\n`;
  response += `â€¢ Complete resources for extra rewards\n\n`;
  response += ` You currently have **${currentPoints}** learning points.`;

  return response;
}

function generateLearningResourcesResponse(userInfo, learningData, resources, userMessage, intent = {}) {
  const lowerMessage = (userMessage || "").toLowerCase();

  // Points and rewards queries
  if (lowerMessage.includes("point") || 
      lowerMessage.includes("reward") || 
      lowerMessage.includes("score") || 
      lowerMessage.includes("voucher") ||
      lowerMessage.includes("progress")) {
    return generatePointsResponse(userInfo, learningData);
  }

  // Streak queries
  if (lowerMessage.includes("streak") || lowerMessage.includes("daily")) {
    return generateStreakResponse(userInfo, learningData);
  }

  // Specific topic queries - ENHANCED
  if (lowerMessage.includes("exercise topic") || 
      lowerMessage.includes("exercise topics") ||
      intent.subType === "exercise" ||
      (lowerMessage.includes("exercise") && !lowerMessage.includes("appointment"))) {
    const exerciseResources = resources.filter(r => 
      r.category?.toLowerCase().includes("exercise") || 
      r.category?.toLowerCase().includes("fitness") ||
      r.category?.toLowerCase().includes("physical") ||
      r.title?.toLowerCase().includes("exercise") ||
      r.title?.toLowerCase().includes("fitness") ||
      r.title?.toLowerCase().includes("workout")
    );
    return generateResourcesListResponse(userInfo, learningData, exerciseResources, "exercise");
  }

  if (lowerMessage.includes("health topic") || 
      lowerMessage.includes("health topics") || 
      intent.subType === "health" || 
      lowerMessage.includes("mental")) {
    const healthResources = resources.filter(r => 
      r.category?.toLowerCase().includes("health") || 
      r.category?.toLowerCase().includes("mental") ||
      r.category?.toLowerCase().includes("nutrition") ||
      r.category?.toLowerCase().includes("wellness")
    );
    return generateResourcesListResponse(userInfo, learningData, healthResources, "health");
  }

  if (lowerMessage.includes("technology topic") || 
      intent.subType === "technology" ||
      lowerMessage.includes("tech topic")) {
    const techResources = resources.filter(r => 
      r.category?.toLowerCase().includes("technology") || 
      r.category?.toLowerCase().includes("digital") ||
      r.category?.toLowerCase().includes("tech")
    );
    return generateResourcesListResponse(userInfo, learningData, techResources, "technology");
  }

  if (lowerMessage.includes("safety topic") || 
      intent.subType === "safety" ||
      lowerMessage.includes("safety topics")) {
    const safetyResources = resources.filter(r => 
      r.category?.toLowerCase().includes("safety") || 
      r.category?.toLowerCase().includes("security") ||
      r.category?.toLowerCase().includes("fraud")
    );
    return generateResourcesListResponse(userInfo, learningData, safetyResources, "safety");
  }

  // Default to showing all resources
  return generateResourcesListResponse(userInfo, learningData, resources, userMessage);
}

/* ---------------------------------------------------
 ðŸ‘¤ getUserData() â€” Enhanced with Personal Info, Appointments & Consultations
--------------------------------------------------- */
async function getUserData(userId, intent = { type: 'both', dateQuery: 'upcoming' }) {
  const start = Date.now();
  if (!validateEmail(userId)) return null;

  const normalizedKey = normalizeEmailForFirebase(userId);

  let userData = null;
  let userKey = normalizedKey;
  const directSnap = await rtdb.ref(`Account/${normalizedKey}`).get();
  if (directSnap.exists()) {
    userData = directSnap.val();
  } else {
    const emailSnap = await rtdb.ref("Account").orderByChild("email").equalTo(userId).get();
    if (emailSnap.exists()) {
      const val = emailSnap.val();
      userKey = Object.keys(val)[0];
      userData = val[userKey];
    }
  }

  if (!userData) {
    return null;
  }

  const userInfo = extractUserInfo(userData);
  const { uid, email } = userInfo;

  if (intent.type === 'user_info' || intent.type === 'caregiver_info' || intent.type === 'learning_resources' || intent.type === 'routines') {
    return { 
      userInfo, 
      appointments: [],
      consultations: [],
      intent,
      timestamp: new Date().toISOString() 
    };
  }

  let appointments = [];
  let consultations = [];

  if (intent.type === 'appointments' || intent.type === 'both') {
    const appointmentsSnap = await rtdb.ref("Appointments").get();
    if (appointmentsSnap.exists()) {
      const allAppointments = appointmentsSnap.val();
      const appointmentList = Object.keys(allAppointments).map(key => ({
        id: key,
        type: 'appointment',
        ...allAppointments[key]
      }));

      const identifiers = [uid, email];
      const matchedAppointments = appointmentList.filter((appt) => {
        if (!appt || typeof appt !== "object") return false;

        const matches = 
          matchesAnyIdentifier(appt.elderlyId, identifiers) ||
          matchesAnyIdentifier(appt.elderlyIds, identifiers) ||
          matchesAnyIdentifier(appt.assignedTo, identifiers);

        return matches;
      });

      appointments = filterItemsByDate(matchedAppointments, intent.dateQuery, 'date');
    }
  }

  if (intent.type === 'consultations' || intent.type === 'both') {
    const consultationsSnap = await rtdb.ref("consultations").get();
    if (consultationsSnap.exists()) {
      const allConsultations = consultationsSnap.val();
      const consultationList = Object.keys(allConsultations).map(key => ({
        id: key,
        type: 'consultation',
        ...allConsultations[key]
      }));

      const identifiers = [uid, email];
      const matchedConsultations = consultationList.filter((consult) => {
        if (!consult || typeof consult !== "object") return false;

        const matches = 
          matchesAnyIdentifier(consult.elderlyEmail, identifiers) ||
          matchesAnyIdentifier(consult.elderlyId, identifiers) ||
          matchesAnyIdentifier(consult.patientUid, [uid]) ||
          (consult.elderlyEmail && consult.elderlyEmail.toLowerCase().includes(userId.toLowerCase())) ||
          (consult.elderlyId && consult.elderlyId.toLowerCase() === userId.toLowerCase());

        return matches;
      });

      consultations = filterItemsByDate(matchedConsultations, intent.dateQuery, 'appointmentDate');
    }
  }

  const sortedAppointments = appointments
    .sort((a, b) => {
      const dateA = new Date(`${a.date}T${a.time || '00:00'}`);
      const dateB = new Date(`${b.date}T${b.time || '00:00'}`);
      return dateA - dateB;
    })
    .slice(0, 10);

  const sortedConsultations = consultations
    .sort((a, b) => {
      const dateFieldA = a.appointmentDate || a.requestedAt || a.date;
      const dateFieldB = b.appointmentDate || b.requestedAt || b.date;
      const dateA = new Date(dateFieldA);
      const dateB = new Date(dateFieldB);
      return dateA - dateB;
    })
    .slice(0, 10);

  return { 
    userInfo, 
    appointments: sortedAppointments, 
    consultations: sortedConsultations,
    intent,
    timestamp: new Date().toISOString() 
  };
}

/* ---------------------------------------------------
 ðŸ‘¤ Generate Personal Info Response
--------------------------------------------------- */
function generatePersonalInfoResponse(userInfo, intent) {
  const { name, firstName, lastName, age, medicalConditions, phone, address, emergencyContact } = userInfo;
  
  switch (intent.subType) {
    case 'name':
      if (firstName && lastName) {
        return `Your name is ${firstName} ${lastName}. You can call me anytime you need assistance!`;
      } else if (firstName) {
        return `Your name is ${firstName}. How can I help you today?`;
      } else {
        return `I know you as ${name}. Is there anything specific you'd like me to call you?`;
      }
      
    case 'age':
      if (age !== null) {
        return `You are ${age} years old. ${age >= 65 ? 'As a senior, I\'m here to help you with all your needs!' : 'I hope you\'re having a wonderful day!'}`;
      } else {
        return `I don't have your age information in my records. You can update your profile with your birth date if you'd like me to remember it.`;
      }
      
    case 'medical':
      if (medicalConditions && medicalConditions.length > 0) {
        const conditions = medicalConditions.join(', ');
        return `Your medical conditions include: ${conditions}. Remember to take your medications and attend all scheduled appointments.`;
      } else {
        return `I don't see any medical conditions recorded in your profile. If you have any health concerns, please make sure to inform your healthcare provider.`;
      }
      
    case 'contact':
      if (phone) {
        return `Your contact number is ${phone}. I'll use this only for important reminders and updates.`;
      } else {
        return `I don't have your phone number in my records. You can add it to your profile for better communication.`;
      }
      
    case 'address':
      if (address) {
        return `Your address is: ${address}. This helps me provide you with location-specific services and information.`;
      } else {
        return `I don't have your address information. You can update your profile with your address if you'd like.`;
      }
      
    case 'emergency':
      if (emergencyContact) {
        return `Your emergency contact number is ${emergencyContact}. In case of emergency, this is who we will contact.`;
      } else {
        return `I don't have an emergency contact number for you. It's important to have one for your safety.`;
      }
      
    case 'all':
    default:
      let response = `Here's your information:\n\n`;
      response += `â€¢ Name: ${firstName && lastName ? `${firstName} ${lastName}` : name}\n`;
      response += `â€¢ Age: ${age !== null ? `${age} years old` : 'Not specified'}\n`;
      
      if (medicalConditions && medicalConditions.length > 0) {
        response += `â€¢ Medical Conditions: ${medicalConditions.join(', ')}\n`;
      }
      
      if (phone) response += `â€¢ Phone: ${phone}\n`;
      if (address) response += `â€¢ Address: ${address}\n`;
      if (emergencyContact) response += `â€¢ Emergency Contact: ${emergencyContact}\n`;
      
      response += `\nIs there anything specific you'd like to know or update?`;
      return response;
  }
}

/* ---------------------------------------------------
 ðŸ“‹ Generate Routines Response
--------------------------------------------------- */
function generateRoutinesResponse(userInfo, routines, dateQuery) {
  const timeContext = getTimeContext(dateQuery).replace('appointments', 'care routines');
  
  if (routines.length === 0) {
    return `You don't have any ${timeContext} assigned, ${userInfo.name}.`;
  }
  
  let response = `Here are your ${timeContext}, ${userInfo.name}:\n\n`;
  
  routines.forEach((routine, index) => {
    const displayTime = routine.time ? formatDisplayTime(routine.time) : 'All day';
    
    response += `${index + 1}. ðŸ“‹ **${routine.title}**\n`;
    response += `   â° ${displayTime}`;
    
    if (routine.duration) {
      response += ` â€¢ â±ï¸ ${routine.duration}`;
    }
    
    if (routine.description && routine.description !== routine.title) {
      response += `\n   ðŸ“ ${routine.description}`;
    }
    
    if (routine.assignedBy) {
      response += `\n   ðŸ‘¤ Assigned by: ${routine.assignedBy}`;
    }
    
    response += `\n\n`;
  });
  
  return response;
}

/* ---------------------------------------------------
 ðŸ“… Generate Enhanced Schedule Response (Popup-Friendly)
--------------------------------------------------- */
function generateEnhancedScheduleResponse(userInfo, scheduleData, dateQuery) {
  const { appointments, consultations, medications, reminders, assignedRoutines, activities, allEvents } = scheduleData;
  
  const totalEvents = allEvents.length;
  const today = new Date().toLocaleDateString('en-US', { 
    weekday: 'long', 
    year: 'numeric', 
    month: 'long', 
    day: 'numeric' 
  });
  
  let response = `ðŸ“… **Your Daily Schedule - ${today}**\n\n`;
  response += `ðŸ‘‹ Hello ${userInfo.name}! Here's your schedule for today:\n\n`;
  
  if (totalEvents === 0) {
    response += `ðŸŽ‰ **No events scheduled today!**\n\n`;
    response += `Enjoy your free day! You can:\n`;
    response += `â€¢ Take a relaxing walk\n`;
    response += `â€¢ Read a book\n`;
    response += `â€¢ Connect with family/friends\n`;
    response += `â€¢ Explore learning resources\n`;
    response += `â€¢ Check out available activities\n\n`;
    response += `ðŸ’¡ *Need something? Ask me about medications, appointments, or activities!*`;
    return response;
  }
  
  response += `ðŸ“Š **Today at a Glance:**\n`;
  response += `â”œâ”€â”€ ðŸ“… Appointments: ${appointments.length}\n`;
  response += `â”œâ”€â”€ ðŸ¥ Consultations: ${consultations.length}\n`;
  response += `â”œâ”€â”€ ðŸ’Š Medications: ${medications.length}\n`;
  response += `â”œâ”€â”€ â° Reminders: ${reminders.length}\n`;
  response += `â”œâ”€â”€ ðŸ“‹ Routines: ${assignedRoutines.length}\n`;
  response += `â””â”€â”€ ðŸŽ¯ Activities: ${activities.length}\n\n`;
  
  response += `â° **Today's Timeline:**\n\n`;
  
  const morningEvents = allEvents.filter(event => {
    const time = getEventTimeRaw(event);
    const hour = new Date(time).getHours();
    return hour >= 6 && hour < 12;
  });
  
  const afternoonEvents = allEvents.filter(event => {
    const time = getEventTimeRaw(event);
    const hour = new Date(time).getHours();
    return hour >= 12 && hour < 18;
  });
  
  const eveningEvents = allEvents.filter(event => {
    const time = getEventTimeRaw(event);
    const hour = new Date(time).getHours();
    return hour >= 18 || hour < 6;
  });
  
  if (morningEvents.length > 0) {
    response += `ðŸŒ… **Morning**\n`;
    morningEvents.forEach((event, index) => {
      response += formatEventForTimeline(event, index + 1);
    });
    response += `\n`;
  }
  
  if (afternoonEvents.length > 0) {
    response += `â˜€ï¸ **Afternoon**\n`;
    afternoonEvents.forEach((event, index) => {
      response += formatEventForTimeline(event, index + 1);
    });
    response += `\n`;
  }
  
  if (eveningEvents.length > 0) {
    response += `ðŸŒ™ **Evening**\n`;
    eveningEvents.forEach((event, index) => {
      response += formatEventForTimeline(event, index + 1);
    });
    response += `\n`;
  }
  
  const pendingMeds = medications.filter(med => !med.isCompleted);
  if (pendingMeds.length > 0) {
    response += `ðŸ’Š **Medication Reminders**\n`;
    response += `You have ${pendingMeds.length} medication${pendingMeds.length > 1 ? 's' : ''} to take today:\n`;
    pendingMeds.forEach(med => {
      const time = med.reminderTime ? formatDisplayTime(med.reminderTime) : 'Scheduled time';
      response += `â€¢ ${med.medicationName} at ${time}\n`;
    });
    response += `\n`;
  }
  
  if (activities.length > 0) {
    response += `ðŸŽ¯ **Today's Activities**\n`;
    activities.forEach(activity => {
      const time = activity.time ? formatDisplayTime(activity.time) : 'All day';
      const status = activity.isRegistered ? 'âœ… Registered' : 'ðŸ’¡ Suggested';
      response += `â€¢ ${activity.title} at ${time} - ${status}\n`;
    });
    response += `\n`;
  }
  
  const now = new Date();
  const upcomingEvents = allEvents.filter(event => {
    const eventTime = new Date(getEventTimeRaw(event));
    return eventTime > now;
  });
  
  if (upcomingEvents.length > 0) {
    const nextEvent = upcomingEvents[0];
    const timeUntil = getTimeUntil(nextEvent);
    response += `â³ **Next Up:** ${getEventIcon(nextEvent.type)} ${nextEvent.title || nextEvent.medicationName} ${timeUntil}\n\n`;
  }
  
  response += `ðŸ’¡ **Quick Actions:**\n`;
  response += `â€¢ Say "medications" to see all medications\n`;
  response += `â€¢ Say "appointments" for detailed appointments\n`;
  response += `â€¢ Say "reminders" for event reminders\n`;
  response += `â€¢ Say "my routines" for care routines\n`;
  response += `â€¢ Say "activities" for today's activities\n`;
  
  return response;
}
function generateSpecificElderlyAppointmentsResponse(caregiverInfo, appointments, elderlyName) {
  if (appointments.length === 0) {
    return `No upcoming appointments found for ${elderlyName}, ${caregiverInfo.name}.`;
  }

  let response = `Upcoming appointments for ${elderlyName}, ${caregiverInfo.name}:\n\n`;

  appointments.forEach((apt, index) => {
    response += `${index + 1}. ${apt.title || apt.reason || 'Appointment'}\n`;
    response += `   ðŸ“… ${formatDisplayDate(apt.date || apt.appointmentDate)}\n`;
    if (apt.time) response += `   â° ${formatDisplayTime(apt.time)}\n`;
    if (apt.location) response += `   ðŸ“ ${apt.location}\n`;
    if (apt.doctor || apt.provider) response += `   ðŸ‘¨â€âš•ï¸ ${apt.doctor || apt.provider}\n`;
    response += `\n`;
  });

  response += `Total: ${appointments.length} appointment${appointments.length !== 1 ? 's' : ''} for ${elderlyName}.`;

  return response;
}
// ENHANCED: Main caregiver schedule function
async function fetchCaregiverSchedule(userId, dateQuery = 'upcoming') {
  try {
    console.log("ðŸ“… Getting COMPLETE schedule for caregiver:", userId, "Date query:", dateQuery);
    
    // Get ALL schedule components in parallel with better error handling
    const [
      caregiverConsultations,
      caregiverSpecificConsultations,
      elderlyAppointments,
      elderlyMedications,
      elderlyActivities,
      elderlyReminders,
      elderlyData
    ] = await Promise.all([
      getCaregiverConsultations(userId, dateQuery).catch(error => {
        console.error("Error getting caregiver consultations:", error);
        return [];
      }),
      getCaregiverSpecificConsultations(userId, dateQuery).catch(error => {
        console.error("Error getting caregiver-specific consultations:", error);
        return [];
      }),
      getElderlyAppointmentsForCaregiverEnhanced(userId, dateQuery).catch(error => {
        console.error("Error getting elderly appointments:", error);
        return { appointments: [] };
      }),
      getElderlyMedicationsForCaregiver(userId, dateQuery).catch(error => {
        console.error("Error getting elderly medications:", error);
        return [];
      }),
      getElderlyActivitiesForCaregiver(userId, dateQuery).catch(error => {
        console.error("Error getting elderly activities:", error);
        return [];
      }),
      getElderlyRemindersForCaregiver(userId, dateQuery).catch(error => {
        console.error("Error getting elderly reminders:", error);
        return [];
      }),
      getCaregiverAssignedElderly(userId).catch(error => {
        console.error("Error getting assigned elderly:", error);
        return { success: false, elderly: [] };
      })
    ]);

    console.log("ðŸ“Š COMPLETE Schedule results:", {
      consultations: caregiverConsultations.length,
      caregiverSpecificConsultations: caregiverSpecificConsultations.length,
      elderlyAppointments: elderlyAppointments.appointments?.length || 0,
      elderlyMedications: elderlyMedications.length,
      elderlyActivities: elderlyActivities.length,
      elderlyReminders: elderlyReminders.length,
      elderlyCount: elderlyData.elderly?.length || 0
    });

    // Combine ALL events with proper categorization
    const allEvents = [
      // CAREGIVER'S PERSONAL CONSULTATIONS
      ...caregiverConsultations.map(cons => ({ 
        ...cons, 
        eventType: 'caregiver_consultation',
        displayType: 'My Consultation',
        sortDate: cons.appointmentDate || cons.date || cons.requestedAt,
        isCaregiverEvent: true,
        title: cons.reason || cons.title || 'Medical Consultation',
        time: cons.appointmentTime || cons.time,
        location: cons.location || 'Virtual'
      })),
      
      // Caregiver-specific consultations
      ...caregiverSpecificConsultations.map(cons => ({
        ...cons,
        eventType: 'caregiver_specific_consultation',
        displayType: 'My Consultation Invitation',
        sortDate: cons.appointmentDate || cons.date || cons.requestedAt,
        isCaregiverEvent: true,
        isInvitation: true,
        title: cons.reason || cons.title || 'Consultation Invitation',
        time: cons.appointmentTime || cons.time,
        location: cons.location || 'Virtual'
      })),
      
      // ELDERLY PATIENT EVENTS
      // Elderly appointments
      ...(elderlyAppointments.appointments || []).map(apt => ({ 
        ...apt, 
        eventType: apt.type === 'consultation' ? 'elderly_consultation' : 'elderly_appointment',
        displayType: apt.type === 'consultation' ? 'Elderly Consultation' : 'Elderly Appointment',
        sortDate: apt.date || apt.appointmentDate,
        isElderlyEvent: true,
        title: apt.title || apt.reason || (apt.type === 'consultation' ? 'Medical Consultation' : 'Appointment')
      })),
      
      // Elderly medications
      ...elderlyMedications.map(med => ({
        ...med,
        eventType: 'elderly_medication',
        displayType: 'Elderly Medication',
        sortDate: `${med.date}T${med.reminderTime || '00:00'}`,
        isElderlyEvent: true,
        title: med.medicationName || 'Medication'
      })),
      
      // Elderly activities
      ...elderlyActivities.map(act => ({
        ...act,
        eventType: 'elderly_activity',
        displayType: 'Elderly Activity',
        sortDate: `${act.date}T${act.time || '10:00'}`,
        isElderlyEvent: true,
        title: act.title || 'Activity'
      })),
      
      // Elderly reminders
      ...elderlyReminders.map(rem => ({
        ...rem,
        eventType: 'elderly_reminder',
        displayType: 'Elderly Reminder',
        sortDate: rem.startTime || '00:00',
        isElderlyEvent: true,
        title: rem.title || 'Reminder'
      }))
    ];

    // Apply date filtering to ALL events based on dateQuery
    const filteredEvents = filterCaregiverEventsByDate(allEvents, dateQuery);

    // Sort filtered events by date
    const sortedEvents = filteredEvents.sort((a, b) => {
      const dateA = new Date(a.sortDate || '9999-12-31');
      const dateB = new Date(b.sortDate || '9999-12-31');
      return dateA - dateB;
    });

    return {
      success: true,
      schedule: sortedEvents,
      
      // Individual components for detailed display
      caregiverConsultations: caregiverConsultations,
      caregiverSpecificConsultations: caregiverSpecificConsultations,
      elderlyAppointments: elderlyAppointments.appointments || [],
      elderlyMedications: elderlyMedications,
      elderlyActivities: elderlyActivities,
      elderlyReminders: elderlyReminders,
      
      // Summary counts
      totalEvents: sortedEvents.length,
      summary: {
        totalConsultations: caregiverConsultations.length + caregiverSpecificConsultations.length,
        totalElderlyAppointments: elderlyAppointments.appointments?.length || 0,
        totalElderlyMedications: elderlyMedications.length,
        totalElderlyActivities: elderlyActivities.length,
        totalElderlyReminders: elderlyReminders.length,
        totalElderly: elderlyData.totalElderly || 0,
        dateQuery: dateQuery
      },
      
      elderlyData: elderlyData
    };

  } catch (error) {
    console.error("ðŸ’¥ Error in fetchCaregiverSchedule:", error);
    return { 
      success: false, 
      error: error.message, 
      schedule: [],
      caregiverConsultations: [],
      caregiverSpecificConsultations: [],
      elderlyAppointments: [],
      elderlyMedications: [],
      elderlyActivities: [],
      elderlyReminders: []
    };
  }
}
function formatEventForTimeline(event, number) {
  const time = getEventTime(event);
  const status = getEventStatus(event);
  const icon = getEventIcon(event.type);
  
  let line = `${number}. ${icon} **${event.title || event.medicationName || 'Untitled'}**\n`;
  line += `   â° ${time} â€¢ ${status}\n`;
  
  switch (event.type) {
    case 'medication':
      const dosage = event.dosage ? ` (${event.dosage})` : '';
      const quantity = event.quantity ? `, ${event.quantity} pill${event.quantity > 1 ? 's' : ''}` : '';
      line += `   ðŸ’Š ${event.medicationName}${dosage}${quantity}\n`;
      break;
    case 'appointment':
    case 'consultation':
      if (event.location) {
        line += `   ðŸ“ ${event.location}\n`;
      }
      if (event.doctor || event.provider) {
        line += `   ðŸ‘¨â€âš•ï¸ ${event.doctor || event.provider}\n`;
      }
      break;
    case 'assigned_routine':
      if (event.description) {
        line += `   ðŸ“ ${event.description}\n`;
      }
      break;
    case 'activity':
      if (event.category) {
        line += `   ðŸ·ï¸ ${event.category}\n`;
      }
      if (event.duration) {
        line += `   â±ï¸ ${event.duration}\n`;
      }
      if (event.description && event.description !== event.title) {
        line += `   ðŸ“ ${event.description}\n`;
      }
      break;
  }
  
  if (event.notes && event.type !== 'assigned_routine' && event.type !== 'activity') {
    line += `   ðŸ“‹ ${event.notes}\n`;
  }
  
  line += `\n`;
  return line;
}

function getTimeUntil(event) {
  const eventTime = new Date(getEventTimeRaw(event));
  const now = new Date();
  const diffMs = eventTime - now;
  const diffMins = Math.floor(diffMs / 60000);
  const diffHours = Math.floor(diffMins / 60);
  
  if (diffMins < 0) {
    return '(passed)';
  } else if (diffMins < 60) {
    return `(in ${diffMins} min)`;
  } else if (diffHours < 24) {
    return `(in ${diffHours} hour${diffHours !== 1 ? 's' : ''})`;
  } else {
    return '(today)';
  }
}

function getEventTime(event) {
  switch (event.type) {
    case 'appointment':
      return event.time ? formatDisplayTime(event.time) : 'All day';
    case 'consultation':
      return event.appointmentTime || event.time || 'Scheduled';
    case 'medication':
      return event.reminderTime ? formatDisplayTime(event.reminderTime) : 'Scheduled';
    case 'reminder':
      return event.startTime ? formatDisplayTime(event.startTime) : 'Scheduled';
    case 'assigned_routine':
      return event.time ? formatDisplayTime(event.time) : 'Scheduled';
    case 'activity':
      return event.time ? formatDisplayTime(event.time) : 'Scheduled';
    default:
      return 'Scheduled';
  }
}

function getEventTimeRaw(event) {
  switch (event.type) {
    case 'appointment':
      return `${event.date}T${event.time || '00:00'}`;
    case 'consultation':
      return `${event.appointmentDate || event.date}T${event.appointmentTime || event.time || '00:00'}`;
    case 'medication':
      return `${event.date}T${event.reminderTime || '00:00'}`;
    case 'reminder':
      return event.startTime || '00:00';
    case 'assigned_routine':
      return `${event.date}T${event.time || '00:00'}`;
    case 'activity':
      return `${event.date}T${event.time || '10:00'}`;
    default:
      return '00:00';
  }
}

function getEventStatus(event) {
  switch (event.type) {
    case 'medication':
      return event.isCompleted ? 'âœ… Taken' : 'â° Pending';
    case 'appointment':
    case 'consultation':
      return event.isCompleted ? 'âœ… Completed' : 'ðŸ“… Upcoming';
    case 'reminder':
      return 'ðŸ”” Active';
    case 'assigned_routine':
      return 'ðŸ“‹ Scheduled';
    case 'activity':
      return event.isRegistered ? 'âœ… Registered' : 'ðŸ’¡ Suggested';
    default:
      return 'ðŸ“… Scheduled';
  }
}

function getEventIcon(eventType) {
  switch (eventType) {
    case 'appointment': return 'ðŸ“…';
    case 'consultation': return 'ðŸ¥';
    case 'medication': return 'ðŸ’Š';
    case 'reminder': return 'â°';
    case 'assigned_routine': return 'ðŸ“‹';
    case 'activity': return 'ðŸŽ¯';
    default: return 'ðŸ“Œ';
  }
}

function getTimeContext(dateQuery) {
  switch (dateQuery) {
    case 'today': return 'appointments today';
    case 'tomorrow': return 'appointments tomorrow';
    case 'yesterday': return 'appointments yesterday';
    case 'past': return 'past appointments';
    case 'all': return 'appointments';
    case 'upcoming': 
    default: return 'upcoming appointments';
  }
}

/* ---------------------------------------------------
 ðŸ¤– Dialogflow Gateway - ENHANCED WITH ROUTINES
--------------------------------------------------- */
// Update your dialogflowGateway to use hybrid data fetching
exports.dialogflowGateway = onRequest(
  { region: "asia-southeast1", timeoutSeconds: 30, memory: "256MiB", cors: true },
  async (req, res) => { 
    res.set("Access-Control-Allow-Origin", "*");
    if (req.method === "OPTIONS") return res.status(204).send("");
    if (req.method !== "POST")
      return res.status(405).json({ success: false, error: "Use POST", version: VERSION });

    const { userId, message } = req.body;
    if (!userId || !message)
      return res.status(400).json({ success: false, error: "Missing fields", version: VERSION });

    try {
      const intent = parseUserIntent(message);
      
      let reply = "";
      let userContext = {};

      // Use hybrid data fetching
      const data = await getUserDataHybrid(userId, intent);
      if (!data) {
        return res.status(404).json({ success: false, error: "User not found", version: VERSION });
      }

      // Add data source to context
      userContext.dataSource = data.dataSource;

      // Rest of your existing logic continues...
      if (intent.type === 'bot_info') {
        reply = `I'm your Elderly Care Assistant! I'm here to help you manage your appointments, remember your medications, and keep track of your important information. You can ask me about your schedule, personal details, learning resources, or any other assistance you need.`;
      
      } else if (intent.type === 'comprehensive_schedule') {
        // Create a hybrid comprehensive schedule function
        const scheduleData = await getComprehensiveScheduleHybrid(userId, intent.dateQuery);
        reply = generateEnhancedScheduleResponse(data.userInfo, scheduleData, intent.dateQuery);
        userContext = {
          userName: data.userInfo.name,
          userType: data.userInfo.userType,
          appointments: scheduleData.appointments.length,
          consultations: scheduleData.consultations.length,
          medications: scheduleData.medications.length,
          reminders: scheduleData.reminders.length,
          assignedRoutines: scheduleData.assignedRoutines.length,
          totalEvents: scheduleData.allEvents.length,
          intent: intent,
          dataSource: data.dataSource
        };
      
      }
      else if (intent.type === 'user_info') {
        const data = await getUserData(userId, intent);
        if (!data) {
          return res.status(404).json({ success: false, error: "User not found", version: VERSION });
        }
        reply = generatePersonalInfoResponse(data.userInfo, intent);
        userContext = {
          userName: data.userInfo.name,
          userType: data.userInfo.userType,
          age: data.userInfo.age,
          hasMedicalInfo: data.userInfo.medicalConditions.length > 0,
          appointments: data.appointments.length,
          consultations: data.consultations.length,
          intent: intent
        };
      
      } else if (intent.type === 'caregiver_info') {
        const caregiverData = await getCaregiverInfo(userId);
        if (caregiverData) {
          reply = generateCaregiverResponse(caregiverData.userInfo, caregiverData.caregivers);
          userContext = {
            userName: caregiverData.userInfo.name,
            userType: caregiverData.userInfo.userType,
            caregiversCount: caregiverData.caregivers.length,
            intent: intent
          };
        } else {
          reply = "I couldn't find your caregiver information. Please make sure you're logged in correctly.";
        }
      
      } else if (intent.type === 'medications') {
        const userData = await getUserData(userId, { type: 'user_info', subType: 'all' });
        if (!userData) {
          return res.status(404).json({ success: false, error: "User not found", version: VERSION });
        }
        
        const medications = await getMedicationReminders(userId, intent.dateQuery);
        reply = generateMedicationResponse(userData.userInfo, medications, intent.dateQuery);
        userContext = {
          userName: userData.userInfo.name,
          userType: userData.userInfo.userType,
          medicationsCount: medications.length,
          pendingMedications: medications.filter(med => !med.isCompleted).length,
          intent: intent
        };
      
      } else if (intent.type === 'reminders') {
        const userData = await getUserData(userId, { type: 'user_info', subType: 'all' });
        if (!userData) {
          return res.status(404).json({ success: false, error: "User not found", version: VERSION });
        }
        
        const reminders = await getEventReminders(userId, intent.dateQuery);
        reply = generateEventRemindersResponse(userData.userInfo, reminders, intent.dateQuery);
        userContext = {
          userName: userData.userInfo.name,
          userType: userData.userInfo.userType,
          remindersCount: reminders.length,
          intent: intent
        };
      
      } else if (intent.type === 'activities_preferences') {
        const recentActivities = await retrieveSelectedActivities(userId);
        const activitiesPreferences = analyzeActivitiesPreferences(recentActivities);
        const userData = await getUserData(userId, { type: 'user_info', subType: 'all' });
        
        if (userData) {
          reply = generateActivitiesPreferencesResponse(userData.userInfo, activitiesPreferences);
          userContext = {
            userName: userData.userInfo.name,
            userType: userData.userInfo.userType,
            activitiesCount: recentActivities.length,
            preferredCategories: activitiesPreferences.preferredCategories,
            activityLevel: activitiesPreferences.activityFrequency,
            intent: intent
          };
        } else {
          reply = "I couldn't find your user information. Please make sure you're logged in correctly.";
        }
      
      } else if (intent.type === 'activities') {
        const activities = await getActivitiesForSchedule(userId, intent.dateQuery);
        const userData = await getUserData(userId, { type: 'user_info', subType: 'all' });
        
        if (userData) {
          reply = generateActivitiesResponse(userData.userInfo, activities, intent.dateQuery);
          userContext = {
            userName: userData.userInfo.name,
            userType: userData.userInfo.userType,
            activitiesCount: activities.length,
            registeredActivities: activities.filter(act => act.isRegistered).length,
            intent: intent
          };
        } else {
          reply = "I couldn't find your activities information. Please make sure you're logged in correctly.";
        }
      
      } else if (intent.type === 'routines') {
        const userData = await getUserData(userId, { type: 'user_info', subType: 'all' });
        if (!userData) {
          return res.status(404).json({ success: false, error: "User not found", version: VERSION });
        }
        
        const routines = await getAssignedRoutinesForSchedule(userId, intent.dateQuery);
        reply = generateRoutinesResponse(userData.userInfo, routines, intent.dateQuery);
        userContext = {
          userName: userData.userInfo.name,
          userType: userData.userInfo.userType,
          routinesCount: routines.length,
          intent: intent
        };
      
      } else if (intent.type === 'user_preferences') {
        // ðŸ†• User preferences handling
        const userData = await getUserData(userId, { type: 'user_info', subType: 'all' });
        if (!userData) {
          return res.status(404).json({ success: false, error: "User not found", version: VERSION });
        }
        
        const recentActivities = await retrieveSelectedActivities(userId);
        const preferences = analyzeInteractionsPreferences(userId, userData.userInfo, recentActivities);
        
        reply = generatePreferencesResponse(userData.userInfo, preferences, recentActivities);
        userContext = {
          userName: userData.userInfo.name,
          userType: userData.userInfo.userType,
          preferences: preferences,
          recentActivitiesCount: recentActivities.length,
          intent: intent
        };

      } else if (intent.type === 'learning_resources') {
        const learningData = await getUserLearningData(userId);
        if (learningData) {
          const lowerMessage = message.toLowerCase();
          let category = null;
          let searchQuery = null;
          
          const categories = ['health', 'exercise', 'technology', 'safety', 'legal', 'mental', 'recreational'];
          for (const cat of categories) {
            if (lowerMessage.includes(cat)) {
              category = cat;
              break;
            }
          }
          
          const commonWords = ['show', 'find', 'get', 'learning', 'resources', 'education', 'study', 'learn', 'points', 'reward', 'achievement', 'streak'];
          const words = message.toLowerCase().split(' ');
          const potentialQueryWords = words.filter(word => 
            !commonWords.includes(word) && 
            !categories.includes(word) &&
            word.length > 2
          );
          
          if (potentialQueryWords.length > 0) {
            searchQuery = potentialQueryWords.join(' ');
          }
          
          const resources = await getLearningResources(category, searchQuery);
          reply = generateLearningResourcesResponse(learningData.userInfo, learningData.learningData, resources, message, intent);
          userContext = {
            userName: learningData.userInfo.name,
            userType: learningData.userInfo.userType,
            points: learningData.learningData.currentPoints,
            streak: learningData.learningData.dailyStreak,
            resourcesFound: resources.length,
            intent: intent
          };
        } else {
          reply = "I couldn't find your learning data. Please make sure you're logged in correctly.";
        }
      
      } else if (intent.type === 'caregiver_elderly') {
        const elderlyData = await getCaregiverAssignedElderly(userId);
        if (elderlyData.success) {
          reply = generateCaregiverElderlyResponse(elderlyData.caregiver, elderlyData);
          userContext = {
            userName: elderlyData.caregiver.name,
            userType: 'caregiver',
            totalElderly: elderlyData.totalElderly,
            intent: intent
          };
        } else {
          reply = "I couldn't find your elderly information. Please make sure you're logged in as a caregiver.";
        }

      } 

      // In the dialogflowGateway, add this new handler after the caregiver_schedule section:
else if (intent.type === 'caregiver_consultations') {
  const consultations = await getCaregiverConsultations(userId, intent.dateQuery);
  const userData = await getUserData(userId, { type: 'user_info', subType: 'all' });
  
  if (userData) {
    reply = generateCaregiverConsultationsResponse(userData.userInfo, consultations, intent.dateQuery);
    userContext = {
      userName: userData.userInfo.name,
      userType: 'caregiver',
      consultationsCount: consultations.length,
      dateQuery: intent.dateQuery,
      intent: intent
    };
  } else {
    reply = "I couldn't find your caregiver information. Please make sure you're logged in correctly.";
  }
}// In the dialogflowGateway function, update this section:
else if (intent.type === 'caregiver_elderly_appointments') {
  // Use the dateQuery from intent (will be 'all' for "all elderly appointments")
  const appointmentsData = await getElderlyAppointmentsForCaregiverEnhanced(userId, intent.dateQuery);
  
  if (appointmentsData.success) {
    const userData = await getUserData(userId, { type: 'user_info', subType: 'all' });
    
    reply = generateElderlyAppointmentsNotification(
      userData?.userInfo || { name: 'Caregiver' }, 
      appointmentsData
    );
    
    userContext = {
      userName: userData?.userInfo?.name || 'Caregiver',
      userType: 'caregiver',
      totalAppointments: appointmentsData.totalAppointments,
      totalElderly: appointmentsData.totalElderly,
      dateQuery: intent.dateQuery, // Make sure this is passed through
      intent: intent
    };
  } else {
    reply = "I couldn't retrieve elderly appointments. Please try again later.";
  }
}
if (intent.type === "health_recommendations") {
  // Fetch general health recommendations
  const response = await fetch(
    "https://gethealthrecommendations-ga4zzowbeq-as.a.run.app",
    {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ userId }),
    }
  );
  const data = await response.json();
  return data.displayMessage; // already formatted by the function
} 
else if (intent.type === "health_tips") {
  // Fetch category-based health tips
  const response = await fetch(
    "https://gethealthtips-ga4zzowbeq-as.a.run.app",
    {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ userId, category: intent.category || "general" }),
    }
  );
  const data = await response.json();
  return data.displayMessage; // already formatted
}

// In the dialogflowGateway function, update this section:
else if (intent.type === 'caregiver_schedule') {
  const scheduleData = await getCaregiverSchedule(userId, intent.dateQuery);
  if (scheduleData.success) {
    const userData = await getUserData(userId, { type: 'user_info', subType: 'all' });
    
    reply = generateEnhancedCaregiverScheduleResponse(
      userData?.userInfo || { name: 'Caregiver' }, 
      scheduleData
    );
    
    userContext = {
      userName: userData?.userInfo?.name || 'Caregiver',
      userType: 'caregiver',
      totalEvents: scheduleData.totalEvents,
      caregiverEvents: scheduleData.schedule.filter(e => e.isCaregiverEvent).length,
      elderlyEvents: scheduleData.schedule.filter(e => e.isElderlyEvent).length,
      dateQuery: intent.dateQuery,
      intent: intent
    };
  } else {
    reply = "I couldn't retrieve your complete schedule. Please try again later.";
  }
}
      // MODIFIED: Handle 'all' appointments request properly
if (intent.type === 'caregiver_elderly_appointments') {
  // Determine the date query based on user input
  let dateQuery = 'upcoming'; // default
  
  if (intent.dateQuery === 'all') {
    dateQuery = 'all';
  } else if (intent.dateQuery === 'today') {
    dateQuery = 'today';
  } else if (intent.dateQuery === 'past') {
    dateQuery = 'past';
  }
  
  // You can also check for specific keywords in the message
  if (intent.message && intent.message.toLowerCase().includes('all appointment')) {
    dateQuery = 'all';
  }

  const appointmentsData = await getElderlyAppointmentsForCaregiverEnhanced(userId, dateQuery);
  
  if (appointmentsData.success) {
    const userData = await getUserData(userId, { type: 'user_info', subType: 'all' });
    
    // Enhanced response based on specific queries
    if (intent.specificElderly) {
      // Filter appointments for specific elderly
      const filteredAppointments = appointmentsData.appointments.filter(apt => 
        apt.elderlyName.toLowerCase().includes(intent.specificElderly.toLowerCase())
      );
      reply = generateSpecificElderlyAppointmentsResponse(
        userData?.userInfo || { name: 'Caregiver' }, 
        filteredAppointments, 
        intent.specificElderly
      );
    } else {
      reply = generateElderlyAppointmentsNotification(
        userData?.userInfo || { name: 'Caregiver' }, 
        appointmentsData
      );
    }
          userContext = {
            userName: userData?.userInfo?.name || 'Caregiver',
            userType: 'caregiver',
            totalAppointments: appointmentsData.totalAppointments,
            totalElderly: appointmentsData.totalElderly,
            dateQuery: intent.dateQuery,
            intent: intent
          };
        } else {
          reply = "I couldn't retrieve elderly appointments. Please try again later.";
        }
      } else {
        const data = await getUserData(userId, intent);
        if (!data) {
          return res.status(404).json({ success: false, error: "User not found", version: VERSION });
        }
        reply = generateScheduleResponse(data.userInfo, data.appointments, data.consultations, intent);
        userContext = {
          userName: data.userInfo.name,
          userType: data.userInfo.userType,
          age: data.userInfo.age,
          hasMedicalInfo: data.userInfo.medicalConditions.length > 0,
          appointments: data.appointments.length,
          consultations: data.consultations.length,
          nextAppointment: data.appointments[0] || null,
          nextConsultation: data.consultations[0] || null,
          intent: intent
        };
      }

      res.json({
        success: true,
        version: VERSION,
        reply,
        userContext,
        timestamp: new Date().toISOString(),
      });
    } catch (error) {
      console.error('Error in dialogflowGateway:', error);
      res.status(500).json({
        success: false,
        error: "Internal server error",
        version: VERSION,
        timestamp: new Date().toISOString(),
      });
    }
  }
);

function generateScheduleResponse(userInfo, appointments, consultations, intent) {
  const timeContext = getTimeContext(intent.dateQuery);
  
  if (appointments.length === 0 && consultations.length === 0) {
    return `You don't have any ${timeContext}, ${userInfo.name}.`;
  }
  
  let response = `Here are your ${timeContext}, ${userInfo.name}:\n\n`;
  
  if (appointments.length > 0) {
    response += `ðŸ“… **Appointments:**\n`;
    appointments.forEach((apt, index) => {
      response += `${index + 1}. **${apt.title}**\n`;
      response += `   ðŸ“… ${formatDisplayDate(apt.date)}\n`;
      response += `   â° ${apt.time ? formatDisplayTime(apt.time) : 'All day'}\n`;
      if (apt.location) response += `   ðŸ“ ${apt.location}\n`;
      if (apt.notes) response += `   ðŸ“ ${apt.notes}\n`;
      response += `\n`;
    });
  }
  
  if (consultations.length > 0) {
  response += `ðŸ¥ **Consultations:**\n`;
  consultations.forEach((consult, index) => {
    const consultDate = consult.appointmentDate || consult.requestedAt || consult.date;
    response += `${index + 1}. **${consult.reason || 'Medical Consultation'}**\n`;
    response += `   ðŸ“… ${formatDisplayDate(consultDate)}\n`;
    if (consult.patientName) response += `   ðŸ‘¤ ${consult.patientName}\n`;
    if (consult.status) response += `   ðŸ“Š Status: ${consult.status}\n`;
    response += `\n`;
  });
}
  
  return response;
}

/* ---------------------------------------------------
 ðŸ‘¤ Quick Profile
--------------------------------------------------- */
// Update quickProfile endpoint
exports.quickProfile = onRequest(
  { timeoutSeconds: 15, memory: "128MiB", cors: true },
  async (req, res) => {
    res.set("Access-Control-Allow-Origin", "*");
    if (req.method === "OPTIONS") return res.status(204).send("");

    try {
      const { userId } = req.method === "POST" ? req.body : req.query;
      if (!userId) return res.status(400).json({ error: "User ID required", version: VERSION });

      const data = await getUserDataHybrid(userId, { type: 'user_info', subType: 'all' });
      if (!data) return res.status(404).json({ success: false, error: "User not found", version: VERSION });

      res.json({
        success: true,
        profile: data.userInfo,
        appointments: data.appointments.length,
        consultations: data.consultations.length,
        upcomingAppointments: data.appointments,
        upcomingConsultations: data.consultations,
        dataSource: data.dataSource, // Include data source in response
        timestamp: new Date().toISOString(),
        version: VERSION,
      });
    } catch (error) {
      res.status(500).json({
        success: false,
        error: "Internal server error",
        version: VERSION,
        timestamp: new Date().toISOString(),
      });
    }
  }
);

/* ---------------------------------------------------
 ðŸ”„ Database Fallback Strategy
--------------------------------------------------- */

async function withDatabaseFallback(primaryOperation, fallbackOperation, operationName) {
  try {
    console.log(`ðŸ”„ Attempting ${operationName} with primary database...`);
    const result = await primaryOperation();
    
    if (result && (!Array.isArray(result) || result.length > 0)) {
      console.log(`âœ… ${operationName} successful with primary database`);
      return { data: result, source: 'primary' };
    }
    
    // If primary returns empty but successful, try fallback
    console.log(`ðŸ”„ Primary database returned empty, trying fallback...`);
    const fallbackResult = await fallbackOperation();
    console.log(`âœ… ${operationName} completed with fallback database`);
    return { data: fallbackResult, source: 'fallback' };
    
  } catch (primaryError) {
    console.error(`âŒ Primary database failed for ${operationName}:`, primaryError);
    
    try {
      console.log(`ðŸ”„ Falling back to secondary database...`);
      const fallbackResult = await fallbackOperation();
      console.log(`âœ… ${operationName} recovered with fallback database`);
      return { data: fallbackResult, source: 'fallback' };
    } catch (fallbackError) {
      console.error(`ðŸ’¥ Both databases failed for ${operationName}:`, fallbackError);
      throw new Error(`All database operations failed for ${operationName}`);
    }
  }
}

// Usage example:
async function getAppointmentsWithFallback(userId, dateQuery) {
  return await withDatabaseFallback(
    () => getAppointmentsFromFirestore(userId, dateQuery),
    () => getAppointmentsFromRTDB(userId, { dateQuery }),
    'getAppointments'
  );
}

/* ---------------------------------------------------
 ðŸ‘¨â€âš•ï¸ Caregiver Lookup Endpoint
--------------------------------------------------- */
exports.getMyCaregivers = onRequest(
  { timeoutSeconds: 15, memory: "128MiB", cors: true },
  async (req, res) => {
    res.set("Access-Control-Allow-Origin", "*");
    if (req.method === "OPTIONS") return res.status(204).send("");

    try {
      const { userId } = req.method === "POST" ? req.body : req.query;
      if (!userId) return res.status(400).json({ error: "User ID required", version: VERSION });
      
      const caregiverData = await getCaregiverInfo(userId);
      if (!caregiverData) {
        return res.status(404).json({ success: false, error: "User not found", version: VERSION });
      }

      res.json({
        success: true,
        userInfo: caregiverData.userInfo,
        caregivers: caregiverData.caregivers,
        caregiversCount: caregiverData.caregivers.length,
        timestamp: new Date().toISOString(),
        version: VERSION,
      });
    } catch (error) {
      res.status(500).json({
        success: false,
        error: "Internal server error",
        version: VERSION,
        timestamp: new Date().toISOString(),
      });
    }
  }
);

/* ---------------------------------------------------
 ðŸ’Š Medication Reminders Endpoints
--------------------------------------------------- */
exports.getMyMedications = onRequest(
  { timeoutSeconds: 15, memory: "128MiB", cors: true },
  async (req, res) => {
    res.set("Access-Control-Allow-Origin", "*");
    if (req.method === "OPTIONS") return res.status(204).send("");

    try {
      const { userId, date = 'today' } = req.method === "POST" ? req.body : req.query;
      if (!userId) return res.status(400).json({ error: "User ID required", version: VERSION });
      
      const medications = await getMedicationReminders(userId, date);
      const userData = await getUserData(userId, { type: 'user_info', subType: 'all' });

      res.json({
        success: true,
        userInfo: userData?.userInfo || null,
        medications: medications,
        totalMedications: medications.length,
        pendingMedications: medications.filter(med => !med.isCompleted).length,
        completedMedications: medications.filter(med => med.isCompleted).length,
        timestamp: new Date().toISOString(),
        version: VERSION,
      });
    } catch (error) {
      res.status(500).json({
        success: false,
        error: "Internal server error",
        version: VERSION,
        timestamp: new Date().toISOString(),
      });
    }
  }
);

/* ---------------------------------------------------
 â° Event Reminders Endpoints
--------------------------------------------------- */
exports.getMyReminders = onRequest(
  { timeoutSeconds: 15, memory: "128MiB", cors: true },
  async (req, res) => {
    res.set("Access-Control-Allow-Origin", "*");
    if (req.method === "OPTIONS") return res.status(204).send("");

    try {
      const { userId, date = 'upcoming' } = req.method === "POST" ? req.body : req.query;
      if (!userId) return res.status(400).json({ error: "User ID required", version: VERSION });

      const reminders = await getEventReminders(userId, date);
      const userData = await getUserData(userId, { type: 'user_info', subType: 'all' });

      res.json({
        success: true,
        userInfo: userData?.userInfo || null,
        reminders: reminders,
        totalReminders: reminders.length,
        timestamp: new Date().toISOString(),
        version: VERSION,
      });
    } catch (error) {
      res.status(500).json({
        success: false,
        error: "Internal server error",
        version: VERSION,
        timestamp: new Date().toISOString(),
      });
    }
  }
);
/* ---------------------------------------------------
 ðŸ‘¨â€âš•ï¸ CAREGIVER COMPREHENSIVE DATA ENDPOINT
--------------------------------------------------- */

exports.getCaregiverComprehensiveData = onRequest(
  { timeoutSeconds: 30, memory: "256MiB", cors: true },
  async (req, res) => {
    res.set("Access-Control-Allow-Origin", "*");
    if (req.method === "OPTIONS") return res.status(204).send("");

    try {
      const { userId, dateQuery = 'upcoming' } = req.method === "POST" ? req.body : req.query;
      if (!userId) return res.status(400).json({ error: "User ID required", version: VERSION });

      console.log("ðŸ” Getting comprehensive data for caregiver:", userId, "Date query:", dateQuery);

      // Get all caregiver data in parallel
      const [caregiverInfo, assignedElderly, consultations, elderlyAppointments, schedule] = await Promise.all([
        getUserData(userId, { type: 'user_info', subType: 'all' }),
        getCaregiverAssignedElderly(userId),
        getCaregiverConsultations(userId, dateQuery),
        getElderlyAppointmentsForCaregiverEnhanced(userId, dateQuery),
        getCaregiverSchedule(userId, dateQuery)
      ]);

      if (!caregiverInfo) {
        return res.status(404).json({ 
          success: false, 
          error: "Caregiver not found", 
          version: VERSION 
        });
      }

      const response = {
        success: true,
        userInfo: caregiverInfo.userInfo,
        assignedElderly: {
          success: assignedElderly.success,
          elderly: assignedElderly.elderly || [],
          totalElderly: assignedElderly.totalElderly || 0,
          error: assignedElderly.error
        },
        consultations: {
          total: consultations.length,
          dateQuery: dateQuery,
          list: consultations
        },
        elderlyAppointments: {
          success: elderlyAppointments.success,
          appointments: elderlyAppointments.appointments || [],
          totalAppointments: elderlyAppointments.totalAppointments || 0,
          totalElderly: elderlyAppointments.totalElderly || 0,
          dateQuery: dateQuery,
          error: elderlyAppointments.error
        },
        schedule: {
          success: schedule.success,
          totalEvents: schedule.totalEvents || 0,
          summary: schedule.summary || {},
          dateQuery: dateQuery,
          error: schedule.error
        },
        displayMessages: {
          elderly: generateCaregiverElderlyResponse(caregiverInfo.userInfo, assignedElderly),
          schedule: generateCaregiverScheduleResponse(caregiverInfo.userInfo, schedule),
          appointments: generateElderlyAppointmentsNotification(caregiverInfo.userInfo, elderlyAppointments)
        },
        timestamp: new Date().toISOString(),
        version: VERSION,
      };

      res.json(response);

    } catch (error) {
      console.error("ðŸ’¥ Error in getCaregiverComprehensiveData:", error);
      res.status(500).json({
        success: false,
        error: "Internal server error",
        version: VERSION,
        timestamp: new Date().toISOString(),
      });
    }
  }
);

/* ---------------------------------------------------
 ðŸ“š Learning Resources Endpoints
--------------------------------------------------- */
exports.getLearningResources = onRequest(
  { timeoutSeconds: 15, memory: "128MiB", cors: true },
  async (req, res) => {
    res.set("Access-Control-Allow-Origin", "*");
    if (req.method === "OPTIONS") return res.status(204).send("");

    try {
      const { category, search, userId } = req.method === "POST" ? req.body : req.query;
      
      const resources = await getLearningResources(category, search);
      
      let userLearningData = null;
      if (userId) {
        const learningData = await getUserLearningData(userId);
        if (learningData) {
          userLearningData = learningData.learningData;
        }
      }

      res.json({
        success: true,
        resources: resources,
        totalResources: resources.length,
        userLearningData: userLearningData,
        timestamp: new Date().toISOString(),
        version: VERSION,
      });
    } catch (error) {
      res.status(500).json({
        success: false,
        error: "Internal server error",
        version: VERSION,
        timestamp: new Date().toISOString(),
      });
    }
  }
);

exports.getUserLearningProgress = onRequest(
  { timeoutSeconds: 15, memory: "128MiB", cors: true },
  async (req, res) => {
    res.set("Access-Control-Allow-Origin", "*");
    if (req.method === "OPTIONS") return res.status(204).send("");

    try {
      const { userId } = req.method === "POST" ? req.body : req.query;
      if (!userId) return res.status(400).json({ error: "User ID required", version: VERSION });
      
      const learningData = await getUserLearningData(userId);
      if (!learningData) {
        return res.status(404).json({ success: false, error: "User not found", version: VERSION });
      }

      res.json({
        success: true,
        userInfo: learningData.userInfo,
        learningData: learningData.learningData,
        timestamp: new Date().toISOString(),
        version: VERSION,
      });
    } catch (error) {
      res.status(500).json({
        success: false,
        error: "Internal server error",
        version: VERSION,
        timestamp: new Date().toISOString(),
      });
    }
  }
);

/* ---------------------------------------------------
 ðŸ“… Comprehensive Schedule Endpoint (Popup-Friendly)
--------------------------------------------------- */
exports.getMySchedule = onRequest(
  { timeoutSeconds: 15, memory: "128MiB", cors: true },
  async (req, res) => {
    res.set("Access-Control-Allow-Origin", "*");
    if (req.method === "OPTIONS") return res.status(204).send("");

    try {
      const { userId, date = 'today' } = req.method === "POST" ? req.body : req.query;
      if (!userId) return res.status(400).json({ error: "User ID required", version: VERSION });
      
      const scheduleData = await getComprehensiveSchedule(userId, date);
      const userData = await getUserData(userId, { type: 'user_info', subType: 'all' });

      const response = {
        success: true,
        userInfo: userData?.userInfo || null,
        schedule: {
          summary: {
            totalEvents: scheduleData.allEvents.length,
            appointments: scheduleData.appointments.length,
            consultations: scheduleData.consultations.length,
            medications: scheduleData.medications.length,
            reminders: scheduleData.reminders.length,
            assignedRoutines: scheduleData.assignedRoutines.length,
            pendingMedications: scheduleData.medications.filter(med => !med.isCompleted).length
          },
          timeline: scheduleData.allEvents.map(event => ({
            id: event.id,
            type: event.type,
            title: event.title || event.medicationName || 'Untitled',
            time: getEventTime(event),
            rawTime: getEventTimeRaw(event),
            status: getEventStatus(event),
            icon: getEventIcon(event.type),
            details: getEventDetails(event)
          })),
          groupedByTime: {
            morning: scheduleData.allEvents.filter(event => {
              const hour = new Date(getEventTimeRaw(event)).getHours();
              return hour >= 6 && hour < 12;
            }),
            afternoon: scheduleData.allEvents.filter(event => {
              const hour = new Date(getEventTimeRaw(event)).getHours();
              return hour >= 12 && hour < 18;
            }),
            evening: scheduleData.allEvents.filter(event => {
              const hour = new Date(getEventTimeRaw(event)).getHours();
              return hour >= 18 || hour < 6;
            })
          },
          rawData: scheduleData
        },
        displayMessage: userData ? generateEnhancedScheduleResponse(userData.userInfo, scheduleData, date) : 'No user data found',
        timestamp: new Date().toISOString(),
        version: VERSION,
      };

      res.json(response);
    } catch (error) {
      res.status(500).json({
        success: false,
        error: "Internal server error",
        version: VERSION,
        timestamp: new Date().toISOString(),
      });
    }
  }
);

function getEventDetails(event) {
  const details = {};
  
  switch (event.type) {
    case 'medication':
      if (event.dosage) details.dosage = event.dosage;
      if (event.quantity) details.quantity = event.quantity;
      if (event.medicationName) details.medicationName = event.medicationName;
      break;
    case 'appointment':
    case 'consultation':
      if (event.location) details.location = event.location;
      if (event.doctor || event.provider) details.provider = event.doctor || event.provider;
      break;
    case 'assigned_routine':
      if (event.description) details.description = event.description;
      if (event.duration) details.duration = event.duration;
      if (event.assignedBy) details.assignedBy = event.assignedBy;
      break;
  }
  
  if (event.notes) details.notes = event.notes;
  
  return details;
}

/* ---------------------------------------------------
 â¤ï¸ Health Check
--------------------------------------------------- */
exports.healthCheck = onRequest(
  { timeoutSeconds: 10, memory: "128MiB", cors: true },
  async (_, res) => {
    try {
      const check = await rtdb.ref("Account").limitToFirst(1).get();
      const resourcesCheck = await rtdb.ref("resources").limitToFirst(1).get();
      const medsCheck = await rtdb.ref("medicationReminders").limitToFirst(1).get();
      const remindersCheck = await rtdb.ref("reminders").limitToFirst(1).get();
      const routinesCheck = await rtdb.ref("AssignedRoutines").limitToFirst(1).get();
      
      res.json({
        status: "healthy",
        version: VERSION,
        database: check.exists() ? "connected" : "no_data",
        user_story_functions: "available",
        behavior_analysis: "available",
        medical_reminders: "available",
        timestamp: new Date().toISOString(),
      });
    } catch (err) {
      res.status(503).json({
        status: "unhealthy",
        version: VERSION,
        error: err.message,
        timestamp: new Date().toISOString(),
      });
    }
  }
);

/* ---------------------------------------------------
 ðŸ”” SCHEDULED NOTIFICATION FUNCTIONS (FIXED)
--------------------------------------------------- */
exports.sendDailyMorningNotifications = onSchedule({
  schedule: '0 8 * * *',
  timeZone: 'UTC',
}, async (event) => {
  try {
    const accountsRef = rtdb.ref('Account');
    const accountsSnap = await accountsRef.get();
    
    if (!accountsSnap.exists()) {
      return;
    }
    
    const accounts = accountsSnap.val();
    
    for (const [userKey, userData] of Object.entries(accounts)) {
      if (userData.email) {
        await createDailyNotificationForUser(userData.email, userData);
      }
    }
    
  } catch (error) {
    return;
  }
});

async function createDailyNotificationForUser(userId, userData) {
  try {
    const schedule = await getComprehensiveSchedule(userId, 'today');
    const totalEvents = schedule.allEvents.length;
    
    if (totalEvents === 0) {
      return;
    }
    
    await storeDailyNotification(userId, schedule, userData);
    
  } catch (error) {
    return;
  }
}

async function storeDailyNotification(userId, schedule, userData) {
  const notificationsRef = rtdb.ref('dailyNotifications');
  const userNotificationsRef = notificationsRef.child(normalizeEmailForFirebase(userId));
  
  const now = new Date();
  const today = now.toISOString().split('T')[0];
  
  const notification = {
    userId: userId,
    userName: userData.firstname || userData.name || 'User',
    date: today,
    timestamp: now.toISOString(),
    totalEvents: schedule.allEvents.length,
    appointments: schedule.appointments.length,
    consultations: schedule.consultations.length,
    medications: schedule.medications.length,
    reminders: schedule.reminders.length,
    assignedRoutines: schedule.assignedRoutines.length,
    events: schedule.allEvents.map(event => ({
      type: event.type,
      title: event.title || event.medicationName,
      time: getEventTime(event),
      status: getEventStatus(event)
    })),
    message: generateDailyNotificationMessage(userData.firstname || userData.name || 'User', schedule),
    read: false,
    sent: false
  };
  
  await userNotificationsRef.push(notification);
}

function generateDailyNotificationMessage(userName, schedule) {
  const { appointments, consultations, medications, reminders, assignedRoutines, allEvents } = schedule;
  const totalEvents = allEvents.length;
  
  let message = `ðŸ“… Good morning ${userName}! Here's your schedule for today:\n\n`;
  
  if (totalEvents === 0) {
    message += `You don't have any events scheduled for today. Enjoy your day! ðŸŽ‰`;
    return message;
  }
  
  message += `You have ${totalEvents} events today:\n`;
  message += `â€¢ ðŸ“… Appointments: ${appointments.length}\n`;
  message += `â€¢ ðŸ¥ Consultations: ${consultations.length}\n`;
  message += `â€¢ ðŸ’Š Medications: ${medications.length}\n`;
  message += `â€¢ â° Reminders: ${reminders.length}\n`;
  message += `â€¢ ðŸ“‹ Routines: ${assignedRoutines.length}\n\n`;
  
  const nextEvents = allEvents.slice(0, 3);
  message += `â° **Next Events:**\n`;
  
  nextEvents.forEach((event, index) => {
    const time = getEventTime(event);
    message += `${index + 1}. ${getEventIcon(event.type)} ${event.title || event.medicationName} at ${time}\n`;
  });
  
  if (totalEvents > 3) {
    message += `\n... and ${totalEvents - 3} more events today.`;
  }
  
  message += `\n\nHave a wonderful day! ðŸŒ±`;
  
  return message;
}

/* ---------------------------------------------------
 ðŸ”” Login Schedule Popup Endpoint
--------------------------------------------------- */
exports.getLoginSchedulePopup = onRequest(
  { 
    timeoutSeconds: 30, // Increased timeout
    memory: "256MiB", // Increased memory
    cors: true 
  },
  async (req, res) => {
    console.log('ðŸ”” getLoginSchedulePopup called');
    
    // Set CORS headers properly
    res.set("Access-Control-Allow-Origin", "*");
    res.set("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
    res.set("Access-Control-Allow-Headers", "Content-Type");

    if (req.method === "OPTIONS") {
      return res.status(204).send("");
    }

    // Add timeout handling
    const timeoutPromise = new Promise((_, reject) => {
      setTimeout(() => reject(new Error("Function timeout")), 25000);
    });

    try {
      console.log('ðŸ“ Parsing request...');
      const { userId } = req.method === "POST" ? req.body : req.query;
      console.log('ðŸ‘¤ User ID:', userId);
      
      if (!userId) {
        console.log('âŒ No user ID provided');
        return res.status(400).json({ 
          success: false, 
          error: "User ID required", 
          version: VERSION 
        });
      }

      console.log('ðŸ” Getting user data...');
      const userDataPromise = getUserData(userId, { 
        type: 'user_info', 
        subType: 'all' 
      });
      
      // Race between function and our timeout
      const userData = await Promise.race([userDataPromise, timeoutPromise]);
      
      console.log('âœ… User data retrieved:', userData ? 'found' : 'not found');
      
      if (!userData) {
        console.log('âŒ User not found');
        return res.status(404).json({ 
          success: false, 
          error: "User not found", 
          version: VERSION 
        });
      }

      console.log('ðŸ“… Getting comprehensive schedule...');
      const scheduleDataPromise = getComprehensiveSchedule(userId, 'today');
      const scheduleData = await Promise.race([scheduleDataPromise, timeoutPromise]);
      
      console.log('âœ… Schedule data retrieved, events:', scheduleData.allEvents.length);
      
      console.log('ðŸŽ¯ Generating popup data...');
      const popupData = generateLoginPopupData(userData.userInfo, scheduleData);
      console.log('âœ… Popup data generated');
      
      const response = {
        success: true,
        showPopup: popupData.showPopup,
        popupData: popupData,
        userInfo: userData.userInfo,
        timestamp: new Date().toISOString(),
        version: VERSION,
      };
      
      console.log('ðŸš€ Sending successful response');
      return res.json(response);
      
    } catch (error) {
      console.error('ðŸ’¥ ERROR in getLoginSchedulePopup:', error);
      console.error('ðŸ” Error stack:', error.stack);
      
      // Different error messages based on error type
      let errorMessage = "Internal server error";
      if (error.message.includes("timeout")) {
        errorMessage = "Request timeout - please try again";
      } else if (error.message.includes("network") || error.message.includes("fetch")) {
        errorMessage = "Network error - check your connection";
      } else {
        errorMessage = "Internal server error: " + error.message;
      }
      
      return res.status(500).json({
        success: false,
        error: errorMessage,
        version: VERSION,
        timestamp: new Date().toISOString(),
      });
    }
  }
);

function generateLoginPopupData(userInfo, scheduleData) {
  const { appointments, consultations, medications, reminders, assignedRoutines, activities, allEvents } = scheduleData;
  
  const totalEvents = allEvents.length;
  const today = new Date().toLocaleDateString('en-US', { 
    weekday: 'long', 
    year: 'numeric', 
    month: 'long', 
    day: 'numeric' 
  });
  
  const pendingMeds = medications.filter(med => !med.isCompleted);
  const now = new Date();
  const upcomingEvents = allEvents.filter(event => {
    const eventTime = new Date(getEventTimeRaw(event));
    return eventTime > now;
  });
  
  const nextEvent = upcomingEvents[0];
  const showPopup = totalEvents > 0 || pendingMeds.length > 0;
  
  return {
    showPopup: showPopup,
    title: `ðŸ“… Today's Schedule`,
    subtitle: `Welcome back, ${userInfo.firstName || userInfo.name.split(' ')[0] || 'there'}!`,
    date: today,
    summary: {
      totalEvents: totalEvents,
      appointments: appointments.length,
      consultations: consultations.length,
      medications: medications.length,
      reminders: reminders.length,
      routines: assignedRoutines.length,
      pendingMeds: pendingMeds.length
    },
    highlights: {
      nextEvent: nextEvent ? {
        title: nextEvent.title || nextEvent.medicationName,
        time: getEventTime(nextEvent),
        type: nextEvent.type,
        icon: getEventIcon(nextEvent.type)
      } : null,
      pendingMeds: pendingMeds.length,
      hasEvents: totalEvents > 0
    },
    timeline: allEvents.slice(0, 8).map(event => ({
      id: event.id,
      type: event.type,
      icon: getEventIcon(event.type),
      title: event.title || event.medicationName,
      time: getEventTime(event),
      status: getEventStatus(event),
      isUpcoming: new Date(getEventTimeRaw(event)) > now,
      details: getEventDetails(event)
    })),
    greeting: getTimeBasedGreeting()
  };
}

function getTimeBasedGreeting() {
  const hour = new Date().getHours();
  
  if (hour < 12) return "Good morning! ðŸŒ…";
  else if (hour < 18) return "Good afternoon! â˜€ï¸";
  else return "Good evening! ðŸŒ™";
}

/* ---------------------------------------------------
 ðŸŽ¯ ACTIVITIES FUNCTIONS
--------------------------------------------------- */
async function getActivitiesForSchedule(userId, dateQuery = 'today') {
  try {
    const activitiesRef = rtdb.ref("Activities");
    const snapshot = await activitiesRef.get();
    
    if (!snapshot.exists()) {
      return [];
    }

    const activities = snapshot.val();
    const activityList = Object.keys(activities)
      .filter(key => isNaN(parseInt(key)))
      .map(key => ({
        id: key,
        type: 'activity',
        ...activities[key]
      }));

    const userActivities = await getUserRegisteredActivities(userId, dateQuery);
    const todayActivities = [...userActivities];
    
    if (todayActivities.length === 0 && dateQuery === 'today') {
      const generalActivities = activityList.slice(0, 3).map(activity => ({
        ...activity,
        date: new Date().toISOString().split('T')[0],
        time: '10:00',
        isRegistered: false
      }));
      todayActivities.push(...generalActivities);
    }
    
    return todayActivities;

  } catch (error) {
    return [];
  }
}

async function getUserRegisteredActivities(userId, dateQuery = 'today') {
  try {
    const activitiesRef = rtdb.ref("Activities");
    const snapshot = await activitiesRef.get();
    
    if (!snapshot.exists()) {
      return [];
    }

    const activities = snapshot.val();
    const userActivities = [];

    for (const [activityId, activity] of Object.entries(activities)) {
      if (activity.registrations && typeof activity.registrations === 'object') {
        const registrations = activity.registrations;
        
        for (const [registrationId, registration] of Object.entries(registrations)) {
          if (registration.registeredEmail === userId || 
              registration.registeredEmail === normalizeEmailForFirebase(userId)) {
            
            const registrationDate = registration.date;
            if (matchesDateQuery(registrationDate, dateQuery)) {
              userActivities.push({
                id: activityId,
                registrationId: registrationId,
                type: 'activity',
                title: activity.title,
                description: activity.description,
                category: activity.category,
                duration: activity.duration,
                difficulty: activity.difficulty,
                image: activity.image,
                date: registrationDate,
                time: registration.time || '10:00',
                status: registration.status || 'confirmed',
                isRegistered: true,
                ...activity
              });
            }
          }
        }
      }
    }

    return userActivities;

  } catch (error) {
    return [];
  }
}

function matchesDateQuery(dateStr, dateQuery) {
  if (!dateStr) return false;
  
  const date = new Date(dateStr);
  date.setHours(0, 0, 0, 0);
  
  const today = new Date();
  today.setHours(0, 0, 0, 0);
  
  const tomorrow = new Date(today);
  tomorrow.setDate(tomorrow.getDate() + 1);
  
  switch (dateQuery) {
    case 'today':
      return date.getTime() === today.getTime();
    case 'tomorrow':
      return date.getTime() === tomorrow.getTime();
    case 'all':
      return true;
    case 'upcoming':
    default:
      return date >= today;
  }
}

async function retrieveSelectedActivities(userId) {
  try {
    const learningData = await getUserLearningData(userId);
    
    if (!learningData || !learningData.learningData) {
      return [];
    }
    
    const { resourcesClicked = [] } = learningData.learningData;
    
    if (resourcesClicked.length > 0) {
      const allResources = await getLearningResources();
      const recentActivities = allResources.filter(resource => 
        resourcesClicked.includes(resource.id)
      ).slice(0, 10);
      
      return recentActivities;
    }
    
    const registeredActivities = await getUserRegisteredActivities(userId, 'all');
    if (registeredActivities.length > 0) {
      return registeredActivities.slice(0, 10);
    }
    
    return [];
  } catch (error) {
    return [];
  }
}

function analyzeActivitiesPreferences(recentActivities) {
  if (!recentActivities || recentActivities.length === 0) {
    return {
      preferredCategories: ['Wellness', 'Social'],
      preferredDifficulty: 'Easy',
      preferredDuration: '30-45 mins',
      activityFrequency: 'New User',
      interests: ['General wellness', 'Social activities'],
      totalActivities: 0,
      favoriteActivity: 'Not specified',
      engagementLevel: 'New'
    };
  }

  const categoryCount = {};
  const difficultyCount = {};
  const durationCount = {};
  
  recentActivities.forEach(activity => {
    const category = activity.category || 'General';
    categoryCount[category] = (categoryCount[category] || 0) + 1;
    
    const difficulty = activity.difficulty || 'Easy';
    difficultyCount[difficulty] = (difficultyCount[difficulty] || 0) + 1;
    
    const duration = activity.duration || '30 min';
    durationCount[duration] = (durationCount[duration] || 0) + 1;
  });

  const topCategory = Object.entries(categoryCount)
    .sort(([,a], [,b]) => b - a)[0]?.[0] || 'Wellness';
    
  const topDifficulty = Object.entries(difficultyCount)
    .sort(([,a], [,b]) => b - a)[0]?.[0] || 'Easy';
    
  const topDuration = Object.entries(durationCount)
    .sort(([,a], [,b]) => b - a)[0]?.[0] || '30-45 mins';

  let frequency;
  if (recentActivities.length > 10) frequency = 'Very Active';
  else if (recentActivities.length > 5) frequency = 'Active';
  else if (recentActivities.length > 2) frequency = 'Moderate';
  else frequency = 'Occasional';

  const interests = [];
  if (topCategory.includes('Wellness') || topCategory.includes('Exercise')) interests.push('Health & Wellness');
  if (topCategory.includes('Social')) interests.push('Social Activities');
  if (topCategory.includes('Learning') || topCategory.includes('Education')) interests.push('Learning & Education');
  if (topCategory.includes('Community')) interests.push('Community Events');
  if (interests.length === 0) interests.push('General activities');

  const preferences = {
    preferredCategories: [topCategory],
    preferredDifficulty: topDifficulty,
    preferredDuration: topDuration,
    activityFrequency: frequency,
    interests: interests,
    totalActivities: recentActivities.length,
    favoriteActivity: recentActivities[0]?.title || 'Not specified',
    engagementLevel: recentActivities.length > 5 ? 'High' : recentActivities.length > 2 ? 'Moderate' : 'Low'
  };

  return preferences;
}

function generateActivitiesPreferencesResponse(userInfo, activitiesPreferences) {
  let response = `ðŸŽ¯ **Your Activities Preferences**, ${userInfo.name}!\n\n`;
  
  response += `ðŸ“Š **Activity Level:** ${activitiesPreferences.activityFrequency}\n`;
  response += `ðŸ·ï¸ **Preferred Categories:** ${activitiesPreferences.preferredCategories.join(', ')}\n`;
  response += `â­ **Difficulty Preference:** ${activitiesPreferences.preferredDifficulty}\n`;
  response += `â±ï¸ **Preferred Duration:** ${activitiesPreferences.preferredDuration}\n`;
  response += `â¤ï¸ **Your Interests:** ${activitiesPreferences.interests.join(', ')}\n\n`;
  
  response += `ðŸ“ˆ **Activity Stats:**\n`;
  response += `â€¢ Total activities: ${activitiesPreferences.totalActivities}\n`;
  response += `â€¢ Engagement level: ${activitiesPreferences.engagementLevel}\n`;
  
  if (activitiesPreferences.favoriteActivity !== 'Not specified') {
    response += `â€¢ Favorite activity: ${activitiesPreferences.favoriteActivity}\n`;
  }
  
  response += `\nðŸ’¡ **Suggestions:**\n`;
  
  if (activitiesPreferences.activityFrequency === 'New User') {
    response += `â€¢ Welcome! Start by exploring different activities\n`;
    response += `â€¢ Try our wellness and social activities first\n`;
    response += `â€¢ Join 1-2 activities per week to get started\n`;
  } else if (activitiesPreferences.activityFrequency === 'Occasional') {
    response += `â€¢ Try to join at least 2 activities per week\n`;
    response += `â€¢ Explore different categories to find what you enjoy\n`;
  } else if (activitiesPreferences.activityFrequency === 'Moderate') {
    response += `â€¢ Great! You're maintaining a good activity level\n`;
    response += `â€¢ Consider trying activities in new categories\n`;
  } else {
    response += `â€¢ Excellent! You're very active\n`;
    response += `â€¢ Share your favorite activities with friends\n`;
  }
  
  response += `â€¢ Check the activities section for new opportunities\n`;
  
  return response;
}

function generateActivitiesResponse(userInfo, activities, dateQuery) {
  const timeContext = getTimeContext(dateQuery).replace('appointments', 'activities');
  
  if (activities.length === 0) {
    return `You don't have any ${timeContext}, ${userInfo.name}. You can explore available activities in the activities section!`;
  }
  
  let response = `Here are your ${timeContext}, ${userInfo.name}:\n\n`;
  
  const registeredActivities = activities.filter(act => act.isRegistered);
  const suggestedActivities = activities.filter(act => !act.isRegistered);
  
  if (registeredActivities.length > 0) {
    response += `âœ… **Registered Activities:**\n`;
    registeredActivities.forEach((activity, index) => {
      const time = activity.time ? formatDisplayTime(activity.time) : 'All day';
      response += `${index + 1}. **${activity.title}**\n`;
      response += `   â° ${time} on ${formatDisplayDate(activity.date)}\n`;
      if (activity.category) response += `   ðŸ·ï¸ ${activity.category}\n`;
      if (activity.duration) response += `   â±ï¸ ${activity.duration}\n`;
      if (activity.description) response += `   ðŸ“ ${activity.description}\n`;
      response += `\n`;
    });
  }
  
  if (suggestedActivities.length > 0) {
    response += `ðŸ’¡ **Suggested Activities:**\n`;
    suggestedActivities.forEach((activity, index) => {
      response += `${index + 1}. **${activity.title}**\n`;
      if (activity.category) response += `   ðŸ·ï¸ ${activity.category}\n`;
      if (activity.duration) response += `   â±ï¸ ${activity.duration}\n`;
      if (activity.difficulty) response += `   â­ ${activity.difficulty}\n`;
      if (activity.description) response += `   ðŸ“ ${activity.description}\n`;
      response += `\n`;
    });
  }
  
  return response;
}

/* ---------------------------------------------------
 ðŸŽ¯ ACTIVITIES API ENDPOINTS
--------------------------------------------------- */
exports.getUserActivities = onRequest(
  { timeoutSeconds: 15, memory: "128MiB", cors: true },
  async (req, res) => {
    res.set("Access-Control-Allow-Origin", "*");
    if (req.method === "OPTIONS") return res.status(204).send("");

    try {
      const { userId, date = 'today' } = req.method === "POST" ? req.body : req.query;
      if (!userId) return res.status(400).json({ error: "User ID required", version: VERSION });

      const activities = await getActivitiesForSchedule(userId, date);
      const userData = await getUserData(userId, { type: 'user_info', subType: 'all' });

      res.json({
        success: true,
        userInfo: userData?.userInfo || null,
        activities: activities,
        totalActivities: activities.length,
        registeredActivities: activities.filter(act => act.isRegistered).length,
        suggestedActivities: activities.filter(act => !act.isRegistered).length,
        timestamp: new Date().toISOString(),
        version: VERSION,
      });
    } catch (error) {
      res.status(500).json({
        success: false,
        error: "Internal server error",
        version: VERSION,
        timestamp: new Date().toISOString(),
      });
    }
  }
);
/* ---------------------------------------------------
 ðŸŽ¯ ACTIVITIES PREFERENCES FUNCTIONS - HYBRID DATABASE
--------------------------------------------------- */

// Main function to get activities preferences from both databases
async function getActivitiesPreferences(userId) {
  try {
    console.log("ðŸŽ¯ Getting activities preferences for:", userId);
    
    // Try Firestore first
    let preferences = await getActivitiesPreferencesFromFirestore(userId);
    let dataSource = 'firestore';
    
    // If Firestore fails or returns empty, try Realtime Database
    if (!preferences || Object.keys(preferences).length === 0) {
      console.log("ðŸ”„ Firestore returned empty, trying Realtime Database...");
      preferences = await getActivitiesPreferencesFromRTDB(userId);
      dataSource = 'realtime-db';
    }
    
    // If both databases return empty, generate default preferences
    if (!preferences || Object.keys(preferences).length === 0) {
      console.log("ðŸ”„ Both databases empty, generating default preferences...");
      preferences = await generateDefaultActivitiesPreferences(userId);
      dataSource = 'default';
    }
    
    console.log(`âœ… Activities preferences retrieved from: ${dataSource}`);
    
    return {
      success: true,
      preferences: preferences,
      dataSource: dataSource,
      timestamp: new Date().toISOString()
    };
    
  } catch (error) {
    console.error("ðŸ’¥ Error getting activities preferences:", error);
    
    // Fallback to default preferences on error
    const defaultPreferences = await generateDefaultActivitiesPreferences(userId);
    
    return {
      success: false,
      preferences: defaultPreferences,
      dataSource: 'error_fallback',
      error: error.message,
      timestamp: new Date().toISOString()
    };
  }
}

// Get activities preferences from Firestore
async function getActivitiesPreferencesFromFirestore(userId) {
  try {
    if (!firestore) {
      console.log("âŒ Firestore not initialized");
      return null;
    }
    
    const userDocRef = firestore.collection('users').doc(userId);
    const userDoc = await userDocRef.get();
    
    if (!userDoc.exists) {
      console.log("ðŸ“­ User not found in Firestore");
      return null;
    }
    
    const userData = userDoc.data();
    
    // Check various possible locations for preferences in Firestore
    let preferences = null;
    
    if (userData.activitiesPreferences) {
      preferences = userData.activitiesPreferences;
    } else if (userData.preferences && userData.preferences.activities) {
      preferences = userData.preferences.activities;
    } else if (userData.userPreferences && userData.userPreferences.activities) {
      preferences = userData.userPreferences.activities;
    } else if (userData.learningData && userData.learningData.preferences) {
      preferences = userData.learningData.preferences;
    }
    
    // If we found preferences, enhance with user info
    if (preferences) {
      preferences.userId = userId;
      preferences.lastUpdated = userData.lastUpdated || userData.updatedAt || new Date().toISOString();
      preferences.dataSource = 'firestore';
    }
    
    return preferences;
    
  } catch (error) {
    console.error("âŒ Firestore preferences error:", error);
    return null;
  }
}

// Get activities preferences from Realtime Database
async function getActivitiesPreferencesFromRTDB(userId) {
  try {
    const normalizedKey = normalizeEmailForFirebase(userId);
    
    // Try multiple possible paths in RTDB
    const possiblePaths = [
      `Account/${normalizedKey}/activitiesPreferences`,
      `Account/${normalizedKey}/preferences/activities`,
      `Account/${normalizedKey}/userPreferences/activities`,
      `users/${normalizedKey}/activitiesPreferences`,
      `userPreferences/${normalizedKey}/activities`,
      `activitiesPreferences/${normalizedKey}`
    ];
    
    for (const path of possiblePaths) {
      try {
        const preferencesRef = rtdb.ref(path);
        const snapshot = await preferencesRef.get();
        
        if (snapshot.exists()) {
          console.log(`âœ… Found preferences at: ${path}`);
          const preferences = snapshot.val();
          
          // Enhance with metadata
          preferences.userId = userId;
          preferences.lastUpdated = preferences.lastUpdated || new Date().toISOString();
          preferences.dataSource = 'realtime-db';
          preferences.foundAtPath = path;
          
          return preferences;
        }
      } catch (pathError) {
        console.log(`âŒ Path ${path} not accessible:`, pathError.message);
        continue;
      }
    }
    
    // If no preferences found, try to generate from user activities
    console.log("ðŸ”„ No direct preferences found, generating from user activities...");
    const generatedPreferences = await generatePreferencesFromUserActivities(userId);
    
    return generatedPreferences;
    
  } catch (error) {
    console.error("âŒ RTDB preferences error:", error);
    return null;
  }
}

// Generate preferences by analyzing user's activities
async function generatePreferencesFromUserActivities(userId) {
  try {
    // Get user's recent activities from both databases
    const recentActivities = await retrieveSelectedActivities(userId);
    
    // Analyze activities to generate preferences
    const preferences = analyzeActivitiesPreferences(recentActivities);
    
    // Enhance with user data
    const userData = await getUserData(userId, { type: 'user_info', subType: 'all' });
    
    if (userData && userData.userInfo) {
      preferences.userId = userId;
      preferences.userName = userData.userInfo.name;
      preferences.userAge = userData.userInfo.age;
      preferences.generatedFromActivities = true;
      preferences.activitiesAnalyzed = recentActivities.length;
      preferences.lastUpdated = new Date().toISOString();
      preferences.dataSource = 'generated_from_activities';
    }
    
    // Save the generated preferences for future use
    await saveGeneratedPreferences(userId, preferences);
    
    return preferences;
    
  } catch (error) {
    console.error("âŒ Error generating preferences from activities:", error);
    return generateDefaultActivitiesPreferences(userId);
  }
}

// Save generated preferences to database
async function saveGeneratedPreferences(userId, preferences) {
  try {
    // Try saving to Firestore first
    try {
      if (firestore) {
        const userDocRef = firestore.collection('users').doc(userId);
        await userDocRef.set({
          activitiesPreferences: preferences,
          lastUpdated: new Date().toISOString()
        }, { merge: true });
        console.log("âœ… Preferences saved to Firestore");
      }
    } catch (firestoreError) {
      console.log("âŒ Could not save to Firestore:", firestoreError.message);
    }
    
    // Try saving to Realtime Database
    try {
      const normalizedKey = normalizeEmailForFirebase(userId);
      const preferencesRef = rtdb.ref(`Account/${normalizedKey}/activitiesPreferences`);
      await preferencesRef.set(preferences);
      console.log("âœ… Preferences saved to Realtime Database");
    } catch (rtdbError) {
      console.log("âŒ Could not save to Realtime Database:", rtdbError.message);
    }
    
  } catch (error) {
    console.error("âŒ Error saving generated preferences:", error);
    // Don't throw error - this is non-critical
  }
}

// Generate default activities preferences
async function generateDefaultActivitiesPreferences(userId) {
  try {
    // Get basic user info for better defaults
    const userData = await getUserData(userId, { type: 'user_info', subType: 'all' });
    
    const defaultPreferences = {
      userId: userId,
      userName: userData?.userInfo?.name || 'User',
      userAge: userData?.userInfo?.age || null,
      preferredCategories: ['Wellness', 'Social', 'Learning'],
      preferredDifficulty: 'Easy',
      preferredDuration: '30-45 mins',
      activityFrequency: 'New User',
      interests: ['General wellness', 'Social activities', 'Health education'],
      totalActivities: 0,
      favoriteActivity: 'Not specified',
      engagementLevel: 'New',
      notificationPreferences: {
        newActivities: true,
        reminders: true,
        recommendations: true
      },
      accessibilityNeeds: {
        mobility: 'Standard',
        vision: 'Standard',
        hearing: 'Standard'
      },
      timePreferences: {
        morning: true,
        afternoon: true,
        evening: false
      },
      socialPreferences: {
        groupActivities: true,
        individualActivities: true,
        virtualActivities: true
      },
      generatedAutomatically: true,
      lastUpdated: new Date().toISOString(),
      dataSource: 'default_generated'
    };
    
    // Adjust defaults based on user age if available
    if (userData?.userInfo?.age) {
      const age = userData.userInfo.age;
      if (age > 75) {
        defaultPreferences.preferredDifficulty = 'Very Easy';
        defaultPreferences.preferredDuration = '20-30 mins';
        defaultPreferences.accessibilityNeeds.mobility = 'Enhanced';
      } else if (age > 65) {
        defaultPreferences.preferredDifficulty = 'Easy';
        defaultPreferences.preferredDuration = '30-45 mins';
      }
      
      // Adjust based on medical conditions if available
      if (userData.userInfo.medicalConditions && userData.userInfo.medicalConditions.length > 0) {
        defaultPreferences.interests.push('Health management');
        if (userData.userInfo.medicalConditions.some(condition => 
          condition.toLowerCase().includes('heart') || condition.toLowerCase().includes('cardio'))) {
          defaultPreferences.preferredDifficulty = 'Light';
        }
      }
    }
    
    return defaultPreferences;
    
  } catch (error) {
    console.error("âŒ Error generating default preferences:", error);
    
    // Ultimate fallback
    return {
      userId: userId,
      preferredCategories: ['General'],
      preferredDifficulty: 'Easy',
      preferredDuration: '30 mins',
      activityFrequency: 'New User',
      interests: ['General activities'],
      totalActivities: 0,
      engagementLevel: 'New',
      generatedAutomatically: true,
      lastUpdated: new Date().toISOString(),
      dataSource: 'fallback'
    };
  }
}

// Enhanced function to retrieve user's selected activities from both databases
async function retrieveSelectedActivities(userId) {
  try {
    let activities = [];
    
    // Try Firestore first
    try {
      const firestoreActivities = await getActivitiesFromFirestore(userId);
      if (firestoreActivities && firestoreActivities.length > 0) {
        activities = firestoreActivities;
        console.log(`âœ… Found ${activities.length} activities in Firestore`);
      }
    } catch (firestoreError) {
      console.log("âŒ Firestore activities retrieval failed:", firestoreError.message);
    }
    
    // If Firestore empty, try Realtime Database
    if (activities.length === 0) {
      try {
        const rtdbActivities = await getActivitiesFromRTDB(userId);
        if (rtdbActivities && rtdbActivities.length > 0) {
          activities = rtdbActivities;
          console.log(`âœ… Found ${activities.length} activities in Realtime Database`);
        }
      } catch (rtdbError) {
        console.log("âŒ Realtime Database activities retrieval failed:", rtdbError.message);
      }
    }
    
    // If both empty, get from learning resources
    if (activities.length === 0) {
      try {
        const learningActivities = await getActivitiesFromLearningResources(userId);
        if (learningActivities && learningActivities.length > 0) {
          activities = learningActivities;
          console.log(`âœ… Found ${activities.length} activities from learning resources`);
        }
      } catch (learningError) {
        console.log("âŒ Learning resources activities retrieval failed:", learningError.message);
      }
    }
    
    return activities;
    
  } catch (error) {
    console.error("ðŸ’¥ Error retrieving selected activities:", error);
    return [];
  }
}

// Get activities from Firestore
async function getActivitiesFromFirestore(userId) {
  try {
    if (!firestore) {
      console.log("âŒ Firestore not initialized");
      return [];
    }
    
    const activitiesRef = firestore.collection('activities');
    const snapshot = await activitiesRef
      .where('userId', '==', userId)
      .orderBy('lastAccessed', 'desc')
      .limit(20)
      .get();
    
    if (snapshot.empty) {
      return [];
    }
    
    const activities = [];
    snapshot.forEach(doc => {
      activities.push({
        id: doc.id,
        ...doc.data()
      });
    });
    
    return activities;
    
  } catch (error) {
    console.error("âŒ Firestore activities error:", error);
    return [];
  }
}

// Get activities from Realtime Database
async function getActivitiesFromRTDB(userId) {
  try {
    const activities = [];
    const normalizedKey = normalizeEmailForFirebase(userId);
    
    // Check multiple possible paths
    const possiblePaths = [
      `userActivities/${normalizedKey}`,
      `Account/${normalizedKey}/selectedActivities`,
      `activitiesRegistrations/${normalizedKey}`,
      `learningData/${normalizedKey}/resourcesClicked`
    ];
    
    for (const path of possiblePaths) {
      try {
        const ref = rtdb.ref(path);
        const snapshot = await ref.get();
        
        if (snapshot.exists()) {
          const data = snapshot.val();
          
          if (typeof data === 'object') {
            Object.entries(data).forEach(([key, value]) => {
              if (value && typeof value === 'object') {
                activities.push({
                  id: key,
                  ...value
                });
              } else if (key !== 'undefined' && value) {
                // Handle simple key-value pairs (like resourcesClicked)
                activities.push({
                  id: key,
                  title: value.title || `Activity ${key}`,
                  category: value.category || 'General',
                  accessedAt: value.timestamp || new Date().toISOString()
                });
              }
            });
          }
          
          if (activities.length > 0) {
            console.log(`âœ… Found activities at path: ${path}`);
            break;
          }
        }
      } catch (pathError) {
        continue;
      }
    }
    
    return activities.slice(0, 20); // Limit to 20 most recent
    
  } catch (error) {
    console.error("âŒ RTDB activities error:", error);
    return [];
  }
}

// Get activities from learning resources
async function getActivitiesFromLearningResources(userId) {
  try {
    const learningData = await getUserLearningData(userId);
    
    if (!learningData || !learningData.learningData) {
      return [];
    }
    
    const { resourcesClicked = [] } = learningData.learningData;
    
    if (resourcesClicked.length === 0) {
      return [];
    }
    
    // Get the actual resource details
    const allResources = await getLearningResources();
    const recentActivities = allResources.filter(resource => 
      resourcesClicked.includes(resource.id)
    ).slice(0, 10);
    
    return recentActivities.map(resource => ({
      id: resource.id,
      title: resource.title,
      category: resource.category,
      description: resource.description,
      accessedAt: resource.lastAccessed || new Date().toISOString(),
      type: 'learning_resource'
    }));
    
  } catch (error) {
    console.error("âŒ Learning resources activities error:", error);
    return [];
  }
}

// Enhanced analysis function
function analyzeActivitiesPreferences(recentActivities) {
  if (!recentActivities || recentActivities.length === 0) {
    return {
      preferredCategories: ['Wellness', 'Social'],
      preferredDifficulty: 'Easy',
      preferredDuration: '30-45 mins',
      activityFrequency: 'New User',
      interests: ['General wellness', 'Social activities'],
      totalActivities: 0,
      favoriteActivity: 'Not specified',
      engagementLevel: 'New',
      confidenceScore: 0
    };
  }

  const categoryCount = {};
  const difficultyCount = {};
  const durationCount = {};
  const typeCount = {};
  
  recentActivities.forEach(activity => {
    // Category analysis
    const category = activity.category || 'General';
    categoryCount[category] = (categoryCount[category] || 0) + 1;
    
    // Difficulty analysis
    const difficulty = activity.difficulty || 'Easy';
    difficultyCount[difficulty] = (difficultyCount[difficulty] || 0) + 1;
    
    // Duration analysis
    const duration = activity.duration || '30 min';
    durationCount[duration] = (durationCount[duration] || 0) + 1;
    
    // Type analysis
    const type = activity.type || 'general';
    typeCount[type] = (typeCount[type] || 0) + 1;
  });

  // Calculate top preferences
  const topCategories = Object.entries(categoryCount)
    .sort(([,a], [,b]) => b - a)
    .slice(0, 3)
    .map(([category]) => category);
    
  const topDifficulty = Object.entries(difficultyCount)
    .sort(([,a], [,b]) => b - a)[0]?.[0] || 'Easy';
    
  const topDuration = Object.entries(durationCount)
    .sort(([,a], [,b]) => b - a)[0]?.[0] || '30-45 mins';

  // Calculate frequency level
  let frequency;
  if (recentActivities.length > 15) frequency = 'Very Active';
  else if (recentActivities.length > 8) frequency = 'Active';
  else if (recentActivities.length > 3) frequency = 'Moderate';
  else frequency = 'Occasional';

  // Determine interests based on categories
  const interests = [];
  topCategories.forEach(category => {
    if (category.includes('Wellness') || category.includes('Exercise') || category.includes('Health')) {
      if (!interests.includes('Health & Wellness')) interests.push('Health & Wellness');
    }
    if (category.includes('Social') || category.includes('Community')) {
      if (!interests.includes('Social Activities')) interests.push('Social Activities');
    }
    if (category.includes('Learning') || category.includes('Education')) {
      if (!interests.includes('Learning & Education')) interests.push('Learning & Education');
    }
    if (category.includes('Creative') || category.includes('Art')) {
      if (!interests.includes('Creative Activities')) interests.push('Creative Activities');
    }
  });
  
  if (interests.length === 0) interests.push('General activities');

  // Calculate confidence score based on data quality
  const confidenceScore = Math.min(100, Math.floor(
    (recentActivities.length / 20) * 70 + // 70% based on activity count
    (topCategories.length / 3) * 30 // 30% based on category diversity
  ));

  const preferences = {
    preferredCategories: topCategories,
    preferredDifficulty: topDifficulty,
    preferredDuration: topDuration,
    activityFrequency: frequency,
    interests: interests,
    totalActivities: recentActivities.length,
    favoriteActivity: recentActivities[0]?.title || 'Not specified',
    engagementLevel: recentActivities.length > 10 ? 'High' : recentActivities.length > 5 ? 'Moderate' : 'Low',
    confidenceScore: confidenceScore,
    lastActivityDate: recentActivities[0]?.accessedAt || new Date().toISOString(),
    analysisDate: new Date().toISOString()
  };

  return preferences;
}

/* ---------------------------------------------------
 ðŸŽ¯ UPDATED ACTIVITIES PREFERENCES API ENDPOINT
--------------------------------------------------- */

exports.getActivitiesPreferences = onRequest(
  { 
    timeoutSeconds: 30, 
    memory: "256MiB", 
    cors: true 
  },
  async (req, res) => {
    // Set CORS headers
    res.set("Access-Control-Allow-Origin", "*");
    res.set("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
    res.set("Access-Control-Allow-Headers", "Content-Type");

    if (req.method === "OPTIONS") {
      return res.status(204).send("");
    }

    try {
      console.log("ðŸŽ¯ Received request for activities preferences");
      
      const { userId } = req.method === "POST" ? req.body : req.query;
      
      console.log("ðŸ‘¤ User ID:", userId);

      if (!userId) {
        return res.status(400).json({ 
          success: false, 
          error: "User ID is required", 
          version: VERSION 
        });
      }

      if (!validateEmail(userId)) {
        return res.status(400).json({ 
          success: false, 
          error: "Invalid user ID format", 
          version: VERSION 
        });
      }

      // Get user data for context
      const userData = await getUserData(userId, { type: 'user_info', subType: 'all' });
      
      if (!userData) {
        return res.status(404).json({ 
          success: false, 
          error: "User not found", 
          version: VERSION 
        });
      }

      // Get activities preferences using hybrid approach
      const preferencesResult = await getActivitiesPreferences(userId);
      
      // Get recent activities for display
      const recentActivities = await retrieveSelectedActivities(userId);
      
      // Generate display messages
      const displayMessage = generateActivitiesPreferencesResponse(userData.userInfo, preferencesResult.preferences);
      const activitiesMessage = generateActivitiesResponse(userData.userInfo, recentActivities, 'all');

      // Build response
      const response = {
        success: preferencesResult.success,
        userInfo: userData.userInfo,
        preferences: preferencesResult.preferences,
        dataSource: preferencesResult.dataSource,
        recentActivities: recentActivities.slice(0, 10), // Limit to 10 most recent
        displayMessage: displayMessage,
        activitiesMessage: activitiesMessage,
        summary: {
          totalPreferences: Object.keys(preferencesResult.preferences).length,
          totalActivities: recentActivities.length,
          confidenceScore: preferencesResult.preferences.confidenceScore || 0,
          dataSourcesChecked: ['firestore', 'realtime-db', 'learning_resources']
        },
        timestamp: new Date().toISOString(),
        version: VERSION,
      };

      // Include error info if applicable
      if (preferencesResult.error) {
        response.error = preferencesResult.error;
      }

      console.log(`âœ… Successfully returned activities preferences from: ${preferencesResult.dataSource}`);
      return res.json(response);

    } catch (error) {
      console.error("ðŸ’¥ ERROR in getActivitiesPreferences endpoint:", error);
      
      return res.status(500).json({
        success: false,
        error: `Internal server error: ${error.message}`,
        version: VERSION,
        timestamp: new Date().toISOString(),
      });
    }
  }
);

/* ---------------------------------------------------
 ðŸŽ¯ UPDATE ACTIVITIES PREFERENCES ENDPOINT
--------------------------------------------------- */

exports.updateActivitiesPreferences = onRequest(
  { 
    timeoutSeconds: 30, 
    memory: "256MiB", 
    cors: true 
  },
  async (req, res) => {
    res.set("Access-Control-Allow-Origin", "*");
    res.set("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
    res.set("Access-Control-Allow-Headers", "Content-Type");

    if (req.method === "OPTIONS") {
      return res.status(204).send("");
    }

    try {
      const { userId, preferences } = req.body;
      
      if (!userId || !preferences) {
        return res.status(400).json({ 
          success: false, 
          error: "User ID and preferences are required", 
          version: VERSION 
        });
      }

      if (!validateEmail(userId)) {
        return res.status(400).json({ 
          success: false, 
          error: "Invalid user ID format", 
          version: VERSION 
        });
      }

      // Validate preferences structure
      if (typeof preferences !== 'object') {
        return res.status(400).json({ 
          success: false, 
          error: "Preferences must be an object", 
          version: VERSION 
        });
      }

      // Enhance preferences with metadata
      const enhancedPreferences = {
        ...preferences,
        userId: userId,
        lastUpdated: new Date().toISOString(),
        updatedBy: 'user',
        version: '1.0'
      };

      // Save to both databases
      const saveResults = await saveActivitiesPreferences(userId, enhancedPreferences);

      // Get updated preferences for response
      const updatedPreferences = await getActivitiesPreferences(userId);
      const userData = await getUserData(userId, { type: 'user_info', subType: 'all' });

      const response = {
        success: true,
        userInfo: userData?.userInfo || null,
        preferences: updatedPreferences.preferences,
        dataSource: updatedPreferences.dataSource,
        saveResults: saveResults,
        displayMessage: `âœ… Your activities preferences have been updated successfully!`,
        timestamp: new Date().toISOString(),
        version: VERSION,
      };

      return res.json(response);

    } catch (error) {
      console.error("ðŸ’¥ ERROR in updateActivitiesPreferences endpoint:", error);
      
      return res.status(500).json({
        success: false,
        error: `Internal server error: ${error.message}`,
        version: VERSION,
        timestamp: new Date().toISOString(),
      });
    }
  }
);

// Save preferences to both databases
async function saveActivitiesPreferences(userId, preferences) {
  const results = {
    firestore: false,
    realtimeDb: false,
    errors: []
  };

  // Save to Firestore
  try {
    if (firestore) {
      const userDocRef = firestore.collection('users').doc(userId);
      await userDocRef.set({
        activitiesPreferences: preferences,
        lastUpdated: new Date().toISOString()
      }, { merge: true });
      results.firestore = true;
      console.log("âœ… Preferences saved to Firestore");
    } else {
      results.errors.push("Firestore not initialized");
    }
  } catch (firestoreError) {
    results.errors.push(`Firestore: ${firestoreError.message}`);
    console.log("âŒ Could not save to Firestore:", firestoreError.message);
  }

  // Save to Realtime Database
  try {
    const normalizedKey = normalizeEmailForFirebase(userId);
    const preferencesRef = rtdb.ref(`Account/${normalizedKey}/activitiesPreferences`);
    await preferencesRef.set(preferences);
    results.realtimeDb = true;
    console.log("âœ… Preferences saved to Realtime Database");
  } catch (rtdbError) {
    results.errors.push(`Realtime DB: ${rtdbError.message}`);
    console.log("âŒ Could not save to Realtime Database:", rtdbError.message);
  }

  return results;
}

/* ---------------------------------------------------
 ðŸŽ¯ UPDATED USER STORY FUNCTIONS - HYBRID DATABASE
--------------------------------------------------- */

async function analyzeInteractionsPreferences(userId, userInfo, recentActivities) {
  try {
    // Try to get existing preferences from databases first
    const existingPreferences = await getActivitiesPreferences(userId);
    
    if (existingPreferences.success && existingPreferences.preferences && 
        Object.keys(existingPreferences.preferences).length > 0) {
      console.log("âœ… Using existing preferences from database");
      return {
        ...existingPreferences.preferences,
        dataSource: existingPreferences.dataSource,
        lastRetrieved: new Date().toISOString()
      };
    }
    
    // Fallback to analysis if no existing preferences
    const defaultPreferences = {
      topicsOfInterest: ['Health & Wellness', 'Daily Living'],
      activeTimes: ['Morning', 'Afternoon'],
      preferredCommunication: 'Friendly and Supportive',
      learningStyle: 'Visual and Simple',
      notificationPreferences: 'Gentle reminders',
      dataSource: 'analyzed_fallback'
    };
    
    if (recentActivities.length === 0) {
      return defaultPreferences;
    }
    
    const categoryCount = {};
    recentActivities.forEach(activity => {
      const category = activity.category || 'General';
      categoryCount[category] = (categoryCount[category] || 0) + 1;
    });
    
    const topCategories = Object.entries(categoryCount)
      .sort(([,a], [,b]) => b - a)
      .slice(0, 3)
      .map(([category]) => category);
    
    const enhancedPreferences = {
      topicsOfInterest: topCategories.length > 0 ? topCategories : defaultPreferences.topicsOfInterest,
      activeTimes: defaultPreferences.activeTimes,
      preferredCommunication: defaultPreferences.preferredCommunication,
      learningStyle: defaultPreferences.learningStyle,
      notificationPreferences: defaultPreferences.notificationPreferences,
      engagementLevel: recentActivities.length > 5 ? 'High' : 'Moderate',
      favoriteTopics: topCategories,
      totalActivities: recentActivities.length,
      lastActive: recentActivities.length > 0 ? 'Recently' : 'Not recently',
      dataSource: 'analyzed_from_activities'
    };
    
    return enhancedPreferences;
    
  } catch (error) {
    console.error("âŒ Error in analyzeInteractionsPreferences:", error);
    return {
      topicsOfInterest: ['Health & Wellness'],
      activeTimes: ['Morning', 'Afternoon'],
      preferredCommunication: 'Friendly',
      dataSource: 'error_fallback'
    };
  }
}

async function sendMedicalReminders(userId) {
  try {
    const medications = await getMedicationReminders(userId, 'today');
    const pendingMeds = medications.filter(med => !med.isCompleted);
    
    if (pendingMeds.length === 0) {
      return {
        sent: false,
        count: 0,
        message: 'No pending medications found',
        reminders: []
      };
    }
    
    const reminders = pendingMeds.map(med => ({
      medication: med.medicationName,
      time: med.reminderTime,
      dosage: med.dosage,
      quantity: med.quantity,
      notes: med.notes
    }));
    
    await storeMedicalReminders(userId, reminders);
    
    return {
      sent: true,
      count: pendingMeds.length,
      message: `You have ${pendingMeds.length} medication(s) to take today`,
      reminders: reminders
    };
    
  } catch (error) {
    return {
      sent: false,
      count: 0,
      message: 'Error checking medications',
      reminders: [],
      error: error.message
    };
  }
}

async function storeMedicalReminders(userId, reminders) {
  try {
    const remindersRef = rtdb.ref('medicalReminderLogs');
    const userRemindersRef = remindersRef.child(normalizeEmailForFirebase(userId));
    
    const reminderLog = {
      userId: userId,
      timestamp: new Date().toISOString(),
      reminders: reminders,
      sent: true,
      read: false
    };
    
    await userRemindersRef.push(reminderLog);
    
    // Also try to store in Firestore
    try {
      if (firestore) {
        const remindersCollection = firestore.collection('medicalReminders');
        await remindersCollection.add({
          userId: userId,
          ...reminderLog
        });
      }
    } catch (firestoreError) {
      console.log("âŒ Could not save to Firestore:", firestoreError.message);
    }
    
  } catch (error) {
    console.error("âŒ Error storing medical reminders:", error);
  }
}

async function detectUnusualPatterns(userId, currentActivity, historicalData) {
  try {
    const alerts = [];
    
    const userData = await getUserData(userId, { type: 'user_info', subType: 'all' });
    const recentActivities = await retrieveSelectedActivities(userId);
    const medications = await getMedicationReminders(userId, 'today');
    
    if (!userData) {
      return {
        detected: false,
        alerts: [],
        message: 'User not found'
      };
    }
    
    const totalMeds = medications.length;
    const completedMeds = medications.filter(med => med.isCompleted).length;
    const adherenceRate = totalMeds > 0 ? (completedMeds / totalMeds) * 100 : 100;
    
    if (adherenceRate < 50 && totalMeds > 0) {
      alerts.push({
        type: 'MEDICATION_ADHERENCE',
        severity: 'MEDIUM',
        message: `Low medication adherence detected (${Math.round(adherenceRate)}%)`,
        details: `Only ${completedMeds} out of ${totalMeds} medications taken today`,
        suggestion: 'Consider setting additional reminders or contacting caregiver'
      });
    }
    
    if (recentActivities.length === 0) {
      alerts.push({
        type: 'LOW_ENGAGEMENT',
        severity: 'LOW',
        message: 'Low engagement with learning resources',
        details: 'No recent learning activities detected',
        suggestion: 'Explore new learning resources to stay mentally active'
      });
    }
    
    const today = new Date();
    const dayOfWeek = today.getDay();
    
    if ([0, 6].includes(dayOfWeek)) {
      alerts.push({
        type: 'WEEKEND_PATTERN',
        severity: 'LOW',
        message: 'Weekend schedule detected',
        details: 'Remember to maintain your routine during weekends',
        suggestion: 'Try to stick to your usual medication and activity schedule'
      });
    }
    
    const missedMeds = medications.filter(med => {
      if (!med.reminderTime) return false;
      
      const medTime = new Date(`${med.date}T${med.reminderTime}`);
      const now = new Date();
      return !med.isCompleted && medTime < now;
    });
    
    if (missedMeds.length > 2) {
      alerts.push({
        type: 'MULTIPLE_MISSED_MEDS',
        severity: 'HIGH',
        message: `Multiple missed medications (${missedMeds.length})`,
        details: 'Several scheduled medications have been missed',
        suggestion: 'Contact caregiver or healthcare provider for assistance'
      });
    }
    
    return {
      detected: alerts.length > 0,
      alerts: alerts,
      summary: {
        totalAlerts: alerts.length,
        highPriority: alerts.filter(a => a.severity === 'HIGH').length,
        medicationAdherence: Math.round(adherenceRate),
        recentActivities: recentActivities.length,
        totalMedications: totalMeds
      },
      timestamp: new Date().toISOString()
    };
    
  } catch (error) {
    return {
      detected: false,
      alerts: [],
      error: error.message,
      timestamp: new Date().toISOString()
    };
  }
}

/* ---------------------------------------------------
 ðŸŽ¯ UPDATED USER STORY API ENDPOINTS
--------------------------------------------------- */

exports.getUserPreferences = onRequest(
  { timeoutSeconds: 30, memory: "256MiB", cors: true },
  async (req, res) => {
    res.set("Access-Control-Allow-Origin", "*");
    if (req.method === "OPTIONS") return res.status(204).send("");

    try {
      const { userId } = req.method === "POST" ? req.body : req.query;
      if (!userId) return res.status(400).json({ error: "User ID required", version: VERSION });

      const userData = await getUserData(userId, { type: 'user_info', subType: 'all' });
      if (!userData) {
        return res.status(404).json({ success: false, error: "User not found", version: VERSION });
      }

      const recentActivities = await retrieveSelectedActivities(userId);
      
      // Use hybrid approach for both general and activities preferences
      const generalPreferences = await analyzeInteractionsPreferences(userId, userData.userInfo, recentActivities);
      const activitiesPreferencesResult = await getActivitiesPreferences(userId);

      const combinedPreferences = {
        ...generalPreferences,
        activities: activitiesPreferencesResult.preferences,
        dataSources: {
          general: generalPreferences.dataSource,
          activities: activitiesPreferencesResult.dataSource
        }
      };

      res.json({
        success: true,
        userInfo: userData.userInfo,
        preferences: combinedPreferences,
        recentActivities: recentActivities,
        displayMessage: generatePreferencesResponse(userData.userInfo, combinedPreferences, recentActivities),
        activitiesMessage: generateActivitiesPreferencesResponse(userData.userInfo, activitiesPreferencesResult.preferences),
        timestamp: new Date().toISOString(),
        version: VERSION,
      });
    } catch (error) {
      console.error("âŒ Error in getUserPreferences:", error);
      res.status(500).json({
        success: false,
        error: "Internal server error",
        version: VERSION,
        timestamp: new Date().toISOString(),
      });
    }
  }
);

exports.triggerMedicalReminders = onRequest(
  { timeoutSeconds: 15, memory: "128MiB", cors: true },
  async (req, res) => {
    res.set("Access-Control-Allow-Origin", "*");
    if (req.method === "OPTIONS") return res.status(204).send("");

    try {
      const { userId } = req.method === "POST" ? req.body : req.query;
      if (!userId) return res.status(400).json({ error: "User ID required", version: VERSION });

      const result = await sendMedicalReminders(userId);

      res.json({
        success: true,
        reminders: result,
        displayMessage: generateMedicalReminderResponse(result),
        timestamp: new Date().toISOString(),
        version: VERSION,
      });
    } catch (error) {
      res.status(500).json({
        success: false,
        error: "Internal server error",
        version: VERSION,
        timestamp: new Date().toISOString(),
      });
    }
  }
);

exports.checkBehaviorPatterns = onRequest(
  { timeoutSeconds: 15, memory: "128MiB", cors: true },
  async (req, res) => {
    res.set("Access-Control-Allow-Origin", "*");
    if (req.method === "OPTIONS") return res.status(204).send("");

    try {
      const { userId } = req.method === "POST" ? req.body : req.query;
      if (!userId) return res.status(400).json({ error: "User ID required", version: VERSION });

      const result = await detectUnusualPatterns(userId, {}, {});

      res.json({
        success: true,
        patterns: result,
        displayMessage: generatePatternCheckResponse(result),
        timestamp: new Date().toISOString(),
        version: VERSION,
      });
    } catch (error) {
      res.status(500).json({
        success: false,
        error: "Internal server error",
        version: VERSION,
        timestamp: new Date().toISOString(),
      });
    }
  }
);

/* ---------------------------------------------------
 ðŸ‘¨â€âš•ï¸ UPDATED CAREGIVER API ENDPOINTS - HYBRID
--------------------------------------------------- */

exports.getCaregiverElderly = onRequest(
  { timeoutSeconds: 15, memory: "128MiB", cors: true },
  async (req, res) => {
    res.set("Access-Control-Allow-Origin", "*");
    if (req.method === "OPTIONS") return res.status(204).send("");

    try {
      const { userId } = req.method === "POST" ? req.body : req.query;
      if (!userId) return res.status(400).json({ error: "User ID required", version: VERSION });

      const elderlyData = await getCaregiverAssignedElderly(userId);
      
      if (!elderlyData.success) {
        return res.status(404).json({ 
          success: false, 
          error: elderlyData.error, 
          version: VERSION 
        });
      }

      res.json({
        success: true,
        caregiver: elderlyData.caregiver,
        elderly: elderlyData.elderly,
        totalElderly: elderlyData.totalElderly,
        displayMessage: generateCaregiverElderlyResponse(elderlyData.caregiver, elderlyData),
        timestamp: new Date().toISOString(),
        version: VERSION,
      });
    } catch (error) {
      res.status(500).json({
        success: false,
        error: "Internal server error",
        version: VERSION,
        timestamp: new Date().toISOString(),
      });
    }
  }
);

exports.getCaregiverSchedule = onRequest(
  { timeoutSeconds: 30, memory: "256MiB", cors: true },
  async (req, res) => {
    res.set("Access-Control-Allow-Origin", "*");
    if (req.method === "OPTIONS") return res.status(204).send("");

    try {
      const { userId, dateQuery = 'upcoming' } = req.method === "POST" ? req.body : req.query;
      
      if (!userId) {
        return res.status(400).json({ 
          error: "User ID required", 
          version: VERSION 
        });
      }

      if (!validateEmail(userId)) {
        return res.status(400).json({ 
          error: "Invalid user ID format", 
          version: VERSION 
        });
      }

      const [scheduleData, userData] = await Promise.all([
        fetchCaregiverSchedule(userId, dateQuery),
        getUserData(userId, { type: 'user_info', subType: 'all' })
      ]);
      
      if (!scheduleData.success) {
        return res.status(404).json({ 
          success: false, 
          error: scheduleData.error, 
          version: VERSION 
        });
      }

      const response = {
        success: true,
        userInfo: userData?.userInfo || null,
        schedule: scheduleData.schedule,
        caregiverConsultations: scheduleData.caregiverConsultations,
        elderlyAppointments: scheduleData.elderlyAppointments,
        summary: scheduleData.summary,
        displayMessage: generateEnhancedCaregiverScheduleResponse(
          userData?.userInfo || { name: 'Caregiver' }, 
          scheduleData
        ),
        timestamp: new Date().toISOString(),
        version: VERSION,
      };

      res.json(response);

    } catch (error) {
      console.error("Error in getCaregiverSchedule endpoint:", error);
      res.status(500).json({
        success: false,
        error: "Internal server error",
        version: VERSION,
        timestamp: new Date().toISOString(),
      });
    }
  }
);

exports.getCaregiverElderlyAppointments = onRequest(
  { timeoutSeconds: 30, memory: "256MiB", cors: true },
  async (req, res) => {
    // Set CORS headers
    res.set("Access-Control-Allow-Origin", "*");
    res.set("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
    res.set("Access-Control-Allow-Headers", "Content-Type");

    if (req.method === "OPTIONS") {
      return res.status(204).send("");
    }

    try {
      console.log("ðŸ“¨ Received request for caregiver elderly appointments");
      
      // Get parameters from both POST body and GET query
      const { userId } = req.method === "POST" ? req.body : req.query;
      
      console.log("ðŸ‘¤ User ID:", userId);

      if (!userId) {
        return res.status(400).json({ 
          success: false, 
          error: "User ID is required", 
          version: VERSION 
        });
      }

      if (!validateEmail(userId)) {
        return res.status(400).json({ 
          success: false, 
          error: "Invalid user ID format", 
          version: VERSION 
        });
      }

      // Use enhanced version
      const appointmentsData = await getElderlyAppointmentsForCaregiverEnhanced(userId);

      if (!appointmentsData.success) {
        return res.status(404).json({ 
          success: false, 
          error: appointmentsData.error, 
          version: VERSION 
        });
      }

      // Get caregiver info for response
      const userData = await getUserData(userId, { type: 'user_info', subType: 'all' });
      const caregiverInfo = userData?.userInfo || { name: 'Caregiver', email: userId };

      // Generate display message
      const displayMessage = generateElderlyAppointmentsNotification(caregiverInfo, appointmentsData);

      // Successful response
      const response = {
        success: true,
        userInfo: caregiverInfo,
        appointments: appointmentsData.appointments,
        totalAppointments: appointmentsData.totalAppointments,
        totalElderly: appointmentsData.totalElderly,
        elderlyList: appointmentsData.elderlyList || [],
        displayMessage: displayMessage,
        debug: appointmentsData.debug || {},
        timestamp: new Date().toISOString(),
        version: VERSION,
      };

      console.log(`âœ… Successfully returned ${appointmentsData.appointments.length} appointments`);
      return res.json(response);

    } catch (error) {
      console.error("ðŸ’¥ FINAL ERROR in endpoint:", error);
      
      return res.status(500).json({
        success: false,
        error: `Internal server error: ${error.message}`,
        version: VERSION,
        timestamp: new Date().toISOString(),
      });
    }
  }
);

function generateElderlyAppointmentsNotification(caregiverInfo, appointmentsData) {
  const isAllAppointments = appointmentsData.dateQuery === 'all';
  
  if (appointmentsData.totalAppointments === 0) {
    return `No ${isAllAppointments ? '' : 'upcoming '}appointments found for your elderly patients, ${caregiverInfo.name}.`;
  }

  let response = `${isAllAppointments ? 'All appointments' : 'Upcoming appointments'} for your elderly patients, ${caregiverInfo.name}:\n\n`;

  appointmentsData.appointments.forEach((apt, index) => {
    response += `${index + 1}. ${apt.elderlyName} - ${apt.title || apt.reason || 'Appointment'}\n`;
    response += `   Date: ${formatDisplayDate(apt.date || apt.appointmentDate)}\n`;
    if (apt.time) response += `   Time: ${formatDisplayTime(apt.time)}\n`;
    if (apt.location) response += `   Location: ${apt.location}\n`;
    if (apt.doctor || apt.provider) response += `   Provider: ${apt.doctor || apt.provider}\n`;
    response += `   Type: ${apt.appointmentType || apt.type}\n`;
    response += `\n`;
  });

  const timeContext = isAllAppointments ? 'appointments' : 'upcoming appointments';
  response += `Total: ${appointmentsData.totalAppointments} ${timeContext} across ${appointmentsData.totalElderly} elderly patients.`;

  return response;
}



/* ---------------------------------------------------
 ðŸ”„ AUTOMATIC DATABASE SYNCHRONIZATION
--------------------------------------------------- */

// Real-time sync from RTDB to Firestore (SAFE VERSION)
exports.syncRTDBtoFirestore = onValueWritten(
  {
    ref: '/{node}/{docId}',
    region: 'asia-southeast1',
    timeoutSeconds: 60,
  },
  async (event) => {
    const { node, docId } = event.params;
    const data = event.data.after.val();
    const syncKey = `firestore-${node}-${docId}`;
    
    // Skip if this was recently synced from Firestore
    if (recentSyncs.has(syncKey)) {
      recentSyncs.delete(syncKey);
      return null;
    }
    
    if (!data || node.startsWith('_') || docId.startsWith('_')) {
      return null;
    }
    
    try {
      if (data === null) {
        await firestore.collection(node).doc(docId).delete();
        console.log(`ðŸ—‘ï¸ RTDB â†’ Firestore: Deleted ${node}/${docId}`);
      } else {
        const serializedData = serializeData(data);
        // Mark as syncing to Firestore
        recentSyncs.add(`rtdb-${node}-${docId}`);
        setTimeout(() => recentSyncs.delete(`rtdb-${node}-${docId}`), SYNC_TIMEOUT);
        
        await firestore.collection(node).doc(docId).set(serializedData, { merge: true });
        console.log(`âœ… RTDB â†’ Firestore: Synced ${node}/${docId}`);
      }
    } catch (error) {
      console.error(`âŒ RTDB â†’ Firestore sync error for ${node}/${docId}:`, error);
    }
    
    return null;
  }
);

// Real-time sync from Firestore to RTDB (SAFE VERSION)
exports.syncFirestoreToRTDB = onDocumentWritten(
  {
    document: '{collection}/{docId}',
    region: 'asia-southeast1',
    timeoutSeconds: 60,
  },
  async (event) => {
    const { collection, docId } = event.params;
    const data = event.data.after.exists ? event.data.after.data() : null;
    const syncKey = `rtdb-${collection}-${docId}`;
    
    // Skip if this was recently synced from RTDB
    if (recentSyncs.has(syncKey)) {
      recentSyncs.delete(syncKey);
      return null;
    }
    
    if (collection.startsWith('_') || docId.startsWith('_')) {
      return null;
    }
    
    try {
      if (!data) {
        await rtdb.ref(`${collection}/${docId}`).remove();
        console.log(`ðŸ—‘ï¸ Firestore â†’ RTDB: Deleted ${collection}/${docId}`);
      } else {
        const serializedData = serializeData(data);
        // Mark as syncing to RTDB
        recentSyncs.add(`firestore-${collection}-${docId}`);
        setTimeout(() => recentSyncs.delete(`firestore-${collection}-${docId}`), SYNC_TIMEOUT);
        
        await rtdb.ref(`${collection}/${docId}`).set(serializedData);
        console.log(`âœ… Firestore â†’ RTDB: Synced ${collection}/${docId}`);
      }
    } catch (error) {
      console.error(`âŒ Firestore â†’ RTDB sync error for ${collection}/${docId}:`, error);
    }
    
    return null;
  }
);
// Enhanced serializer to handle complex data types
function serializeData(obj) {
  if (obj === null || obj === undefined) {
    return null;
  }
  
  if (Array.isArray(obj)) {
    return obj.map(item => serializeData(item));
  }
  
  if (typeof obj === 'object' && !(obj instanceof Date)) {
    if (obj._firestore) {
      // Skip Firestore objects
      return null;
    }
    
    const result = {};
    for (const [key, value] of Object.entries(obj)) {
      // Skip internal properties and Firestore metadata
      if (key.startsWith('_') || key === 'firestore') {
        continue;
      }
      
      const serializedValue = serializeData(value);
      if (serializedValue !== undefined) {
        result[key] = serializedValue;
      }
    }
    return result;
  }
  
  // Handle basic types
  if (typeof obj === 'string' || typeof obj === 'number' || typeof obj === 'boolean') {
    return obj;
  }
  
  if (obj instanceof Date) {
    return obj.toISOString();
  }
  
  return null;
}

// Batch sync function for initial setup
exports.initialSyncRTDBtoFirestore = functions.https.onRequest(async (req, res) => {
  try {
    const { node, limit = 100 } = req.body;
    
    if (!node) {
      return res.status(400).json({ error: 'Node parameter required' });
    }
    
    const snapshot = await rtdb.ref(node).limitToFirst(parseInt(limit)).get();
    
    if (!snapshot.exists()) {
      return res.json({ message: `No data found in ${node}`, synced: 0 });
    }
    
    const data = snapshot.val();
    let syncedCount = 0;
    
    for (const [docId, docData] of Object.entries(data)) {
      try {
        const serializedData = serializeData(docData);
        await firestore.collection(node).doc(docId).set(serializedData, { merge: true });
        syncedCount++;
        console.log(`âœ… Initial sync: ${node}/${docId}`);
      } catch (error) {
        console.error(`âŒ Initial sync error for ${node}/${docId}:`, error);
      }
    }
    
    res.json({ 
      success: true, 
      message: `Initial sync completed for ${node}`,
      synced: syncedCount,
      node: node
    });
    
  } catch (error) {
    console.error('âŒ Initial sync error:', error);
    res.status(500).json({ error: error.message });
  }
});

// Sync status checker
exports.getSyncStatus = functions.https.onRequest(async (req, res) => {
  try {
    const { node, docId } = req.query;
    
    let rtdbData = null;
    let firestoreData = null;
    
    // Get RTDB data
    if (node && docId) {
      const rtdbSnap = await rtdb.ref(`${node}/${docId}`).get();
      rtdbData = rtdbSnap.exists() ? rtdbSnap.val() : null;
    }
    
    // Get Firestore data
    if (node && docId) {
      const firestoreDoc = await firestore.collection(node).doc(docId).get();
      firestoreData = firestoreDoc.exists ? firestoreDoc.data() : null;
    }
    
    res.json({
      success: true,
      rtdb: rtdbData,
      firestore: firestoreData,
      inSync: JSON.stringify(rtdbData) === JSON.stringify(firestoreData),
      timestamp: new Date().toISOString()
    });
    
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

/* ---------------------------------------------------
 ðŸ©º HEALTH RECOMMENDATIONS FUNCTIONS
--------------------------------------------------- */

// Generate personalized health recommendations based on user data
async function generateHealthRecommendations(userId) {
  try {
    console.log("Generating health recommendations for:", userId);
    
    // Get comprehensive user data
    const [userData, medications, activities, learningData, schedule] = await Promise.all([
      getUserData(userId, { type: 'user_info', subType: 'all' }),
      getMedicationReminders(userId, 'today'),
      getActivitiesForSchedule(userId, 'today'),
      getUserLearningData(userId),
      getComprehensiveSchedule(userId, 'today')
    ]);

    if (!userData) {
      return {
        success: false,
        error: "User not found",
        recommendations: []
      };
    }

    const recommendations = [];
    const userInfo = userData.userInfo;
    const now = new Date();

    // 1. MEDICATION-BASED RECOMMENDATIONS
    const pendingMeds = medications.filter(med => !med.isCompleted);
    const upcomingMeds = medications.filter(med => {
      if (!med.reminderTime || med.isCompleted) return false;
      const medTime = new Date(`${med.date}T${med.reminderTime}`);
      return medTime > now && medTime < new Date(now.getTime() + 60 * 60 * 1000); // Next hour
    });

    if (pendingMeds.length > 0) {
      recommendations.push({
        type: 'medication_reminder',
        priority: 'high',
        title: 'Medication Reminder',
        message: `You have ${pendingMeds.length} medication${pendingMeds.length > 1 ? 's' : ''} to take today`,
        details: pendingMeds.map(med => `${med.medicationName} at ${formatDisplayTime(med.reminderTime)}`).join(', '),
        action: 'view_medications',
        timestamp: new Date().toISOString()
      });
    }

    // 2. ACTIVITY & EXERCISE RECOMMENDATIONS
    const hasActivityToday = activities.length > 0;
    const lastActivityTime = await getLastActivityTime(userId);
    
    if (!hasActivityToday && shouldRecommendActivity(lastActivityTime)) {
      recommendations.push({
        type: 'activity_suggestion',
        priority: 'medium',
        title: 'Daily Activity',
        message: 'Stay active today. Consider a gentle walk or light exercise',
        details: 'Regular activity helps maintain mobility and overall health',
        action: 'browse_activities',
        timestamp: new Date().toISOString()
      });
    }

    // 3. HYDRATION REMINDERS
    recommendations.push({
      type: 'hydration',
      priority: 'medium',
      title: 'Stay Hydrated',
      message: 'Remember to drink water regularly throughout the day',
      details: 'Aim for 6-8 glasses of water daily for optimal health',
      action: 'dismiss',
      timestamp: new Date().toISOString()
    });

    // 4. NUTRITION RECOMMENDATIONS
    const mealTimes = getMealTimes();
    const nextMeal = getNextMeal(mealTimes);
    
    if (nextMeal) {
      recommendations.push({
        type: 'nutrition',
        priority: 'medium',
        title: 'Healthy Eating',
        message: `Time for ${nextMeal.meal}. Consider a balanced option`,
        details: 'Include protein, vegetables, and whole grains for sustained energy',
        action: 'nutrition_tips',
        timestamp: new Date().toISOString()
      });
    }

    // 5. PERSONALIZED HEALTH TIPS BASED ON USER PROFILE
    if (userInfo.age && userInfo.age > 65) {
      recommendations.push({
        type: 'senior_health',
        priority: 'low',
        title: 'Senior Wellness',
        message: 'Consider balance exercises to prevent falls',
        details: 'Simple balance exercises can significantly reduce fall risk',
        action: 'learn_more',
        timestamp: new Date().toISOString()
      });
    }

    if (userInfo.medicalConditions && userInfo.medicalConditions.length > 0) {
      const conditions = userInfo.medicalConditions.join(', ').toLowerCase();
      
      if (conditions.includes('blood pressure') || conditions.includes('heart')) {
        recommendations.push({
          type: 'heart_health',
          priority: 'medium',
          title: 'Heart Health',
          message: 'Monitor your blood pressure regularly',
          details: 'Keep track of your readings and share with your doctor',
          action: 'learn_more',
          timestamp: new Date().toISOString()
        });
      }

      if (conditions.includes('diabetes') || conditions.includes('blood sugar')) {
        recommendations.push({
          type: 'diabetes_care',
          priority: 'medium',
          title: 'Diabetes Management',
          message: 'Check your blood sugar levels as recommended',
          details: 'Maintain consistent meal times and monitor carbohydrate intake',
          action: 'learn_more',
          timestamp: new Date().toISOString()
        });
      }
    }

    // 6. MENTAL HEALTH & WELLBEING
    const stressLevel = await assessStressLevel(userId, schedule);
    if (stressLevel === 'high') {
      recommendations.push({
        type: 'mental_health',
        priority: 'medium',
        title: 'Relaxation Time',
        message: 'Take a moment for deep breathing or meditation',
        details: 'Even 5 minutes of relaxation can reduce stress significantly',
        action: 'guided_breathing',
        timestamp: new Date().toISOString()
      });
    }

    // 7. SLEEP RECOMMENDATIONS (based on time of day)
    const sleepRecommendation = getSleepRecommendation();
    if (sleepRecommendation) {
      recommendations.push({
        type: 'sleep',
        priority: 'low',
        title: 'Sleep Wellness',
        message: sleepRecommendation.message,
        details: sleepRecommendation.details,
        action: 'sleep_tips',
        timestamp: new Date().toISOString()
      });
    }

    // Sort by priority and limit to top 5
    const priorityOrder = { high: 3, medium: 2, low: 1 };
    const sortedRecommendations = recommendations
      .sort((a, b) => priorityOrder[b.priority] - priorityOrder[a.priority])
      .slice(0, 5);

    return {
      success: true,
      userInfo: userInfo,
      recommendations: sortedRecommendations,
      total: sortedRecommendations.length,
      byPriority: {
        high: sortedRecommendations.filter(r => r.priority === 'high').length,
        medium: sortedRecommendations.filter(r => r.priority === 'medium').length,
        low: sortedRecommendations.filter(r => r.priority === 'low').length
      },
      timestamp: new Date().toISOString()
    };

  } catch (error) {
    console.error("Error generating health recommendations:", error);
    return {
      success: false,
      error: error.message,
      recommendations: []
    };
  }
}

// Helper function to get last activity time
async function getLastActivityTime(userId) {
  try {
    const activities = await retrieveSelectedActivities(userId);
    if (activities.length === 0) return null;
    
    // Find the most recent activity
    const recentActivity = activities.sort((a, b) => 
      new Date(b.accessedAt || b.date) - new Date(a.accessedAt || a.date)
    )[0];
    
    return recentActivity.accessedAt || recentActivity.date;
  } catch (error) {
    return null;
  }
}

// Determine if activity should be recommended
function shouldRecommendActivity(lastActivityTime) {
  if (!lastActivityTime) return true;
  
  const lastActivity = new Date(lastActivityTime);
  const today = new Date();
  const daysSinceLastActivity = Math.floor((today - lastActivity) / (1000 * 60 * 60 * 24));
  
  return daysSinceLastActivity >= 1; // Recommend if no activity in last 24 hours
}

// Assess stress level based on schedule density
function assessStressLevel(userId, schedule) {
  try {
    const totalEvents = schedule.allEvents.length;
    const now = new Date();
    const next4Hours = new Date(now.getTime() + 4 * 60 * 60 * 1000);
    
    const upcomingEvents = schedule.allEvents.filter(event => {
      const eventTime = new Date(getEventTimeRaw(event));
      return eventTime > now && eventTime < next4Hours;
    });

    if (upcomingEvents.length >= 3) return 'high';
    if (upcomingEvents.length >= 2) return 'medium';
    return 'low';
  } catch (error) {
    return 'low';
  }
}

// Get meal times
function getMealTimes() {
  const now = new Date();
  const currentHour = now.getHours();
  
  return {
    breakfast: currentHour < 11 && currentHour >= 7,
    lunch: currentHour >= 11 && currentHour < 14,
    dinner: currentHour >= 17 && currentHour < 20
  };
}

// Get next meal recommendation
function getNextMeal(mealTimes) {
  const now = new Date();
  const currentHour = now.getHours();
  
  if (currentHour < 11 && !mealTimes.breakfast) {
    return { meal: 'breakfast', time: 'morning' };
  } else if (currentHour < 14 && !mealTimes.lunch) {
    return { meal: 'lunch', time: 'midday' };
  } else if (currentHour < 20 && !mealTimes.dinner) {
    return { meal: 'dinner', time: 'evening' };
  }
  
  return null;
}

// Get sleep recommendations based on time of day
function getSleepRecommendation() {
  const now = new Date();
  const currentHour = now.getHours();
  
  if (currentHour >= 21 || currentHour < 6) {
    return {
      message: 'Wind down for restful sleep',
      details: 'Avoid screens before bed and create a relaxing bedtime routine'
    };
  } else if (currentHour === 14 || currentHour === 15) {
    return {
      message: 'Consider a short power nap',
      details: 'A 20-30 minute nap can boost energy without affecting nighttime sleep'
    };
  }
  
  return null;
}

// Generate specific recommendations based on medical conditions
function generateConditionSpecificRecommendations(medicalConditions) {
  const recommendations = [];
  
  medicalConditions.forEach(condition => {
    const lowerCondition = condition.toLowerCase();
    
    if (lowerCondition.includes('arthritis') || lowerCondition.includes('joint')) {
      recommendations.push({
        condition: 'Arthritis',
        recommendation: 'Try gentle range-of-motion exercises in the morning',
        tip: 'Apply warm compress to stiff joints before moving'
      });
    }
    
    if (lowerCondition.includes('blood pressure') || lowerCondition.includes('hypertension')) {
      recommendations.push({
        condition: 'Blood Pressure',
        recommendation: 'Limit sodium intake and monitor your readings',
        tip: 'Take medications at the same time each day'
      });
    }
    
    if (lowerCondition.includes('diabetes')) {
      recommendations.push({
        condition: 'Diabetes',
        recommendation: 'Check blood sugar before meals and monitor carbohydrate intake',
        tip: 'Keep fast-acting glucose nearby in case of low blood sugar'
      });
    }
    
    if (lowerCondition.includes('heart')) {
      recommendations.push({
        condition: 'Heart Health',
        recommendation: 'Take prescribed medications regularly and monitor for swelling',
        tip: 'Report any chest discomfort or shortness of breath immediately'
      });
    }
    
    if (lowerCondition.includes('osteoporosis') || lowerCondition.includes('bone')) {
      recommendations.push({
        condition: 'Bone Health',
        recommendation: 'Ensure adequate calcium and vitamin D intake',
        tip: 'Practice balance exercises to prevent falls'
      });
    }
  });
  
  return recommendations.slice(0, 3); // Return top 3
}

// Generate response message for health recommendations
function generateHealthRecommendationsResponse(userInfo, recommendationsData) {
  if (!recommendationsData.success || recommendationsData.recommendations.length === 0) {
    return `I don't have any specific health recommendations for you right now, ${userInfo.name}. Keep up with your regular health routines and stay active!`;
  }

  let response = `Health Recommendations for You, ${userInfo.name}\n\n`;
  
  recommendationsData.recommendations.forEach((rec, index) => {
    const priorityIcon = rec.priority === 'high' ? 'HIGH' : rec.priority === 'medium' ? 'MEDIUM' : 'LOW';
    
    response += `${index + 1}. [${priorityIcon}] ${rec.title}\n`;
    response += `   ${rec.message}\n`;
    if (rec.details) {
      response += `   Note: ${rec.details}\n`;
    }
    response += `\n`;
  });

  response += `Total Recommendations: ${recommendationsData.recommendations.length} `;
  response += `(High: ${recommendationsData.byPriority.high}, Medium: ${recommendationsData.byPriority.medium}, Low: ${recommendationsData.byPriority.low})`;

  return response;
}

// Generate health tips by category
function generateHealthTipsByCategory(category, userId) {
  const allTips = {
    general: [
      "Stay hydrated by drinking water throughout the day",
      "Aim for 7-8 hours of quality sleep each night",
      "Include fruits and vegetables in every meal",
      "Take short walks after meals to aid digestion",
      "Practice deep breathing exercises to reduce stress",
      "Eat fresh fruits and vegetables daily",
      "Include fiber-rich foods such as oats and whole grains",
      "Drink plenty of water throughout the day",
      "Limit salt, sugar, and fried foods",
      "Have calcium-rich foods like milk, tofu, and leafy greens",
      "Eat lean proteins like fish, eggs, and beans",
      "Avoid skipping meals - maintain a regular eating schedule"
    ],
    exercise: [
      "Start with 10-15 minutes of light activity daily",
      "Focus on balance exercises to prevent falls",
      "Try chair exercises if standing is difficult",
      "Walk in place during TV commercials",
      "Stretch gently every morning and evening"
    ],
    nutrition: [
      "Eat fresh fruits and vegetables daily",
      "Include fiber-rich foods such as oats and whole grains",
      "Drink plenty of water throughout the day",
      "Limit salt, sugar, and fried foods",
      "Have calcium-rich foods like milk, tofu, and leafy greens",
      "Eat lean proteins like fish, eggs, and beans",
      "Avoid skipping meals - maintain a regular eating schedule",
      "Choose whole grains over refined carbohydrates",
      "Include lean protein with each meal",
      "Limit processed foods and added sugars",
      "Eat slowly and mindfully",
      "Stay consistent with meal times"
    ],
    medication: [
      "Use a pill organizer to stay organized",
      "Set reminders for medication times",
      "Keep a current medication list with you",
      "Take medications with food if required",
      "Don't skip doses - set up refill reminders"
    ],
    mental_health: [
      "Stay connected with friends and family",
      "Practice gratitude daily",
      "Try meditation or mindfulness",
      "Engage in hobbies you enjoy",
      "Get sunlight exposure when possible"
    ]
  };

  const selectedCategory = category && allTips[category.toLowerCase()] ? category.toLowerCase() : 'general';
  return allTips[selectedCategory].slice(0, 7); // Return top 7 tips
}

// Generate response for health tips
function generateHealthTipsResponse(tips, category, userInfo) {
  const categoryDisplay = category ? category.replace('_', ' ').toLowerCase() : 'general health';
  const userName = userInfo?.name ? `, ${userInfo.name}` : '';
  
  let response = `${categoryDisplay.charAt(0).toUpperCase() + categoryDisplay.slice(1)} Tips${userName}\n\n`;
  
  tips.forEach((tip, index) => {
    response += `${index + 1}. ${tip}\n`;
  });
  
  response += `\nRemember: Small, consistent changes lead to big health benefits!`;
  
  return response;
}
/* ---------------------------------------------------
 ðŸ©º HEALTH RECOMMENDATIONS API ENDPOINTS
--------------------------------------------------- */

exports.getHealthRecommendations = onRequest(
  { 
    timeoutSeconds: 120, 
    memory: "256MiB", 
    cors: true 
  },
  async (req, res) => {
    res.set("Access-Control-Allow-Origin", "*");
    res.set("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
    res.set("Access-Control-Allow-Headers", "Content-Type");

    if (req.method === "OPTIONS") {
      return res.status(204).send("");
    }

    try {
      const { userId } = req.method === "POST" ? req.body : req.query;
      
      if (!userId) {
        return res.status(400).json({ 
          success: false, 
          error: "User ID is required", 
          version: VERSION 
        });
      }

      if (!validateEmail(userId)) {
        return res.status(400).json({ 
          success: false, 
          error: "Invalid user ID format", 
          version: VERSION 
        });
      }

      // Generate health recommendations
      const recommendations = await generateHealthRecommendations(userId);
      
      // Get user data for response
      const userData = await getUserData(userId, { type: 'user_info', subType: 'all' });
      
      if (!userData) {
        return res.status(404).json({ 
          success: false, 
          error: "User not found", 
          version: VERSION 
        });
      }

      // Generate condition-specific recommendations
      const conditionRecommendations = userData.userInfo.medicalConditions && 
        userData.userInfo.medicalConditions.length > 0 
          ? generateConditionSpecificRecommendations(userData.userInfo.medicalConditions)
          : [];

      const response = {
        success: recommendations.success,
        userInfo: userData.userInfo,
        recommendations: recommendations.recommendations,
        conditionRecommendations: conditionRecommendations,
        displayMessage: generateHealthRecommendationsResponse(userData.userInfo, recommendations),
        summary: {
          total: recommendations.recommendations.length,
          byPriority: recommendations.byPriority,
          byType: countRecommendationsByType(recommendations.recommendations)
        },
        timestamp: new Date().toISOString(),
        version: VERSION,
      };

      if (recommendations.error) {
        response.error = recommendations.error;
      }

      return res.json(response);

    } catch (error) {
      console.error("ERROR in getHealthRecommendations:", error);
      
      return res.status(500).json({
        success: false,
        error: `Internal server error: ${error.message}`,
        version: VERSION,
        timestamp: new Date().toISOString(),
      });
    }
  }
);

// Get specific health tips based on category
exports.getHealthTips = onRequest(
  { 
    timeoutSeconds: 120, 
    memory: "128MiB", 
    cors: true 
  },
  async (req, res) => {
    res.set("Access-Control-Allow-Origin", "*");
    if (req.method === "OPTIONS") return res.status(204).send("");

    try {
      const { category, userId } = req.method === "POST" ? req.body : req.query;
      
      const healthTips = generateHealthTipsByCategory(category, userId);
      
      let userInfo = null;
      if (userId) {
        const userData = await getUserData(userId, { type: 'user_info', subType: 'all' });
        userInfo = userData?.userInfo;
      }

      res.json({
        success: true,
        userInfo: userInfo,
        category: category || 'general',
        tips: healthTips,
        displayMessage: generateHealthTipsResponse(healthTips, category, userInfo),
        timestamp: new Date().toISOString(),
        version: VERSION,
      });
    } catch (error) {
      res.status(500).json({
        success: false,
        error: "Internal server error",
        version: VERSION,
        timestamp: new Date().toISOString(),
      });
    }
  }
);

// Count recommendations by type
function countRecommendationsByType(recommendations) {
  const counts = {};
  recommendations.forEach(rec => {
    counts[rec.type] = (counts[rec.type] || 0) + 1;
  });
  return counts;
}


