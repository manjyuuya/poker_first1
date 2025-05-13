import * as functions from "firebase-functions";
import admin from "firebase-admin";

admin.initializeApp();

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