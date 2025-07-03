import * as functions from "firebase-functions";
import admin from "firebase-admin";

admin.initializeApp();
const db = admin.firestore();

export const someFunction = functions.firestore
  .document("users/{userId}")
  .onCreate((snap, context) => {
    console.log("新しいユーザー:", snap.data());
    return null;
  });

export const deleteShiftOnDenial = functions.firestore
  .document("shifts/{shiftsId}")
  .onUpdate(async (change, context) => {
    const beforeData = change.before.data();
    const afterData = change.after.data();

    if (!beforeData || !afterData) {
      console.error("データが不正です");
      return null;
    }

    if (!beforeData.denied && afterData.denied === true) {
      await admin.firestore().collection("shifts")
        .doc(context.params.shiftsId)
        .delete();

      console.log("shiftsId:", context.params.shiftsId);
      console.log(`スケジュール (${context.params.shiftsId}) を削除しました`);
    }

    return null;
  });
  export const checkPokerNameExists = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError(
          "unauthenticated", "Authentication required."
      );
    }

    const pokerName = data.pokerName;
    if (!pokerName || typeof pokerName !== "string") {
      throw new functions.https.HttpsError(
          "invalid-argument", "PokerName is required and must be a string."
      );
    }

    try {
      const usersRef = admin.firestore().collection("users");
      const snapshot = await usersRef.where(
          "pokerName", "==", pokerName).limit(1).get();

      return {exists: !snapshot.empty};
    } catch (error) {
      console.error("PokerName チェックエラー:", error);
      throw new functions.https.HttpsError("internal", "PokerName チェックに失敗しました。");
    }
  });　

　export const onAttendanceCorrectionApproved = functions.firestore
   .document("attendanceCorrections/{correctionId}")
   .onUpdate(async (change, context) => {
     const before = change.before.data();
     const after = change.after.data();

     console.log("Function triggered. Before status:", before.status, "After status:", after.status);

     // ✅ ロック処理を追加（すでに approved / rejected 済みの場合はスキップ）
     if (before.status === "approved" || before.status === "rejected") {
       console.log("Already finalized (approved/rejected). Skipping update.");
       return;
     }

     if (after.status === "approved") {
       console.log("Correction approved. Proceeding with update.");

       const userId = after.userId;

       const dateObj = after.targetDate && after.targetDate.toDate
         ? after.targetDate.toDate()
         : null;

       if (!dateObj) {
         console.error("Invalid targetDate timestamp.");
         return;
       }

       const dateString = dateObj.toISOString().split("T")[0].replace(/-/g, "");

       const clockInDate = after.requestedClockInDateTime && after.requestedClockInDateTime.toDate
         ? after.requestedClockInDateTime.toDate()
         : null;

       const clockOutDate = after.requestedClockOutDateTime && after.requestedClockOutDateTime.toDate
         ? after.requestedClockOutDateTime.toDate()
         : null;

       if (!clockInDate || !clockOutDate) {
         console.error("Invalid clockIn or clockOut timestamp.");
         return;
       }

       console.log("userId:", userId, "dateString:", dateString);
       console.log("clockInDate:", clockInDate, "clockOutDate:", clockOutDate);

       const attendanceRef = db.collection("attendances").doc(`${userId}_${dateString}`);
       const attendanceSnap = await attendanceRef.get();

       if (!attendanceSnap.exists) {
         console.error("Attendance document not found:", `${userId}_${dateString}`);
         return;
       }

       const attendanceData = attendanceSnap.data();
       console.log("Fetched attendance data:", attendanceData);

       const shiftId = attendanceData && attendanceData.shiftId;
       if (!shiftId) {
         console.error("No shiftId found in attendance document.");
         return;
       }

       const shiftSnap = await db.collection("shifts").doc(shiftId).get();
       if (!shiftSnap.exists) {
         console.error("Shift not found:", shiftId);
         return;
       }

       const shift = shiftSnap.data();
       const scheduledStart = shift.start.toDate();
       const scheduledEnd = shift.end.toDate();

       console.log("Scheduled start:", scheduledStart, "Scheduled end:", scheduledEnd);

       const totalMinutes = Math.floor((clockOutDate.getTime() - clockInDate.getTime()) / 60000);
       console.log("Calculated totalMinutes:", totalMinutes);

       // ✅ 深夜時間算出関数
       const calculateNightMinutes = (clockInUtc, clockOutUtc) => {
         let nightMinutes = 0;
         let current = new Date(clockInUtc);
         while (current < clockOutUtc) {
           const jst = new Date(current.getTime() + 9 * 60 * 60 * 1000); // JST変換
           const hour = jst.getHours();
           if (hour >= 22 || hour < 5) {
             nightMinutes++;
           }
           current.setMinutes(current.getMinutes() + 1);
         }
         return nightMinutes;
       };

       const nightMinutes = calculateNightMinutes(clockInDate, clockOutDate);
       console.log("Calculated nightMinutes:", nightMinutes);

       const late = clockInDate > scheduledStart;
       console.log("Is late:", late);

       let shortageMinutes = 0;
       if (clockInDate > scheduledStart) {
         shortageMinutes += Math.floor((clockInDate.getTime() - scheduledStart.getTime()) / 60000);
       }
       if (clockOutDate < scheduledEnd) {
         shortageMinutes += Math.floor((scheduledEnd.getTime() - clockOutDate.getTime()) / 60000);
       }
       console.log("Calculated shortageMinutes:", shortageMinutes);

       const overtimeMinutes = clockOutDate > scheduledEnd
         ? Math.floor((clockOutDate.getTime() - scheduledEnd.getTime()) / 60000)
         : 0;
       console.log("Calculated overtimeMinutes:", overtimeMinutes);

       await attendanceRef.set({
         clockIn: admin.firestore.Timestamp.fromDate(clockInDate),
         clockOut: admin.firestore.Timestamp.fromDate(clockOutDate),
         totalMinutes,
         nightMinutes,
         late,
         shortageMinutes,
         overtimeMinutes
       }, { merge: true });

       console.log("Attendance document updated successfully.");
     } else {
       console.log("No status change to approved. Skipping update.");
     }
   });

 export const onAttendanceCorrectionRejected = functions.firestore
   .document("attendanceCorrections/{correctionId}")
   .onUpdate(async (change, context) => {
     const before = change.before.data();
     const after = change.after.data();

     console.log("Before status:", before.status, "After status:", after.status);

     // ✅ ロック処理：すでに削除対象であればスキップ
     if (before.status === "approved" || before.status === "rejected") {
       console.log("Already finalized (approved/rejected). Skipping deletion.");
       return;
     }

     if (after.status === "rejected") {
       const docRef = change.after.ref;

       try {
         await docRef.delete();
         console.log(`Deleted attendanceCorrection document ${context.params.correctionId}
           because status changed to rejected.`);
       } catch (error) {
         console.error("Error deleting document:", error);
       }
     } else {
       console.log("No status change to rejected. Skipping deletion.");
     }
   });
   export const calculateTournamentPrizes = functions.pubsub
     .schedule("every 1 minutes")
     .onRun(async (context) => {
       const now = admin.firestore.Timestamp.now();

       const tournamentsSnap = await admin.firestore()
         .collection("tournaments")
         .where("registerClose", "<=", now)
         .where("prizeCalculated", "==", false)
         .get();

       const batch = admin.firestore().batch();

       for (const doc of tournamentsSnap.docs) {
         const data = doc.data();
         const tournamentRef = doc.ref;

         const entryFee = data.entryFee || 0;
         const reentryFee = data.reentryFee || 0;
         const addonFee = data.addonFee || 0;

         // prizeTemplateId から割合を取得する
         const prizeTemplateId = data.prizeTemplateId;
         let entryPercentage = 100;
         let reentryPercentage = 100;
         let addonPercentage = 0;

         if (prizeTemplateId) {
           const prizeTemplateDoc = await admin.firestore()
             .collection("prizeSettings")
             .doc(prizeTemplateId)
             .get();

           if (prizeTemplateDoc.exists) {
             const templateData = prizeTemplateDoc.data();
             entryPercentage = (templateData.entryPercentage !== undefined && templateData.entryPercentage !== null)
               ? templateData.entryPercentage : 100;
             reentryPercentage = (templateData.reentryPercentage !== undefined && templateData.reentryPercentage !== null)
               ? templateData.reentryPercentage : 100;
             addonPercentage = (templateData.addonPercentage !== undefined && templateData.addonPercentage !== null)
               ? templateData.addonPercentage : 0;
           }
         }

         const playersSnap = await tournamentRef.collection("players").get();

         let totalEntry = 0;
         let totalReentry = 0;
         let totalAddon = 0;

         playersSnap.forEach(playerDoc => {
           totalEntry += 1;
           totalReentry += playerDoc.data().reentryCount || 0;
           totalAddon += playerDoc.data().addonCount || 0;
         });

         const entryTotal = totalEntry * entryFee * (entryPercentage / 100);
         const reentryTotal = totalReentry * reentryFee * (reentryPercentage / 100);
         const addonTotal = totalAddon * addonFee * (addonPercentage / 100);

         const totalPrize = Math.floor(entryTotal + reentryTotal + addonTotal);

         batch.update(tournamentRef, {
           prizeAmount: totalPrize,
           prizeCalculated: true
         });

         console.log(`Calculated prize for ${doc.id}: ${totalPrize}`);
       }

       await batch.commit();
       console.log("All tournaments processed.");
       return null;
     });
  /*// 出勤予定時刻の30分前に通知を送信
 export const sendShiftReminder = functions.pubsub
     .schedule("every 24 hours")  // 1日1回実行される（任意の時間を設定可能）
     .timeZone("Asia/Tokyo")  // 日本のタイムゾーンで実行
     .onRun(async (context) => {
       const now = new Date();
       const currentTime = now.getTime();  // 現在の時間をミリ秒単位で取得
       const thirtyMinutesBeforeShift = 30 * 60 * 1000;  // 30分前をミリ秒で表現

       // Shiftsコレクションから全てのシフトを取得（出勤予定30分前のシフトを選定）
       const shiftsSnapshot = await admin.firestore().collection("shifts").get();

       shiftsSnapshot.forEach(async (shiftDoc) => {
         const shiftData = shiftDoc.data();
         const shiftStart = shiftData.start.toDate(); // タイムスタンプから日付に変換

         // もし出勤時間が現在時刻+30分よりも近ければ、リマインダー通知を送る
         if (shiftStart.getTime() - currentTime <= thirtyMinutesBeforeShift) {
           const userId = shiftData.userId;
           const userRef = admin.firestore().collection("users").doc(userId);
           const userDoc = await userRef.get();

           if (userDoc.exists) {
             const userData = userDoc.data();
             const fcmToken = userData.fcmToken;

             if (fcmToken) {
               // 通知の送信
               const message = {
                 notification: {
                   title: "出勤リマインダー",
                   body: `もうすぐ出勤時刻です！(${shiftData.shift})`
                 },
                 token: fcmToken
               };

               try {
                 await admin.messaging().send(message);
                 console.log(`通知送信成功: ${userData.userName}`);
               } catch (error) {
                 console.log("通知送信エラー:", error);
               }
             }
           }
         }
       });
     });*/