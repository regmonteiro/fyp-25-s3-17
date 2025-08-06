import { ref, get } from "firebase/database";
import { database } from "../firebaseConfig";

function isInRange(dateStr, start, end) {
  if (!dateStr) return false;
  const date = new Date(dateStr);

  const startDate = new Date(start);
  startDate.setHours(0, 0, 0, 0);

  const endDate = new Date(end);
  endDate.setHours(23, 59, 59, 999);

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

      let loginCount = filteredLogs.length;
      let lastActiveDate = "N/A";

      if (loginCount > 0) {
        lastActiveDate = filteredLogs[filteredLogs.length - 1].date;
      } else if (isInRange(user.lastLoginDate, startDate, endDate)) {
        loginCount = 1;
        lastActiveDate = user.lastLoginDate;
      }

      console.log(`User ${id}: loginCount=${loginCount}, lastActiveDate=${lastActiveDate}`);

      reports.push({
        id,
        email: user.email || "N/A",
        userType: user.userType || "N/A",
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
      const type = user.userType || "unknown";
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
