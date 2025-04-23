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
