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

export async function getGroupedUserReport(startDate, endDate) {
  try {
    const accountsRef = ref(database, "Account");
    const snapshot = await get(accountsRef);
    if (!snapshot.exists()) return {};

    const data = snapshot.val();
    const groups = {
      admin: [],
      caregiver: [],
      elderly: [],
      unknown: [],
    };

    Object.entries(data).forEach(([id, user]) => {
      const userType = user.userType || "unknown";

      // Gather logs in range
      const logs = user.loginLogs ? Object.values(user.loginLogs) : [];
      const filteredLogs = logs.filter((log) => isInRange(log.date, startDate, endDate));
      filteredLogs.sort((a, b) => new Date(a.date) - new Date(b.date));

      let loginCount = filteredLogs.length;
      let lastActiveDate = null;

      if (loginCount > 0) {
        lastActiveDate = filteredLogs[filteredLogs.length - 1].date;
      } else if (isInRange(user.lastLoginDate, startDate, endDate)) {
        loginCount = 1;
        lastActiveDate = user.lastLoginDate;
      }

      groups[userType] = groups[userType] || [];
      groups[userType].push({
        email: user.email || "N/A",
        loginCount,
        lastActiveDate: lastActiveDate ? new Date(lastActiveDate) : null,
      });
    });

    // Sort each group by lastActiveDate descending (most recent first)
    Object.keys(groups).forEach((key) => {
      groups[key].sort((a, b) => {
        if (!a.lastActiveDate && !b.lastActiveDate) return 0;
        if (!a.lastActiveDate) return 1;
        if (!b.lastActiveDate) return -1;
        return b.lastActiveDate - a.lastActiveDate;
      });
    });

    return groups;
  } catch (error) {
    console.error("Error fetching grouped user report:", error);
    return {};
  }
}
