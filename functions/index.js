const functions = require("firebase-functions/v2");
const admin = require("firebase-admin");
admin.initializeApp();

// Send notification to caregivers (keep this the same)
exports.sendCaregiverNotification = functions.https.onCall(async (data) => {
  try {
    if (!data.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "User must be authenticated"
      );
    }

    const { tokens, title, body, notificationData } = data;

    if (!tokens || tokens.length === 0) {
      console.log("No tokens provided");
      return { success: true, sent: 0 };
    }

    const message = {
      notification: {
        title: title,
        body: body,
      },
      data: notificationData || {},
      tokens: tokens,
    };

    const response = await admin.messaging().sendEachForMulticast(message);

    console.log(`Successfully sent ${response.successCount} notifications`);
    console.log(`Failed to send ${response.failureCount} notifications`);

    return {
      success: true,
      sent: response.successCount,
      failed: response.failureCount,
    };
  } catch (error) {
    console.error("Error sending notification:", error);
    throw new functions.https.HttpsError("internal", error.message);
  }
});

// Check for missed medications every 5 minutes (v2 syntax)
exports.checkMissedMedications = functions.scheduler.onSchedule(
  "every 5 minutes",
  async (event) => {
    console.log("🔍 Checking for missed medications...");

    try {
      const db = admin.firestore();
      const now = new Date();
      const todayStr = formatDate(now);

      const patientGroupsSnapshot = await db.collection("patientGroups").get();

      let totalChecked = 0;
      let totalNotificationsSent = 0;

      for (const groupDoc of patientGroupsSnapshot.docs) {
        const patientGroupID = groupDoc.id;
        const patientGroupData = groupDoc.data();
        const patientUid = patientGroupData.patient_uid;

        const patientDoc = await db.collection("users").doc(patientUid).get();
        const patientName = patientDoc.exists
          ? patientDoc.data().fullName || "Patient"
          : "Patient";

        const tabletsSnapshot = await db
          .collection("patientGroups")
          .doc(patientGroupID)
          .collection("tablets")
          .get();

        for (const tabletDoc of tabletsSnapshot.docs) {
          const tabletData = tabletDoc.data();
          const schedule = tabletData.schedule;
          const medication = tabletData.medication;
          const caregiverSettings = tabletData.caregiverSettings;

          if (
            !schedule ||
            !medication ||
            !caregiverSettings ||
            caregiverSettings.notifyCaregivers !== true
          ) {
            continue;
          }

          const daysOfWeek = schedule.daysOfWeek || [];
          const currentDay = getDayAbbreviation(now.getDay());

          if (!daysOfWeek.includes("All") && !daysOfWeek.includes(currentDay)) {
            continue;
          }

          const times = schedule.times || [];
          const lateWindowStr = caregiverSettings.lateWindow;
          const lateWindowMinutes = parseLateWindow(lateWindowStr);

          if (!lateWindowMinutes) continue;

          for (const scheduledTime of times) {
            totalChecked++;

            const scheduledDateTime = parseScheduledTime(scheduledTime, now);
            if (!scheduledDateTime) continue;

            const lateWindowExpiry = new Date(
              scheduledDateTime.getTime() + lateWindowMinutes * 60000
            );

            if (now <= lateWindowExpiry) continue;

            const logId = `${tabletDoc.id}_${todayStr}_${scheduledTime.replace(/:/g, "-").replace(/ /g, "_")}`;
            const logDoc = await db
              .collection("patientGroups")
              .doc(patientGroupID)
              .collection("medicationLogs")
              .doc(logId)
              .get();

            if (logDoc.exists) continue;

            console.log(
              `❌ MISSED: ${medication.name} at ${scheduledTime} for patient ${patientName}`
            );

            await db
              .collection("patientGroups")
              .doc(patientGroupID)
              .collection("medicationLogs")
              .doc(logId)
              .set({
                tabletId: tabletDoc.id,
                medicationName: medication.name,
                scheduledTime: scheduledTime,
                date: todayStr,
                status: "missed",
                createdAt: admin.firestore.FieldValue.serverTimestamp(),
              });

            const tokens = await getCaregiverTokens(
              db,
              patientGroupID,
              patientUid
            );

            if (tokens.length > 0) {
              const message = {
                notification: {
                  title: "Medication Missed",
                  body: `${patientName} missed ${medication.name} (scheduled for ${scheduledTime})`,
                },
                data: {
                  type: "medication_missed",
                  medicationName: medication.name,
                  scheduledTime: scheduledTime,
                },
                tokens: tokens,
              };

              const response = await admin
                .messaging()
                .sendEachForMulticast(message);
              totalNotificationsSent += response.successCount;

              console.log(
                `✅ Sent missed notification to ${response.successCount} caregivers`
              );
            }
          }
        }
      }

      console.log(
        `✅ Checked ${totalChecked} medications, sent ${totalNotificationsSent} notifications`
      );
      return null;
    } catch (error) {
      console.error("❌ Error checking missed medications:", error);
      return null;
    }
  }
);

// Helper functions
function formatDate(date) {
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, "0");
  const day = String(date.getDate()).padStart(2, "0");
  return `${year}-${month}-${day}`;
}

function getDayAbbreviation(dayIndex) {
  const days = ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"];
  return days[dayIndex];
}

function parseLateWindow(lateWindowStr) {
  if (!lateWindowStr) return null;
  const match = lateWindowStr.match(/\d+/);
  return match ? parseInt(match[0]) : null;
}

function parseScheduledTime(timeStr, referenceDate) {
  try {
    const parts = timeStr.split(" ");
    const timeParts = parts[0].split(":");
    let hour = parseInt(timeParts[0]);
    const minute = parseInt(timeParts[1]);
    const isPM = parts[1] === "PM";

    if (isPM && hour !== 12) hour += 12;
    if (!isPM && hour === 12) hour = 0;

    const scheduledDate = new Date(referenceDate);
    scheduledDate.setHours(hour, minute, 0, 0);
    return scheduledDate;
  } catch (error) {
    console.error("Error parsing time:", timeStr, error);
    return null;
  }
}

async function getCaregiverTokens(db, patientGroupID, patientUid) {
  try {
    const groupDoc = await db
      .collection("patientGroups")
      .doc(patientGroupID)
      .get();

    if (!groupDoc.exists) return [];

    const caregiverIds = groupDoc.data().caregivers || [];
    const actualCaregivers = caregiverIds.filter((id) => id !== patientUid);

    const tokens = [];
    for (const caregiverId of actualCaregivers) {
      const userDoc = await db.collection("users").doc(caregiverId).get();
      if (userDoc.exists) {
        const token = userDoc.data().fcmToken;
        if (token) tokens.push(token);
      }
    }

    return tokens;
  } catch (error) {
    console.error("Error getting caregiver tokens:", error);
    return [];
  }
}