const admin = require('firebase-admin');

// Initialize Firebase Admin SDK
const serviceAccount = require('../functions/serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL: 'https://elderly-aiassistant-default-rtdb.asia-southeast1.firebasedatabase.app'
});

const db = admin.database();

// Mapping of email to UID
const emailToUidMap = {
  // Elderly users
  'elderlyone@gmail.com': 'VuCi0D8TEUh7slr4DGxQg3eVnB02',
  'elderlytwo@gmail.com': 'yx1fAQSPQIgn9Cvnb7t6hXePVa02',
  'elderly3@gmail.com': 'Ck75GhY7hoUdeJJgtwpADcQyHmB3',
  'elderly4@gmail.com': 'OVExOULS9jfhDhzAZ6oBcGqR2Bz1',
  'elderlyfive@gmail.com': 'MES0FsBUYMb7BuDyc6QLY5XemEB3',
  'serene@hotmail.com': 'oxIcrL7U5zcCPCS0sSZc5SdIPrl1',
  'misty@hotmail.com': 'OA4XBDJL7rX5B6GYY9qLFvMWHQp1',
  'helloworld3@gmail.com': '33gq0s09D7b9AI6rnXZVdTKyaV52',
  'jiegoh@gmail.com': 'SESNLapWAvPrXFb831YYWX7mvUo1',
  'himay@gmail.com': '2bixGIJ3EaddvjtpaFd4oz4NFjA3',
  'catoh@gmail.com': 'arxvZUTAPZhQYwr4V4JKHwpt47X2',
  'gransgoh@gmail.com': 'n8ufkrBRtJSoYqEciJHSIcTipFI3',
  'mxgoh007@gmail.com': 'iShF4B7XVFTQMQIGlJLw4O9ASRD2',
  'reggoh@gmail.com': 'yCpzBPVmfmNy9Acdac0Iveb4V6k1',
  'brock@hotmail.com': '44Sr62La3TSNKe83G0i2WR7enw43',

  // Caregiver users
  'caregiver1@gmail.com': 'sw3DqPHrWkeUUv7l7ZiTTXINOl93',
  'caregiver2@gmail.com': '5SrUzl0dnUe3atAZ8M3JTLhvBur2',
  'caregiver3@gmail.com': 'EABtRs3ybaQx5xqNW6008333HgI2',
  'bobmarley1@gmail.com': 'bobmarley1@gmail_com',
  'brocklee@hotmail.com': 'KF0XEYdO8iYiscumCZYWCaii4CA3',
  'reginacarer@gmail.com': 'DEQhruyN11fVppjKFSARSXLP8pX2',
  'testmay@gmail.com': '9PEgaAKvSDRFXun83z2YW8zojKz2',
  'testingcaregiver1@gmail.com': 'juemMZyyv5WgJdL3W5RYxuP9L912',
  'testunreg@gmail.com': 'v7uX1tTHXUSXwBiVIy0eNfaxNi03',
  'johndoe@gmail.com': 'johndoe@gmail_com'
};

// Helper functions
function makeFirebaseSafeKey(key) {
  return key.replace(/\./g, '_');
}
function normalizeEmailKey(emailKey) {
  return emailKey.replace(/_/g, '.');
}
function convertEmailToUid(email) {
  return emailToUidMap[email] || email;
}

// ----------------------------- FIX ACCOUNTS -----------------------------
async function fixAccounts() {
  console.log('🔧 Fixing Accounts...');

  const accountsRef = db.ref('Account');
  const snapshot = await accountsRef.once('value');
  const accounts = snapshot.val();

  if (!accounts) {
    console.log('ℹ️ No accounts found');
    return;
  }

  const updates = {};

  Object.entries(accounts).forEach(([key, account]) => {
    const accountUpdates = {};

    if (account.elderlyId && emailToUidMap[account.elderlyId]) {
      accountUpdates.elderlyId = convertEmailToUid(account.elderlyId);
    }

    if (account.elderlyIds && Array.isArray(account.elderlyIds)) {
      accountUpdates.elderlyIds = account.elderlyIds.map(email => convertEmailToUid(email));
    }

    if (account.uidOfElder && emailToUidMap[account.uidOfElder]) {
      accountUpdates.elderlyId = convertEmailToUid(account.uidOfElder);
    }

    if (account.linkedElders && Array.isArray(account.linkedElders)) {
      accountUpdates.linkedElders = account.linkedElders.map(email => convertEmailToUid(email));
    }

    if (account.linkedCaregivers && Array.isArray(account.linkedCaregivers)) {
      accountUpdates.linkedCaregivers = account.linkedCaregivers.map(email => convertEmailToUid(email));
    }

    Object.entries(accountUpdates).forEach(([field, value]) => {
      updates[`Account/${key}/${field}`] = value;
    });
  });

  if (Object.keys(updates).length > 0) {
    await db.ref().update(updates);
    console.log(`✅ Updated ${Object.keys(updates).length} account fields`);
  } else {
    console.log('ℹ️ No account updates needed');
  }
}

// ----------------------------- FIX APPOINTMENTS -----------------------------
async function fixAppointments() {
  console.log('🔧 Fixing Appointments...');

  const appointmentsRef = db.ref('Appointments');
  const snapshot = await appointmentsRef.once('value');
  const appointments = snapshot.val();

  if (!appointments) {
    console.log('ℹ️ No appointments found');
    return;
  }

  const updates = {};

  Object.entries(appointments).forEach(([key, appointment]) => {
    const appointmentUpdates = {};

    if (appointment.elderlyId) {
      if (Array.isArray(appointment.elderlyId)) {
        appointmentUpdates.elderlyId = appointment.elderlyId.map(email => convertEmailToUid(email));
      } else {
        appointmentUpdates.elderlyId = convertEmailToUid(appointment.elderlyId);
      }
    }

    if (appointment.assignedTo && emailToUidMap[appointment.assignedTo]) {
      appointmentUpdates.assignedTo = convertEmailToUid(appointment.assignedTo);
    }

    Object.entries(appointmentUpdates).forEach(([field, value]) => {
      updates[`Appointments/${key}/${field}`] = value;
    });
  });

  if (Object.keys(updates).length > 0) {
    await db.ref().update(updates);
    console.log(`✅ Updated ${Object.keys(updates).length} appointment fields`);
  } else {
    console.log('ℹ️ No appointment updates needed');
  }
}

// ----------------------------- FIX ASSIGNED ROUTINES -----------------------------
async function fixAssignedRoutines() {
  console.log('🔧 Fixing AssignedRoutines...');

  const routinesRef = db.ref('AssignedRoutines');
  const snapshot = await routinesRef.once('value');
  const routines = snapshot.val();

  if (!routines) {
    console.log('ℹ️ No assigned routines found');
    return;
  }

  const updates = {};
  const deletions = [];

  Object.entries(routines).forEach(([emailKey, routineGroup]) => {
    const normalizedEmail = normalizeEmailKey(emailKey);
    const uidKey = convertEmailToUid(normalizedEmail);
    const safeUidKey = makeFirebaseSafeKey(uidKey);

    Object.entries(routineGroup).forEach(([routineId, routine]) => {
      const routineUpdates = {};

      if (routine.elderlyId && emailToUidMap[routine.elderlyId]) {
        routineUpdates.elderlyId = convertEmailToUid(routine.elderlyId);
      }

      if (safeUidKey !== emailKey) {
        updates[`AssignedRoutines/${safeUidKey}/${routineId}`] = { ...routine, ...routineUpdates };
        deletions.push(`AssignedRoutines/${emailKey}/${routineId}`);
      } else {
        Object.entries(routineUpdates).forEach(([field, value]) => {
          updates[`AssignedRoutines/${emailKey}/${routineId}/${field}`] = value;
        });
      }
    });
  });

  if (Object.keys(updates).length > 0) {
    await db.ref().update(updates);
    console.log(`✅ Updated ${Object.keys(updates).length} routine fields`);
  }

  for (const delPath of deletions) {
    await db.ref(delPath).remove();
  }

  if (deletions.length > 0) console.log(`🗑️ Deleted ${deletions.length} old routine paths`);
}

// ----------------------------- FIX CARE ROUTINE TEMPLATES -----------------------------
async function fixCareRoutineTemplates() {
  console.log('🔧 Fixing Care Routine Templates...');

  const templatesRef = db.ref('careRoutineTemplateEntity');
  const snapshot = await templatesRef.once('value');
  const templates = snapshot.val();

  if (!templates) {
    console.log('ℹ️ No templates found');
    return;
  }

  const updates = {};

  Object.entries(templates).forEach(([key, template]) => {
    if (template.createdBy && emailToUidMap[template.createdBy]) {
      updates[`careRoutineTemplateEntity/${key}/createdBy`] = convertEmailToUid(template.createdBy);
    }
  });

  if (Object.keys(updates).length > 0) {
    await db.ref().update(updates);
    console.log(`✅ Updated ${Object.keys(updates).length} template fields`);
  } else {
    console.log('ℹ️ No template updates needed');
  }
}

// ----------------------------- FIX CONSULTATIONS -----------------------------
async function fixConsultations() {
  console.log('🔧 Fixing Consultations...');

  const consultationsRef = db.ref('consultations');
  const snapshot = await consultationsRef.once('value');
  const consultations = snapshot.val();

  if (!consultations) {
    console.log('ℹ️ No consultations found');
    return;
  }

  const updates = {};

  Object.entries(consultations).forEach(([key, consultation]) => {
    const consultationUpdates = {};

    if (consultation.elderlyEmail && emailToUidMap[consultation.elderlyEmail]) {
      consultationUpdates.elderlyId = convertEmailToUid(consultation.elderlyEmail);
    }

    if (consultation.patientUid && emailToUidMap[consultation.patientUid]) {
      consultationUpdates.patientUid = convertEmailToUid(consultation.patientUid);
    }

    if (consultation.invitedCaregivers) {
      const fixedCaregivers = {};
      Object.entries(consultation.invitedCaregivers).forEach(([emailKey, caregiver]) => {
        const normalizedEmail = emailKey.replace(/_dot_/g, '.');
        const uidKey = convertEmailToUid(normalizedEmail);
        const safeUidKey = makeFirebaseSafeKey(uidKey);
        const caregiverUpdates = { ...caregiver };

        if (caregiver.caregiverEmail && emailToUidMap[caregiver.caregiverEmail]) {
          caregiverUpdates.caregiverId = convertEmailToUid(caregiver.caregiverEmail);
        }

        if (caregiver.elderlyEmail && emailToUidMap[caregiver.elderlyEmail]) {
          caregiverUpdates.elderlyId = convertEmailToUid(caregiver.elderlyEmail);
        }

        fixedCaregivers[safeUidKey] = caregiverUpdates;
      });
      consultationUpdates.invitedCaregivers = fixedCaregivers;
    }

    Object.entries(consultationUpdates).forEach(([field, value]) => {
      updates[`consultations/${key}/${field}`] = value;
    });
  });

  if (Object.keys(updates).length > 0) {
    await db.ref().update(updates);
    console.log(`✅ Updated ${Object.keys(updates).length} consultation fields`);
  } else {
    console.log('ℹ️ No consultation updates needed');
  }
}

// ----------------------------- FIX CONSULTATION INVITATIONS -----------------------------
async function fixConsultationInvitations() {
  console.log('🔧 Fixing Consultation Invitations...');

  const invitationsRef = db.ref('consultationInvitations');
  const snapshot = await invitationsRef.once('value');
  const invitations = snapshot.val();

  if (!invitations) {
    console.log('ℹ️ No invitations found');
    return;
  }

  const updates = {};

  Object.entries(invitations).forEach(([key, invitation]) => {
    if (invitation.elderlyEmail && emailToUidMap[invitation.elderlyEmail]) {
      updates[`consultationInvitations/${key}/elderlyId`] = convertEmailToUid(invitation.elderlyEmail);
    }

    if (invitation.caregiverEmail && emailToUidMap[invitation.caregiverEmail]) {
      updates[`consultationInvitations/${key}/caregiverId`] = convertEmailToUid(invitation.caregiverEmail);
    }
  });

  if (Object.keys(updates).length > 0) {
    await db.ref().update(updates);
    console.log(`✅ Updated ${Object.keys(updates).length} invitation fields`);
  } else {
    console.log('ℹ️ No invitation updates needed');
  }
}

// ----------------------------- MAIN FUNCTION -----------------------------
async function main() {
  try {
    console.log('🚀 Starting Firebase elderlyId migration...\n');

    await fixAccounts();
    await fixAppointments();
    await fixAssignedRoutines();
    await fixCareRoutineTemplates();
    await fixConsultations();
    await fixConsultationInvitations();

    console.log('\n🎉 Migration completed successfully!');
  } catch (error) {
    console.error('❌ Migration failed:', error);
    console.error('Error details:', error.message);
  } finally {
    admin.app().delete();
  }
}

main();
