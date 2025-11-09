import { ref, get } from "firebase/database";
import { database } from "../firebaseConfig";

function isInRange(dateStr, start, end) {
  if (!dateStr) return false;
  const date = new Date(dateStr);

  // Always treat start/end as UTC
  const startDate = new Date(start + "T00:00:00.000Z");
  const endDate = new Date(end + "T23:59:59.999Z");

  return date >= startDate && date <= endDate;
}

export async function generateUsageReport(startDate, endDate) {
  try {
    const accountsRef = ref(database, "Account");
    const snapshot = await get(accountsRef);

    if (!snapshot.exists()) return [];

    const data = snapshot.val();
    const reports = [];

    Object.entries(data).forEach(([id, user]) => {
      const logs = user.loginLogs ? Object.values(user.loginLogs) : [];

      // Filter logs in range
      const filteredLogs = logs.filter((log) => isInRange(log.date, startDate, endDate));

      // Sort filtered logs by date ascending
      filteredLogs.sort((a, b) => new Date(a.date) - new Date(b.date));

      const loginCount = filteredLogs.length;
      let lastActiveDate = "N/A";

      if (loginCount > 0) {
        lastActiveDate = filteredLogs[filteredLogs.length - 1].date;
      } else if (user.lastLoginDate) {
        lastActiveDate = user.lastLoginDate;
      }

      // Skip users with no email, no login activity, or unknown type
      if (!user.email || lastActiveDate === "N/A" || !user.userType || user.userType === "unknown") return;

      reports.push({
        id,
        email: user.email,
        userType: user.userType,
        loginCount,
        lastActiveDate,
      });
    });

    return reports;
  } catch (err) {
    console.error("Error generating report:", err);
    return [];
  }
}

export async function getAllUserTypeDistribution() {
  try {
    const accountsRef = ref(database, "Account");
    const snapshot = await get(accountsRef);

    if (!snapshot.exists()) return [];

    const data = snapshot.val();
    const counts = {};

    Object.values(data).forEach((user) => {
      // Skip unknown users or users without email
      if (!user.email || !user.userType || user.userType === "unknown") return;

      const type = user.userType;
      counts[type] = (counts[type] || 0) + 1;
    });

    return Object.entries(counts).map(([type, count]) => ({
      name: type,
      value: count,
    }));
  } catch (err) {
    console.error("Error fetching user type distribution:", err);
    return [];
  }
}
